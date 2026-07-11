// ConsistencyInsightLogic.swift
// WS3a §5.1 — the NEW Consistency card, plus the pure additions to the existing
// Hydration and pH cards (§5.2, §5.3). Pure logic only; the SwiftUI cards render
// these view models. No new data models, no async.

import Foundation

// MARK: - Consistency card (reads StreakEngine)

public struct ConsistencyCardModel: Equatable {
    public let dailyStreak: Int
    public let weeklyStreak: Int
    public let bestDailyStreak: Int
    public let daysLoggedThisWeek: Int
    public let weekDots: [Bool]          // Monday-first, 7 entries
    public let insight: String
    public let isEmpty: Bool

    public init(
        dailyStreak: Int,
        weeklyStreak: Int,
        bestDailyStreak: Int,
        daysLoggedThisWeek: Int,
        weekDots: [Bool],
        insight: String,
        isEmpty: Bool
    ) {
        self.dailyStreak = dailyStreak
        self.weeklyStreak = weeklyStreak
        self.bestDailyStreak = bestDailyStreak
        self.daysLoggedThisWeek = daysLoggedThisWeek
        self.weekDots = weekDots
        self.insight = insight
        self.isEmpty = isEmpty
    }
}

public enum ConsistencyInsightLogic {

    public static func model(from state: StreakState) -> ConsistencyCardModel {
        let empty = state.dailyHydration == 0 && state.weeklyStreak == 0
            && state.daysLoggedThisWeek == 0 && state.bestDailyStreak == 0

        let insight: String
        if empty {
            // De-pressured empty state — never guilt (§8).
            insight = "Nothing logged yet — one small entry starts the picture."
        } else if state.weeklyStreak >= 1 {
            insight = "You've logged \(state.daysLoggedThisWeek) of 7 days this week — "
                + "\(state.weeklyStreak) steady week\(state.weeklyStreak == 1 ? "" : "s")."
        } else {
            insight = "You've logged \(state.daysLoggedThisWeek) of 7 days this week — "
                + "steady counts more than perfect."
        }

        return ConsistencyCardModel(
            dailyStreak: state.dailyHydration,
            weeklyStreak: state.weeklyStreak,
            bestDailyStreak: state.bestDailyStreak,
            daysLoggedThisWeek: state.daysLoggedThisWeek,
            weekDots: state.weekDots,
            insight: insight,
            isEmpty: empty
        )
    }
}

// MARK: - Hydration card deepening (§5.2): week-over-week delta

public enum HydrationDeltaLogic {

    /// Week-over-week hydration delta line, e.g. "+300ml vs last week".
    /// Returns nil unless BOTH weeks have at least one logged day — no fabricated
    /// comparisons (§8: thin data is called thin).
    public static func weekOverWeekLine(
        thisWeekMl: [Int],   // logged days only, current 7-day window
        lastWeekMl: [Int]    // logged days only, previous 7-day window
    ) -> String? {
        guard !thisWeekMl.isEmpty, !lastWeekMl.isEmpty else { return nil }
        let delta = thisWeekMl.reduce(0, +) - lastWeekMl.reduce(0, +)
        if delta == 0 { return "Level with last week" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(abs(delta))ml vs last week"
    }
}

// MARK: - pH card deepening (§5.3): reading-count context

public enum PhContextLogic {

    /// "How solid is this trend" context line. Keeps the early-days guard.
    public static func readingCountLine(count: Int, windowDays: Int = 30) -> String {
        switch count {
        case 0:
            return "No readings yet in the last \(windowDays) days."
        case 1...3:
            return "\(count) reading\(count == 1 ? "" : "s") in \(windowDays) days — early days, too soon to read patterns."
        default:
            return "\(count) readings in \(windowDays) days."
        }
    }
}
