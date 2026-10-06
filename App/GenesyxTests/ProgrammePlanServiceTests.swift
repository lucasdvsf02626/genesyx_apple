import XCTest
@testable import Genesyx
import GenesyxCore

/// The plan service (the real trackers' records in, the core engine's plans and figures out) and
/// the adapter that reads the repositories. The engine and the consistency arithmetic are tested
/// in the core; here the worked days of `ProgrammeConsistencyTests` are reproduced from records.
@MainActor
final class ProgrammePlanServiceTests: XCTestCase {

    // The core fixtures' user: started 1 June 2026, so day 23 is in programme week 4 (days 22 to 28).
    private let start = CalendarDate(2026, 6, 1)
    private var state: ProgrammeState { ProgrammeState(startedOn: start, contentVersion: ProgrammeContent.draft.version) }

    private func date(_ day: Int) -> CalendarDate { ProgrammeCalendar.date(ofDay: day, startedOn: start) }

    /// Cycle settings that put programme day `day` on cycle day `cycleDay`. With a 28-day cycle
    /// the predicted fertile window is cycle days 9 to 15.
    private func settings(day: Int, onCycleDay cycleDay: Int) -> CycleSettings {
        CycleSettings(lastPeriodDate: date(day).minusDays(cycleDay - 1), cycleLength: 28, periodLength: 5)
    }

    /// Day A's log: water 1500 of 2400 ml, three food groups, no symptoms.
    private let logA = DailyLog(mood: .good, energy: .normal, sleepMinutes: 440, supplements: ["folate"],
                                waterMl: 1500, foodGroups: ["vegetables", "fruit", "protein"])
    /// Day B's log: water on goal, no supplement.
    private let logB = DailyLog(mood: .okay, energy: .high, sleepMinutes: 400, waterMl: 2400)

    private func emptyInput(todayDay: Int) -> ProgrammePlanInput {
        ProgrammePlanInput(state: state, today: date(todayDay))
    }

    private func dayPlan(_ day: Int, _ input: ProgrammePlanInput) -> ProgrammeDayPlan? {
        ProgrammePlanService.plan(on: date(day), input: input)
    }

    private func daySnapshot(_ day: Int, _ input: ProgrammePlanInput) -> ProgrammeDaySnapshot {
        ProgrammePlanService.snapshot(on: date(day), input: input)
    }

    private func task(_ plan: ProgrammeDayPlan?, _ category: ProgrammeTaskCategory) -> ProgrammeTask? {
        plan?.tasks.first { $0.category == category }
    }

    private func weekly(_ plan: ProgrammeDayPlan?, _ category: ProgrammeTaskCategory) -> ProgrammeTask? {
        plan?.weeklyTasks.first { $0.category == category }
    }

    private func counted(_ plan: ProgrammeDayPlan?) -> [ProgrammeTaskCategory] {
        (plan?.tasks ?? []).filter(\.isCounted).map(\.category).sorted { $0.rawValue < $1.rawValue }
    }

    private let fiveDaily: [ProgrammeTaskCategory] =
        [.energyCheckIn, .hydrationCheckIn, .moodCheckIn, .sleepCheckIn, .supplementCheckIn]

    // MARK: - The three worked days

    /// Day A: no scan features, a pH reading earlier in the week, cycle day 20.
    private func inputA(todayDay: Int = 23) -> ProgrammePlanInput {
        var input = emptyInput(todayDay: todayDay)
        input.logsByDate = [date(23): logA]
        input.phReadingDates = [date(22)]
        input.cycleSettings = settings(day: 23, onCycleDay: 20)
        input.quizAnswers = ["supplements": "yes"]
        return input
    }

    /// Day A: 4.625 of 5 = 93 per cent.
    func testWorkedDayA() throws {
        let plan = try XCTUnwrap(dayPlan(23, inputA()))
        XCTAssertEqual(plan.day, 23)
        XCTAssertEqual(plan.week, 4)
        XCTAssertEqual(counted(plan), fiveDaily)
        XCTAssertEqual(task(plan, .hydrationCheckIn)?.credit, 0.625)
        XCTAssertEqual(task(plan, .lhTest)?.notApplicableReason, .featureUnavailable)
        XCTAssertEqual(weekly(plan, .phTest)?.status, .completed)
        XCTAssertEqual(task(plan, .nutritionCheckIn)?.status, .optional)
        XCTAssertEqual(plan.foodGroupsRecorded, 3)

        let figure = ProgrammeConsistency.day(plan)
        XCTAssertEqual(figure.counted, 5)
        XCTAssertEqual(figure.credit, 4.625)
        XCTAssertEqual(figure.percentage, 93)
    }

    /// Day B: 5 of 6 = 83 per cent. Inside the predicted window, scanning available, an LH result
    /// on the date, no supplement, and no pH reading yet this week.
    func testWorkedDayB() throws {
        var input = emptyInput(todayDay: 23)
        input.logsByDate = [date(23): logB]
        input.lhResultDates = [date(23)]
        input.cycleSettings = settings(day: 23, onCycleDay: 11)
        input.quizAnswers = ["supplements": "yes"]
        input.scanFeaturesAvailable = true

        let plan = try XCTUnwrap(dayPlan(23, input))
        XCTAssertEqual(counted(plan), (fiveDaily + [.lhTest]).sorted { $0.rawValue < $1.rawValue })
        XCTAssertEqual(task(plan, .lhTest)?.status, .completed)
        XCTAssertEqual(task(plan, .supplementCheckIn)?.status, .eligible)
        XCTAssertEqual(weekly(plan, .phTest)?.status, .eligible)

        let figure = ProgrammeConsistency.day(plan)
        XCTAssertEqual(figure.counted, 6)
        XCTAssertEqual(figure.credit, 5)
        XCTAssertEqual(figure.percentage, 83)
    }

