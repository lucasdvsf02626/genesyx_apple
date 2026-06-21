import XCTest
@testable import GenesyxCore

/// Completeness + integrity checks for the ported nutrition/cycle content and overlay helpers.
/// Ported verbatim from the Android `NutritionContentTest.kt`.
final class ContentTests: XCTestCase {

    private let allPhases = Set(Phase.allCases)

    // ── Nutrition focus foods (screens/Nutrition.tsx PHASE_FOODS) ──

    func testEveryPhaseHasFocusFoodsWithExpectedCounts() {
        XCTAssertEqual(Set(NutritionContent.phaseFoods.keys), allPhases)
        XCTAssertEqual(NutritionContent.phaseFoods[.period]!.count, 3)
        XCTAssertEqual(NutritionContent.phaseFoods[.follicular]!.count, 3)
        XCTAssertEqual(NutritionContent.phaseFoods[.ovulatory]!.count, 4)
        XCTAssertEqual(NutritionContent.phaseFoods[.luteal]!.count, 4)
    }

    func testEveryFocusFoodHasNonBlankCopyAndRicherExpandedDescription() {
        for food in NutritionContent.phaseFoods.values.flatMap({ $0 }) {
            XCTAssertFalse(food.name.isBlank, "name blank")
            XCTAssertFalse(food.shortDesc.isBlank, "shortDesc blank for \(food.name)")
            XCTAssertFalse(food.expandedDesc.isBlank, "expandedDesc blank for \(food.name)")
            XCTAssertGreaterThan(
                food.expandedDesc.count, food.shortDesc.count,
                "expandedDesc should be longer than shortDesc for \(food.name)"
            )
        }
    }

    func testEachPhaseUsesOneAccentAndTheFourPhaseAccentsAreDistinct() {
        for (phase, foods) in NutritionContent.phaseFoods {
            let accents = Set(foods.map(\.accent))
            XCTAssertEqual(accents.count, 1, "phase \(phase) should use a single accent")
        }
        let phaseAccents = Set(NutritionContent.phaseFoods.values.map { $0.first!.accent })
        XCTAssertEqual(phaseAccents.count, 4, "the four phases should have distinct accents")
    }

    func testPhaseDescriptionsCoverEveryPhaseAndAreNonBlank() {
        XCTAssertEqual(Set(NutritionContent.phaseDescription.keys), allPhases)
        for desc in NutritionContent.phaseDescription.values {
            XCTAssertFalse(desc.isBlank)
        }
    }

    func testSupplementPlanIsFolateOmega3VitaminDAndZinc() {
        XCTAssertEqual(NutritionContent.supplementPlan.map(\.initial), ["F", "O", "D", "Z"])
        for item in NutritionContent.supplementPlan {
            XCTAssertFalse(item.name.isBlank)
            XCTAssertFalse(item.rationale.isBlank)
        }
    }

    func testThereAreThreeLearnMoreArticlesWithCopy() {
        XCTAssertEqual(NutritionContent.articles.count, 3)
        for article in NutritionContent.articles {
            XCTAssertFalse(article.title.isBlank)
            XCTAssertFalse(article.read.isBlank)
        }
    }

    // ── Cycle content (lib/cycle.ts phaseHeroCopy / phaseFoods / phaseLabel) ──

    func testCycleContentCoversEveryPhase() {
        XCTAssertEqual(Set(CycleContent.phaseHeroCopy.keys), allPhases)
        XCTAssertEqual(Set(CycleContent.phaseLabel.keys), allPhases)
        XCTAssertEqual(Set(CycleContent.phaseFoods.keys), allPhases)
        for foods in CycleContent.phaseFoods.values {
            XCTAssertEqual(foods.count, 4)
        }
        for copy in CycleContent.phaseHeroCopy.values {
            XCTAssertFalse(copy.hero.isBlank)
            XCTAssertFalse(copy.sub.isBlank)
            XCTAssertFalse(copy.tags.isEmpty)
            XCTAssertFalse(copy.focus.title.isBlank)
            XCTAssertFalse(copy.focus.body.isBlank)
        }
    }

    // ── Fertile-window overlay (lib/cycleEngine.ts) ──

    func testSubLabelIsThePhaseLabelNormallyAndFertileWindowWhenFertile() {
        for phase in Phase.allCases {
            XCTAssertEqual(CycleContent.phaseSubLabel(phase, inFertile: false), CycleContent.phaseLabel[phase]!)
            XCTAssertEqual(CycleContent.phaseSubLabel(phase, inFertile: true), "Fertile window")
        }
    }

    func testHeroTextOverlaysForNonOvulatoryFertileDaysButNotOvulationItself() {
        // Ovulatory keeps its own hero even inside the fertile window.
        XCTAssertEqual(CycleContent.phaseHeroText(.ovulatory, inFertile: true), CycleContent.phaseHeroCopy[.ovulatory]!.hero)
        // Other phases switch to the fertile-window hero when fertile.
        XCTAssertEqual(CycleContent.phaseHeroText(.follicular, inFertile: true), "Fertile window is open")
        XCTAssertEqual(CycleContent.phaseHeroText(.follicular, inFertile: false), CycleContent.phaseHeroCopy[.follicular]!.hero)
        XCTAssertTrue(CycleContent.phaseHeroSubtext(.follicular, inFertile: true).contains("Conception"))
        XCTAssertEqual(CycleContent.phaseHeroSubtext(.luteal, inFertile: false), CycleContent.phaseHeroCopy[.luteal]!.sub)
    }

    func testTagsPrependFertileWindowForNonOvulatoryFertileDaysOnly() {
        let base = CycleContent.phaseHeroCopy[.follicular]!.tags
        let fertile = CycleContent.phaseTags(.follicular, inFertile: true)
        XCTAssertEqual(fertile.first, "Fertile window")
        XCTAssertEqual(fertile.count, base.count + 1)
        // Ovulatory is not overlaid.
        XCTAssertEqual(CycleContent.phaseTags(.ovulatory, inFertile: true), CycleContent.phaseHeroCopy[.ovulatory]!.tags)
        // Not fertile -> unchanged.
        XCTAssertEqual(CycleContent.phaseTags(.follicular, inFertile: false), base)
    }
}

private extension String {
    /// Kotlin `isNotBlank()` parity: non-empty after trimming whitespace.
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
