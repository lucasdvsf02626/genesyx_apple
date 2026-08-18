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

    /// Her period dates are health data like any other, so setting them up or correcting them is
    /// collection and stops with the rest of it.
    var isCollectionPermitted: HealthDataCollectionGate = { true }

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

    /// **Returns false when the gate refused the write** — see the note on
    /// `DailyLogRepository.upsert`. The caller must not report success on a false.
    @discardableResult
    func upsert(_ settings: CycleSettings) -> Bool {
        guard isCollectionPermitted() else { return false }
        self.settings = settings
        store.save(settings, forKey: key)
        pendingPush = true
        push(settings)
        return true
    }

    /// Push what the server is owed, then pull. No-op when local-only.
    ///
    /// The pull sits behind the same gate as the writes: fetching her period dates back down from
    /// the server is fresh processing of special-category data, and after a withdrawal there is no
    /// lawful basis for it. The drain above it is deliberately *not* gated — see `drainPending`.
    func refresh() async {
        guard let backend else { return }
        await drainPending()
        guard isCollectionPermitted() else { return }
        guard !pendingPush, let remote = try? await backend.fetch() else { return }
        // Re-read after the fetch's suspension: an edit made while it was in flight is newer than
        // what came back, and overwriting it would revert her cycle dates on screen.
        guard !pendingPush else { return }
        settings = remote
        store.save(remote, forKey: key)
    }

    /// Retry the write the server never received. Called on launch/sign-in and app foreground.
    ///
    /// Ungated on purpose. Everything in this queue was recorded while consent was live, and a
    /// withdrawal does not undo the lawfulness of what came before it — it is finishing a transfer
    /// she authorised, not starting a new one. Blocking it would also strand the queue on the
    /// device indefinitely, which serves nobody.
    func drainPending() async {
        guard let backend, pendingPush, let snapshot = settings else { return }
        guard (try? await backend.upsert(snapshot)) != nil else { return }
        if settings == snapshot { pendingPush = false }   // unless she re-edited meanwhile
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
