import XCTest
import GenesyxCore
@testable import Genesyx

/// What the cycle history screen shows and what its period sheet allows, as pure functions.
@MainActor
final class CycleHistoryScreenTests: XCTestCase {

    private let today = CalendarDate(2026, 10, 6)
    private let window = CycleHistoryRules.correctionWindowDays

    private func cycle(_ start: CalendarDate, length: Int? = nil, periodDays: Int? = nil,
                       source: PeriodSource = .recorded, closing: PeriodSource? = nil) -> DerivedCycle {
        DerivedCycle(start: start, end: length.map { start.plusDays($0 - 1) }, length: length, periodDays: periodDays,
                     source: source, closingSource: length == nil ? nil : (closing ?? .recorded))
    }

    private func records(_ starts: [CalendarDate]) -> [StoredPeriodRecord] {
        starts.map { StoredPeriodRecord(period: PeriodRecord(startDate: $0), updatedAt: Date(), pendingSync: true) }
    }

    private func outcome(_ date: CalendarDate, with starts: [CalendarDate]) -> PeriodStartOutcome {
        CycleHistoryRules.apply(newStart: date, to: records(starts), today: today, now: Date()).outcome
    }

    // MARK: Rows

    func testNoStartsNoRows() {
        XCTAssertEqual(CycleHistoryPresentation.rows(cycles: [], refusedStarts: []), [])
    }

