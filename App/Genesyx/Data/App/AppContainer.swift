import Foundation
#if DEBUG
import GenesyxCore
#endif

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
        self.prefs = PreferencesRepository(store: store, backend: backend?.profile)
        self.session = SessionRepository(auth: backend?.auth)
        self.partner = PartnerRepository(backend: backend?.partner)

        // Auth-transition wiring: wipe on-device health data on sign-out / account deletion, and
        // rehydrate from the backend on sign-in. Weak self avoids a retain cycle (container owns session).
        session.onClearLocalState = { [weak self] in self?.clearLocalState() }
        session.onHydrate = { [weak self] in await self?.hydrate() }
        session.onDisplayNameChanged = { name in
            guard let profile = backend?.profile else { return }
            Task { try? await profile.upsert(displayName: name) }
        }

        // Online-first hydration when a backend is present (no-op when local-only).
        if backend != nil {
            Task { @MainActor in await self.hydrate() }
        }
    }

    /// Sync each repository with the backend, cheapest table first so a slow one never holds up
    /// the rest: profile → cycle → daily logs → pH. Each one pushes what it still owes the server
    /// before pulling, so nothing on the device is overwritten by a staler copy in the cloud.
    /// No-op per-repo when local-only.
    func hydrate() async {
        await prefs.refresh()
        await cycle.refresh()
        await dailyLog.refresh()
        await ph.refresh()
        await partner.refresh()
    }

    /// Retry everything a failed push left owed to the server. Called when the app is foregrounded
    /// — the moment the network is most likely back.
    func drainPending() async {
        await prefs.drainPending()
        await cycle.drainPending()
        await dailyLog.drainPending()
        await ph.drainPending()
    }

    /// Wipe on-device health data (cycle settings, pH readings, daily logs) from memory and the
    /// local store on sign-out / account deletion, so a different user never sees the previous
    /// user's cached data. Session/prefs are cleared by their own teardown.
    func clearLocalState() {
        cycle.clearLocalState()
        ph.clearLocalState()
        dailyLog.clearLocalState()
    }

    /// Production init — standard on-device store + resolved backend.
    convenience init() {
        self.init(store: LocalStore(), backend: AppBackend.make())
    }

    #if DEBUG
    /// Screenshot/UI-test entry point: wipes app defaults, seeds realistic sample data, and marks
    /// onboarding complete so a fresh launch lands directly on the main tabs. Triggered by the
    /// `-uiTestSeed YES` launch argument (see `GenesyxApp`). Never compiled into Release builds.
    static func uiTestSeeded() -> AppContainer {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        let container = AppContainer(store: LocalStore(), backend: nil)
        container.cycle.upsert(CycleSettings(lastPeriodDate: CalendarDate.today().minusDays(8), cycleLength: 28, periodLength: 5))
        container.dailyLog.setWater(750)
        container.dailyLog.upsert(
            DailyLog(mood: .good, energy: .normal, symptoms: ["Fatigue", "Cramps"],
                     sleepMinutes: 445, supplements: ["Folic acid", "Vitamin D"],
                     notes: "Felt steady today, gentle walk in the evening.", waterMl: 1_800),
            on: CalendarDate.today().minusDays(1))
        container.dailyLog.upsert(
            DailyLog(mood: .great, energy: .high, symptoms: ["Bloating"],
                     sleepMinutes: 480, supplements: ["Omega-3"],
                     notes: "Great energy, good focus at work.", waterMl: 2_100),
            on: CalendarDate.today().minusDays(3))
        container.ph.create(PhReading(phValue: 6.3, recordedAt: Date().addingTimeInterval(-5 * 86_400)))
        container.ph.create(PhReading(phValue: 6.7, recordedAt: Date().addingTimeInterval(-2 * 86_400)))
        container.ph.create(PhReading(phValue: 6.9, recordedAt: Date()))
        container.session.signIn(email: "lucas@example.com", name: "Lucas")
        UserDefaults.standard.set(true, forKey: "genesyx.onboardingComplete")
        return container
    }
    #endif
}
