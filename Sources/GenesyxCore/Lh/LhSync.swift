import Foundation

/// An LH result plus the bookkeeping the sync layer needs: when the local copy last changed,
/// whether it still owes the server a push, and whether it is a tombstone, a deleted result
/// kept on the books so the deletion reaches her other devices instead of being resurrected by
/// the next pull.
///
/// `pendingSync` is deliberately client-only: the server never needs to know that *this* device
/// hasn't finished pushing yet.
public struct LhRecord: Identifiable, Hashable, Sendable {
    public let result: LhResult
    public let updatedAt: Date
    public let pendingSync: Bool
    public let deleted: Bool

    public var id: String { result.id }

    public init(result: LhResult, updatedAt: Date, pendingSync: Bool, deleted: Bool = false) {
        self.result = result
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
        self.deleted = deleted
    }

    public func marking(pendingSync: Bool) -> LhRecord {
        LhRecord(result: result, updatedAt: updatedAt, pendingSync: pendingSync, deleted: deleted)
    }
}

/// Reconciling the device's LH results with the cloud's. Pure, so the rules are testable without
/// a network: the device is the source of truth, the cloud is a mirror.
public enum LhSync {

    /// Folds a remote snapshot into the local set.
    ///
    /// - A record with unpushed local edits (`pendingSync`) keeps its local copy, whatever the
    ///   server says. This is the "never overwrite an unsynced edit" rule.
    /// - Otherwise the later `updatedAt` wins.
    /// - A record the server has never seen is **kept** and marked pending. This is what carries a
    ///   local-only history up to the cloud on first sign-in, and what stops an empty cloud table
    ///   from wiping the device.
    /// - A record only the server has is adopted (including tombstones, so deletions propagate).
    public static func merge(local: [LhRecord], remote: [LhRecord]) -> [LhRecord] {
        var byId: [String: LhRecord] = [:]
        for record in remote { byId[record.id] = record }

        for mine in local {
            guard let theirs = byId[mine.id] else {
                byId[mine.id] = mine.marking(pendingSync: true)   // the server has never seen it
                continue
            }
            if mine.pendingSync {
                byId[mine.id] = mine                             // unpushed edit: local always wins
            } else if mine.updatedAt > theirs.updatedAt {
                byId[mine.id] = mine.marking(pendingSync: true)  // server copy is stale: re-push
            } else {
                byId[mine.id] = theirs
            }
        }
        return sorted(Array(byId.values))
    }

    /// Folds a *partial* remote snapshot into the local set: the rows an incremental sync
    /// returned because they changed since the last cursor, rather than the whole table.
    ///
    /// The per-record resolution is identical to `merge`, but the "a record only the device has is
    /// marked pending" clause is dropped on purpose: with an incremental pull, a local record that
    /// is absent from `remote` means "unchanged since the cursor", not "never pushed", so it is
    /// left exactly as it is. Feeding a subset to `merge` would instead re-flag every quiet record
    /// as owed and re-push the entire history on every launch, which is the opposite of the point.
    public static func mergeIncremental(local: [LhRecord], remote: [LhRecord]) -> [LhRecord] {
        var byId = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for theirs in remote {
            guard let mine = byId[theirs.id] else {
                byId[theirs.id] = theirs                             // new or changed on the server
                continue
            }
            if mine.pendingSync {
                continue                                             // unpushed local edit: local wins
            } else if mine.updatedAt > theirs.updatedAt {
                byId[theirs.id] = mine.marking(pendingSync: true)    // server copy is stale: re-push
            } else {
                byId[theirs.id] = theirs
            }
        }
        return sorted(Array(byId.values))
    }

    /// Records the server is still owed, oldest edit first.
    public static func pending(_ records: [LhRecord]) -> [LhRecord] {
        records.filter(\.pendingSync).sorted { ($0.updatedAt, $0.id) < ($1.updatedAt, $1.id) }
    }

    /// What she should actually see: tombstones hidden, oldest result first.
    public static func visible(_ records: [LhRecord]) -> [LhResult] {
        sorted(records.filter { !$0.deleted }).map(\.result)
    }

    /// Ordered by test time, id breaking ties so the result is stable.
    private static func sorted(_ records: [LhRecord]) -> [LhRecord] {
        records.sorted { ($0.result.recordedAt, $0.id) < ($1.result.recordedAt, $1.id) }
    }
}
