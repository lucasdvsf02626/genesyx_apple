import XCTest
import GenesyxCore
@testable import Genesyx

/// What the Programme Reviews list and the two review screens are given: the list around the
/// first and last weeks, the consistency card, and the two reviews as core builds them from the
/// context the screens read.
@MainActor
final class ProgrammeReviewScreenTests: XCTestCase {

    private let today = CalendarDate(2026, 11, 20)

    private typealias Presentation = ProgrammeReviewPresentation

    private func fullLog(water: Int = 2_400) -> DailyLog {
        DailyLog(mood: .good, energy: .normal, sleepMinutes: 450, waterMl: water)
    }

    /// A log on each programme day from the first to `lastDay`.
    private func logs(startedOn start: CalendarDate, days: ClosedRange<Int>, _ log: DailyLog) -> [CalendarDate: DailyLog] {
        Dictionary(uniqueKeysWithValues: days.map { (start.plusDays($0 - 1), log) })
    }

    private func context(day: Int, logs: [CalendarDate: DailyLog] = [:], cycles: [DerivedCycle] = [],
                         scan: Bool = true, lhResults: [LhResult] = []) -> FertilityKitContext {
        KitFixture.context(today: today, day: day, scan: scan, logs: logs, cycles: cycles, lhResults: lhResults)
    }

    private func recordedCycle(_ start: CalendarDate, length: Int?) -> DerivedCycle {
        DerivedCycle(start: start, end: length.map { start.plusDays($0 - 1) }, length: length, periodDays: 5,
                     source: .recorded, closingSource: length == nil ? nil : .recorded)
    }

    // MARK: - The list

    func testTheListAroundTheFirstWeek() {
        let day3 = Presentation.listing(in: context(day: 3))
        XCTAssertEqual(day3.weeks, [])
        XCTAssertEqual(day3.nextReview, ProgrammeReviewScreenCopy.nextReviewReady(
            1, FertilityKitDates.dayMonth(today.plusDays(5))))
        XCTAssertFalse(day3.noReviewsYet, "the next review is named, so there is nothing more to say")

        let day7 = Presentation.listing(in: context(day: 7))
        XCTAssertEqual(day7.weeks, [], "week 1 ends today, so it has no review yet (R-160)")
        XCTAssertEqual(day7.nextReview, ProgrammeReviewScreenCopy.nextReviewReadyTomorrow(1))

        let day8 = Presentation.listing(in: context(day: 8))
        XCTAssertEqual(day8.weeks.map(\.number), [1])
        XCTAssertEqual(day8.weeks.first?.title, ProgrammeReviewScreenCopy.weekRow(1))
        XCTAssertEqual(day8.weeks.first?.dates, FertilityKitDates.range(today.minusDays(7), today.minusDays(1)))
        XCTAssertEqual(day8.nextReview, ProgrammeReviewScreenCopy.nextReviewReady(
            2, FertilityKitDates.dayMonth(today.plusDays(7))))
    }

    func testTheListAroundTheLastWeek() {
        let day90 = Presentation.listing(in: context(day: 90))
        XCTAssertEqual(day90.weeks.map(\.number), Array((1...12).reversed()), "newest first")
        XCTAssertEqual(day90.nextReview, ProgrammeReviewScreenCopy.nextReviewReadyTomorrow(13))
        XCTAssertFalse(day90.ninetyDayAvailable, "never a disabled row")
        XCTAssertEqual(day90.ninetyDayNote, ProgrammeReviewScreenCopy.ninetyDayReady(
            FertilityKitDates.dayMonth(today.plusDays(1))))

        let day91 = Presentation.listing(in: context(day: 91))
        XCTAssertEqual(day91.weeks.map(\.number), Array((1...13).reversed()))
        XCTAssertTrue(day91.ninetyDayAvailable)
        XCTAssertNil(day91.ninetyDayNote)
        XCTAssertNil(day91.nextReview)
        XCTAssertEqual(day91.ninetyDayDates, FertilityKitDates.range(today.minusDays(90), today.minusDays(1)))
    }

