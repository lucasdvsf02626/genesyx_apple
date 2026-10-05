import XCTest
@testable import GenesyxCore

/// The facts Your Diet Plan shows about what she recorded, and the one value the app reads.
final class DietPlanFactsTests: XCTestCase {

    private typealias F = ProgrammeFixtures

    private let allSix = Set(FoodGroup.allCases.map(\.rawValue))

    private func food(_ groups: String...) -> DailyLog { DailyLog(foodGroups: Set(groups)) }

    // ── Today ──

    func testNoLogAndAnEmptyLogAreADayWithNothingRecorded() {
        for log in [nil, DailyLog(), DailyLog(mood: .good, waterMl: 900)] {
            let facts = DietPlanFacts.day(log)
            XCTAssertEqual(facts.recordedGroups, [])
            XCTAssertEqual(facts.recordedCount, 0)
            XCTAssertEqual(facts.groupTotal, 6)
            XCTAssertEqual(facts.customGroups, [])
            XCTAssertFalse(facts.hasCheckIn)
        }
    }

    func testOneGroupIsACheckInAndOneOfSix() {
        let facts = DietPlanFacts.day(food("fruit"))
        XCTAssertEqual(facts.recordedGroups, [.fruit])
        XCTAssertEqual(facts.recordedCount, 1)
        XCTAssertEqual(facts.groupTotal, 6)
        XCTAssertTrue(facts.hasCheckIn)
        XCTAssertEqual(facts.customGroups, [])
    }

    func testSixGroupsComeBackInTheTrackersOrder() {
        let facts = DietPlanFacts.day(DailyLog(foodGroups: allSix))
        XCTAssertEqual(facts.recordedGroups, FoodGroup.allCases)
        XCTAssertEqual(facts.recordedCount, 6)
        XCTAssertTrue(facts.hasCheckIn)
        // The order is the tracker's, whatever order the set happens to hold.
        XCTAssertEqual(DietPlanFacts.day(food("protein", "vegetables")).recordedGroups, [.vegetables, .protein])
    }

    func testACustomGroupOnlyIsACheckInWithNoneOfTheSix() {
        let facts = DietPlanFacts.day(food("Fermented foods"))
        XCTAssertTrue(facts.hasCheckIn)
        XCTAssertEqual(facts.recordedGroups, [])
        XCTAssertEqual(facts.recordedCount, 0)
        XCTAssertEqual(facts.groupTotal, 6)
        XCTAssertEqual(facts.customGroups, ["Fermented foods"])
    }

    func testCustomGroupsAreListedApartAndNeverCountedInTheSix() {
        let facts = DietPlanFacts.day(DailyLog(foodGroups: allSix.union(["Soup", "Herbal tea"])))
        XCTAssertEqual(facts.recordedCount, 6)
        XCTAssertEqual(facts.customGroups, ["Herbal tea", "Soup"])
        XCTAssertTrue(facts.hasCheckIn)
        // A built-in name in other letter case is not the built-in token.
        XCTAssertEqual(DietPlanFacts.day(food("Fruit")).recordedGroups, [])
        XCTAssertEqual(DietPlanFacts.day(food("Fruit")).customGroups, ["Fruit"])
    }

    // ── The same rule as the task engine ──

    /// The nutrition check-in here and the programme's nutrition check-in are one rule. This runs
    /// the task engine on the same logs and holds the two answers together.
    func testTheCheckInRuleIsTheTaskEnginesRule() throws {
        var logs: [DailyLog?] = [nil, DailyLog(), DailyLog(mood: .low), food("Soup"), food("fruit", "Soup"),
                                 DailyLog(foodGroups: allSix), DailyLog(foodGroups: allSix.union(["Soup"]))]
        logs += FoodGroup.allCases.map { DailyLog(foodGroups: [$0.rawValue]) }
        // The check-in counted in every week, so the engine has a status to compare as well.
        let counted = F.content(.nutritionCheckIn, .eligible)

        for log in logs {
            var snapshot = F.snapshotA()
            snapshot.log = log
            let facts = DietPlanFacts.day(log)
            for content in [ProgrammeContent.draft, counted] {
                let plan = F.plan(snapshot, content: content)
                let task = try XCTUnwrap(plan.task(.nutritionCheckIn))
                XCTAssertEqual(facts.hasCheckIn, task.credit == 1, "\(String(describing: log?.foodGroups))")
                XCTAssertEqual(facts.hasCheckIn, task.completionSource == .logFoodGroups)
                XCTAssertTrue(task.credit == 0 || task.credit == 1)
                XCTAssertEqual(facts.recordedCount, plan.foodGroupsRecorded)
                XCTAssertEqual(facts.groupTotal, plan.foodGroupTotal)
            }
            XCTAssertEqual(F.plan(snapshot, content: counted).task(.nutritionCheckIn)?.status,
                           facts.hasCheckIn ? .completed : .eligible)
            // And the count agrees with the tracker row's own arithmetic.
            XCTAssertEqual(facts.recordedCount, NutritionDaySignal.knownFoodGroups(log?.foodGroups ?? []))
        }
    }

