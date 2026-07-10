import Foundation

/// Cycle-regularity insight derived from the CURRENT cycle settings only (we don't store
/// per-cycle history), so it's honest about being a single-cycle view against the typical range.
public struct CycleRegularityInsights: Equatable, Sendable {
    public let cycleLength: Int
    public let inTypicalRange: Bool     // 21...35
    public let insight: String

    public init(cycleLength: Int, inTypicalRange: Bool, insight: String) {
        self.cycleLength = cycleLength
        self.inTypicalRange = inTypicalRange
        self.insight = insight
    }
}

public enum CycleRegularityLogic {
    /// Returns nil when no cycle is set (card shows an empty state).
    public static func compute(settings: CycleSettings?) -> CycleRegularityInsights? {
        guard let settings else { return nil }
        let length = settings.cycleLength
        let inRange = (21...35).contains(length)
        let insight = inRange
            ? "Your cycle length of \(length) days sits within the typical 21–35 day range."
            : "Your cycle length of \(length) days is outside the typical range — worth mentioning to a clinician if it persists."
        return CycleRegularityInsights(cycleLength: length, inTypicalRange: inRange, insight: insight)
    }
}
