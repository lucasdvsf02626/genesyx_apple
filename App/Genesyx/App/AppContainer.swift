import Foundation

/// Composition root — constructs the `LocalStore`, resolves the optional remote backend, and
/// builds all repositories. Injected into the environment. The lightweight iOS equivalent of the
/// Android Hilt graph. In the local-only v1 `backend` is `nil` and repositories are on-device.
@MainActor
final class AppContainer: ObservableObject {

    let store: LocalStore
    let backend: GenesyxBackend?

    let cycle: CycleRepository
    let dailyLog: DailyLogRepository
    let ph: PhRepository
    let prefs: PreferencesRepository
    let session: SessionRepository
    let partner: PartnerRepository

    /// Designated init. Allows an injected store (used by previews/tests for isolation).
    init(store: LocalStore, backend: GenesyxBackend?) {
        self.store = store
        self.backend = backend

        self.cycle = CycleRepository(store: store, backend: backend?.cycle)
        self.dailyLog = DailyLogRepository(store: store, backend: backend?.dailyLog)
        self.ph = PhRepository(store: store, backend: backend?.ph)
        self.prefs = PreferencesRepository(store: store)
        self.session = SessionRepository(auth: backend?.auth)
        self.partner = PartnerRepository(backend: backend?.partner)

        // Online-first hydration when a backend is present (no-op when local-only).
        if backend != nil {
            Task { @MainActor in
                await cycle.refresh()
                await ph.refresh()
                await dailyLog.refresh()
                await partner.refresh()
            }
        }
    }

    /// Production init — standard on-device store + resolved backend.
    convenience init() {
        self.init(store: LocalStore(), backend: AppBackend.make())
    }
}
