import XCTest
@testable import GenesyxCore

final class FertilityKitHomeCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(FertilityKitHomeCopy.allSurfaces.count, 20, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: FertilityKitHomeCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "FertilityKitHomeCopy.swift", surfaces: FertilityKitHomeCopy.allSurfaces), [])
    }

    func testTheBriefsExactStringsArePresent() {
        XCTAssertEqual(FertilityKitHomeCopy.openToday, "Open today's lesson")
        XCTAssertEqual(FertilityKitHomeCopy.thisWeeksFocus, "This week's focus")
        XCTAssertEqual(FertilityKitHomeCopy.weeklyToDo, "This week: to do")
        XCTAssertEqual(FertilityKitHomeCopy.weeklyDone, "This week: done")
        XCTAssertEqual(FertilityKitHomeCopy.notStartedBody,
                       "Start your 90-Day Programme when you are ready. Everything else in your kit is available now.")
        XCTAssertEqual(FertilityKitHomeCopy.scheduledBody,
                       "Your Programme Guide, Your Diet Plan and My Fertility Picture are available now.")
        XCTAssertEqual(FertilityKitHomeCopy.completedBody,
                       "Your 90 days are complete. Everything in your Fertility Kit stays available to you.")
        XCTAssertEqual(FertilityKitHomeCopy.stoppedBody, "Everything else in your Fertility Kit stays available.")
        XCTAssertEqual(FertilityKitHomeCopy.programmeDays, "Programme days")
        XCTAssertEqual(FertilityKitHomeCopy.dailyLogDetail, "Record today")
    }
}