    func testTheListBeforeAndAfterTheProgramme() {
        XCTAssertEqual(Presentation.listing(in: context(day: 1)).weeks, [])
        let notStarted = KitFixture.context(today: today)
        XCTAssertEqual(Presentation.listing(in: notStarted), Presentation.Listing())
        XCTAssertFalse(Presentation.listing(in: notStarted).hasWeeklySection)

        let scheduled = Presentation.listing(in: KitFixture.context(today: today, startsIn: 3))
        XCTAssertTrue(scheduled.noReviewsYet)
        XCTAssertNil(scheduled.nextReview)

        // Stopped on day 20: weeks 1 and 2 ended before it, and nothing more is coming.
        let stopped = KitFixture.context(today: today, state: ProgrammeState(
            startedOn: today.minusDays(29), stoppedOn: today.minusDays(9)))
        let listing = Presentation.listing(in: stopped)
        XCTAssertEqual(listing.weeks.map(\.number), [2, 1])
        XCTAssertNil(listing.nextReview)
        XCTAssertNil(listing.ninetyDayNote)
        XCTAssertFalse(listing.noReviewsYet)
    }

    // MARK: - The consistency card

    func testNoPercentageBelowFiveCountedActivitiesAndNeverANoughtPerCent() {
        let start = today.minusDays(1)
        let kit = context(day: 2, logs: logs(startedOn: start, days: 1...1, fullLog()))
        let report = kit.report()
        XCTAssertLessThan(report.programme.counted, ProgrammeConsistency.minimumCountedForPercentage)
        let card = Presentation.consistency(in: kit)
        XCTAssertFalse(card.isEmpty)
        let words = (card.overall + card.activities).flatMap(\.lines)
        XCTAssertFalse(words.contains { $0.contains("%") }, "\(words)")
        XCTAssertFalse(words.contains { $0.range(of: "(?<![0-9])0%", options: .regularExpression) != nil })
    }

    func testTheThirtyDayRowAsATable() {
        for (day, shown) in [(1, false), (30, false), (31, true), (90, true), (91, true), (92, false), (100, false), (121, false)] {
            XCTAssertEqual(Presentation.showsLastThirtyDays(day: day), shown, "day \(day)")
        }
        // Through the card, with a log on every programme day so every figure has lines.
        for (day, shown) in [(30, false), (31, true), (40, true)] {
            let kit = KitFixture.context(today: today.minusDays(40 - day), day: day,
                                         logs: logs(startedOn: today.minusDays(day - 1), days: 1...max(day - 1, 1), fullLog()))
            let ids = Presentation.consistency(in: kit).overall.map(\.identifier)
            XCTAssertEqual(ids.contains("kit.reviews.consistency.last30"), shown, "day \(day)")
        }
    }

    func testNutritionIsNeverInTheActivityListAndNoActivityHasAnEmptyName() {
        let kit = context(day: 40, logs: logs(startedOn: today.minusDays(39), days: 1...39,
                                              DailyLog(mood: .good, energy: .normal, sleepMinutes: 450, waterMl: 2_400,
                                                       foodGroups: ["vegetables", "fruit"])))
        let ids = Presentation.consistency(in: kit).activities.map(\.identifier)
        XCTAssertFalse(ids.isEmpty)
        XCTAssertFalse(ids.contains("kit.reviews.consistency.activity.nutritionCheckIn"))
        XCTAssertFalse(ids.contains("kit.reviews.consistency.activity.pregnancyTestRelatedAction"))
        for figure in Presentation.consistency(in: kit).activities {
            XCTAssertFalse(figure.title.isEmpty)
            XCTAssertEqual(figure.lines.count, 1, "one line each: the name and its figure, never ranked")
        }
    }

    func testTodaysRecordsDoNotMoveThePeriodFigures() {
        let start = today.minusDays(14)
        let before = logs(startedOn: start, days: 1...14, fullLog())
        var after = before
        after[today] = fullLog(water: 3_000)
        let card = Presentation.consistency(in: context(day: 15, logs: before))
        XCTAssertFalse(card.isEmpty)
        XCTAssertEqual(Presentation.consistency(in: context(day: 15, logs: after)), card, "R-145")
        XCTAssertEqual(context(day: 15, logs: after).report().week, context(day: 15, logs: before).report().week)
    }

    // MARK: - The weekly review

    func testAFullyMissedWeekHasOneLineAndTheSupportLine() throws {
        let kit = context(day: 15)
        let review = try XCTUnwrap(ProgrammeReviewLogic.weekly(week: 1, input: kit.reviewInput()))
        XCTAssertEqual(review.consistencyLines, [ProgrammeReviewCopy.nothingRecorded])
        XCTAssertEqual(review.supportLine, ProgrammeReviewCopy.welcomeBack, "compared by reference, R-168")
        XCTAssertEqual(review.tracked, [], "no tracked list beside the missed line, R-142")
    }

