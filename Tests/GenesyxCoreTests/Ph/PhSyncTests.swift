import XCTest
@testable import GenesyxCore

final class PhSyncTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(_ id: String, ph: Double = 6.5, recorded: Double = 0, updated: Double,
                        pending: Bool = false, deleted: Bool = false) -> PhRecord {
        PhRecord(
            reading: PhReading(id: id, phValue: ph, recordedAt: t0.addingTimeInterval(recorded)),
            updatedAt: t0.addingTimeInterval(updated),
            pendingSync: pending,
            deleted: deleted
        )
    }

    // MARK: - The data-loss case

    /// An empty cloud must never wipe the device — the local history is kept and queued for push.
    func testEmptyRemoteKeepsLocalHistoryAndQueuesIt() {
        let local = [record("a", updated: 10), record("b", updated: 20)]

        let merged = PhSync.merge(local: local, remote: [])

        XCTAssertEqual(merged.map(\.id), ["a", "b"])
        XCTAssertTrue(merged.allSatisfy(\.pendingSync), "local-only records must be queued for push")
    }

    // MARK: - Conflict resolution

    func testUnpushedLocalEditBeatsNewerRemote() {
        let local = [record("a", ph: 7.0, updated: 10, pending: true)]
        let remote = [record("a", ph: 6.0, updated: 99)]

        let merged = PhSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.reading.phValue, 7.0)
        XCTAssertTrue(merged.first!.pendingSync)
    }

    func testNewerRemoteWinsOverSyncedLocal() {
        let local = [record("a", ph: 6.0, updated: 10)]
        let remote = [record("a", ph: 7.0, updated: 20)]

        let merged = PhSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.reading.phValue, 7.0)
        XCTAssertFalse(merged.first!.pendingSync)
    }

    func testStaleRemoteLosesToNewerLocalAndIsRequeued() {
        let local = [record("a", ph: 7.0, updated: 30)]
        let remote = [record("a", ph: 6.0, updated: 20)]

        let merged = PhSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.reading.phValue, 7.0)
        XCTAssertTrue(merged.first!.pendingSync, "a stale server copy must be corrected")
    }

    func testRemoteOnlyRecordIsAdopted() {
        let merged = PhSync.merge(local: [], remote: [record("a", updated: 10)])

        XCTAssertEqual(merged.map(\.id), ["a"])
        XCTAssertFalse(merged.first!.pendingSync)
    }

    // MARK: - Tombstones

    func testRemoteTombstoneDeletesLocally() {
        let local = [record("a", updated: 10)]
        let remote = [record("a", updated: 20, deleted: true)]

        let merged = PhSync.merge(local: local, remote: remote)

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(PhSync.visible(merged).isEmpty)
    }

    func testTombstoneSurvivesAnEmptyRemoteInsteadOfResurrecting() {
        let local = [record("a", updated: 10, pending: true, deleted: true)]

        let merged = PhSync.merge(local: local, remote: [])

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(merged.first!.pendingSync)
    }

    // MARK: - Queue + visibility

    func testPendingReturnsOldestEditFirst() {
        let records = [
            record("new", updated: 30, pending: true),
            record("synced", updated: 20),
            record("old", updated: 10, pending: true),
        ]

        XCTAssertEqual(PhSync.pending(records).map(\.id), ["old", "new"])
    }

    func testVisibleHidesTombstonesAndSortsByRecordedAt() {
        let records = [
            record("late", recorded: 500, updated: 10),
            record("gone", recorded: 100, updated: 10, deleted: true),
            record("early", recorded: 0, updated: 10),
        ]

        XCTAssertEqual(PhSync.visible(records).map(\.id), ["early", "late"])
    }

    func testEmptyHistoryMergesToNothing() {
        XCTAssertTrue(PhSync.merge(local: [], remote: []).isEmpty)
    }
}
