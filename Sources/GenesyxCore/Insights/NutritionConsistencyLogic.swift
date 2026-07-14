import Foundation

/// Weekly nutrition state derived from real logged supplements (mirrors `HydrationInsightLogic`).
/// The signal is honest: how many of her plan supplements she logged each day this ISO week — no
/// mock bars, no fabricated adherence.
public struct NutritionConsistencyInsights: Equatable, Sendable {
    public let dailyCounts: [Int]   // 7 values, Monday → Sunday: supplements logged that day
    public let daysLogged: Int      // days with ≥1 supplement, 0...7
    public let totalTaken: Int      // sum over the week
    public let insight: String

    public init(dailyCounts: [Int], daysLogged: Int, totalTaken: Int, insight: String) {
        self.dailyCounts = dailyCounts
        self.daysLogged = daysLogged
        self.totalTaken = totalTaken
        self.insight = insight
    }
}

/// Pure nutrition-consistency logic. Copy is behavioural and de-pressured — never medical, never
/// guilt, present-tense and inviting (British English).
public enum NutritionConsistencyLogic {

    /// The number of supplements in her plan — the denominator each bar is drawn against. Matches the
    /// four options on the Daily Log supplement picker.
    public static let planSize = 4

    public static func compute(dailyCounts: [Int]) -> NutritionConsistencyInsights {
        let daysLogged = dailyCounts.filter { $0 > 0 }.count
        let total = dailyCounts.reduce(0, +)
        return NutritionConsistencyInsights(
            dailyCounts: dailyCounts,
            daysLogged: daysLogged,
            totalTaken: total,
            insight: insightLine(daysLogged: daysLogged, hasAny: total > 0)
        )
    }

    /// `hasAny` separates "logged supplements on no day" (nothing tracked) from a genuine zero, so a
    /// user who tracked nothing is invited to start rather than told she fell short.
    public static func insightLine(daysLogged: Int, hasAny: Bool = true) -> String {
        switch daysLogged {
        case 0 where !hasAny:
            return "No supplements logged yet this week — even one, whenever you remember, is a gentle start."
        case 0:
            return "You've started noting your supplements — small, steady habits build from here."
        case 1...3:
            let dayWord = daysLogged == 1 ? "day" : "days"
            return "\(daysLogged) \(dayWord) with supplements this week — a gentle rhythm is forming."
        case 4...6:
            return "\(daysLogged) of 7 days with supplements — lovely, steady consistency."
        default:
            return "Supplements every day this week — beautifully consistent."
        }
    }
}
