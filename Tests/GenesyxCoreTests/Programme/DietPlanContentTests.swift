import XCTest
@testable import GenesyxCore

/// Your Diet Plan content: the food guide, the meal cards, the weekly text and the review marks.
final class DietPlanContentTests: XCTestCase {

    private let content = DietPlanContent.draft

    private func words(_ text: String) -> Int { text.split(separator: " ").count }
    private func sentences(_ text: String) -> Int { text.filter { ".!?".contains($0) }.count }

    // ── The six real food groups ──

    /// The names this content is written against. If the tracker's groups change, the guide has to
    /// be looked at again, and this is the test that says so.
    func testTheSixFoodGroupsAreTheTrackersOwn() {
        XCTAssertEqual(FoodGroup.allCases.map(\.rawValue),
                       ["vegetables", "fruit", "starchyCarbs", "protein", "dairy", "oilsAndFats"])
        XCTAssertEqual(FoodGroup.allCases.map(\.label),
                       ["Vegetables", "Fruit", "Starchy carbs", "Protein", "Dairy & alternatives", "Oils & fats"])
    }

    // ── Food guide ──

    func testTheGuideHasExactlyOneEntryForEachRealGroup() {
        XCTAssertEqual(content.foodGuide.count, 6)
        XCTAssertEqual(content.foodGuide.map(\.group), FoodGroup.allCases)
        XCTAssertEqual(content.foodGuide.map(\.title), FoodGroup.allCases.map(\.label))
        XCTAssertEqual(DietPlanGuidePart.allCases.map(\.heading), ["Learn", "Examples", "Try", "Track"])
    }

    func testEveryGuideEntryHasAllFourPartsWithinTheirLimits() {
        for entry in content.foodGuide {
            let name = entry.group.rawValue
            // LEARN: 40 to 90 words, and it names the chip she ticks by the tracker's own label.
            XCTAssertTrue((40...90).contains(words(entry.learn)), "\(name) learn is \(words(entry.learn)) words")
            XCTAssertTrue(entry.learn.lowercased().contains("tick " + entry.group.label.lowercased()),
                          "\(name) learn does not name its own chip")
            // EXAMPLES: 8 to 12 short food names, none repeated.
            XCTAssertTrue((8...12).contains(entry.examples.count), "\(name) has \(entry.examples.count) examples")
            XCTAssertEqual(Set(entry.examples).count, entry.examples.count, "\(name) repeats an example")
            for example in entry.examples {
                XCTAssertTrue((1...6).contains(words(example)), "\(name): \(example)")
                XCTAssertFalse(example.contains { $0.isNumber }, "an example carries a number: \(example)")
            }
            // TRY: one or two sentences.
            XCTAssertTrue((1...2).contains(sentences(entry.tryIt)), "\(name) try is not one or two sentences")
            XCTAssertTrue((8...40).contains(words(entry.tryIt)), "\(name) try is \(words(entry.tryIt)) words")
            // TRACK: a typed way into the existing tracker.
            XCTAssertEqual(entry.track.destination, .nutrition)
            XCTAssertEqual(entry.track.foodGroup, entry.group)
            XCTAssertTrue(entry.track.label.contains(entry.group.label.lowercased()))
        }
    }

    func testNoExampleIsListedUnderTwoGroups() {
        let all = content.foodGuide.flatMap(\.examples)
        XCTAssertEqual(Set(all).count, all.count)
    }

