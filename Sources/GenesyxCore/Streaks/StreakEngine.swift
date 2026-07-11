// StreakEngine.swift
// WS1 — Streak engine v2 (Master Implementation Doc §3).
// Pure and synchronous: repositories feed it, nothing async inside.
// Reads daily logs + pH days; produces daily/weekly streaks and one-shot milestones.

import Foundation

// MARK: - CalendarDate helpers
// GenesyxCore already defines `CalendarDate` (Models/CalendarDate.swift, backed by a
// proleptic-Gregorian dayNumber). Per the handoff, we do NOT ship a second struct — we
// add only the helpers the engine needs (labeled init / addingDays / isoWeekday /
// startOfWeek), mapped onto the existing API (plusDays / weekdaySundayZero).

public extension CalendarDate {
    /// Labeled convenience initialiser used by the engine and its tests.
    init(year: Int, month: Int, day: Int) {
        self.init(year, month, day)
    }

    /// Alias for `plusDays`, matching the engine's vocabulary (negative = backwards).
    func addingDays(_ days: Int) -> CalendarDate { plusDays(days) }

    /// ISO weekday: 1 = Monday … 7 = Sunday (weeks are Mon–Sun per §3).
    /// Existing `weekdaySundayZero` is Sun=0 … Sat=6, so Sunday maps to 7.
    var isoWeekday: Int {
        weekdaySundayZero == 0 ? 7 : weekdaySundayZero
    }

    /// The Monday of this date's Mon–Sun week.
    var startOfWeek: CalendarDate {
        addingDays(-(isoWeekday - 1))
    }
}

// MARK: - Input protocol

/// What the engine needs to know about a day's log. Keeps the engine decoupled
/// from the concrete DailyLog model (and trivially testable).
public protocol StreakLoggable {
    var waterMl: Int { get }
    /// True when ANY field was logged: water, mood, energy, symptom, sleep,
    /// supplement, or note. pH days arrive separately via `phByDate`.
    var hasAnyEntry: Bool { get }
}

/// Conform the existing DailyLog model to the engine's input protocol (§3).
extension DailyLog: StreakLoggable {
    public var hasAnyEntry: Bool {
        waterMl > 0 || mood != nil || energy != nil || !symptoms.isEmpty
            || sleepMinutes != nil || !supplements.isEmpty || !(notes ?? "").isEmpty
    }
}

// MARK: - Output

public enum Milestone: String, CaseIterable {
    case day7 = "milestone_7"       // 7-day daily hydration streak
    case day14 = "milestone_14"     // 14-day daily hydration streak
    case week1 = "milestone_w1"     // first complete week
    case week4 = "milestone_w4"     // four consecutive complete weeks

    /// The persisted "celebrated" flag key (PreferencesRepository).
    public var flagKey: String { rawValue + "_sent" }
}

public struct StreakState: Equatable {
    /// Consecutive days with any water logged, ending today — or ending yesterday
    /// when today has no water YET (morning grace: the streak isn't zeroed at 8am
    /// before she's had a chance to log; a genuinely missed day still breaks it).
    public let dailyHydration: Int
    /// Consecutive COMPLETE weeks (≥5 of 7 days with any activity, Mon–Sun),
    /// ending with the current week (if already complete) or the previous week
    /// (a current week still in progress never breaks the streak).
    public let weeklyStreak: Int
    /// Days with any activity in the current Mon–Sun week (0–7).
    public let daysLoggedThisWeek: Int
    /// All-time best daily hydration streak found in the provided history.
    public let bestDailyStreak: Int
    /// Milestones newly crossed and not yet celebrated — fire these, then persist
    /// their flags.
    public let milestones: [Milestone]
    /// Celebrated flags whose underlying streak has dropped below the threshold —
    /// clear these so re-achieving re-fires (§3 rule).
    public let lapsedCelebrations: Set<String>
    /// Per-day activity for the current week, Monday-first — drives the
    /// Consistency card's 7-dot row.
    public let weekDots: [Bool]

    public init(
        dailyHydration: Int,
        weeklyStreak: Int,
        daysLoggedThisWeek: Int,
        bestDailyStreak: Int,
        milestones: [Milestone],
        lapsedCelebrations: Set<String>,
        weekDots: [Bool]
    ) {
        self.dailyHydration = dailyHydration
        self.weeklyStreak = weeklyStreak
        self.daysLoggedThisWeek = daysLoggedThisWeek
        self.bestDailyStreak = bestDailyStreak
        self.milestones = milestones
        self.lapsedCelebrations = lapsedCelebrations
        self.weekDots = weekDots
    }
}

