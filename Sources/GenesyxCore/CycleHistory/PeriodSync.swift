import Foundation

/// A period record plus the bookkeeping the sync layer needs: when the local copy last changed,
/// whether it still owes the server a push, and whether it is a tombstone, a deleted record kept
/// on the books so the deletion reaches her other devices instead of being resurrected by the
/// next pull.
///
/// `pendingSync` is deliberately client-only, as it is for `LhRecord`.
public struct StoredPeriodRecord: Identifiable, Hashable, Sendable {
    public let period: PeriodRecord
    public let updatedAt: Date
    public let pendingSync: Bool
    public let deleted: Bool

    /// The start date: the same key the server uses, together with the user.
    public var id: CalendarDate { period.startDate }

    public init(period: PeriodRecord, updatedAt: Date, pendingSync: Bool, deleted: Bool = false) {
        self.period = period
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
        self.deleted = deleted
    }

    public func marking(pendingSync: Bool) -> StoredPeriodRecord {
        StoredPeriodRecord(period: period, updatedAt: updatedAt, pendingSync: pendingSync, deleted: deleted)
    }
}

/// Reconciling the device's period records with the cloud's. The rules are `LhSync`'s, keyed by
/// start date instead of a random id: the device is the source of truth, the cloud is a mirror.
///
/// A tombstone is an ordinary record here, exactly as in `LhSync`: it wins or loses by the same
/// `pendingSync` then `updatedAt` rule as any other edit, with no priority of its own.
public enum PeriodSync {

    /// Folds a remote snapshot into the local set.
    ///
    /// - A record with unpushed local edits (`pendingSync`) keeps its local copy, whatever the
    ///   server says.
    /// - Otherwise the later `updatedAt` wins.
    /// - A record the server has never seen is **kept** and marked pending, so an empty cloud
    ///   table never wipes the device.
    /// - A record only the server has is adopted (including tombstones, so deletions propagate).
    ///
    /// The same start recorded on two devices is one key, so it collapses to one record.
    public static func merge(local: [StoredPeriodRecord], remote: [StoredPeriodRecord]) -> [StoredPeriodRecord] {
        var byId: [CalendarDate: StoredPeriodRecord] = [:]
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
    /// returned because they changed since the last cursor. Per-record resolution is identical to
    /// `merge`, but a local record absent from `remote` means it has not changed since the cursor, so it
    /// is left exactly as it is instead of being re-flagged as owed.
    public static func mergeIncremental(local: [StoredPeriodRecord], remote: [StoredPeriodRecord]) -> [StoredPeriodRecord] {
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
    public static func pending(_ records: [StoredPeriodRecord]) -> [StoredPeriodRecord] {
        records.filter(\.pendingSync).sorted { ($0.updatedAt, $0.id) < ($1.updatedAt, $1.id) }
    }

    /// The periods that count: tombstones hidden, earliest start first.
    public static func visible(_ records: [StoredPeriodRecord]) -> [PeriodRecord] {
        sorted(records.filter { !$0.deleted }).map(\.period)
    }

    /// Ordered by start date, which is unique, so the result is stable.
    static func sorted(_ records: [StoredPeriodRecord]) -> [StoredPeriodRecord] {
        records.sorted { $0.id < $1.id }
    }
}
