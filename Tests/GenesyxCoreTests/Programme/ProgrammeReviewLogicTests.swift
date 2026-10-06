import XCTest
@testable import GenesyxCore

/// Shared set-up for the review tests: programmes built day by day from snapshots, with the logs
/// and dated records those snapshots stand for. Everything hangs off `ProgrammeFixtures`.
enum ProgrammeReviewFixtures {

    private typealias F = ProgrammeFixtures

    /// Plans for `days` read on `todayDay`, the log behind each plan, and a dated ovulation-test
    /// result wherever a snapshot says one exists.
    static func programme(
        days: ClosedRange<Int>,
        todayDay: Int,
        goal: ProgrammeGoalEmphasis = .understandMyCycle,
        content: ProgrammeContent = .draft,
        snapshot: (Int) -> ProgrammeDaySnapshot
    ) -> ProgrammeReviewInput {
        var input = ProgrammeReviewInput(state: F.state, today: F.date(ofDay: todayDay), goal: goal, content: content)
        for day in days {
            let facts = snapshot(day)
            input.plans.append(F.plan(day: day, todayDay: todayDay, goal: goal, facts, content: content))
            input.logsByDate[F.date(ofDay: day)] = facts.log
            if facts.lhResultExistsForDate { input.lhResultDates.append(F.date(ofDay: day)) }
        }
        return input
    }

    /// The Day A profile with nothing logged and no pH reading in the week.
    static func nothing(day: Int) -> ProgrammeDaySnapshot {
        var snapshot = F.snapshotC(day: day)
        snapshot.phReadingExistsThisProgrammeWeek = false
        return snapshot
    }

    static func lessonID(day: Int) -> String { ProgrammeContent.draft.day(day)!.lesson.id }

    /// Food groups, a symptom and the day's lesson read on every one of `days`, and nothing the
    /// draft schedule counts: no mood, energy, sleep or water, a "no" to supplements, no tests.
    static func uncountedRecordsOnly(days: ClosedRange<Int>, todayDay: Int) -> ProgrammeReviewInput {
        programme(days: days, todayDay: todayDay) { day in
            var snapshot = nothing(day: day)
            snapshot.supplementsAnswer = "no"
            snapshot.log = DailyLog(symptoms: ["headache"], foodGroups: ["fruit"])
            snapshot.completedLessonIDs = [lessonID(day: day)]
            return snapshot
        }
    }

    /// Cycles from period starts on programme days: at most one copied from her settings, the
    /// others recorded by her.
    static func cycles(seededOnDay seeded: Int? = nil, recordedOnDays recorded: [Int]) -> [DerivedCycle] {
        let periods = (seeded.map { [PeriodRecord(startDate: F.date(ofDay: $0), source: .seeded)] } ?? [])
            + recorded.map { PeriodRecord(startDate: F.date(ofDay: $0)) }
        return CycleHistory.cycles(from: periods.map {
            StoredPeriodRecord(period: $0, updatedAt: Date(timeIntervalSince1970: 0), pendingSync: false)
        })
    }

    /// The draft content with every week's schedule replaced.
    static func content(activities: [ProgrammeActivityRule]) -> ProgrammeContent {
        let draft = ProgrammeContent.draft
        let weeks = draft.weeks.map { week in
            ProgrammeWeekDefinition(
                number: week.number, themeTitle: week.themeTitle, purpose: week.purpose,
                connectsTo: week.connectsTo, nutritionFocus: week.nutritionFocus, activities: activities,
                relatedContent: week.relatedContent, safetyNotes: week.safetyNotes, review: week.review)
        }
        return ProgrammeContent(version: "test", weeks: weeks, phaseTitles: draft.phaseTitles,
                                kindCopy: draft.kindCopy, kindReflections: draft.kindReflections,
                                kindReadMinutes: draft.kindReadMinutes, testGuidanceWeeks: draft.testGuidanceWeeks)
    }

    // ── The six reviews the copy guard reads ──

    /// The plan's worked week 4 (days 22 to 28) read on day 29: five days like A, one like B, one
    /// like C, and the week's pH reading taken on day 22. A partly recorded week.
    static var workedWeek: ProgrammeReviewInput {
        var input = programme(days: 22...28, todayDay: 29) { day in
            day == 27 ? F.snapshotB(day: day) : day == 28 ? F.snapshotC(day: day) : F.snapshotA(day: day)
        }
        input.phReadingDates = [F.date(ofDay: 22)]
        return input
    }

    /// Weeks 3 and 4 read on day 29. Week 4 holds every kind of record: sleep on all seven days,
    /// supplements on six, mood on five, energy on four, water on six with four on goal, food
    /// groups on three, symptoms on two, four lessons read, two pH readings, three ovulation-test
    /// results and one recorded period start. Week 3 has three days like A and a seeded start.
    static var fullWeeks: ProgrammeReviewInput {
        var input = programme(days: 15...28, todayDay: 29) { day in
            guard day >= 22 else { return day <= 17 ? F.snapshotA(day: day) : F.snapshotC(day: day) }
            let i = day - 22
            var snapshot = F.snapshotC(day: day)
            snapshot.log = DailyLog(
                mood: i < 5 ? .good : nil,
                energy: i < 4 ? .normal : nil,
                symptoms: i == 1 || i == 2 ? ["headache"] : [],
                sleepMinutes: 420,
                supplements: i < 6 ? ["folate"] : [],
                waterMl: i < 4 ? 2400 : i < 6 ? 1200 : 0,
                foodGroups: i < 3 ? ["fruit"] : [])
            if [0, 2, 4, 5].contains(i) { snapshot.completedLessonIDs = [lessonID(day: day)] }
            return snapshot
        }
        input.phReadingDates = [F.date(ofDay: 23), F.date(ofDay: 25)]
        input.lhResultDates = [22, 23, 24].map(F.date(ofDay:))
        input.cycles = cycles(seededOnDay: 16, recordedOnDays: [24])
        return input
    }

    /// Week 4 with nothing recorded at all, read on day 29.
    static var emptyWeek: ProgrammeReviewInput {
        programme(days: 22...28, todayDay: 29) { nothing(day: $0) }
    }

    /// Week 13 (days 85 to 90), six days like A, read on day 91.
    static var lastWeek: ProgrammeReviewInput {
        var input = programme(days: 85...90, todayDay: 91) { F.snapshotA(day: $0) }
        input.phReadingDates = [F.date(ofDay: 85)]
        return input
    }

