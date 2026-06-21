import Foundation

/// Cycle phase. Mirrors `Phase` in web `src/lib/cycle.ts` and the Android `Phase` enum.
public enum Phase: String, CaseIterable, Sendable {
    case period, follicular, ovulatory, luteal
}

/// Calendar day classification (Phase + fertile/ovulation overlays).
public enum DayType: String, Sendable {
    case period, follicular, fertile, ovulation, luteal
}

/// Inclusive day-of-cycle range for the fertile window.
public struct FertileWindow: Hashable, Sendable {
    public let startDay: Int
    public let endDay: Int

    public init(startDay: Int, endDay: Int) {
        self.startDay = startDay
        self.endDay = endDay
    }

    /// Mirrors Kotlin's `operator fun contains`: `dayOfCycle in fertileWindow`.
    public func contains(_ dayOfCycle: Int) -> Bool {
        (startDay...endDay).contains(dayOfCycle)
    }
}

/// Derived cycle state for a target date.
public struct CyclePhaseInfo: Hashable, Sendable {
    public let dayOfCycle: Int
    public let phase: Phase
    public let fertileWindow: FertileWindow
    public let ovulationDay: Int
    public let daysUntilNextPeriod: Int

    public init(
        dayOfCycle: Int,
        phase: Phase,
        fertileWindow: FertileWindow,
        ovulationDay: Int,
        daysUntilNextPeriod: Int
    ) {
        self.dayOfCycle = dayOfCycle
        self.phase = phase
        self.fertileWindow = fertileWindow
        self.ovulationDay = ovulationDay
        self.daysUntilNextPeriod = daysUntilNextPeriod
    }
}

/// A single calendar cell in the month grid (Kotlin sealed interface `CalendarCell`).
public enum CalendarCell: Hashable, Sendable {
    case empty
    case day(date: CalendarDate, info: CyclePhaseInfo, isToday: Bool)
}

/// User cycle configuration (`cycle_settings`).
public struct CycleSettings: Hashable, Codable, Sendable {
    public let lastPeriodDate: CalendarDate
    public let cycleLength: Int
    public let periodLength: Int

    public init(lastPeriodDate: CalendarDate, cycleLength: Int = 28, periodLength: Int = 5) {
        self.lastPeriodDate = lastPeriodDate
        self.cycleLength = cycleLength
        self.periodLength = periodLength
    }
}
