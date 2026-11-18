import Foundation
import GenesyxCore

/// Cycle settings. Local-first: persists on-device and, when a `CycleBackend` is provided
/// (Supabase activated), refreshes from and writes through to the remote. Backend is `nil` in
/// the local-only v1, so behaviour is unchanged. Mirrors the Android `CycleRepository`.
@MainActor
final class CycleRepository: ObservableObject {

    @Published private(set) var settings: CycleSettings?

    private let store: LocalStore
    private let backend: CycleBackend?
    private let key = "cycle_settings"

    init(store: LocalStore, backend: CycleBackend? = nil) {
        self.store = store
        self.backend = backend
        self.settings = store.load(CycleSettings.self, forKey: key)
    }

    func upsert(_ settings: CycleSettings) {
        self.settings = settings
        store.save(settings, forKey: key)
        if let backend { Task { try? await backend.upsert(settings) } }
    }

    /// Pull the latest from the remote (no-op when local-only).
    func refresh() async {
        guard let backend, let remote = try? await backend.fetch() else { return }
        settings = remote
        store.save(remote, forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        settings = nil
        store.remove(forKey: key)
    }
}
