import XCTest
@testable import GenesyxCore

/// Validates the cycle engine against the web `cycle.ts` formulas (docs/CYCLE_ENGINE.md).
/// Ported verbatim from the Android `CycleEngineTest.kt` to guarantee cross-platform parity.
final class CycleEngineTests: XCTestCase {

    private let lastPeriod = CalendarDate(2026, 6, 1)
    private let cycleLength = 28
    private let periodLength = 5

    private func phaseOn(_ date: CalendarDate) -> CyclePhaseInfo {
        CycleEngine.cyclePhase(
            lastPeriodDate: lastPeriod,
            cycleLength: cycleLength,
            periodLength: periodLength,
            target: date
        )
    }

    func testDayOneIsPeriodDayOfCycleOne() {
        let info = phaseOn(lastPeriod)
        XCTAssertEqual(info.dayOfCycle, 1)
        XCTAssertEqual(info.phase, .period)
    }

    func testOvulationDayEqualsCycleLengthMinus14() {
        let ovDate = lastPeriod.plusDays(13) // day 14 for a 28-day cycle
        let info = phaseOn(ovDate)
        XCTAssertEqual(info.dayOfCycle, 14)
        XCTAssertEqual(info.ovulationDay, 14)
        XCTAssertEqual(info.phase, .ovulatory)
        XCTAssertEqual(CycleEngine.dayType(for: info), .ovulation)
    }

    func testFertileWindowSpansOvulationMinus5ToPlus1() {
        let info = phaseOn(lastPeriod)
        XCTAssertEqual(info.fertileWindow.startDay, 9)
        XCTAssertEqual(info.fertileWindow.endDay, 15)
        XCTAssertTrue(info.fertileWindow.contains(12))
        XCTAssertFalse(info.fertileWindow.contains(16))
    }

    func testFertileWindowIsInclusiveAtBothBoundaries() {
        let info = phaseOn(lastPeriod)
        XCTAssertTrue(info.fertileWindow.contains(9), "start day 9 is fertile")
        XCTAssertTrue(info.fertileWindow.contains(15), "end day 15 is fertile")
        XCTAssertFalse(info.fertileWindow.contains(8), "day 8 is not fertile")
        XCTAssertFalse(info.fertileWindow.contains(16), "day 16 is not fertile")
    }

    func testFollicularBeforeOvulationLutealAfter() {
        XCTAssertEqual(phaseOn(lastPeriod.plusDays(7)).phase, .follicular) // day 8
        XCTAssertEqual(phaseOn(lastPeriod.plusDays(20)).phase, .luteal) // day 21
    }

    func testDayOfCycleWrapsAndHandlesDatesBeforeLastPeriod() {
        // 28 days later = start of next cycle, day 1 again
        XCTAssertEqual(phaseOn(lastPeriod.plusDays(28)).dayOfCycle, 1)
        // one day before last period = last day of previous cycle (day 28)
        XCTAssertEqual(phaseOn(lastPeriod.minusDays(1)).dayOfCycle, 28)
    }

    func testFertileDayIsClassifiedAsFertileNotPhase() {
        let info = phaseOn(lastPeriod.plusDays(11)) // day 12, within [9,15], not ovulation
        XCTAssertEqual(CycleEngine.dayType(for: info), .fertile)
    }

    func testDaysUntilNextPeriodIsZeroOnDayOneAndCountsDownOtherwise() {
        // Matches web cycle.ts: day 1 reports 0.
        XCTAssertEqual(phaseOn(lastPeriod).daysUntilNextPeriod, 0)
        XCTAssertEqual(phaseOn(lastPeriod.plusDays(7)).daysUntilNextPeriod, 20) // day 8 -> 28-8
        XCTAssertEqual(phaseOn(lastPeriod.plusDays(26)).daysUntilNextPeriod, 1) // day 27 -> 28-27
    }

    func testPeriodTakesPrecedenceOverFertileOnShortCycle() {
        // 21-day cycle: ovulation = day 7, fertile window = [2, 8]; period = days 1-5.
        // Days 2-5 are both period and fertile — web cycle.ts classifies them as period.
        let shortLast = CalendarDate(2026, 6, 1)
        let day3 = CycleEngine.cyclePhase(
            lastPeriodDate: shortLast, cycleLength: 21, periodLength: 5,
            target: shortLast.plusDays(2)
        ) // day 3
        XCTAssertEqual(day3.phase, .period)
        XCTAssertTrue(day3.fertileWindow.contains(3))
        XCTAssertEqual(CycleEngine.dayType(for: day3), .period, "period wins over fertile")

        // Day 6 is fertile but no longer period -> fertile.
        let day6 = CycleEngine.cyclePhase(
            lastPeriodDate: shortLast, cycleLength: 21, periodLength: 5,
            target: shortLast.plusDays(5)
        )
        XCTAssertEqual(CycleEngine.dayType(for: day6), .fertile)
    }

    func testLutealDayAfterFertileWindowIsClassifiedLuteal() {
        let info = phaseOn(lastPeriod.plusDays(19)) // day 20, luteal, outside fertile
        XCTAssertEqual(info.phase, .luteal)
        XCTAssertEqual(CycleEngine.dayType(for: info), .luteal)
    }

    func testCycleNumberIncrementsOncePerFullCycle() {
        XCTAssertEqual(CycleEngine.cycleNumber(lastPeriodDate: lastPeriod, cycleLength: cycleLength, target: lastPeriod), 1)
        XCTAssertEqual(CycleEngine.cycleNumber(lastPeriodDate: lastPeriod, cycleLength: cycleLength, target: lastPeriod.plusDays(28)), 2)
        XCTAssertEqual(CycleEngine.cycleNumber(lastPeriodDate: lastPeriod, cycleLength: cycleLength, target: lastPeriod.plusDays(56)), 3)
        // Dates before the last period clamp to cycle 1.
        XCTAssertEqual(CycleEngine.cycleNumber(lastPeriodDate: lastPeriod, cycleLength: cycleLength, target: lastPeriod.minusDays(3)), 1)
    }

    func testMonthGridIsSundayFirstPaddedWithCorrectDayCountAndTodayFlag() {
        let settings = CycleSettings(lastPeriodDate: lastPeriod, cycleLength: cycleLength, periodLength: periodLength)
        let anchor = YearMonth(2026, 6) // June 2026: the 1st is a Monday
        let today = CalendarDate(2026, 6, 15)
        let cells = CycleEngine.buildMonthGrid(monthAnchor: anchor, settings: settings, today: today)

        XCTAssertEqual(cells.count % 7, 0, "grid is whole weeks")

        let dayCells: [(date: CalendarDate, info: CyclePhaseInfo, isToday: Bool)] = cells.compactMap {
            if case let .day(date, info, isToday) = $0 { return (date, info, isToday) }
            return nil
        }
        XCTAssertEqual(dayCells.count, 30, "30 day cells for June")

        // Monday -> one leading empty (Sunday-first).
        if case .empty = cells.first { } else { XCTFail("first cell should be empty") }
        XCTAssertEqual(cells.firstIndex(where: { if case .day = $0 { return true }; return false }), 1)

        XCTAssertEqual(dayCells.filter { $0.isToday }.count, 1)
        XCTAssertEqual(dayCells.first { $0.isToday }?.date, today)
    }
}
