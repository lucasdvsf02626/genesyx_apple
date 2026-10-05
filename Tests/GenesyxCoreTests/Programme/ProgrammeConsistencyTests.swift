import XCTest
@testable import GenesyxCore

/// The consistency arithmetic, starting from the plan's three worked days and its worked week.
final class ProgrammeConsistencyTests: XCTestCase {

    private typealias F = ProgrammeFixtures

    private func counted(_ plan: ProgrammeDayPlan) -> [ProgrammeTaskCategory] {
        plan.tasks.filter(\.isCounted).map(\.category).sorted { $0.rawValue < $1.rawValue }
    }

    private let fiveDaily: [ProgrammeTaskCategory] =
        [.energyCheckIn, .hydrationCheckIn, .moodCheckIn, .sleepCheckIn, .supplementCheckIn]

    // ── The three worked days ──

    /// Day A: 4.625 of 5 = 93 per cent. Water 1500 of 2400 ml; pH and LH not applicable.
    func testWorkedDayA() {
        let plan = F.plan(F.snapshotA())
        XCTAssertEqual(plan.day, 23)
        XCTAssertEqual(plan.week, 4)
        XCTAssertEqual(counted(plan), fiveDaily)
        XCTAssertEqual(plan.task(.hydrationCheckIn)?.credit, 0.625)
        XCTAssertEqual(plan.task(.phTest)?.status, .notApplicable)
        XCTAssertEqual(plan.task(.lhTest)?.status, .notApplicable)
        XCTAssertEqual(plan.task(.nutritionCheckIn)?.status, .optional)
        XCTAssertEqual(plan.task(.symptomCheckIn)?.status, .optional)
        XCTAssertEqual(plan.task(.programmeLesson)?.status, .optional)
        XCTAssertEqual(plan.foodGroupsRecorded, 3)

        let figure = ProgrammeConsistency.day(plan)
        XCTAssertEqual(figure.counted, 5)
        XCTAssertEqual(figure.credit, 4.625)
        XCTAssertEqual(figure.completed, 4)
        XCTAssertEqual(figure.partlyCompleted, 1)
        XCTAssertEqual(figure.percentage, 93)
        XCTAssertNil(figure.withheld)
        XCTAssertFalse(figure.nothingRecorded)
    }

    /// Day B: 5 of 6 = 83 per cent, inside the predicted window with scanning available and an LH
    /// record present. The pH reading is open for the week and is not in the day.
    func testWorkedDayB() {
        let plan = F.plan(F.snapshotB())
        XCTAssertEqual(counted(plan), (fiveDaily + [.lhTest]).sorted { $0.rawValue < $1.rawValue })
        XCTAssertEqual(plan.task(.lhTest)?.status, .completed)
        XCTAssertEqual(plan.task(.supplementCheckIn)?.status, .eligible)
        XCTAssertEqual(plan.task(.phTest)?.status, .notApplicable)
        XCTAssertEqual(plan.weekly(.phTest)?.status, .eligible)

        let figure = ProgrammeConsistency.day(plan)
        XCTAssertEqual(figure.counted, 6)
        XCTAssertEqual(figure.credit, 5)
        XCTAssertEqual(figure.completed, 5)
        XCTAssertEqual(figure.partlyCompleted, 0)
        XCTAssertEqual(figure.percentage, 83)
    }

    /// Day C: 0 of 5, the "nothing recorded" state.
    func testWorkedDayC() {
        let plan = F.plan(day: 23, todayDay: 24, F.snapshotC())
        XCTAssertEqual(counted(plan), fiveDaily)
        XCTAssertTrue(plan.tasks.filter(\.isCounted).allSatisfy { $0.status == .skipped })

        let figure = ProgrammeConsistency.day(plan)
        XCTAssertEqual(figure.counted, 5)
        XCTAssertEqual(figure.credit, 0)
        XCTAssertEqual(figure.completed, 0)
        XCTAssertEqual(figure.percentage, 0)
        XCTAssertTrue(figure.nothingRecorded)

        // The same day while it is still today: counts only.
        XCTAssertEqual(ProgrammeConsistency.today(F.plan(F.snapshotC())),
                       ProgrammeTodayProgress(completed: 0, partlyCompleted: 0, total: 5))
    }

