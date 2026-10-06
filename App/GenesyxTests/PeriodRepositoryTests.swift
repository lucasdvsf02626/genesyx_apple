import XCTest
@testable import Genesyx
import GenesyxCore

/// The cycle-history data layer: the persisted DTO, the `period_records` row, `PeriodRepository`,
/// the reconcile table for a `last_period_date` written elsewhere, and the one flag in front of
/// all of it. Shaped like `LhRepositoryTests`; the rules themselves are tested in the core.
@MainActor
final class PeriodRepositoryTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    private static let key = "period_records"
    private static let cursorKey = "period_records_cursor"
    private static let refusedKey = "period_records_refused"

    // All in the past, so none is ever refused as a future date.
    private let jan3 = CalendarDate(2026, 1, 3)
    private let feb1 = CalendarDate(2026, 2, 1)
    private let mar3 = CalendarDate(2026, 3, 3)
    private let mar5 = CalendarDate(2026, 3, 5)
    private let today = CalendarDate(2026, 4, 1)

    private func stored(_ start: CalendarDate, end: CalendarDate? = nil, source: PeriodSource = .recorded,
                        updatedAt: TimeInterval = 1_000, pending: Bool = false, deleted: Bool = false) -> StoredPeriodRecord {
        StoredPeriodRecord(period: PeriodRecord(startDate: start, endDate: end, source: source),
                           updatedAt: Date(timeIntervalSince1970: updatedAt), pendingSync: pending, deleted: deleted)
    }

    private func settings(_ date: CalendarDate, cycle: Int = 30, period: Int = 4) -> CycleSettings {
        CycleSettings(lastPeriodDate: date, cycleLength: cycle, periodLength: period)
    }

    private func saved(_ store: LocalStore) -> [PeriodRecordDTO] {
        store.load([PeriodRecordDTO].self, forKey: Self.key) ?? []
    }

    /// A local-only container as the app builds one, with consent given.
    private func container(_ store: LocalStore, cycleHistory: Bool = true) -> AppContainer {
        let c = AppContainer(store: store, backend: nil, monitorNetwork: false, cycleHistory: cycleHistory)
        c.consent.grant()
        return c
    }

    // MARK: - Local DTO

    func testDTORoundTripThroughRecordDTO() throws {
        let records = [
            stored(mar3, end: mar5, source: .seeded, updatedAt: 2_000, pending: true),
            stored(feb1, updatedAt: 3_000, pending: false, deleted: true),
        ]
        for record in records {
            let data = try JSONEncoder().encode(record.dto)
            XCTAssertEqual(try JSONDecoder().decode(PeriodRecordDTO.self, from: data).record, record)
        }
    }

    func testMinimalDTODecodesAsRecordedPendingAndLive() throws {
        let data = try JSONEncoder().encode(["startDate": mar3])
        let record = try XCTUnwrap(JSONDecoder().decode(PeriodRecordDTO.self, from: data).record)
        XCTAssertEqual(record.period, PeriodRecord(startDate: mar3))
        XCTAssertTrue(record.pendingSync, "a record with no bookkeeping has never been pushed")
        XCTAssertFalse(record.deleted)
    }

    func testAnUnknownSourceDecodesAsRecorded() {
        var dto = stored(mar3).dto
        dto.source = "imported"
        XCTAssertEqual(dto.record?.period.source, .recorded)
    }

    /// One unreadable entry costs that entry, never the list, and never a crash.
    func testGarbageEntriesAreDroppedAndTheRestOfTheListSurvives() throws {
        let good = String(data: try JSONEncoder().encode(stored(mar3).dto), encoding: .utf8)!
        let json = """
            [\(good), {"startDate":"not a date"}, {"startDate":{"dayNumber":"x"}}, {}, "text", 7,
             {"startDate":{"dayNumber":\(feb1.dayNumber)},"endDate":"bad","updatedAt":"bad","pendingSync":"bad","deleted":3}]
            """
        let dtos = try JSONDecoder().decode([PeriodRecordDTO].self, from: Data(json.utf8))
        XCTAssertEqual(dtos.count, 7)
        let records = dtos.compactMap(\.record)
        XCTAssertEqual(records.map(\.id), [mar3, feb1], "entries with no readable start date are dropped")
        XCTAssertEqual(records.last?.period, PeriodRecord(startDate: feb1), "an unreadable end is no end")
        XCTAssertEqual(records.last?.pendingSync, true)
    }

    func testARepositoryLoadsPastAnEntryWithNoStartDate() {
        let store = makeStore()
        store.save([stored(mar3).dto, PeriodRecordDTO(source: "recorded")], forKey: Self.key)
        XCTAssertEqual(PeriodRepository(store: store).periods.map(\.startDate), [mar3])
    }

    // MARK: - Row

    private func json(_ row: PeriodRecordRow) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
    }

    func testRowKeysAndDates() throws {
        let row = try json(PeriodRecordRow(userId: "u", record: stored(mar3, end: mar5, source: .seeded)))
        XCTAssertEqual(Set(row.keys), ["user_id", "start_date", "end_date", "source", "updated_at", "deleted_at"])
        XCTAssertEqual(row["user_id"] as? String, "u")
        XCTAssertEqual(row["start_date"] as? String, "2026-03-03")
        XCTAssertEqual(row["end_date"] as? String, "2026-03-05")
        XCTAssertEqual(row["source"] as? String, "seeded")
    }

    /// An upsert leaves an omitted column as it was, so clearing an end and recording again on a
    /// deleted date both depend on the null being sent.
    func testRowSendsExplicitNullsForNoEndAndNoTombstone() throws {
        let row = try json(PeriodRecordRow(userId: "u", record: stored(mar3)))
        XCTAssertTrue(row["end_date"] is NSNull, "end_date must be sent as null, not omitted")
        XCTAssertTrue(row["deleted_at"] is NSNull, "deleted_at must be sent as null, not omitted")

        let tombstone = try json(PeriodRecordRow(userId: "u", record: stored(mar3, deleted: true)))
        XCTAssertNotNil(tombstone["deleted_at"] as? String)
    }

    func testRowRoundTripAndTolerance() throws {
        let record = stored(mar3, end: mar5, updatedAt: 5_000, deleted: true)
        let data = try JSONEncoder().encode(PeriodRecordRow(userId: "u", record: record))
        var row = try JSONDecoder().decode(PeriodRecordRow.self, from: data)
        XCTAssertEqual(row.domain, record, "a row from the server is never pending")

        row.source = "imported"
        row.endDate = "soon"
        XCTAssertEqual(row.domain?.period, PeriodRecord(startDate: mar3))
        row.startDate = "03/03/2026"
        XCTAssertNil(row.domain, "a row whose start date cannot be read is dropped")
    }

    // MARK: - Recording

    func testEachOutcomeIsReturnedAndSurvivesAFreshRepository() {
        let store = makeStore()
        let repo = PeriodRepository(store: store)
        XCTAssertEqual(repo.recordStart(feb1, today: today), .append(feb1))
        XCTAssertEqual(repo.recordStart(mar3, today: today), .append(mar3))
        XCTAssertEqual(repo.recordStart(mar3, today: today), .noChange)
        XCTAssertEqual(repo.recordStart(jan3, today: today), .backFill(jan3))
        XCTAssertEqual(repo.recordStart(mar5, today: today), .correction(from: mar3, to: mar5))
        XCTAssertEqual(repo.recordStart(today.plusDays(1), today: today), .refused)
        XCTAssertEqual(repo.setEnd(mar5.plusDays(3), forStart: mar5, today: today), .updated)
        XCTAssertEqual(repo.setEnd(feb1, forStart: mar5, today: today), .refusedBeforeStart)

        let reloaded = PeriodRepository(store: store)
        XCTAssertEqual(reloaded.periods, [PeriodRecord(startDate: jan3), PeriodRecord(startDate: feb1),
                                          PeriodRecord(startDate: mar5, endDate: mar5.plusDays(3))])
        XCTAssertEqual(reloaded.cycles.map(\.length), [29, 32, nil], "cycles are derived, never stored")
        XCTAssertEqual(reloaded.cycles.last?.periodDays, 4)
    }

    func testACorrectionIsATombstonePlusANewRecordAndBothAreOwed() {
        let store = makeStore()
        let repo = PeriodRepository(store: store)
        repo.recordStart(mar5, today: today)
        store.save(saved(store).compactMap(\.record).map { $0.marking(pendingSync: false).dto }, forKey: Self.key)

        let again = PeriodRepository(store: store)
        XCTAssertEqual(again.recordStart(mar3, today: today), .correction(from: mar5, to: mar3))

        let records = saved(store).compactMap(\.record)
        XCTAssertEqual(records.map(\.id), [mar3, mar5])
        XCTAssertEqual(records.map(\.deleted), [false, true], "the old date is kept as a tombstone")
        XCTAssertEqual(records.map(\.pendingSync), [true, true], "both writes are owed to the server")
        XCTAssertEqual(again.periods.map(\.startDate), [mar3])
    }

    func testDeleteIsATombstoneAndSurvivesAPull() async {
        let backend = FakePeriodBackend()
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        repo.recordStart(mar3, today: today)
        await repo.drainPending()

        XCTAssertTrue(repo.delete(start: mar3))
        XCTAssertFalse(repo.delete(start: mar3), "there is nothing left on that date to delete")
        XCTAssertTrue(repo.periods.isEmpty, "hidden at once")
        await repo.drainPending()
        XCTAssertEqual(backend.remote.first?.deleted, true, "the server gets a tombstone, not a delete")

        await repo.refresh()
        XCTAssertTrue(repo.periods.isEmpty, "a pull must not resurrect a deleted period")
    }

    // MARK: - Drain

    /// The correction here moves the start EARLIER, so by date alone the new record would go
    /// first. The tombstone has to land first: another device may see the period missing for a
    /// moment, never twice.
    func testDrainPushesTheTombstoneBeforeTheNewRecord() async {
        let store = makeStore()
        let seeder = PeriodRepository(store: store)
        seeder.recordStart(mar5, today: today)
        seeder.recordStart(mar3, today: today)

        let backend = ProbePeriodBackend()
        await PeriodRepository(store: store, backend: backend).drainPending()

        XCTAssertEqual(backend.pushed.map(\.id), [mar5, mar3])
        XCTAssertEqual(backend.pushed.map(\.deleted), [true, false])
        XCTAssertTrue(saved(store).allSatisfy { $0.pendingSync == false })
    }

    /// The second write of a correction failing: the tombstone has landed, the new record stays
    /// owed, and the next drain carries it.
    func testARejectedRowDoesNotBlockTheNextAndStaysQueued() async {
        let store = makeStore()
        let seeder = PeriodRepository(store: store)
        seeder.recordStart(feb1, today: today)
        seeder.recordStart(mar5, today: today)
        seeder.recordStart(mar3, today: today)   // tombstone mar5, new record mar3

        let backend = ProbePeriodBackend(reject: mar3)
        let repo = PeriodRepository(store: store, backend: backend)
        await repo.drainPending()

        XCTAssertEqual(backend.remote.map(\.id).sorted(), [feb1, mar5], "the rows either side of the rejected one still sync")
        XCTAssertEqual(backend.remote.first { $0.id == mar5 }?.deleted, true)
        XCTAssertEqual(saved(store).compactMap(\.record).filter(\.pendingSync).map(\.id), [mar3], "the rejected row stays owed")
        XCTAssertEqual(repo.periods.map(\.startDate), [feb1, mar3], "and stays on the device")

        backend.reject = nil
        await repo.drainPending()
        XCTAssertEqual(backend.remote.filter { !$0.deleted }.map(\.id).sorted(), [feb1, mar3])
    }

    func testAConnectionFailureHaltsThisDrainAndKeepsTheQueue() async {
        let store = makeStore()
        let seeder = PeriodRepository(store: store)
        seeder.recordStart(feb1, today: today)
        seeder.recordStart(mar3, today: today)

        let backend = ProbePeriodBackend()
        backend.offline = true
        await PeriodRepository(store: store, backend: backend).drainPending()

        XCTAssertEqual(backend.attempts, 1, "a failed connection is the same answer for every row behind it")
        XCTAssertEqual(saved(store).filter { $0.pendingSync == true }.count, 2)
    }

    // MARK: - Merge

    /// Two devices recorded the same period on different dates. Both survive, as a two-day cycle,
    /// for her to see and to delete one of. Nothing merges them.
    func testTwoDevicesDifferentStartsBothSurviveAMerge() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(mar5, updatedAt: 9_000)]
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        repo.recordStart(mar3, today: today)

        await repo.refresh()

        XCTAssertEqual(repo.periods.map(\.startDate), [mar3, mar5])
        XCTAssertEqual(repo.cycles.map(\.length), [2, nil])
        XCTAssertEqual(backend.remote.filter { !$0.deleted }.map(\.id).sorted(), [mar3, mar5])
        XCTAssertTrue(repo.delete(start: mar5), "she can delete either one")
        XCTAssertEqual(repo.periods.map(\.startDate), [mar3])
    }

    func testTheSameStartOnTwoDevicesIsOneRecord() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(mar3, updatedAt: 9_000)]
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        repo.recordStart(mar3, today: today)
        await repo.refresh()
        XCTAssertEqual(repo.periods.map(\.startDate), [mar3])
    }

    /// A merge can leave an end on or after the next start. It is kept as it arrived and simply
    /// not counted.
    func testAnEndThatReachesTheNextStartIsTolerated() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(mar3, end: mar5.plusDays(1), updatedAt: 9_000), stored(mar5, updatedAt: 9_000)]
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        await repo.refresh()
        XCTAssertEqual(repo.periods.first?.endDate, mar5.plusDays(1))
        XCTAssertNil(repo.cycles.first?.periodDays)
    }

    // MARK: - Consent

    func testWithdrawingConsentStopsNewRecordsButNotDeletion() {
        let store = makeStore()
        let c = container(store)
        XCTAssertEqual(c.periods.recordStart(mar3, today: today), .append(mar3))
        XCTAssertEqual(c.periods.setEnd(mar5, forStart: mar3, today: today), .updated)

        c.consent.withdraw()
        let before = saved(store).compactMap(\.record)

        XCTAssertNil(c.periods.recordStart(feb1, today: today), "no new period may be recorded after a withdrawal")
        XCTAssertNil(c.periods.setEnd(mar5.plusDays(1), forStart: mar3, today: today))
        c.periods.seedIfEmpty()
        XCTAssertEqual(saved(store).compactMap(\.record), before, "nothing was written")

        XCTAssertEqual(c.periods.setEnd(nil, forStart: mar3, today: today), .updated, "clearing an end stays available")
        XCTAssertTrue(c.periods.delete(start: mar3), "erasing what she recorded must stay available")
        XCTAssertTrue(c.periods.periods.isEmpty)
    }

    func testAWithdrawnRefreshDoesNotPullButStillDrains() async {
        let store = makeStore()
        PeriodRepository(store: store).recordStart(mar3, today: today)

        let spy = FakePeriodBackend()
        spy.remote = [stored(feb1)]
        let repo = PeriodRepository(store: store, backend: spy)
        repo.isCollectionPermitted = { false }
        repo.cycleSettings = { self.settings(self.jan3) }

        await repo.refresh()

        XCTAssertTrue(spy.sinceArgs.isEmpty, "a withdrawn phone must not pull her periods back down")
        XCTAssertEqual(repo.periods.map(\.startDate), [mar3])
        XCTAssertTrue(spy.remote.contains { $0.id == mar3 }, "the queue still drains")
    }

    // MARK: - Wipe

    func testSignOutClearsPeriodRecordsAndTheCursor() {
        let store = makeStore()
        store.save(Date(timeIntervalSince1970: 1_000), forKey: Self.cursorKey)
        let c = container(store)
        c.periods.recordStart(mar3, today: today)
        XCTAssertFalse(saved(store).isEmpty)

        c.session.signOut()

        XCTAssertTrue(c.periods.periods.isEmpty)
        XCTAssertTrue(c.periods.cycles.isEmpty)
        XCTAssertNil(store.load([PeriodRecordDTO].self, forKey: Self.key))
        XCTAssertNil(store.load(Date.self, forKey: Self.cursorKey), "the next account must start from a full pull")
        XCTAssertTrue(PeriodRepository(store: store).periods.isEmpty)
    }

    // MARK: - Cursor

    func testSyncIsFullThenIncrementalOnServerTime() async {
        let store = makeStore()
        let spy = FakePeriodBackend()
        spy.remote = [stored(mar3, updatedAt: 1_000)]
        let repo = PeriodRepository(store: store, backend: spy)
        await repo.refresh()
        await repo.refresh()
        XCTAssertEqual(spy.sinceArgs.count, 2)
        XCTAssertNil(spy.sinceArgs[0], "first sync must fetch full history")
        XCTAssertEqual(spy.sinceArgs[1]?.timeIntervalSince1970 ?? -1, 940, accuracy: 0.001,
                       "second sync asks from the server's stamp less the 60 s overlap")

        spy.online = false
        await repo.refresh()
        XCTAssertEqual(store.load(Date.self, forKey: Self.cursorKey)?.timeIntervalSince1970 ?? -1, 1_000, accuracy: 0.001,
                       "a failed pull must not move the cursor")
    }

    // MARK: - Seeding

    /// An upgrading user: settings on the device from the previous build, history empty.
    func testSeedingHappensOnceAndIsNotRepeatedAfterSheDeletesEverything() {
        let store = makeStore()
        container(store, cycleHistory: false).cycle.upsert(settings(mar3))

        let c = container(store)
        XCTAssertEqual(c.periods.periods, [PeriodRecord(startDate: mar3, source: .seeded)])
        XCTAssertEqual(saved(store).first?.pendingSync, true, "the seeded record is owed to the server")

        XCTAssertEqual(container(store).periods.periods.count, 1, "a second launch does not seed again")

        XCTAssertTrue(c.periods.delete(start: mar3))
        c.periods.seedIfEmpty()
        XCTAssertTrue(c.periods.periods.isEmpty)
        XCTAssertTrue(container(store).periods.periods.isEmpty, "a history she emptied is never refilled")
        XCTAssertEqual(c.cycle.settings, settings(mar3), "deleting her only period leaves her settings alone")
    }

    func testNothingIsSeededWithoutCycleSettings() {
        let c = container(makeStore())
        c.periods.seedIfEmpty()
        XCTAssertTrue(c.periods.periods.isEmpty)
    }

    /// With a backend the seed waits for the pull, so tombstones from her other device are seen
    /// before anything is written.
    func testWithABackendSeedingWaitsForThePullAndRespectsItsTombstones() async {
        let emptied = FakePeriodBackend()
        emptied.remote = [stored(mar3, source: .seeded, updatedAt: 9_000, deleted: true)]
        let first = PeriodRepository(store: makeStore(), backend: emptied)
        first.cycleSettings = { self.settings(self.mar3) }
        await first.refresh()
        XCTAssertTrue(first.periods.isEmpty, "she emptied her history on another device")
        XCTAssertEqual(emptied.remote.map(\.deleted), [true])

        let fresh = FakePeriodBackend()
        let second = PeriodRepository(store: makeStore(), backend: fresh)
        second.cycleSettings = { self.settings(self.mar3) }
        await second.refresh()
        XCTAssertEqual(second.periods, [PeriodRecord(startDate: mar3, source: .seeded)])
        XCTAssertEqual(fresh.remote.map(\.id), [mar3], "and the seeded record is pushed")

        let offline = FakePeriodBackend()
        offline.online = false
        let third = PeriodRepository(store: makeStore(), backend: offline)
        third.cycleSettings = { self.settings(self.mar3) }
        await third.refresh()
        XCTAssertTrue(third.periods.isEmpty, "no seed until a pull has succeeded")
    }

    /// The promise to every existing user: seeding changes no prediction.
    func testSeedingLeavesEveryEngineOutputIdentical() {
        let store = makeStore()
        let mine = settings(mar3, cycle: 31, period: 6)
        let baseline = container(store, cycleHistory: false)
        baseline.cycle.upsert(mine)
        func outputs(_ settings: CycleSettings?) -> [CyclePhaseInfo] {
            (-40...120).map { CycleEngine.cyclePhase(settings: settings!, target: mar3.plusDays($0)) }
        }
        let before = outputs(baseline.cycle.settings)
        let gridBefore = CycleEngine.buildMonthGrid(monthAnchor: YearMonth(2026, 4), settings: baseline.cycle.settings, today: today)

        let c = container(store)
        XCTAssertEqual(c.periods.periods.count, 1, "history was seeded")
        XCTAssertEqual(c.cycle.settings, mine, "seeding writes nothing to her settings")
        XCTAssertEqual(outputs(c.cycle.settings), before)
        XCTAssertEqual(CycleEngine.buildMonthGrid(monthAnchor: YearMonth(2026, 4), settings: c.cycle.settings, today: today), gridBefore)
        XCTAssertEqual(store.load(CycleSettings.self, forKey: "cycle_settings"), mine)
    }

    // MARK: - The existing settings flow

    /// `cycle.upsert` is what the settings sheet calls on Save.
    func testSavingANewDateInTheSettingsSheetAppendsHistoryAndMovesOnlyTheDate() {
        let store = makeStore()
        container(store, cycleHistory: false).cycle.upsert(settings(feb1))
        let c = container(store)

        XCTAssertTrue(c.cycle.upsert(settings(mar3)))

        XCTAssertEqual(c.periods.periods, [PeriodRecord(startDate: feb1, source: .seeded), PeriodRecord(startDate: mar3)],
                       "the earlier period is kept, not overwritten")
        XCTAssertEqual(c.periods.cycles.map(\.length), [30, nil])
        XCTAssertEqual(c.cycle.settings, settings(mar3), "only lastPeriodDate moved")
    }

    func testFirstSetupThroughTheSheetIsARecordedStart() {
        let c = container(makeStore())
        c.cycle.upsert(settings(mar3))
        XCTAssertEqual(c.periods.periods, [PeriodRecord(startDate: mar3)])
    }

    func testSavingTheSheetWithTheSameDateChangesNoHistoryAndKeepsHerLengths() {
        let c = container(makeStore())
        c.cycle.upsert(settings(mar3))
        c.cycle.upsert(settings(mar3, cycle: 26, period: 7))
        XCTAssertEqual(c.periods.periods, [PeriodRecord(startDate: mar3)])
        XCTAssertEqual(c.cycle.settings, settings(mar3, cycle: 26, period: 7), "her lengths are stored exactly as she set them")
    }

    func testANearbyDateInTheSheetIsACorrection() {
        let c = container(makeStore())
        c.cycle.upsert(settings(mar3))
        c.cycle.upsert(settings(mar5))
        XCTAssertEqual(c.periods.periods, [PeriodRecord(startDate: mar5)])
        XCTAssertEqual(c.cycle.settings?.lastPeriodDate, mar5)
    }

    /// An earlier date is a past period: it is added, and predictions stay on her latest start.
    func testAnEarlierDateInTheSheetIsABackFillAndTheDateStaysOnHerLatestStart() {
        let c = container(makeStore())
        c.cycle.upsert(settings(mar3))
        c.cycle.upsert(settings(feb1, cycle: 27, period: 4))
        XCTAssertEqual(c.periods.periods.map(\.startDate), [feb1, mar3])
        XCTAssertEqual(c.cycle.settings, settings(mar3, cycle: 27, period: 4))
    }

    func testRecordingOrDeletingAStartMovesLastPeriodDateAndNothingElse() {
        let c = container(makeStore())
        c.cycle.upsert(settings(feb1, cycle: 33, period: 6))

        c.periods.recordStart(mar3, today: today)
        XCTAssertEqual(c.cycle.settings, settings(mar3, cycle: 33, period: 6))

        c.periods.recordStart(jan3, today: today)
        XCTAssertEqual(c.cycle.settings, settings(mar3, cycle: 33, period: 6), "a past period does not move it")

        XCTAssertTrue(c.periods.delete(start: mar3))
        XCTAssertEqual(c.cycle.settings, settings(feb1, cycle: 33, period: 6), "deleting her latest start moves it back")
        XCTAssertEqual(c.periods.periods.map(\.startDate), [jan3, feb1])
    }

    // MARK: - A last period date written elsewhere (plan 7.1, the Android contract)

    private func reconcile(_ date: CalendarDate, _ records: [StoredPeriodRecord]) -> PeriodStartChange {
        PeriodReconcile.apply(lastPeriodDate: date, to: records, today: today, now: Date(timeIntervalSince1970: 5_000))
    }

    func testReconcileMoreThanTenDaysLaterAppends() {
        let records = [stored(feb1)]
        let change = reconcile(feb1.plusDays(11), records)
        XCTAssertEqual(change.outcome, .append(feb1.plusDays(11)))
        XCTAssertEqual(PeriodSync.visible(change.records).map(\.startDate), [feb1, feb1.plusDays(11)])
        XCTAssertEqual(change.records.last?.pendingSync, true)
    }

    func testReconcileWithinTenDaysLaterCorrectsTheLatestStart() {
        let change = reconcile(feb1.plusDays(10), [stored(jan3), stored(feb1)])
        XCTAssertEqual(change.outcome, .correction(from: feb1, to: feb1.plusDays(10)))
        XCTAssertEqual(PeriodSync.visible(change.records).map(\.startDate), [jan3, feb1.plusDays(10)])
    }

    func testReconcileWithinTenDaysEarlierCorrectsTheLatestStart() {
        let change = reconcile(feb1.minusDays(10), [stored(feb1)])
        XCTAssertEqual(change.outcome, .correction(from: feb1, to: feb1.minusDays(10)))
    }

    func testReconcileMoreThanTenDaysEarlierChangesNoHistory() {
        let records = [stored(feb1), stored(mar3)]
        for date in [mar3.minusDays(11), jan3, feb1.plusDays(2)] {
            XCTAssertEqual(reconcile(date, records).outcome, .noChange)
            XCTAssertEqual(reconcile(date, records).records, records, "no back-fill, and no correction of an older start")
        }
    }

    func testReconcileTheSameDateAsAnyStartChangesNoHistory() {
        let records = [stored(feb1), stored(mar3)]
        XCTAssertEqual(reconcile(mar3, records).records, records)
        XCTAssertEqual(reconcile(feb1, records).records, records)
    }

    func testReconcileWithNoVisibleStartOrAFutureDateChangesNoHistory() {
        XCTAssertEqual(reconcile(mar3, []).records, [])
        let emptied = [stored(feb1, deleted: true)]
        XCTAssertEqual(reconcile(mar3, emptied).records, emptied, "a history she emptied is not refilled")
        let records = [stored(mar3)]
        XCTAssertEqual(reconcile(today.plusDays(1), records).records, records)
    }

    /// Two starts closer than the window, and a date nearest the older one: the core would
    /// correct the older start, which is not what the table says, so nothing changes.
    func testReconcileNeverCorrectsAStartThatIsNotTheLatest() {
        let records = [stored(mar3), stored(mar5)]
        XCTAssertEqual(reconcile(mar3.minusDays(1), records).records, records)
    }

    /// A pull applies the table: Android moved `last_period_date` forward a month.
    func testAPullTurnsALaterRemoteLastPeriodDateIntoARecord() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(feb1, updatedAt: 1_000)]
        var saves = 0
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        repo.cycleSettings = { self.settings(self.mar3) }
        repo.saveCycleSettings = { _ in saves += 1 }

        await repo.refresh()

        XCTAssertEqual(repo.periods.map(\.startDate), [feb1, mar3])
        XCTAssertEqual(backend.remote.map(\.id).sorted(), [feb1, mar3], "the new record is pushed")
        XCTAssertEqual(saves, 0, "her settings are already on that date; nothing is written back")
    }

    /// The case the plan singles out. Her settings hold an OLDER date than her latest start
    /// (set on Android). History does not change, and no pull ever puts her settings back.
    func testAPullNeverOverwritesAnOlderRemoteLastPeriodDate() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(feb1, updatedAt: 1_000), stored(mar3, updatedAt: 1_000)]
        var saves = 0
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        repo.cycleSettings = { self.settings(self.jan3) }
        repo.saveCycleSettings = { _ in saves += 1 }

        await repo.refresh()
        backend.remote = [stored(mar3, end: mar5, updatedAt: 2_000)]   // another device recorded an end
        await repo.refresh()

        XCTAssertEqual(repo.periods.map(\.startDate), [feb1, mar3], "no back-fill of the older date")
        XCTAssertEqual(repo.periods.last?.endDate, mar5)
        XCTAssertEqual(saves, 0, "a pull never writes her settings")
    }

    // MARK: - Dates no period can be on

    private let year2099 = CalendarDate(2099, 1, 1)
    private let buddhistYear = CalendarDate(2569, 10, 6)   // what a phone on the Buddhist calendar calls 2026
    private let year8 = CalendarDate(8, 10, 6)             // and one on the Japanese calendar
    private let dec1899 = CalendarDate(1899, 12, 31)

    private func cursor(_ store: LocalStore) -> TimeInterval {
        store.load(Date.self, forKey: Self.cursorKey)?.timeIntervalSince1970 ?? -1
    }

    func testAStartNoPeriodCanBeOnIsRefusedAndNothingIsStored() {
        let store = makeStore()
        let repo = PeriodRepository(store: store)
        for date in [today.plusDays(1), year2099, buddhistYear, year8, dec1899] {
            XCTAssertEqual(repo.recordStart(date, today: today), .refused)
        }
        XCTAssertTrue(repo.periods.isEmpty)
        XCTAssertTrue(saved(store).isEmpty)
    }

    /// Her settings can hold any date: Android and older builds write them freely. Nothing is
    /// seeded from one no period can be on, with or without a pull, and nothing is pushed.
    func testALastPeriodDateNoPeriodCanBeOnSeedsNothingAndPushesNothing() async {
        for date in [today.plusDays(1), year2099, buddhistYear, year8, dec1899] {
            let store = makeStore()
            let backend = FakePeriodBackend()
            let repo = PeriodRepository(store: store, backend: backend)
            repo.cycleSettings = { self.settings(date) }

            repo.seedIfEmpty(today: today)
            await repo.refresh(today: today)

            XCTAssertTrue(repo.periods.isEmpty)
            XCTAssertTrue(saved(store).isEmpty, "nothing is seeded, on that date or on any other")
            XCTAssertEqual(backend.upserts, 0)
        }
    }

    func testTheSameSettingsSeedOnceTheirDateArrives() async {
        let tomorrow = today.plusDays(1)
        let backend = FakePeriodBackend()
        let repo = PeriodRepository(store: makeStore(), backend: backend)
        repo.cycleSettings = { self.settings(tomorrow) }

        await repo.refresh(today: today)
        XCTAssertTrue(repo.periods.isEmpty)

        await repo.refresh(today: tomorrow)
        XCTAssertEqual(repo.periods, [PeriodRecord(startDate: tomorrow, source: .seeded)])
        XCTAssertEqual(backend.remote.map(\.id), [tomorrow])
    }

    /// The settings sheet's way in. Such a date writes no history. What ends up in her settings
    /// is `CycleRepository`'s business and is not looked at here.
    func testADateNoPeriodCanBeOnInTheSettingsSheetWritesNoHistory() {
        let c = container(makeStore())
        c.cycle.upsert(settings(mar3))
        for date in [CalendarDate.today().plusDays(2), year2099, buddhistYear, year8, dec1899] {
            c.cycle.upsert(settings(date))
            XCTAssertEqual(c.periods.periods, [PeriodRecord(startDate: mar3)])
        }
    }

    // MARK: - Rows from the server on a date no period can be on

    /// Written by another client, or by a server that does not hold the rule. None of them is
    /// taken up, becomes her latest start, is sent back or is tombstoned.
    func testSuchARowIsLeftOutIsNeverHerLatestStartAndIsNeverSentBack() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(mar3, updatedAt: 1_000), stored(year2099, updatedAt: 1_000), stored(buddhistYear, updatedAt: 1_000),
                          stored(year8, updatedAt: 1_000), stored(dec1899, updatedAt: 1_000)]
        let onTheServer = backend.remote
        let store = makeStore()
        var saves: [CycleSettings] = []
        let repo = PeriodRepository(store: store, backend: backend)
        repo.cycleSettings = { saves.last ?? self.settings(self.mar3) }
        repo.saveCycleSettings = { saves.append($0) }

        await repo.refresh(today: today)

        XCTAssertEqual(repo.periods.map(\.startDate), [mar3])
        XCTAssertEqual(repo.cycles.map(\.length), [nil])
        XCTAssertEqual(saved(store).compactMap(\.record).map(\.id), [mar3], "not kept on the device, shown or hidden")
        XCTAssertEqual(backend.upserts, 0, "not sent back, and not tombstoned")
        XCTAssertEqual(backend.remote, onTheServer)

        // Whatever she records next moves her last period date to HER latest start.
        let later = mar3.plusDays(20)
        XCTAssertEqual(repo.recordStart(later, today: today), .append(later))
        XCTAssertTrue(repo.delete(start: later))
        XCTAssertEqual(saves.map(\.lastPeriodDate), [later, mar3])

        await repo.refresh(today: today)
        XCTAssertEqual(repo.periods.map(\.startDate), [mar3], "and the next pull leaves them out again")
    }

    /// A row a day ahead can be real: recorded in a time zone ahead of this one, or this phone's
    /// clock is behind. It is left out for now, asked for again, and taken up when its day comes.
    func testARowAheadOfThisDevicesDateWaitsAndIsTakenUpWhenItsDayArrives() async {
        let tomorrow = today.plusDays(1)
        let store = makeStore()
        let backend = FakePeriodBackend()
        backend.remote = [stored(mar3, updatedAt: 1_000)]
        let repo = PeriodRepository(store: store, backend: backend)
        await repo.refresh(today: today)
        XCTAssertEqual(cursor(store), 1_000, accuracy: 0.001)

        backend.remote.append(stored(tomorrow, updatedAt: 2_000))
        await repo.refresh(today: today)
        XCTAssertEqual(repo.periods.map(\.startDate), [mar3])
        XCTAssertEqual(cursor(store), 1_000, accuracy: 0.001, "the cursor must not step past a row that was left out")

        await repo.refresh(today: tomorrow)
        XCTAssertEqual(repo.periods.map(\.startDate), [mar3, tomorrow])
        XCTAssertEqual(cursor(store), 2_000, accuracy: 0.001)
        XCTAssertEqual(backend.sinceArgs.map { $0?.timeIntervalSince1970 }, [nil, 940, 940], "it was asked for again")
        XCTAssertEqual(backend.upserts, 0)
    }

    /// A row before the earliest date will never be taken up, so nothing waits for it.
    func testARowBeforeTheEarliestDateDoesNotHoldTheCursor() async {
        let store = makeStore()
        let backend = FakePeriodBackend()
        backend.remote = [stored(mar3, updatedAt: 1_000), stored(year8, updatedAt: 2_000)]
        let repo = PeriodRepository(store: store, backend: backend)

        await repo.refresh(today: today)

        XCTAssertEqual(repo.periods.map(\.startDate), [mar3])
        XCTAssertEqual(cursor(store), 2_000, accuracy: 0.001)
    }

    /// A date this device already holds (recorded where the date was a day ahead, say) merges as
    /// it always did. Left out, the full merge would push our older copy over the server's.
    func testAServerRowOnADateThisDeviceAlreadyHoldsStillMerges() async {
        let tomorrow = today.plusDays(1)
        let store = makeStore()
        store.save([stored(tomorrow, updatedAt: 1_000).dto], forKey: Self.key)
        let backend = FakePeriodBackend()
        backend.remote = [stored(tomorrow, end: tomorrow, updatedAt: 9_000)]
        let repo = PeriodRepository(store: store, backend: backend)

        await repo.refresh(today: today)

        XCTAssertEqual(repo.periods, [PeriodRecord(startDate: tomorrow, endDate: tomorrow)], "the server's later copy is taken")
        XCTAssertEqual(backend.upserts, 0, "and ours is not pushed over it")
    }

    /// Only the start decides. An end on such a date comes with a period that is hers, so the
    /// period is taken as it arrived, like any other end a merge brings in, and is not sent back.
    func testARowWhoseEndIsOnSuchADateKeepsItsPeriod() async {
        let backend = FakePeriodBackend()
        backend.remote = [stored(feb1, end: year8, updatedAt: 1_000), stored(mar3, end: year2099, updatedAt: 1_000)]
        let repo = PeriodRepository(store: makeStore(), backend: backend)

        await repo.refresh(today: today)

        XCTAssertEqual(repo.periods.map(\.startDate), [feb1, mar3])
        XCTAssertEqual(repo.cycles.map(\.length), [30, nil])
        XCTAssertNil(repo.cycles.first?.periodDays, "an end before its start is not counted")
        XCTAssertEqual(backend.upserts, 0)
        XCTAssertEqual(repo.setEnd(nil, forStart: mar3, today: today), .updated, "and she can clear it")
    }

    // MARK: - A record the server refuses

    func testSyncErrorTellsARefusedRowFromEverythingElse() {
        XCTAssertTrue(SyncError.isRowRefused(RemoteError.rowRefused))
        XCTAssertFalse(SyncError.shouldHaltDrain(RemoteError.rowRefused), "it is about one row, not about the connection")
        let others: [Error] = [URLError(.notConnectedToInternet), URLError(.timedOut), RemoteError.notAuthenticated,
                               RemoteError.notConfigured, PeriodDrainProbeError.serverRejected]
        for other in others { XCTAssertFalse(SyncError.isRowRefused(other)) }
    }

    /// This phone's date was ahead when she recorded the start, so the device accepted it and
    /// the server refuses it on every attempt. It is offered once.
    func testARecordTheServerRefusesIsOfferedOnceAndDoesNotBlockTheRest() async {
        let store = makeStore()
        let seeder = PeriodRepository(store: store)
        seeder.recordStart(feb1, today: today)
        seeder.recordStart(mar3, today: today)

        let backend = ProbePeriodBackend()
        backend.refuse = feb1
        let repo = PeriodRepository(store: store, backend: backend)
        for _ in 1...3 { await repo.drainPending() }

        XCTAssertEqual(backend.attempts, 2, "offered once and never again, and the record behind it still went")
        XCTAssertEqual(backend.remote.map(\.id), [mar3])
        XCTAssertEqual(repo.refusedStarts, [feb1], "the app can see which period the server would not take")
        XCTAssertEqual(repo.periods.map(\.startDate), [feb1, mar3], "nothing she recorded is removed")
        XCTAssertEqual(saved(store).compactMap(\.record).filter(\.pendingSync).map(\.id), [feb1], "and it is not passed off as synced")

        // A relaunch and a full pull forget none of it.
        let relaunched = PeriodRepository(store: store, backend: backend)
        await relaunched.refresh(today: today)
        XCTAssertEqual(backend.attempts, 2)
        XCTAssertEqual(relaunched.refusedStarts, [feb1])
        XCTAssertEqual(relaunched.periods.map(\.startDate), [feb1, mar3])
    }

    /// Changing the record is one way out: the new version is a different write, so it is offered.
    func testARefusedRecordIsOfferedAgainOnceSheChangesIt() async {
        let store = makeStore()
        PeriodRepository(store: store).recordStart(feb1, today: today)
        let backend = ProbePeriodBackend()
        backend.refuse = feb1
        await PeriodRepository(store: store, backend: backend).drainPending()

        XCTAssertEqual(PeriodRepository(store: store).setEnd(feb1.plusDays(3), forStart: feb1, today: today), .updated)
        backend.refuse = nil
        let repo = PeriodRepository(store: store, backend: backend)
        XCTAssertTrue(repo.refusedStarts.isEmpty, "the version that was refused is no longer the one she has")
        await repo.drainPending()

        XCTAssertEqual(backend.attempts, 2)
        XCTAssertEqual(backend.remote.map(\.period), [PeriodRecord(startDate: feb1, endDate: feb1.plusDays(3))])
        XCTAssertTrue(saved(store).allSatisfy { $0.pendingSync == false })
    }

    /// Deleting it is the other. The server refuses the tombstone for the same reason, which is
    /// harmless because it never held the record. Nothing is left to show, report or retry.
    func testDeletingARefusedRecordEndsIt() async {
        let store = makeStore()
        PeriodRepository(store: store).recordStart(feb1, today: today)
        let backend = ProbePeriodBackend()
        backend.refuse = feb1
        await PeriodRepository(store: store, backend: backend).drainPending()

        XCTAssertTrue(PeriodRepository(store: store).delete(start: feb1))
        let repo = PeriodRepository(store: store, backend: backend)
        for _ in 1...3 { await repo.drainPending() }

        XCTAssertEqual(backend.attempts, 2, "the record once, its tombstone once")
        XCTAssertTrue(repo.periods.isEmpty)
        XCTAssertTrue(repo.refusedStarts.isEmpty)
        XCTAssertTrue(backend.remote.isEmpty)
    }

    /// Everything else the server rejects is offered on every drain, exactly as before: from
    /// here it cannot be told from a failure that will pass.
    func testAnyOtherRejectionIsStillRetriedOnEveryDrain() async {
        let store = makeStore()
        let seeder = PeriodRepository(store: store)
        seeder.recordStart(feb1, today: today)
        seeder.recordStart(mar3, today: today)

        let backend = ProbePeriodBackend(reject: feb1)
        let repo = PeriodRepository(store: store, backend: backend)
        for _ in 1...3 { await repo.drainPending() }

        XCTAssertEqual(backend.attempts, 4, "feb1 on each of the three drains, mar3 once")
        XCTAssertEqual(saved(store).compactMap(\.record).filter(\.pendingSync).map(\.id), [feb1])
        XCTAssertTrue(repo.refusedStarts.isEmpty)
        XCTAssertNil(store.load([CalendarDate: Date].self, forKey: Self.refusedKey), "nothing is written when nothing was refused")
    }

    func testSignOutForgetsWhatTheServerRefused() async {
        let store = makeStore()
        PeriodRepository(store: store).recordStart(feb1, today: today)
        let backend = ProbePeriodBackend()
        backend.refuse = feb1
        let repo = PeriodRepository(store: store, backend: backend)
        await repo.drainPending()
        XCTAssertEqual(store.load([CalendarDate: Date].self, forKey: Self.refusedKey)?.keys.map { $0 }, [feb1])

        repo.clearLocalState()

        XCTAssertTrue(repo.refusedStarts.isEmpty)
        XCTAssertNil(store.load([CalendarDate: Date].self, forKey: Self.refusedKey), "it names a period date, so it goes with the rest")
    }

    // MARK: - The flag

    /// `cycleHistory: false` is the Release configuration. Nothing is seeded, written or pulled,
    /// and saving settings does exactly what it did before.
    func testWithTheFlagOffNothingIsSeededWrittenOrPulled() async {
        let store = makeStore()
        let c = container(store, cycleHistory: false)
        XCTAssertFalse(c.cycleHistory)
        XCTAssertNil(c.cycle.periodStartRecorder, "the settings flow is untouched")

        XCTAssertTrue(c.cycle.upsert(settings(feb1)))
        XCTAssertTrue(c.cycle.upsert(settings(jan3, cycle: 25, period: 3)))
        XCTAssertEqual(c.cycle.settings, settings(jan3, cycle: 25, period: 3), "an earlier date is stored as given, as before")

        c.periods.seedIfEmpty()
        XCTAssertNil(c.periods.recordStart(mar3, today: today))
        XCTAssertNil(c.periods.setEnd(mar5, forStart: mar3, today: today))
        await c.hydrate()
        await c.drainPending()
        XCTAssertTrue(c.periods.periods.isEmpty)
        XCTAssertNil(store.load([PeriodRecordDTO].self, forKey: Self.key), "nothing was ever stored")

        // The container's own gate, in front of a backend: no pull, nothing seeded, nothing pushed.
        let spy = FakePeriodBackend()
        spy.remote = [stored(mar3)]
        let repo = PeriodRepository(store: store, backend: spy)
        repo.isCollectionPermitted = c.periods.isCollectionPermitted
        repo.cycleSettings = { c.cycle.settings }
        await repo.refresh()
        XCTAssertTrue(spy.sinceArgs.isEmpty, "the table is never read while the flag is off")
        XCTAssertEqual(spy.upserts, 0)
        XCTAssertTrue(repo.periods.isEmpty)
        XCTAssertTrue(container(store, cycleHistory: false).periods.periods.isEmpty)
    }

    func testALocalOnlyContainerExposesPeriodsAndItsSyncCallsComplete() async {
        let c = container(makeStore())
        XCTAssertTrue(c.cycleHistory, "on in a DEBUG build")
        XCTAssertEqual(c.periods.recordStart(mar3, today: today), .append(mar3))
        await c.hydrate()
        await c.drainPending()
        XCTAssertEqual(c.periods.periods.count, 1)
    }

    // MARK: - Source guards

    /// A test run is always a DEBUG build, so the Release value is asked of the source, the way
    /// `ScanReleaseGateTests` does. If this fails, do not edit the test to match the code: the
    /// three conditions are on the flag's doc comment in `LearnModels.swift`.
    func testTheFlagIsDebugOnlyAndReadInOnePlace() throws {
        let models = Self.collapsed(try Self.source("App/Genesyx/UI/Learn/LearnModels.swift"))
        XCTAssertTrue(
            models.contains("#if DEBUG static let cycleHistory = true #else static let cycleHistory = false #endif"),
            "`cycleHistory` must stay off for Release until the migration, consent review and Android contract are done")
        XCTAssertEqual(Self.count("static let cycleHistory", in: models), 2)

        var reads: [String: Int] = [:]
        let root = Self.repoRoot.appendingPathComponent("App/Genesyx")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let file as URL in walker where file.pathExtension == "swift" {
            let hits = Self.codeLines(try String(contentsOf: file, encoding: .utf8))
                .reduce(0) { $0 + Self.count("FeatureFlags.cycleHistory", in: $1) }
            if hits > 0 { reads[file.lastPathComponent] = hits }
        }
        XCTAssertEqual(reads, ["AppContainer.swift": 1],
                       "`FeatureFlags.cycleHistory` is read once, as the default of `AppContainer.init`. Everything else asks the container.")

        let container = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/Data/App/AppContainer.swift")).joined(separator: "\n"))
        for required in [
            "cycleHistory: Bool = FeatureFlags.cycleHistory) {",
            "periods.isCollectionPermitted = { cycleHistory && permitted() }",
            "if cycleHistory { await periods.refresh() }",
            "if cycleHistory { await periods.drainPending() }",
            "if cycleHistory { periods.cycleSettings = { [cycle] in cycle.settings }",
        ] {
            XCTAssertTrue(container.contains(required), "AppContainer must still contain `\(required)`")
        }
        XCTAssertEqual(Self.count("periodStartRecorder =", in: container), 1, "the settings flow is wired in one place, behind the flag")
        XCTAssertEqual(Self.count("periods.refresh()", in: container), 1, "the pull has one caller, behind the flag")
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

    /// Every line that is not a comment.
    private static func codeLines(_ source: String) -> [String] {
        source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
    }

    private static func collapsed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}

