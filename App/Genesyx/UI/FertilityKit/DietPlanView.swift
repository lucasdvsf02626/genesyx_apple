import GenesyxCore
import SwiftUI

/// Your Diet Plan: today's food groups, this week's focus, the food guide, meal ideas, a plain
/// history of what she recorded, and where the plan meets the programme. A record, never a target:
/// nothing here is counted towards anything, and no figure is turned into a share or a grade.
struct DietPlanView: View {
    @Environment(\.fertilityKit) private var kit
    @EnvironmentObject private var container: AppContainer

    @State private var route: FertilityKitRoute?
    @State private var openMeal: DietPlanMealCard?

    init() {}

    var body: some View {
        let diet = DietPlan.assemble(logsByDate: kit.planInput.logsByDate, state: kit.planInput.state, today: kit.today)
        let recording = kit.planInput.consentActive
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ConsentWithdrawnBanner()
                todayCard(diet, recording: recording)
                if let focus = diet.weekFocus { focusCard(focus) }
                foodGuide(diet, recording: recording)
                meals(diet)
                historyCard(diet)
                connectionCard()
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .kitContainer("kit.diet")
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.dietPlan)
        .navigationBarTitleDisplayMode(.inline)
        .fertilityKitRoute($route)
        .sheet(item: $openMeal) { card in
            DietPlanMealSheet(card: card).withAppEnvironment(container)
        }
    }

    // MARK: Today

    private func todayCard(_ diet: DietPlan, recording: Bool) -> some View {
        let lines = DietPlanPresentation.todayLines(diet.today)
        return KitCard(identifier: "kit.diet.today") {
            KitSectionTitle(YourDietPlanScreenCopy.todayTitle)
            if let checkIn = lines.checkIn {
                KitLine(checkIn).accessibilityIdentifier("kit.diet.today.checkIn")
            } else {
                KitLine(YourDietPlanScreenCopy.todayEmpty).accessibilityIdentifier("kit.diet.today.empty")
            }
            if let groups = lines.groups {
                KitLine(groups).accessibilityIdentifier("kit.diet.today.groups")
            }
            KitSecondaryButton(title: YourDietPlanScreenCopy.track) { route = .dailyLog(kit.today) }
                .disabled(!recording)
                .accessibilityIdentifier("kit.diet.today.track")
            KitNote(diet.recordNote).accessibilityIdentifier("kit.diet.recordNote")
        }
    }

    // MARK: This week's focus

    private func focusCard(_ focus: DietPlanWeekFocus) -> some View {
        KitCard(tinted: true, identifier: "kit.diet.focus") {
            KitSectionTitle(YourDietPlanScreenCopy.focusTitle)
            Text(focus.title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("kit.diet.focus.title")
            KitLine(focus.detail, muted: true)
            KitLine(focus.body)
            if !focus.foodGroups.isEmpty {
                KitLine(YourDietPlanScreenCopy.groupList(focus.foodGroups.map(\.label)), muted: true)
            }
            partHeading(.tryIt)
            KitLine(focus.tryThisWeek)
        }
    }

    // MARK: Food guide

    @ViewBuilder
    private func foodGuide(_ diet: DietPlan, recording: Bool) -> some View {
        KitSectionTitle(YourDietPlanScreenCopy.foodGuideTitle).padding(.top, 8)
        ForEach(diet.foodGuide) { entry in
            KitCard(identifier: "kit.diet.guide.\(entry.group.rawValue)") {
                KitSectionTitle(entry.title)
                partHeading(.learn)
                KitLine(entry.learn)
                partHeading(.examples)
                KitLine(YourDietPlanScreenCopy.groupList(entry.examples))
                partHeading(.tryIt)
                KitLine(entry.tryIt)
                partHeading(.track)
                KitSecondaryButton(title: entry.track.label) { route = .dailyLog(kit.today) }
                    .disabled(!recording)
                    .accessibilityIdentifier("kit.diet.guide.\(entry.group.rawValue).track")
            }
        }
        KitNote(diet.allergyNote, boxed: true).accessibilityIdentifier("kit.diet.allergyNote")
    }

    private func partHeading(_ part: DietPlanGuidePart) -> some View {
        Text(part.heading).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.primary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Meal inspiration

    private func meals(_ diet: DietPlan) -> some View {
        let rows = DietPlanPresentation.mealRows(diet.mealInspiration)
        return VStack(alignment: .leading, spacing: 12) {
            KitSectionTitle(YourDietPlanScreenCopy.mealsTitle)
            ForEach(rows, id: \.category) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.category.label).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                        .accessibilityAddTraits(.isHeader)
                    // Edge to edge, so a card can scroll under the page margin; a plain stack, so
                    // every card is in the tree before it is on the screen.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(row.cards.enumerated()), id: \.offset) { index, card in
                                mealCard(card, category: row.category, index: index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                }
                .kitContainer("kit.diet.meals.category.\(row.category.rawValue)")
            }
        }
        .kitContainer("kit.diet.meals")
        .padding(.top, 8)
    }

    private func mealCard(_ card: DietPlanMealCard, category: DietPlanMealCategory, index: Int) -> some View {
        let lines = DietPlanPresentation.mealLines(card)
        return Button { openMeal = card } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(lines.name).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                Text(lines.meta).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                if let contains = lines.contains {
                    Text(contains).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .frame(minWidth: 200, maxWidth: 240, minHeight: 44, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .kitRow("kit.diet.meal.\(category.rawValue).\(index)", label: FertilityKitCopy.sentences(lines.all))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: History

    private func historyCard(_ diet: DietPlan) -> some View {
        KitCard(identifier: "kit.diet.history") {
            KitSectionTitle(YourDietPlanScreenCopy.historyTitle)
            if let week = diet.history.programmeWeek {
                KitLines(DietPlanPresentation.historyLines(week, title: YourDietPlanScreenCopy.rangeProgrammeWeek),
                         identifier: "kit.diet.history.week")
            }
            KitLines(DietPlanPresentation.historyLines(diet.history.last7Days, title: YourDietPlanScreenCopy.rangeLast7),
                     identifier: "kit.diet.history.last7")
            KitLines(DietPlanPresentation.historyLines(diet.history.last28Days, title: YourDietPlanScreenCopy.rangeLast28),
                     identifier: "kit.diet.history.last28")
        }
    }

    // MARK: Programme connection

    private func connectionCard() -> some View {
        KitCard(identifier: "kit.diet.connection") {
            KitSectionTitle(YourDietPlanScreenCopy.connectionTitle)
            if case .active(_, let week, _) = kit.accessState {
                KitLine(YourDietPlanScreenCopy.connectionWeek(week))
                KitLine(YourDietPlanScreenCopy.connectionBody)
                KitSecondaryButton(title: YourDietPlanScreenCopy.openToday) { kit.open(.fertilityKit) }
                    .accessibilityIdentifier("kit.diet.connection.openToday")
            } else {
                KitLine(YourDietPlanScreenCopy.connectionNotRunning)
            }
        }
    }
}

/// What the screen says, worked out from plain values so it can be tested without drawing it.
enum DietPlanPresentation {

    /// The check-in line and the "n of 6" line. Her own groups make a check-in but are never part of
    /// the six, and nothing recorded means no count at all, never "0 of 6".
    static func todayLines(_ facts: DietPlanDayFacts) -> (checkIn: String?, groups: String?) {
        guard facts.hasCheckIn else { return (nil, nil) }
        let groups = facts.recordedCount > 0
            ? FertilityKitCopy.foodGroupsRecorded(facts.recordedCount, of: facts.groupTotal) : nil
        return (FertilityKitCopy.nutritionCheckInCompleted, groups)
    }

    /// One range of the history: its title, the check-in days, then every group she recorded on at
    /// least one day, in the tracker's order. A group with no days is not listed. With nothing
    /// recorded the range says so.
    static func historyLines(_ facts: DietPlanHistoryFacts, title: String) -> [String] {
        let groups = facts.groupDays.filter { $0.days > 0 }
        if facts.daysWithCheckIn == 0 && groups.isEmpty { return [title, YourDietPlanScreenCopy.historyEmpty] }
        return [title, YourDietPlanScreenCopy.checkInDays(facts.daysWithCheckIn, of: facts.daysElapsed)]
            + groups.map { YourDietPlanScreenCopy.groupDays($0.group.label, $0.days) }
    }

    /// The meal rows in the order of the categories: only a category that has a card, and only a card
    /// whose recipe still exists.
    static func mealRows(
        _ cards: [DietPlanMealCard], recipe: (DietPlanMealCard) -> Recipe? = { $0.recipe }
    ) -> [(category: DietPlanMealCategory, cards: [DietPlanMealCard])] {
        let usable = cards.filter { recipe($0) != nil }
        return DietPlanMealCategory.allCases.compactMap { category in
            let inRow = usable.filter { $0.categories.contains(category) }
            return inRow.isEmpty ? nil : (category, inRow)
        }
    }

    /// The three lines of a meal card: the recipe's name, its time and servings, and the groups it
    /// contains (absent when it names none).
    static func mealLines(_ card: DietPlanMealCard) -> (name: String, meta: String, contains: String?, all: [String]) {
        guard let recipe = card.recipe else { return ("", "", nil, []) }
        let meta = RecipeCopy.meta(minutes: recipe.minutes, serves: recipe.serves)
        let contains = card.foodGroups.isEmpty
            ? nil : YourDietPlanScreenCopy.mealContains(card.foodGroups.map(\.label))
        return (recipe.name, meta, contains, [recipe.name, meta] + (contains.map { [$0] } ?? []))
    }
}

#if DEBUG
#Preview {
    NavigationStack { DietPlanView() }.withKitPreview(day: 23)
}
#endif