    static let samplePatterns = [
        ProgrammeEvidenceStatement(level: .crossCyclePattern, text: "Your last three recorded cycles were 23, 23 and 21 days long."),
        ProgrammeEvidenceStatement(level: .withinWeekTrend, text: "You recorded sleep on 6 days this week."),
        ProgrammeEvidenceStatement(level: .observation, text: "Your latest pH reading was recorded this week."),
        ProgrammeEvidenceStatement(level: .withinCyclePattern, text: "You recorded 3 ovulation test results in this cycle."),
    ]

    /// All ninety days, on a weekly pattern of five days like A, one like B and one like C, with a
    /// pH reading on the first day of every week, a seeded period start on day 1, four recorded
    /// ones (so three countable cycles) and one pattern statement at each level.
    static func fullProgramme(todayDay: Int = 91) -> ProgrammeReviewInput {
        var input = programme(days: 1...90, todayDay: todayDay) { day in
            if day % 7 == 4 { return F.snapshotB(day: day) }
            if day % 7 == 5 { return F.snapshotC(day: day) }
            var snapshot = F.snapshotA(day: day)
            if day % 5 == 0 { snapshot.log?.symptoms = ["headache"] }
            if day % 3 == 0 { snapshot.completedLessonIDs = [lessonID(day: day)] }
            return snapshot
        }
        input.phReadingDates = (1...13).map { F.date(ofDay: ProgrammeCalendar.dayRange(ofWeek: $0).lowerBound) }
        input.cycles = cycles(seededOnDay: 1, recordedOnDays: [22, 45, 68, 89])
        input.patterns = samplePatterns
        return input
    }

    /// All ninety days with nothing recorded, read on day 91.
    static var emptyProgramme: ProgrammeReviewInput {
        programme(days: 1...90, todayDay: 91) { nothing(day: $0) }
    }
}

/// The Weekly Programme Review and the 90-Day Review, against programmes built from the plan's
/// worked days.
final class ProgrammeReviewLogicTests: XCTestCase {

    private typealias F = ProgrammeFixtures
    private typealias RF = ProgrammeReviewFixtures
    private typealias Logic = ProgrammeReviewLogic
    private typealias Copy = ProgrammeReviewCopy

    private func count(_ kind: ProgrammeReviewCount.Kind, in tracked: [ProgrammeReviewCount]) -> Int {
        tracked.first { $0.kind == kind }?.count ?? 0
    }

    private func text(_ kind: ProgrammeReviewCount.Kind, in tracked: [ProgrammeReviewCount]) -> String? {
        tracked.first { $0.kind == kind }?.text
    }

    /// Weeks 3 and 4 read on day 29, with a one-line log on the first days of each week and the
    /// water goal reached on the first `onGoal` days of week 4.
    private func twoWeeks(logged: Int, onGoal: Int = 0, weekBefore: Int = 0) -> ProgrammeReviewInput {
        RF.programme(days: 15...28, todayDay: 29) { day in
            var snapshot = RF.nothing(day: day)
            let position = day >= 22 ? day - 22 : day - 15
            if position < (day >= 22 ? logged : weekBefore) {
                snapshot.log = DailyLog(mood: .okay, waterMl: day >= 22 && position < onGoal ? 2400 : 0)
            }
            return snapshot
        }
    }

    // ── Availability ──

