import XCTest
@testable import GenesyxCore

/// The words My Fertility Picture adds around core's own.
final class FertilityPictureScreenCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(FertilityPictureScreenCopy.allSurfaces.count, 2, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: FertilityPictureScreenCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "FertilityPictureScreenCopy.swift", surfaces: FertilityPictureScreenCopy.allSurfaces), [])
    }

    func testTheBriefsExactStringsArePresent() {
        XCTAssertEqual(FertilityPictureScreenCopy.intro,
                       "A summary of what you have recorded. It reflects your own records and is not medical advice.")
        XCTAssertEqual(FertilityPictureScreenCopy.empty, "Nothing to show yet. Your picture fills in as you record.")
    }

    func testARowsLinesAreItsPartsInReadingOrder() {
        let day = CalendarDate(2026, 10, 6)
        let full = FertilityPictureRow(.latestPhReading, label: "Latest pH", value: "4.2", detail: "Healthy",
                                       date: day, destination: .programme(.phTest))
        XCTAssertEqual(FertilityPictureScreenCopy.rowLines(for: full), ["Latest pH", "4.2", "Healthy", "6 October"])
        let window = FertilityPictureRow(.estimatedFertileWindow, label: "Window",
                                         dateRange: day...day.plusDays(6), destination: .programme(.cycle))
        XCTAssertEqual(FertilityPictureScreenCopy.rowLines(for: window), ["Window", "6 October to 12 October"])
        let bare = FertilityPictureRow(.pattern, label: "Label", destination: .programme(.cycle))
        XCTAssertEqual(FertilityPictureScreenCopy.rowLines(for: bare), ["Label"])
    }
}
