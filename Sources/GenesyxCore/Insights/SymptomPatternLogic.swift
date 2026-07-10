import Foundation

/// Symptom-pattern insight over the last 28 days of real logged symptoms. Honest about thin data:
/// with fewer than 7 days of symptoms it refuses to claim a pattern.
public struct SymptomPatternInsights: Equatable, Sendable {
    public let dailyCounts: [Int]      // 28 values, oldest → newest
    public let topSymptom: String?
    public let topSymptomCount: Int
    public let daysWithSymptoms: Int
    public let insight: String

    public init(dailyCounts: [Int], topSymptom: String?, topSymptomCount: Int, daysWithSymptoms: Int, insight: String) {
        self.dailyCounts = dailyCounts
        self.topSymptom = topSymptom
        self.topSymptomCount = topSymptomCount
        self.daysWithSymptoms = daysWithSymptoms
        self.insight = insight
    }
}

public enum SymptomPatternLogic {
    public static func compute(logs: [CalendarDate: DailyLog], today: CalendarDate = .today()) -> SymptomPatternInsights {
        let days = (0..<28).reversed().map { today.minusDays($0) }   // oldest → newest
        let counts = days.map { logs[$0]?.symptoms.count ?? 0 }
        let daysWith = counts.filter { $0 > 0 }.count

        var frequency: [String: Int] = [:]
        for day in days {
            for symptom in logs[day]?.symptoms ?? [] { frequency[symptom, default: 0] += 1 }
        }
        // Deterministic top pick: highest count, then alphabetical.
        let top = frequency.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.first

        let insight: String
        if daysWith == 0 {
            insight = "No symptoms logged in the last 4 weeks — log how you feel to see patterns."
        } else if daysWith < 7 {
            insight = "Early days — too soon to read patterns. Keep logging how you feel."
        } else if let top {
            insight = "You logged \(top.key) \(top.value) times this month."
        } else {
            insight = "Symptoms are varied — keep logging to reveal patterns over time."
        }

        return SymptomPatternInsights(
            dailyCounts: counts,
            topSymptom: top?.key,
            topSymptomCount: top?.value ?? 0,
            daysWithSymptoms: daysWith,
            insight: insight
        )
    }
}