    /// Every group can be met without meat, fish, dairy or eggs. Four of the groups are plants by
    /// definition; the two that are not each list plant-based entries by name.
    func testEveryGroupListsPlantBasedExamples() throws {
        let animal = ["egg", "tuna", "sardine", "salmon", "fish", "chicken", "beef", "lamb", "milk", "kefir",
                      "cheese", "cheddar", "paneer", "lassi"]
        func isPlantBased(_ example: String) -> Bool {
            let lower = example.lowercased()
            if lower.contains("plant-based") || lower.contains("soya") || lower.contains("oat or almond") { return true }
            return !lower.contains("yoghurt") && !animal.contains { lower.contains($0) }
        }
        for entry in content.foodGuide {
            XCTAssertGreaterThanOrEqual(entry.examples.filter(isPlantBased).count, 3, entry.group.rawValue)
        }
        for group in [FoodGroup.vegetables, .fruit, .starchyCarbs, .oilsAndFats] {
            let entry = try XCTUnwrap(content.foodGuide.first { $0.group == group })
            XCTAssertTrue(entry.examples.allSatisfy(isPlantBased), group.rawValue)
        }
        let protein = try XCTUnwrap(content.foodGuide.first { $0.group == .protein })
        for expected in ["Lentils", "Chickpeas", "Tofu"] { XCTAssertTrue(protein.examples.contains(expected)) }
        // The guard can tell the two apart.
        XCTAssertFalse(isPlantBased("Yoghurt"))
        XCTAssertFalse(isPlantBased("Salmon or white fish"))
        XCTAssertTrue(isPlantBased("Plant-based yoghurt alternative"))
    }

    func testTheAllergyNoteIsTheOneAgreedSentence() {
        XCTAssertEqual(content.allergyNote,
                       "If you have an allergy, a medical condition or dietary needs, follow the advice of your "
                       + "GP or a registered dietitian.")
        XCTAssertEqual(sentences(content.allergyNote), 1)
    }

    // ── Meal inspiration ──

    func testEveryExistingRecipeHasExactlyOneCardAndEveryCardARealRecipe() throws {
        XCTAssertEqual(RecipeContent.all.count, 8)
        XCTAssertEqual(content.mealCards.map(\.recipeID), RecipeContent.all.map(\.id))
        XCTAssertEqual(Set(content.mealCards.map(\.id)).count, content.mealCards.count)
        for card in content.mealCards {
            let recipe = try XCTUnwrap(card.recipe, "no recipe with id \(card.recipeID)")
            XCTAssertEqual(recipe.id, card.recipeID)
            XCTAssertEqual(card.reference, .recipe(id: recipe.id))
            // The food groups are the recipe's own, not a second list.
            XCTAssertEqual(card.foodGroups, recipe.groups)
            XCTAssertFalse(card.foodGroups.isEmpty)
        }
        // No category entry is left pointing at a recipe that does not exist.
        XCTAssertEqual(Set(DietPlanContent.draftMealCategories.keys), Set(RecipeContent.all.map(\.id)))
    }

    func testARecipeWithNoCategoryEntryStillGetsOneCardThatClaimsNothing() {
        let extra = Recipe("Test toast", usesFocusFood: "Complex carbs", phase: .luteal, minutes: 5, serves: 1,
                           ingredients: ["Bread"], method: ["Toast it."], groups: [.starchyCarbs])
        let cards = DietPlanContent.mealCards(for: RecipeContent.all + [extra],
                                              categories: DietPlanContent.draftMealCategories)
        XCTAssertEqual(cards.count, 9)
        XCTAssertEqual(cards.last?.recipeID, "Test toast")
        XCTAssertEqual(cards.last?.foodGroups, [.starchyCarbs])
        XCTAssertEqual(cards.last?.categories, [])
        XCTAssertNil(cards.last?.recipe)
    }

    /// The table as written. A change to it is a content change and has to be made here too.
    func testTheCategoriesOfTheEightRecipes() {
        let expected: [String: [DietPlanMealCategory]] = [
            "Lentil, spinach and lemon dal": [.dinner, .vegetarian, .plantBased],
            "Ginger and sweet potato soup": [.lunch, .vegetarian, .plantBased],
            "Kefir and berry breakfast bowl": [.breakfast, .quick, .vegetarian],
            "Sprouted seed and tofu traybake": [.dinner, .vegetarian, .plantBased],
            "Big green salad with quinoa": [.lunch, .vegetarian, .plantBased],
            "Rainbow pepper and bean bowl": [.lunch, .quick, .vegetarian, .plantBased],
            "Dark chocolate and almond oat bars": [.snack, .vegetarian],
            "Salmon, oats and greens traybake": [.dinner],
        ]
        for card in content.mealCards {
            XCTAssertEqual(card.categories, expected[card.recipeID], card.recipeID)
            XCTAssertFalse(card.categories.isEmpty, card.recipeID)
            XCTAssertEqual(Set(card.categories).count, card.categories.count, card.recipeID)
        }
        XCTAssertEqual(DietPlanMealCategory.allCases.map(\.label),
                       ["Breakfast", "Lunch", "Dinner", "Snacks", "Quick options", "Vegetarian", "Plant-based"])
    }