    // ── History ──

    /// Programme week 4 is days 22 to 28. Logs on five of the seven days, with two gaps.
    private var weekFourLogs: [CalendarDate: DailyLog] {
        [
            F.date(ofDay: 22): food("vegetables", "protein"),
            F.date(ofDay: 23): food("vegetables"),
            // day 24: nothing
            F.date(ofDay: 25): food("vegetables", "fruit", "Soup"),
            F.date(ofDay: 26): food("Soup"),
            // day 27: a log with no food groups
            F.date(ofDay: 27): DailyLog(mood: .good, waterMl: 1200),
            F.date(ofDay: 28): food("vegetables", "dairy"),
        ]
    }

    func testAWeekWithGapsIsCountedAndNothingElse() throws {
        let facts = try XCTUnwrap(DietPlanFacts.programmeWeek(4, state: F.state, today: F.date(ofDay: 40),
                                                              logsByDate: weekFourLogs))
        XCTAssertEqual(facts.firstDate, F.date(ofDay: 22))
        XCTAssertEqual(facts.lastDate, F.date(ofDay: 28))
        XCTAssertEqual(facts.daysElapsed, 7)
        XCTAssertEqual(facts.daysWithCheckIn, 5)
        // A day with only her own group is a check-in and adds to no built-in group.
        XCTAssertEqual(facts.groupDays.map(\.days), [4, 1, 0, 1, 1, 0])
        XCTAssertEqual(facts.days(recording: .vegetables), 4)
        XCTAssertEqual(facts.days(recording: .starchyCarbs), 0)
    }

    func testTheGroupsAlwaysComeBackInTheTrackersOrder() throws {
        // Oils and fats on every day and vegetables on one: the order does not follow the counts.
        var logs: [CalendarDate: DailyLog] = [:]
        for day in 22...28 { logs[F.date(ofDay: day)] = food("oilsAndFats") }
        logs[F.date(ofDay: 22)] = food("oilsAndFats", "vegetables")
        let facts = try XCTUnwrap(DietPlanFacts.programmeWeek(4, state: F.state, today: F.date(ofDay: 28), logsByDate: logs))
        XCTAssertEqual(facts.groupDays.map(\.group), FoodGroup.allCases)
        XCTAssertEqual(facts.groupDays.map(\.days), [1, 0, 0, 0, 0, 7])
        XCTAssertEqual(facts.groupDays.count, 6)
    }

    func testDaysNotYetElapsedAreLeftOut() throws {
        // Today is day 25: days 22 to 25 have begun, days 26 to 28 have not.
        let facts = try XCTUnwrap(DietPlanFacts.programmeWeek(4, state: F.state, today: F.date(ofDay: 25),
                                                              logsByDate: weekFourLogs))
        XCTAssertEqual(facts.daysElapsed, 4)
        XCTAssertEqual(facts.daysWithCheckIn, 3)
        XCTAssertEqual(facts.groupDays.map(\.days), [3, 1, 0, 1, 0, 0])
        XCTAssertEqual(facts.lastDate, F.date(ofDay: 28))

        // On the first day of the week, one day has begun.
        let first = try XCTUnwrap(DietPlanFacts.programmeWeek(4, state: F.state, today: F.date(ofDay: 22),
                                                              logsByDate: weekFourLogs))
        XCTAssertEqual(first.daysElapsed, 1)
        XCTAssertEqual(first.daysWithCheckIn, 1)

        // A week that has not started yet has no days in it, whatever is logged.
        let ahead = try XCTUnwrap(DietPlanFacts.programmeWeek(5, state: F.state, today: F.date(ofDay: 25),
                                                              logsByDate: [F.date(ofDay: 29): food("fruit")]))
        XCTAssertEqual(ahead.daysElapsed, 0)
        XCTAssertEqual(ahead.daysWithCheckIn, 0)
        XCTAssertEqual(ahead.groupDays.map(\.days), [0, 0, 0, 0, 0, 0])
    }

