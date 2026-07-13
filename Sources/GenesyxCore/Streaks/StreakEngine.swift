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
    /// Consecutive COMPLETE weeks (≥4 of 7 days with any activity, Mon–Sun, per the canonical
    /// `TrackingEngine` rule), ending with the current week (if already complete) or the previous
    /// week (a current week still in progress never breaks the streak).
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
        // Canonical metrics come from the single cross-platform engine (`TrackingEngine`); this
        // type adds only the milestone + week-dot bookkeeping the UI needs on top of them.
        let hydrationDays = Set(logsByDate.filter { $0.value.waterMl > 0 }.keys)
        let activityDays = Set(logsByDate.filter { $0.value.hasAnyEntry }.keys)
            .union(phByDate) // pH-only days count toward weekly consistency (§3)

        let daily = TrackingEngine.streak(days: hydrationDays, today: today)
        let best = TrackingEngine.bestStreak(days: hydrationDays)
        let weekly = TrackingEngine.weeklyStreak(
            days: activityDays, today: today, minDays: TrackingEngine.defaultWeeklyMinDays)

        // Current-week dots (Monday-first) and count for the Consistency card's 7-dot row.
        let currentMonday = today.startOfWeek
        let dots = (0..<7).map { activityDays.contains(currentMonday.addingDays($0)) }
        let thisWeekCount = dots.filter { $0 }.count

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

}
