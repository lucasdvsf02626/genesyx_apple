import Foundation
import GenesyxCore

/// The supplements she added herself. Local-first, then carried up to her `user_supplements` row —
/// the same table Android has read and written since 13 Aug 2026.
///
/// This is the last thing in the app that never left the phone. Everything else she records — her
/// cycle, her logs, her pH readings, her preferences, her name — is written locally and then owed to
/// the server until it lands. Custom supplements were `@AppStorage` JSON and nothing more, so a
/// reinstall lost them and the same account showed two different lists on her two phones with
/// neither device aware of the other.
///
/// Same contract as `PhRepository`, which is the closest shape: the device is the source of truth, a
/// failed push stays owed and is retried, `refresh` MERGES rather than replaces so an empty cloud
/// cannot wipe her list, and a delete is a tombstone so it reaches her other devices instead of
/// being resurrected by the next pull.
@MainActor
final class SupplementsRepository: ObservableObject {

    /// What the UI sees: tombstones hidden, in the order she added them.
    @Published private(set) var supplements: [CustomSupplement] = []

    /// Guards `add` only. `delete` stays available after a withdrawal, as it does for pH readings.
    var isCollectionPermitted: HealthDataCollectionGate = { true }

    private var records: [SupplementRecord] = [] {
        didSet { supplements = SupplementSync.visible(records) }
    }

    private let store: LocalStore
    private let backend: SupplementBackend?

    private let recordsKey = "custom_supplement_records"

    /// Where the list lived before it had any sync bookkeeping: a bare JSON array written by
    /// `@AppStorage`, which is **unprefixed `UserDefaults.standard`** — not `LocalStore`, which
    /// namespaces everything it writes under `genesyx.`. Reading it through the store would find
    /// nothing and quietly discard every supplement on the device.
    private let legacyDefaults: UserDefaults

    init(store: LocalStore, backend: SupplementBackend? = nil,
         legacyDefaults: UserDefaults = .standard) {
        self.store = store
        self.backend = backend
        self.legacyDefaults = legacyDefaults
        records = Self.loadRecords(store: store, recordsKey: recordsKey, legacyDefaults: legacyDefaults)
        supplements = SupplementSync.visible(records)
    }

    /// Reads the sync-aware store, falling back to the plain list this replaced.
    ///
    /// The fallback is the migration, and it is the only chance it gets: everyone who added a
    /// supplement before this shipped has a bare JSON array under the old key and no record of when
    /// any of it was added. Adopting it as pending is what pushes it up on her next sign-in, which
    /// is the difference between "her list arrives on her new phone" and "her list is silently
    /// replaced by an empty server". The old key is left in place rather than deleted — it costs
    /// nothing, and it is the only copy if a downgrade ever happens.
    private static func loadRecords(store: LocalStore, recordsKey: String,
                                    legacyDefaults: UserDefaults) -> [SupplementRecord] {
        if let stored = store.load([SupplementRecordDTO].self, forKey: recordsKey) {
            return stored.map(\.record)
        }
        let legacy = CustomSupplement.decodeList(
            legacyDefaults.string(forKey: CustomSupplement.storageKey) ?? "[]")
        guard !legacy.isEmpty else { return [] }
        // One timestamp for the lot, spaced so the original order survives the sort.
        let base = Date(timeIntervalSince1970: 0)
        return legacy.enumerated().map { index, item in
            SupplementRecord(supplement: item, updatedAt: base.addingTimeInterval(Double(index)),
                             pendingSync: true)
        }
    }

    /// Add one. Invalid names are refused here rather than sent — the server's
    /// `char_length(btrim(name)) between 1 and 60` would reject the row, and a rejected row sits in
    /// the queue retrying a write that can never succeed.
    @discardableResult
    func add(_ supplement: CustomSupplement) -> Bool {
        guard isCollectionPermitted(), supplement.isValid else { return false }
        save(SupplementRecord(supplement: supplement, updatedAt: Date(), pendingSync: true))
        return true
    }

    /// Tombstone, not a removal. Dropping it from the array is invisible to the server: the next
    /// pull finds a row this device does not have, treats it as new, and puts the supplement back.
    func delete(id: String) {
        guard let existing = records.first(where: { $0.id == id }) else { return }
        save(SupplementRecord(supplement: existing.supplement, updatedAt: Date(), pendingSync: true,
                              deleted: true))
    }

    /// Merge the remote snapshot in, then push anything the server is still owed. A failed fetch
    /// still drains the queue — that is the retry path. No-op when local-only.
    ///
    /// The pull is gated on consent like the writes are: what she takes is health data, and
    /// pulling it back down after a withdrawal is fresh processing with no lawful basis. What is
    /// already on the device stays. The drain runs either way — it carries her deletions.
    func refresh() async {
        guard let backend else { return }
        if isCollectionPermitted(), let remote = try? await backend.list() {
            records = SupplementSync.merge(local: records, remote: remote)
            persist()
        }
        await drainPending()
    }

    /// Push every record the server is still owed, oldest first. A connection failure is the same
    /// answer for everything behind it, so we stop and leave the queue for next time; a server-side
    /// rejection is specific to one record, and stepping over it keeps one poisoned write from
    /// starving everything newer.
    func drainPending() async {
        guard let backend else { return }
        for record in SupplementSync.pending(records) {
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

    private func save(_ record: SupplementRecord) {
        records = records.filter { $0.id != record.id } + [record]
        persist()
        push(record)
    }

    private func push(_ record: SupplementRecord) {
        guard let backend else { return }
        Task {
            guard (try? await backend.upsert(record)) != nil else { return }   // stays queued on failure
            clearPending(record)
            persist()
        }
    }

    /// Clear the queue flag, but only if the record hasn't changed again while the push was in
    /// flight — otherwise a newer local edit gets marked synced and is lost.
    private func clearPending(_ pushed: SupplementRecord) {
        records = records.map { current in
            current.id == pushed.id && current.updatedAt == pushed.updatedAt
                ? current.marking(pendingSync: false)
                : current
        }
    }

    private func persist() {
        store.save(records.map(SupplementRecordDTO.init), forKey: recordsKey)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    ///
    /// The legacy key goes too. It is only ever read once, on a device that has not migrated yet —
    /// but "only ever read once" is a property of this code, not of the data, and a supplement list
    /// left behind by the previous account is exactly the kind of thing the next sign-in picks up.
    func clearLocalState() {
        records = []
        store.remove(forKey: recordsKey)
        legacyDefaults.removeObject(forKey: CustomSupplement.storageKey)
    }
}
