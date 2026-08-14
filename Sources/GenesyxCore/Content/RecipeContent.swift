import Foundation

/// Recipes for the focus foods, so the Nutrition screen stops naming ingredients and starts naming
/// meals (client change list T27).
///
/// ## Why these carry no medical sign-off, and `phaseFoods` does
///
/// Every recipe here is tied to a phase, which looks like the same kind of statement `phaseFoods`
/// makes — and that one needed a reviewer. The difference is that a recipe adds no reason of its
/// own. It names a focus food the reviewed content *already* recommends for that phase, and then
/// says how to cook it. `usesFocusFood` is not a label, it is a foreign key: `testEveryRecipeNamesAFocusFoodThatExists`
/// fails if it does not match a `PhaseFood.name` in the same phase, byte for byte.
///
/// So the claim is `phaseFoods`', made once and signed off once. Ingredients and method are
/// instructions — "soften the onion for 5 minutes" asserts nothing about a body. If a recipe ever
/// starts explaining *why* it helps, it has stopped repeating a reviewed claim and started making a
/// new one, and it needs what `phaseFoods` has. `testRecipeCopyMakesNoHealthClaim` is what notices.
///
/// ## Photography
///
/// Each shipped recipe names its own approved food photograph. `imageName` remains optional so the
/// phase-gradient fallback still works for a newly-authored recipe while its final artwork is being
/// prepared, but the shipped content tests require all current recipes to have unique mappings.
public struct Recipe: Identifiable, Hashable, Sendable {
    public let name: String
    /// The `PhaseFood.name` this meal is built around. Must exist in `NutritionContent.phaseFoods`
    /// for `phase` — that constraint is the whole compliance argument, and a test enforces it.
    public let usesFocusFood: String
    public let phase: Phase
    public let minutes: Int
    public let serves: Int
    public let ingredients: [String]
    public let method: [String]
    /// What she can tick off in the food log once she has eaten it. Closes the loop between the two
    /// cards rather than making her re-enter what the recipe already knows.
    public let groups: [FoodGroup]
    /// Asset-catalogue name for the food-only recipe photograph.
    public let imageName: String?

    public var id: String { name }

    public init(
        _ name: String,
        usesFocusFood: String,
        phase: Phase,
        minutes: Int,
        serves: Int,
        ingredients: [String],
        method: [String],
        groups: [FoodGroup],
        imageName: String? = nil
    ) {
        self.name = name
        self.usesFocusFood = usesFocusFood
        self.phase = phase
        self.minutes = minutes
        self.serves = serves
        self.ingredients = ingredients
        self.method = method
        self.groups = groups
        self.imageName = imageName
    }
}

/// Reader-facing copy for the recipe cards. In Core, not in the view, so the content guards can see
/// it — the same reason `FoodLogCopy` and `HydrationCoach`'s copy live here.
public enum RecipeCopy {
    public static let title = "Something to cook"
    public static let eyebrow = "Recipes"

    /// Names the reviewed focus food the recipe is built from. A pointer to the card above, not a
    /// reason of its own — see the note on `Recipe`.
    public static func usesLine(_ focusFood: String) -> String { "Uses your focus food: \(focusFood)" }

    public static func meta(minutes: Int, serves: Int) -> String {
        "\(minutes) min · serves \(serves)"
    }

    /// Shown after cooking. Ticks the groups the recipe already knows it covers, so she is not
    /// re-entering what is on screen.
    public static func logGroupsAction(_ groups: [FoodGroup]) -> String {
        groups.count == 1
            ? "Log \(groups[0].label.lowercased())"
            : "Log \(FoodLogCopy.sentenceList(groups.map { $0.label.lowercased() }))"
    }

    public static let ingredientsHeading = "You'll need"
    public static let methodHeading = "Method"

    /// Serving sizes, oven temperatures and swaps are the user's own call, and this screen has no
    /// way to know about an allergy or an intolerance.
    public static let footnote = "Recipes are a starting point — swap anything that does not suit you."

