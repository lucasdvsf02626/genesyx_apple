import XCTest
@testable import GenesyxCore

/// Exercises the `CalendarDate` / `YearMonth` value types that back the cycle engine.
final class CalendarDateTests: XCTestCase {

    func testComponentsRoundTrip() {
        let d = CalendarDate(2026, 6, 1)
        XCTAssertEqual(d.year, 2026)
        XCTAssertEqual(d.month, 6)
        XCTAssertEqual(d.day, 1)
        // dayNumber -> components -> dayNumber is stable
        XCTAssertEqual(CalendarDate(dayNumber: d.dayNumber).year, 2026)
    }

    func testPlusMinusDaysAndDaysBetween() {
        let d = CalendarDate(2026, 6, 1)
        XCTAssertEqual(d.plusDays(28), CalendarDate(2026, 6, 29))
        XCTAssertEqual(d.minusDays(1), CalendarDate(2026, 5, 31))
        XCTAssertEqual(CycleEngine.daysBetween(d, d.plusDays(40)), 40)
        XCTAssertEqual(CycleEngine.daysBetween(d, d.minusDays(3)), -3)
    }

    func testWeekdaySundayZeroMatchesKnownDates() {
        // 1970-01-01 was a Thursday (=4 with Sunday==0).
        XCTAssertEqual(CalendarDate(1970, 1, 1).weekdaySundayZero, 4)
        // 2026-06-01 is a Monday (=1).
        XCTAssertEqual(CalendarDate(2026, 6, 1).weekdaySundayZero, 1)
    }

    func testComparableAndAcrossMonthBoundary() {
        XCTAssertTrue(CalendarDate(2026, 1, 31) < CalendarDate(2026, 2, 1))
        XCTAssertEqual(CalendarDate(2026, 1, 31).plusDays(1), CalendarDate(2026, 2, 1))
    }

    func testYearMonthLengthAndLeapYear() {
        XCTAssertEqual(YearMonth(2026, 2).lengthOfMonth, 28)
        XCTAssertEqual(YearMonth(2028, 2).lengthOfMonth, 29) // leap
        XCTAssertEqual(YearMonth(2026, 4).lengthOfMonth, 30)
        XCTAssertEqual(YearMonth(2026, 12).lengthOfMonth, 31)
        XCTAssertEqual(YearMonth(2026, 6).atDay(15), CalendarDate(2026, 6, 15))
    }

    func testCodableRoundTrip() throws {
        let settings = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 30, periodLength: 4)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CycleSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }
}