    func testNoWeekHasAReviewBeforeItHasEnded() {
        XCTAssertEqual(Logic.availableWeeks(state: .notStarted, today: F.date(ofDay: 50)), [])
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.start.minusDays(1)), [])
        for day in 1...7 {
            XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: day)), [], "day \(day)")
        }
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 8)), [1])
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 14)), [1])
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 15)), [1, 2])
    }

    func testEarlierWeeksStayAvailableAndWeekThirteenArrivesOnDayNinetyOne() {
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 85)), Array(1...12))
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 90)), Array(1...12))
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 91)), Array(1...13))
        XCTAssertEqual(Logic.availableWeeks(state: F.state, today: F.date(ofDay: 400)), Array(1...13))
    }

    func testAStopMarkerCutsTheList() {
        // Stopped on day 20: weeks 1 and 2 ended before it; week 3 ends on day 21 and did not.
        let stopped = ProgrammeState(startedOn: F.start, stoppedOn: F.date(ofDay: 20))
        XCTAssertEqual(Logic.availableWeeks(state: stopped, today: F.date(ofDay: 40)), [1, 2])
        XCTAssertEqual(Logic.availableWeeks(state: stopped, today: F.date(ofDay: 10)), [1])
        let onTheBoundary = ProgrammeState(startedOn: F.start, stoppedOn: F.date(ofDay: 22))
        XCTAssertEqual(Logic.availableWeeks(state: onTheBoundary, today: F.date(ofDay: 40)), [1, 2, 3])
        // Stopped on week 3's own last day: the stop date is not a programme day, so the week
        // did not end before she left.
        let onTheLastDay = ProgrammeState(startedOn: F.start, stoppedOn: F.date(ofDay: 21))
        XCTAssertEqual(Logic.availableWeeks(state: onTheLastDay, today: F.date(ofDay: 40)), [1, 2])
    }

    func testWeeklyIsNilForAWeekWithNoReviewAndWithoutConsent() {
        let input = RF.workedWeek
        XCTAssertNotNil(Logic.weekly(week: 4, input: input))
        XCTAssertNil(Logic.weekly(week: 5, input: input), "week 5 has only just begun")
        XCTAssertNil(Logic.weekly(week: 0, input: input))
        XCTAssertNil(Logic.weekly(week: 14, input: input))

        var withoutConsent = input
        withoutConsent.consentActive = false
        XCTAssertNil(Logic.weekly(week: 4, input: withoutConsent))

        var notStarted = input
        notStarted.state = .notStarted
        XCTAssertNil(Logic.weekly(week: 4, input: notStarted))

        var onTheLastDay = input
        onTheLastDay.today = F.date(ofDay: 28)
        XCTAssertNil(Logic.weekly(week: 4, input: onTheLastDay))
    }

    func testTheNinetyDayReviewExistsFromDayNinetyOneOnly() {
        XCTAssertFalse(Logic.isNinetyDayReviewAvailable(state: .notStarted, today: F.date(ofDay: 91)))
        XCTAssertFalse(Logic.isNinetyDayReviewAvailable(state: F.state, today: F.date(ofDay: 90)))
        XCTAssertTrue(Logic.isNinetyDayReviewAvailable(state: F.state, today: F.date(ofDay: 91)))
        XCTAssertTrue(Logic.isNinetyDayReviewAvailable(state: F.state, today: F.date(ofDay: 400)))

        XCTAssertNil(Logic.ninetyDay(RF.fullProgramme(todayDay: 90)))
        XCTAssertNotNil(Logic.ninetyDay(RF.fullProgramme(todayDay: 91)))

        var stopped = RF.fullProgramme(todayDay: 100)
        XCTAssertNotNil(Logic.ninetyDay(stopped))
        stopped.state.stoppedOn = F.date(ofDay: 95)
        XCTAssertNil(Logic.ninetyDay(stopped))
        stopped.state.stoppedOn = F.date(ofDay: 50)
        XCTAssertNil(Logic.ninetyDay(stopped))

        var withoutConsent = RF.fullProgramme()
        withoutConsent.consentActive = false
        XCTAssertNil(Logic.ninetyDay(withoutConsent))
    }

    // ── Weekly figures ──

    /// 29.125 of 37 is 79 per cent: 26 done in full and the water on the five A days part done.
    func testTheWorkedWeekReviewsAsSeventyNinePerCent() throws {
        let input = RF.workedWeek
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: input))
        XCTAssertEqual(review.week, 4)
        XCTAssertEqual(review.phase, .buildTheFoundation)
        XCTAssertEqual(review.phaseTitle, "Build the Foundation")
        XCTAssertEqual(review.themeTitle, "Hydration & Sleep")
        XCTAssertEqual(review.firstDate, F.date(ofDay: 22))
        XCTAssertEqual(review.lastDate, F.date(ofDay: 28))
        XCTAssertEqual(review.headline, "Week 4 complete")

        XCTAssertEqual(review.consistency, ProgrammeConsistency.period(input.plans, days: 22...28, todayDay: 29))
        XCTAssertEqual(review.consistency.percentage, 79)
        XCTAssertEqual(review.consistencyLines, ["79%", "26 of 37 activities completed, 5 partly completed"])
        XCTAssertNil(review.supportLine)
    }

    func testTheFigureIsTheSameHoweverLongAfterTheWeekItIsRead() throws {
        var later = RF.workedWeek
        later.today = F.date(ofDay: 60)
        let now = try XCTUnwrap(Logic.weekly(week: 4, input: RF.workedWeek))
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 4, input: later)).consistency, now.consistency)
    }

    func testAPercentageIsWithheldBelowTheMinimumAndTheCountsStand() throws {
        // One day, supplements not applicable, no pH logging: four counted, three done in full.
        let input = RF.programme(days: 22...22, todayDay: 29) { day in
            var snapshot = F.snapshotA(day: day)
            snapshot.supplementsAnswer = "no"
            snapshot.phLoggingAvailable = false
            return snapshot
        }
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: input))
        XCTAssertEqual(review.consistency.withheld, .belowMinimum)
        XCTAssertEqual(review.consistencyLines, ["3 of 4 activities completed, 1 partly completed"])

        // One activity counted and part done: the singular, and a line the registry holds.
        let waterOnly = RF.content(activities: [.init(.hydrationCheckIn, .eligible)])
        let one = RF.programme(days: 22...22, todayDay: 29, content: waterOnly) { day in
            var snapshot = RF.nothing(day: day)
            snapshot.log = DailyLog(waterMl: 1200)
            return snapshot
        }
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 4, input: one)).consistencyLines,
                       ["1 of 1 activity partly completed"])
        XCTAssertTrue(Copy.allSurfaces.contains("1 of 1 activity partly completed"))
    }

    func testAWeekWithNoPlansHasNoConsistencyLine() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: ProgrammeReviewInput(state: F.state, today: F.date(ofDay: 29))))
        XCTAssertEqual(review.consistency.withheld, .nothingCounted)
        XCTAssertEqual(review.consistencyLines, [])
        XCTAssertEqual(review.supportLine, Copy.welcomeBack)
    }

    /// Water below the goal and nothing else: credit, but nothing done in full and a percentage
    /// that rounds to nought. Neither nought is stated.
    func testANoughtIsNeverStatedAsAPercentageOrACount() throws {
        let week = RF.programme(days: 22...28, todayDay: 29) { day in
            var snapshot = RF.nothing(day: day)
            if day < 25 { snapshot.log = DailyLog(waterMl: 1200) }
            return snapshot
        }
        let weekly = try XCTUnwrap(Logic.weekly(week: 4, input: week))
        XCTAssertEqual(weekly.consistencyLines, ["4%", "3 of 36 activities partly completed"])

        let programme = RF.programme(days: 1...90, todayDay: 91) { day in
            var snapshot = RF.nothing(day: day)
            if day == 40 { snapshot.log = DailyLog(waterMl: 1200) }
            return snapshot
        }
        let review = try XCTUnwrap(Logic.ninetyDay(programme))
        XCTAssertEqual(review.consistency?.percentage, 0)
        XCTAssertEqual(review.consistencyLines, ["1 of 463 activities partly completed"])
        XCTAssertNil(review.supportLine)
        XCTAssertEqual(review.hydration?.text, "1%, 1 of 90 activities partly completed")
    }

    // ── What you tracked ──

    func testEveryKindIsCountedFromAHandBuiltWeek() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: RF.fullWeeks))
        XCTAssertEqual(review.tracked.map(\.kind), ProgrammeReviewCount.Kind.allCases)
        XCTAssertEqual(review.tracked.map(\.count), [7, 3, 6, 4, 7, 5, 4, 2, 1, 2, 3, 4])
        XCTAssertEqual(review.tracked.map(\.text), [
            "Something recorded on 7 of 7 days", "Nutrition check-in on 3 days", "Water recorded on 6 days",
            "Water goal reached on 4 days", "Sleep recorded for 7 nights", "Mood recorded on 5 days",
            "Energy recorded on 4 days", "Symptoms recorded on 2 days", "1 period start recorded",
            "2 pH readings recorded", "3 ovulation test results recorded", "4 programme lessons read",
        ])
        XCTAssertEqual(review.tracked.map(\.destination), [
            .dailyLog, .nutrition, .hydration, .hydration, .dailyLog, .dailyLog, .dailyLog, .dailyLog,
            .cycle, .phTest, .lhTest, .programmeLesson,
        ])
        XCTAssertEqual(Set(review.tracked.map(\.id)).count, 12)
    }

    func testAZeroIsLeftOutAndTheSeededStartIsNotCounted() throws {
        // Week 3 of the same programme: three days like A, the seeded start, no tests, no lessons.
        let review = try XCTUnwrap(Logic.weekly(week: 3, input: RF.fullWeeks))
        XCTAssertEqual(review.tracked.map(\.kind),
                       [.daysRecorded, .nutritionCheckIns, .waterDays, .sleepNights, .moodCheckIns, .energyCheckIns])
        XCTAssertTrue(review.tracked.allSatisfy { $0.count >= 1 })
        XCTAssertEqual(text(.daysRecorded, in: review.tracked), "Something recorded on 3 of 7 days")

        let worked = try XCTUnwrap(Logic.weekly(week: 4, input: RF.workedWeek))
        XCTAssertEqual(worked.tracked.map(\.kind), [.daysRecorded, .nutritionCheckIns, .waterDays, .waterGoalDays,
                                                    .sleepNights, .moodCheckIns, .energyCheckIns, .phReadings, .lhResults])
        XCTAssertEqual(worked.tracked.map(\.count), [6, 5, 6, 1, 6, 6, 6, 1, 1])
        XCTAssertEqual(text(.waterGoalDays, in: worked.tracked), "Water goal reached on 1 day")
        XCTAssertEqual(text(.phReadings, in: worked.tracked), "1 pH reading recorded")
        XCTAssertEqual(text(.lhResults, in: worked.tracked), "1 ovulation test result recorded")
    }

    /// The test-guidance days carry the Fertility Kit guide's lesson, under its own category.
    func testAReadGuideLessonIsALessonRead() throws {
        XCTAssertEqual(ProgrammeContent.draft.day(40)?.kind, .testGuidance)
        let input = RF.programme(days: 36...42, todayDay: 43) { day in
            var snapshot = RF.nothing(day: day)
            if day == 40 { snapshot.completedLessonIDs = [RF.lessonID(day: day)] }
            return snapshot
        }
        XCTAssertEqual(input.plans.first { $0.day == 40 }?.task(.fertilityKitEducation)?.isDone, true)
        let review = try XCTUnwrap(Logic.weekly(week: 6, input: input))
        XCTAssertEqual(review.tracked.map(\.text), ["1 programme lesson read"])
    }

    /// The plans are one per programme day. Should one arrive twice, its day is still one day.
    func testAPlanGivenTwiceDoesNotCountItsDayTwice() throws {
        var twice = RF.fullWeeks
        twice.plans += twice.plans
        let once = try XCTUnwrap(Logic.weekly(week: 4, input: RF.fullWeeks))
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 4, input: twice)).tracked, once.tracked)
    }

    func testADayWithOnlyAPhReadingIsARecordedDay() throws {
        var input = RF.emptyWeek
        input.phReadingDates = [F.date(ofDay: 24)]
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: input))
        XCTAssertEqual(review.tracked.map(\.kind), [.daysRecorded, .phReadings])
        XCTAssertEqual(review.tracked.map(\.count), [1, 1])
    }

    func testWeekThirteenHasSixDaysAndDayNinetyOneAddsNothing() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 13, input: RF.lastWeek))
        XCTAssertEqual(review.firstDate, F.date(ofDay: 85))
        XCTAssertEqual(review.lastDate, F.date(ofDay: 90))
        XCTAssertEqual(text(.daysRecorded, in: review.tracked), "Something recorded on 6 of 6 days")
        XCTAssertEqual(count(.waterDays, in: review.tracked), 6)
        XCTAssertEqual(count(.waterGoalDays, in: review.tracked), 0)
        XCTAssertEqual(count(.phReadings, in: review.tracked), 1)

        // Day 91 is the seventh date the summary reads. A full log, a reading, a result and a
        // period start on it change nothing, on the day itself or later.
        var after = RF.lastWeek
        after.logsByDate[F.date(ofDay: 91)] = DailyLog(mood: .great, energy: .high, sleepMinutes: 480, waterMl: 3000,
                                                      foodGroups: ["fruit"])
        after.phReadingDates.append(F.date(ofDay: 91))
        after.lhResultDates.append(F.date(ofDay: 91))
        after.cycles = RF.cycles(recordedOnDays: [91])
        XCTAssertEqual(Logic.weekly(week: 13, input: after), review)
        after.today = F.date(ofDay: 95)
        XCTAssertEqual(Logic.weekly(week: 13, input: after), review)
    }

    func testTheDayBeforeTheStartAddsNothingToWeekOne() throws {
        let input = RF.programme(days: 1...7, todayDay: 8) { F.snapshotA(day: $0) }
        let review = try XCTUnwrap(Logic.weekly(week: 1, input: input))
        XCTAssertEqual(count(.daysRecorded, in: review.tracked), 7)

        var before = input
        for offset in 1...7 {
            before.logsByDate[F.start.minusDays(offset)] = DailyLog(mood: .good, sleepMinutes: 400, waterMl: 2400,
                                                                  foodGroups: ["fruit"])
        }
        before.phReadingDates.append(F.start.minusDays(1))
        before.lhResultDates.append(F.start.minusDays(1))
        before.cycles = RF.cycles(recordedOnDays: [0])
        XCTAssertEqual(Logic.weekly(week: 1, input: before), review)
    }

    /// Only dates come in, so a value cannot come out: the input has no field for one, and the
    /// lines about tests are counts.
    func testTestsAreCountsAndNoValueOrClassificationCanAppear() throws {
        let input = RF.fullWeeks
        XCTAssertEqual(Mirror(reflecting: input).children.compactMap(\.label), [
            "state", "today", "goal", "consentActive", "plans", "logsByDate", "waterGoalMl",
            "phReadingDates", "lhResultDates", "cycles", "patterns", "content",
        ])
        XCTAssertTrue(type(of: input.phReadingDates) == [CalendarDate].self)
        XCTAssertTrue(type(of: input.lhResultDates) == [CalendarDate].self)

        let weekly = try XCTUnwrap(Logic.weekly(week: 4, input: input))
        let whole = try XCTUnwrap(Logic.ninetyDay(RF.fullProgramme()))
        let classifications = LhClassification.allCases.map(\.rawValue) + ["healthy", "elevated", "peak", "line"]
        for surface in weekly.surfaces + whole.surfaces where !RF.samplePatterns.map(\.text).contains(surface) {
            for word in classifications {
                XCTAssertNil(surface.range(of: "\\b\(word)\\b", options: [.regularExpression, .caseInsensitive]), surface)
            }
            XCTAssertNil(surface.range(of: "[0-9]\\.[0-9]", options: .regularExpression), surface)
        }
    }

    func testNutritionIsADayCountAndNeverAPercentage() throws {
        let weekly = try XCTUnwrap(Logic.weekly(week: 4, input: RF.fullWeeks))
        XCTAssertEqual(text(.nutritionCheckIns, in: weekly.tracked), "Nutrition check-in on 3 days")
        let whole = try XCTUnwrap(Logic.ninetyDay(RF.fullProgramme()))
        XCTAssertEqual(text(.nutritionCheckIns, in: whole.tracked), "Nutrition check-in on 64 days")
        for surface in weekly.surfaces + whole.surfaces where surface.lowercased().contains("nutrition") {
            XCTAssertFalse(surface.contains("%"), surface)
            XCTAssertFalse(surface.contains(" of "), surface)
        }
        // One food group and all six are the same count.
        var allSix = RF.fullWeeks
        for date in allSix.logsByDate.keys where !(allSix.logsByDate[date]?.foodGroups.isEmpty ?? true) {
            allSix.logsByDate[date]?.foodGroups = Set(FoodGroup.allCases.map(\.rawValue))
        }
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 4, input: allSix)).tracked, weekly.tracked)
    }

    // ── What we noticed ──

    func testRecordedEveryDayNeedsEveryDay() throws {
        let every = ProgrammeEvidenceStatement(level: .observation, text: "You recorded something on every day of the week.")
        XCTAssertTrue(try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 7))).noticed.contains(every))
        XCTAssertFalse(try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 6))).noticed.contains(every))
        // Week 13: six of six is every day.
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 13, input: RF.lastWeek)).noticed, [every])
    }

    func testTheWaterGoalIsNoticedFromFourDays() throws {
        XCTAssertEqual(Logic.waterGoalDaysWorthNoticing, 4)
        let four = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 5, onGoal: 4)))
        XCTAssertEqual(four.noticed, [.init(level: .observation, text: "You reached your water goal on 4 days.")])
        XCTAssertFalse(four.isStillLearning)
        let three = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 5, onGoal: 3)))
        XCTAssertEqual(three.noticed, [])
        XCTAssertTrue(three.isStillLearning)
    }

    /// A water goal of nought would put every day "on goal". It falls back to the default, as it
    /// does in the task engine.
    func testAWaterGoalOfNoughtDoesNotInventGoalDays() throws {
        var input = twoWeeks(logged: 5)
        input.waterGoalMl = 0
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: input))
        XCTAssertEqual(count(.waterGoalDays, in: review.tracked), 0)
        XCTAssertEqual(review.noticed, [])
    }

    func testRecordedDaysAreComparedOnlyWhenBothWeeksHaveSome() throws {
        let both = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 1, weekBefore: 1)))
        XCTAssertTrue(both.noticed.contains(.init(
            level: .withinWeekTrend, text: "You recorded something on 1 day this week and 1 the week before.")))
        let more = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 5, weekBefore: 3)))
        XCTAssertTrue(more.noticed.contains(.init(
            level: .withinWeekTrend, text: "You recorded something on 5 days this week and 3 the week before.")))

        let nothingBefore = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 1, weekBefore: 0)))
        XCTAssertFalse(nothingBefore.noticed.contains { $0.level == .withinWeekTrend })
        let nothingNow = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 0, weekBefore: 1)))
        XCTAssertEqual(nothingNow.noticed, [])
    }

    /// Week 13 has six days and week 12 has seven. Six beside seven would read as a drop that is
    /// only the calendar, so the two counts of days are not set side by side. Percentages still are.
    func testWeekThirteensRecordedDaysAreNotSetBesideASevenDayWeek() throws {
        let input = RF.programme(days: 71...90, todayDay: 91) { F.snapshotA(day: $0) }
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 12, input: input)).noticed.map(\.text), [
            "You recorded something on every day of the week.",
            "You recorded something on 7 days this week and 7 the week before.",
            "Your programme consistency was 93% this week and 93% the week before.",
        ])
        XCTAssertEqual(try XCTUnwrap(Logic.weekly(week: 13, input: input)).noticed.map(\.text), [
            "You recorded something on every day of the week.",
            "Your programme consistency was 93% this week and 93% the week before.",
        ])
    }

    func testConsistencyIsComparedOnlyWhenBothWeeksCarryAPercentage() throws {
        // Week 4 is seven days like A. Week 3 is one day with four daily activities counted, plus
        // the week's pH reading (five counted) or without pH logging at all (four counted).
        func input(weekBeforeCountsFive: Bool) -> ProgrammeReviewInput {
            RF.programme(days: 21...28, todayDay: 29) { day in
                var snapshot = F.snapshotA(day: day)
                if day == 21 {
                    snapshot.supplementsAnswer = "no"
                    snapshot.phReadingExistsThisProgrammeWeek = false
                    snapshot.phLoggingAvailable = weekBeforeCountsFive
                }
                return snapshot
            }
        }
        let five = input(weekBeforeCountsFive: true)
        XCTAssertEqual(ProgrammeConsistency.period(five.plans, days: 15...21, todayDay: 29).counted, 5)
        XCTAssertTrue(try XCTUnwrap(Logic.weekly(week: 4, input: five)).noticed.contains(.init(
            level: .withinWeekTrend, text: "Your programme consistency was 93% this week and 73% the week before.")))

        let four = input(weekBeforeCountsFive: false)
        XCTAssertEqual(ProgrammeConsistency.period(four.plans, days: 15...21, todayDay: 29).counted, 4)
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: four))
        XCTAssertFalse(review.noticed.contains { $0.text.contains("%") })
        XCTAssertTrue(review.noticed.contains { $0.level == .withinWeekTrend }, "the recorded days are still compared")
    }

    /// A week with nothing recorded has a percentage of nought. It is not set beside another week.
    func testAPercentageOfNoughtIsNeverCompared() throws {
        let emptyBefore = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 7, weekBefore: 0)))
        XCTAssertEqual(emptyBefore.noticed.map(\.text), [Copy.recordedEveryDay])
        let emptyNow = try XCTUnwrap(Logic.weekly(week: 4, input: twoWeeks(logged: 0, weekBefore: 7)))
        XCTAssertEqual(emptyNow.noticed, [])
    }

    func testWeekOneHasNoLevelTwoNoteAndNoNoteIsEverAboveLevelTwo() throws {
        let first = try XCTUnwrap(Logic.weekly(week: 1, input: RF.programme(days: 1...7, todayDay: 8) { F.snapshotA(day: $0) }))
        XCTAssertEqual(first.noticed.map(\.level), [.observation])

        let full = try XCTUnwrap(Logic.weekly(week: 4, input: RF.fullWeeks))
        XCTAssertEqual(full.noticed, [
            .init(level: .observation, text: "You recorded something on every day of the week."),
            .init(level: .observation, text: "You reached your water goal on 4 days."),
            .init(level: .withinWeekTrend, text: "You recorded something on 7 days this week and 3 the week before."),
            .init(level: .withinWeekTrend, text: "Your programme consistency was 78% this week and 41% the week before."),
        ])
        let everyWeek = RF.fullProgramme()
        for week in 1...13 {
            let review = try XCTUnwrap(Logic.weekly(week: week, input: everyWeek))
            XCTAssertTrue(review.noticed.allSatisfy { $0.level <= .withinWeekTrend }, "week \(week)")
            XCTAssertEqual(review.isStillLearning, review.noticed.isEmpty)
        }
    }

    // ── Strongest routine ──

    func testAClearWinnerIsTheStrongestRoutine() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: RF.fullWeeks))
        let routine = try XCTUnwrap(review.strongestRoutine)
        XCTAssertEqual(routine.category, .sleepCheckIn)
        XCTAssertEqual(routine.name, "Sleep check-in")
        XCTAssertEqual(routine.figure.percentage, 100)
        XCTAssertEqual(routine.text, "100%, 7 of 7 activities completed")
    }

    func testATieAtTheTopNamesNoRoutine() throws {
        // The worked week: mood, energy and sleep are each six of seven.
        XCTAssertNil(try XCTUnwrap(Logic.weekly(week: 4, input: RF.workedWeek)).strongestRoutine)
    }

    func testFewerThanFiveCountedNamesNoRoutine() throws {
        let fourDays = RF.programme(days: 22...25, todayDay: 29) { day in
            var snapshot = RF.nothing(day: day)
            snapshot.log = DailyLog(sleepMinutes: 420)
            return snapshot
        }
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: fourDays))
        XCTAssertEqual(count(.sleepNights, in: review.tracked), 4)
        XCTAssertNil(review.strongestRoutine)
    }

    func testARoutineNeedsFiftyPerCent() throws {
        XCTAssertEqual(Logic.strongestRoutineMinimumPercentage, 50)
        func week(waterMl: Int) -> ProgrammeReviewInput {
            RF.programme(days: 22...28, todayDay: 29) { day in
                var snapshot = RF.nothing(day: day)
                snapshot.log = DailyLog(waterMl: waterMl)
                return snapshot
            }
        }
        let half = try XCTUnwrap(Logic.weekly(week: 4, input: week(waterMl: 1200)))
        XCTAssertEqual(half.strongestRoutine?.category, .hydrationCheckIn)
        XCTAssertEqual(half.strongestRoutine?.text, "50%, 7 of 7 activities partly completed")
        XCTAssertNil(try XCTUnwrap(Logic.weekly(week: 4, input: week(waterMl: 1150))).strongestRoutine)
    }

    /// With content that counts the nutrition check-in, and nutrition recorded on more days than
    /// anything else, the routine named is still the next one down.
    func testNutritionIsNeverTheStrongestRoutine() throws {
        let counted = F.content(.nutritionCheckIn, .eligible)
        // Food groups on every day, sleep on six days in seven.
        func snapshot(_ day: Int) -> ProgrammeDaySnapshot {
            var snapshot = RF.nothing(day: day)
            snapshot.log = DailyLog(sleepMinutes: day % 7 != 0 ? 420 : nil, foodGroups: ["fruit"])
            return snapshot
        }
        let week = RF.programme(days: 22...28, todayDay: 29, content: counted, snapshot: snapshot)
        let weekPlans = ProgrammeConsistency.report(state: F.state, today: week.today, plans: week.plans)
        XCTAssertEqual(weekPlans.categories[.nutritionCheckIn]?.percentage, 100, "the content does count it")
        XCTAssertEqual(weekPlans.categories[.sleepCheckIn]?.percentage, 86)
        let weekly = try XCTUnwrap(Logic.weekly(week: 4, input: week))
        XCTAssertEqual(weekly.strongestRoutine?.category, .sleepCheckIn)

        // Nutrition alone at the top, everything else under fifty per cent: nothing is named.
        let alone = RF.programme(days: 22...28, todayDay: 29, content: counted) { day in
            var snapshot = RF.nothing(day: day)
            snapshot.log = DailyLog(foodGroups: ["fruit"])
            return snapshot
        }
        XCTAssertNil(try XCTUnwrap(Logic.weekly(week: 4, input: alone)).strongestRoutine)

        let programme = RF.programme(days: 1...90, todayDay: 91, content: counted, snapshot: snapshot)
        let whole = try XCTUnwrap(Logic.ninetyDay(programme))
        XCTAssertEqual(whole.strongestRoutines.map(\.category), [.sleepCheckIn])
        XCTAssertEqual(whole.whatToContinue, ["Continue with your sleep check-in.", Copy.continueClosing])
        for surface in weekly.surfaces + whole.surfaces where surface.lowercased().contains("nutrition") {
            XCTAssertFalse(surface.contains("%"), surface)
        }
    }

    // ── Next week's focus ──

    func testNextFocusIsTheFollowingWeeksContent() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: RF.workedWeek))
        let next = try XCTUnwrap(review.nextFocus)
        let week5 = try XCTUnwrap(ProgrammeContent.draft.week(5))
        XCTAssertEqual(next.week, 5)
        XCTAssertEqual(next.themeTitle, week5.themeTitle)
        XCTAssertEqual(next.purpose, week5.purpose)
        XCTAssertEqual(next.nutritionFocusTitle, week5.nutritionFocus.title)
        XCTAssertEqual(next.leadingActivities.count, 3)

        XCTAssertNil(try XCTUnwrap(Logic.weekly(week: 13, input: RF.lastWeek)).nextFocus)
    }

    func testTheGoalOrdersTheActivitiesAndAnAbsentFeatureIsLeftOut() throws {
        func leading(_ goal: ProgrammeGoalEmphasis, scan: Bool) throws -> [String] {
            let input = RF.programme(days: 22...28, todayDay: 29, goal: goal) { day in
                var snapshot = F.snapshotA(day: day)
                snapshot.scanFeaturesAvailable = scan
                return snapshot
            }
            return try XCTUnwrap(Logic.weekly(week: 4, input: input)?.nextFocus).leadingActivities
        }
        XCTAssertEqual(try leading(.understandMyCycle, scan: false), ["Mood check-in", "Energy check-in", "Symptom check-in"])
        XCTAssertEqual(try leading(.prepareForPregnancy, scan: false), ["Nutrition check-in", "Hydration check-in", "Sleep check-in"])
        // Day A is outside the predicted window, which is no reason to leave the test out.
        XCTAssertEqual(try leading(.tryingToConceive, scan: true), ["Ovulation test", "pH test", "Mood check-in"])
        XCTAssertEqual(try leading(.tryingToConceive, scan: false), ["pH test", "Mood check-in", "Energy check-in"])
    }

    func testAnActivityHerOnboardingAnswerRulesOutIsLeftOut() throws {
        let content = RF.content(activities: [.init(.moodCheckIn, .eligible), .init(.supplementCheckIn, .eligible),
                                              .init(.sleepCheckIn, .eligible), .init(.pregnancyTestRelatedAction, .optional)])
        func leading(supplements answer: String) throws -> [String] {
            let input = RF.programme(days: 22...28, todayDay: 29, goal: .prepareForPregnancy, content: content) { day in
                var snapshot = F.snapshotA(day: day)
                snapshot.supplementsAnswer = answer
                return snapshot
            }
            return try XCTUnwrap(Logic.weekly(week: 4, input: input)?.nextFocus).leadingActivities
        }
        XCTAssertEqual(try leading(supplements: "yes"), ["Sleep check-in", "Supplement check-in", "Mood check-in"])
        XCTAssertEqual(try leading(supplements: "no"), ["Sleep check-in", "Mood check-in"])
    }

    // ── An empty week ──

    func testAnEmptyWeekSaysSoOnceAndOffersSupport() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: RF.emptyWeek))
        XCTAssertTrue(review.consistency.nothingRecorded)
        XCTAssertEqual(review.consistencyLines, ["No Programme activities recorded."])
        XCTAssertEqual(review.supportLine, "Welcome back. Continue with today.")
        XCTAssertEqual(review.tracked, [])
        XCTAssertNil(review.strongestRoutine)
        XCTAssertEqual(review.noticed, [])
        XCTAssertTrue(review.isStillLearning)
        XCTAssertTrue(review.surfaces.contains(ProgrammeEvidenceCopy.stillLearning))
        XCTAssertNotNil(review.nextFocus, "next week is still set out")
        for surface in review.surfaces {
            XCTAssertNil(surface.range(of: "\\b0\\b", options: .regularExpression), surface)
        }
    }

    // ── Records that no figure counts ──

    /// The draft schedule never counts food groups, symptoms or lessons. A week holding only
    /// those has records and no credit: it is not called a week with nothing recorded, and she is
    /// not welcomed back. The consistency section says nothing, since a nought is never stated.
    func testAWeekOfRecordsNoFigureCountsIsNotCalledEmpty() throws {
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: RF.uncountedRecordsOnly(days: 22...28, todayDay: 29)))
        XCTAssertTrue(review.consistency.nothingRecorded, "activities were counted and none has credit")
        XCTAssertEqual(review.tracked.map(\.text), [
            "Something recorded on 7 of 7 days", "Nutrition check-in on 7 days",
            "Symptoms recorded on 7 days", "7 programme lessons read",
        ])
        XCTAssertEqual(review.consistencyLines, [])
        XCTAssertNil(review.supportLine)
        XCTAssertEqual(review.noticed.map(\.text), ["You recorded something on every day of the week."])
        XCTAssertNil(review.strongestRoutine)
        XCTAssertFalse(review.surfaces.contains(Copy.nothingRecorded))
        XCTAssertFalse(review.surfaces.contains(Copy.welcomeBack))
    }

    /// One record is enough: a single period start in a week with nothing else.
    func testOneRecordIsEnoughForAWeekNotToBeCalledEmpty() throws {
        var input = RF.emptyWeek
        input.cycles = RF.cycles(recordedOnDays: [24])
        let review = try XCTUnwrap(Logic.weekly(week: 4, input: input))
        XCTAssertTrue(review.consistency.nothingRecorded)
        XCTAssertEqual(review.tracked.map(\.text), ["1 period start recorded"])
        XCTAssertEqual(review.consistencyLines, [])
        XCTAssertNil(review.supportLine)
    }

    func testAProgrammeOfRecordsNoFigureCountsIsNotCalledEmpty() throws {
        let review = try XCTUnwrap(Logic.ninetyDay(RF.uncountedRecordsOnly(days: 1...90, todayDay: 91)))
        XCTAssertEqual(review.consistency?.nothingRecorded, true)
        XCTAssertEqual(review.tracked.map(\.text), [
            "Something recorded on 90 of 90 days", "Nutrition check-in on 90 days",
            "Symptoms recorded on 90 days", "90 programme lessons read",
        ])
        XCTAssertEqual(review.consistencyLines, [])
        XCTAssertNil(review.supportLine)
        XCTAssertNil(review.hydration)
        XCTAssertNil(review.sleep)
        XCTAssertEqual(review.strongestRoutines, [])
        XCTAssertEqual(review.whatToContinue, [Copy.continueClosing])
        XCTAssertFalse(review.surfaces.contains(Copy.nothingRecorded))
        XCTAssertFalse(review.surfaces.contains(Copy.pickUpYourRoutine))
    }

    // ── The 90-day review ──

    func testTheThirteenWeeklyReviewsAddUpToTheNinetyDayReview() throws {
        let input = RF.fullProgramme()
        let whole = try XCTUnwrap(Logic.ninetyDay(input))
        let weeks = try (1...13).map { try XCTUnwrap(Logic.weekly(week: $0, input: input)) }
        XCTAssertEqual(whole.tracked.map(\.kind), ProgrammeReviewCount.Kind.allCases)
        for kind in ProgrammeReviewCount.Kind.allCases {
            XCTAssertEqual(count(kind, in: whole.tracked), weeks.reduce(0) { $0 + count(kind, in: $1.tracked) }, "\(kind)")
        }

        // And against the pattern the programme was built on: 64 days like A, 13 like B, 13 like C.
        let daysLikeA = (1...90).filter { $0 % 7 != 4 && $0 % 7 != 5 }
        XCTAssertEqual(whole.tracked.map(\.count), [
            77, 64, 77, 13, 77, 77, 77, daysLikeA.filter { $0 % 5 == 0 }.count, 4, 13, 13,
            daysLikeA.filter { $0 % 3 == 0 }.count,
        ])
        XCTAssertEqual(text(.daysRecorded, in: whole.tracked), "Something recorded on 77 of 90 days")
        XCTAssertEqual(text(.periodStarts, in: whole.tracked), "4 period starts recorded")
        XCTAssertEqual(whole.firstDate, F.date(ofDay: 1))
        XCTAssertEqual(whole.lastDate, F.date(ofDay: 90))
        XCTAssertEqual(whole.headline, "Your 90-Day Review")
    }

    func testTheNinetyDayFiguresAreTheReportsFigures() throws {
        let input = RF.fullProgramme()
        let whole = try XCTUnwrap(Logic.ninetyDay(input))
        let report = ProgrammeConsistency.report(state: input.state, today: input.today, plans: input.plans)
        XCTAssertEqual(whole.consistency, report.programme)
        let percentage = try XCTUnwrap(report.programme.percentage)
        XCTAssertEqual(whole.consistencyLines.first, "\(percentage)%")
        XCTAssertEqual(whole.consistencyLines.count, 2)
        XCTAssertNil(whole.supportLine)

        XCTAssertEqual(whole.hydration?.category, .hydrationCheckIn)
        XCTAssertEqual(whole.hydration?.name, "Hydration check-in")
        XCTAssertEqual(whole.hydration?.figure, report.categories[.hydrationCheckIn])
        XCTAssertEqual(whole.sleep?.figure, report.categories[.sleepCheckIn])
        XCTAssertEqual(whole.sleep?.text, "86%, 77 of 90 activities completed")
    }

    func testReadingLaterOrWithLaterRecordsChangesNothing() throws {
        let whole = try XCTUnwrap(Logic.ninetyDay(RF.fullProgramme()))
        var later = RF.fullProgramme(todayDay: 120)
        for day in 91...119 {
            later.logsByDate[F.date(ofDay: day)] = DailyLog(mood: .good, sleepMinutes: 400, waterMl: 2400, foodGroups: ["fruit"])
            later.phReadingDates.append(F.date(ofDay: day))
            later.lhResultDates.append(F.date(ofDay: day))
        }
        XCTAssertEqual(Logic.ninetyDay(later), whole)
    }

    func testEveryTiedLeaderIsAStrongestRoutine() throws {
        // The full programme: every ovulation test that counted was done, and so was every
        // week's pH reading.
        let whole = try XCTUnwrap(Logic.ninetyDay(RF.fullProgramme()))
        XCTAssertEqual(whole.strongestRoutines.map(\.category), [.lhTest, .phTest])
        XCTAssertEqual(whole.strongestRoutines.map(\.figure.percentage), [100, 100])
        XCTAssertEqual(whole.whatToContinue, ["Continue with your ovulation test.", "Continue with your pH test.",
                                              "Everything in your Fertility Kit stays available. Continue with today."])

        // Without tests: sleep, mood, energy and supplements are level, in the category order.
        let daily = RF.programme(days: 1...90, todayDay: 91) { day in
            var snapshot = day % 7 == 5 ? F.snapshotC(day: day) : F.snapshotA(day: day)
            snapshot.phReadingExistsThisProgrammeWeek = false
            return snapshot
        }
        let level = try XCTUnwrap(Logic.ninetyDay(daily))
        XCTAssertEqual(level.strongestRoutines.map(\.category),
                       [.sleepCheckIn, .moodCheckIn, .energyCheckIn, .supplementCheckIn])
        XCTAssertEqual(level.whatToContinue.count, 5)
    }

    func testACrossCycleStatementNeedsThreeCountableCycles() throws {
        var input = RF.fullProgramme()
        XCTAssertEqual(CycleHistory.countableCycles(input.cycles).count, 3)
        let earned = try XCTUnwrap(Logic.ninetyDay(input))
        XCTAssertEqual(earned.patterns.map(\.level), [.observation, .withinWeekTrend, .withinCyclePattern, .crossCyclePattern])
        XCTAssertFalse(earned.isStillLearning)
        XCTAssertFalse(earned.surfaces.contains(ProgrammeEvidenceCopy.stillLearning))

        // Two countable cycles, then one cycle, then none: levels 1 to 3 stay, level 4 goes.
        for cycles in [RF.cycles(seededOnDay: 1, recordedOnDays: [22, 45, 68]),
                       RF.cycles(recordedOnDays: [22]),
                       []] {
            input.cycles = cycles
            XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(cycles))
            let review = try XCTUnwrap(Logic.ninetyDay(input))
            XCTAssertEqual(review.patterns.map(\.level), [.observation, .withinWeekTrend, .withinCyclePattern])
            XCTAssertFalse(review.patterns.contains(RF.samplePatterns[0]))
            XCTAssertTrue(review.isStillLearning)
            XCTAssertTrue(review.surfaces.contains(ProgrammeEvidenceCopy.stillLearning))
        }
    }

    func testPatternsKeepTheirOrderWithinALevel() throws {
        var input = RF.fullProgramme()
        input.patterns = [.init(level: .withinWeekTrend, text: "b"), .init(level: .observation, text: "c"),
                          .init(level: .withinWeekTrend, text: "a"), .init(level: .observation, text: "d")]
        XCTAssertEqual(try XCTUnwrap(Logic.ninetyDay(input)).patterns.map(\.text), ["c", "d", "b", "a"])
    }

    func testAProgrammeWithNothingRecordedOmitsEverything() throws {
        let review = try XCTUnwrap(Logic.ninetyDay(RF.emptyProgramme))
        XCTAssertEqual(review.tracked, [])
        XCTAssertEqual(review.consistency?.nothingRecorded, true)
        XCTAssertEqual(review.consistencyLines, ["No Programme activities recorded."])
        XCTAssertNil(review.hydration)
        XCTAssertNil(review.sleep)
        XCTAssertEqual(review.strongestRoutines, [])
        XCTAssertEqual(review.patterns, [])
        XCTAssertTrue(review.isStillLearning)
        XCTAssertEqual(review.whatToContinue, [Copy.continueClosing])
        XCTAssertEqual(review.supportLine, "Pick up your routine whenever you are ready.")
        for surface in review.surfaces {
            XCTAssertNil(surface.range(of: "\\b0\\b", options: .regularExpression), surface)
        }

        // With no plans at all there is no figure either.
        let bare = try XCTUnwrap(Logic.ninetyDay(ProgrammeReviewInput(state: F.state, today: F.date(ofDay: 91))))
        XCTAssertNil(bare.consistency)
        XCTAssertEqual(bare.consistencyLines, [])
        XCTAssertEqual(bare.tracked, [])
        XCTAssertEqual(bare.supportLine, Copy.pickUpYourRoutine)
        XCTAssertEqual(bare.surfaces, ["Your 90-Day Review", ProgrammeEvidenceCopy.stillLearning,
                                       Copy.continueClosing, Copy.pickUpYourRoutine])
    }

    // ── What a review never reads ──

    func testTheIntimacyFieldChangesNothing() throws {
        func input(_ recorded: Bool) -> ProgrammeReviewInput {
            RF.programme(days: 1...90, todayDay: 91) { day in
                // A day with nothing else in its log, and days with everything else.
                var snapshot = day % 7 == 5 ? RF.nothing(day: day) : F.snapshotA(day: day)
                if day % 7 == 5 { snapshot.log = DailyLog() }
                snapshot.log?.sexualActivity = recorded
                return snapshot
            }
        }
        XCTAssertNotEqual(input(true).logsByDate, input(false).logsByDate)
        for week in 1...13 {
            XCTAssertEqual(Logic.weekly(week: week, input: input(true)), Logic.weekly(week: week, input: input(false)))
        }
        XCTAssertEqual(Logic.ninetyDay(input(true)), Logic.ninetyDay(input(false)))
        XCTAssertNotNil(Logic.ninetyDay(input(true)))
    }
}
