import XCTest
@testable import GenesyxCore

final class CycleHistoryRulesTests: XCTestCase {

    private let today = CalendarDate(2026, 6, 30)
    private let now = PeriodFixture.t0.addingTimeInterval(500)
    private let mar1 = CalendarDate(2026, 3, 1)
    private let mar20 = CalendarDate(2026, 3, 20)

    private func stored(_ start: CalendarDate, end: CalendarDate? = nil, source: PeriodSource = .recorded,
                        deleted: Bool = false) -> StoredPeriodRecord {
        PeriodFixture.stored(start, end: end, source: source, deleted: deleted)
    }

    private func apply(_ start: CalendarDate, to records: [StoredPeriodRecord]) -> PeriodStartChange {
        CycleHistoryRules.apply(newStart: start, to: records, today: today, now: now)
    }

    private func starts(_ records: [StoredPeriodRecord]) -> [CalendarDate] {
        PeriodSync.visible(records).map(\.startDate)
    }

    // MARK: - The window

    func testCorrectionWindowIsTheLongestPeriodTheAppAccepts() {
        XCTAssertEqual(CycleHistoryRules.correctionWindowDays, CycleEngine.periodLengthRange.upperBound)
        XCTAssertEqual(CycleHistoryRules.correctionWindowDays, 10)
    }

    // MARK: - Append

    func testFirstStartIntoAnEmptySetIsAnAppend() {
        let change = apply(mar1, to: [])

        XCTAssertEqual(change.outcome, .append(mar1))
        XCTAssertEqual(change.records, [
            StoredPeriodRecord(period: PeriodRecord(startDate: mar1, endDate: nil, source: .recorded),
                               updatedAt: now, pendingSync: true),
        ])
    }

    func testJustOutsideTheWindowAfterTheLatestIsAnAppend() {
        let existing = [stored(mar1)]
        let change = apply(CalendarDate(2026, 3, 12), to: existing)   // 11 days later

        XCTAssertEqual(change.outcome, .append(CalendarDate(2026, 3, 12)))
        XCTAssertEqual(starts(change.records), [mar1, CalendarDate(2026, 3, 12)])
        XCTAssertEqual(change.records.first, existing.first, "the earlier record is not rewritten")
        XCTAssertEqual(CycleHistory.cycles(from: change.records).first?.length, 11)
    }

    func testTodayIsAccepted() {
        XCTAssertEqual(apply(today, to: [stored(mar1)]).outcome, .append(today))
    }

    func testAStartOnATombstonedDateBringsItBack() {
        let change = apply(mar1, to: [stored(mar1, end: CalendarDate(2026, 3, 4), deleted: true)])

        XCTAssertEqual(change.outcome, .append(mar1))
        XCTAssertEqual(change.records.count, 1)
        XCTAssertEqual(PeriodSync.visible(change.records), [PeriodRecord(startDate: mar1)])
    }

    // MARK: - No change and refusal

    func testSameDateIsNoChange() {
        let existing = [stored(mar1), stored(CalendarDate(2026, 4, 1))]
        let change = apply(mar1, to: existing)

        XCTAssertEqual(change.outcome, .noChange)
        XCTAssertEqual(change.records, existing)
    }

    func testFutureDateIsRefused() {
        let existing = [stored(mar1)]
        let change = apply(today.plusDays(1), to: existing)

        XCTAssertEqual(change.outcome, .refused)
        XCTAssertEqual(change.records, existing)
        XCTAssertEqual(apply(today.plusDays(1), to: []).outcome, .refused)
    }

    // MARK: - Correction

    func testInsideTheWindowAtItsLaterEdgeIsACorrection() {
        let change = apply(CalendarDate(2026, 3, 11), to: [stored(mar1)])   // exactly 10 days later

        XCTAssertEqual(change.outcome, .correction(from: mar1, to: CalendarDate(2026, 3, 11)))
        XCTAssertEqual(starts(change.records), [CalendarDate(2026, 3, 11)])
        XCTAssertEqual(change.records.count, 2, "the old date stays as a tombstone so the move reaches other devices")
        let tombstone = change.records.first { $0.id == mar1 }
        XCTAssertEqual(tombstone?.deleted, true)
        XCTAssertEqual(tombstone?.pendingSync, true)
        XCTAssertEqual(tombstone?.updatedAt, now)
        XCTAssertTrue(change.records.allSatisfy(\.pendingSync))
    }

    func testInsideTheWindowAtItsEarlierEdgeIsACorrection() {
        let change = apply(CalendarDate(2026, 3, 10), to: [stored(mar20)])   // exactly 10 days earlier

        XCTAssertEqual(change.outcome, .correction(from: mar20, to: CalendarDate(2026, 3, 10)))
        XCTAssertEqual(starts(change.records), [CalendarDate(2026, 3, 10)])
    }

