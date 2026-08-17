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

    /// The predicted peak day, asked of the day itself rather than of the phase.
    ///
    /// `phase` cannot answer it: on a short cycle — 21/7, 22/8, 23/9 and 24/10 are all selectable in
    /// the settings sheet — ovulation falls inside the period, and `phase` says `.period` because she
    /// is still bleeding. Any surface that keyed peak-day copy off `phase == .ovulatory` therefore
    /// went quiet on exactly the cycles where the prediction is hardest to work out unaided.
    public var isOvulationDay: Bool { dayOfCycle == ovulationDay }

    /// In the fertile window on a day that is not the peak itself — the "chances are rising" case,
    /// as distinct from "today". Derived here so no screen has to re-derive it and get it wrong.
    public var isFertileButNotPeak: Bool { fertileWindow.contains(dayOfCycle) && !isOvulationDay }

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
///
/// `info` is nil when she has not set her cycle up. A day still exists without a phase prediction —
/// it can be tapped, logged and marked — and requiring one meant the grid could not be drawn at all
/// until she supplied a period date, which left no way to record anything on any past day.
public enum CalendarCell: Hashable, Sendable {
    case empty
    case day(date: CalendarDate, info: CyclePhaseInfo?, isToday: Bool)
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