    /// A category is claimed only where the recipe's own data bears it out.
    func testCategoryClaimsAreBorneOutByTheRecipeData() throws {
        let meatOrFish = ["salmon", "tuna", "fish", "prawn", "anchov", "chicken", "turkey", "beef", "lamb",
                          "pork", "bacon", "ham", "sausage", "mince", "meat", "gelatine"]
        let otherAnimal = ["kefir", "yoghurt", "milk", "cheese", "butter", "cream", "egg", "honey", "chocolate"]
        func mentions(_ terms: [String], _ recipe: Recipe) -> Bool {
            recipe.ingredients.contains { line in terms.contains { line.lowercased().contains($0) } }
        }
        let mealtimes: [DietPlanMealCategory] = [.breakfast, .lunch, .dinner, .snack]
        XCTAssertEqual(DietPlanMealCategory.quickMinutesLimit, 20)

        for card in content.mealCards {
            let recipe = try XCTUnwrap(card.recipe)
            XCTAssertEqual(card.categories.contains(.quick),
                           recipe.minutes <= DietPlanMealCategory.quickMinutesLimit, recipe.name)
            XCTAssertEqual(card.categories.contains(.vegetarian), !mentions(meatOrFish, recipe), recipe.name)
            if card.categories.contains(.plantBased) {
                XCTAssertTrue(card.categories.contains(.vegetarian), recipe.name)
                XCTAssertFalse(mentions(otherAnimal, recipe), "\(recipe.name) is not plant-based")
            }
            if card.categories.contains(.breakfast) {
                XCTAssertTrue(recipe.name.lowercased().contains("breakfast"), recipe.name)
            }
            // One mealtime each: the mealtime is a judgement, so it is made once per recipe.
            XCTAssertEqual(card.categories.filter(mealtimes.contains).count, 1, recipe.name)
        }
    }

    func testEveryCategoryHasAtLeastOneCard() {
        for category in DietPlanMealCategory.allCases {
            let cards = content.mealCards(in: category)
            XCTAssertFalse(cards.isEmpty, "\(category) has no card")
            XCTAssertTrue(cards.allSatisfy { $0.categories.contains(category) })
        }
        XCTAssertEqual(content.mealCards(in: .vegetarian).count, 7)
        XCTAssertEqual(content.mealCards(in: .plantBased).count, 5)
        XCTAssertEqual(content.mealCards(in: .breakfast).map(\.recipeID), ["Kefir and berry breakfast bowl"])
    }

    // ── Weekly nutrition text ──

    func testThirteenWeeklyBodiesKeyedOneToThirteen() {
        XCTAssertEqual(content.weekTexts.map(\.week), Array(1...13))
        for text in content.weekTexts {
            XCTAssertTrue((40...90).contains(words(text.body)), "week \(text.week) body is \(words(text.body)) words")
            XCTAssertTrue(text.tryThisWeek.hasPrefix("This week, try "), "week \(text.week)")
            XCTAssertEqual(sentences(text.tryThisWeek), 1, "week \(text.week)")
            XCTAssertTrue((8...35).contains(words(text.tryThisWeek)), "week \(text.week)")
        }
        XCTAssertEqual(Set(content.weekTexts.map(\.body)).count, 13)
        XCTAssertEqual(Set(content.weekTexts.map(\.tryThisWeek)).count, 13)
    }

    func testEachWeeksTextJoinsToTheProgrammesOwnFocus() throws {
        let programme = ProgrammeContent.draft
        for week in 1...13 {
            let focus = try XCTUnwrap(content.weekFocus(forWeek: week))
            let own = try XCTUnwrap(programme.week(week)?.nutritionFocus)
            XCTAssertEqual(focus.week, week)
            XCTAssertEqual(focus.title, own.title)
            XCTAssertEqual(focus.detail, own.detail)
            XCTAssertEqual(focus.foodGroups, own.foodGroups)
            XCTAssertEqual(focus.body, content.weekTexts[week - 1].body)
            XCTAssertEqual(focus.tryThisWeek, content.weekTexts[week - 1].tryThisWeek)
        }
        XCTAssertNil(content.weekFocus(forWeek: 0))
        XCTAssertNil(content.weekFocus(forWeek: 14))
    }