    func testAProgrammeWeekBoundaryDividesTheDays() throws {
        // Day 7 closes week 1 and day 8 opens week 2.
        let logs = [
            F.date(ofDay: 7): food("fruit"),
            F.date(ofDay: 8): food("protein"),
            F.start.minusDays(1): food("dairy"),
        ]
        let today = F.date(ofDay: 20)
        let one = try XCTUnwrap(DietPlanFacts.programmeWeek(1, state: F.state, today: today, logsByDate: logs))
        let two = try XCTUnwrap(DietPlanFacts.programmeWeek(2, state: F.state, today: today, logsByDate: logs))
        XCTAssertEqual(one.firstDate, F.start)
        XCTAssertEqual(one.lastDate, F.date(ofDay: 7))
        XCTAssertEqual(two.firstDate, F.date(ofDay: 8))
        XCTAssertEqual(two.lastDate, F.date(ofDay: 14))
        XCTAssertEqual(one.daysWithCheckIn, 1)
        XCTAssertEqual(two.daysWithCheckIn, 1)
        XCTAssertEqual(one.days(recording: .fruit), 1)
        XCTAssertEqual(one.days(recording: .protein), 0)
        XCTAssertEqual(two.days(recording: .protein), 1)
        XCTAssertEqual(two.days(recording: .fruit), 0)
        // The day before the programme began belongs to no programme week.
        XCTAssertEqual(one.days(recording: .dairy), 0)
    }

    func testWeekThirteenHasSixDaysAndThereIsNoWeekOutsideOneToThirteen() throws {
        let thirteen = try XCTUnwrap(DietPlanFacts.programmeWeek(13, state: F.state, today: F.date(ofDay: 120), logsByDate: [:]))
        XCTAssertEqual(thirteen.firstDate, F.date(ofDay: 85))
        XCTAssertEqual(thirteen.lastDate, F.date(ofDay: 90))
        XCTAssertEqual(thirteen.daysElapsed, 6)
        XCTAssertNil(DietPlanFacts.programmeWeek(0, state: F.state, today: F.start, logsByDate: [:]))
        XCTAssertNil(DietPlanFacts.programmeWeek(14, state: F.state, today: F.start, logsByDate: [:]))
        XCTAssertNil(DietPlanFacts.programmeWeek(1, state: .notStarted, today: F.start, logsByDate: [:]))
    }

    func testTrailingSevenAndTwentyEightDaysEndToday() {
        let today = CalendarDate(2026, 3, 30)
        var logs: [CalendarDate: DailyLog] = [
            today: food("fruit"),
            today.minusDays(6): food("fruit", "protein"),
            today.minusDays(7): food("protein"),
            today.minusDays(27): food("dairy"),
            today.minusDays(28): food("dairy"),
        ]
        // Tomorrow is never read.
        logs[today.plusDays(1)] = food("vegetables")

        let seven = DietPlanFacts.trailing(days: 7, endingOn: today, logsByDate: logs)
        XCTAssertEqual(seven.firstDate, today.minusDays(6))
        XCTAssertEqual(seven.lastDate, today)
        XCTAssertEqual(seven.daysElapsed, 7)
        XCTAssertEqual(seven.daysWithCheckIn, 2)
        XCTAssertEqual(seven.groupDays.map(\.days), [0, 2, 0, 1, 0, 0])

        let twentyEight = DietPlanFacts.trailing(days: 28, endingOn: today, logsByDate: logs)
        XCTAssertEqual(twentyEight.firstDate, today.minusDays(27))
        XCTAssertEqual(twentyEight.daysElapsed, 28)
        XCTAssertEqual(twentyEight.daysWithCheckIn, 4)
        XCTAssertEqual(twentyEight.groupDays.map(\.days), [0, 2, 0, 2, 1, 0])

        XCTAssertEqual(DietPlanFacts.trailing(days: 1, endingOn: today, logsByDate: logs).daysWithCheckIn, 1)
    }

    func testHistoryOverAnyRangeReadsOnlyTheRange() {
        let first = CalendarDate(2026, 2, 27)
        let last = CalendarDate(2026, 3, 2)   // across the end of February: four days
        let logs = [first: food("fruit"), last: food("fruit"), last.plusDays(1): food("fruit")]
        let facts = DietPlanFacts.history(from: first, through: last, today: last.plusDays(10), logsByDate: logs)
        XCTAssertEqual(facts.daysElapsed, 4)
        XCTAssertEqual(facts.daysWithCheckIn, 2)
        XCTAssertEqual(facts.days(recording: .fruit), 2)
        // A range that ends before it begins holds no days.
        XCTAssertEqual(DietPlanFacts.history(from: last, through: first, today: last, logsByDate: logs).daysElapsed, 0)
    }