    func testOneDayEitherSideIsACorrection() {
        XCTAssertEqual(apply(mar20.plusDays(1), to: [stored(mar20)]).outcome, .correction(from: mar20, to: mar20.plusDays(1)))
        XCTAssertEqual(apply(mar20.minusDays(1), to: [stored(mar20)]).outcome, .correction(from: mar20, to: mar20.minusDays(1)))
    }

    func testCorrectingTheSeededRecordMakesItRecorded() {
        let change = apply(CalendarDate(2026, 3, 3), to: [stored(mar1, source: .seeded)])

        XCTAssertEqual(PeriodSync.visible(change.records), [PeriodRecord(startDate: CalendarDate(2026, 3, 3), source: .recorded)])
    }

    func testCorrectionKeepsAnEndThatIsStillValidAndDropsOneThatIsNot() {
        let existing = [stored(mar1, end: CalendarDate(2026, 3, 5))]

        XCTAssertEqual(PeriodSync.visible(apply(CalendarDate(2026, 3, 3), to: existing).records).first?.endDate,
                       CalendarDate(2026, 3, 5))
        XCTAssertNil(PeriodSync.visible(apply(CalendarDate(2026, 3, 6), to: existing).records).first?.endDate,
                     "the end would now be before the start")
        XCTAssertNil(PeriodSync.visible(apply(CalendarDate(2026, 2, 23), to: existing).records).first?.endDate,
                     "the period would now be longer than the longest accepted")
    }

    func testCorrectionMovesTheNearestStart() {
        let mar16 = CalendarDate(2026, 3, 16)
        let change = apply(CalendarDate(2026, 3, 9), to: [stored(mar1), stored(mar16)])   // 8 from one, 7 from the other

        XCTAssertEqual(change.outcome, .correction(from: mar16, to: CalendarDate(2026, 3, 9)))
        XCTAssertEqual(starts(change.records), [mar1, CalendarDate(2026, 3, 9)])
    }

    func testWhenTwoStartsAreEquallyNearTheLaterOneMoves() {
        let mar15 = CalendarDate(2026, 3, 15)
        let change = apply(CalendarDate(2026, 3, 8), to: [stored(mar1), stored(mar15)])

        XCTAssertEqual(change.outcome, .correction(from: mar15, to: CalendarDate(2026, 3, 8)))
    }

    func testCorrectionThatReachesBackIntoThePreviousPeriodClearsThatPeriodsEnd() {
        let mar12 = CalendarDate(2026, 3, 12)
        let change = apply(CalendarDate(2026, 3, 7), to: [stored(mar1, end: CalendarDate(2026, 3, 8)), stored(mar12)])

        XCTAssertEqual(change.outcome, .correction(from: mar12, to: CalendarDate(2026, 3, 7)))
        XCTAssertEqual(PeriodSync.visible(change.records), [
            PeriodRecord(startDate: mar1), PeriodRecord(startDate: CalendarDate(2026, 3, 7)),
        ])
        XCTAssertTrue(change.records.allSatisfy(\.pendingSync))
    }

    func testCorrectionLeavesAnEarlierPeriodsEndAloneWhenItStillFits() {
        let mar12 = CalendarDate(2026, 3, 12)
        let change = apply(CalendarDate(2026, 3, 9), to: [stored(mar1, end: CalendarDate(2026, 3, 8)), stored(mar12)])

        XCTAssertEqual(PeriodSync.visible(change.records).first?.endDate, CalendarDate(2026, 3, 8))
        XCTAssertEqual(change.records.first?.pendingSync, false, "an untouched record is not re-pushed")
    }

    // MARK: - Back-fill

    func testJustOutsideTheWindowBeforeTheEarliestIsABackFill() {
        let change = apply(CalendarDate(2026, 3, 9), to: [stored(mar20)])   // 11 days earlier

        XCTAssertEqual(change.outcome, .backFill(CalendarDate(2026, 3, 9)))
        XCTAssertEqual(starts(change.records), [CalendarDate(2026, 3, 9), mar20])
    }

    func testBackFillBetweenTwoExistingStartsRederivesInDateOrder() {
        let jan1 = CalendarDate(2026, 1, 1), feb1 = CalendarDate(2026, 2, 1)
        let change = apply(feb1, to: [stored(mar1), stored(jan1)])

        XCTAssertEqual(change.outcome, .backFill(feb1))
        XCTAssertEqual(change.records.map(\.id), [jan1, feb1, mar1], "the stored list comes back sorted too")
        XCTAssertEqual(CycleHistory.completedLengths(CycleHistory.cycles(from: change.records)), [31, 28])
        XCTAssertEqual(PeriodSync.pending(change.records).map(\.id), [feb1], "only the new record is owed")
    }

