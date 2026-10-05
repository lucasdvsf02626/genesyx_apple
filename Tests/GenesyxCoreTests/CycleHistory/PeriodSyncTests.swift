import XCTest
@testable import GenesyxCore

/// Shared builders for the cycle history tests.
enum PeriodFixture {
    static let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    static func stored(
        _ start: CalendarDate,
        end: CalendarDate? = nil,
        source: PeriodSource = .recorded,
        updated: Double = 0,
        pending: Bool = false,
        deleted: Bool = false
    ) -> StoredPeriodRecord {
        StoredPeriodRecord(
            period: PeriodRecord(startDate: start, endDate: end, source: source),
            updatedAt: t0.addingTimeInterval(updated),
            pendingSync: pending,
            deleted: deleted
        )
    }
}

final class PeriodSyncTests: XCTestCase {

    private let mar3 = CalendarDate(2026, 3, 3)
    private let apr1 = CalendarDate(2026, 4, 1)

    private func stored(_ start: CalendarDate, end: CalendarDate? = nil, source: PeriodSource = .recorded,
                        updated: Double, pending: Bool = false, deleted: Bool = false) -> StoredPeriodRecord {
        PeriodFixture.stored(start, end: end, source: source, updated: updated, pending: pending, deleted: deleted)
    }

    // MARK: - Identity

    func testIdentityIsTheStartDate() {
        XCTAssertEqual(PeriodRecord(startDate: mar3).id, mar3)
        XCTAssertEqual(stored(mar3, updated: 0).id, mar3)
    }

    /// Two offline devices that both record the same start end up with one record, not two.
    func testSameStartFromTwoDevicesCollapsesToOne() {
        let local = [stored(mar3, updated: 10, pending: true)]
        let remote = [stored(mar3, updated: 12)]

        let merged = PeriodSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(CycleHistory.cycles(from: merged).count, 1)
    }

    func testSameStartCollapsesOnIncrementalMergeToo() {
        let merged = PeriodSync.mergeIncremental(local: [stored(mar3, updated: 10)], remote: [stored(mar3, updated: 12)])

        XCTAssertEqual(merged.count, 1)
    }

    // MARK: - The data-loss case

    func testEmptyRemoteKeepsLocalHistoryAndQueuesIt() {
        let local = [stored(mar3, updated: 10), stored(apr1, updated: 20)]

        let merged = PeriodSync.merge(local: local, remote: [])

        XCTAssertEqual(merged.map(\.id), [mar3, apr1])
        XCTAssertTrue(merged.allSatisfy(\.pendingSync), "local-only records must be queued for push")
    }

    // MARK: - Conflict resolution