    // ── The worked week ──

    /// Week 4 (days 22 to 28): five days like A, one like B, one like C, read on `todayDay`.
    private func workedWeek(todayDay: Int) -> [ProgrammeDayPlan] {
        (22...26).map { F.plan(day: $0, todayDay: todayDay, F.snapshotA(day: $0)) }
            + [F.plan(day: 27, todayDay: todayDay, F.snapshotB(day: 27)),
               F.plan(day: 28, todayDay: todayDay, F.snapshotC(day: 28))]
    }

    /// 5 x 4.625 + 5 + 0 + 1 = 29.125 over 5 x 5 + 6 + 5 + 1 = 37, which is 79 per cent.
    func testWorkedWeek() {
        let plans = workedWeek(todayDay: 29)
        let week = ProgrammeConsistency.period(plans, days: 22...28, todayDay: 29)
        XCTAssertEqual(week.counted, 37)
        XCTAssertEqual(week.credit, 29.125)
        XCTAssertEqual(week.percentage, 79)
        XCTAssertEqual(week.completed, 26)        // 5 x 4 + 5 + 0 + the pH reading
        XCTAssertEqual(week.partlyCompleted, 5)   // water on the five A days

        // The mean of the seven daily percentages is a different number, and is not what is used.
        let daily = plans.map { ProgrammeConsistency.day($0).percentage ?? 0 }
        XCTAssertEqual(daily, [93, 93, 93, 93, 93, 83, 0])
        XCTAssertEqual(Int((Double(daily.reduce(0, +)) / 7).rounded()), 78)
    }

    func testTheReportAgreesWithThePeriodAndAddsUp() {
        let plans = workedWeek(todayDay: 29).shuffledDeterministically()
        let report = ProgrammeConsistency.report(state: F.state, today: F.date(ofDay: 29), plans: plans)
        XCTAssertNil(report.today, "no plan was supplied for day 29")
        XCTAssertEqual(report.week.counted, 0)                    // week 5 has no past day yet
        XCTAssertEqual(report.week.withheld, .nothingCounted)
        XCTAssertEqual(report.trailing30Days.percentage, 79)
        XCTAssertEqual(report.phases[.buildTheFoundation]?.counted, 37)
        XCTAssertEqual(report.phases[.discoverYourPatterns]?.counted, 0)
        XCTAssertEqual(report.programme.credit, 29.125)

        XCTAssertEqual(report.categories[.hydrationCheckIn]?.counted, 7)
        XCTAssertEqual(report.categories[.hydrationCheckIn]?.credit, 5 * 0.625 + 1)
        XCTAssertEqual(report.categories[.hydrationCheckIn]?.percentage, 59)
        XCTAssertEqual(report.categories[.supplementCheckIn]?.credit, 5)
        XCTAssertEqual(report.categories[.lhTest]?.counted, 1)
        XCTAssertEqual(report.categories[.lhTest]?.withheld, .belowMinimum)
        XCTAssertEqual(report.categories[.phTest]?.counted, 1)
        XCTAssertNil(report.categories[.nutritionCheckIn], "an optional activity has no figure")
        XCTAssertEqual(report.categories.values.reduce(0) { $0 + $1.counted }, 37)
        XCTAssertEqual(report.categories.values.reduce(0) { $0 + $1.credit }, 29.125)
    }

    // ── Today and yesterday ──

    func testTodayIsExcludedFromThePeriodAndReportedOnItsOwn() {
        // Read on day 28: Day C is today, so the week runs to day 27. The pH reading is done, so
        // it already counts although the week is not over.
        let plans = workedWeek(todayDay: 28)
        let report = ProgrammeConsistency.report(state: F.state, today: F.date(ofDay: 28), plans: plans)
        XCTAssertEqual(report.week.counted, 5 * 5 + 6 + 1)
        XCTAssertEqual(report.week.credit, 5 * 4.625 + 5 + 1)
        XCTAssertEqual(report.week.percentage, 91)
        XCTAssertEqual(report.today, ProgrammeTodayProgress(completed: 0, partlyCompleted: 0, total: 5))
        XCTAssertEqual(report.week, ProgrammeConsistency.period(plans, days: 22...28, todayDay: 28))

        // Logging today moves today's counts and leaves the period alone.
        var logged = plans
        logged[6] = F.plan(day: 28, todayDay: 28, F.snapshotA(day: 28))
        let after = ProgrammeConsistency.report(state: F.state, today: F.date(ofDay: 28), plans: logged)
        XCTAssertEqual(after.week, report.week)
        XCTAssertEqual(after.today, ProgrammeTodayProgress(completed: 4, partlyCompleted: 1, total: 5))
    }

