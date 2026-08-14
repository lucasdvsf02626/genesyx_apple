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

    /// The state the editor could not previously reach, and the reason the fabrication happened:
    /// showing the picker required giving it a date, so "she opened the picker" and "she chose a
    /// date" were the same event, and the second one silently meant today.
    func testOpeningThePickerIsNotChoosingADate() {
        XCTAssertTrue(CycleSetup.showsDatePicker(lastPeriod: nil, isPicking: true),
                      "asking for the picker shows it")
        XCTAssertFalse(CycleSetup.canSave(lastPeriod: nil),
                       "but nothing has been chosen yet, so Save stays disabled")
    }

    func testPickerIsHiddenUntilAskedForAndAlwaysShownOnceADateExists() {
        XCTAssertFalse(CycleSetup.showsDatePicker(lastPeriod: nil, isPicking: false),
                       "a new user sees the empty state, not a picker sitting on today")
        XCTAssertTrue(CycleSetup.showsDatePicker(lastPeriod: CalendarDate(2026, 7, 1), isPicking: false),
                      "an existing date is edited in the picker without asking for it")
    }
}
