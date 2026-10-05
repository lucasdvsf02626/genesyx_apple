import XCTest
@testable import Genesyx
import GenesyxCore

/// The LH (ovulation test) data layer: the persisted DTO, the `lh_results` row, and
/// `LhRepository`, which is a copy of `PhRepository` and is held to the same behaviour.
@MainActor
final class LhRepositoryTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    private static let key = "lh_results"
    private static let cursorKey = "lh_results_cursor"

    private let measurement = LhScanMeasurement(
        testSignal: 0.45, controlSignal: 0.5, testControlRatio: 0.9, confidence: 0.95,
        scannerVersion: "scanner-1", configurationID: "strip-test", configurationVersion: "9.9.9")

    private func serverRecord(id: String, updatedAt: TimeInterval) -> LhRecord {
        LhRecord(result: LhResult(id: id, recordedAt: Date(timeIntervalSince1970: updatedAt), classification: .low),
                 updatedAt: Date(timeIntervalSince1970: updatedAt), pendingSync: false)
    }

    private func json(_ row: LhResultRow) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
    }

    private static let scanKeys = ["test_signal", "control_signal", "test_control_ratio", "scan_confidence",
                                   "scan_configuration_id", "scan_configuration_version", "scanner_version"]

    // MARK: - Local DTO

    /// Through `LhRecord.dto`, the one path the repository persists through, and back.
    func testDTORoundTripThroughRecordDTO() throws {
        let manual = LhRecord(
            result: LhResult(id: "m", recordedAt: Date(timeIntervalSince1970: 1_000), cycleDay: 12, classification: .invalid),
            updatedAt: Date(timeIntervalSince1970: 2_000), pendingSync: false, deleted: true)
        let scanned = LhRecord(
            result: LhResult(id: "s", recordedAt: Date(timeIntervalSince1970: 3_000), cycleDay: 14,
                             classification: .positive, scan: measurement),
            updatedAt: Date(timeIntervalSince1970: 4_000), pendingSync: true)

        for record in [manual, scanned] {
            let data = try JSONEncoder().encode(record.dto)
            let back = try JSONDecoder().decode(LhResultDTO.self, from: data).record
            XCTAssertEqual(back, record)
        }
        XCTAssertEqual(manual.dto.record?.result.source, .manual)
        XCTAssertEqual(scanned.dto.record?.result.scan, measurement, "every measurement field must survive")
        XCTAssertEqual(scanned.dto.record?.result.cycleDay, 14)
        XCTAssertEqual(manual.dto.record?.deleted, true, "the tombstone flag must survive")
    }

    func testMinimalDTODecodesAsManualAndPending() throws {
        let data = Data(#"{"id":"a","recordedAt":0,"classification":"low"}"#.utf8)
        let record = try XCTUnwrap(JSONDecoder().decode(LhResultDTO.self, from: data).record)
        XCTAssertEqual(record.result.source, .manual)
        XCTAssertNil(record.result.cycleDay)
        XCTAssertTrue(record.pendingSync, "a record with no bookkeeping has never been pushed")
        XCTAssertFalse(record.deleted)
        XCTAssertEqual(record.updatedAt, record.result.recordedAt)
    }

    func testUnknownClassificationIsDroppedAndTheOthersStillLoad() {
        XCTAssertNil(LhResultDTO(id: "x", recordedAt: Date(), classification: "nonsense").record)

        let store = makeStore()
        store.save([LhResultDTO(id: "a", recordedAt: Date(timeIntervalSince1970: 1), classification: "low"),
                    LhResultDTO(id: "x", recordedAt: Date(timeIntervalSince1970: 2), classification: "nonsense"),
                    LhResultDTO(id: "b", recordedAt: Date(timeIntervalSince1970: 3), classification: "positive")],
                   forKey: Self.key)
        XCTAssertEqual(LhRepository(store: store).results.map(\.id), ["a", "b"])
    }

    /// A scan is rebuilt only when all seven measurement fields are there; otherwise it is manual.
    func testDTOWithAnIncompleteScanDecodesAsManual() {
        var dto = LhRecord(result: LhResult(recordedAt: Date(), classification: .low, scan: measurement),
                           updatedAt: Date(), pendingSync: true).dto
        dto.scannerVersion = nil
        XCTAssertEqual(dto.record?.result.source, .manual)
    }

    // MARK: - Remote row

    func testManualRowEncodesManualSourceAndNoScanKeys() throws {
        let record = LhRecord(result: LhResult(id: "a", recordedAt: Date(), cycleDay: 9, classification: .low),
                              updatedAt: Date(), pendingSync: true)
        let body = try json(LhResultRow(userId: "u", record: record))
        XCTAssertEqual(body["source"] as? String, "manual")
        XCTAssertEqual(body["classification"] as? String, "low")
        XCTAssertEqual(body["cycle_day"] as? Int, 9)
        XCTAssertEqual(body["user_id"] as? String, "u")
        XCTAssertNil(body["deleted_at"])
        for key in Self.scanKeys { XCTAssertNil(body[key], "\(key) must be omitted for a manual result") }
    }

    func testScannedRowEncodesAllSevenScanKeysAndDecodesBack() throws {
        let record = LhRecord(result: LhResult(id: "a", recordedAt: Date(timeIntervalSince1970: 1_000),
                                               classification: .positive, scan: measurement),
                              updatedAt: Date(timeIntervalSince1970: 2_000), pendingSync: true)
        let row = LhResultRow(userId: "u", record: record)
        let body = try json(row)
        XCTAssertEqual(body["source"] as? String, "camera_scan")
        for key in Self.scanKeys { XCTAssertNotNil(body[key], "\(key) must be sent for a scan") }

        let back = try XCTUnwrap(JSONDecoder().decode(LhResultRow.self, from: JSONEncoder().encode(row)).domain)
        XCTAssertEqual(back.result.scan, measurement)
        XCTAssertEqual(back.result, record.result)
        XCTAssertFalse(back.pendingSync)
        XCTAssertFalse(back.deleted)
    }

    func testTombstoneRowCarriesDeletedAt() throws {
        let record = LhRecord(result: LhResult(id: "a", recordedAt: Date(), classification: .low),
                              updatedAt: Date(), pendingSync: true, deleted: true)
        let row = LhResultRow(userId: "u", record: record)
        XCTAssertNotNil(try json(row)["deleted_at"])
        XCTAssertEqual(row.domain?.deleted, true)
    }

    func testCameraScanRowMissingOneScanValueDecodesAsManual() throws {
        let data = Data("""
        {"id":"a","user_id":"u","recorded_at":"2026-10-05T08:00:00Z","classification":"positive",
         "source":"camera_scan","test_signal":0.45,"control_signal":0.5,"test_control_ratio":0.9,
         "scan_confidence":0.95,"scan_configuration_id":"strip-test","scan_configuration_version":"9.9.9",
         "updated_at":"2026-10-05T08:00:01Z"}
        """.utf8)
        let record = try XCTUnwrap(JSONDecoder().decode(LhResultRow.self, from: data).domain)
        XCTAssertEqual(record.result.source, .manual)
        XCTAssertEqual(record.result.classification, .positive)
    }

    func testRowWithUnknownClassificationHasNoDomain() throws {
        let data = Data("""
        {"id":"a","user_id":"u","recorded_at":"2026-10-05T08:00:00Z","classification":"nonsense",
         "source":"manual","updated_at":"2026-10-05T08:00:01Z"}
        """.utf8)
        XCTAssertNil(try JSONDecoder().decode(LhResultRow.self, from: data).domain)
    }

    // MARK: - Repository

    func testResultsSurviveARelaunchOrderedByRecordedAt() {
        let store = makeStore()
        let repo = LhRepository(store: store)
        XCTAssertTrue(repo.create(LhResult(id: "late", recordedAt: Date(), classification: .positive, scan: measurement)))
        XCTAssertTrue(repo.create(LhResult(id: "early", recordedAt: Date().addingTimeInterval(-86_400), cycleDay: 11,
                                           classification: .low)))

        let relaunched = LhRepository(store: store)
        XCTAssertEqual(relaunched.results.map(\.id), ["early", "late"])
        XCTAssertEqual(relaunched.results.first?.cycleDay, 11)
        XCTAssertEqual(relaunched.results.last?.scan, measurement)
    }

    func testAnUnreadableResultIsRefusedAndNothingIsStored() {
        let store = makeStore()
        let repo = LhRepository(store: store)
        XCTAssertFalse(repo.create(LhResult(recordedAt: Date(), classification: .unreadable)))
        XCTAssertTrue(repo.results.isEmpty)
        XCTAssertNil(store.load([LhResultDTO].self, forKey: Self.key))
    }

    func testDeleteIsATombstoneAndSurvivesAPull() async {
        let backend = FakeLhBackend()
        let repo = LhRepository(store: makeStore(), backend: backend)
        repo.create(LhResult(id: "a", recordedAt: Date(), classification: .low))
        await repo.drainPending()

        repo.delete(id: "a")
        XCTAssertTrue(repo.results.isEmpty, "hidden at once")
        await repo.drainPending()

        XCTAssertEqual(backend.remote.first?.deleted, true, "the server gets a tombstone, not a delete")

        await repo.refresh()

        XCTAssertTrue(repo.results.isEmpty, "a pull must not resurrect a deleted result")
    }

    func testEmptyCloudDoesNotWipeLocalHistoryAndPushesItUp() async {
        let backend = FakeLhBackend()
        let repo = LhRepository(store: makeStore(), backend: backend)
        repo.create(LhResult(id: "a", recordedAt: Date(), classification: .low))

        await repo.refresh()

        XCTAssertEqual(repo.results.map(\.id), ["a"], "an empty cloud must not wipe the device")
        XCTAssertEqual(backend.remote.map(\.id), ["a"], "the local-only result is carried up")
    }

    func testFailedPushStaysQueuedAndLandsOnTheNextRefresh() async {
        let store = makeStore()
        let backend = FakeLhBackend()
        backend.online = false
        let repo = LhRepository(store: store, backend: backend)

        repo.create(LhResult(id: "a", recordedAt: Date(), classification: .low))
        await repo.drainPending()

        XCTAssertEqual(repo.results.map(\.id), ["a"], "an offline save is never dropped")
        XCTAssertTrue(backend.remote.isEmpty)
        XCTAssertEqual(store.load([LhResultDTO].self, forKey: Self.key)?.first?.pendingSync, true)

        backend.online = true
        await repo.refresh()

        XCTAssertEqual(backend.remote.map(\.id), ["a"])
    }

    /// What keeps a refused row (for example while the table does not exist yet) from blocking
    /// the results behind it.
    func testAServerRejectedResultIsSteppedOverSoNewerOnesStillSync() async {
        let store = makeStore()
        let seeder = LhRepository(store: store, backend: nil)
        seeder.create(LhResult(id: "aaaa-poison", recordedAt: Date().addingTimeInterval(-100), classification: .low))
        seeder.create(LhResult(id: "bbbb-good", recordedAt: Date(), classification: .positive))

        let backend = ProbeLhBackend(reject: "aaaa-poison")
        let repo = LhRepository(store: store, backend: backend)
        await repo.drainPending()

        XCTAssertTrue(backend.remote.contains { $0.id == "bbbb-good" }, "the good result must get past the poisoned one")
        XCTAssertFalse(backend.remote.contains { $0.id == "aaaa-poison" }, "the rejected result is not stored")
        XCTAssertEqual(repo.results.count, 2, "and the rejected one stays on the device")
    }

    // MARK: - Consent

    func testWithdrawingConsentStopsNewResultsButNotDeletion() {
        let c = AppContainer(store: makeStore(), backend: nil)
        c.consent.grant()
        let kept = LhResult(recordedAt: Date(), classification: .low)
        XCTAssertTrue(c.lh.create(kept))

        c.consent.withdraw()

        XCTAssertFalse(c.lh.create(LhResult(recordedAt: Date(), classification: .positive)),
                       "no new result may be recorded after a withdrawal")
        XCTAssertEqual(c.lh.results.count, 1)

        c.lh.delete(id: kept.id)
        XCTAssertTrue(c.lh.results.isEmpty, "erasing what she recorded must stay available")
    }

    func testAWithdrawnRefreshDoesNotPullButStillDrains() async {
        let store = makeStore()
        LhRepository(store: store).create(LhResult(id: "owed", recordedAt: Date(), classification: .low))

        let spy = CursorSpyLhBackend()
        spy.remote = [serverRecord(id: "theirs", updatedAt: 1_000)]
        let repo = LhRepository(store: store, backend: spy)
        repo.isCollectionPermitted = { false }

        await repo.refresh()

        XCTAssertTrue(spy.sinceArgs.isEmpty, "a withdrawn phone must not pull her results back down")
        XCTAssertEqual(repo.results.map(\.id), ["owed"])
        XCTAssertTrue(spy.remote.contains { $0.id == "owed" }, "the queue still drains")
    }

    // MARK: - Wipe

    func testSignOutClearsLhResultsAndTheCursor() {
        let store = makeStore()
        store.save(Date(timeIntervalSince1970: 1_000), forKey: Self.cursorKey)
        let c = AppContainer(store: store, backend: nil)
        c.consent.grant()
        c.lh.create(LhResult(recordedAt: Date(), classification: .positive))
        XCTAssertFalse(c.lh.results.isEmpty)
        XCTAssertNotNil(store.load([LhResultDTO].self, forKey: Self.key))

        c.session.signOut()

        XCTAssertTrue(c.lh.results.isEmpty)
        XCTAssertNil(store.load([LhResultDTO].self, forKey: Self.key))
        XCTAssertNil(store.load(Date.self, forKey: Self.cursorKey), "the next account must start from a full pull")
        XCTAssertTrue(LhRepository(store: store).results.isEmpty)
    }

    // MARK: - Cursor

    func testSyncIsFullThenIncremental() async {
        let spy = CursorSpyLhBackend()
        spy.remote = [serverRecord(id: "a", updatedAt: 1_000)]
        let repo = LhRepository(store: makeStore(), backend: spy)
        await repo.refresh()
        await repo.refresh()
        XCTAssertEqual(spy.sinceArgs.count, 2)
        XCTAssertNil(spy.sinceArgs[0], "first sync must fetch full history")
        XCTAssertEqual(spy.sinceArgs[1]?.timeIntervalSince1970 ?? -1, 940, accuracy: 0.001,
                       "second sync asks from the cursor less the 60 s overlap")
    }

    func testCursorIsServerTimeNotDeviceClock() async {
        let store = makeStore()
        let spy = CursorSpyLhBackend()
        spy.remote = [serverRecord(id: "a", updatedAt: 1_000)]
        await LhRepository(store: store, backend: spy).refresh()

        XCTAssertEqual(store.load(Date.self, forKey: Self.cursorKey)?.timeIntervalSince1970 ?? -1, 1_000, accuracy: 0.001,
                       "the cursor must be the server's updated_at, never the device clock")
    }

    func testEmptyFailedAndUnreadablePullsEachHoldTheCursor() async {
        let store = makeStore()
        let spy = CursorSpyLhBackend()
        spy.remote = [serverRecord(id: "a", updatedAt: 1_000)]
        let repo = LhRepository(store: store, backend: spy)
        await repo.refresh()
        func cursor() -> TimeInterval { store.load(Date.self, forKey: Self.cursorKey)?.timeIntervalSince1970 ?? -1 }

        spy.remote = []
        await repo.refresh()
        XCTAssertEqual(cursor(), 1_000, accuracy: 0.001, "an empty pull must leave the cursor where it was")

        spy.online = false
        spy.remote = [serverRecord(id: "b", updatedAt: 9_000)]
        await repo.refresh()
        XCTAssertEqual(cursor(), 1_000, accuracy: 0.001, "a failed pull must not advance the cursor")

        spy.online = true
        spy.cursorOverride = .some(nil)             // the page carried a stamp that would not parse
        await repo.refresh()
        XCTAssertEqual(cursor(), 1_000, accuracy: 0.001, "an unreadable server stamp must not advance the cursor")
        XCTAssertTrue(repo.results.contains { $0.id == "b" },
                      "holding the cursor must not cost us the rows the pull did return")
    }

    func testCursorNeverMovesBackwards() async {
        let store = makeStore()
        let spy = CursorSpyLhBackend()
        spy.remote = [serverRecord(id: "a", updatedAt: 5_000)]
        let repo = LhRepository(store: store, backend: spy)
        await repo.refresh()

        spy.remote = [serverRecord(id: "b", updatedAt: 2_000)]
        await repo.refresh()

        XCTAssertEqual(store.load(Date.self, forKey: Self.cursorKey)?.timeIntervalSince1970 ?? -1, 5_000, accuracy: 0.001)
    }

    // MARK: - Container

    func testALocalOnlyContainerExposesLhAndItsSyncCallsComplete() async {
        let c = AppContainer(store: makeStore(), backend: nil)
        c.consent.grant()
        XCTAssertTrue(c.lh.create(LhResult(recordedAt: Date(), classification: .low)))
        await c.hydrate()
        await c.drainPending()
        XCTAssertEqual(c.lh.results.count, 1)
    }
}