    func testAnOpenWeeklyActivityAddsNothingUntilTheWeekIsOver() {
        // Seven C days, no pH reading at all.
        func plans(todayDay: Int) -> [ProgrammeDayPlan] {
            (22...28).map { day -> ProgrammeDayPlan in
                var snapshot = F.snapshotC(day: day)
                snapshot.phReadingExistsThisProgrammeWeek = false
                return F.plan(day: day, todayDay: todayDay, snapshot)
            }
        }
        let during = ProgrammeConsistency.period(plans(todayDay: 26), days: 22...28, todayDay: 26)
        XCTAssertEqual(during.counted, 4 * 5)
        let after = ProgrammeConsistency.period(plans(todayDay: 29), days: 22...28, todayDay: 29)
        XCTAssertEqual(after.counted, 7 * 5 + 1)
        XCTAssertEqual(after.credit, 0)
        XCTAssertTrue(after.nothingRecorded)
    }

    func testAWeeklyActivityCountsOnceHoweverManyDaysReportIt() {
        let plans = (22...28).map { F.plan(day: $0, todayDay: 29, F.snapshotA(day: $0)) }
        let week = ProgrammeConsistency.period(plans, days: 22...28, todayDay: 29)
        XCTAssertEqual(week.counted, 7 * 5 + 1)
        XCTAssertEqual(week.credit, 7 * 4.625 + 1)
    }

    func testAWeeklyActivityBelongsToThePeriodHoldingItsWeeksFirstDay() {
        // Week 5 is days 29 to 35 and straddles the end of phase 1 (day 30).
        let plans = (29...35).map { F.plan(day: $0, todayDay: 36, F.snapshotA(day: $0)) }
        let report = ProgrammeConsistency.report(state: F.state, today: F.date(ofDay: 36), plans: plans)
        XCTAssertEqual(report.phases[.buildTheFoundation]?.counted, 2 * 5 + 1)
        XCTAssertEqual(report.phases[.discoverYourPatterns]?.counted, 5 * 5)
        XCTAssertEqual(report.programme.counted, 7 * 5 + 1)
    }

    // ── Denominator rule ──

    func testOptionalAndNotApplicableNeverChangeTheDenominator() {
        let base = ProgrammeConsistency.day(F.plan(F.snapshotA()))

        var more = F.snapshotA()
        more.log?.symptoms = ["cramps", "bloating"]
        more.log?.foodGroups = Set(FoodGroup.allCases.map(\.rawValue))
        more.log?.notes = "A note"
        more.completedLessonIDs = ["programme-day-023"]
        more.periodRecordExistsForDate = true
        XCTAssertEqual(ProgrammeConsistency.day(F.plan(more)), base)

        var less = F.snapshotA()
        less.log?.foodGroups = []
        less.cycleSettings = nil
        less.phReadingExistsThisProgrammeWeek = false
        XCTAssertEqual(ProgrammeConsistency.day(F.plan(less)), base)

        // Every optional task done, every not-applicable one present: still five counted.
        let plan = F.plan(more)
        XCTAssertGreaterThanOrEqual(plan.tasks.filter { $0.status == .optional && $0.isDone }.count, 5)
        XCTAssertGreaterThanOrEqual(plan.tasks.filter { $0.status == .notApplicable }.count, 2)
        XCTAssertEqual(ProgrammeConsistency.figure(for: plan.tasks).counted, 5)
        XCTAssertEqual(ProgrammeConsistency.figure(for: plan.tasks.filter { !$0.isCounted }).counted, 0)
    }

