import Foundation

/// Pure cycle math, ported verbatim from the Android `CycleEngine.kt`
/// (itself a port of web `src/lib/cycle.ts` + `src/lib/cycleEngine.ts`).
/// See docs/CYCLE_ENGINE.md. All dates are local (no UTC).
public enum CycleEngine {

    public static let defaultCycleLength = 28
    public static let defaultPeriodLength = 5
    public static let cycleLengthRange = 21...35
    public static let periodLengthRange = 1...10

    /// Whole-day difference (target - origin).
    public static func daysBetween(_ origin: CalendarDate, _ target: CalendarDate) -> Int {
        target.dayNumber - origin.dayNumber
    }

    /// Derived cycle state for `target`.
    /// `dayOfCycle` is 1-based and handles dates before the last period (negative diff).
    public static func cyclePhase(
        lastPeriodDate: CalendarDate,
        cycleLength: Int,
        periodLength: Int,
        target: CalendarDate = .today()
    ) -> CyclePhaseInfo {
        let diff = daysBetween(lastPeriodDate, target)
        let dayOfCycle = diff.mod(cycleLength) + 1
        let ovulationDay = cycleLength - 14 // luteal phase fixed at 14 days
        let fertileWindow = FertileWindow(startDay: ovulationDay - 5, endDay: ovulationDay + 1)

        let phase: Phase
        if dayOfCycle <= periodLength {
            phase = .period
        } else if dayOfCycle == ovulationDay {
            phase = .ovulatory
        } else if dayOfCycle < ovulationDay {
            phase = .follicular
        } else {
            phase = .luteal
        }

        // Matches web cycle.ts: day 1 reports 0 (period just started).
        let daysUntilNextPeriod = dayOfCycle == 1 ? 0 : cycleLength - dayOfCycle

        return CyclePhaseInfo(
            dayOfCycle: dayOfCycle,
            phase: phase,
            fertileWindow: fertileWindow,
            ovulationDay: ovulationDay,
            daysUntilNextPeriod: daysUntilNextPeriod
        )
    }

    public static func cyclePhase(
        settings: CycleSettings,
        target: CalendarDate = .today()
    ) -> CyclePhaseInfo {
        cyclePhase(
            lastPeriodDate: settings.lastPeriodDate,
            cycleLength: settings.cycleLength,
            periodLength: settings.periodLength,
            target: target
        )
    }

    /// Calendar day classification. Order matches web cycle.ts: period > ovulation > fertile > luteal.
    public static func dayType(for info: CyclePhaseInfo) -> DayType {
        if info.phase == .period {
            return .period
        } else if info.dayOfCycle == info.ovulationDay {
            return .ovulation
        } else if info.fertileWindow.contains(info.dayOfCycle) {
            return .fertile
        } else if info.phase == .luteal {
            return .luteal
        } else {
            return .follicular
        }
    }

    /// 1-based cycle number for `target`. Dates before the last period clamp to cycle 1 (web parity).
    public static func cycleNumber(
        lastPeriodDate: CalendarDate,
        cycleLength: Int,
        target: CalendarDate = .today()
    ) -> Int {
        max(daysBetween(lastPeriodDate, target), 0) / cycleLength + 1
    }

    /// Sunday-first month grid with leading/trailing empty cells.
    public static func buildMonthGrid(
        monthAnchor: YearMonth,
        settings: CycleSettings,
        today: CalendarDate = .today()
    ) -> [CalendarCell] {
        let first = monthAnchor.atDay(1)
        let daysInMonth = monthAnchor.lengthOfMonth
        let leading = first.weekdaySundayZero // Sun=0 ... Sat=6

        var cells: [CalendarCell] = []
        cells.reserveCapacity(42)
        for _ in 0..<leading { cells.append(.empty) }
        for day in 1...daysInMonth {
            let date = monthAnchor.atDay(day)
            cells.append(
                .day(
                    date: date,
                    info: cyclePhase(settings: settings, target: date),
                    isToday: date == today
                )
            )
        }
        while cells.count % 7 != 0 { cells.append(.empty) }
        return cells
    }
}