// In-memory stand-ins for `lh_results`, shaped like the pH fakes in `RepositoryTests`.

@MainActor
private final class FakeLhBackend: LhBackend {
    var remote: [LhRecord] = []
    var online = true

    func list(updatedSince: Date?) async throws -> SyncPage<[LhRecord]> {
        guard online else { throw RemoteError.notConfigured }
        return SyncPage(payload: remote, latestUpdatedAt: remote.map(\.updatedAt).max())
    }

    func upsert(_ record: LhRecord) async throws {
        guard online else { throw RemoteError.notConfigured }
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}

/// Records the `updatedSince` argument of every pull. `cursorOverride` replaces the stamp this
/// fake hands back, for an empty page or an unreadable timestamp.
@MainActor
private final class CursorSpyLhBackend: LhBackend {
    var remote: [LhRecord] = []
    var online = true
    private(set) var sinceArgs: [Date?] = []
    var cursorOverride: Date??

    func list(updatedSince: Date?) async throws -> SyncPage<[LhRecord]> {
        sinceArgs.append(updatedSince)
        guard online else { throw RemoteError.notConfigured }
        return SyncPage(payload: remote, latestUpdatedAt: cursorOverride ?? remote.map(\.updatedAt).max())
    }

    func upsert(_ record: LhRecord) async throws {
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}

private enum LhDrainProbeError: Error { case serverRejected }

/// Rejects one result id with a non-transport error; stores every other result.
@MainActor
private final class ProbeLhBackend: LhBackend {
    var remote: [LhRecord] = []
    var reject: String?

    init(reject: String? = nil) { self.reject = reject }

    func list(updatedSince: Date?) async throws -> SyncPage<[LhRecord]> {
        SyncPage(payload: remote, latestUpdatedAt: remote.map(\.updatedAt).max())
    }

    func upsert(_ record: LhRecord) async throws {
        if record.id == reject { throw LhDrainProbeError.serverRejected }
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}
