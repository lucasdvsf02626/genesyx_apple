// TrackingEngine.swift
// Canonical cross-platform tracking metrics — identical rules to the Android `TrackingEngine`.
// Pure and synchronous, with NO UI/SwiftUI imports. This is the single type the shared
// `tracking_test_vectors.json` (mirrored byte-for-byte in the Android repo) runs against; it is
// the contract that keeps both platforms computing the same numbers from the same data.
//
// Definitions (canonical spec):
//   • Day  = the user's local calendar date (`CalendarDate`, timezone-free).
//   • Week = ISO-8601 Monday-start calendar week (`CalendarDate.startOfWeek`).
//   • Meaningful log = a day whose log has ANY of: mood, energy, ≥1 symptom, sleep > 0,
//     water > 0, ≥1 supplement, non-blank note — OR a pH reading exists for that date.

import Foundation

/// The minimal per-day facts the engine needs. Keeping the engine on this protocol (rather than the
/// concrete `DailyLog`) is what lets the shared vectors drive it with a tiny synthetic type.
public protocol TrackingLoggable {
    var waterMl: Int { get }
    /// True when the day's log carries ANY meaningful field: mood, energy, ≥1 symptom, sleep > 0,
    /// water > 0, ≥1 supplement, or a non-blank note. Excludes pH — the engine folds pH in
    /// separately via `phByDate`, because a pH reading also makes a day "meaningful".
    var isMeaningfulLog: Bool { get }
}

extension DailyLog: TrackingLoggable {
    public var isMeaningfulLog: Bool {
        waterMl > 0 || mood != nil || energy != nil || !symptoms.isEmpty
            || (sleepMinutes ?? 0) > 0 || !supplements.isEmpty || !(notes ?? "").isEmpty
    }
}

/// All five canonical metrics for one render — `TrackingEngine.compute` fills this in one pass.
public struct TrackingMetrics: Equatable, Sendable {
    /// Consecutive meaningful-log days ending today (or yesterday, under morning grace).
    public let dailyLogStreak: Int
    /// Consecutive days with water > 0 ending today (or yesterday, under grace). Drives the flame.
    public let hydrationLogStreak: Int
    /// Days in the CURRENT ISO week (Mon–Sun containing `today`) with water ≥ goal.
    public let daysOnGoal: Int
    /// Consecutive completed ISO weeks with ≥ `minDays` meaningful-log days; the current
    /// incomplete week never breaks the streak and may extend it once it reaches `minDays`.
    public let weeklyStreak: Int
    /// Longest run of consecutive hydration days found in the supplied history. The app persists
    /// `max(stored, computed)` so a truncated fetch window can never shrink the all-time best.
    public let bestDailyStreak: Int

    public init(
        dailyLogStreak: Int,
        hydrationLogStreak: Int,
        daysOnGoal: Int,
        weeklyStreak: Int,
        bestDailyStreak: Int
    ) {
        self.dailyLogStreak = dailyLogStreak
        self.hydrationLogStreak = hydrationLogStreak
        self.daysOnGoal = daysOnGoal
        self.weeklyStreak = weeklyStreak
        self.bestDailyStreak = bestDailyStreak
    }
}

public enum TrackingEngine {

    public static let defaultWaterGoalMl = 2400
    public static let defaultWeeklyMinDays = 4

    /// Compute every canonical metric for one render.
    public static func compute<Log: TrackingLoggable>(
        logsByDate: [CalendarDate: Log],
        phByDate: Set<CalendarDate>,
        today: CalendarDate,
        goalMl: Int = defaultWaterGoalMl,
        weeklyMinDays: Int = defaultWeeklyMinDays
    ) -> TrackingMetrics {
        let hydration = hydrationDays(logsByDate)
        let meaningful = meaningfulDays(logsByDate: logsByDate, phByDate: phByDate)
        return TrackingMetrics(
            dailyLogStreak: streak(days: meaningful, today: today),
            hydrationLogStreak: streak(days: hydration, today: today),
            daysOnGoal: daysOnGoal(logsByDate: logsByDate, goalMl: goalMl, today: today),
            weeklyStreak: weeklyStreak(days: meaningful, today: today, minDays: weeklyMinDays),
            bestDailyStreak: bestStreak(days: hydration))
    }

    // MARK: - Day-set builders

    /// Dates with any water logged.
    public static func hydrationDays<Log: TrackingLoggable>(_ logsByDate: [CalendarDate: Log]) -> Set<CalendarDate> {
        Set(logsByDate.filter { $0.value.waterMl > 0 }.keys)
    }

    /// Dates that count as a meaningful log — a log with any meaningful field, OR a pH-only day.
    public static func meaningfulDays<Log: TrackingLoggable>(
        logsByDate: [CalendarDate: Log],
        phByDate: Set<CalendarDate>
    ) -> Set<CalendarDate> {
        Set(logsByDate.filter { $0.value.isMeaningfulLog }.keys).union(phByDate)
    }

    // MARK: - Streaks (today-grace)

    /// Consecutive days present in `days` ending today, or ending yesterday when today is not yet
    /// in the set (morning grace: an unlogged today does not zero the streak; a genuinely missed
    /// day breaks it). Empty history → 0.
    public static func streak(days: Set<CalendarDate>, today: CalendarDate) -> Int {
        let anchor: CalendarDate
        if days.contains(today) {
            anchor = today
        } else if days.contains(today.addingDays(-1)) {
            anchor = today.addingDays(-1)
        } else {
            return 0
        }
        var streak = 0
        var cursor = anchor
        while days.contains(cursor) {
            streak += 1
            cursor = cursor.addingDays(-1)
        }
        return streak
    }

    /// Longest run of consecutive days anywhere in `days`.
    public static func bestStreak(days: Set<CalendarDate>) -> Int {
        var best = 0
        for day in days where !days.contains(day.addingDays(-1)) {
            var length = 0
            var cursor = day
            while days.contains(cursor) {
                length += 1
                cursor = cursor.addingDays(1)
            }
            best = max(best, length)
        }
        return best
    }

    // MARK: - Days on goal (current ISO week)

    /// Days in the Mon–Sun week containing `today` whose logged water is at least `goalMl`.
    public static func daysOnGoal<Log: TrackingLoggable>(
        logsByDate: [CalendarDate: Log],
        goalMl: Int,
        today: CalendarDate
    ) -> Int {
        let monday = today.startOfWeek
        return (0..<7).filter { (logsByDate[monday.addingDays($0)]?.waterMl ?? 0) >= goalMl }.count
    }

    // MARK: - Weekly streak (completed ISO weeks + current-week grace)

    /// Consecutive ISO weeks with ≥ `minDays` meaningful-log days. The current (in-progress) week
    /// never breaks the streak: counting starts at the current week only once it already reaches
    /// `minDays`, otherwise at the previous week.
    public static func weeklyStreak(
        days: Set<CalendarDate>,
        today: CalendarDate,
        minDays: Int
    ) -> Int {
        func activeDays(weekStarting monday: CalendarDate) -> Int {
            (0..<7).filter { days.contains(monday.addingDays($0)) }.count
        }
        let currentMonday = today.startOfWeek
        var cursor = activeDays(weekStarting: currentMonday) >= minDays
            ? currentMonday
            : currentMonday.addingDays(-7)

        var streak = 0
        while activeDays(weekStarting: cursor) >= minDays {
            streak += 1
            cursor = cursor.addingDays(-7)
        }
        return streak
    }
}
