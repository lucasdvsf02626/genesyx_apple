import Foundation
import GenesyxCore

/// Ovulation (LH) test results. Local-first, ordered by `recordedAt` ascending. A copy of
/// `PhRepository`, with one difference in kind: a result is immutable, so there is `create` and
/// `delete` and no `update`.
///
/// The device is the source of truth. Every write is saved locally first and then queued for the
/// backend: a push that fails (offline, signed out, server down, table not there yet) leaves the
/// record marked `pendingSync` and is retried on the next `refresh` or app foreground. It is never
/// dropped. `refresh` MERGES the remote snapshot into the local set (`LhSync.merge`) rather than
/// replacing it, so an empty or stale cloud can't wipe her history. Deletes are tombstones so they
/// reach her other devices instead of being resurrected by the next pull.
@MainActor
final class LhRepository: ObservableObject {

    /// What the UI sees: tombstones hidden, oldest first.
    @Published private(set) var results: [LhResult] = []

    private var records: [LhRecord] = [] {
        didSet { results = LhSync.visible(records) }
    }

    /// Guards new results only. `delete` is deliberately outside it: erasing what she already
    /// recorded is Article 17 and must stay available after a withdrawal.
    var isCollectionPermitted: HealthDataCollectionGate = { true }

    private let store: LocalStore
    private let backend: LhBackend?
    private let key = "lh_results"
    private let cursorKey = "lh_results_cursor"
    /// Overlap subtracted from the cursor on each pull, to absorb clock skew against the server that
    /// stamps `updated_at`.
    private static let cursorOverlap: TimeInterval = 60

    /// The server's stamp from the last successful pull. Nil until the first one, which is what
    /// makes that first sync a full-history fetch.
    private var lastSyncedAt: Date? {
        didSet {
            if let date = lastSyncedAt { store.save(date, forKey: cursorKey) } else { store.remove(forKey: cursorKey) }
        }
    }

    init(store: LocalStore, backend: LhBackend? = nil) {
        self.store = store
        self.backend = backend
        self.lastSyncedAt = store.load(Date.self, forKey: cursorKey)
        if let stored = store.load([LhResultDTO].self, forKey: key) {
            // An entry whose classification this build does not know is dropped, never guessed.
            records = stored.compactMap(\.record)
            results = LhSync.visible(records)
        }
    }

    /// **Returns false when the write was refused.** The caller must not report success on a false.
    /// Refused when the consent gate says no, and for an unreadable scan, which is never a record.
    @discardableResult
    func create(_ result: LhResult) -> Bool {
        guard isCollectionPermitted() else { return false }
        if result.classification == .unreadable { return false }
        save(LhRecord(result: result, updatedAt: Date(), pendingSync: true))
        return true
    }

    /// Tombstone, not a removal: the deletion has to survive the next pull and reach her other
    /// devices. `LhSync.visible` hides it from the UI immediately.
    func delete(id: String) {
        guard let existing = records.first(where: { $0.id == id }) else { return }
        save(LhRecord(result: existing.result, updatedAt: Date(), pendingSync: true, deleted: true))
    }

    /// Merge the remote snapshot into the local set, then push anything the server is still owed.
    /// A failed fetch still drains the queue (that's the retry path). No-op when local-only.
    ///
    /// The pull is gated on consent like the writes are. Results already on the device stay
    /// visible: withdrawal stops collection, it is not erasure. The drain still runs, and must:
    /// it is what carries her *deletions* to her other devices.
    func refresh() async {
        guard let backend else { return }
        if isCollectionPermitted() {
            let since = lastSyncedAt.map { $0.addingTimeInterval(-Self.cursorOverlap) }
            if let page = try? await backend.list(updatedSince: since) {
                // The first (full) pull uses `merge`, which carries a local-only history up on
                // first sign-in. An incremental pull returns only changed rows, so it must NOT
                // treat the quiet ones as unknown.
                let remote = page.payload
                records = since == nil
                    ? LhSync.merge(local: records, remote: remote)
                    : LhSync.mergeIncremental(local: records, remote: remote)
                persist()
                // Only ever forward, and only onto ground the server named. A nil page cursor
                // (nothing returned, or a stamp that would not parse) leaves the cursor where it
                // was, so the next pull asks from the same point rather than stepping over a row.
                if let cursor = page.latestUpdatedAt, cursor > (lastSyncedAt ?? .distantPast) {
                    lastSyncedAt = cursor
                }
                #if DEBUG
                print("[Sync] lh_results: \(remote.count) rows (\(since == nil ? "full" : "incremental"))")
                #endif
            }
        }
        await drainPending()
    }

    /// Push every record the server is still owed, oldest edit first. A failure of the connection
    /// (offline, or no session yet) is the same answer for every record behind it, so we stop and
    /// leave the queue for next time. A server-side rejection is specific to that one record:
    /// stepping over it keeps a single refused row from starving every newer result behind it.
    func drainPending() async {
        guard let backend else { return }
        for record in LhSync.pending(records) {
            do {
                try await backend.upsert(record)
                clearPending(record)
            } catch {
                if SyncError.shouldHaltDrain(error) { break }
                continue
            }
        }
        persist()
    }

    /// Order doesn't matter here: `LhSync.visible` sorts for the UI and `LhSync.pending` sorts
    /// the queue.
    private func save(_ record: LhRecord) {
        records = records.filter { $0.id != record.id } + [record]
        persist()
        push(record)
    }

    private func push(_ record: LhRecord) {
        guard let backend else { return }
        Task {
            guard (try? await backend.upsert(record)) != nil else { return }   // stays queued on failure
            clearPending(record)
            persist()
        }
    }

    /// Clear the queue flag, but only if the record hasn't changed again while the push was in
    /// flight (a delete made mid-push must stay owed).
    private func clearPending(_ pushed: LhRecord) {
        records = records.map { current in
            current.id == pushed.id && current.updatedAt == pushed.updatedAt
                ? current.marking(pendingSync: false)
                : current
        }
    }

    private func persist() {
        store.save(records.map(\.dto), forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        records = []
        lastSyncedAt = nil          // next account starts from a full history fetch, not this one's cursor
        store.remove(forKey: key)
    }
}
