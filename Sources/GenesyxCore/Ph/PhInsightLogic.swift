import Foundation

public enum Trend: String, Sendable { case up, down, flat }

/// Computed vaginal-pH insights, mirroring the Android `PhInsights` data class.
public struct PhInsights: Equatable, Sendable {
    public var hasReadings: Bool
    public var currentValue: Double?
    public var currentStatus: PhStatus?
    public var trend: Trend
    public var avg7: Double?
    public var avg30: Double?
    public var insight: String
    public var recommendation: String

    public init(
        hasReadings: Bool = false,
        currentValue: Double? = nil,
        currentStatus: PhStatus? = nil,
        trend: Trend = .flat,
        avg7: Double? = nil,
        avg30: Double? = nil,
        insight: String = "Log a few pH readings to see personalised insights here.",
        recommendation: String = ""
    ) {
        self.hasReadings = hasReadings
        self.currentValue = currentValue
        self.currentStatus = currentStatus
        self.trend = trend
        self.avg7 = avg7
        self.avg30 = avg30
        self.insight = insight
        self.recommendation = recommendation
    }
}

/// Pure vaginal-pH insight computation, ported from the Android `PhInsightLogic` (web
/// `PhInsightsSection`). Trend uses the last two readings (threshold 0.1); the
/// insight/recommendation derive from the 7-day-average status once there are at least two
/// recent readings. Averages are over the 7- and 30-day windows ending at `now`.
public enum PhInsightLogic {

    private static let secondsPerDay: TimeInterval = 86_400

    public static func compute(_ readings: [PhReading], now: Date = Date()) -> PhInsights {
        // Vaginal-only: legacy urine readings are on a different scale and must never be classified
        // into a Healthy/Elevated band. Filter BEFORE any computation; with no vaginal readings we
        // return the empty/default state.
        let vaginal = readings.filter { $0.measurementType == .vaginal }
        if vaginal.isEmpty { return PhInsights() }

        let sorted = vaginal.sorted { $0.recordedAt < $1.recordedAt }
        let latest = sorted[sorted.count - 1]
        let previous = sorted.count >= 2 ? sorted[sorted.count - 2] : nil
        let status = PhStatus.classify(latest.phValue)

        func avgWithin(_ days: Double) -> Double? {
            let cutoff = now.addingTimeInterval(-days * secondsPerDay)
            let window = sorted.filter { $0.recordedAt > cutoff }
            guard !window.isEmpty else { return nil }
            return window.map(\.phValue).reduce(0, +) / Double(window.count)
        }

        let last7 = sorted.filter { $0.recordedAt > now.addingTimeInterval(-7 * secondsPerDay) }
        let avg7 = avgWithin(7)
        let avg30 = avgWithin(30)

        let trend: Trend
        if let previous {
            let delta = latest.phValue - previous.phValue
            if delta > 0.1 {
                trend = .up
            } else if delta < -0.1 {
                trend = .down
            } else {
                trend = .flat
            }
        } else {
            trend = .flat
        }

        var insight = "Log a few more readings and we'll share gentle observations."
        // The "recommendation" field carries the non-alarming GP/pharmacist signpost for elevated
        // readings only — never dietary advice.
        var recommendation = ""
        if last7.count >= 2, let avg7 {
            switch PhStatus.classify(avg7) {
            case .healthy:
                insight = PhCopy.healthy
            case .elevated:
                insight = PhCopy.elevated
                recommendation = PhCopy.elevatedSignpost
            }
        }

        return PhInsights(
            hasReadings: true,
            currentValue: latest.phValue,
            currentStatus: status,
            trend: trend,
            avg7: avg7,
            avg30: avg30,
            insight: insight,
            recommendation: recommendation
        )
    }
}