// MARK: - Engine

public enum StreakEngine {

    public static func compute<Log: StreakLoggable>(
        logsByDate: [CalendarDate: Log],
        phByDate: Set<CalendarDate>,
        today: CalendarDate,
        celebrated: Set<String>
    ) -> StreakState {
        let hydrationDays = Set(logsByDate.filter { $0.value.waterMl > 0 }.keys)
        let activityDays = Set(logsByDate.filter { $0.value.hasAnyEntry }.keys)
            .union(phByDate) // pH-only days count toward weekly consistency (§3)

        let daily = dailyStreak(hydrationDays: hydrationDays, today: today)
        let best = bestStreak(hydrationDays: hydrationDays)
        let (weekly, thisWeekCount, dots) = weeklyStreak(activityDays: activityDays, today: today)

        let current: [Milestone: Int] = [
            .day7: daily, .day14: daily, .week1: weekly, .week4: weekly,
        ]
        let thresholds: [Milestone: Int] = [.day7: 7, .day14: 14, .week1: 1, .week4: 4]

        var newlyCrossed: [Milestone] = []
        var lapsed: Set<String> = []
        for m in Milestone.allCases {
            let met = current[m]! >= thresholds[m]!
            let alreadyCelebrated = celebrated.contains(m.flagKey)
            if met && !alreadyCelebrated { newlyCrossed.append(m) }
            if !met && alreadyCelebrated { lapsed.insert(m.flagKey) }
        }

        return StreakState(
            dailyHydration: daily,
            weeklyStreak: weekly,
            daysLoggedThisWeek: thisWeekCount,
            bestDailyStreak: best,
            milestones: newlyCrossed,
            lapsedCelebrations: lapsed,
            weekDots: dots
        )
    }

    // MARK: internals (static + deterministic)

    /// Consecutive hydration days ending today, or ending yesterday when today is
    /// still unlogged (morning grace). A fully missed day breaks the run.
    static func dailyStreak(hydrationDays: Set<CalendarDate>, today: CalendarDate) -> Int {
        let anchor: CalendarDate
        if hydrationDays.contains(today) {
            anchor = today
        } else if hydrationDays.contains(today.addingDays(-1)) {
            anchor = today.addingDays(-1)
        } else {
            return 0
        }
        var streak = 0
        var cursor = anchor
        while hydrationDays.contains(cursor) {
            streak += 1
            cursor = cursor.addingDays(-1)
        }
        return streak
    }

    /// Longest run of consecutive hydration days anywhere in history.
    static func bestStreak(hydrationDays: Set<CalendarDate>) -> Int {
        var best = 0
        for day in hydrationDays where !hydrationDays.contains(day.addingDays(-1)) {
            var length = 0
            var cursor = day
            while hydrationDays.contains(cursor) {
                length += 1
                cursor = cursor.addingDays(1)
            }
            best = max(best, length)
        }
        return best
    }

    static let completeWeekThreshold = 5 // of 7 days — perfection not required (§3)

    /// Returns (weeklyStreak, daysLoggedThisWeek, weekDots Monday-first).
    static func weeklyStreak(
        activityDays: Set<CalendarDate>,
        today: CalendarDate
    ) -> (streak: Int, thisWeek: Int, dots: [Bool]) {
        func daysActive(inWeekStarting monday: CalendarDate) -> Int {
            (0..<7).filter { activityDays.contains(monday.addingDays($0)) }.count
        }

        let currentMonday = today.startOfWeek
        let dots = (0..<7).map { activityDays.contains(currentMonday.addingDays($0)) }
        let thisWeekCount = dots.filter { $0 }.count

        // Streak ends with the current week when it's already complete; otherwise
        // the in-progress week is pending (never a break) and counting starts at
        // the previous week.
        var cursor = thisWeekCount >= completeWeekThreshold
            ? currentMonday
            : currentMonday.addingDays(-7)

        var streak = 0
        while daysActive(inWeekStarting: cursor) >= completeWeekThreshold {
            streak += 1
            cursor = cursor.addingDays(-7)
        }
        return (streak, thisWeekCount, dots)
    }
}
