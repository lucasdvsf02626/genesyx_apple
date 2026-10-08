import XCTest
import GenesyxCore
@testable import Genesyx

/// Your Diet Plan: what the screen says about a day, a week and a history, worked out from the same
/// plain values the view reads.
@MainActor
final class DietPlanScreenTests: XCTestCase {

    private let today = CalendarDate(2026, 10, 6)

    private func log(_ groups: [String], on date: CalendarDate) -> [CalendarDate: DailyLog] {
        [date: DailyLog(foodGroups: Set(groups))]
    }

    private func diet(_ context: FertilityKitContext) -> DietPlan {
        DietPlan.assemble(logsByDate: context.planInput.logsByDate, state: context.planInput.state, today: context.today)
    }

    // MARK: Today

    func testACustomGroupOnlyIsACheckInWithNoCountOfSix() {
        let context = KitFixture.context(today: today, day: 4, logs: log(["my own group"], on: today))
        let lines = DietPlanPresentation.todayLines(diet(context).today)
        XCTAssertEqual(lines.checkIn, "Nutrition check-in: completed")
        XCTAssertNil(lines.groups, "her own groups are never part of n of 6")
        XCTAssertFalse((lines.checkIn ?? "").contains("of 6"))
    }

    func testNothingRecordedShowsNeitherALineNorACount() {
        let lines = DietPlanPresentation.todayLines(diet(KitFixture.context(today: today, day: 4)).today)
        XCTAssertNil(lines.checkIn)
        XCTAssertNil(lines.groups)
    }

    func testRecordedGroupsAreCountedOutOfSixAndCustomOnesAreNot() {
        let context = KitFixture.context(today: today, day: 4,
                                         logs: log(["vegetables", "protein", "my own group"], on: today))
        XCTAssertEqual(DietPlanPresentation.todayLines(diet(context).today).groups, "Food groups recorded: 2 of 6")
    }

    // MARK: History

    func testHistoryListsOnlyGroupsWithDaysInTheTrackersOrder() {
        var logs: [CalendarDate: DailyLog] = [:]
        for back in 0..<3 { logs.merge(log(["protein", "vegetables"], on: today.minusDays(back))) { $1 } }
        logs.merge(log(["fruit"], on: today.minusDays(4))) { $1 }
        let facts = diet(KitFixture.context(today: today, day: 10, logs: logs)).history.last7Days
        let lines = DietPlanPresentation.historyLines(facts, title: "Last 7 days")
        XCTAssertEqual(lines, ["Last 7 days", "Nutrition check-in on 4 of 7 days",
                               "Vegetables recorded on 3 days", "Fruit recorded on 1 day", "Protein recorded on 3 days"])
        XCTAssertFalse(lines.joined().contains("Dairy"))
        XCTAssertFalse(lines.joined().contains("Oils"))
    }

    func testARangeWithNothingRecordedSaysSoAndListsNothingElse() {
        let facts = diet(KitFixture.context(today: today, day: 10)).history.last28Days
        XCTAssertEqual(DietPlanPresentation.historyLines(facts, title: "Last 28 days"),
                       ["Last 28 days", "Nothing recorded in this period."])
    }

    func testTheProgrammeWeekHistoryExistsOnlyWhileActive() {
        XCTAssertNotNil(diet(KitFixture.context(today: today, day: 23)).history.programmeWeek)
        XCTAssertNil(diet(KitFixture.context(today: today)).history.programmeWeek)
        XCTAssertNil(diet(KitFixture.context(today: today, day: 91)).history.programmeWeek)
    }

    // MARK: This week's focus

    func testTheWeekFocusIsAbsentOutsideAnActiveProgrammeDay() {
        XCTAssertNil(diet(KitFixture.context(today: today)).weekFocus, "not started")
        XCTAssertNil(diet(KitFixture.context(today: today, startsIn: 3)).weekFocus, "scheduled")
        XCTAssertNil(diet(KitFixture.context(today: today, day: 91)).weekFocus, "after day 90")
        XCTAssertNil(diet(KitFixture.context(today: today, state: ProgrammeState(startedOn: today.minusDays(5), stoppedOn: today.minusDays(1)))).weekFocus, "stopped")
    }

    func testTheWeekFocusIsPresentOnDay23WithTheWeeksTitle() throws {
        let focus = try XCTUnwrap(diet(KitFixture.context(today: today, day: 23)).weekFocus)
        XCTAssertEqual(focus.week, 4)
        XCTAssertFalse(focus.title.isEmpty)
        XCTAssertEqual(focus.title, DietPlanContent.draft.weekFocus(forWeek: 4)?.title)
    }

    // MARK: Meals

    func testEveryCategoryThatHasCardsShowsThemInOrder() {
        let cards = DietPlanContent.draft.mealCards
        let rows = DietPlanPresentation.mealRows(cards)
        XCTAssertFalse(rows.isEmpty)
        let order = DietPlanMealCategory.allCases
        XCTAssertEqual(rows.map(\.category), order.filter { category in cards.contains { $0.categories.contains(category) } })
        for row in rows {
            XCTAssertEqual(row.cards, cards.filter { $0.categories.contains(row.category) })
        }
    }

    func testACardWhoseRecipeIsMissingIsDroppedAndAnEmptyCategoryWithIt() throws {
        let cards = DietPlanContent.draft.mealCards
        let dropped = try XCTUnwrap(cards.first)
        let rows = DietPlanPresentation.mealRows(cards, recipe: { $0.recipeID == dropped.recipeID ? nil : $0.recipe })
        XCTAssertFalse(rows.flatMap(\.cards).contains(dropped))
        XCTAssertTrue(DietPlanPresentation.mealRows(cards, recipe: { _ in nil }).isEmpty)
    }

    func testAMealCardReadsNameTimeAndGroupsOnly() throws {
        let card = try XCTUnwrap(DietPlanContent.draft.mealCards.first)
        let recipe = try XCTUnwrap(card.recipe)
        let lines = DietPlanPresentation.mealLines(card)
        XCTAssertEqual(lines.name, recipe.name)
        XCTAssertEqual(lines.meta, RecipeCopy.meta(minutes: recipe.minutes, serves: recipe.serves))
        XCTAssertEqual(lines.contains, YourDietPlanScreenCopy.mealContains(card.foodGroups.map(\.label)))
        XCTAssertFalse(lines.all.joined().lowercased().contains("focus food"))
    }

    // MARK: The promise

    func testTheRecordNoteIsTheTrackersOwnFootnote() {
        XCTAssertEqual(diet(KitFixture.context(today: today, day: 4)).recordNote, FoodLogCopy.footnote)
    }
}
