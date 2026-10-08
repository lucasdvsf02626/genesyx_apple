import XCTest
@testable import GenesyxCore

/// The registry of the Your Diet Plan screen: the three standard checks, and the Diet Plan's own
/// bans applied to its words and to the source of this file.
final class YourDietPlanScreenCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(YourDietPlanScreenCopy.allSurfaces.count, 20, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: YourDietPlanScreenCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "YourDietPlanScreenCopy.swift", surfaces: YourDietPlanScreenCopy.allSurfaces), [])
    }

    func testTheExactStringsArePresent() {
        typealias C = YourDietPlanScreenCopy
        XCTAssertEqual(C.todayTitle, "Today's nutrition")
        XCTAssertEqual(C.focusTitle, "This week's nutrition focus")
        XCTAssertEqual(C.foodGuideTitle, "Food guide")
        XCTAssertEqual(C.mealsTitle, "Meal inspiration")
        XCTAssertEqual(C.historyTitle, "Your nutrition history")
        XCTAssertEqual(C.connectionTitle, "Programme connection")
        XCTAssertEqual(C.todayEmpty, "No food groups recorded today.")
        XCTAssertEqual(C.track, "Record today's food groups")
        XCTAssertEqual(C.mealContains(["Vegetables", "Protein"]), "Contains: Vegetables, Protein")
        XCTAssertEqual(C.groupList(["Vegetables", "Fruit"]), "Vegetables, Fruit")
        XCTAssertEqual(C.checkInDays(4, of: 7), "Nutrition check-in on 4 of 7 days")
        XCTAssertEqual(C.groupDays("Vegetables", 3), "Vegetables recorded on 3 days")
        XCTAssertEqual(C.groupDays("Fruit", 1), "Fruit recorded on 1 day")
        XCTAssertEqual(C.historyEmpty, "Nothing recorded in this period.")
        XCTAssertEqual(C.connectionWeek(4), "You are in week 4 of your 90-Day Programme.")
        XCTAssertEqual(C.openToday, "Open Today's Programme")
    }

    // MARK: The Diet Plan's own bans

    private let neverInCopy = ["score", "percent", "%", "grade", "rating", "quality", "rank", "best", "worst",
                               "missing"]
    private let noTargets = ["all six", "at least", "aim for", "eat more", "eat less", "every day", "avoid", "limit",
                             "not enough", "healthier"]

    private func hits(in text: String) -> [String] {
        let lower = text.lowercased()
        return (neverInCopy + noTargets).filter { lower.contains($0) }
    }

    func testTheRegistryHoldsNothingAMarkOrATargetIsBuiltFrom() {
        for surface in YourDietPlanScreenCopy.allSurfaces {
            XCTAssertEqual(hits(in: surface), [], surface)
        }
    }

    func testTheRegistrySourceHoldsNoMarkAndNoPromiseOfItsOwn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(
            "Sources/GenesyxCore/Programme/YourDietPlanScreenCopy.swift"), encoding: .utf8)
        let code = FertilityKitCopyGuard.withoutComments(text)
        XCTAssertEqual(neverInCopy.filter { code.lowercased().contains($0) }, [])
        XCTAssertFalse(code.contains("A record, not a target"), "the promise is read from the tracker, never typed")
    }

    func testTheMarkGuardCanFail() {
        for bad in ["Your score today", "40% of days", "A grade for the week", "A rating", "Quality of your diet",
                    "Your best week", "A missing group", "Eat more greens", "At least three groups", "Avoid sugar"] {
            XCTAssertFalse(hits(in: bad).isEmpty, "the guard let through: \(bad)")
        }
        XCTAssertEqual(hits(in: "Vegetables recorded on 3 days"), [])
    }

    func testTheCountsReadNaturally() {
        XCTAssertEqual(YourDietPlanScreenCopy.groupDays("Protein", 0), "Protein recorded on 0 days")
        XCTAssertEqual(YourDietPlanScreenCopy.checkInDays(1, of: 1), "Nutrition check-in on 1 of 1 days")
    }
}
