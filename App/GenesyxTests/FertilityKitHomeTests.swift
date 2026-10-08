import XCTest
import GenesyxCore
@testable import Genesyx

/// The Fertility Kit home and its task list, as pure values: what each access state shows, how a
/// task row reads, and where it leads.
@MainActor
final class FertilityKitHomeTests: XCTestCase {

    private let today = CalendarDate(2026, 10, 6)
    private let calendar = Calendar.autoupdatingCurrent

    private func rows(_ kit: FertilityKitContext, onDayPage: Bool = false) -> [ProgrammeTaskPresentation.Row] {
        ProgrammeTaskPresentation.dailyRows(kit.todayPlan()!, in: kit, onDayPage: onDayPage)
    }

    private func row(_ id: String, in kit: FertilityKitContext, onDayPage: Bool = false) -> ProgrammeTaskPresentation.Row? {
        rows(kit, onDayPage: onDayPage).first { $0.id == id }
    }

    private func label(_ row: ProgrammeTaskPresentation.Row) -> String {
        FertilityKitCopy.rowLabel(row.name, status: row.status, details: row.detailLines)
    }

    private func groups(_ count: Int) -> Set<String> {
        Set(FoodGroup.allCases.prefix(count).map(\.rawValue))
    }

    private func settings(cycleDay: Int) -> CycleSettings {
        CycleSettings(lastPeriodDate: today.minusDays(cycleDay - 1), cycleLength: 28, periodLength: 5)
    }

    // MARK: - Access decides

    func testAccessDecidesWhatTheHomeShows() {
        let without = KitFixture.context(today: today, day: 23, access: false)
        XCTAssertEqual(without.accessState, .noAccess)
        XCTAssertNotNil(without.planInput.state.startedOn, "a start date is stored, and changes nothing")
        XCTAssertTrue(FertilityKitHomePresentation.showsAccessCard(without.accessState))
        XCTAssertNil(FertilityKitHomePresentation.body(for: without.accessState))
        XCTAssertNil(FertilityKitHomePresentation.weekFocus(for: without))
        XCTAssertEqual(FertilityKitHomePresentation.rows(for: without), [])
        XCTAssertEqual(FertilityKitHomePresentation.weekFigureLines(without), [])

        let with = KitFixture.context(today: today, day: 23)
        guard case .active(let day, let week, _) = with.accessState else { return XCTFail("not active") }
        XCTAssertEqual([day, week], [23, 4])
        XCTAssertFalse(FertilityKitHomePresentation.showsAccessCard(with.accessState))
        XCTAssertNotNil(FertilityKitHomePresentation.weekFocus(for: with))
        XCTAssertFalse(FertilityKitHomePresentation.rows(for: with).isEmpty)
        XCTAssertFalse(rows(with).isEmpty)
    }

