import Foundation

// Your Diet Plan: the content SCHEMA. Value types only. The words are in
// `DietPlanDraftContent.swift`, the facts read from her food groups are in `DietPlanFacts.swift`,
// and `DietPlan.swift` puts the two together for a screen.
//
// ONE SOURCE OF TRUTH PER FACT
//   • The six food groups are `FoodGroup`. No group is named here that the tracker does not have.
//   • A recipe is a `Recipe`, pointed at by its own id. Its food groups are read from the recipe.
//   • A week's focus title is the programme's `ProgrammeNutritionFocus`. This file adds a body to
//     it and never a second title.
//   • What she ate is `DailyLog.foodGroups`. Nothing here stores it again.
//
// THE PROMISE THESE FILES KEEP
//   The food group tracker is a record, not a target (`FoodLogCopy.footnote`). So the Diet Plan
//   files hold counts and words only. They hold no score, no percentage, no grade, no rating and no
//   measure of diet quality, and nothing that orders the groups or lists the ones she did not
//   record. `DietPlanGuardTests` reads these sources and fails if one of those words appears in
//   the code.

// MARK: - Food guide

/// The four parts of a food guide entry, in the order they are shown.
public enum DietPlanGuidePart: String, CaseIterable, Sendable {
    case learn, examples, tryIt, track

    public var heading: String {
        switch self {
        case .learn: return "Learn"
        case .examples: return "Examples"
        case .tryIt: return "Try"
        case .track: return "Track"
        }
    }
}

/// A call to action into the existing food group tracker. The destination is typed, so the app
/// maps it to the real screen and no second tracker can be reached from here.
public struct DietPlanTrackAction: Hashable, Sendable {
    public let label: String
    public let destination: ProgrammeDestination
    /// The group the entry is about.
    public let foodGroup: FoodGroup
}

/// One food group in the guide: what it is, everyday examples, one idea, and the way into the
/// tracker. The title is the group's own label.
public struct DietPlanFoodGuideEntry: Identifiable, Hashable, Sendable {
    public let group: FoodGroup
    /// What the group is. Names what belongs in it and says nothing about what any food does.
    public let learn: String
    /// Everyday foods in the group. Every list has plant-based entries.
    public let examples: [String]
    /// One simple idea, in one or two sentences.
    public let tryIt: String
    public let track: DietPlanTrackAction
    public let review: ProgrammeContentReview

    public var id: String { group.rawValue }
    public var title: String { group.label }

    public init(
        _ group: FoodGroup,
        learn: String,
        examples: [String],
        tryIt: String,
        review: ProgrammeContentReview = ProgrammeContentReview(containsHealthInterpretation: true)
    ) {
        self.group = group
        self.learn = learn
        self.examples = examples
        self.tryIt = tryIt
        self.track = DietPlanTrackAction(
            label: "Record " + group.label.lowercased() + " in the food group tracker",
            destination: .nutrition,
            foodGroup: group)
        self.review = review
    }
}

// MARK: - Meal inspiration

public enum DietPlanMealCategory: String, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack, quick, vegetarian, plantBased

    /// A recipe is quick at or under this many minutes, read from `Recipe.minutes`.
    public static let quickMinutesLimit = 20

    public var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        case .quick: return "Quick options"
        case .vegetarian: return "Vegetarian"
        case .plantBased: return "Plant-based"
        }
    }
}

/// A meal idea that stands on a recipe the app already has. The card holds no name, ingredients or
/// method of its own: the recipe does.
public struct DietPlanMealCard: Identifiable, Hashable, Sendable {
    /// `Recipe.id` of the existing recipe.
    public let recipeID: String
    /// The food groups the meal contributes to: the recipe's own `groups`, in the recipe's order.
    public let foodGroups: [FoodGroup]
    public let categories: [DietPlanMealCategory]
    public let review: ProgrammeContentReview

    public var id: String { recipeID }
    /// The recipe itself, or `nil` if it has been removed from `RecipeContent`.
    public var recipe: Recipe? { RecipeContent.all.first { $0.id == recipeID } }
    public var reference: ProgrammeContentReference { .recipe(id: recipeID) }
}

// MARK: - Weekly nutrition text

/// The body written for one programme week's nutrition focus. Keyed by week number; the title
/// stays in the programme content.
public struct DietPlanWeekText: Hashable, Sendable {
    /// 1 to 13.
    public let week: Int
    public let body: String
    /// One practical line, opening "This week, try".
    public let tryThisWeek: String
    public let review: ProgrammeContentReview