    /// Everything these cards can render, for the content guards.
    public static var allStrings: [String] {
        var out = [title, eyebrow, ingredientsHeading, methodHeading, footnote]
        out += RecipeContent.all.flatMap { recipe -> [String] in
            [recipe.name, usesLine(recipe.usesFocusFood),
             meta(minutes: recipe.minutes, serves: recipe.serves),
             logGroupsAction(recipe.groups)]
            + recipe.ingredients + recipe.method
        }
        return out
    }
}

public enum RecipeContent {

    /// Two per phase. `usesFocusFood` matches `NutritionContent.phaseFoods[phase]` exactly.
    public static let all: [Recipe] = [

        // ── Period ──
        Recipe(
            "Lentil, spinach and lemon dal",
            usesFocusFood: "Iron-rich foods",
            phase: .period,
            minutes: 30,
            serves: 2,
            ingredients: [
                "150g red lentils, rinsed",
                "1 onion, finely chopped",
                "2 garlic cloves, crushed",
                "1 tsp ground cumin and 1 tsp ground turmeric",
                "400ml vegetable stock",
                "100g spinach",
                "Juice of half a lemon",
                "1 tbsp olive oil",
            ],
            method: [
                "Soften the onion in the oil over a low heat for 5 minutes, then add the garlic and spices for one minute more.",
                "Add the lentils and stock. Simmer for 20 minutes, stirring now and then, until the lentils collapse.",
                "Stir the spinach through until it wilts.",
                "Take off the heat and add the lemon juice. Season to taste.",
            ],
            groups: [.protein, .vegetables, .oilsAndFats],
            imageName: "recipe_lentil_spinach_lemon_dal"
        ),
        Recipe(
            "Ginger and sweet potato soup",
            usesFocusFood: "Warming foods",
            phase: .period,
            minutes: 35,
            serves: 3,
            ingredients: [
                "2 sweet potatoes (about 500g), peeled and cubed",
                "1 thumb of fresh ginger, grated",
                "1 onion, chopped",
                "700ml vegetable stock",
                "1 tbsp olive oil",
                "Black pepper",
            ],
            method: [
                "Soften the onion in the oil for 5 minutes, then add the ginger for one minute.",
                "Add the sweet potato and stock. Bring to a simmer and cook for 20–25 minutes, until a knife slides through the potato easily.",
                "Blend until smooth, adding a splash of hot water if it is thicker than you want.",
                "Season with black pepper and serve hot.",
            ],
            groups: [.vegetables, .starchyCarbs, .oilsAndFats],
            imageName: "recipe_ginger_sweet_potato_soup"
        ),

        // ── Follicular ──
        Recipe(
            "Kefir and berry breakfast bowl",
            usesFocusFood: "Fermented foods",
            phase: .follicular,
            minutes: 5,
            serves: 1,
            ingredients: [
                "200ml kefir or live yoghurt",
                "80g mixed berries, fresh or frozen",
                "1 tbsp mixed seeds",
                "1 tsp honey, optional",
            ],
            method: [
                "Spoon the kefir into a bowl.",
                "Top with the berries and seeds.",
                "Add honey if you want it sweeter. If the berries are frozen, leave it to stand for five minutes.",
            ],
            groups: [.dairy, .fruit, .oilsAndFats],
            imageName: "recipe_kefir_berry_breakfast_bowl"
        ),
        Recipe(
            "Sprouted seed and tofu traybake",
            usesFocusFood: "Sprouted seeds",
            phase: .follicular,
            minutes: 30,
            serves: 2,
            ingredients: [
                "280g firm tofu, pressed and cubed",
                "2 tbsp pumpkin seeds",
                "1 tbsp ground flaxseed",
                "1 red pepper and 1 courgette, chopped",
                "1 tbsp olive oil",
                "1 tsp smoked paprika",
            ],
            method: [
                "Heat the oven to 200°C (180°C fan).",
                "Toss the tofu and vegetables with the oil and paprika, spread on a tray and roast for 20 minutes.",
                "Scatter over the pumpkin seeds and roast for a further 5 minutes.",
                "Sprinkle the ground flaxseed over just before serving.",
            ],
            groups: [.protein, .vegetables, .oilsAndFats],
            imageName: "recipe_sprouted_seed_tofu_traybake"
        ),

        // ── Ovulatory ──
        Recipe(
            "Big green salad with quinoa",
            usesFocusFood: "Leafy greens",
            phase: .ovulatory,
            minutes: 25,
            serves: 2,
            ingredients: [
                "100g quinoa",
                "2 large handfuls of spinach and rocket",
                "1 avocado, sliced",
                "1 tbsp pumpkin seeds",
                "Juice of half a lemon and 1 tbsp olive oil",
            ],
            method: [
                "Cook the quinoa in plenty of water for 15 minutes, then drain and let it cool a little.",
                "Whisk the lemon juice and oil together with a pinch of salt.",
                "Toss the leaves, quinoa and avocado with the dressing.",
                "Finish with the pumpkin seeds.",
            ],
            groups: [.vegetables, .starchyCarbs, .oilsAndFats],
            imageName: "recipe_big_green_quinoa_salad"
        ),
        Recipe(
            "Rainbow pepper and bean bowl",
            usesFocusFood: "Antioxidant foods",
            phase: .ovulatory,
            minutes: 20,
            serves: 2,
            ingredients: [
                "2 peppers of different colours, sliced",
                "1 tin (400g) black beans, drained",
                "200g cherry tomatoes, halved",
                "150g brown rice, cooked",
                "1 tbsp olive oil, juice of half a lime",
            ],
            method: [
                "Fry the peppers in the oil over a high heat for 6–8 minutes, until they take a little colour.",
                "Add the beans and tomatoes and warm through for 3 minutes.",
                "Spoon over the rice and finish with the lime juice.",
            ],
            groups: [.vegetables, .protein, .starchyCarbs, .oilsAndFats],
            imageName: "recipe_rainbow_pepper_bean_bowl"
        ),

        // ── Luteal ──
        Recipe(
            "Dark chocolate and almond oat bars",
            usesFocusFood: "Magnesium-rich foods",
            phase: .luteal,
            minutes: 40,
            serves: 8,
            ingredients: [
                "200g rolled oats",
                "100g almonds, roughly chopped",
                "60g dark chocolate (70%), chopped",
                "2 ripe bananas, mashed",
                "3 tbsp olive or rapeseed oil",
                "2 tbsp honey",
            ],
            method: [
                "Heat the oven to 180°C (160°C fan) and line a small tin.",
                "Mix everything together in a bowl until the oats are evenly coated.",
                "Press firmly into the tin and bake for 25 minutes, until golden at the edges.",
                "Cool completely in the tin before cutting, or the bars will crumble.",
            ],
            groups: [.starchyCarbs, .fruit, .oilsAndFats],
            imageName: "recipe_dark_chocolate_almond_oat_bars"
        ),
        Recipe(
            "Salmon, oats and greens traybake",
            usesFocusFood: "B6 foods",
            phase: .luteal,
            minutes: 30,
            serves: 2,
            ingredients: [
                "2 salmon fillets",
                "2 tbsp oats and 1 tbsp sunflower seeds, for the crust",
                "200g tenderstem broccoli",
                "1 tbsp olive oil",
                "Half a lemon",
            ],
            method: [
                "Heat the oven to 200°C (180°C fan).",
                "Mix the oats and sunflower seeds with half the oil and press onto the salmon fillets.",
                "Toss the broccoli in the rest of the oil and spread on a tray with the salmon.",
                "Bake for 15–18 minutes, until the salmon flakes with a fork. Squeeze the lemon over to serve.",
            ],
            groups: [.protein, .vegetables, .starchyCarbs, .oilsAndFats],
            imageName: "recipe_salmon_oats_greens_traybake"
        ),
    ]

    public static func forPhase(_ phase: Phase) -> [Recipe] {
        all.filter { $0.phase == phase }
    }
}
