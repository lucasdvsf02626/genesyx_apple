import XCTest
@testable import GenesyxCore

/// Covers `daysUntilFertileWindow`, which the fertile-window notification is scheduled from.
/// A 28-day cycle puts the window on days 9–15.
final class OvulationLogicTests: XCTestCase {

    private let lastPeriod = CalendarDate(2026, 6, 1)

    private func settings(cycleLength: Int = 28) -> CycleSettings {
        CycleSettings(lastPeriodDate: lastPeriod, cycleLength: cycleLength, periodLength: 5)
    }

    private func daysUntilWindow(onCycleDay day: Int, cycleLength: Int = 28) -> Int? {
        OvulationLogic.daysUntilFertileWindow(
            settings: settings(cycleLength: cycleLength),
            today: lastPeriod.plusDays(day - 1)
        )
    }

    func testCountsDownToTheWindowWithinTheCurrentCycle() {
        XCTAssertEqual(daysUntilWindow(onCycleDay: 1), 8)
        XCTAssertEqual(daysUntilWindow(onCycleDay: 8), 1)
    }

    func testReturnsZeroOnTheDayTheWindowOpens() {
        XCTAssertEqual(daysUntilWindow(onCycleDay: 9), 0)
    }

    /// Once this cycle's window has opened the answer is the *next* opening, never a date behind
    /// her — otherwise the notification would be scheduled into the past and silently dropped.
    func testWrapsToTheNextCycleOnceTheWindowHasOpened() {
        XCTAssertEqual(daysUntilWindow(onCycleDay: 10), 27)
        XCTAssertEqual(daysUntilWindow(onCycleDay: 15), 22, "still inside the window, but it has opened")
        XCTAssertEqual(daysUntilWindow(onCycleDay: 28), 9)
    }

    func testFollowsAShorterCycle() {
        // 24-day cycle → ovulation day 10, window opens day 5.
        XCTAssertEqual(daysUntilWindow(onCycleDay: 1, cycleLength: 24), 4)
        XCTAssertEqual(daysUntilWindow(onCycleDay: 5, cycleLength: 24), 0)
        XCTAssertEqual(daysUntilWindow(onCycleDay: 6, cycleLength: 24), 23)
    }

    func testNilWithoutACycle() {
        XCTAssertNil(OvulationLogic.daysUntilFertileWindow(settings: nil))
    }
}
