import Foundation

/// The "is hydration okay today?" read, for the Home summary chip and the Track header.
///
/// Owns ONLY: pacing maths, the status `title`, its `tone`, and week-context passthrough.
/// Every `focusLine` is `HydrationCoach.coachLine(hour:pct:)` VERBATIM — this type writes no
/// focus copy of its own. Pure: `hour` is injected, never read from `Date()` here.
public struct HydrationStatus: Equatable, Sendable {

    /// Deliberately has NO negative/warning case — "A little behind" and "Winding down" are
    /// `.neutral`, never a red/alarm colour. The UI maps `.neutral`→muted, `.positive`→accent.
    public enum Tone: Sendable, Equatable { case neutral, positive }

    public let title: String
    public let tone: Tone
    /// The time-of-day focus sentence — always straight from `HydrationCoach`.
    public let focusLine: String
    public let daysOnGoal: Int
    public let streak: Int

    public init(title: String, tone: Tone, focusLine: String, daysOnGoal: Int, streak: Int) {
        self.title = title
        self.tone = tone
        self.focusLine = focusLine
        self.daysOnGoal = daysOnGoal
        self.streak = streak
    }
}

public enum HydrationStatusEvaluator {

    /// Expected fraction of the daily goal by this hour — a gentle ramp from 08:00 to 21:00,
    /// clamped to 0…1. Before 08:00 the day hasn't really started (0); by 21:00 the full goal is
    /// "on pace" (1). Pure and hour-injected so pacing is unit-testable without a clock.
    public static func expectedPace(hour: Int) -> Double {
        let start = 8.0, end = 21.0
        if Double(hour) <= start { return 0 }
        if Double(hour) >= end { return 1 }
        return min(max((Double(hour) - start) / (end - start), 0), 1)
    }

    /// Evaluate today's hydration into a chip title + tone, carrying the week context through.
    /// `focusLine` is `HydrationCoach.coachLine` verbatim for the same `hour`/`pct`.
    public static func evaluate(todayMl: Int, goalMl: Int = 2400, hour: Int,
                                daysOnGoal: Int, streak: Int) -> HydrationStatus {
        let pct = goalMl > 0 ? Double(todayMl) / Double(goalMl) : 0
        let expected = expectedPace(hour: hour)

        let title: String
        let tone: HydrationStatus.Tone
        if todayMl >= Int(Double(goalMl) * 1.25) {
            title = "Hydration looks great"; tone = .positive
        } else if todayMl >= goalMl {
            title = "Target reached"; tone = .positive
        } else if hour >= 20 {
            // Late and under goal: the evening reminder owns re-engagement, so the chip stays
            // neutral and calm — never "behind" (O3: the UI must not double-nag).
            title = "Winding down"; tone = .neutral
        } else if todayMl == 0 && hour < 10 {
            title = "A fresh start"; tone = .neutral
        } else if pct >= expected {
            title = "On track"; tone = .positive
        } else {
            title = "A little behind"; tone = .neutral   // neutral tone — never a warning colour
        }

        return HydrationStatus(
            title: title,
            tone: tone,
            focusLine: HydrationCoach.coachLine(hour: hour, pct: pct),
            daysOnGoal: daysOnGoal,
            streak: streak)
    }
}