    func testPendingLocalSurvivesAStaleRemote() {
        let local = [stored(mar3, end: CalendarDate(2026, 3, 7), updated: 30, pending: true)]
        let remote = [stored(mar3, updated: 20)]

        let merged = PeriodSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.period.endDate, CalendarDate(2026, 3, 7))
        XCTAssertTrue(merged.first!.pendingSync)
    }

    func testPendingLocalBeatsNewerRemote() {
        let local = [stored(mar3, end: CalendarDate(2026, 3, 7), updated: 10, pending: true)]
        let remote = [stored(mar3, updated: 99)]

        XCTAssertEqual(PeriodSync.merge(local: local, remote: remote).first?.period.endDate, CalendarDate(2026, 3, 7))
        XCTAssertEqual(PeriodSync.mergeIncremental(local: local, remote: remote).first?.period.endDate,
                       CalendarDate(2026, 3, 7))
    }

    func testNewerRemoteWinsOverSyncedLocal() {
        let local = [stored(mar3, updated: 10)]
        let remote = [stored(mar3, end: CalendarDate(2026, 3, 6), updated: 20)]

        let merged = PeriodSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.period.endDate, CalendarDate(2026, 3, 6))
        XCTAssertFalse(merged.first!.pendingSync)
    }

    func testStaleRemoteLosesToNewerSyncedLocalAndIsRequeued() {
        let local = [stored(mar3, end: CalendarDate(2026, 3, 6), updated: 30)]
        let remote = [stored(mar3, updated: 20)]

        let merged = PeriodSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.period.endDate, CalendarDate(2026, 3, 6))
        XCTAssertTrue(merged.first!.pendingSync, "a stale server copy must be corrected")
    }

    func testRemoteOnlyRecordIsAdopted() {
        let merged = PeriodSync.merge(local: [], remote: [stored(mar3, updated: 5)])

        XCTAssertEqual(merged.map(\.id), [mar3])
        XCTAssertFalse(merged.first!.pendingSync)
    }

    // MARK: - Tombstones (the LhSync rule: no priority of their own)

    func testNewerRemoteTombstoneWinsOverSyncedLocal() {
        let merged = PeriodSync.merge(local: [stored(mar3, updated: 10)],
                                      remote: [stored(mar3, updated: 20, deleted: true)])

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(PeriodSync.visible(merged).isEmpty)
    }

    func testOlderRemoteTombstoneLosesToNewerSyncedLocal() {
        let merged = PeriodSync.merge(local: [stored(mar3, updated: 30)],
                                      remote: [stored(mar3, updated: 20, deleted: true)])

        XCTAssertFalse(merged.first!.deleted)
        XCTAssertTrue(merged.first!.pendingSync)
    }

    func testPendingLocalTombstoneBeatsNewerRemoteRecord() {
        let merged = PeriodSync.merge(local: [stored(mar3, updated: 10, pending: true, deleted: true)],
                                      remote: [stored(mar3, updated: 99)])

        XCTAssertTrue(merged.first!.deleted, "an unpushed deletion must not be resurrected by a pull")
    }

    func testPendingLocalRecordBeatsNewerRemoteTombstone() {
        let merged = PeriodSync.merge(local: [stored(mar3, updated: 10, pending: true)],
                                      remote: [stored(mar3, updated: 99, deleted: true)])

        XCTAssertFalse(merged.first!.deleted)
    }

    // MARK: - Incremental

    /// A quiet local record absent from a partial pull is unchanged, not owed.
    func testIncrementalLeavesAbsentLocalRecordsExactlyAsTheyAre() {
        let local = [stored(mar3, updated: 10), stored(apr1, updated: 20)]

        let merged = PeriodSync.mergeIncremental(local: local, remote: [])

        XCTAssertEqual(merged, local)
    }

    func testIncrementalAdoptsNewAndNewerRemoteRows() {
        let local = [stored(mar3, updated: 10)]
        let remote = [stored(mar3, end: CalendarDate(2026, 3, 5), updated: 20), stored(apr1, updated: 20)]

        let merged = PeriodSync.mergeIncremental(local: local, remote: remote)

        XCTAssertEqual(merged.map(\.id), [mar3, apr1])
        XCTAssertEqual(merged.first?.period.endDate, CalendarDate(2026, 3, 5))
        XCTAssertFalse(merged.contains(where: \.pendingSync))
    }

    func testIncrementalRequeuesANewerSyncedLocal() {
        let merged = PeriodSync.mergeIncremental(local: [stored(mar3, updated: 30)], remote: [stored(mar3, updated: 20)])

        XCTAssertTrue(merged.first!.pendingSync)
    }

    // MARK: - Pending and visible

    func testPendingIsOldestEditFirst() {
        let records = [
            stored(apr1, updated: 5, pending: true),
            stored(mar3, updated: 9, pending: true),
            stored(CalendarDate(2026, 5, 1), updated: 1),
        ]

        XCTAssertEqual(PeriodSync.pending(records).map(\.id), [apr1, mar3])
    }

    func testVisibleHidesTombstonesAndSortsByStart() {
        let records = [
            stored(apr1, updated: 1),
            stored(CalendarDate(2026, 2, 1), updated: 1, deleted: true),
            stored(mar3, updated: 1),
        ]

        XCTAssertEqual(PeriodSync.visible(records).map(\.startDate), [mar3, apr1])
    }
}