    // MARK: - End dates

    private func setEnd(_ end: CalendarDate?, _ start: CalendarDate, _ records: [StoredPeriodRecord]) -> PeriodEndChange {
        CycleHistoryRules.setEnd(end, forStart: start, in: records, today: today, now: now)
    }

    func testRecordingAnEnd() {
        let change = setEnd(CalendarDate(2026, 3, 5), mar1, [stored(mar1, source: .seeded)])

        XCTAssertEqual(change.outcome, .updated)
        XCTAssertEqual(change.records, [
            StoredPeriodRecord(period: PeriodRecord(startDate: mar1, endDate: CalendarDate(2026, 3, 5), source: .seeded),
                               updatedAt: now, pendingSync: true),
        ])
        XCTAssertEqual(CycleHistory.cycles(from: change.records).first?.periodDays, 5)
    }

    func testAOneDayPeriodIsAllowed() {
        XCTAssertEqual(setEnd(mar1, mar1, [stored(mar1)]).outcome, .updated)
    }

    func testSameEndIsNoChangeAndNilClearsIt() {
        let existing = [stored(mar1, end: CalendarDate(2026, 3, 5))]

        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 5), mar1, existing).outcome, .noChange)
        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 5), mar1, existing).records, existing)
        let cleared = setEnd(nil, mar1, existing)
        XCTAssertEqual(cleared.outcome, .updated)
        XCTAssertEqual(PeriodSync.visible(cleared.records), [PeriodRecord(startDate: mar1)])
        XCTAssertEqual(setEnd(nil, mar1, [stored(mar1)]).outcome, .noChange)
    }

    func testEndBeforeItsStartIsRefused() {
        let existing = [stored(mar1)]
        let change = setEnd(CalendarDate(2026, 2, 28), mar1, existing)

        XCTAssertEqual(change.outcome, .refusedBeforeStart)
        XCTAssertEqual(change.records, existing)
    }

    /// The longest period is ten days counted inclusively: day 10 is allowed, day 11 is not.
    func testEndIsLimitedToTheLongestPeriodTheAppAccepts() {
        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 10), mar1, [stored(mar1)]).outcome, .updated)
        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 11), mar1, [stored(mar1)]).outcome, .refusedTooLong)
    }

    func testEndMustFallBeforeTheNextStart() {
        // Two starts this close can only arrive through a merge; the rule still holds.
        let records = [stored(mar1), stored(CalendarDate(2026, 3, 6))]

        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 5), mar1, records).outcome, .updated)
        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 6), mar1, records).outcome, .refusedReachesNextStart)
        XCTAssertEqual(setEnd(CalendarDate(2026, 3, 7), mar1, records).outcome, .refusedReachesNextStart)
    }

    func testFutureEndIsRefused() {
        let records = [stored(today.minusDays(2))]

        XCTAssertEqual(setEnd(today, today.minusDays(2), records).outcome, .updated)
        XCTAssertEqual(setEnd(today.plusDays(1), today.minusDays(2), records).outcome, .refusedFuture)
    }

    func testEndForAnUnknownOrDeletedStartIsRefused() {
        XCTAssertEqual(setEnd(mar1, mar1, []).outcome, .refusedUnknownStart)
        XCTAssertEqual(setEnd(mar1, mar1, [stored(mar1, deleted: true)]).outcome, .refusedUnknownStart)
    }

    // MARK: - Deleting

    func testDeletingAMiddleStartMergesItsCycleIntoThePreviousOne() {
        let jan1 = CalendarDate(2026, 1, 1), feb1 = CalendarDate(2026, 2, 1)
        let records = CycleHistoryRules.delete(start: feb1, from: [stored(jan1), stored(feb1), stored(mar1)], now: now)

        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[1], StoredPeriodRecord(period: PeriodRecord(startDate: feb1), updatedAt: now,
                                                      pendingSync: true, deleted: true))
        let cycles = CycleHistory.cycles(from: records)
        XCTAssertEqual(cycles.map(\.start), [jan1, mar1])
        XCTAssertEqual(cycles[0].length, 59)
    }

    func testDeletingTheLatestStartReopensThePreviousCycle() {
        let records = CycleHistoryRules.delete(start: mar20, from: [stored(mar1), stored(mar20)], now: now)

        let cycles = CycleHistory.cycles(from: records)
        XCTAssertEqual(cycles.map(\.start), [mar1])
        XCTAssertEqual(cycles[0].status, .active)
    }

    func testDeletingAnUnknownStartChangesNothing() {
        let existing = [stored(mar1)]

        XCTAssertEqual(CycleHistoryRules.delete(start: mar20, from: existing, now: now), existing)
    }

    // MARK: - Seeding

    private let settings = CycleSettings(lastPeriodDate: CalendarDate(2026, 3, 1), cycleLength: 31, periodLength: 4)

    func testSeedIsTheLastPeriodDateAndNothingElse() {
        XCTAssertEqual(
            CycleHistoryRules.seed(settings: settings, records: [], now: now),
            StoredPeriodRecord(period: PeriodRecord(startDate: mar1, endDate: nil, source: .seeded),
                               updatedAt: now, pendingSync: true)
        )
    }

    func testNoSettingsMeansNoSeed() {
        XCTAssertNil(CycleHistoryRules.seed(settings: nil, records: [], now: now))
    }

    func testSeedIsNotRepeated() throws {
        let seeded = try XCTUnwrap(CycleHistoryRules.seed(settings: settings, records: [], now: now))

        XCTAssertNil(CycleHistoryRules.seed(settings: settings, records: [seeded], now: now))
        XCTAssertNil(CycleHistoryRules.seed(settings: settings, records: [stored(mar20)], now: now))
    }

    /// A history she emptied on purpose is not refilled.
    func testSeedIsNotRepeatedAfterEverythingWasDeleted() {
        XCTAssertNil(CycleHistoryRules.seed(settings: settings, records: [stored(mar1, source: .seeded, deleted: true)], now: now))
    }

    // MARK: - Keeping settings in step

    /// A user who records nothing new: seeding must not move her predictions at all.
    func testSeedingLeavesSettingsAndPredictionsIdentical() throws {
        let seeded = try XCTUnwrap(CycleHistoryRules.seed(settings: settings, records: [], now: now))
        let after = try XCTUnwrap(CycleHistoryRules.settingsInStep(settings, with: [seeded]))

        XCTAssertEqual(after, settings)
        XCTAssertEqual(CycleEngine.cyclePhase(settings: after, target: today), CycleEngine.cyclePhase(settings: settings, target: today))
    }

    func testAppendMovesLastPeriodDateOnly() {
        let change = apply(CalendarDate(2026, 4, 2), to: [stored(mar1, source: .seeded)])

        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: change.records),
                       CycleSettings(lastPeriodDate: CalendarDate(2026, 4, 2), cycleLength: 31, periodLength: 4))
    }

    func testCorrectingTheAnchorStartMovesLastPeriodDateOnly() {
        let change = apply(CalendarDate(2026, 3, 4), to: [stored(CalendarDate(2026, 2, 1)), stored(mar1)])

        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: change.records),
                       CycleSettings(lastPeriodDate: CalendarDate(2026, 3, 4), cycleLength: 31, periodLength: 4))
    }

    func testBackFillAndEarlierCorrectionLeaveSettingsAlone() {
        let backFilled = apply(CalendarDate(2026, 2, 1), to: [stored(mar1)])
        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: backFilled.records), settings)

        let corrected = apply(CalendarDate(2026, 2, 3), to: backFilled.records)
        XCTAssertEqual(corrected.outcome, .correction(from: CalendarDate(2026, 2, 1), to: CalendarDate(2026, 2, 3)))
        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: corrected.records), settings)
    }

    /// The latest visible start, not the earliest and not a tombstone.
    func testLastPeriodDateFollowsTheLatestVisibleStart() {
        let records = [stored(CalendarDate(2026, 5, 1), deleted: true), stored(mar20), stored(CalendarDate(2026, 1, 1))]

        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: records)?.lastPeriodDate, mar20)
    }

    func testDeletingTheLatestStartMovesLastPeriodDateBackToThePreviousStart() {
        let current = CycleSettings(lastPeriodDate: mar20, cycleLength: 31, periodLength: 4)
        let records = CycleHistoryRules.delete(start: mar20, from: [stored(CalendarDate(2026, 2, 1)), stored(mar20)], now: now)

        XCTAssertEqual(CycleHistoryRules.settingsInStep(current, with: records),
                       CycleSettings(lastPeriodDate: CalendarDate(2026, 2, 1), cycleLength: 31, periodLength: 4))
    }

    func testDeletingTheOnlyRecordLeavesSettingsUntouched() {
        let records = CycleHistoryRules.delete(start: mar1, from: [stored(mar1)], now: now)

        XCTAssertTrue(CycleHistory.cycles(from: records).isEmpty)
        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: records), settings)
    }

    func testNoSettingsStayNoSettings() {
        XCTAssertNil(CycleHistoryRules.settingsInStep(nil, with: [stored(mar1)]))
        XCTAssertEqual(CycleHistoryRules.settingsInStep(settings, with: []), settings)
    }
}
