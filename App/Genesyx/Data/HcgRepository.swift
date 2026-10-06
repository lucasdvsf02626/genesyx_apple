import Foundation
import GenesyxCore

/// Pregnancy test results. ON-DEVICE ONLY by decision (hcg-adr H2): there is no server copy,
/// no queue and no sync, so sign-out and an account switch destroy the only copy. A result is
/// immutable: create and delete, no update.
@MainActor
final class HcgRepository: ObservableObject {

    /// Oldest first.
    @Published private(set) var results: [HcgResult] = []

    /// Guards new results only. `delete` and `deleteAll` are deliberately outside it: erasing what
    /// she already recorded is Article 17 and must stay available after a withdrawal.
    var isCollectionPermitted: HealthDataCollectionGate = { true }

    private let store: LocalStore
    private let key = "hcg_results"

    init(store: LocalStore) {
        self.store = store
        if let stored = store.load([HcgResultDTO].self, forKey: key) {
            // An entry whose classification this build does not know is dropped, never guessed.
            results = Self.sorted(stored.compactMap(\.result))
        }
    }

    /// **Returns false when the write was refused.** The caller must not report success on a false.
    /// Refused when the consent gate says no, and for a scanned invalid test, which is never a
    /// record (one she typed in is). A result with an existing `id` replaces it.
    @discardableResult
    func create(_ result: HcgResult) -> Bool {
        guard isCollectionPermitted() else { return false }
        if result.classification == .invalid && result.scan != nil { return false }
        results = Self.sorted(results.filter { $0.id != result.id } + [result])
        persist()
        return true
    }

    /// A hard removal: there is no other device for a tombstone to reach.
    func delete(id: String) {
        guard results.contains(where: { $0.id == id }) else { return }
        results.removeAll { $0.id == id }
        persist()
    }

    /// Removes every result from memory and removes the store key, so not even an empty list is left.
    func deleteAll() {
        results = []
        store.remove(forKey: key)
    }

    private static func sorted(_ results: [HcgResult]) -> [HcgResult] {
        results.sorted { ($0.recordedAt, $0.id) < ($1.recordedAt, $1.id) }
    }

    private func persist() {
        store.save(results.map(\.dto), forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        deleteAll()
    }
}
