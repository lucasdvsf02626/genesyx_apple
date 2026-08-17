import XCTest
@testable import GenesyxCore

/// The tracker's Nutrition row and the Daily Log's supplement tick-list both drifted away from the
/// data they claim to summarise. These tests hold the two joins that fixed it: the row must see
/// food groups, and the tick-list must be the plan.
final class NutritionDaySignalTests: XCTestCase {

    // MARK: The row must see food groups

    /// The defect this type exists for. Six food groups and no supplements used to summarise as
    /// "No entries yet" on the one screen whose job is to show her what she recorded.
    func testADayOfFoodGroupsAloneIsNotAnEmptyDay() {
        let line = NutritionDaySignal.summaryLine(supplements: 0, foodGroups: 6)
        XCTAssertNotNil(line, "food groups alone still read as nothing logged")
        XCTAssertEqual(line, "6 of 6 food groups today")
        XCTAssertGreaterThan(NutritionDaySignal.fill(supplements: 0, foodGroups: 6), 0)
    }

    func testADayOfSupplementsAloneKeepsItsOwnWording() {
        XCTAssertEqual(NutritionDaySignal.summaryLine(supplements: 2, foodGroups: 0),
                       "2 of 4 supplements today")
    }

    func testADayWithBothNamesBoth() {
        let line = try! XCTUnwrap(NutritionDaySignal.summaryLine(supplements: 2, foodGroups: 3))
        XCTAssertTrue(line.contains("2 supplements"))
        XCTAssertTrue(line.contains("3 food groups"))
    }

    /// `nil` rather than a sentence, so the caller decides what an untouched day says.
    func testAnUntouchedDayReturnsNothingToSay() {
        XCTAssertNil(NutritionDaySignal.summaryLine(supplements: 0, foodGroups: 0))
        XCTAssertEqual(NutritionDaySignal.fill(supplements: 0, foodGroups: 0), 0)
    }

    /// Neither half is the more real entry, so neither may outweigh the other in the sparkline.
    func testNeitherHalfOutweighsTheOther() {
        XCTAssertEqual(NutritionDaySignal.fill(supplements: 4, foodGroups: 0),
                       NutritionDaySignal.fill(supplements: 0, foodGroups: 6))
        XCTAssertEqual(NutritionDaySignal.fill(supplements: 4, foodGroups: 6), 1)
    }

    func testFillNeverExceedsFull() {
        XCTAssertEqual(NutritionDaySignal.fill(supplements: 99, foodGroups: 99), 1)
    }

    // MARK: Counting against what is known, not what is stored

    /// A token from a newer build, or a supplement since dropped from the plan, must not push a
    /// count past its own denominator — the "7 of 6" the food-group card already guards against.
    func testUnknownTokensDoNotInflateEitherCount() {
        XCTAssertEqual(NutritionDaySignal.knownFoodGroups(["vegetables", "seaweed"]), 1)
        XCTAssertEqual(NutritionDaySignal.knownSupplements(["Vitamin D", "Iron"]), 1)
    }

    // MARK: The tick-list must be the plan

    /// Zinc was in her plan and absent from the tick-list, so it could never be logged and
    /// "4 of 4 taken today" was mathematically unreachable. Iron was in the tick-list and in no
    /// plan, so it counted toward one it was not part of.
    func testEveryPlanSupplementCanActuallyBeLogged() {
        XCTAssertEqual(NutritionContent.supplementLogOptions.count,
                       NutritionContent.supplementPlan.count)
        for item in NutritionContent.supplementPlan {
            XCTAssertTrue(NutritionContent.supplementLogOptions.contains(item.logLabel),
                          "\(item.name) is in the plan but cannot be ticked")
        }
        XCTAssertTrue(NutritionContent.supplementLogOptions.contains("Zinc"))
        XCTAssertFalse(NutritionContent.supplementLogOptions.contains("Iron"),
                       "Iron is in no plan on this screen; it must not count toward one")
    }

    /// A full plan must reach a full count — the arithmetic that was unreachable before.
    func testTickingTheWholePlanReadsAsComplete() {
        let all = Set(NutritionContent.supplementLogOptions)
        XCTAssertEqual(NutritionDaySignal.knownSupplements(all), NutritionConsistencyLogic.planSize)
        XCTAssertEqual(NutritionDaySignal.summaryLine(supplements: NutritionDaySignal.knownSupplements(all),
                                                      foodGroups: 0),
                       "4 of 4 supplements today")
    }

    /// `logLabel` is persisted — it is the key a logged day is recognised by. Re-wording the
    /// displayed dose must not silently orphan every day already recorded.
    func testLogLabelsAreStableAndDoseFree() {
        XCTAssertEqual(NutritionContent.supplementLogOptions,
                       ["Folate", "Omega-3", "Vitamin D", "Zinc"])
        for label in NutritionContent.supplementLogOptions {
            XCTAssertFalse(label.contains("("), "a dose in the stored key makes it re-wordable: \(label)")
        }
    }

    // MARK: Compliance

    /// This copy states counts. The moment it says a group or a supplement *does* something, it
    /// joins the surfaces that need a citation and a sign-off — see `ContentTests`.
    func testTheRowMakesNoHealthClaim() {
        let claimWords = ["boost", "improve", "good for", "supports", "increases", "reduces",
                          "fertility", "conceive", "egg quality", "hormone", "optimis"]
        for text in NutritionDaySignal.allStrings {
            let lower = text.lowercased()
            for word in claimWords {
                XCTAssertFalse(lower.contains(word), "\"\(word)\" turns a count into a claim: \(text)")
            }
        }
    }
}
