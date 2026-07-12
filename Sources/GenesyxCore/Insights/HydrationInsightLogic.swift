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
}