    public init(
        _ week: Int,
        body: String,
        tryThisWeek: String,
        review: ProgrammeContentReview = ProgrammeContentReview(containsHealthInterpretation: true)
    ) {
        self.week = week
        self.body = body
        self.tryThisWeek = tryThisWeek
        self.review = review
    }
}

/// A week's nutrition focus ready to show: the programme's own title, detail and food groups,
/// joined to the body and the practical line written here.
public struct DietPlanWeekFocus: Hashable, Sendable {
    public let week: Int
    /// `ProgrammeNutritionFocus.title`.
    public let title: String
    /// `ProgrammeNutritionFocus.detail`.
    public let detail: String
    /// `ProgrammeNutritionFocus.foodGroups`. Empty when the focus is a habit, not a group.
    public let foodGroups: [FoodGroup]
    public let body: String
    public let tryThisWeek: String
    public let review: ProgrammeContentReview
}

// MARK: - Review report

/// One row of the Diet Plan review report. For reports only; never shown to users.
public struct DietPlanReviewItem: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case foodGuide, mealCard, weekText }
    public let kind: Kind
    /// Stable within the content: "diet-guide-vegetables", "diet-meal-" and the recipe id,
    /// "diet-week-04".
    public let id: String
    public let review: ProgrammeContentReview
}

// MARK: - Content

public struct DietPlanContent: Sendable {
    /// One entry per food group, in the tracker's order.
    public let foodGuide: [DietPlanFoodGuideEntry]
    /// The one medical sentence the guide carries.
    public let allergyNote: String
    /// One card per existing recipe, in the recipes' order.
    public let mealCards: [DietPlanMealCard]
    public let weekTexts: [DietPlanWeekText]

    public init(
        foodGuide: [DietPlanFoodGuideEntry],
        allergyNote: String,
        mealCards: [DietPlanMealCard],
        weekTexts: [DietPlanWeekText]
    ) {
        self.foodGuide = foodGuide
        self.allergyNote = allergyNote
        self.mealCards = mealCards
        self.weekTexts = weekTexts
    }

    public func mealCards(in category: DietPlanMealCategory) -> [DietPlanMealCard] {
        mealCards.filter { $0.categories.contains(category) }
    }

    /// The focus for a programme week, or `nil` when either side has no entry for that week.
    public func weekFocus(forWeek week: Int, programme: ProgrammeContent = .draft) -> DietPlanWeekFocus? {
        guard let text = weekTexts.first(where: { $0.week == week }),
              let focus = programme.week(week)?.nutritionFocus else { return nil }
        return DietPlanWeekFocus(
            week: week, title: focus.title, detail: focus.detail, foodGroups: focus.foodGroups,
            body: text.body, tryThisWeek: text.tryThisWeek, review: text.review)
    }

    /// One card for each recipe, with the recipe's own food groups. A recipe with no entry in
    /// `categories` still gets its card, with no category claimed for it.
    static func mealCards(
        for recipes: [Recipe],
        categories: [String: [DietPlanMealCategory]]
    ) -> [DietPlanMealCard] {
        recipes.map {
            DietPlanMealCard(
                recipeID: $0.id, foodGroups: $0.groups, categories: categories[$0.id] ?? [],
                review: ProgrammeContentReview(containsHealthInterpretation: true))
        }
    }

    // MARK: Review report

    /// Every Diet Plan content item with its review mark.
    public func reviewItems() -> [DietPlanReviewItem] {
        foodGuide.map { DietPlanReviewItem(kind: .foodGuide, id: "diet-guide-" + $0.id, review: $0.review) }
            + mealCards.map { DietPlanReviewItem(kind: .mealCard, id: "diet-meal-" + $0.id, review: $0.review) }
            + weekTexts.map {
                DietPlanReviewItem(kind: .weekText, id: "diet-week-" + ($0.week < 10 ? "0" : "") + String($0.week),
                                   review: $0.review)
            }
    }

    // MARK: Guarded registry

    /// Every reader-facing string this content adds: the part headings, the category labels, the
    /// allergy note, each guide entry and each week's text. The guard tests scan this list, so a
    /// string added to the schema has to be added here to be covered. Recipe names and the
    /// programme's focus titles are not repeated here: they belong to their own registries.
    public var allSurfaces: [String] {
        DietPlanGuidePart.allCases.map(\.heading)
            + DietPlanMealCategory.allCases.map(\.label)
            + [allergyNote]
            + foodGuide.flatMap { [$0.learn] + $0.examples + [$0.tryIt, $0.track.label] }
            + weekTexts.flatMap { [$0.body, $0.tryThisWeek] }
    }
}
