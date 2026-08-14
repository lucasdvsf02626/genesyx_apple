import Foundation

/// A custom supplement plus the bookkeeping the sync layer needs: when the local copy last changed,
/// whether it still owes the server a push, and whether it is a tombstone.
///
/// The tombstone is the part that was missing. Removing an item from a local array is invisible to
/// the server, so the next pull finds a row the device does not have, treats it as new, and puts the
/// supplement back — she deletes it, and it returns. A deletion has to be a fact that travels.
///
/// `pendingSync` is client-only: the server has no use for knowing that *this* device hasn't
/// finished pushing yet.
public struct SupplementRecord: Identifiable, Equatable, Sendable {
    public let supplement: CustomSupplement
    public let updatedAt: Date
    public let pendingSync: Bool
    public let deleted: Bool

    public var id: String { supplement.id }

    public init(supplement: CustomSupplement, updatedAt: Date, pendingSync: Bool, deleted: Bool = false) {
        self.supplement = supplement
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
        self.deleted = deleted
    }

    public func marking(pendingSync: Bool) -> SupplementRecord {
        SupplementRecord(supplement: supplement, updatedAt: updatedAt, pendingSync: pendingSync,
                         deleted: deleted)
    }
}

/// Reconciling the device's supplement list with the cloud's. Pure, so the rules are testable
/// without a network: the device is the source of truth, the cloud is a mirror.
///
/// Deliberately the same rules as `PhSync`, restated rather than shared: the two carry different
/// payloads and different orderings, and a generic over both would be more machinery than the
/// twenty lines it saves. If a third arrives, generalise then.
public enum SupplementSync {

    /// Folds a remote snapshot into the local set.
    ///
    /// - A record with unpushed local edits (`pendingSync`) keeps its local copy, whatever the
    ///   server says.
    /// - Otherwise the later `updatedAt` wins.
    /// - A record the server has never seen is kept and marked pending. This is what carries an
    ///   existing local-only list up to the cloud on first sign-in — the whole migration path for
    ///   everyone who added supplements before this shipped — and what stops an empty cloud table
    ///   from wiping the device.
    /// - A record only the server has is adopted, tombstones included, so a deletion made on her
    ///   Android phone reaches this one.
    public static func merge(local: [SupplementRecord], remote: [SupplementRecord]) -> [SupplementRecord] {
        var byId: [String: SupplementRecord] = [:]
        for record in remote { byId[record.id] = record }

        for mine in local {
            guard let theirs = byId[mine.id] else {
                byId[mine.id] = mine.marking(pendingSync: true)
                continue
            }
            if mine.pendingSync {
                byId[mine.id] = mine
            } else if mine.updatedAt > theirs.updatedAt {
                byId[mine.id] = mine.marking(pendingSync: true)
            } else {
                byId[mine.id] = theirs
            }
        }
        return sorted(Array(byId.values))
    }

    /// Records the server is still owed, oldest edit first.
    public static func pending(_ records: [SupplementRecord]) -> [SupplementRecord] {
        records.filter(\.pendingSync).sorted { ($0.updatedAt, $0.id) < ($1.updatedAt, $1.id) }
    }

    /// What she should actually see: tombstones hidden, in the order they were added.
    public static func visible(_ records: [SupplementRecord]) -> [CustomSupplement] {
        sorted(records.filter { !$0.deleted }).map(\.supplement)
    }

    /// Oldest first, id breaking ties so the list is stable across devices rather than reordering
    /// itself every time it syncs.
    ///
    /// `updatedAt` is insertion order in practice: nothing edits an existing entry — the only
    /// mutation is deletion, and a tombstone is hidden. Should an edit path ever be added, this
    /// becomes "most recently touched last" and will want a `createdAt` of its own.
    private static func sorted(_ records: [SupplementRecord]) -> [SupplementRecord] {
        records.sorted { ($0.updatedAt, $0.id) < ($1.updatedAt, $1.id) }
    }
}
