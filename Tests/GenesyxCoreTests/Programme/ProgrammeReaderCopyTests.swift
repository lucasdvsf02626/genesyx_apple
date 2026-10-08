import XCTest
@testable import GenesyxCore

/// The words around the day reader and the Programme Guide.
final class ProgrammeReaderCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(ProgrammeReaderCopy.allSurfaces.count, 22, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: ProgrammeReaderCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "ProgrammeReaderCopy.swift", surfaces: ProgrammeReaderCopy.allSurfaces), [])
    }

    func testTheBriefsExactStringsArePresent() {
        XCTAssertEqual(ProgrammeReaderCopy.todaysFocus, "Today's focus")
        XCTAssertEqual(ProgrammeReaderCopy.whyThisMatters, "Why this matters")
        XCTAssertEqual(ProgrammeReaderCopy.todaysActions, "Today's actions")
        XCTAssertEqual(ProgrammeReaderCopy.learnMore, "Learn more")
        XCTAssertEqual(ProgrammeReaderCopy.yourProgress, "Your progress")
        XCTAssertEqual(ProgrammeReaderCopy.optionalReflection, "Optional reflection")
        XCTAssertEqual(ProgrammeReaderCopy.previousDay, "Previous day")
        XCTAssertEqual(ProgrammeReaderCopy.nextDay, "Next day")
        XCTAssertEqual(ProgrammeReaderCopy.openTodaysLog, "Open today's log")
        XCTAssertEqual(ProgrammeReaderCopy.openThisDaysLog, "Open this day's log")
        XCTAssertEqual(ProgrammeReaderCopy.notStarted, "Your programme has not started yet.")
        XCTAssertEqual(ProgrammeReaderCopy.guideIntro, "Thirty short sections. Read them in any order.")
        XCTAssertEqual(ProgrammeReaderCopy.relatedHeading, "Related reading")
    }

    func testEveryDestinationButTheLessonHasALabel() {
        for destination in ProgrammeDestination.allCases {
            let label = ProgrammeReaderCopy.callToActionLabel(for: destination)
            if destination == .programmeLesson {
                XCTAssertNil(label, "she is already on the lesson")
            } else {
                XCTAssertFalse((label ?? "").isEmpty, "no label for \(destination)")
                XCTAssertTrue(ProgrammeReaderCopy.allSurfaces.contains(label ?? ""), "\(destination) is not registered")
            }
        }
        XCTAssertEqual(ProgrammeReaderCopy.callToActionLabel(for: .cycle), "Open your calendar")
        XCTAssertEqual(ProgrammeReaderCopy.callToActionLabel(for: .weeklyReview), "Open your Programme Reviews")
        XCTAssertEqual(ProgrammeReaderCopy.callToActionLabel(for: .fertilityKitGuide), "Open the Programme Guide")
    }
}