    func testSupplementsAnsweredNoShrinksTheDenominatorInsteadOfScoringZero() {
        var snapshot = F.snapshotA()
        snapshot.supplementsAnswer = "no"
        let figure = ProgrammeConsistency.day(F.plan(snapshot))
        XCTAssertEqual(figure.counted, 4)
        XCTAssertEqual(figure.credit, 3.625)
        XCTAssertNil(figure.percentage)
        XCTAssertEqual(figure.withheld, .belowMinimum)
    }

    // ── No percentage ──

    func testADayWithNothingCountedHasNoPercentageAndAddsNothing() {
        var snapshot = F.snapshotA()
        snapshot.consentActive = false
        let empty = F.plan(day: 24, todayDay: 29, snapshot)
        let figure = ProgrammeConsistency.day(empty)
        XCTAssertEqual(figure.counted, 0)
        XCTAssertNil(figure.percentage)
        XCTAssertEqual(figure.withheld, .nothingCounted)
        XCTAssertFalse(figure.nothingRecorded)

        var plans = workedWeek(todayDay: 29)
        let before = ProgrammeConsistency.period(plans, days: 22...28, todayDay: 29)
        plans.append(F.plan(day: 21, todayDay: 29, snapshot))
        XCTAssertEqual(ProgrammeConsistency.period(plans, days: 21...28, todayDay: 29), before)
    }

    func testAPercentageNeedsFiveCountedActivities() {
        XCTAssertEqual(ProgrammeConsistency.minimumCountedForPercentage, 5)
        let tasks = F.plan(F.snapshotA()).tasks.filter(\.isCounted)
        XCTAssertEqual(ProgrammeConsistency.figure(for: Array(tasks.prefix(4))).withheld, .belowMinimum)
        XCTAssertNil(ProgrammeConsistency.figure(for: Array(tasks.prefix(4))).percentage)
        XCTAssertNotNil(ProgrammeConsistency.figure(for: tasks).percentage)
        XCTAssertEqual(ProgrammeConsistency.figure(for: []).withheld, .nothingCounted)
    }

    func testNotStartedGivesAnEmptyReport() {
        let report = ProgrammeConsistency.report(state: .notStarted, today: F.start, plans: workedWeek(todayDay: 29))
        XCTAssertNil(report.today)
        XCTAssertEqual(report.programme.counted, 0)
        XCTAssertNil(report.programme.percentage)
        XCTAssertTrue(report.categories.isEmpty)
    }

    func testRoundingIsHalvesUp() {
        // 4.625 of 5 is exactly 92.5 per cent.
        XCTAssertEqual(ProgrammeConsistency.day(F.plan(F.snapshotA())).percentage, 93)
        var snapshot = F.snapshotA()
        snapshot.log?.waterMl = 1488   // 0.62 of the goal: 92.4 per cent
        XCTAssertEqual(ProgrammeConsistency.day(F.plan(snapshot)).percentage, 92)
    }

    // ── Recalculation ──

    func testADeletedOrLateLogChangesTheRecalculatedFigure() {
        var plans = workedWeek(todayDay: 29)
        // Day C filled in afterwards, like a Day A.
        plans[6] = F.plan(day: 28, todayDay: 29, F.snapshotA(day: 28))
        let filled = ProgrammeConsistency.period(plans, days: 22...28, todayDay: 29)
        XCTAssertEqual(filled.credit, 29.125 + 4.625)
        XCTAssertEqual(filled.counted, 37)
        XCTAssertEqual(filled.percentage, 91)

        // The first day's log deleted.
        plans[0] = F.plan(day: 22, todayDay: 29, F.snapshotC(day: 22))
        let deleted = ProgrammeConsistency.period(plans, days: 22...28, todayDay: 29)
        XCTAssertEqual(deleted.credit, 29.125)
        XCTAssertEqual(deleted.percentage, 79)
    }

    // ── What consistency never reads ──

