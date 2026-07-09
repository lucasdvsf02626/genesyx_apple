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
