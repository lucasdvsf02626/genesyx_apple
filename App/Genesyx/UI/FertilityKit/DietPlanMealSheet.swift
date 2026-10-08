import GenesyxCore
import SwiftUI

/// One recipe from the meal ideas: what it contains, what to gather and how to cook it. It reads
/// the recipe's name, times, ingredients and method, and nothing about why the recipe was chosen.
struct DietPlanMealSheet: View {
    private let card: DietPlanMealCard

    @Environment(\.dismiss) private var dismiss

    init(card: DietPlanMealCard) { self.card = card }

    var body: some View {
        let lines = DietPlanPresentation.mealLines(card)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let recipe = card.recipe {
                        VStack(alignment: .leading, spacing: 4) {
                            KitLine(lines.meta, muted: true)
                            if let contains = lines.contains {
                                KitLine(contains).accessibilityIdentifier("kit.diet.meal.sheet.groups")
                            }
                        }
                        KitCard {
                            KitSectionTitle(RecipeCopy.ingredientsHeading)
                            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in KitLine(line) }
                        }
                        KitCard {
                            KitSectionTitle(RecipeCopy.methodHeading)
                            ForEach(Array(recipe.method.enumerated()), id: \.offset) { _, step in KitLine(step) }
                        }
                        KitNote(YourDietPlanScreenCopy.swapNote)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .background(GenesyxColor.background)
            .navigationTitle(lines.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(FertilityKitCopy.done) { dismiss() }
                        .accessibilityIdentifier("kit.diet.meal.sheet.done")
                }
            }
        }
        .kitContainer("kit.diet.meal.sheet")
    }
}

#if DEBUG
#Preview {
    if let card = DietPlanContent.draft.mealCards.first {
        DietPlanMealSheet(card: card).withKitPreview(day: 23)
    }
}
#endif
