import XCTest
@testable import GenesyxCore

/// What earns a dot on the month grid. The rule is deliberately narrower than "she logged
/// something": water, mood, energy, sleep and supplements are all deliberately unmarked, because a
/// grid where most days carry most dots marks nothing at all.
final class DayMarkersTests: XCTestCase {

    private func markers(_ log: DailyLog, ph: Bool = false) -> [DayMarker] {
        DayMarkers.markers(log: log, hasPhReading: ph)
    }

    func testAnEmptyDayIsUnmarked() {
        XCTAssertEqual(markers(DailyLog()), [])
    }

    func testEachMarkerStandsOnItsOwn() {
        XCTAssertEqual(markers(DailyLog(), ph: true), [.ph])
        XCTAssertEqual(markers(DailyLog(symptoms: ["Cramps"])), [.symptoms])
        XCTAssertEqual(markers(DailyLog(sexualActivity: true)), [.intimacy])
    }

    /// A day she described in free text but tagged with no chips is still a day she described.
    func testANoteAloneEarnsTheSymptomsMarker() {
        XCTAssertEqual(markers(DailyLog(notes: "rough afternoon")), [.symptoms])
        XCTAssertEqual(markers(DailyLog(notes: "")), [])
    }

    /// The dots are for what she recorded about the day, not for how much of the routine she hit.
    /// Water, sleep and supplements have their own cards; marking them here would leave nearly
    /// every day dotted and the sparse markers unfindable among them.
    func testTheRoutineFieldsAreNotMarked() {
        XCTAssertEqual(markers(DailyLog(mood: .good, energy: .high, sleepMinutes: 420,
                                        supplements: ["Iron"], waterMl: 2000)), [])
    }

    /// Order is fixed so a marker never shifts position because a neighbour is absent — that
    /// stability is what lets her scan a column down the month.
    func testOrderIsStableRegardlessOfWhichAreAbsent() {
        let all = markers(DailyLog(symptoms: ["Cramps"], sexualActivity: true), ph: true)
        XCTAssertEqual(all, [.ph, .symptoms, .intimacy])
        XCTAssertEqual(markers(DailyLog(sexualActivity: true), ph: true), [.ph, .intimacy])
    }
}
