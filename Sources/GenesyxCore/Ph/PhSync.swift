import Foundation

/// A pH reading plus the bookkeeping the sync layer needs: when the local copy last changed,
/// whether it still owes the server a push, and whether it is a tombstone — a deleted reading
/// kept on the books so the deletion reaches her other devices instead of being resurrected by
/// the next pull.
///
/// `pendingSync` is deliberately client-only: the server never needs to know that *this* device
/// hasn't finished pushing yet.
public struct PhRecord: Identifiable, Hashable, Sendable {
    public let reading: PhReading
    public let updatedAt: Date
    public let pendingSync: Bool
    public let deleted: Bool

    public var id: String { reading.id }

    public init(reading: PhReading, updatedAt: Date, pendingSync: Bool, deleted: Bool = false) {
        self.reading = reading
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
        self.deleted = deleted
    }

    public func marking(pendingSync: Bool) -> PhRecord {
        PhRecord(reading: reading, updatedAt: updatedAt, pendingSync: pendingSync, deleted: deleted)
    }
}

/// Reconciling the device's pH history with the cloud's. Pure, so the rules are testable without
/// a network: the device is the source of truth, the cloud is a mirror.
public enum PhSync {

    /// Folds a remote snapshot into the local set.
    ///
    /// - A record with unpushed local edits (`pendingSync`) keeps its local copy, whatever the
    ///   server says. This is the "never overwrite an unsynced edit" rule.
    /// - Otherwise the later `updatedAt` wins.
    /// - A record the server has never seen is **kept** and marked pending. This is what carries a
    ///   local-only history up to the cloud on first sign-in — and what stops an empty cloud table
    ///   from wiping the device.
    /// - A record only the server has is adopted (including tombstones, so deletions propagate).
    public static func merge(local: [PhRecord], remote: [PhRecord]) -> [PhRecord] {
        var byId: [String: PhRecord] = [:]
        for record in remote { byId[record.id] = record }

        for mine in local {
            guard let theirs = byId[mine.id] else {
                byId[mine.id] = mine.marking(pendingSync: true)   // the server has never seen it
                continue
            }
            if mine.pendingSync {
                byId[mine.id] = mine                             // unpushed edit: local always wins
            } else if mine.updatedAt > theirs.updatedAt {
                byId[mine.id] = mine.marking(pendingSync: true)  // server copy is stale — re-push
            } else {
                byId[mine.id] = theirs
            }
        }
        return sorted(Array(byId.values))
    }

    /// Records the server is still owed, oldest edit first.
    public static func pending(_ records: [PhRecord]) -> [PhRecord] {
        records.filter(\.pendingSync).sorted { ($0.updatedAt, $0.id) < ($1.updatedAt, $1.id) }
    }

    /// What she should actually see: tombstones hidden, oldest reading first.
    public static func visible(_ records: [PhRecord]) -> [PhReading] {
        sorted(records.filter { !$0.deleted }).map(\.reading)
    }

    /// Ordered by reading time, id breaking ties so the result is stable.
    private static func sorted(_ records: [PhRecord]) -> [PhRecord] {
        records.sorted { ($0.reading.recordedAt, $0.id) < ($1.reading.recordedAt, $1.id) }
    }
}