    /// Day C: the Day A profile with nothing logged. 0 of 5 once the day is over; counts only
    /// while it is still today.
    func testWorkedDayC() throws {
        var input = inputA(todayDay: 24)
        input.logsByDate = [:]
        let figure = ProgrammeConsistency.day(try XCTUnwrap(dayPlan(23, input)))
        XCTAssertEqual(figure.counted, 5)
        XCTAssertEqual(figure.credit, 0)
        XCTAssertEqual(figure.percentage, 0)
        XCTAssertTrue(figure.nothingRecorded)

        input.today = date(23)
        let today = ProgrammePlanService.report(input).today
        XCTAssertEqual(today?.completed, 0)
        XCTAssertEqual(today?.total, 5)
    }

    // MARK: - The worked week

    /// Week 4 from one set of records, read on day 29: a day like B (day 22, the last day of the
    /// predicted window), five like A (days 23 to 27) and one like C (day 28), with one pH
    /// reading in the week. 5 x 4.625 + 5 + 0 + 1 = 29.125 over 5 x 5 + 6 + 5 + 1 = 37.
    private func workedWeek() -> ProgrammePlanInput {
        var input = emptyInput(todayDay: 29)
        input.logsByDate = Dictionary(uniqueKeysWithValues: (23...27).map { (date($0), logA) })
        input.logsByDate[date(22)] = logB
        input.phReadingDates = [date(24)]
        input.lhResultDates = [date(22)]
        input.cycleSettings = settings(day: 22, onCycleDay: 15)
        input.quizAnswers = ["supplements": "yes"]
        input.scanFeaturesAvailable = true
        return input
    }

    func testWorkedWeek() {
        let plans = ProgrammePlanService.plans(workedWeek())
        XCTAssertEqual(plans.map(\.day), Array(1...29))

        let week = ProgrammeConsistency.period(plans, days: 22...28, todayDay: 29)
        XCTAssertEqual(week.counted, 37)
        XCTAssertEqual(week.credit, 29.125)
        XCTAssertEqual(week.percentage, 79)
        XCTAssertEqual(week.completed, 26)
        XCTAssertEqual(week.partlyCompleted, 5)

        let daily = plans.filter { (22...28).contains($0.day) }.map { ProgrammeConsistency.day($0).percentage }
        XCTAssertEqual(daily, [83, 93, 93, 93, 93, 93, 0])
    }

    // MARK: - pH: once per programme week

    func testAPhReadingCountsForItsWholeProgrammeWeekAndNoOtherDay() {
        var input = emptyInput(todayDay: 40)
        func daysWithAReading() -> [Int] {
            (-5...100).filter { daySnapshot($0, input).phReadingExistsThisProgrammeWeek }
        }
        XCTAssertEqual(daysWithAReading(), [], "no reading, no week")

        for readingDay in [8, 11, 14] {
            input.phReadingDates = [date(readingDay)]
            XCTAssertEqual(daysWithAReading(), Array(8...14), "a reading on day \(readingDay)")
        }
        // The engine reads it as the week's task, on every day of that week and on no other.
        input.phReadingDates = [date(8)]
        XCTAssertEqual(weekly(dayPlan(8, input), .phTest)?.status, .completed)
        XCTAssertEqual(weekly(dayPlan(14, input), .phTest)?.completionSource, .phReading)
        XCTAssertEqual(weekly(dayPlan(7, input), .phTest)?.status, .skipped)
        XCTAssertEqual(weekly(dayPlan(15, input), .phTest)?.status, .skipped)

        // The day before the start and day 91 belong to no programme week.
        input.phReadingDates = [date(0), date(91), date(-30), date(200)]
        XCTAssertEqual(daysWithAReading(), [])

        // Week 13 has six days.
        for readingDay in [85, 90] {
            input.phReadingDates = [date(readingDay)]
            XCTAssertEqual(daysWithAReading(), Array(85...90), "a reading on day \(readingDay)")
        }
        input.phReadingDates = [date(1), date(1), date(84)]
        XCTAssertEqual(daysWithAReading(), Array(1...7) + Array(78...84))
    }

    func testAPhReadingIsNotApplicableWhereItCannotBeLogged() {
        var input = emptyInput(todayDay: 40)
        input.phReadingDates = [date(8)]
        input.phLoggingAvailable = false
        XCTAssertEqual(task(dayPlan(8, input), .phTest)?.notApplicableReason, .featureUnavailable)
    }

    // MARK: - LH: the date itself

    func testAnLhResultCountsForItsOwnDateOnly() {
        var input = emptyInput(todayDay: 24)
        input.lhResultDates = [date(23)]
        XCTAssertEqual((15...30).filter { daySnapshot($0, input).lhResultExistsForDate }, [23])

        // Days 22 to 24 are cycle days 10 to 12: inside the predicted window.
        input.cycleSettings = settings(day: 23, onCycleDay: 11)
        input.scanFeaturesAvailable = true
        XCTAssertEqual(task(dayPlan(23, input), .lhTest)?.status, .completed)
        XCTAssertEqual(task(dayPlan(23, input), .lhTest)?.completionSource, .lhResult)
        XCTAssertEqual(task(dayPlan(22, input), .lhTest)?.status, .skipped)
        XCTAssertEqual(task(dayPlan(24, input), .lhTest)?.status, .eligible)
    }

    func testWithoutScanFeaturesAnLhResultCompletesNothing() {
        var input = emptyInput(todayDay: 24)
        input.lhResultDates = [date(23)]
        input.cycleSettings = settings(day: 23, onCycleDay: 11)
        input.scanFeaturesAvailable = false

        XCTAssertTrue(daySnapshot(23, input).lhResultExistsForDate, "the record is still there")
        let lh = task(dayPlan(23, input), .lhTest)
        XCTAssertEqual(lh?.status, .notApplicable)
        XCTAssertEqual(lh?.notApplicableReason, .featureUnavailable)
        XCTAssertEqual(lh?.credit, 0)
    }

    // MARK: - Periods

