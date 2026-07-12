import XCTest
@testable import Genesyx
import GenesyxCore

/// Behavioural tests for the on-device repositories (water clamping, streaks, pH rounding/order,
/// persistence across instances). Marked @MainActor because the repositories are.
@MainActor
final class RepositoryTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    func testCyclePersistsAcrossInstances() {
        let store = makeStore()
        let settings = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 29, periodLength: 6)
        CycleRepository(store: store).upsert(settings)
        XCTAssertEqual(CycleRepository(store: store).settings, settings)
    }

    func testWaterClampsAndAdjusts() {
        let repo = DailyLogRepository(store: makeStore())
        repo.setWater(20_000)                 // clamp high
        XCTAssertEqual(repo.waterMl(on: .today()), 10_000)
        repo.setWater(500)
        repo.adjustWater(250)
        XCTAssertEqual(repo.waterMl(on: .today()), 750)
        repo.adjustWater(-50_000)             // clamp low
        XCTAssertEqual(repo.waterMl(on: .today()), 0)
    }

    func testStreakCountsConsecutiveDaysWithWater() {
        let repo = DailyLogRepository(store: makeStore())
        let today = CalendarDate.today()
        repo.setWater(300, on: today)
        repo.setWater(300, on: today.minusDays(1))
        repo.setWater(300, on: today.minusDays(2))
        XCTAssertEqual(repo.streak(today: today), 3)
        // A gap two days back stops the streak at the gap.
        repo.setWater(0, on: today.minusDays(1))
        XCTAssertEqual(repo.streak(today: today), 1)
    }

    func testPhCreateRoundsAndSortsByDate() {
        let repo = PhRepository(store: makeStore())
        let t0 = Date(timeIntervalSince1970: 2_000)
        let t1 = Date(timeIntervalSince1970: 1_000) // earlier
        repo.create(PhReading(phValue: 6.46, recordedAt: t0))   // rounds to 6.5
        repo.create(PhReading(phValue: 7.0, recordedAt: t1))
        XCTAssertEqual(repo.readings.map(\.phValue), [7.0, 6.5]) // ascending by recordedAt
        XCTAssertEqual(repo.readings.first?.recordedAt, t1)
    }

    func testPhUpdateAndDelete() {
        let repo = PhRepository(store: makeStore())
        let r = PhReading(id: "x", phValue: 6.0, recordedAt: Date())
        repo.create(r)
        repo.update(PhReading(id: "x", phValue: 7.2, recordedAt: r.recordedAt))
        XCTAssertEqual(repo.readings.first?.phValue, 7.2)
        repo.delete(id: "x")
        XCTAssertTrue(repo.readings.isEmpty)
    }

    func testPreferencesPersist() {
        let store = makeStore()
        let prefs = PreferencesRepository(store: store)
        prefs.themeMode = .dark
        prefs.pushEnabled = false
        prefs.focusMode = .pregnancy
        let reloaded = PreferencesRepository(store: store)
        XCTAssertEqual(reloaded.themeMode, .dark)
        XCTAssertFalse(reloaded.pushEnabled)
        XCTAssertEqual(reloaded.focusMode, .pregnancy)
    }

    // MARK: - Local health-data wipe on auth transitions

    /// Seeds cycle/pH/daily-log data into a container, then asserts sign-out clears both the
    /// in-memory state AND the on-device store keys — so a different user never sees it.
    func testSignOutClearsLocalHealthData() {
        let store = makeStore()
        let c = AppContainer(store: store, backend: nil)
        c.cycle.upsert(CycleSettings(lastPeriodDate: .today(), cycleLength: 28, periodLength: 5))
        c.ph.create(PhReading(phValue: 6.5, recordedAt: Date()))
        c.dailyLog.setWater(500)
        XCTAssertNotNil(c.cycle.settings)
        XCTAssertFalse(c.ph.readings.isEmpty)
        XCTAssertFalse(c.dailyLog.logByDate.isEmpty)

        c.session.signOut()

        // In-memory reset.
        XCTAssertNil(c.cycle.settings)
        XCTAssertTrue(c.ph.readings.isEmpty)
        XCTAssertTrue(c.dailyLog.logByDate.isEmpty)
        // Store keys absent → a fresh repo on the same store (i.e. a next user) loads empty.
        XCTAssertNil(store.load(CycleSettings.self, forKey: "cycle_settings"))
        XCTAssertNil(store.load([PhReadingDTO].self, forKey: "ph_readings"))
        XCTAssertNil(store.load([String: DailyLogDTO].self, forKey: "daily_logs"))
        XCTAssertNil(CycleRepository(store: store).settings)
        XCTAssertTrue(PhRepository(store: store).readings.isEmpty)
    }

    // MARK: - pH sync (the device is the source of truth; the cloud is a mirror)

    /// The regression this suite exists for: `refresh()` used to assign the remote snapshot over
    /// the local one, so hydrating a signed-in user against an empty cloud table wiped her pH
    /// history — and persisted the wipe. It must merge, keep the local rows, and push them up.
    func testEmptyCloudDoesNotWipeLocalHistoryAndPushesItUp() async {
        let backend = FakePhBackend()                       // the cloud has never seen her
        let repo = PhRepository(store: makeStore(), backend: backend)
        repo.create(PhReading(id: "a", phValue: 6.5, recordedAt: Date()))

        await repo.refresh()

        XCTAssertEqual(repo.readings.map(\.id), ["a"], "an empty cloud must not wipe the device")
        XCTAssertEqual(backend.remote.map(\.id), ["a"], "the local-only reading is carried up")
    }

    /// A v1.0 install has readings with no sync bookkeeping. They must decode as "never pushed"
    /// so the first sign-in carries the existing history to the cloud (the one-time migration).
    func testLegacyReadingsAreCarriedUpOnFirstSync() async {
        let store = makeStore()
        store.save([PhReadingDTO(id: "old", phValue: 6.2, recordedAt: Date(), notes: nil)], forKey: "ph_readings")
        let backend = FakePhBackend()

        await PhRepository(store: store, backend: backend).refresh()

        XCTAssertEqual(backend.remote.map(\.id), ["old"])
    }

    /// Offline: the local save still succeeds and the push is queued, not dropped. It lands when
    /// the network comes back (app foreground → `drainPending`).
    func testFailedPushStaysQueuedAndLandsWhenBackOnline() async {
        let backend = FakePhBackend()
        backend.online = false
        let repo = PhRepository(store: makeStore(), backend: backend)

        repo.create(PhReading(id: "a", phValue: 6.5, recordedAt: Date()))
        await repo.drainPending()

        XCTAssertEqual(repo.readings.map(\.id), ["a"], "an offline save is never dropped")
        XCTAssertTrue(backend.remote.isEmpty)

        backend.online = true
        await repo.drainPending()

        XCTAssertEqual(backend.remote.map(\.id), ["a"])
    }

    /// A delete is a tombstone, not a removal — otherwise the next pull would resurrect it (and
    /// other devices would never learn about the deletion).
    func testDeleteIsATombstoneAndSurvivesAPull() async {
        let backend = FakePhBackend()
        let repo = PhRepository(store: makeStore(), backend: backend)
        repo.create(PhReading(id: "a", phValue: 6.5, recordedAt: Date()))
        await repo.drainPending()

        repo.delete(id: "a")
        await repo.drainPending()

        XCTAssertTrue(repo.readings.isEmpty)
        XCTAssertEqual(backend.remote.first?.deleted, true, "the server gets a tombstone, not a delete")

        await repo.refresh()

        XCTAssertTrue(repo.readings.isEmpty, "a pull must not resurrect a deleted reading")
    }

    // MARK: - Auth

    /// With "Confirm email" on, Supabase's sign-up returns a user but no session. She is not signed
    /// in until she clicks the link — claiming otherwise would leave every write failing the
    /// server's auth check while the UI insisted all was well.
    func testSignUpWithoutASessionDoesNotSignHerIn() async {
        let auth = FakeAuthBackend()
        auth.grantsSessionOnSignUp = false          // the project requires email confirmation
        let session = SessionRepository(auth: auth)

        do {
            try await session.authenticate(email: "a@b.com", password: "password123", name: nil, signUp: true)
            XCTFail("sign-up without a session must not report success")
        } catch RemoteError.emailConfirmationRequired {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertFalse(session.isSignedIn)
    }

    func testSignUpWithASessionSignsHerIn() async throws {
        let session = SessionRepository(auth: FakeAuthBackend())   // confirmation off: session granted

        try await session.authenticate(email: "a@b.com", password: "password123", name: "Ada", signUp: true)

        XCTAssertTrue(session.isSignedIn)
        XCTAssertEqual(session.displayName, "Ada")
    }

    // MARK: - Cycle, daily-log and profile sync (same contract: a stale cloud never wins)

    func testCycleOfflineEditIsNotOverwrittenByAStalePull() async {
        let backend = FakeCycleBackend()
        backend.remote = CycleSettings(lastPeriodDate: CalendarDate(2026, 1, 1), cycleLength: 28, periodLength: 5)
        backend.online = false
        let repo = CycleRepository(store: makeStore(), backend: backend)

        let edited = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 30, periodLength: 4)
        repo.upsert(edited)              // offline: the push fails and stays owed
        await repo.refresh()

        XCTAssertEqual(repo.settings, edited, "a stale cloud copy must not undo an offline edit")

        backend.online = true
        await repo.refresh()

        XCTAssertEqual(backend.remote, edited, "the owed write lands once we're back online")
        XCTAssertEqual(repo.settings, edited)
    }

    func testDailyLogOfflineEditIsNotOverwrittenByAStalePull() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        backend.remote[today] = DailyLog(waterMl: 250)      // stale cloud copy
        backend.online = false
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        repo.setWater(1_500)
        await repo.refresh()

        XCTAssertEqual(repo.waterMl(on: today), 1_500, "a stale cloud copy must not undo an offline log")

        backend.online = true
        await repo.refresh()

        XCTAssertEqual(backend.remote[today]?.waterMl, 1_500)
    }

    /// A pull still brings down the days this device has never seen — that's the point of it.
    func testDailyLogPullAdoptsCloudDaysTheDeviceDoesNotHave() async {
        let backend = FakeDailyLogBackend()
        let yesterday = CalendarDate.today().minusDays(1)
        backend.remote[yesterday] = DailyLog(waterMl: 900)
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        await repo.refresh()

        XCTAssertEqual(repo.waterMl(on: yesterday), 900)
    }

    /// A v1.0 install has a history but has never pushed anything: first sync carries it up.
    func testDailyLogHistoryIsCarriedUpOnFirstSync() async {
        let store = makeStore()
        DailyLogRepository(store: store).setWater(800)      // local-only, as v1.0 was
        let backend = FakeDailyLogBackend()

        await DailyLogRepository(store: store, backend: backend).refresh()

        XCTAssertEqual(backend.remote[.today()]?.waterMl, 800)
    }

    func testProfileIsSeededFromTheDeviceWhenTheCloudHasNone() async {
        let backend = FakeProfileBackend()                 // no row up there
        let repo = PreferencesRepository(store: makeStore(), backend: backend)

        repo.focusMode = .pregnancy
        await repo.refresh()

        XCTAssertEqual(backend.remote?.focusMode, .pregnancy)
    }

    func testProfilePullAppliesRemotePrefs() async {
        let backend = FakeProfileBackend()
        backend.remote = ProfilePrefs(focusMode: .pregnancy, themeMode: .dark, pushEnabled: false)
        let repo = PreferencesRepository(store: makeStore(), backend: backend)

        await repo.refresh()

        XCTAssertEqual(repo.themeMode, .dark)
        XCTAssertEqual(repo.focusMode, .pregnancy)
        XCTAssertFalse(repo.pushEnabled)
    }

    /// Sign-out must also wipe the notification state derived from her data. Milestone flags and
    /// the read-article list are as personal as a log: leaving them behind means the next user on
    /// the device silently inherits them — her celebrations already "spent", her Learn nudges
    /// skipping articles she never read.
    func testSignOutClearsNotificationState() {
        let store = makeStore()
        let container = AppContainer(store: store, backend: nil)
        container.prefs.celebrate(["milestone_7_sent", "milestone_w1_sent"])
        LearnReadLog.markRead("first-week")
        XCTAssertFalse(container.prefs.celebratedMilestones.isEmpty)

        container.session.signOut()

        XCTAssertTrue(container.prefs.celebratedMilestones.isEmpty,
                      "the next user must be able to earn her own milestones")
        XCTAssertFalse(LearnReadLog.readSlugs.contains("first-week"),
                       "the next user has not read the previous user's articles")
        XCTAssertTrue(PreferencesRepository(store: store).celebratedMilestones.isEmpty,
                      "and it must not come back from the store on next launch")
    }

    /// Account deletion (success path) must wipe the same on-device health data.
    func testDeleteAccountClearsLocalHealthData() async throws {
        let store = makeStore()
        let c = AppContainer(store: store, backend: nil)
        c.cycle.upsert(CycleSettings(lastPeriodDate: .today(), cycleLength: 30, periodLength: 4))
        c.ph.create(PhReading(phValue: 7.0, recordedAt: Date()))
        c.dailyLog.setWater(750)

        try await c.session.deleteAccount()

        XCTAssertNil(c.cycle.settings)
        XCTAssertTrue(c.ph.readings.isEmpty)
        XCTAssertTrue(c.dailyLog.logByDate.isEmpty)
        XCTAssertNil(store.load(CycleSettings.self, forKey: "cycle_settings"))
        XCTAssertNil(store.load([PhReadingDTO].self, forKey: "ph_readings"))
        XCTAssertNil(store.load([String: DailyLogDTO].self, forKey: "daily_logs"))
    }
}

