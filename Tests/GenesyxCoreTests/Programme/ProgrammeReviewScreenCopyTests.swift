import XCTest
@testable import GenesyxCore

/// The wording of the Programme Reviews list and the two review screens.
final class ProgrammeReviewScreenCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(ProgrammeReviewScreenCopy.allSurfaces.count, 13, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: ProgrammeReviewScreenCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "ProgrammeReviewScreenCopy.swift", surfaces: ProgrammeReviewScreenCopy.allSurfaces), [])
    }

    func testTheBriefsExactStringsArePresent() {
        XCTAssertEqual(ProgrammeReviewScreenCopy.consistencySoFar, "Programme so far")
        XCTAssertEqual(ProgrammeReviewScreenCopy.lastThirtyDays, "Last 30 days")
        XCTAssertEqual(ProgrammeReviewScreenCopy.byActivity, "By activity")
        XCTAssertEqual(ProgrammeReviewScreenCopy.weeklyHeading, "Weekly reviews")
        XCTAssertEqual(ProgrammeReviewScreenCopy.weekRow(3), "Week 3")
        XCTAssertEqual(ProgrammeReviewScreenCopy.nextReviewReady(3, "20 October"),
                       "Your Week 3 review will be ready on 20 October.")
        XCTAssertEqual(ProgrammeReviewScreenCopy.nextReviewReadyTomorrow(3), "Your Week 3 review will be ready tomorrow.")
        XCTAssertEqual(ProgrammeReviewScreenCopy.ninetyDayReady("4 January"),
                       "Your 90-Day Review will be ready on 4 January.")
        XCTAssertEqual(ProgrammeReviewScreenCopy.noReviewsYet,
                       "Your first weekly review will be ready after your first programme week.")
        XCTAssertEqual(ProgrammeReviewScreenCopy.notStarted, "Reviews begin once your programme has started.")
        XCTAssertEqual(ProgrammeReviewScreenCopy.notAvailable, "This review is not available yet.")
        XCTAssertEqual(ProgrammeReviewScreenCopy.openPicture, "Open My Fertility Picture")
    }
}