    func testAPeriodRecordCoversItsDatesAndNoOthers() {
        var input = emptyInput(todayDay: 95)
        input.periods = [
            PeriodRecord(startDate: date(3), endDate: date(6)),            // a start and an end
            PeriodRecord(startDate: date(20)),                             // a start alone
            PeriodRecord(startDate: date(40), source: .seeded),            // the seeded record counts
            PeriodRecord(startDate: date(60), endDate: date(57)),          // an end before its start
        ]
        func covered() -> [Int] { (-5...100).filter { daySnapshot($0, input).periodRecordExistsForDate } }
        XCTAssertEqual(covered(), [3, 4, 5, 6, 20, 40, 60])

        // The engine offers it and never counts it.
        XCTAssertEqual(task(dayPlan(4, input), .periodLog)?.status, .optional)
        XCTAssertEqual(task(dayPlan(4, input), .periodLog)?.completionSource, .periodRecord)
        XCTAssertEqual(task(dayPlan(7, input), .periodLog)?.isDone, false)

        // A period that began before day 1, and one that runs past day 90 with an end far away.
        input.periods = [
            PeriodRecord(startDate: date(-2), endDate: date(2)),
            PeriodRecord(startDate: date(89), endDate: date(89).plusDays(5_000_000)),
        ]
        XCTAssertEqual(covered(), [1, 2, 89, 90])
    }

    // MARK: - Goal and supplements

    func testTheGoalComesFromTheStoredStageAnswer() {
        var input = emptyInput(todayDay: 23)
        XCTAssertEqual(ProgrammePlanService.goal(input), .understandMyCycle, "no answer")
        let expected: [(String, ProgrammeGoalEmphasis)] = [
            ("exploring", .understandMyCycle), ("preparing", .prepareForPregnancy), ("trying", .tryingToConceive),
            ("support", .understandMyCycle), ("something-newer", .understandMyCycle),
        ]
        for (stage, goal) in expected {
            input.quizAnswers = ["stage": stage, "supplements": "yes"]
            XCTAssertEqual(ProgrammePlanService.goal(input), goal, stage)
            XCTAssertEqual(ProgrammePlanService.goal(input), ProgrammeGoalEmphasis(storedStage: stage))
        }
        // It reaches the engine: the goal's first activity leads the list, and no figure moves.
        input.quizAnswers = ["stage": "preparing", "supplements": "yes"]
        let preparing = dayPlan(23, input)
        XCTAssertEqual(preparing?.tasks.first?.category, .nutritionCheckIn)
        input.quizAnswers = ["stage": "trying", "supplements": "yes"]
        let trying = dayPlan(23, input)
        XCTAssertEqual(trying?.tasks.first?.category, .lhTest)
        XCTAssertEqual(preparing.map(ProgrammeConsistency.day), trying.map(ProgrammeConsistency.day))
    }

    func testTheSupplementsAnswerDecidesWhetherSupplementsAreCounted() {
        var input = inputA(todayDay: 24)
        for answer in ["yes", "some"] {
            input.quizAnswers = ["supplements": answer]
            XCTAssertEqual(daySnapshot(23, input).supplementsAnswer, answer)
            XCTAssertEqual(task(dayPlan(23, input), .supplementCheckIn)?.status, .completed, answer)
        }
        input.quizAnswers = ["supplements": "no"]
        XCTAssertEqual(task(dayPlan(23, input), .supplementCheckIn)?.notApplicableReason, .onboardingAnswer)
        XCTAssertEqual(counted(dayPlan(23, input)).count, 4)

        let unanswered: [[String: String]] = [[:], ["supplements": "guidance"], ["supplements": "something-newer"],
                                              ["stage": "trying"]]
        for answers in unanswered {
            input.quizAnswers = answers
            XCTAssertEqual(daySnapshot(23, input).supplementsAnswer, answers["supplements"])
            XCTAssertEqual(task(dayPlan(23, input), .supplementCheckIn)?.status, .optional, "\(answers)")
        }
    }

    /// A known limit, pinned so that it stays a decision. Only today's answer is held and it is
    /// applied to every date. Thirty-nine days with mood, energy, sleep and water recorded read
    /// 156 of 161 while the answer is "no"; the same days read 156 of 200 once it is "yes", with
    /// a supplements figure of 0 of 39.
    func testChangingTheSupplementsAnswerRecountsEveryEarlierDay() {
        var input = emptyInput(todayDay: 40)
        let log = DailyLog(mood: .good, energy: .normal, sleepMinutes: 440, waterMl: 2_400)
        input.logsByDate = Dictionary(uniqueKeysWithValues: (1...39).map { (date($0), log) })

        input.quizAnswers = ["supplements": "no"]
        let before = ProgrammePlanService.report(input)
        XCTAssertEqual(before.programme.counted, 161, "39 days of four check-ins, and the pH reading of weeks 1 to 5")
        XCTAssertEqual(before.programme.credit, 156)
        XCTAssertEqual(before.programme.percentage, 97)
        XCTAssertNil(before.categories[.supplementCheckIn])

        input.quizAnswers = ["supplements": "yes"]
        let after = ProgrammePlanService.report(input)
        XCTAssertEqual(after.programme.counted, 200)
        XCTAssertEqual(after.programme.credit, 156)
        XCTAssertEqual(after.programme.percentage, 78)
        XCTAssertEqual(after.categories[.supplementCheckIn]?.counted, 39)
        XCTAssertEqual(after.categories[.supplementCheckIn]?.credit, 0)
    }

    // MARK: - The predicted window: the period that was current on the date

    private func cycleSettings(lastPeriodDay day: Int, length: Int = 28) -> CycleSettings {
        CycleSettings(lastPeriodDate: date(day), cycleLength: length, periodLength: 5)
    }

    /// The programme days on which the ovulation test is counted.
    private func lhCountedDays(_ input: ProgrammePlanInput) -> [Int] {
        ProgrammePlanService.plans(input).filter { task($0, .lhTest)?.isCounted == true }.map(\.day)
    }

