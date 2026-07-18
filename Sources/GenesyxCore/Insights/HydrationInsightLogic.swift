import Foundation

/// Weekly hydration state derived from real logged water (mirrors `PhInsightLogic`).
public struct HydrationInsights: Equatable, Sendable {
    public let dailyMl: [Int]      // 7 values, oldest → newest
    public let totalMl: Int
    public let daysOnGoal: Int     // 0...7
    public let streak: Int
    public let insight: String

    public init(dailyMl: [Int], totalMl: Int, daysOnGoal: Int, streak: Int, insight: String) {
        self.dailyMl = dailyMl
        self.totalMl = totalMl
        self.daysOnGoal = daysOnGoal
        self.streak = streak
        self.insight = insight
    }
}

/// Pure hydration-insight logic. Copy is behavioural and de-pressured — never medical, never guilt.
public enum HydrationInsightLogic {

    public static func compute(dailyMl: [Int], goalMl: Int = 2400, streak: Int) -> HydrationInsights {
        let total = dailyMl.reduce(0, +)
        let onGoal = dailyMl.filter { $0 >= goalMl }.count
        return HydrationInsights(
            dailyMl: dailyMl,
            totalMl: total,
            daysOnGoal: onGoal,
            streak: streak,
            insight: insightLine(daysOnGoal: onGoal, streak: streak, hasAnyWater: total > 0)
        )
    }

    /// `hasAnyWater` separates "logged, but never hit goal" from "logged nothing at all" — both used
    /// to land on daysOnGoal == 0, so a user who tracked nothing was told she'd started tracking.
    public static func insightLine(daysOnGoal: Int, streak: Int, hasAnyWater: Bool = true) -> String {
        var base: String
        switch daysOnGoal {
        case 0 where !hasAnyWater:
            base = "No water logged yet this week — one glass, whenever you think of it, is enough to start."
        case 0:     base = "You've started tracking water this week — small, steady sips build the habit."
        case 1...3: base = "\(daysOnGoal) days on goal this week. Anchor a glass to a meal and you'll steady out."
        case 4...6: base = "\(daysOnGoal) of 7 days on goal — gentle, consistent progress."
        default:    base = "Every day on goal this week — lovely consistency."
        }
        if streak >= 3 { base += " \(streak)-day streak going." }
        return base
    }

    /// Trailing 7-day window ending today (index 6 = today), read straight from the logs so no
    /// view buckets dates itself — one source of truth for Home and Track. `today` is injectable
    /// (derive with `CalendarDate.today(_:now:)`) so midnight/timezone behaviour is unit-testable.
    public static func lastSevenDays(logByDate: [CalendarDate: DailyLog],
                                     goalMl: Int = 2400,
                                     streak: Int,
                                     today: CalendarDate = .today()) -> HydrationInsights {
        let daily = (0..<7).map { logByDate[today.minusDays(6 - $0)]?.waterMl ?? 0 }
        return compute(dailyMl: daily, goalMl: goalMl, streak: streak)
    }

    /// Fill level for one day's bar/dot: 1 on goal, 0.5 partial, 0 none. Pure so the week row's
    /// visual state is unit-testable without a snapshot harness. Missed days return 0 (rendered
    /// neutrally — never a warning colour).
    public static func dayFillLevel(ml: Int, goalMl: Int = 2400) -> Double {
        guard goalMl > 0 else { return 0 }
        if ml >= goalMl { return 1 }
        return ml > 0 ? 0.5 : 0
    }
}