// In-memory stand-ins for `period_records`, shaped like the LH fakes.

/// Stores what it is sent and records the `updatedSince` argument of every pull.
@MainActor
private final class FakePeriodBackend: PeriodBackend {
    var remote: [StoredPeriodRecord] = []
    var online = true
    private(set) var sinceArgs: [Date?] = []
    private(set) var upserts = 0

    func list(updatedSince: Date?) async throws -> SyncPage<[StoredPeriodRecord]> {
        sinceArgs.append(updatedSince)
        guard online else { throw URLError(.notConnectedToInternet) }
        return SyncPage(payload: remote, latestUpdatedAt: remote.map(\.updatedAt).max())
    }

    func upsert(_ record: StoredPeriodRecord) async throws {
        upserts += 1
        guard online else { throw URLError(.notConnectedToInternet) }
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}

private enum PeriodDrainProbeError: Error { case serverRejected }

/// Keeps the order rows were accepted in. Rejects one start date with a non-transport error,
/// refuses one as the table's CHECK would, or fails every call as an offline connection would.
@MainActor
private final class ProbePeriodBackend: PeriodBackend {
    var remote: [StoredPeriodRecord] = []
    private(set) var pushed: [StoredPeriodRecord] = []
    private(set) var attempts = 0
    var reject: CalendarDate?
    var refuse: CalendarDate?
    var offline = false

    init(reject: CalendarDate? = nil) { self.reject = reject }

    func list(updatedSince: Date?) async throws -> SyncPage<[StoredPeriodRecord]> {
        SyncPage(payload: remote, latestUpdatedAt: remote.map(\.updatedAt).max())
    }

    func upsert(_ record: StoredPeriodRecord) async throws {
        attempts += 1
        if offline { throw URLError(.notConnectedToInternet) }
        if record.id == reject { throw PeriodDrainProbeError.serverRejected }
        if record.id == refuse { throw RemoteError.rowRefused }
        pushed.append(record)
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}