// In-memory stand-ins for the four synced tables. `online = false` makes every call fail the way
// an offline device does, so the queue behaviour is testable without a network.

@MainActor
private final class FakePhBackend: PhBackend {
    var remote: [PhRecord] = []
    var online = true

    func list(sinceDays: Int?) async throws -> [PhRecord] {
        guard online else { throw RemoteError.notConfigured }
        return remote
    }

    func upsert(_ record: PhRecord) async throws {
        guard online else { throw RemoteError.notConfigured }
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}

/// `grantsSessionOnSignUp = false` reproduces a project with "Confirm email" turned on: sign-up
/// succeeds, but no session exists until she clicks the link.
@MainActor
private final class FakeAuthBackend: AuthBackend {
    var currentUserId: String?
    var grantsSessionOnSignUp = true

    func signUp(email: String, password: String) async throws {
        if grantsSessionOnSignUp { currentUserId = "user-1" }
    }

    func signIn(email: String, password: String) async throws { currentUserId = "user-1" }
    func signOut() async throws { currentUserId = nil }
}

@MainActor
private final class FakeCycleBackend: CycleBackend {
    var remote: CycleSettings?
    var online = true

    func fetch() async throws -> CycleSettings? {
        guard online else { throw RemoteError.notConfigured }
        return remote
    }

