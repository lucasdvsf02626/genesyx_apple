import Foundation

/// Weekly sleep state derived from real logged sleep (mirrors `HydrationInsightLogic`). Duration
/// only — the app logs minutes slept, never a quality score, so nothing here is invented.
public struct SleepInsights: Equatable, Sendable {
    public let dailyMinutes: [Int]   // 7 values, Monday → Sunday; 0 = no night logged
    public let nightsLogged: Int     // days with sleep > 0, 0...7
    public let averageMinutes: Int   // mean over logged nights (0 when none)
    public let insight: String

    public init(dailyMinutes: [Int], nightsLogged: Int, averageMinutes: Int, insight: String) {
        self.dailyMinutes = dailyMinutes
        self.nightsLogged = nightsLogged
        self.averageMinutes = averageMinutes
        self.insight = insight
    }
}

/// Pure sleep-insight logic. Copy is behavioural and de-pressured — never a sleep score, never a
/// medical or causal claim (the Learn content is explicit that duration can't prove cause), never
/// guilt. British English.
public enum SleepInsightLogic {

    /// The height a full bar represents (10h). A soft ceiling for the chart, not a goal — sleep has
    /// no pass/fail target, so bars are scaled against this rather than a goal line.
    public static let chartCeilingMinutes = 600

    public static func compute(dailyMinutes: [Int]) -> SleepInsights {
        let logged = dailyMinutes.filter { $0 > 0 }
        let nights = logged.count
        let average = nights > 0 ? logged.reduce(0, +) / nights : 0
        return SleepInsights(
            dailyMinutes: dailyMinutes,
            nightsLogged: nights,
            averageMinutes: average,
            insight: insightLine(nightsLogged: nights, averageMinutes: average)
        )
    }

    /// Duration formatted as "7h" or "7h 25m".
    public static func durationLabel(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    public static func insightLine(nightsLogged: Int, averageMinutes: Int) -> String {
        guard nightsLogged > 0 else {
            return "No sleep logged yet this week — noting even one night helps the picture build."
        }
        let nights = "\(nightsLogged) \(nightsLogged == 1 ? "night" : "nights")"
        let avg = durationLabel(averageMinutes)
        switch averageMinutes {
        case ..<(6 * 60):
            return "You're averaging \(avg) a night across \(nights) — rest where the day allows."
        case (6 * 60)..<(7 * 60):
            return "Averaging \(avg) a night over \(nights) — a little more rest, when you can, tends to help."
        case (7 * 60)...(9 * 60):
            return "Averaging \(avg) a night across \(nights) — a steady, restful rhythm."
        default:
            return "Averaging \(avg) a night over \(nights) — plenty of rest this week."
        }
    }
}
