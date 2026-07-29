import XCTest
@testable import GenesyxCore

/// Display-layer hydration unit conversion (glasses primary, ml secondary). Storage is unaffected.
final class HydrationUnitTests: XCTestCase {

    func testGlassConstantIs250() {
        XCTAssertEqual(HydrationUnit.mlPerGlass, 250)
    }

    func testAmountInMl() {
        XCTAssertEqual(HydrationFormat.amount(ml: 500, unit: .milliliters), "500 ml")
        XCTAssertEqual(HydrationFormat.amount(ml: 0, unit: .milliliters), "0 ml")
    }

    func testAmountInGlassesWholeAndFractionalAndSingular() {
        XCTAssertEqual(HydrationFormat.amount(ml: 500, unit: .glasses), "2 glasses")
        XCTAssertEqual(HydrationFormat.amount(ml: 250, unit: .glasses), "1 glass")   // singular
        XCTAssertEqual(HydrationFormat.amount(ml: 375, unit: .glasses), "1.5 glasses")
        XCTAssertEqual(HydrationFormat.amount(ml: 0, unit: .glasses), "0 glasses")
    }

    func testProgressReadout() {
        XCTAssertEqual(HydrationFormat.progress(ml: 500, goalMl: 2400, unit: .milliliters), "500 / 2400 ml")
        XCTAssertEqual(HydrationFormat.progress(ml: 500, goalMl: 2500, unit: .glasses), "2 / 10 glasses")
    }

    func testGoal2400IsNinetySixGlasses() {
        XCTAssertEqual(HydrationFormat.glasses(fromMl: 2400), 9.6, accuracy: 1e-9)
        XCTAssertEqual(HydrationFormat.progress(ml: 0, goalMl: 2400, unit: .glasses), "0 / 9.6 glasses")
    }
}