    /// Her last period started on day 8, so with a 28-day cycle the predicted window is days 16
    /// to 22, and she tested on each of them. Her next period arrives on day 39 (a 31-day cycle)
    /// and recording it moves her last period date. The seven days she was asked for stay the
    /// seven days counted.
    func testRecordingTheNextPeriodLeavesThePredictedWindowOfEarlierDaysWhereItWas() {
        var input = emptyInput(todayDay: 38)
        input.scanFeaturesAvailable = true
        input.lhResultDates = (16...22).map(date)
        input.periods = [PeriodRecord(startDate: date(8))]
        input.cycleSettings = cycleSettings(lastPeriodDay: 8)

        XCTAssertEqual(lhCountedDays(input), Array(16...22))
        var figure = ProgrammePlanService.report(input).categories[.lhTest]
        XCTAssertEqual(figure?.counted, 7)
        XCTAssertEqual(figure?.credit, 7)

        input.today = date(40)
        input.periods.append(PeriodRecord(startDate: date(39)))
        input.cycleSettings = cycleSettings(lastPeriodDay: 39)

        XCTAssertEqual(lhCountedDays(input), Array(16...22))
        figure = ProgrammePlanService.report(input).categories[.lhTest]
        XCTAssertEqual(figure?.counted, 7)
        XCTAssertEqual(figure?.credit, 7)
        XCTAssertEqual(figure?.percentage, 100)

        // The engine is handed the start of the period that was current on the date, with the
        // lengths she has set now. From day 39 that is her settings exactly.
        XCTAssertEqual(daySnapshot(38, input).cycleSettings, cycleSettings(lastPeriodDay: 8))
        XCTAssertEqual(daySnapshot(39, input).cycleSettings, input.cycleSettings)
        XCTAssertEqual(daySnapshot(120, input).cycleSettings, input.cycleSettings)

        // The new cycle has its own predicted window, days 47 to 53.
        input.today = date(60)
        XCTAssertEqual(lhCountedDays(input), Array(16...22) + Array(47...53))
    }

    /// Her first recorded start is day 20, so days 1 to 6 are read back from it (cycle days 10 to
    /// 15 of the cycle before). They are read from that same start after she records the next one.
    func testADateBeforeHerFirstRecordedStartIsReadFromThatStart() {
        var input = emptyInput(todayDay: 27)
        input.scanFeaturesAvailable = true
        input.periods = [PeriodRecord(startDate: date(20))]
        input.cycleSettings = cycleSettings(lastPeriodDay: 20)
        XCTAssertEqual(lhCountedDays(input), Array(1...6))

        input.today = date(52)
        input.periods = [PeriodRecord(startDate: date(51)), PeriodRecord(startDate: date(20))]   // in any order
        input.cycleSettings = cycleSettings(lastPeriodDay: 51)
        XCTAssertEqual(lhCountedDays(input), Array(1...6) + Array(28...34))
        XCTAssertEqual(daySnapshot(1, input).cycleSettings, cycleSettings(lastPeriodDay: 20))
        XCTAssertEqual(daySnapshot(-40, input).cycleSettings, cycleSettings(lastPeriodDay: 20))
    }

    /// Known limits, pinned. The cycle length is today's for every date, so an edit moves the
    /// earlier windows. And where she has no period record at all, her last period date is
    /// today's for every date too.
    func testACycleLengthEditAndADateWithNoPeriodRecordStillMoveEarlierWindows() {
        var input = emptyInput(todayDay: 38)
        input.scanFeaturesAvailable = true
        input.periods = [PeriodRecord(startDate: date(8))]
        input.cycleSettings = cycleSettings(lastPeriodDay: 8)
        XCTAssertEqual(lhCountedDays(input), Array(16...22))

        input.cycleSettings = cycleSettings(lastPeriodDay: 8, length: 30)
        XCTAssertEqual(lhCountedDays(input), Array(18...24), "a 30-day cycle: cycle days 11 to 17")

        input.periods = []
        input.cycleSettings = cycleSettings(lastPeriodDay: 39)
        XCTAssertEqual(lhCountedDays(input), Array(19...25), "her settings as they are")
        XCTAssertEqual(daySnapshot(20, input).cycleSettings, input.cycleSettings)

        // With no settings there is nothing to predict from, whatever the period records say.
        input.periods = [PeriodRecord(startDate: date(8))]
        input.cycleSettings = nil
        XCTAssertNil(daySnapshot(20, input).cycleSettings)
        XCTAssertEqual(task(dayPlan(20, input), .lhTest)?.notApplicableReason, .noCycleSettings)
    }

    // MARK: - The water goal and the content

    func testTheInputsWaterGoalIsTheOneTheEngineIsGiven() {
        var input = emptyInput(todayDay: 24)
        input.logsByDate = [date(23): DailyLog(waterMl: 1_200)]
        XCTAssertEqual(task(dayPlan(23, input), .hydrationCheckIn)?.credit, 0.5, "1200 of the default 2400 ml")

        input.waterGoalMl = 1_200
        XCTAssertEqual(daySnapshot(23, input).waterGoalMl, 1_200)
        XCTAssertEqual(task(dayPlan(23, input), .hydrationCheckIn)?.credit, 1)
    }

    /// The content passed in is the content used, for one plan, for the plans and for the report.
    func testTheContentPassedInIsTheContentUsed() {
        let draft = ProgrammeContent.draft
        let weekOneOnly = ProgrammeContent(
            version: "week-one-only", weeks: draft.weeks.filter { $0.number == 1 }, phaseTitles: draft.phaseTitles,
            kindCopy: draft.kindCopy, kindReflections: draft.kindReflections, kindReadMinutes: draft.kindReadMinutes,
            testGuidanceWeeks: draft.testGuidanceWeeks)
        let input = inputA()

        XCTAssertNotNil(ProgrammePlanService.plan(on: date(8), input: input))
        XCTAssertNil(ProgrammePlanService.plan(on: date(8), input: input, content: weekOneOnly))
        XCTAssertEqual(ProgrammePlanService.plans(input, content: weekOneOnly).map(\.day), Array(1...7))

        let report = ProgrammePlanService.report(input, content: weekOneOnly)
        XCTAssertEqual(report, ProgrammeConsistency.report(state: input.state, today: input.today,
                                                           plans: ProgrammePlanService.plans(input, content: weekOneOnly)))
        XCTAssertNotEqual(report, ProgrammePlanService.report(input))
    }

    // MARK: - Explicit completions

