import Foundation
// Not `#if DEBUG`. It was, back when only the seeding block used the package — then the sign-out
// wipe started naming `CustomSupplement.storageKey`, which is release code. Every test target is a
// Debug build, so they all kept compiling and only `archive` failed.
import GenesyxCore

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
    let supplements: SupplementsRepository
    let prefs: PreferencesRepository
    let session: SessionRepository
    let partner: PartnerRepository
    let learn: LearnProgress
    let reachability: Reachability

    /// Designated init. Allows an injected store (used by previews/tests for isolation).
    /// `monitorNetwork: false` keeps tests off the host's real connectivity.
    init(store: LocalStore, backend: GenesyxBackend?, monitorNetwork: Bool = true) {
        self.store = store
        self.backend = backend
        self.reachability = Reachability(monitoring: monitorNetwork)

        self.cycle = CycleRepository(store: store, backend: backend?.cycle)
        self.dailyLog = DailyLogRepository(store: store, backend: backend?.dailyLog)
        self.ph = PhRepository(store: store, backend: backend?.ph)
        self.supplements = SupplementsRepository(store: store, backend: backend?.supplements)
        self.prefs = PreferencesRepository(store: store, backend: backend?.profile)
        self.session = SessionRepository(store: store, auth: backend?.auth)
        self.partner = PartnerRepository(backend: backend?.partner)
        self.learn = LearnProgress()

        // Auth-transition wiring: wipe on-device health data on sign-out / account deletion, and
        // rehydrate from the backend on sign-in. Weak self avoids a retain cycle (container owns session).
        session.onClearLocalState = { [weak self] in self?.clearLocalState() }
        session.onHydrate = { [weak self] in await self?.hydrate() }
        session.onPushDisplayName = { name in
            guard let profile = backend?.profile else { return false }
            do { try await profile.upsert(displayName: name); return true } catch { return false }
        }
        session.onFetchDisplayName = { try? await backend?.profile.fetchDisplayName() }

        // Online-first hydration only after a valid session exists. A reconnect is the other
        // moment the queues can move, and until now the app slept through it: the only trigger
        // was foregrounding, so a phone that stayed in her hand through a tunnel or a dead-spot
        // kept its backlog until she next switched apps.
        if backend != nil {
            reachability.onReconnect = { [weak self] in
                guard let self, self.session.isSignedIn else { return }
                await self.drainPending()
            }
        }
    }

    /// Release without a configured backend must not fall through to mock auth or private tabs.
    var isServiceAvailable: Bool {
        #if DEBUG
        true
        #else
        backend != nil
        #endif
    }

    /// Sync each repository with the backend, cheapest table first so a slow one never holds up
    /// the rest: profile → cycle → daily logs → pH. Each one pushes what it still owes the server
    /// before pulling, so nothing on the device is overwritten by a staler copy in the cloud.
    /// No-op per-repo when local-only.
    func hydrate() async {
        // First, because it is the cheapest round-trip in the graph and because it is what her
        // partner sees: sign-up is the only screen that asks for a name, so this is the moment the
        // name she registered under reaches her row at all — and, on a new phone, the moment it
        // comes back.
        await session.refreshDisplayName()
        await prefs.refresh()
        await cycle.refresh()
        await dailyLog.refresh()
        await ph.refresh()
        await supplements.refresh()
        // Excluded from the 1.2.0 public release, so this is skipped rather than merely hidden:
        // with the flag off the app never reads `partner_invites` or a partner's profile row at
        // all. See `FeatureFlags.partnerInvites`.
        if FeatureFlags.partnerInvites { await partner.refresh() }
    }

    /// Retry everything a failed push left owed to the server. Called when the app is foregrounded
    /// — the moment the network is most likely back.
    func drainPending() async {
        await session.drainPendingName()
        await prefs.drainPending()
        await cycle.drainPending()
        await dailyLog.drainPending()
        await ph.drainPending()
        await supplements.drainPending()
        // A partner accepting an invite is a change made on *another* device, so there is nothing
        // owed to push — only something to pull. Without this the inviter had to fully relaunch
        // the app before her partner ever showed up as linked.
        // Skipped for the 1.2.0 public release — see `FeatureFlags.partnerInvites`.
        if FeatureFlags.partnerInvites { await partner.refresh() }
    }

    /// Wipe on-device health data (cycle settings, pH readings, daily logs) from memory and the
    /// local store on sign-out / account deletion, so a different user never sees the previous
    /// user's cached data. Session/prefs are cleared by their own teardown.
    func clearLocalState() {
        cycle.clearLocalState()
        ph.clearLocalState()
        dailyLog.clearLocalState()
        // Notification state is derived from her data, so it is her data: milestone flags and the
        // read-article list must not follow her out of the app.
        prefs.clearNotificationState()
        // Onboarding does not re-run on sign-out — that flag is device-local and stays set — so
        // without this the next user on the phone would silently inherit her quiz answers.
        prefs.clearQuizAnswers()
        // Whether she is trying or already pregnant is health data, and it was being kept as though
        // it were a device preference like the theme.
        prefs.clearFocusMode()
        // A profile write she owed the server outlives the session that owed it, so the next
        // account's first refresh pushed her theme and focus mode into their row.
        prefs.clearOwedProfileWrite()
        // The light-mode migration corrects a per-account server value but latched per-device, so
        // only the first account ever signed in on a phone could receive it.
        prefs.clearThemeMigrationFlag()
        learn.clear()
        // Nor may the next account inherit her partner link or her pending invites.
        partner.clearLocalState()
        // Custom supplements are user-entered and, since 14 Aug, synced. The repository clears both
        // the sync-aware store and the pre-sync `@AppStorage` list it migrates from — leaving either
        // behind would hand the next account on this phone her supplements.
        supplements.clearLocalState()
        // Which cycle phase she was last in is health data too, and leaving it would announce a
        // phase change to the next account for a transition that was not hers.
        UserDefaults.standard.removeObject(forKey: NutritionView.lastSeenPhaseKey)
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
        // `-uiTestKeepStore YES` is the second half of a cold-relaunch test: the same local-only
        // container, but reading whatever the previous launch left on disk instead of wiping and
        // re-seeding. Without it every launch starts empty and "did this survive a restart?" cannot
        // be asked at all — which is how the pH serialization defect reached a release candidate.
        // Deliberately still backend-less: a relaunch without the seed flag would resolve the real
        // Supabase backend, and no test may point at the shared production project.
        if UserDefaults.standard.bool(forKey: "uiTestKeepStore") {
            return AppContainer(store: LocalStore(), backend: nil)
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        let container = AppContainer(store: LocalStore(), backend: nil)
        // `-uiTestNoCycle YES` is the user who skipped cycle setup: everything else seeded, no
        // period date. The calendar has to work for her too, and used not to exist at all.
        if !UserDefaults.standard.bool(forKey: "uiTestNoCycle") {
            container.cycle.upsert(CycleSettings(lastPeriodDate: CalendarDate.today().minusDays(8), cycleLength: 28, periodLength: 5))
        }
        container.dailyLog.setWater(750)
        container.dailyLog.upsert(
            DailyLog(mood: .good, energy: .normal, symptoms: ["Fatigue", "Cramps"],
                     sleepMinutes: 445, supplements: ["Folate", "Vitamin D"],
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
        // Public screenshots must never expose a real person's account details.
        // Onboarding and signed-out launches must not sign in: a signed-in session now opens
        // the tabs regardless of the onboarding flag.
        let wantsOnboarding = UserDefaults.standard.bool(forKey: "uiTestOnboarding")
        let wantsSignedOut = UserDefaults.standard.bool(forKey: "uiTestSignedOut")
        if !wantsOnboarding && !wantsSignedOut {
            container.session.signIn(email: "maya@example.com", name: "Maya")
        }
        // Onboarding is skipped by default — every other test wants the tabs. `-uiTestOnboarding YES`
        // leaves it un-run so the quiz itself can be driven.
        UserDefaults.standard.set(!wantsOnboarding, forKey: "genesyx.onboardingComplete")
        // The wipe above makes every seeded launch a first install, which by design shows no
        // phase-change card. `-uiTestPhaseChange YES` backdates the last phase she was told about
        // to the one before the seeded cycle day (day 9 → follicular), so the card is due.
        if UserDefaults.standard.bool(forKey: "uiTestPhaseChange") {
            UserDefaults.standard.set(Phase.period.rawValue, forKey: NutritionView.lastSeenPhaseKey)
        }
        // `-uiTestMilestone YES` is a week of meals and nothing else: six backdated food-group-only
        // days which, with today's seeded water, make a 7-day *logging* streak and a 1-day hydration
        // one. That asymmetry is the point — under the old rule, where the daily milestones keyed off
        // hydration, this woman crossed nothing. She is exactly who the trigger was repointed for.
        if UserDefaults.standard.bool(forKey: "uiTestMilestone") {
            for day in 1...6 {
                container.dailyLog.upsert(
                    DailyLog(foodGroups: ["vegetables", "protein"]),
                    on: CalendarDate.today().minusDays(day))
            }
        } else {
            // Every other seeded launch is a woman with several days of history behind her, and on
            // most weekdays that history already clears the first weekly milestone — the base seed
            // does it today. Her celebration would then open over the tab bar in every unrelated UI
            // test and swallow its taps, on some weekdays and not others. She has been here a while:
            // treat her celebrations as already spent, and let the milestone test be the one place
            // they are not.
            container.prefs.celebrate(Milestone.allCases.map(\.flagKey))
        }
        return container
    }
    #endif
}