    /// With the same records present, the values inside them change nothing: not a status, not a
    /// credit, not a figure.
    func testValuesInsideARecordNeverMoveAStatusOrAFigure() {
        let base = F.plan(day: 23, todayDay: 24, F.snapshotA())
        func assertSame(_ change: (inout ProgrammeDaySnapshot) -> Void, _ what: String, line: UInt = #line) {
            var snapshot = F.snapshotA()
            change(&snapshot)
            let plan = F.plan(day: 23, todayDay: 24, snapshot)
            XCTAssertEqual(plan, base, what, line: line)
            XCTAssertEqual(ProgrammeConsistency.day(plan), ProgrammeConsistency.day(base), what, line: line)
        }
        for mood in Mood.allCases { assertSame({ $0.log?.mood = mood }, "mood \(mood)") }
        for energy in EnergyLevel.allCases { assertSame({ $0.log?.energy = energy }, "energy \(energy)") }
        for minutes in [0, 60, 180, 440, 600, 900] { assertSame({ $0.log?.sleepMinutes = minutes }, "sleep \(minutes)") }
        assertSame({ $0.log?.sexualActivity = true }, "intimacy")
        assertSame({ $0.log?.notes = "Anything" }, "notes")
        assertSame({ $0.log?.supplements = ["a", "b", "c", "d"] }, "which and how many supplements")
        assertSame({ $0.log?.foodGroups = ["dairy", "oilsAndFats", "starchyCarbs"] }, "which food groups")
        // Cycle length and period length, in a build without the scan features.
        for length in CycleEngine.cycleLengthRange {
            assertSame({ $0.cycleSettings = CycleSettings(lastPeriodDate: F.date(ofDay: 4), cycleLength: length, periodLength: 3) },
                       "cycle length \(length)")
        }
    }

    func testSymptomsNeverMoveAFigureWhateverTheyAre() {
        var one = F.snapshotA()
        var many = F.snapshotA()
        one.log?.symptoms = ["headache"]
        many.log?.symptoms = ["cramps", "bloating", "fatigue", "nausea", "headache"]
        XCTAssertEqual(F.plan(one), F.plan(many))
        XCTAssertEqual(ProgrammeConsistency.day(F.plan(one)), ProgrammeConsistency.day(F.plan(F.snapshotA())))
    }

    /// With scanning available the cycle length still is not judged: it only places the predicted
    /// window. Two lengths that both put the date inside the window give the same plan.
    func testCycleLengthIsNeverJudgedOnlyUsedToPlaceTheWindow() {
        var short = F.snapshotB()
        var long = F.snapshotB()
        short.cycleSettings = F.settings(day: 23, onCycleDay: 5, cycleLength: 21)   // window 2 to 8
        long.cycleSettings = F.settings(day: 23, onCycleDay: 18, cycleLength: 35)   // window 16 to 22
        XCTAssertEqual(F.plan(short), F.plan(long))
        XCTAssertEqual(F.plan(short).task(.lhTest)?.status, .completed)
    }

    /// A pH value, an LH result and a pregnancy-test result cannot move anything because they
    /// cannot get in: the snapshot carries "a record exists" and nothing else about a test, and
    /// nothing at all about a pregnancy test. Adding a field here is a decision, not a refactor.
    func testTheSnapshotHasNoFieldThatCouldCarryATestValue() {
        let labels = Mirror(reflecting: ProgrammeDaySnapshot()).children.compactMap(\.label)
        XCTAssertEqual(labels, [
            "log", "waterGoalMl", "phReadingExistsThisProgrammeWeek", "lhResultExistsForDate",
            "periodRecordExistsForDate", "cycleSettings", "scanFeaturesAvailable", "phLoggingAvailable",
            "completedLessonIDs", "completedReviewWeeks", "supplementsAnswer", "consentActive",
        ])
        let snapshot = ProgrammeDaySnapshot()
        XCTAssertTrue(type(of: snapshot.phReadingExistsThisProgrammeWeek) == Bool.self)
        XCTAssertTrue(type(of: snapshot.lhResultExistsForDate) == Bool.self)
    }
}

private extension Array {
    /// A fixed reordering, to show the order of the plans does not matter.
    func shuffledDeterministically() -> [Element] {
        Array(self.reversed().enumerated().sorted { ($0.offset % 3, $0.offset) < ($1.offset % 3, $1.offset) }.map(\.element))
    }
}