    func testEachStateSaysItsOwnLine() {
        let cases: [(FertilityKitContext, String?)] = [
            (KitFixture.context(today: today), FertilityKitHomeCopy.notStartedBody),
            (KitFixture.context(today: today, startsIn: 3), FertilityKitHomeCopy.scheduledBody),
            (KitFixture.context(today: today, day: 91), FertilityKitHomeCopy.completedBody),
            (KitFixture.context(today: today, state: ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(2))),
             FertilityKitHomeCopy.stoppedBody),
            (KitFixture.context(today: today, day: 23), nil),
            (KitFixture.context(today: today, day: 23, access: false), nil),
        ]
        for (kit, expected) in cases {
            XCTAssertEqual(FertilityKitHomePresentation.body(for: kit.accessState)?.text, expected, "\(kit.accessState)")
        }
    }

    // MARK: - This week's focus

    func testThisWeeksFocusIsWeekFoursThemeAndPurposeVerbatim() throws {
        let week = try XCTUnwrap(ProgrammeContent.draft.week(4))
        let focus = try XCTUnwrap(FertilityKitHomePresentation.weekFocus(for: KitFixture.context(today: today, day: 23)))
        XCTAssertEqual(focus.theme, week.themeTitle)
        XCTAssertEqual(focus.purpose, week.purpose)
    }

    func testThisWeeksFocusIsAbsentOutsideAnActiveProgramme() {
        let stopped = ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(2))
        for kit in [KitFixture.context(today: today), KitFixture.context(today: today, startsIn: 3),
                    KitFixture.context(today: today, day: 91), KitFixture.context(today: today, state: stopped)] {
            XCTAssertNil(FertilityKitHomePresentation.weekFocus(for: kit), "\(kit.accessState)")
        }
    }

    // MARK: - A row says everything it draws

    func testTheNutritionRowLabelHoldsItsNameStatusAndEveryDetailLine() throws {
        let kit = KitFixture.context(today: today, day: 23, logs: [today: DailyLog(foodGroups: groups(4))])
        let nutrition = try XCTUnwrap(row("nutritionCheckIn", in: kit))
        XCTAssertEqual(label(nutrition),
                       "Nutrition check-in, done. Nutrition check-in: completed. Food groups recorded: 4 of 6")
        XCTAssertEqual(nutrition.detailLines, ["Nutrition check-in: completed", "Food groups recorded: 4 of 6"])
    }

    func testTheNutritionRowShowsNoNumberUntilAGroupIsRecorded() throws {
        let none = KitFixture.context(today: today, day: 23)
        let nutrition = try XCTUnwrap(row("nutritionCheckIn", in: none))
        XCTAssertEqual(nutrition.status, "Optional")
        XCTAssertEqual(nutrition.detailLines, [])
        XCTAssertFalse(label(nutrition).contains("of 6"))
        // A custom group alone is a check-in, and "0 of 6" is never shown.
        let custom = KitFixture.context(today: today, day: 23, logs: [today: DailyLog(foodGroups: ["homemade soup"])])
        let own = try XCTUnwrap(row("nutritionCheckIn", in: custom))
        XCTAssertEqual(own.status, "Done")
        XCTAssertEqual(own.detailLines, [FertilityKitCopy.nutritionCheckInCompleted])
        XCTAssertFalse(label(own).contains("of 6"))
        // Some groups: the number appears.
        let some = KitFixture.context(today: today, day: 23, logs: [today: DailyLog(foodGroups: groups(2))])
        XCTAssertTrue(label(try XCTUnwrap(row("nutritionCheckIn", in: some))).hasSuffix("Food groups recorded: 2 of 6"))
    }

    // MARK: - Which rows exist

    func testTasksThatDoNotApplyAreDropped() {
        let answeredNo = KitFixture.context(today: today, day: 23, quizAnswers: ["supplements": "no"])
        XCTAssertNil(row("supplementCheckIn", in: answeredNo))
        XCTAssertNotNil(row("supplementCheckIn", in: KitFixture.context(today: today, day: 23, quizAnswers: ["supplements": "yes"])))

        let inWindow = KitFixture.context(today: today, day: 23, cycleSettings: settings(cycleDay: 10))
        XCTAssertNotNil(row("lhTest", in: inWindow))
        let withoutScanning = KitFixture.context(today: today, day: 23, scan: false, cycleSettings: settings(cycleDay: 10))
        XCTAssertNil(row("lhTest", in: withoutScanning))
        let outsideWindow = KitFixture.context(today: today, day: 23, cycleSettings: settings(cycleDay: 2))
        XCTAssertNil(row("lhTest", in: outsideWindow))
        for kit in [answeredNo, inWindow, withoutScanning, outsideWindow] {
            XCTAssertFalse(rows(kit).contains { $0.status.isEmpty }, "every shown row has a status")
        }
    }

    func testAnOptionalTaskIsDoneOrOptionalAndNeverChangesTodaysCount() throws {
        let before = KitFixture.context(today: today, day: 23)
        let after = KitFixture.context(today: today, day: 23, logs: [today: DailyLog(foodGroups: groups(3))])
        XCTAssertEqual(try XCTUnwrap(row("nutritionCheckIn", in: before)).status, "Optional")
        XCTAssertEqual(try XCTUnwrap(row("nutritionCheckIn", in: after)).status, "Done")
        XCTAssertEqual(ProgrammeConsistency.today(before.todayPlan()!), ProgrammeConsistency.today(after.todayPlan()!))
    }

    func testHydrationAtFifteenHundredOfTwentyFourHundredReadsPartDone() throws {
        var kit = KitFixture.context(today: today, day: 23, logs: [today: DailyLog(waterMl: 1_500)])
        kit.planInput.waterGoalMl = 2_400
        XCTAssertEqual(try XCTUnwrap(row("hydrationCheckIn", in: kit)).status, "Part done")
        let lines = FertilityKitHomePresentation.progressLines(kit.todayPlan()!, consentActive: true)
        XCTAssertEqual(lines.last, "1 activity partly completed")
        XCTAssertEqual(ProgrammeConsistency.today(kit.todayPlan()!).partlyCompleted, 1)
    }

    func testThePhTaskIsOnlyAWeeklyRow() throws {
        let kit = KitFixture.context(today: today, day: 23)
        let plan = try XCTUnwrap(kit.todayPlan())
        XCTAssertNil(row("phTest", in: kit), "not part of the day")
        let weekly = ProgrammeTaskPresentation.weeklyRows(plan, in: kit)
        XCTAssertEqual(weekly.map(\.id), ["phTest"])
        XCTAssertEqual(weekly.first?.status, "This week: to do")
        let reading = PhReading(phValue: 4.2, recordedAt: today.toDate(calendar: calendar))
        let done = KitFixture.context(today: today, day: 23, phReadings: [reading])
        let doneRows = ProgrammeTaskPresentation.weeklyRows(try XCTUnwrap(done.todayPlan()), in: done)
        XCTAssertEqual(doneRows.first?.status, "This week: done")
        XCTAssertFalse(label(try XCTUnwrap(doneRows.first)).contains("4.2"), "a value is never printed")
    }

    func testNoPregnancyTestRowAndNoRowNamesIntimacy() {
        for day in [43, 47, 23, 40] {
            let kit = KitFixture.context(today: today, day: day, logs: [today: DailyLog(sexualActivity: true)])
            let shown = rows(kit)
            XCTAssertFalse(shown.contains { $0.id == "pregnancyTestRelatedAction" }, "day \(day)")
            XCTAssertFalse(shown.contains { $0.name.lowercased().contains("pregnan") || $0.name.lowercased().contains("intima") })
        }
    }

    // MARK: - The hub

    func testTheHubRowsOfEachState() {
        func ids(_ kit: FertilityKitContext) -> [String] { FertilityKitHomePresentation.rows(for: kit).map(\.id) }
        let stopped = ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(2))
        XCTAssertEqual(ids(KitFixture.context(today: today)), ["guide", "dietPlan", "picture", "cycleHistory"])
        XCTAssertEqual(ids(KitFixture.context(today: today, startsIn: 3)), ["guide", "dietPlan", "picture", "cycleHistory"])
        XCTAssertEqual(ids(KitFixture.context(today: today, day: 23)), ["guide", "dietPlan", "reviews", "picture", "cycleHistory"])
        XCTAssertEqual(ids(KitFixture.context(today: today, day: 91)),
                       ["ninetyDayReview", "reviews", "picture", "dietPlan", "guide", "days", "dailyLog", "cycleHistory"])
        XCTAssertEqual(ids(KitFixture.context(today: today, state: stopped)),
                       ["guide", "dietPlan", "picture", "reviews", "cycleHistory"])
        XCTAssertEqual(ids(KitFixture.context(today: today, day: 23, access: false)), [])
    }

    func testTheHubKeepsItsConditionalRowsConditional() {
        func ids(_ kit: FertilityKitContext) -> [String] { FertilityKitHomePresentation.rows(for: kit).map(\.id) }
        XCTAssertFalse(ids(KitFixture.context(today: today, day: 23, cycleHistory: false)).contains("cycleHistory"))
        XCTAssertFalse(ids(KitFixture.context(today: today, day: 91, cycleHistory: false)).contains("cycleHistory"))
        XCTAssertFalse(ids(KitFixture.context(today: today)).contains("reviews"), "no start date, no reviews")
        XCTAssertFalse(ids(KitFixture.context(today: today, day: 23)).contains("ninetyDayReview"))
        XCTAssertTrue(ids(KitFixture.context(today: today, day: 91)).contains("ninetyDayReview"))
    }

    func testTheHubRowsLeadWhereTheirNamesSay() throws {
        let kit = KitFixture.context(today: today, day: 91)
        let routes = Dictionary(uniqueKeysWithValues: FertilityKitHomePresentation.rows(for: kit).map { ($0.id, $0.route) })
        XCTAssertEqual(routes["guide"], .kit(.kitGuide))
        XCTAssertEqual(routes["dietPlan"], .kit(.kitDietPlan))
        XCTAssertEqual(routes["reviews"], .kit(.kitReviews))
        XCTAssertEqual(routes["ninetyDayReview"], .kit(.kitNinetyDayReview))
        XCTAssertEqual(routes["picture"], .kit(.kitPicture))
        XCTAssertEqual(routes["cycleHistory"], .kit(.kitCycleHistory))
        XCTAssertEqual(routes["days"], .kit(.kitToday))
        XCTAssertEqual(routes["dailyLog"], .dailyLog(today))
    }

    // MARK: - Nothing she records reorders or changes a status

    func testTheGoalChangesTheOrderOnly() throws {
        let plain = KitFixture.context(today: today, day: 23)
        let trying = KitFixture.context(today: today, day: 23, quizAnswers: ["stage": "trying"])
        func statuses(_ kit: FertilityKitContext) -> [String: String] {
            Dictionary(uniqueKeysWithValues: rows(kit).map { ($0.id, $0.status) })
        }
        XCTAssertEqual(statuses(plain), statuses(trying))
        XCTAssertEqual(ProgrammeConsistency.today(plain.todayPlan()!), ProgrammeConsistency.today(trying.todayPlan()!))
    }

    func testTheLevelsAndChoicesInsideARecordChangeNoStatusAndNoCount() {
        func log(_ mood: Mood, _ energy: EnergyLevel, _ symptoms: Set<String>, _ sleep: Int, _ intimacy: Bool) -> DailyLog {
            DailyLog(mood: mood, energy: energy, symptoms: symptoms, sleepMinutes: sleep, waterMl: 2_400,
                     sexualActivity: intimacy, foodGroups: groups(2))
        }
        let first = KitFixture.context(today: today, day: 23, logs: [today: log(.good, .normal, ["Fatigue"], 445, false)])
        let second = KitFixture.context(today: today, day: 23, logs: [today: log(.great, .high, ["Bloating", "Cramps"], 300, true)])
        XCTAssertEqual(rows(first).map(\.status), rows(second).map(\.status))
        XCTAssertEqual(rows(first).map(\.id), rows(second).map(\.id))
        XCTAssertEqual(ProgrammeConsistency.today(first.todayPlan()!), ProgrammeConsistency.today(second.todayPlan()!))
        XCTAssertEqual(rows(first).map(\.detailLines), rows(second).map(\.detailLines))
    }

    // MARK: - Figures

    func testTodaysLinesNeverHoldAPercentage() {
        let full = DailyLog(mood: .good, energy: .normal, sleepMinutes: 450, waterMl: 2_400)
        for logs in [[:], [today: full]] as [[CalendarDate: DailyLog]] {
            let kit = KitFixture.context(today: today, day: 23, logs: logs)
            let lines = FertilityKitHomePresentation.progressLines(kit.todayPlan()!, consentActive: true)
            XCTAssertFalse(lines.isEmpty)
            XCTAssertFalse(lines.joined().contains("%"))
        }
    }

    func testTheWeekFigureHasAPercentageOnlyFromFiveCountedActivities() {
        // Day 23 is the second day of week 4, so the week so far is day 22. Scanning is off, so
        // four daily activities count, and a pH reading in the week adds the weekly one.
        let yesterday = DailyLog(mood: .good, energy: .normal, sleepMinutes: 450, waterMl: 2_400)
        let reading = PhReading(phValue: 4.2, recordedAt: today.toDate(calendar: calendar))

        let four = KitFixture.context(today: today, day: 23, scan: false, logs: [today.minusDays(1): yesterday])
        let fourLines = FertilityKitHomePresentation.weekFigureLines(four)
        XCTAssertEqual(four.report().week.counted, 4)
        XCTAssertFalse(fourLines.isEmpty)
        XCTAssertFalse(fourLines.joined().contains("%"), "\(fourLines)")

        let five = KitFixture.context(today: today, day: 23, scan: false, logs: [today.minusDays(1): yesterday],
                                      phReadings: [reading])
        let fiveLines = FertilityKitHomePresentation.weekFigureLines(five)
        XCTAssertEqual(five.report().week.counted, 5)
        XCTAssertTrue(fiveLines.joined().contains("%"), "\(fiveLines)")

        // A little credit over five counted activities rounds to nought, and a nought is never
        // shown. Scanning on and yesterday inside the predicted window makes the ovulation test
        // the fifth.
        let sip = DailyLog(waterMl: 1)
        let nought = KitFixture.context(today: today, day: 23, logs: [today.minusDays(1): sip],
                                        cycleSettings: settings(cycleDay: 11))
        let noughtLines = FertilityKitHomePresentation.weekFigureLines(nought)
        XCTAssertEqual(nought.report().week.counted, 5)
        XCTAssertEqual(nought.report().week.percentage, 0)
        XCTAssertFalse(noughtLines.isEmpty)
        XCTAssertFalse(noughtLines.joined().contains("%"), "\(noughtLines)")
    }

    // MARK: - Where a task leads

    func testTheLessonRowRoutesToTodaysPageExceptOnThePageItself() throws {
        let dayOne = KitFixture.context(today: today, day: 1)
        XCTAssertEqual(try XCTUnwrap(row("programmeLesson", in: dayOne)).route, .kit(.kitToday))
        XCTAssertEqual(try XCTUnwrap(row("programmeLesson", in: dayOne, onDayPage: true)).route, .unavailable)

        let testGuidance = KitFixture.context(today: today, day: 40)
        let guide = try XCTUnwrap(row("fertilityKitEducation", in: testGuidance))
        XCTAssertEqual(guide.name, "Fertility Kit guide")
        XCTAssertEqual(guide.route, .kit(.kitToday))
        XCTAssertEqual(try XCTUnwrap(row("fertilityKitEducation", in: testGuidance, onDayPage: true)).route, .unavailable)
    }

    func testOtherRowsKeepTheirRouteOnTheDayPage() throws {
        let kit = KitFixture.context(today: today, day: 23)
        XCTAssertEqual(try XCTUnwrap(row("moodCheckIn", in: kit, onDayPage: true)).route, .dailyLog(today))
        XCTAssertEqual(try XCTUnwrap(row("hydrationCheckIn", in: kit)).route, .hydration)
        XCTAssertEqual(try XCTUnwrap(row("nutritionCheckIn", in: kit)).route, .kit(.kitDietPlan))
    }

    // MARK: - Consent

    func testWithConsentWithdrawnThereAreNoRowsAndNoFigure() throws {
        let kit = KitFixture.context(today: today, day: 23, consent: false)
        let plan = try XCTUnwrap(kit.todayPlan())
        XCTAssertEqual(rows(kit), [])
        XCTAssertEqual(ProgrammeTaskPresentation.weeklyRows(plan, in: kit), [])
        XCTAssertEqual(FertilityKitHomePresentation.progressLines(plan, consentActive: false), [])
        XCTAssertEqual(FertilityKitHomePresentation.weekFigureLines(kit), [])
    }
}
