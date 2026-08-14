import XCTest
@testable import GenesyxCore

final class SupplementSyncTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(_ id: String, name: String = "Magnesium", updated: Double,
                        pending: Bool = false, deleted: Bool = false) -> SupplementRecord {
        SupplementRecord(
            supplement: CustomSupplement(id: id, name: name, dose: "200 mg", timeOfDay: .evening),
            updatedAt: t0.addingTimeInterval(updated),
            pendingSync: pending,
            deleted: deleted
        )
    }

    // MARK: - The data-loss case this whole file exists for

    /// The list she already has must never be replaced by an empty server. Before the sync existed
    /// the supplements were local-only, so on first sign-in EVERY user has a full device and an
    /// empty `user_supplements` — if that pull won, the feature would launch by deleting her list.
    func testAnEmptyCloudKeepsHerListAndQueuesItForUpload() {
        let local = [record("a", updated: 10), record("b", updated: 20)]

        let merged = SupplementSync.merge(local: local, remote: [])

        XCTAssertEqual(merged.map(\.id), ["a", "b"])
        XCTAssertTrue(merged.allSatisfy(\.pendingSync), "a local-only list must be queued for push")
    }

    /// The other half of the same story: her Android phone already has the list, this iPhone is
    /// fresh. The rows are adopted as already-synced — re-pushing what the server just gave us
    /// would be pointless traffic.
    func testAListThatOnlyExistsOnTheServerIsAdoptedWithoutBeingPushedBack() {
        let merged = SupplementSync.merge(local: [], remote: [record("a", updated: 10)])

        XCTAssertEqual(merged.map(\.id), ["a"])
        XCTAssertFalse(merged.first!.pendingSync)
    }

    // MARK: - Conflict resolution

    func testAnUnpushedLocalChangeBeatsANewerServerCopy() {
        let local = [record("a", name: "Magnesium glycinate", updated: 10, pending: true)]
        let remote = [record("a", name: "Magnesium", updated: 99)]

        let merged = SupplementSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.supplement.name, "Magnesium glycinate")
        XCTAssertTrue(merged.first!.pendingSync)
    }

    func testANewerServerCopyWinsOverASyncedLocalOne() {
        let local = [record("a", name: "Old", updated: 10)]
        let remote = [record("a", name: "New", updated: 20)]

        let merged = SupplementSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.supplement.name, "New")
        XCTAssertFalse(merged.first!.pendingSync)
    }

    func testAStaleServerCopyLosesAndIsRequeuedForCorrection() {
        let local = [record("a", name: "New", updated: 30)]
        let remote = [record("a", name: "Old", updated: 20)]

        let merged = SupplementSync.merge(local: local, remote: remote)

        XCTAssertEqual(merged.first?.supplement.name, "New")
        XCTAssertTrue(merged.first!.pendingSync, "a server copy known to be stale must be corrected")
    }

    // MARK: - Tombstones

    /// Deleting on her Android phone has to reach this one. It arrives as a tombstone rather than as
    /// an absence, because an absence is indistinguishable from "this device never pushed it".
    func testADeletionMadeOnAnotherDeviceRemovesItHere() {
        let local = [record("a", updated: 10)]
        let remote = [record("a", updated: 20, deleted: true)]

        let merged = SupplementSync.merge(local: local, remote: remote)

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(SupplementSync.visible(merged).isEmpty)
    }

    /// The resurrection bug, stated as a test. She deletes a supplement while offline; the pull
    /// finds the row still on the server. If the tombstone did not survive the merge, the delete
    /// would silently undo itself.
    func testADeleteMadeOfflineSurvivesTheNextPullInsteadOfComingBack() {
        let local = [record("a", updated: 30, pending: true, deleted: true)]
        let remote = [record("a", updated: 20)]

        let merged = SupplementSync.merge(local: local, remote: remote)

        XCTAssertTrue(merged.first!.deleted)
        XCTAssertTrue(merged.first!.pendingSync, "the server still owes this deletion")
        XCTAssertTrue(SupplementSync.visible(merged).isEmpty)
    }

    // MARK: - Queue + what she sees

    func testTheQueueDrainsOldestFirst() {
        let records = [
            record("new", updated: 30, pending: true),
            record("synced", updated: 20),
            record("old", updated: 10, pending: true),
        ]

        XCTAssertEqual(SupplementSync.pending(records).map(\.id), ["old", "new"])
    }

    /// Tombstones are hidden, and the order is the order she added them — not the arbitrary order a
    /// dictionary-keyed merge happens to produce.
    func testVisibleHidesTombstonesAndKeepsTheOrderSheAddedThemIn() {
        let records = [
            record("third", updated: 30),
            record("gone", updated: 20, deleted: true),
            record("first", updated: 10),
        ]

        XCTAssertEqual(SupplementSync.visible(records).map(\.id), ["first", "third"])
    }

    /// Two supplements added in the same second must not swap places between one sync and the next.
    func testIdBreaksTiesSoTheListDoesNotReshuffleItself() {
        let records = [record("b", updated: 10), record("a", updated: 10)]

        XCTAssertEqual(SupplementSync.visible(records).map(\.id), ["a", "b"])
        XCTAssertEqual(SupplementSync.visible(records.reversed()).map(\.id), ["a", "b"])
    }

    func testNothingOnEitherSideMergesToNothing() {
        XCTAssertTrue(SupplementSync.merge(local: [], remote: []).isEmpty)
    }
}