    // ── The one value the app reads ──

    func testAnActiveDayAssemblesTodayTheWeeksFocusAndAllThreeRanges() throws {
        let today = F.date(ofDay: 25)
        let plan = DietPlan.assemble(logsByDate: weekFourLogs, state: F.state, today: today)

        XCTAssertEqual(plan.today.recordedGroups, [.vegetables, .fruit])
        XCTAssertEqual(plan.today.customGroups, ["Soup"])
        XCTAssertTrue(plan.today.hasCheckIn)

        let focus = try XCTUnwrap(plan.weekFocus)
        let own = try XCTUnwrap(ProgrammeContent.draft.week(4)?.nutritionFocus)
        XCTAssertEqual(focus.week, 4)
        XCTAssertEqual(focus.title, own.title)
        XCTAssertEqual(focus.body, DietPlanContent.draft.weekTexts[3].body)

        XCTAssertEqual(plan.foodGuide.map(\.group), FoodGroup.allCases)
        XCTAssertEqual(plan.mealInspiration.map(\.recipeID), RecipeContent.all.map(\.id))
        XCTAssertEqual(plan.allergyNote, DietPlanContent.draft.allergyNote)

        let week = try XCTUnwrap(plan.history.programmeWeek)
        XCTAssertEqual(week.firstDate, F.date(ofDay: 22))
        XCTAssertEqual(week.daysElapsed, 4)
        XCTAssertEqual(week.daysWithCheckIn, 3)
        XCTAssertEqual(plan.history.last7Days.daysElapsed, 7)
        XCTAssertEqual(plan.history.last7Days.daysWithCheckIn, 3)
        XCTAssertEqual(plan.history.last28Days.daysElapsed, 28)
        XCTAssertEqual(plan.history.last28Days.firstDate, today.minusDays(27))
    }

    func testTheRecordNoteIsTheTrackersOwnLine() {
        let plan = DietPlan.assemble(logsByDate: [:], state: F.state, today: F.date(ofDay: 3))
        XCTAssertEqual(plan.recordNote, FoodLogCopy.footnote)
        XCTAssertTrue(plan.recordNote.hasPrefix("A record, not a target. Nothing here is scored"))
    }

    func testOutsideTheProgrammeThereIsNoWeekFocusAndNoProgrammeWeek() {
        let logs = [F.date(ofDay: 95): food("fruit")]
        let stopped = ProgrammeState(startedOn: F.start, stoppedOn: F.date(ofDay: 30))
        let cases: [(ProgrammeState, CalendarDate)] = [
            (.notStarted, F.date(ofDay: 95)),           // not started
            (F.state, F.start.minusDays(2)),            // before the start
            (F.state, F.date(ofDay: 95)),               // after day 90
            (stopped, F.date(ofDay: 40)),               // stopped
        ]
        for (state, today) in cases {
            let plan = DietPlan.assemble(logsByDate: logs, state: state, today: today)
            XCTAssertNil(plan.weekFocus)
            XCTAssertNil(plan.history.programmeWeek)
            // Everything that does not depend on the programme is still there.
            XCTAssertEqual(plan.foodGuide.count, 6)
            XCTAssertEqual(plan.mealInspiration.count, 8)
            XCTAssertEqual(plan.history.last7Days.daysElapsed, 7)
            XCTAssertEqual(plan.history.last28Days.daysElapsed, 28)
        }
        let after = DietPlan.assemble(logsByDate: logs, state: F.state, today: F.date(ofDay: 95))
        XCTAssertEqual(after.today.recordedGroups, [.fruit])
        XCTAssertEqual(after.history.last7Days.daysWithCheckIn, 1)
    }

    func testTheFirstAndLastProgrammeDaysHaveTheirOwnWeek() {
        XCTAssertEqual(DietPlan.assemble(logsByDate: [:], state: F.state, today: F.start).weekFocus?.week, 1)
        let last = DietPlan.assemble(logsByDate: [:], state: F.state, today: F.date(ofDay: 90))
        XCTAssertEqual(last.weekFocus?.week, 13)
        XCTAssertEqual(last.history.programmeWeek?.daysElapsed, 6)
    }
}