    func testOneStartIsTheOpenCycle() {
        let rows = CycleHistoryPresentation.rows(cycles: [cycle(CalendarDate(2026, 10, 1))], refusedStarts: [])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].index, 0)
        XCTAssertEqual(rows[0].lines, ["Current cycle", "Started 1 October"])
        XCTAssertEqual(rows[0].label, "Current cycle. Started 1 October")
    }

    func testRowsAreNewestFirstAndNumberedFromTheNewest() {
        let a = CalendarDate(2026, 8, 1), b = CalendarDate(2026, 8, 29), c = CalendarDate(2026, 9, 26), d = CalendarDate(2026, 10, 24)
        let cycles = [cycle(a, length: 28), cycle(b, length: 28), cycle(c, length: 28), cycle(d)]
        let two = CycleHistoryPresentation.rows(cycles: Array(cycles.suffix(2)), refusedStarts: [])
        XCTAssertEqual(two.map(\.index), [0, 1])
        XCTAssertEqual(two.map(\.start), [d, c])
        XCTAssertEqual(two[1].lines, ["26 September to 23 October", "28 days"])
        let four = CycleHistoryPresentation.rows(cycles: cycles, refusedStarts: [])
        XCTAssertEqual(four.map(\.start), [d, c, b, a])
        XCTAssertEqual(four.map(\.index), [0, 1, 2, 3])
        XCTAssertEqual(four[3].lines.first, "1 August to 28 August")
    }

    func testAnEndRecordedAddsThePeriodDaysAndTheEndForTheSheet() {
        let start = CalendarDate(2026, 9, 1)
        let rows = CycleHistoryPresentation.rows(cycles: [cycle(start, length: 28, periodDays: 5)], refusedStarts: [])
        XCTAssertEqual(rows[0].lines, ["1 September to 28 September", "28 days", "Period: 5 days"])
        XCTAssertEqual(rows[0].periodEnd, start.plusDays(4))
        let one = CycleHistoryPresentation.rows(cycles: [cycle(start, length: 28, periodDays: 1)], refusedStarts: [])
        XCTAssertEqual(one[0].lines.last, "Period: 1 day")
        XCTAssertNil(CycleHistoryPresentation.rows(cycles: [cycle(start, length: 28)], refusedStarts: [])[0].periodEnd)
    }

    func testTheSeededRecordIsMarkedAsFromSettings() {
        let seeded = cycle(CalendarDate(2026, 9, 1), length: 28, source: .seeded)
        let recorded = cycle(CalendarDate(2026, 9, 29))
        let rows = CycleHistoryPresentation.rows(cycles: [seeded, recorded], refusedStarts: [])
        XCTAssertEqual(rows[1].lines.last, "From your cycle settings")
        XCTAssertFalse(rows[0].lines.contains("From your cycle settings"))
    }

    func testAnyLengthIsShownLikeAnyOtherWithNoComment() {
        let long = CycleHistoryPresentation.rows(cycles: [cycle(CalendarDate(2026, 6, 1), length: 40)], refusedStarts: [])
        XCTAssertEqual(long[0].lines, ["1 June to 10 July", "40 days"])
        let short = CycleHistoryPresentation.rows(cycles: [cycle(CalendarDate(2026, 6, 1), length: 12)], refusedStarts: [])
        XCTAssertEqual(short[0].lines, ["1 June to 12 June", "12 days"])
    }

    func testARefusedStartCarriesTheNotSavedLineInItsLinesAndItsLabel() {
        let refused = CalendarDate(2026, 10, 1), saved = CalendarDate(2026, 9, 1)
        let cycles = [cycle(saved, length: 30), cycle(refused)]
        let rows = CycleHistoryPresentation.rows(cycles: cycles, refusedStarts: [refused])
        XCTAssertEqual(rows[0].lines.last, CycleHistoryScreenCopy.notSaved)
        XCTAssertTrue(rows[0].label.contains(CycleHistoryScreenCopy.notSaved))
        XCTAssertFalse(rows[1].lines.contains(CycleHistoryScreenCopy.notSaved))
        XCTAssertFalse(rows[1].label.contains(CycleHistoryScreenCopy.notSaved))
        XCTAssertEqual(CycleHistoryPresentation.rows(cycles: cycles, refusedStarts: [])[0].lines,
                       ["Current cycle", "Started 1 October"])
    }

    func testTheContextCarriesWhatTheRepositoryRefused() {
        let refused: Set<CalendarDate> = [CalendarDate(2026, 10, 1)]
        let context = KitFixture.context(today: today, cycles: [cycle(CalendarDate(2026, 10, 1))], refusedPeriodStarts: refused)
        XCTAssertEqual(context.refusedPeriodStarts, refused)
        let container = KitFixture.container()
        XCTAssertEqual(KitFixture.context(from: container, today: today).refusedPeriodStarts, [],
                       "a start refused by the server needs a backend: this is the pass-through only")
    }

    // MARK: Delete

    func testDeletingTheLatestStartUsesTheLatestWordingOnlyWhenAnEarlierStartExists() {
        XCTAssertEqual(CycleHistoryPresentation.deleteMessage(isLatest: true, startCount: 3), CycleHistoryScreenCopy.deleteLatestBody)
        XCTAssertEqual(CycleHistoryPresentation.deleteMessage(isLatest: true, startCount: 1), CycleHistoryScreenCopy.deleteBody,
                       "her only record promises nothing before it")
        XCTAssertEqual(CycleHistoryPresentation.deleteMessage(isLatest: false, startCount: 3), CycleHistoryScreenCopy.deleteBody)
    }

    // MARK: The sheet: range and default

    func testAddStartAllowsEveryDateTheRuleAccepts() {
        let range = CycleHistoryPresentation.allowedDates(for: .addStart, today: today, existingStarts: [])
        XCTAssertEqual(range, CycleHistoryRules.earliestDate...today)
        XCTAssertTrue(CycleHistoryRules.accepts(range.lowerBound, today: today))
        XCTAssertTrue(CycleHistoryRules.accepts(range.upperBound, today: today))
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(for: .addStart, today: today, existingStarts: []), today)
    }

    func testSetEndRunsFromTheStartForTheLongestPeriodNeverPastToday() {
        let early = today.minusDays(30)
        XCTAssertEqual(CycleHistoryPresentation.allowedDates(
            for: .setEnd(start: early, current: nil), today: today, existingStarts: [early]),
                       early...early.plusDays(window - 1))
        let recent = today.minusDays(3)
        XCTAssertEqual(CycleHistoryPresentation.allowedDates(
            for: .setEnd(start: recent, current: nil), today: today, existingStarts: [recent]), recent...today)
        // A longest allowed period is accepted by the rule, one day more is not.
        XCTAssertEqual(CycleHistoryRules.setEnd(early.plusDays(window - 1), forStart: early, in: records([early]),
                                                today: today, now: Date()).outcome, .updated)
        XCTAssertEqual(CycleHistoryRules.setEnd(early.plusDays(window), forStart: early, in: records([early]),
                                                today: today, now: Date()).outcome, .refusedTooLong)
    }

    func testSetEndDefaultsToTheCurrentEndOtherwiseTheStartOrToday() {
        let start = today.minusDays(30)
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(
            for: .setEnd(start: start, current: start.plusDays(4)), today: today, existingStarts: [start]), start.plusDays(4))
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(
            for: .setEnd(start: start, current: nil), today: today, existingStarts: [start]), start)
        let recent = today.minusDays(1)
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(
            for: .setEnd(start: recent, current: nil), today: today, existingStarts: [recent]), recent)
    }

    func testCorrectStartWithNoOtherStartRunsTheWholeWindowEitherSide() {
        let old = today.minusDays(60)
        let range = CycleHistoryPresentation.allowedDates(for: .correctStart(old), today: today, existingStarts: [old])
        XCTAssertEqual(range, old.minusDays(window)...old.plusDays(window))
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(for: .correctStart(old), today: today, existingStarts: [old]),
                       old.minusDays(1))
    }

    func testCorrectStartNeverReachesPastTodayOrBeforeTheEarliestDate() {
        let recent = today.minusDays(3)
        XCTAssertEqual(CycleHistoryPresentation.allowedDates(for: .correctStart(recent), today: today, existingStarts: [recent]).upperBound, today)
        let first = CycleHistoryRules.earliestDate.plusDays(2)
        XCTAssertEqual(CycleHistoryPresentation.allowedDates(for: .correctStart(first), today: today, existingStarts: [first]).lowerBound,
                       CycleHistoryRules.earliestDate)
    }

    func testCorrectStartWithTwoStartsTwelveDaysApartOnlyOffersDatesThatMoveTheOneOpened() throws {
        let earlier = today.minusDays(60), later = earlier.plusDays(12)
        let starts = [earlier, later]
        for old in starts {
            let range = CycleHistoryPresentation.allowedDates(for: .correctStart(old), today: today, existingStarts: starts)
            XCTAssertTrue(range.contains(old))
            var day = range.lowerBound
            while day <= range.upperBound {
                if day != old {
                    XCTAssertEqual(outcome(day, with: starts), .correction(from: old, to: day),
                                   "\(day.dayNumber - old.dayNumber) days from the start opened")
                }
                day = day.plusDays(1)
            }
        }
        // The plain window would have reached the other period: these bounds are the narrowed ones.
        let laterRange = CycleHistoryPresentation.allowedDates(for: .correctStart(later), today: today, existingStarts: starts)
        XCTAssertEqual(laterRange, later.minusDays(6)...later.plusDays(window), "on a tie the later start is the one moved")
        let earlierRange = CycleHistoryPresentation.allowedDates(for: .correctStart(earlier), today: today, existingStarts: starts)
        XCTAssertEqual(earlierRange, earlier.minusDays(window)...earlier.plusDays(5))
        // And the dates just outside belong to the other start.
        XCTAssertEqual(outcome(later.minusDays(7), with: starts), .correction(from: earlier, to: later.minusDays(7)))
        XCTAssertEqual(outcome(earlier.plusDays(6), with: starts), .correction(from: later, to: earlier.plusDays(6)))
    }

    func testCorrectStartDefaultsToTheDayBeforeOrTheNearestAllowedDate() {
        let earlier = today.minusDays(60), later = earlier.plusDays(12)
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(
            for: .correctStart(later), today: today, existingStarts: [earlier, later]), later.minusDays(1))
        // One day apart: the day before is the other start itself, so the default is the nearest allowed date.
        let near = later.minusDays(1)
        let range = CycleHistoryPresentation.allowedDates(for: .correctStart(later), today: today, existingStarts: [near, later])
        XCTAssertFalse(range.contains(later.minusDays(1)))
        XCTAssertEqual(CycleHistoryPresentation.defaultDate(
            for: .correctStart(later), today: today, existingStarts: [near, later]), range.lowerBound)
        XCTAssertEqual(range.lowerBound, later)
    }

    // MARK: The sheet: the note before saving

    func testTheCorrectionNoteAppearsExactlyWhenTheDateWouldMoveAStart() {
        let existing = today.minusDays(40)
        let starts = [existing]
        for offset in -window...window where offset != 0 {
            let date = existing.plusDays(offset)
            XCTAssertEqual(CycleHistoryPresentation.correctionTarget(for: date, existingStarts: starts), existing)
            XCTAssertEqual(outcome(date, with: starts), .correction(from: existing, to: date), "\(offset)")
        }
        for offset in [window + 1, -(window + 1), 25] {
            let date = existing.plusDays(offset)
            XCTAssertNil(CycleHistoryPresentation.correctionTarget(for: date, existingStarts: starts))
            let result = outcome(date, with: starts)
            XCTAssertTrue(result == .append(date) || result == .backFill(date), "\(offset): \(result)")
        }
        XCTAssertNil(CycleHistoryPresentation.correctionTarget(for: existing, existingStarts: starts), "that date is already recorded")
        XCTAssertEqual(outcome(existing, with: starts), .noChange)
    }

    func testAChangeClosesTheSheetAndNothingElseDoes() {
        let a = CalendarDate(2026, 9, 1)
        XCTAssertTrue(CycleHistoryPresentation.isChange(.append(a)))
        XCTAssertTrue(CycleHistoryPresentation.isChange(.backFill(a)))
        XCTAssertTrue(CycleHistoryPresentation.isChange(.correction(from: a, to: a.plusDays(1))))
        XCTAssertFalse(CycleHistoryPresentation.isChange(.noChange))
        XCTAssertFalse(CycleHistoryPresentation.isChange(.refused))
    }

    // MARK: Outcomes

    func testEveryOutcomeHasASentenceNoneEmpty() {
        let a = CalendarDate(2026, 9, 1)
        let starts: [PeriodStartOutcome] = [.append(a), .backFill(a), .correction(from: a, to: a.plusDays(2)), .noChange, .refused]
        let ends: [PeriodEndOutcome] = [.updated, .noChange, .refusedUnknownStart, .refusedBeforeStart, .refusedTooLong,
                                        .refusedReachesNextStart, .refusedFuture]
        XCTAssertTrue(starts.map(CycleHistoryScreenCopy.sentence(for:)).allSatisfy { !$0.isEmpty })
        XCTAssertTrue(ends.map(CycleHistoryScreenCopy.sentence(for:)).allSatisfy { !$0.isEmpty })
        XCTAssertEqual(CycleHistoryScreenCopy.sentence(for: PeriodStartOutcome.correction(from: CalendarDate(2026, 9, 28), to: CalendarDate(2026, 10, 6))),
                       "Start date moved from 28 September to 6 October.")
    }

    // MARK: The summary

    func testTheSummaryAppearsOnlyWhenACrossCycleStatementMayBeMade() {
        func context(_ starts: Int) -> FertilityKitContext {
            let container = KitFixture.container()
            for index in 0..<starts {
                container.periods.recordStart(today.minusDays(27 + 28 * (starts - 1 - index)), today: today)
            }
            return KitFixture.context(from: container, today: today)
        }
        for starts in 0...3 {
            let kit = context(starts)
            XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(kit.cycles), "\(starts)")
            XCTAssertEqual(CycleHistoryPresentation.summary(kit), [], "fewer than three countable cycles: no summary at all")
        }
        let enough = context(4)
        XCTAssertTrue(CycleHistory.canMakeCrossCycleStatement(enough.cycles))
        let summary = CycleHistoryPresentation.summary(enough)
        XCTAssertFalse(summary.isEmpty)
        XCTAssertEqual(summary, FertilityPicturePatterns.statements(enough.pictureInput())
            .filter { $0.level == .crossCyclePattern }.map(\.text))
    }
}
