import XCTest
@testable import GenesyxCore

/// Guards for the recipe cards (T27). The interesting ones here are not "is the content complete" —
/// they are the two rules that let these cards ship without a medical sign-off of their own.
final class RecipeContentTests: XCTestCase {

    // MARK: - The compliance foreign key

    /// ⚠️ The entire reason these cards carry no citation, no disclaimer and no reviewer is that
    /// they add no claim of their own: each one cooks a focus food that `phaseFoods` — which *has*
    /// all three — already recommends for that phase.
    ///
    /// `usesFocusFood` is therefore a foreign key, not a caption. If a recipe names a food that is
    /// not in the reviewed list for its phase, the card has quietly started recommending something
    /// on its own authority, and there is no authority. This is the test that refuses.
    func testEveryRecipeNamesAFocusFoodThatExistsInItsOwnPhase() {
        for recipe in RecipeContent.all {
            let reviewed = (NutritionContent.phaseFoods[recipe.phase] ?? []).map(\.name)
            XCTAssertTrue(reviewed.contains(recipe.usesFocusFood),
                "\"\(recipe.name)\" claims focus food \"\(recipe.usesFocusFood)\", which is not in the "
                + "reviewed \(recipe.phase) list \(reviewed). Either fix the name or add the food to "
                + "phaseFoods — which needs the medical sign-off this card is relying on.")
        }
    }

    /// ⚠️ The same argument as `FoodLogCopy`'s guard, over the other card that has no sign-off. The
    /// realistic failure is not a banned phrase; it is one helpful sentence added later — "the
    /// spinach here supports egg quality" — turning a method step into a claim wanting
    /// substantiation under CAP Code 3.7, with every other guard still green.
    ///
    /// A recipe may say what to do with an ingredient. It may not say what the ingredient does to
    /// her. That line is the whole compliance position.
    func testRecipeCopyMakesNoHealthClaim() {
        let claimWords = [
            "boost", "improve", "helps you", "help you", "good for", "supports", "support your",
            "increases", "reduces", "prevents", "treats", "cures", "balances", "optimis",
            "fertility", "conceive", "egg quality", "hormone", "detox", "cleanse",
        ]
        for text in RecipeCopy.allStrings {
            let lower = text.lowercased()
            for word in claimWords {
                XCTAssertFalse(lower.contains(word),
                    "\"\(word)\" makes the recipe card a claim surface. It has no citation and no "
                    + "sign-off — the reason it needs neither is that it only repeats phaseFoods. "
                    + "Copy: \(text)")
            }
        }
    }

    // MARK: - Completeness

    func testEveryPhaseHasRecipes() {
        for phase in Phase.allCases {
            XCTAssertFalse(RecipeContent.forPhase(phase).isEmpty, "\(phase) has no recipes")
        }
    }

    func testRecipesAreUniquelyNamedAndFullyWritten() {
        XCTAssertEqual(Set(RecipeContent.all.map(\.name)).count, RecipeContent.all.count)
        for recipe in RecipeContent.all {
            XCTAssertFalse(recipe.name.isBlank, "blank name")
            XCTAssertGreaterThan(recipe.minutes, 0, "\(recipe.name) takes no time")
            XCTAssertGreaterThan(recipe.serves, 0, "\(recipe.name) serves nobody")
            XCTAssertGreaterThanOrEqual(recipe.ingredients.count, 3, "\(recipe.name) is short on ingredients")
            XCTAssertGreaterThanOrEqual(recipe.method.count, 2, "\(recipe.name) is short on method")
            for line in recipe.ingredients + recipe.method {
                XCTAssertFalse(line.isBlank, "blank line in \(recipe.name)")
            }
        }
    }

    /// The groups are what the "log this" button ticks off, so a wrong or repeated one writes bad
    /// data into her food log rather than merely reading oddly.
    func testEveryRecipeNamesFoodGroupsAndNamesNoneTwice() {
        for recipe in RecipeContent.all {
            XCTAssertFalse(recipe.groups.isEmpty, "\(recipe.name) names no food groups")
            XCTAssertEqual(Set(recipe.groups).count, recipe.groups.count,
                           "\(recipe.name) names a group twice")
        }
    }

    /// Nil throughout by design — there is no food photography in the asset catalogue, and a card
    /// pointing at an image that does not exist renders an empty box on her phone. When photography
    /// arrives this test is deleted in the same commit as the assets.
    func testNoRecipeClaimsAnImageTheAppDoesNotHave() {
        for recipe in RecipeContent.all {
            XCTAssertNil(recipe.imageName,
                "\(recipe.name) names an image — add the asset and delete this test together")
        }
    }

    // MARK: - Copy

    func testLogGroupsActionReadsAsEnglish() {
        XCTAssertEqual(RecipeCopy.logGroupsAction([.fruit]), "Log fruit")
        XCTAssertEqual(RecipeCopy.logGroupsAction([.fruit, .protein]), "Log fruit and protein")
        XCTAssertEqual(RecipeCopy.logGroupsAction([.fruit, .protein, .dairy]),
                       "Log fruit, protein and dairy & alternatives")
    }

    func testUsesLineNamesTheFoodItWasGiven() {
        XCTAssertEqual(RecipeCopy.usesLine("Leafy greens"), "Uses your focus food: Leafy greens")
    }

    func testMetaStatesTimeAndServings() {
        XCTAssertEqual(RecipeCopy.meta(minutes: 25, serves: 2), "25 min · serves 2")
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
