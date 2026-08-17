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

/// A single day of nutrition as the tracker row and its detail sheet report it.
///
/// The Daily Log collects **two** things under nutrition — supplements and food groups — and for a
/// long time every summary surface counted only the first. A woman who ticked six food groups and
/// no supplements opened the tracker's Nutrition row and was told she had logged nothing. This is
/// the shared arithmetic that stops any one surface drifting back to half the data.
///
/// It states counts and nothing else. Naming how many groups a day contained is a record, not a
/// claim, which is the same line `FoodLogCopy` holds — see `NutritionContent.FoodGroup`.
public enum NutritionDaySignal {

    public static var foodGroupCount: Int { FoodGroup.allCases.count }

    /// Counted against the known cases rather than the stored set, so a token written by a newer
    /// build — or a supplement she has since removed from her plan — cannot render "7 of 6".
    public static func knownFoodGroups(_ logged: Set<String>) -> Int {
        FoodGroup.allCases.filter { logged.contains($0.rawValue) }.count
    }

    public static func knownSupplements(_ logged: Set<String>) -> Int {
        NutritionContent.supplementLogOptions.filter { logged.contains($0) }.count
    }

    /// `nil` when she logged neither, so the caller can use its own "nothing yet" copy rather than
    /// this deciding what an empty day should say.
    public static func summaryLine(supplements: Int, foodGroups: Int) -> String? {
        switch (supplements, foodGroups) {
        case (0, 0):
            return nil
        case (let s, 0):
            return "\(s) of \(NutritionConsistencyLogic.planSize) supplements today"
        case (0, let f):
            return "\(f) of \(foodGroupCount) food groups today"
        case (let s, let f):
            return "\(s) supplements, \(f) food groups"
        }
    }

    /// Both halves weighted equally, so a day of food groups alone fills the same as a day of
    /// supplements alone. Neither is the more real entry.
    public static func fill(supplements: Int, foodGroups: Int) -> Double {
        let supplementShare = min(Double(supplements) / Double(NutritionConsistencyLogic.planSize), 1)
        let foodShare = min(Double(foodGroups) / Double(foodGroupCount), 1)
        return (supplementShare + foodShare) / 2
    }

    /// Everything this type can render, for the food-log claim guard.
    public static var allStrings: [String] {
        var out: [String] = []
        for s in 0...NutritionConsistencyLogic.planSize {
            for f in 0...foodGroupCount {
                if let line = summaryLine(supplements: s, foodGroups: f) { out.append(line) }
            }
        }
        return out
    }
}