    /// The bodies were written for these titles. A retitled focus must not keep an old body.
    func testTheFocusTitlesAreTheOnesTheBodiesWereWrittenFor() {
        XCTAssertEqual((1...13).map { content.weekFocus(forWeek: $0)?.title }, [
            "Your current routine", "Notice variety", "Balanced plate", "Hydration",
            "Fruit and vegetable variety", "Protein variety", "Fibre-rich choices", "Oils and fats",
            "Meal regularity", "Practical preparation", "Sustainable choices",
            "Understand your nutrition pattern", "Long-term routine",
        ])
    }

    // ── Every food group named is real ──

    func testEveryFoodGroupNamedAnywhereIsARealCase() {
        let real = Set(FoodGroup.allCases)
        let named = content.foodGuide.map(\.group)
            + content.foodGuide.map(\.track.foodGroup)
            + content.mealCards.flatMap(\.foodGroups)
            + (1...13).flatMap { content.weekFocus(forWeek: $0)?.foodGroups ?? [] }
        XCTAssertGreaterThan(named.count, 12)
        XCTAssertTrue(Set(named).isSubset(of: real))
        // Where the copy names a chip to tick, it uses a real label, capitalised as the tracker has it.
        let labels = FoodGroup.allCases.map(\.label)
        for surface in content.allSurfaces {
            var rest = Substring(surface)
            while let range = rest.range(of: "ick ") {
                let after = rest[range.upperBound...]
                if after.first?.isUppercase == true {
                    XCTAssertTrue(labels.contains { after.hasPrefix($0) }, "not a real chip: \(after.prefix(30))")
                }
                rest = after
            }
        }
    }

    // ── Review status ──

    func testEveryItemIsADraftFlaggedForClinicalReview() {
        let items = content.reviewItems()
        XCTAssertEqual(items.count, 6 + 8 + 13)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count, "review ids must be unique")
        XCTAssertEqual(items.filter { $0.kind == .foodGuide }.count, 6)
        XCTAssertEqual(items.filter { $0.kind == .mealCard }.count, 8)
        XCTAssertEqual(items.filter { $0.kind == .weekText }.count, 13)
        XCTAssertEqual(items.first?.id, "diet-guide-vegetables")
        XCTAssertEqual(items.last?.id, "diet-week-13")
        XCTAssertTrue(items.contains { $0.id == "diet-week-04" })

        let reviews = items.map(\.review)
            + content.foodGuide.map(\.review) + content.mealCards.map(\.review) + content.weekTexts.map(\.review)
            + (1...13).compactMap { content.weekFocus(forWeek: $0)?.review }
        XCTAssertEqual(reviews.count, 27 + 27 + 13)
        for review in reviews {
            XCTAssertEqual(review.status, .draft)
            XCTAssertTrue(review.containsHealthInterpretation)
        }
    }

    // ── Guarded registry ──

    func testEveryStringOfEveryItemIsInTheRegistry() {
        let surfaces = Set(content.allSurfaces)
        XCTAssertEqual(content.allSurfaces.count, 4 + 7 + 1 + 6 * 3 + 67 + 13 * 2)
        for entry in content.foodGuide {
            for s in [entry.learn, entry.tryIt, entry.track.label] + entry.examples {
                XCTAssertTrue(surfaces.contains(s), s)
            }
        }
        for text in content.weekTexts {
            XCTAssertTrue(surfaces.contains(text.body))
            XCTAssertTrue(surfaces.contains(text.tryThisWeek))
        }
        XCTAssertTrue(surfaces.contains(content.allergyNote))
        for category in DietPlanMealCategory.allCases { XCTAssertTrue(surfaces.contains(category.label)) }
        for part in DietPlanGuidePart.allCases { XCTAssertTrue(surfaces.contains(part.heading)) }
    }
}