    func testAReadLessonAndAViewedReviewCompleteTheirTasksAndMoveNoFigure() {
        let before = workedWeek()
        var after = before
        after.completions = ProgrammeCompletions(lessonsRead: ["programme-day-023"], weeklyReviewsViewed: [4],
                                                 ninetyDayReviewViewed: true)

        XCTAssertEqual(task(dayPlan(23, before), .programmeLesson)?.isDone, false)
        XCTAssertEqual(task(dayPlan(23, after), .programmeLesson)?.isDone, true)
        XCTAssertEqual(task(dayPlan(23, after), .programmeLesson)?.completionSource, .explicitRecord)
        XCTAssertEqual(task(dayPlan(23, after), .programmeLesson)?.status, .optional)
        XCTAssertEqual(task(dayPlan(22, after), .programmeLesson)?.isDone, false, "one lesson, one day")

        XCTAssertEqual(task(dayPlan(28, before), .weeklyReview)?.isDone, false)
        XCTAssertEqual(task(dayPlan(28, after), .weeklyReview)?.isDone, true)
        XCTAssertEqual(task(dayPlan(28, after), .weeklyReview)?.completionSource, .explicitRecord)
        XCTAssertEqual(task(dayPlan(21, after), .weeklyReview)?.isDone, false, "week 3 was not viewed")

        XCTAssertEqual(daySnapshot(23, after).completedLessonIDs, ["programme-day-023"])
        XCTAssertEqual(daySnapshot(23, after).completedReviewWeeks, [4])
        XCTAssertEqual(ProgrammePlanService.report(after), ProgrammePlanService.report(before))
    }

    // MARK: - Plans and the report

