// CycleSetupTests.swift
// The empty-date contract for the "Your cycle" editor: a new user never gets a fabricated
// date, and Save is gated on a real choice. Existing settings prefill and are saveable.

import XCTest
@testable import GenesyxCore

final class CycleSetupTests: XCTestCase {

    func testNewUserStartsWithNoLastPeriod() {
        XCTAssertNil(CycleSetup.initialLastPeriod(from: nil),
                     "a new user must not have a last-period date fabricated for them")
    }

    func testExistingSettingsPrefillTheSavedDate() {
        let saved = CycleSettings(lastPeriodDate: CalendarDate(2026, 7, 1),
                                  cycleLength: 28, periodLength: 5)
        XCTAssertEqual(CycleSetup.initialLastPeriod(from: saved), CalendarDate(2026, 7, 1))
    }

    func testSaveDisabledUntilADateIsChosen() {
        XCTAssertFalse(CycleSetup.canSave(lastPeriod: nil))
        XCTAssertTrue(CycleSetup.canSave(lastPeriod: CalendarDate(2026, 7, 1)))
    }
}
