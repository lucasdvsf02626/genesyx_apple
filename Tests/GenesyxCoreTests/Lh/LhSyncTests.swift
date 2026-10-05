import XCTest
@testable import GenesyxCore

final class LhSyncTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(_ id: String, _ classification: LhClassification = .low, recorded: Double = 0,
                        updated: Double, pending: Bool = false, deleted: Bool = false) -> LhRecord {
        LhRecord(
            result: LhResult(id: id, recordedAt: t0.addingTimeInterval(recorded), classification: classification),
            updatedAt: t0.addingTimeInterval(updated),
            pendingSync: pending,
            deleted: deleted
        )
    }

    // MARK: - The data-loss case

    /// An empty cloud must never wipe the device: the local history is kept and queued for push.
    func testEmptyRemoteKeepsLocalHistoryAndQueuesIt() {
        let local = [record("a", updated: 10), record("b", updated: 20)]

        let merged = LhSync.merge(local: local, remote: [])

        XCTAssertEqual(merged.map(\.id), ["a", "b"])
        XCTAssertTrue(merged.allSatisfy(\.pendingSync), "local-only records must be queued for push")
    }

    // MARK: - Conflict resolution

    func testUnpushedLocalEditBeatsNewerRemote() {
        let local = [record("a", .positive, updated: 10, pending: true)]
        let remote = [record("a", .low, updated: 99)]

        let merged = LhSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.result.classification, .positive)
        XCTAssertTrue(merged.first!.pendingSync)
    }

    func testNewerRemoteWinsOverSyncedLocal() {
        let local = [record("a", .low, updated: 10)]
        let remote = [record("a", .positive, updated: 20)]

        let merged = LhSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.result.classification, .positive)
        XCTAssertFalse(merged.first!.pendingSync)
    }

    func testStaleRemoteLosesToNewerLocalAndIsRequeued() {
        let local = [record("a", .positive, updated: 30)]
        let remote = [record("a", .low, updated: 20)]

        let merged = LhSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.result.classification, .positive)
        XCTAssertTrue(merged.first!.pendingSync, "a stale server copy must be corrected")
    }

    func testRemoteOnlyRecordIsAdopted() {
        let merged = LhSync.merge(local: [], remote: [record("a", updated: 10)])

        XCTAssertEqual(merged.map(\.id), ["a"])
        XCTAssertFalse(merged.first!.pendingSync)
    }

    // MARK: - Tombstones

    func testRemoteTombstoneDeletesLocally() {
        let local = [record("a", updated: 10)]
        let remote = [record("a", updated: 20, deleted: true)]

        let merged = LhSync.merge(local: local, remote: remote)

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(LhSync.visible(merged).isEmpty)
    }

    func testTombstoneSurvivesAnEmptyRemoteInsteadOfResurrecting() {
        let local = [record("a", updated: 10, pending: true, deleted: true)]

        let merged = LhSync.merge(local: local, remote: [])

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(merged.first!.pendingSync)
    }

    // MARK: - Incremental merge

    /// A local record the partial pull did not mention is unchanged, not unpushed.
    func testIncrementalMergeLeavesAQuietLocalRecordAlone() {
        let local = [record("quiet", updated: 10), record("changed", .low, recorded: 100, updated: 10)]
        let remote = [record("changed", .positive, recorded: 100, updated: 20), record("new", recorded: 200, updated: 20)]

        let merged = LhSync.mergeIncremental(local: local, remote: remote)

        XCTAssertEqual(merged.map(\.id), ["quiet", "changed", "new"])
        XCTAssertEqual(merged[0], local[0], "a record absent from a partial pull must be left exactly as it is")
        XCTAssertEqual(merged[1].result.classification, .positive)
        XCTAssertTrue(LhSync.pending(merged).isEmpty, "nothing here is owed to the server")
    }

    func testIncrementalMergeKeepsAnUnpushedLocalEditOverAChangedRemoteRow() {
        let local = [record("a", .positive, updated: 10, pending: true), record("b", updated: 10, pending: true, deleted: true)]
        let remote = [record("a", .low, updated: 99), record("b", updated: 99)]

        let merged = LhSync.mergeIncremental(local: local, remote: remote)

        XCTAssertEqual(merged, local)
    }

    // MARK: - Queue + visibility

    func testPendingReturnsOldestEditFirst() {
        let records = [
            record("new", updated: 30, pending: true),
            record("synced", updated: 20),
            record("old", updated: 10, pending: true),
        ]

        XCTAssertEqual(LhSync.pending(records).map(\.id), ["old", "new"])
    }

    func testVisibleHidesTombstonesAndSortsByRecordedAt() {
        let records = [
            record("late", recorded: 500, updated: 10),
            record("gone", recorded: 100, updated: 10, deleted: true),
            record("early", recorded: 0, updated: 10),
        ]

        XCTAssertEqual(LhSync.visible(records).map(\.id), ["early", "late"])
    }

    func testEmptyHistoryMergesToNothing() {
        XCTAssertTrue(LhSync.merge(local: [], remote: []).isEmpty)
    }
}
