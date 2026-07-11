import Foundation
import GenesyxCore

/// Cycle settings. Local-first: persists on-device and, when a `CycleBackend` is provided
/// (Supabase activated), writes through to the remote. Mirrors the Android `CycleRepository`.
///
/// A push that fails (offline, signed out) leaves the settings marked as owed to the server, and
/// until they have landed a pull will NOT overwrite them — otherwise a stale cloud copy would undo
/// an edit she made offline. So `refresh` pushes what is owed first, and only then pulls.
@MainActor
final class CycleRepository: ObservableObject {

    @Published private(set) var settings: CycleSettings?

    private let store: LocalStore
    private let backend: CycleBackend?
    private let key = "cycle_settings"
    private let pendingKey = "cycle_settings_pending"

    /// True when the server hasn't got the local settings yet. A v1.0 install has settings but no
    /// flag — that counts as owed, so an existing on-device cycle is carried up on first sign-in.
    private var pendingPush: Bool {
        didSet { store.setBool(pendingPush, forKey: pendingKey) }
    }

    init(store: LocalStore, backend: CycleBackend? = nil) {
        self.store = store
        self.backend = backend
        let local = store.load(CycleSettings.self, forKey: key)
        self.settings = local
        self.pendingPush = store.bool(forKey: pendingKey, default: local != nil)
    }

    func upsert(_ settings: CycleSettings) {
        self.settings = settings
        store.save(settings, forKey: key)
        pendingPush = true
        push(settings)
    }

    /// Push what the server is owed, then pull. No-op when local-only.
    func refresh() async {
        guard let backend else { return }
        await drainPending()
        guard !pendingPush, let remote = try? await backend.fetch() else { return }
        settings = remote
        store.save(remote, forKey: key)
    }

    /// Retry the write the server never received. Called on launch/sign-in and app foreground.
    func drainPending() async {
        guard let backend, pendingPush, let settings else { return }
        guard (try? await backend.upsert(settings)) != nil else { return }
        pendingPush = false
    }

    private func push(_ settings: CycleSettings) {
        guard let backend else { return }
        Task {
            guard (try? await backend.upsert(settings)) != nil else { return }   // stays owed
            if self.settings == settings { pendingPush = false }                 // unless re-edited meanwhile
        }
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        settings = nil
        store.remove(forKey: key)
        store.remove(forKey: pendingKey)
    }
}
