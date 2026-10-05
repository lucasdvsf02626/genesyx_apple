import XCTest
@testable import GenesyxCore

final class LhResultTests: XCTestCase {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Midday UTC on the given day, so the calendar day is not in doubt.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private let settings = CycleSettings(lastPeriodDate: CalendarDate(2026, 10, 1), cycleLength: 28, periodLength: 5)

    // MARK: - Source

    func testAResultWithoutAMeasurementIsManual() {
        let result = LhResult(recordedAt: date(2026, 10, 5), classification: .positive)

        XCTAssertNil(result.scan)
        XCTAssertEqual(result.source, .manual)
        XCTAssertNil(result.cycleDay)
        XCTAssertFalse(result.id.isEmpty)
    }

    func testAResultWithAMeasurementIsACameraScan() {
        let measurement = LhScanMeasurement(testSignal: 0.06, controlSignal: 0.6, testControlRatio: 0.1,
                                            confidence: 0.95, scannerVersion: "0.1.0",
                                            configurationID: "t", configurationVersion: "1")
        let result = LhResult(id: "a", recordedAt: date(2026, 10, 5), cycleDay: 5, classification: .low,
                              scan: measurement)

        XCTAssertEqual(result.source, .cameraScan)
        XCTAssertEqual(result.scan, measurement)
        XCTAssertEqual(result.cycleDay, 5)
    }

    /// These strings are stored on the device and on the server.
    func testStoredRawValuesDoNotMove() {
        XCTAssertEqual(LhClassification.allCases.map(\.rawValue), ["low", "rising", "positive", "invalid", "unreadable"])
        XCTAssertEqual(LhResultSource.manual.rawValue, "manual")
        XCTAssertEqual(LhResultSource.cameraScan.rawValue, "cameraScan")
    }

    // MARK: - Cycle day snapshot

    func testNoCycleSettingsMeansNoCycleDay() {
        XCTAssertNil(LhCycleDay.snapshot(settings: nil, at: date(2026, 10, 5), calendar: utc))
    }

    func testTheLastPeriodDateIsDayOne() {
        XCTAssertEqual(LhCycleDay.snapshot(settings: settings, at: date(2026, 10, 1), calendar: utc), 1)
        XCTAssertEqual(LhCycleDay.snapshot(settings: settings, at: date(2026, 10, 12), calendar: utc), 12)
    }

    func testTheDayWrapsAfterTheCycleLength() {
        XCTAssertEqual(LhCycleDay.snapshot(settings: settings, at: date(2026, 10, 28), calendar: utc), 28)
        XCTAssertEqual(LhCycleDay.snapshot(settings: settings, at: date(2026, 10, 29), calendar: utc), 1)
    }

    func testADateBeforeTheLastPeriodIsStillOneBased() {
        XCTAssertEqual(LhCycleDay.snapshot(settings: settings, at: date(2026, 9, 30), calendar: utc), 28)
        XCTAssertEqual(LhCycleDay.snapshot(settings: settings, at: date(2026, 9, 3), calendar: utc), 1)
    }
}