    func testAWeekThatEndedAtWeekThirteenHasNoNextFocus() throws {
        let kit = context(day: 91)
        let last = try XCTUnwrap(ProgrammeReviewLogic.weekly(week: 13, input: kit.reviewInput()))
        XCTAssertNil(last.nextFocus, "R-165")
        let fifth = try XCTUnwrap(ProgrammeReviewLogic.weekly(week: 5, input: kit.reviewInput()))
        XCTAssertEqual(fifth.nextFocus?.week, 6)
        XCTAssertNil(ProgrammeReviewLogic.weekly(week: 14, input: kit.reviewInput()))
    }

    func testAWeekWithATieHasNoStrongestRoutineAndOneLeaderHasOne() throws {
        let start = today.minusDays(14)
        let tied = context(day: 15, logs: logs(startedOn: start, days: 1...7, fullLog()))
        let review = try XCTUnwrap(ProgrammeReviewLogic.weekly(week: 1, input: tied.reviewInput()))
        XCTAssertNil(review.strongestRoutine, "mood, energy, sleep and water all reach the same figure, R-164")

        let moodOnly = context(day: 15, logs: logs(startedOn: start, days: 1...7, DailyLog(mood: .good)))
        let leader = try XCTUnwrap(ProgrammeReviewLogic.weekly(week: 1, input: moodOnly.reviewInput()))
        XCTAssertEqual(leader.strongestRoutine?.category, .moodCheckIn)
    }

    func testWithoutScanningNoLhDateIsCarriedAndNoRowRoutesToAnOvulationTest() throws {
        let at = today.minusDays(3).toDate(calendar: .autoupdatingCurrent)
        let result = LhResult(recordedAt: at, cycleDay: nil, classification: .low)
        let with = context(day: 15, scan: true, lhResults: [result])
        let without = context(day: 15, scan: false, lhResults: [result])
        XCTAssertEqual(with.reviewInput().lhResultDates.count, 1)
        XCTAssertEqual(without.reviewInput().lhResultDates, [], "R-167")
        let review = try XCTUnwrap(ProgrammeReviewLogic.weekly(week: 1, input: without.reviewInput()))
        XCTAssertFalse(review.tracked.contains { $0.kind == .lhResults })
        XCTAssertEqual(FertilityKitRoutes.route(for: .lhTest, in: without), .unavailable)
        XCTAssertEqual(FertilityKitRoutes.route(for: .lhTest, in: with), .scan(.ovulationTest))
    }

    // MARK: - The 90-Day Review

    private let observation = ProgrammeEvidenceStatement(level: .observation, text: "A recorded fact.")
    private let withinCycle = ProgrammeEvidenceStatement(level: .withinCyclePattern, text: "A pattern inside one cycle.")
    private let acrossCycles = ProgrammeEvidenceStatement(level: .crossCyclePattern, text: "A pattern across cycles.")

    private func ninetyDay(cycles: [DerivedCycle], patterns: [ProgrammeEvidenceStatement]) throws -> ProgrammeNinetyDayReview {
        let kit = context(day: 95, cycles: cycles)
        return try XCTUnwrap(ProgrammeReviewLogic.ninetyDay(kit.reviewInput(patterns: patterns)))
    }

    func testTwoRecordedCyclesShowTheLowerPatternsAndTheStillLearningSentenceTogether() throws {
        let first = today.minusDays(120)
        let cycles = [recordedCycle(first, length: 28), recordedCycle(first.plusDays(28), length: 28),
                      recordedCycle(first.plusDays(56), length: nil)]
        let review = try ninetyDay(cycles: cycles, patterns: [observation, withinCycle, acrossCycles])
        XCTAssertEqual(review.patterns, [observation, withinCycle], "nothing across cycles from two")
        XCTAssertTrue(review.isStillLearning)
        XCTAssertTrue(Presentation.showsPatterns(review))
    }