    func testPlansAreEmptyBeforeThereIsAProgrammeDay() {
        XCTAssertEqual(ProgrammePlanService.plans(ProgrammePlanInput(state: .notStarted, today: date(23))), [])
        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: 0)), [], "the day before the start")
        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: -40)), [])
        XCTAssertNil(ProgrammePlanService.plan(on: date(0), input: emptyInput(todayDay: 23)))
        XCTAssertNil(ProgrammePlanService.plan(on: date(91), input: emptyInput(todayDay: 95)))
    }

    func testPlansRunFromDayOneToTodayInOrder() {
        let input = inputA()
        let plans = ProgrammePlanService.plans(input)
        XCTAssertEqual(plans.map(\.day), Array(1...23))
        XCTAssertEqual(plans.map(\.date), (1...23).map(date))
        XCTAssertEqual(plans.last, dayPlan(23, input), "each one is the engine's plan for that date")
        XCTAssertEqual(plans.first, ProgrammeTaskEngine.plan(
            on: date(1), state: state, today: date(23), goal: .understandMyCycle,
            snapshot: ProgrammePlanService.snapshot(on: date(1), input: input)))

        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: 1)).map(\.day), [1])
        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: 90)).map(\.day), Array(1...90))
    }

    func testFromDayNinetyOneThereAreAllNinetyPlans() {
        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: 91)).map(\.day), Array(1...90))
        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: 95)).map(\.day), Array(1...90))
        XCTAssertEqual(ProgrammePlanService.plans(emptyInput(todayDay: 4_000)).count, 90)
    }

    func testPlansStopAtAStopMarker() {
        var input = emptyInput(todayDay: 40)
        input.state.stoppedOn = date(11)
        XCTAssertEqual(ProgrammePlanService.plans(input).map(\.day), Array(1...10))
        input.state.stoppedOn = date(1)
        XCTAssertEqual(ProgrammePlanService.plans(input), [])
    }

    func testTheReportIsTheCoreReportOverTheSamePlans() {
        for input in [workedWeek(), inputA(), emptyInput(todayDay: 95), ProgrammePlanInput(state: .notStarted, today: date(5))] {
            XCTAssertEqual(ProgrammePlanService.report(input),
                           ProgrammeConsistency.report(state: input.state, today: input.today,
                                                       plans: ProgrammePlanService.plans(input)))
        }
        // Read on day 29 the current week is week 5, which has no finished day yet.
        let report = ProgrammePlanService.report(workedWeek())
        XCTAssertEqual(report.week.withheld, .nothingCounted)
        XCTAssertEqual(report.categories[.lhTest]?.counted, 7, "days 16 to 22, the dates inside the predicted window")
        XCTAssertEqual(report.categories[.lhTest]?.credit, 1, "and the one of them with a result")
        XCTAssertEqual(report.categories[.phTest]?.counted, 4, "one a week for weeks 1 to 4")
        XCTAssertEqual(report.categories[.phTest]?.credit, 1)
        XCTAssertEqual(report.today?.completed, 0)
        XCTAssertEqual(report.today?.total, 5)
    }

    // MARK: - Consent

    /// Today's answer is applied to every date: while consent is withdrawn nothing is applicable
    /// and there is no figure to show.
    func testWithConsentWithdrawnNothingIsApplicableAndNothingIsCounted() {
        var input = workedWeek()
        input.completions = ProgrammeCompletions(lessonsRead: ["programme-day-023"], weeklyReviewsViewed: [4])
        input.periods = [PeriodRecord(startDate: date(8), endDate: date(12))]
        input.consentActive = false

        let plans = ProgrammePlanService.plans(input)
        XCTAssertEqual(plans.count, 29)
        for plan in plans {
            for item in plan.tasks + plan.weeklyTasks {
                XCTAssertEqual(item.status, .notApplicable, "day \(plan.day) \(item.category)")
                XCTAssertEqual(item.notApplicableReason, .consentWithdrawn, "day \(plan.day) \(item.category)")
            }
        }
        let report = ProgrammePlanService.report(input)
        XCTAssertEqual(report.programme.counted, 0)
        XCTAssertEqual(report.programme.withheld, .nothingCounted)
        XCTAssertNil(report.programme.percentage)
        XCTAssertTrue(report.categories.isEmpty)
        XCTAssertEqual(report.today?.total, 0)
    }

    // MARK: - What is never read

    func testIntimacyNeverChangesAPlanOrAFigure() {
        let without = workedWeek()
        var with = without
        with.logsByDate = without.logsByDate.mapValues { log in
            var log = log
            log.sexualActivity = true
            return log
        }
        // And on days with no other entry at all.
        var only = without
        for day in [1, 9, 28] { only.logsByDate[date(day)] = DailyLog(sexualActivity: true) }
        var none = without
        for day in [1, 9, 28] { none.logsByDate[date(day)] = DailyLog() }

        XCTAssertNotEqual(with, without, "the two inputs do differ")
        XCTAssertEqual(ProgrammePlanService.plans(with), ProgrammePlanService.plans(without))
        XCTAssertEqual(ProgrammePlanService.report(with), ProgrammePlanService.report(without))
        XCTAssertEqual(ProgrammePlanService.plans(only), ProgrammePlanService.plans(none))
        XCTAssertEqual(ProgrammePlanService.report(only), ProgrammePlanService.report(none))
    }

    /// Pregnancy test records and intimacy cannot move anything because they cannot get in.
    /// Adding a field here is a decision, not a refactor.
    func testTheInputHasExactlyTheseThirteenFields() {
        let labels = Mirror(reflecting: ProgrammePlanInput(state: .notStarted, today: start)).children.compactMap(\.label)
        XCTAssertEqual(labels, [
            "state", "today", "completions", "logsByDate", "waterGoalMl", "phReadingDates", "lhResultDates",
            "periods", "cycleSettings", "quizAnswers", "consentActive", "scanFeaturesAvailable", "phLoggingAvailable",
        ])
        let input = ProgrammePlanInput(state: .notStarted, today: start)
        XCTAssertTrue(type(of: input.phReadingDates) == [CalendarDate].self, "a date per reading, never a value")
        XCTAssertTrue(type(of: input.lhResultDates) == [CalendarDate].self, "a date per result, never a result")
        XCTAssertEqual(input.waterGoalMl, TrackingEngine.defaultWaterGoalMl)
        XCTAssertFalse(input.scanFeaturesAvailable)
    }

    // MARK: - A long history

    /// A smoke check only. The guarantee is the single index built per input.
    func testALargeHistoryStillBuildsNinetyPlansPromptly() {
        var input = emptyInput(todayDay: 95)
        input.phReadingDates = (0..<6_000).map { start.plusDays($0 % 700 - 300) }
        input.lhResultDates = (0..<6_000).map { start.plusDays(($0 * 7) % 700 - 300) }
        input.periods = (0..<400).map { PeriodRecord(startDate: start.plusDays($0 * 28 - 5_600), endDate: start.plusDays($0 * 28 - 5_596)) }
        input.logsByDate = Dictionary(uniqueKeysWithValues: (-300..<400).map { (start.plusDays($0), logA) })
        input.cycleSettings = settings(day: 1, onCycleDay: 1)
        input.scanFeaturesAvailable = true

        let began = Date()
        let plans = ProgrammePlanService.plans(input)
        let report = ProgrammePlanService.report(input)
        let elapsed = Date().timeIntervalSince(began)

        XCTAssertEqual(plans.count, 90)
        XCTAssertNotNil(report.programme.percentage)
        XCTAssertLessThan(elapsed, 2, "ninety plans and a report took \(elapsed) s")
    }

    // MARK: - The adapter, over the real repositories

    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    /// A local-only container as the app builds one, with consent given, and a programme
    /// repository beside it wired the way the container will wire it.
    private func container(_ store: LocalStore) -> (AppContainer, ProgrammeRepository) {
        let c = AppContainer(store: store, backend: nil, monitorNetwork: false, cycleHistory: true)
        c.consent.grant()
        let programme = ProgrammeRepository(store: store)
        programme.isAccessActive = { true }
        programme.isCollectionPermitted = { [consent = c.consent] in consent.isActive }
        return (c, programme)
    }

    private func adapter(_ c: AppContainer, _ programme: ProgrammeRepository, scan: Bool = false,
                         calendar: Calendar? = nil) -> ProgrammePlanSource {
        ProgrammePlanSource(programme: programme, dailyLog: c.dailyLog, ph: c.ph, lh: c.lh, periods: c.periods,
                            cycle: c.cycle, prefs: c.prefs, consent: c.consent, scanFeaturesAvailable: scan,
                            calendar: calendar ?? utc)
    }

    private func instant(_ date: CalendarDate, _ hour: Int, _ minute: Int = 0, in calendar: Calendar? = nil) -> Date {
        (calendar ?? utc).date(from: DateComponents(year: date.year, month: date.month, day: date.day,
                                                   hour: hour, minute: minute))!
    }

    func testWritesMadeThroughTheRealTrackersCompleteTheMatchingTasks() throws {
        let (c, programme) = container(makeStore())
        let today = date(23)
        let cycle = settings(day: 23, onCycleDay: 11)   // last period started on day 13

        XCTAssertEqual(programme.start(today: start), .started(start))
        XCTAssertTrue(programme.markLessonRead("programme-day-023"))
        XCTAssertTrue(c.prefs.recordQuizAnswers(["stage": "trying", "supplements": "yes"]))
        XCTAssertEqual(c.periods.recordStart(date(13), today: today), .append(date(13)))
        XCTAssertTrue(c.cycle.upsert(cycle))
        c.dailyLog.setWater(1_200, on: date(22))
        XCTAssertTrue(c.dailyLog.upsert(
            DailyLog(mood: .good, energy: .normal, sleepMinutes: 440, supplements: ["folate"], waterMl: 2_400,
                     foodGroups: ["vegetables", "fruit"]), on: today))
        XCTAssertTrue(c.ph.create(PhReading(phValue: 4.2, recordedAt: instant(date(22), 12))))
        XCTAssertTrue(c.lh.create(LhResult(recordedAt: instant(today, 8), classification: .low)))

        let input = adapter(c, programme, scan: true).input(today: today)

        XCTAssertEqual(input.state, programme.state)
        XCTAssertEqual(input.state.startedOn, start)
        XCTAssertEqual(input.today, today)
        XCTAssertEqual(input.completions, ProgrammeCompletions(lessonsRead: ["programme-day-023"]))
        XCTAssertEqual(input.logsByDate, c.dailyLog.logByDate)
        XCTAssertEqual(input.logsByDate[date(22)]?.waterMl, 1_200)
        XCTAssertEqual(input.phReadingDates, [date(22)])
        XCTAssertEqual(input.lhResultDates, [today])
        XCTAssertEqual(input.periods, [PeriodRecord(startDate: date(13))])
        XCTAssertEqual(input.cycleSettings, cycle)
        XCTAssertEqual(input.quizAnswers, ["stage": "trying", "supplements": "yes"])
        XCTAssertTrue(input.consentActive)
        XCTAssertTrue(input.phLoggingAvailable)

        XCTAssertEqual(ProgrammePlanService.goal(input), .tryingToConceive)
        let plan = try XCTUnwrap(ProgrammePlanService.plan(on: today, input: input))
        XCTAssertEqual(task(plan, .moodCheckIn)?.completionSource, .logMood)
        XCTAssertEqual(task(plan, .energyCheckIn)?.completionSource, .logEnergy)
        XCTAssertEqual(task(plan, .sleepCheckIn)?.completionSource, .logSleepMinutes)
        XCTAssertEqual(task(plan, .hydrationCheckIn)?.completionSource, .logWaterMl)
        XCTAssertEqual(task(plan, .supplementCheckIn)?.completionSource, .logSupplements)
        XCTAssertEqual(task(plan, .nutritionCheckIn)?.completionSource, .logFoodGroups)
        XCTAssertEqual(task(plan, .lhTest)?.completionSource, .lhResult)
        XCTAssertEqual(task(plan, .cycleCheckIn)?.completionSource, .cycleSettings)
        XCTAssertEqual(task(plan, .programmeLesson)?.completionSource, .explicitRecord)
        XCTAssertEqual(weekly(plan, .phTest)?.completionSource, .phReading)
        XCTAssertEqual(plan.foodGroupsRecorded, 2)
        XCTAssertEqual(ProgrammeConsistency.day(plan).counted, 6)
        XCTAssertEqual(ProgrammeConsistency.day(plan).completed, 6)

        let dayBefore = ProgrammePlanService.plan(on: date(22), input: input)
        XCTAssertEqual(task(dayBefore, .hydrationCheckIn)?.credit, 0.5, "1200 of the 2400 ml goal")
        XCTAssertEqual(task(dayBefore, .moodCheckIn)?.status, .skipped)
        XCTAssertEqual(task(ProgrammePlanService.plan(on: date(13), input: input), .periodLog)?.completionSource, .periodRecord)
        XCTAssertEqual(task(ProgrammePlanService.plan(on: date(14), input: input), .periodLog)?.isDone, false)
        XCTAssertEqual(ProgrammePlanService.plans(input).map(\.day), Array(1...23))
    }

    func testUrineReadingsAndDeletedRecordsAreNotCounted() {
        let (c, programme) = container(makeStore())
        programme.start(today: start)
        let source = adapter(c, programme, scan: true)

        XCTAssertTrue(c.ph.create(PhReading(phValue: 6.5, recordedAt: instant(date(9), 9), measurementType: .urine)))
        let deletedReading = PhReading(phValue: 4.4, recordedAt: instant(date(16), 9))
        XCTAssertTrue(c.ph.create(deletedReading))
        let deletedResult = LhResult(recordedAt: instant(date(16), 9), classification: .positive)
        XCTAssertTrue(c.lh.create(deletedResult))

        var input = source.input(today: date(40))
        XCTAssertEqual(input.phReadingDates, [date(16)], "the urine reading is never seen")
        XCTAssertEqual(input.lhResultDates, [date(16)])
        XCTAssertFalse(ProgrammePlanService.snapshot(on: date(9), input: input).phReadingExistsThisProgrammeWeek)

        c.ph.delete(id: deletedReading.id)
        c.lh.delete(id: deletedResult.id)

        input = source.input(today: date(40))
        XCTAssertEqual(input.phReadingDates, [])
        XCTAssertEqual(input.lhResultDates, [])
        XCTAssertFalse(ProgrammePlanService.snapshot(on: date(16), input: input).phReadingExistsThisProgrammeWeek)
        XCTAssertFalse(ProgrammePlanService.snapshot(on: date(16), input: input).lhResultExistsForDate)

        // One that stays, so "nothing counted" is not all this shows.
        XCTAssertTrue(c.ph.create(PhReading(phValue: 4.4, recordedAt: instant(date(30), 9))))
        XCTAssertEqual(source.input(today: date(40)).phReadingDates, [date(30)])
    }

    /// Day 7 is the last day of programme week 1. Half past eleven that night and half past
    /// midnight are one hour apart and two programme weeks, in the calendar the phone is in.
    func testAReadingBelongsToItsLocalDay() {
        var plusTwo = Calendar(identifier: .gregorian)
        plusTwo.timeZone = TimeZone(secondsFromGMT: 2 * 3_600)!
        let (c, programme) = container(makeStore())
        programme.start(today: start)

        let lateEvening = instant(date(7), 23, 30, in: plusTwo)
        let afterMidnight = instant(date(8), 0, 30, in: plusTwo)
        XCTAssertEqual(afterMidnight.timeIntervalSince(lateEvening), 3_600)
        XCTAssertTrue(c.ph.create(PhReading(phValue: 4.2, recordedAt: lateEvening)))
        XCTAssertTrue(c.lh.create(LhResult(recordedAt: lateEvening, classification: .low)))

        var input = adapter(c, programme, calendar: plusTwo).input(today: date(20))
        func weekHasAReading(_ day: Int) -> Bool {
            ProgrammePlanService.snapshot(on: date(day), input: input).phReadingExistsThisProgrammeWeek
        }
        XCTAssertEqual(input.phReadingDates, [date(7)])
        XCTAssertEqual(input.lhResultDates, [date(7)])
        XCTAssertTrue(weekHasAReading(1))
        XCTAssertFalse(weekHasAReading(8))

        XCTAssertTrue(c.ph.create(PhReading(phValue: 4.3, recordedAt: afterMidnight)))
        input = adapter(c, programme, calendar: plusTwo).input(today: date(20))
        XCTAssertEqual(input.phReadingDates, [date(7), date(8)])
        XCTAssertTrue(weekHasAReading(7))
        XCTAssertTrue(weekHasAReading(14))
        XCTAssertFalse(weekHasAReading(15))

        // The same two instants on a phone in UTC are both on day 7.
        XCTAssertEqual(adapter(c, programme, calendar: utc).input(today: date(20)).phReadingDates, [date(7), date(7)])
    }

    func testTheWaterGoalIsTheConstantAndTheScanFlagAndConsentPassThrough() {
        let (c, programme) = container(makeStore())
        programme.start(today: start)

        XCTAssertEqual(adapter(c, programme).input(today: start).waterGoalMl, TrackingEngine.defaultWaterGoalMl)
        XCTAssertEqual(TrackingEngine.defaultWaterGoalMl, 2_400)
        XCTAssertFalse(adapter(c, programme, scan: false).input(today: start).scanFeaturesAvailable)
        XCTAssertTrue(adapter(c, programme, scan: true).input(today: start).scanFeaturesAvailable)
        XCTAssertEqual(adapter(c, programme).input(today: date(5)).today, date(5))

        XCTAssertTrue(adapter(c, programme).input(today: start).consentActive)
        c.consent.withdraw()
        XCTAssertFalse(adapter(c, programme).input(today: start).consentActive)
        XCTAssertEqual(adapter(c, programme).input(today: start).state.startedOn, start, "what is stored is still read")
        c.consent.grant()
        XCTAssertTrue(adapter(c, programme).input(today: start).consentActive)
    }

    /// The worked case through the real trackers. Recording her next period is what moves
    /// `lastPeriodDate`, and the seven days she was asked for stay seven of seven.
    func testRecordingTheNextPeriodThroughTheRealTrackersKeepsTheEarlierDays() {
        let (c, programme) = container(makeStore())
        programme.start(today: start)
        XCTAssertEqual(c.periods.recordStart(date(8), today: date(8)), .append(date(8)))
        XCTAssertTrue(c.cycle.upsert(CycleSettings(lastPeriodDate: date(8), cycleLength: 28, periodLength: 5)))
        for day in 16...22 {
            XCTAssertTrue(c.lh.create(LhResult(recordedAt: instant(date(day), 8), classification: .low)))
        }
        let source = adapter(c, programme, scan: true)
        func figure(todayDay: Int) -> ProgrammeConsistencyFigure? {
            ProgrammePlanService.report(source.input(today: date(todayDay))).categories[.lhTest]
        }
        XCTAssertEqual(figure(todayDay: 38)?.counted, 7)
        XCTAssertEqual(figure(todayDay: 38)?.credit, 7)

        XCTAssertEqual(c.periods.recordStart(date(39), today: date(39)), .append(date(39)))
        XCTAssertEqual(c.cycle.settings?.lastPeriodDate, date(39), "her settings moved to the new start")

        XCTAssertEqual(figure(todayDay: 40)?.counted, 7)
        XCTAssertEqual(figure(todayDay: 40)?.credit, 7)
        XCTAssertEqual(figure(todayDay: 40)?.percentage, 100)
    }

    /// Unless a calendar is passed, the one used follows the phone. A calendar copied when the
    /// source was built would keep the old time zone after she travels, while "today" moved on.
    func testTheDefaultCalendarFollowsThePhone() {
        let (c, programme) = container(makeStore())
        let source = ProgrammePlanSource(programme: programme, dailyLog: c.dailyLog, ph: c.ph, lh: c.lh,
                                         periods: c.periods, cycle: c.cycle, prefs: c.prefs, consent: c.consent,
                                         scanFeaturesAvailable: false)
        XCTAssertEqual(source.calendar, .autoupdatingCurrent)
        XCTAssertNotEqual(source.calendar, .current)
    }

    // MARK: - Source guards

    /// The service is pure and the adapter only maps. Neither may name the intimacy field, the
    /// pregnancy test records, a feature flag or the scan services; the service also reads no
    /// clock and names no repository.
    func testTheServiceAndTheAdapterNameNothingTheyMustNot() throws {
        let serviceFile = try Self.source("App/Genesyx/Services/Programme/ProgrammePlanService.swift")
        let adapterFile = try Self.source("App/Genesyx/Services/Programme/ProgrammePlanSource.swift")
        XCTAssertTrue(serviceFile.contains("enum ProgrammePlanService"), "the path is wrong, not the code")
        XCTAssertTrue(adapterFile.contains("struct ProgrammePlanSource"), "the path is wrong, not the code")

        for banned in ["sexualActivity", "hcg", "Hcg", "FeatureFlags", "ScanServices", "print("] {
            XCTAssertFalse(serviceFile.contains(banned), "ProgrammePlanService.swift must not contain `\(banned)`")
            XCTAssertFalse(adapterFile.contains(banned), "ProgrammePlanSource.swift must not contain `\(banned)`")
        }
        for banned in ["Date()", ".today()", "Calendar.current", "Repository"] {
            XCTAssertFalse(serviceFile.contains(banned), "ProgrammePlanService.swift must not contain `\(banned)`")
        }
        let imports = serviceFile.components(separatedBy: .newlines).filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation", "import GenesyxCore"])
    }

    /// One producer: no other file under App/Genesyx asks the engine for a plan. A screen, a
    /// review or a reminder that needs plans takes them from the service.
    func testThePlanServiceIsTheOnlyCallerOfTheTaskEngine() throws {
        let root = Self.repoRoot.appendingPathComponent("App/Genesyx")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var callers: Set<String> = []
        for case let file as URL in walker where file.pathExtension == "swift" {
            let code = try String(contentsOf: file, encoding: .utf8).components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            if code.contains(where: { $0.contains("ProgrammeTaskEngine.plan(") }) { callers.insert(file.lastPathComponent) }
        }
        XCTAssertEqual(callers, ["ProgrammePlanService.swift"])
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GenesyxTests
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }
}
