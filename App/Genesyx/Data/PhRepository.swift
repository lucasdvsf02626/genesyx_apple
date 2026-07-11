import Foundation
import GenesyxCore

/// Urine-pH readings. Local-first, ordered by `recordedAt` ascending; pH rounded to 1 dp on write
/// (web `round(v*10)/10`). Mirrors the Android `PhRepository`.
///
/// The device is the source of truth. Every write is saved locally first and then queued for the
/// backend: a push that fails (offline, signed out, server down) leaves the record marked
/// `pendingSync` and is retried on the next `refresh` or app foreground — it is never dropped.
/// `refresh` MERGES the remote snapshot into the local set (`PhSync.merge`) rather than replacing
/// it, so an empty or stale cloud can't wipe her history. Deletes are tombstones so they reach her
/// other devices instead of being resurrected by the next pull.
@MainActor
final class PhRepository: ObservableObject {

    /// What the UI sees: tombstones hidden, oldest first.
    @Published private(set) var readings: [PhReading] = []

    private var records: [PhRecord] = [] {
        didSet { readings = PhSync.visible(records) }
    }

    private let store: LocalStore
    private let backend: PhBackend?
    private let key = "ph_readings"

    init(store: LocalStore, backend: PhBackend? = nil) {
        self.store = store
        self.backend = backend
        if let stored = store.load([PhReadingDTO].self, forKey: key) {
            records = stored.map(\.record)
            readings = PhSync.visible(records)
        }
    }

    private func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    func create(_ reading: PhReading) {
        let normalized = PhReading(id: reading.id, phValue: round1(reading.phValue), recordedAt: reading.recordedAt, notes: reading.notes)
        save(PhRecord(reading: normalized, updatedAt: Date(), pendingSync: true))
    }

    func update(_ reading: PhReading) {
        let normalized = PhReading(id: reading.id, phValue: round1(reading.phValue), recordedAt: reading.recordedAt, notes: reading.notes)
        save(PhRecord(reading: normalized, updatedAt: Date(), pendingSync: true))
    }

    /// Tombstone, not a removal — the deletion has to survive the next pull and reach her other
    /// devices. `PhSync.visible` hides it from the UI immediately.
    func delete(id: String) {
        guard let existing = records.first(where: { $0.id == id }) else { return }
        save(PhRecord(reading: existing.reading, updatedAt: Date(), pendingSync: true, deleted: true))
    }

    /// Merge the remote snapshot into the local set, then push anything the server is still owed.
    /// A failed fetch still drains the queue (that's the retry path). No-op when local-only.
    func refresh() async {
        guard let backend else { return }
        if let remote = try? await backend.list(sinceDays: nil) {
            records = PhSync.merge(local: records, remote: remote)
            persist()
        }
        await drainPending()
    }

    /// Push every record the server is still owed, oldest edit first. Stops at the first failure —
    /// if one push fails we're almost certainly offline, so the rest stay queued for next time.
    /// Called on launch/sign-in (via `refresh`) and on app foreground.
    func drainPending() async {
        guard let backend else { return }
        for record in PhSync.pending(records) {
            do {
                try await backend.upsert(record)
                clearPending(record)
            } catch {
                break
            }
        }
        persist()
    }

    /// Order doesn't matter here — `PhSync.visible` sorts for the UI and `PhSync.pending` sorts
    /// the queue.
    private func save(_ record: PhRecord) {
        records = records.filter { $0.id != record.id } + [record]
        persist()
        push(record)
    }

    private func push(_ record: PhRecord) {
        guard let backend else { return }
        Task {
            guard (try? await backend.upsert(record)) != nil else { return }   // stays queued on failure
            clearPending(record)
            persist()
        }
    }

    /// Clear the queue flag, but only if the record hasn't been edited again while the push was in
    /// flight — otherwise we'd mark a newer local edit as synced and lose it.
    private func clearPending(_ pushed: PhRecord) {
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
        store.remove(forKey: key)
    }
}