    func testThreeCountableCyclesShowTheCrossCyclePatternAndNoStillLearningSentence() throws {
        let first = today.minusDays(150)
        let cycles = [recordedCycle(first, length: 28), recordedCycle(first.plusDays(28), length: 28),
                      recordedCycle(first.plusDays(56), length: 28), recordedCycle(first.plusDays(84), length: nil)]
        let review = try ninetyDay(cycles: cycles, patterns: [acrossCycles, observation])
        XCTAssertEqual(review.patterns, [observation, acrossCycles], "lowest level first")
        XCTAssertFalse(review.isStillLearning)

        let empty = try ninetyDay(cycles: cycles, patterns: [])
        XCTAssertEqual(empty.patterns, [])
        XCTAssertFalse(empty.isStillLearning)
        XCTAssertFalse(Presentation.showsPatterns(empty), "no Patterns section")
    }

    func testAFullyMissedProgrammeHasTheNeutralLineAndTheSupportLine() throws {
        let review = try ninetyDay(cycles: [], patterns: [])
        XCTAssertEqual(review.consistencyLines, [ProgrammeReviewCopy.nothingRecorded])
        XCTAssertEqual(review.supportLine, ProgrammeReviewCopy.pickUpYourRoutine, "compared by reference, R-202")
    }

    func testThePatternsAreThoseOfDayNinetyWhateverDayItIsOpenedOn() {
        let start = today.minusDays(120)
        let cycles = [recordedCycle(start.plusDays(20), length: 28), recordedCycle(start.plusDays(48), length: nil)]
        var records = logs(startedOn: start, days: 1...90, fullLog())
        func kit(on day: Int) -> FertilityKitContext {
            KitFixture.context(today: start.plusDays(day - 1), state: ProgrammeState(startedOn: start),
                               logs: records, cycles: cycles)
        }
        let expected = kit(on: 91).ninetyDayPatterns()
        XCTAssertGreaterThanOrEqual(expected.count, 2, "the comparison below must not be of two empty lists")
        XCTAssertEqual(kit(on: 121).ninetyDayPatterns(), expected, "the same records, the same sentences (R-203)")
        // A log made on day 120 is outside the programme.
        records[start.plusDays(119)] = fullLog(water: 500)
        XCTAssertEqual(kit(on: 121).ninetyDayPatterns(), expected)
        XCTAssertEqual(Presentation.ninetyDayUnavailable(in: context(day: 40)),
                       ProgrammeReviewScreenCopy.ninetyDayReady(FertilityKitDates.dayMonth(today.plusDays(51))))
        XCTAssertEqual(Presentation.ninetyDayUnavailable(in: KitFixture.context(today: today)),
                       ProgrammeReviewScreenCopy.notAvailable)
    }

    func testTheTrackedCountsAreSplitWithoutLosingOne() throws {
        let kit = context(day: 95, logs: logs(startedOn: today.minusDays(94), days: 1...30,
                                              DailyLog(mood: .good, energy: .low, symptoms: ["Fatigue"], waterMl: 2_400)))
        let review = try XCTUnwrap(ProgrammeReviewLogic.ninetyDay(kit.reviewInput()))
        let body = review.tracked.filter { Presentation.bodyKinds.contains($0.kind) }
        XCTAssertEqual(Set(body.map(\.kind)), [.moodCheckIns, .energyCheckIns, .symptomDays])
        XCTAssertEqual(body.count + review.tracked.filter { !Presentation.bodyKinds.contains($0.kind) }.count,
                       review.tracked.count)
    }

    // MARK: - A review is recorded as viewed only when it exists

    func testAReviewIsRecordedAsViewedOnlyWhenItExists() throws {
        let container = KitFixture.container()
        KitUITestSeed(access: true, day: 15).apply(to: container, anchor: today)
        XCTAssertNotNil(container.programme.state.startedOn)
        let kit = KitFixture.context(from: container, today: today)

        Presentation.markViewed(ProgrammeReviewLogic.weekly(week: 5, input: kit.reviewInput()), in: container.programme)
        Presentation.markViewed(ProgrammeReviewLogic.ninetyDay(kit.reviewInput()), in: container.programme)
        XCTAssertEqual(container.programme.completions.weeklyReviewsViewed, [])
        XCTAssertFalse(container.programme.completions.ninetyDayReviewViewed)

        Presentation.markViewed(ProgrammeReviewLogic.weekly(week: 1, input: kit.reviewInput()), in: container.programme)
        XCTAssertEqual(container.programme.completions.weeklyReviewsViewed, [1])

        let late = KitFixture.context(from: container, today: today.plusDays(80))
        Presentation.markViewed(ProgrammeReviewLogic.ninetyDay(late.reviewInput()), in: container.programme)
        XCTAssertTrue(container.programme.completions.ninetyDayReviewViewed)
    }
}
