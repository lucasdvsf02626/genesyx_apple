import XCTest
@testable import GenesyxCore

/// Display-layer hydration unit conversion (glasses primary, ml secondary). Storage is unaffected.
final class HydrationUnitTests: XCTestCase {

    func testUnitConstants() {
        XCTAssertEqual(HydrationUnit.mlPerGlass, 250)
        XCTAssertEqual(HydrationUnit.mlPerCup, 240)
        XCTAssertEqual(HydrationUnit.allCases, [.milliliters, .glasses, .cups])
        XCTAssertNil(HydrationUnit.milliliters.mlPerUnit())
        XCTAssertEqual(HydrationUnit.glasses.mlPerUnit(), 250)
        XCTAssertEqual(HydrationUnit.cups.mlPerUnit(), 240)
        XCTAssertEqual(HydrationUnit.cups.settingsLabel, "Cups")
    }

    func testCupsAmountAndProgress() {
        XCTAssertEqual(HydrationFormat.amount(ml: 240, unit: .cups), "1 cup")
        XCTAssertEqual(HydrationFormat.amount(ml: 480, unit: .cups), "2 cups")
        XCTAssertEqual(HydrationFormat.progress(ml: 480, goalMl: 2400, unit: .cups), "2 / 10 cups")
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

    // MARK: - T23 · a glass she sizes herself

    /// Absent or nonsense sizes fall back to 250 ml rather than being clamped to the nearest bound,
    /// so a corrupted store shows the familiar default instead of a number she never picked.
    func testResolvedGlassMlFallsBackToTheDefault() {
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(nil), 250)
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(300), 300)
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(50), 50)      // lower bound, inclusive
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(1000), 1000)  // upper bound, inclusive
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(49), 250)
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(1001), 250)
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(0), 250)
        XCTAssertEqual(HydrationUnit.resolvedGlassMl(-300), 250)   // never divide by a negative
    }

    /// The whole point of T23: her 300 ml glass describes the same water as fewer glasses.
    func testCustomGlassSizeRescalesTheReadout() {
        XCTAssertEqual(HydrationFormat.amount(ml: 900, unit: .glasses, glassMl: 300), "3 glasses")
        XCTAssertEqual(HydrationFormat.amount(ml: 300, unit: .glasses, glassMl: 300), "1 glass")
        XCTAssertEqual(HydrationFormat.progress(ml: 900, goalMl: 2400, unit: .glasses, glassMl: 300),
                       "3 / 8 glasses")
        XCTAssertEqual(HydrationFormat.trimmedUnits(fromMl: 450, unit: .glasses, glassMl: 300), "1.5")
        XCTAssertEqual(HydrationFormat.glasses(fromMl: 900, glassMl: 300), 3, accuracy: 1e-9)
    }

    /// Only the glass is hers to size. A cup is a recipe measure and ml is the storage unit, so
    /// both must ignore the setting entirely — otherwise switching unit would silently rescale.
    func testOnlyGlassesHonoursTheCustomSize() {
        XCTAssertEqual(HydrationUnit.cups.mlPerUnit(glassMl: 300), 240)
        XCTAssertNil(HydrationUnit.milliliters.mlPerUnit(glassMl: 300))
        XCTAssertEqual(HydrationFormat.amount(ml: 480, unit: .cups, glassMl: 300), "2 cups")
        XCTAssertEqual(HydrationFormat.amount(ml: 500, unit: .milliliters, glassMl: 300), "500 ml")
    }

    /// An out-of-range size must not reach the divisor — a 0 ml glass would divide by zero.
    func testOutOfRangeSizeCannotBreakFormatting() {
        XCTAssertEqual(HydrationFormat.amount(ml: 500, unit: .glasses, glassMl: 0), "2 glasses")
        XCTAssertEqual(HydrationFormat.progress(ml: 500, goalMl: 2500, unit: .glasses, glassMl: -1),
                       "2 / 10 glasses")
    }

    /// Omitting `glassMl` anywhere must read exactly as it did before T23.
    func testDefaultArgumentPreservesPreT23Behaviour() {
        XCTAssertEqual(HydrationFormat.amount(ml: 500, unit: .glasses),
                       HydrationFormat.amount(ml: 500, unit: .glasses, glassMl: 250))
        XCTAssertEqual(HydrationFormat.progress(ml: 500, goalMl: 2500, unit: .glasses),
                       HydrationFormat.progress(ml: 500, goalMl: 2500, unit: .glasses, glassMl: 250))
    }
}
