import Foundation

/// Ovulation insight from the cycle engine. Ovulation is ESTIMATED (cycleLength − 14), so every
/// string is framed as "predicted" — never confirmed.
public struct OvulationInsights: Equatable, Sendable {
    public let cycleDay: Int
    public let ovulationDay: Int
    public let fertileWindow: FertileWindow
    public let phase: Phase
    public let daysUntilOvulation: Int?   // nil once ovulation has passed this cycle
    public let insight: String

    public init(cycleDay: Int, ovulationDay: Int, fertileWindow: FertileWindow, phase: Phase, daysUntilOvulation: Int?, insight: String) {
        self.cycleDay = cycleDay
        self.ovulationDay = ovulationDay
        self.fertileWindow = fertileWindow
        self.phase = phase
        self.daysUntilOvulation = daysUntilOvulation
        self.insight = insight
    }
}

public enum OvulationLogic {
    /// Returns nil when no cycle is set (card shows an empty state).
    public static func compute(settings: CycleSettings?, today: CalendarDate = .today()) -> OvulationInsights? {
        guard let settings else { return nil }
        let info = CycleEngine.cyclePhase(settings: settings, target: today)
        let untilOvulation = info.ovulationDay - info.dayOfCycle
        let daysUntil: Int? = untilOvulation > 0 ? untilOvulation : nil
        let window = info.fertileWindow

        let insight: String
        if window.contains(info.dayOfCycle) {
            insight = "You're in your predicted fertile window (days \(window.startDay)–\(window.endDay)) — the most likely time to conceive."
        } else if untilOvulation > 0 {
            insight = "Ovulation is predicted around day \(info.ovulationDay) — \(untilOvulation) day\(untilOvulation == 1 ? "" : "s") away."
        } else if info.phase == .period {
            insight = "You're on your period. Ovulation is predicted around day \(info.ovulationDay)."
        } else {
            insight = "Ovulation was predicted around day \(info.ovulationDay). You're in the luteal phase now."
        }

        return OvulationInsights(
            cycleDay: info.dayOfCycle,
            ovulationDay: info.ovulationDay,
            fertileWindow: window,
            phase: info.phase,
            daysUntilOvulation: daysUntil,
            insight: insight
        )
    }
}