    func upsert(_ settings: CycleSettings) async throws {
        guard online else { throw RemoteError.notConfigured }
        remote = settings
    }
}

@MainActor
private final class FakeDailyLogBackend: DailyLogBackend {
    var remote: [CalendarDate: DailyLog] = [:]
    var online = true

    func fetch(date: CalendarDate) async throws -> DailyLog? {
        guard online else { throw RemoteError.notConfigured }
        return remote[date]
    }

    func list() async throws -> [CalendarDate: DailyLog] {
        guard online else { throw RemoteError.notConfigured }
        return remote
    }

    func upsert(_ log: DailyLog, on date: CalendarDate) async throws {
        guard online else { throw RemoteError.notConfigured }
        remote[date] = log
    }
}

@MainActor
private final class FakeProfileBackend: ProfileBackend {
    var remote: ProfilePrefs?
    var displayName: String?
    var online = true

    func fetch() async throws -> ProfilePrefs? {
        guard online else { throw RemoteError.notConfigured }
        return remote
    }

    func upsert(_ prefs: ProfilePrefs) async throws {
        guard online else { throw RemoteError.notConfigured }
        remote = prefs
    }

    func upsert(displayName: String) async throws {
        guard online else { throw RemoteError.notConfigured }
        self.displayName = displayName
    }
}
