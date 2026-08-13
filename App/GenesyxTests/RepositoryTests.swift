import Combine
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

    /// A day she missed has to stay fillable, and filling it must not disturb today. The repository
    /// always supported this; until the log sheet took a date, nothing could reach it.
    func testBackfillingAPastDayLeavesTodayAlone() {
        let store = makeStore()
        let today = CalendarDate.today()
        let threeDaysAgo = today.minusDays(3)

        let repo = DailyLogRepository(store: store)
        repo.upsert(DailyLog(mood: .good, waterMl: 500), on: today)
        repo.upsert(DailyLog(symptoms: ["Cramps"], sexualActivity: true), on: threeDaysAgo)

        let reloaded = DailyLogRepository(store: store)
        XCTAssertEqual(reloaded.log(on: threeDaysAgo).symptoms, ["Cramps"])
        XCTAssertTrue(reloaded.log(on: threeDaysAgo).sexualActivity)
        XCTAssertEqual(reloaded.log(on: today).mood, .good, "today must survive a backfill three days back")
        XCTAssertEqual(reloaded.log(on: today).waterMl, 500)
        XCTAssertFalse(reloaded.log(on: today).sexualActivity, "the past day's entry must not bleed forward")
    }

    /// Correcting a past day replaces that day rather than stacking a second entry beside it.
    func testEditingAPastDayReplacesItRatherThanDuplicating() {
        let store = makeStore()
        let yesterday = CalendarDate.today().minusDays(1)

        let repo = DailyLogRepository(store: store)
        repo.upsert(DailyLog(mood: .low, symptoms: ["Headache"], waterMl: 250), on: yesterday)
        repo.upsert(DailyLog(mood: .great, symptoms: ["Cramps"], waterMl: 1_000), on: yesterday)

        let reloaded = DailyLogRepository(store: store)
        XCTAssertEqual(reloaded.logByDate.keys.filter { $0 == yesterday }.count, 1, "one entry per day, always")
        XCTAssertEqual(reloaded.log(on: yesterday).mood, .great)
        XCTAssertEqual(reloaded.log(on: yesterday).symptoms, ["Cramps"])
        XCTAssertEqual(reloaded.log(on: yesterday).waterMl, 1_000)
    }

    func testHydrationPersistsAcrossRepositoryReload() {
        let store = makeStore()
        let today = CalendarDate.today()

        DailyLogRepository(store: store).setWater(1_750, on: today)

        XCTAssertEqual(DailyLogRepository(store: store).waterMl(on: today), 1_750)
    }

    func testSleepPersistsAcrossRepositoryReload() {
        let store = makeStore()
        let today = CalendarDate.today()

        DailyLogRepository(store: store).setSleep(455, on: today)

        XCTAssertEqual(DailyLogRepository(store: store).log(on: today).sleepMinutes, 455)
    }

    func testSleepEditUsesDailyLogWritePathAndCanClear() {
        let repo = DailyLogRepository(store: makeStore())
        let today = CalendarDate.today()

        repo.setSleep(900, on: today)
        XCTAssertEqual(repo.log(on: today).sleepMinutes, 720)

        repo.setSleep(0, on: today)
        XCTAssertNil(repo.log(on: today).sleepMinutes)

        repo.setSleep(455, on: today)
        repo.setSleep(nil, on: today)
        XCTAssertNil(repo.log(on: today).sleepMinutes)
    }

    func testDailyLogHydrationSyncState() async {
        let today = CalendarDate.today()
        let localOnly = DailyLogRepository(store: makeStore())
        localOnly.setWater(500, on: today)
        XCTAssertEqual(localOnly.syncState(on: today), .saved)

        let backend = FakeDailyLogBackend()
        backend.online = false
        let synced = DailyLogRepository(store: makeStore(), backend: backend)
        synced.setWater(500, on: today)
        XCTAssertEqual(synced.syncState(on: today), .pendingSync)

        backend.online = true
        await synced.refresh()
        XCTAssertEqual(synced.syncState(on: today), .synced)
    }

    func testHydrationIsIncludedInOutboundDailyLogSyncPayload() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        let repo = DailyLogRepository(store: makeStore(), backend: backend)
        let log = DailyLog(
            mood: .good,
            energy: .normal,
            symptoms: ["Fatigue"],
            sleepMinutes: 420,
            supplements: ["Vitamin D"],
            notes: "steady day",
            waterMl: 1_650
        )

        repo.upsert(log, on: today)
        await repo.drainPending()

        XCTAssertEqual(backend.remote[today]?.waterMl, 1_650)
        XCTAssertEqual(backend.remote[today]?.mood, .good)
        XCTAssertEqual(backend.remote[today]?.energy, .normal)
        XCTAssertEqual(backend.remote[today]?.sleepMinutes, 420)
        XCTAssertEqual(backend.remote[today]?.supplements, ["Vitamin D"])
        XCTAssertEqual(repo.syncState(on: today), .synced)
    }

    func testSleepIsIncludedInOutboundDailyLogSyncPayload() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        repo.setSleep(430, on: today)
        await repo.drainPending()

        XCTAssertEqual(backend.remote[today]?.sleepMinutes, 430)
        XCTAssertEqual(repo.syncState(on: today), .synced)
    }

    func testSexualActivityIsIncludedInOutboundDailyLogSyncPayload() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        repo.upsert(DailyLog(sexualActivity: true), on: today)
        await repo.drainPending()

        XCTAssertEqual(backend.remote[today]?.sexualActivity, true)
        XCTAssertEqual(repo.syncState(on: today), .synced)
    }

    func testFoodGroupsAreIncludedInOutboundDailyLogSyncPayload() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        repo.toggleFoodGroup(FoodGroup.vegetables.rawValue, on: today)
        await repo.drainPending()

        XCTAssertEqual(backend.remote[today]?.foodGroups, ["vegetables"])
        XCTAssertEqual(repo.syncState(on: today), .synced)
    }

    func testTogglingAFoodGroupTwiceRemovesIt() {
        let repo = DailyLogRepository(store: makeStore())
        let today = CalendarDate.today()

        repo.toggleFoodGroup(FoodGroup.fruit.rawValue, on: today)
        repo.toggleFoodGroup(FoodGroup.protein.rawValue, on: today)
        repo.toggleFoodGroup(FoodGroup.fruit.rawValue, on: today)

        XCTAssertEqual(repo.log(on: today).foodGroups, ["protein"])
    }

    /// ⚠️ The recipe card's "log this" button writes several groups at once, and the obvious
    /// implementation — call `toggleFoodGroup` per group — would *un*-log every group she had
    /// already ticked by hand before opening the recipe. A silent removal of her own data, by an
    /// action whose label says "log". `logFoodGroups` is additive for exactly that reason.
    func testLoggingARecipeAddsItsGroupsAndNeverRemovesOne() {
        let repo = DailyLogRepository(store: makeStore())
        let today = CalendarDate.today()

        repo.toggleFoodGroup(FoodGroup.fruit.rawValue, on: today)
        repo.logFoodGroups([FoodGroup.fruit.rawValue, FoodGroup.protein.rawValue], on: today)
        XCTAssertEqual(repo.log(on: today).foodGroups, ["fruit", "protein"])

        // A second tap means the same thing as the first.
        repo.logFoodGroups([FoodGroup.fruit.rawValue, FoodGroup.protein.rawValue], on: today)
        XCTAssertEqual(repo.log(on: today).foodGroups, ["fruit", "protein"])
    }

    /// Re-logging a recipe whose groups are all already recorded must not mark the day owed again.
    /// Every `upsert` queues a push, so without the no-op guard, reopening a recipe and tapping the
    /// button would put an unchanged day back in the sync queue and show her the unsynced badge
    /// over a day the server already has.
    func testReLoggingTheSameRecipeQueuesNothing() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        repo.logFoodGroups([FoodGroup.dairy.rawValue], on: today)
        await repo.drainPending()
        XCTAssertEqual(repo.syncState(on: today), .synced)

        repo.logFoodGroups([FoodGroup.dairy.rawValue], on: today)
        XCTAssertEqual(repo.syncState(on: today), .synced, "an unchanged day must not be re-queued")
    }

    func testFoodGroupsSurviveARelaunch() {
        let store = makeStore()
        let today = CalendarDate.today()
        DailyLogRepository(store: store).toggleFoodGroup(FoodGroup.dairy.rawValue, on: today)

        XCTAssertEqual(DailyLogRepository(store: store).log(on: today).foodGroups, ["dairy"])
    }

    /// Two surfaces now write the same day: food groups from Nutrition, everything else from the
    /// log sheet. `LogView.save` used to rebuild a whole `DailyLog` from its own `@State`, which
    /// resets every field it does not show — so saving a note after ticking off lunch would have
    /// erased lunch, silently and with no undo.
    ///
    /// This pins the repository half of the fix: a read-modify-write on the stored day, so neither
    /// surface can flatten the other.
    func testLoggingOneSurfaceDoesNotEraseTheOther() {
        let repo = DailyLogRepository(store: makeStore())
        let today = CalendarDate.today()

        repo.toggleFoodGroup(FoodGroup.vegetables.rawValue, on: today)
        var entry = repo.log(on: today)
        entry.mood = .good
        entry.notes = "long day"
        repo.upsert(entry, on: today)

        XCTAssertEqual(repo.log(on: today).foodGroups, ["vegetables"])
        XCTAssertEqual(repo.log(on: today).mood, .good)
    }

    /// Seed days into the store already marked owed, without any backend push — so `drainPending`
    /// is the only thing that talks to the backend and there is no fire-and-forget race to fight.
    private func seedPendingDailyLogs(store: LocalStore, _ logs: [CalendarDate: DailyLog]) {
        let seeder = DailyLogRepository(store: store, backend: nil)
        for (date, log) in logs { seeder.upsert(log, on: date) }
    }

    /// Offline stops the drain at the first owed day and keeps the rest queued, so a reconnect isn't
    /// spent firing writes that will all fail the same way.
    func testATransportFailureStopsTheDrainAndKeepsTheQueue() async {
        let store = makeStore()
        let older = CalendarDate.today().minusDays(1)
        let newer = CalendarDate.today()
        seedPendingDailyLogs(store: store, [older: DailyLog(waterMl: 100), newer: DailyLog(waterMl: 200)])

        let backend = DrainProbeDailyLogBackend()
        backend.transportFail = true
        let repo = DailyLogRepository(store: store, backend: backend)
        await repo.drainPending()

        XCTAssertEqual(backend.attempts, 1, "offline should stop after the first owed day, not walk the whole queue")
        XCTAssertEqual(repo.syncState(on: older), .pendingSync)
        XCTAssertEqual(repo.syncState(on: newer), .pendingSync)

        backend.transportFail = false
        await repo.drainPending()
        XCTAssertEqual(repo.syncState(on: older), .synced)
        XCTAssertEqual(repo.syncState(on: newer), .synced)
    }

    /// No session is the same answer for every day in the queue, so it must stop the drain like
    /// being offline does — not be mistaken for the server rejecting each day in turn.
    ///
    /// `requireUID` throws `notAuthenticated` before a request ever leaves the device, and that is
    /// not a `URLError` — so the first cut of the step-over-a-rejection change read it as "this one
    /// day is poison" and stepped over it. The drain then walked the whole backlog making one
    /// doomed call per owed day, every foreground, for as long as the session was missing. Two days
    /// here; it would have been however many she logged offline.
    ///
    /// Caught before release: the shipped build stops the drain on any failure at all, so this case
    /// was covered for free until stepping over rejections stopped covering it.
    func testAMissingSessionStopsTheDrainInsteadOfWalkingTheWholeQueue() async {
        let store = makeStore()
        let older = CalendarDate.today().minusDays(1)
        let newer = CalendarDate.today()
        seedPendingDailyLogs(store: store, [older: DailyLog(waterMl: 100), newer: DailyLog(waterMl: 200)])

        let backend = DrainProbeDailyLogBackend()
        backend.authFail = true
        let repo = DailyLogRepository(store: store, backend: backend)
        await repo.drainPending()

        XCTAssertEqual(backend.attempts, 1, "no session should stop after the first owed day, not walk the whole queue")
        XCTAssertEqual(repo.syncState(on: older), .pendingSync)
        XCTAssertEqual(repo.syncState(on: newer), .pendingSync)

        // And nothing was lost by stopping: once she is signed in, the same queue drains whole.
        backend.authFail = false
        await repo.drainPending()
        XCTAssertEqual(repo.syncState(on: older), .synced)
        XCTAssertEqual(repo.syncState(on: newer), .synced)
        XCTAssertEqual(backend.remote[older]?.waterMl, 100)
        XCTAssertEqual(backend.remote[newer]?.waterMl, 200)
    }

    /// The regression guard: a day the server permanently rejects must not wall off the newer days
    /// queued behind it. Under the old break-on-any-failure it did, stalling every future sync.
    func testAServerRejectedDayIsSteppedOverSoNewerDaysStillSync() async {
        let store = makeStore()
        let poisoned = CalendarDate.today().minusDays(1)   // sorts first — the head of the queue
        let good = CalendarDate.today()
        seedPendingDailyLogs(store: store, [poisoned: DailyLog(waterMl: 100), good: DailyLog(waterMl: 200)])

        let backend = DrainProbeDailyLogBackend()
        backend.reject = poisoned
        let repo = DailyLogRepository(store: store, backend: backend)
        await repo.drainPending()

        XCTAssertEqual(backend.attempts, 2, "both days must be attempted — the poisoned one can't short-circuit the drain")
        XCTAssertEqual(repo.syncState(on: good), .synced)
        XCTAssertEqual(backend.remote[good]?.waterMl, 200)
        XCTAssertEqual(repo.syncState(on: poisoned), .pendingSync, "the rejected day stays owed for a later retry")
        XCTAssertNil(backend.remote[poisoned])
    }

    /// Same guard on the pH queue: a rejected reading is stepped over so the newer ones still land.
    func testAServerRejectedPhReadingIsSteppedOverSoNewerOnesStillSync() async {
        let store = makeStore()
        // Seed two owed readings with no backend push. `PhSync.pending` sorts on (updatedAt, id);
        // the "aaaa" id makes the poisoned one the head even if the two timestamps tie.
        let seeder = PhRepository(store: store, backend: nil)
        seeder.create(PhReading(id: "aaaa-poison", phValue: 6.0, recordedAt: Date().addingTimeInterval(-100)))
        seeder.create(PhReading(id: "bbbb-good", phValue: 6.5, recordedAt: Date()))

        let backend = ProbePhBackend(reject: "aaaa-poison")
        let repo = PhRepository(store: store, backend: backend)
        await repo.drainPending()

        XCTAssertTrue(backend.remote.contains { $0.id == "bbbb-good" }, "the good reading must get past the poisoned one")
        XCTAssertFalse(backend.remote.contains { $0.id == "aaaa-poison" }, "the rejected reading is not stored")
    }

    func testSexualActivitySurvivesARelaunch() {
        let store = makeStore()
        let today = CalendarDate.today()
        DailyLogRepository(store: store).upsert(DailyLog(sexualActivity: true), on: today)

        XCTAssertTrue(DailyLogRepository(store: store).log(on: today).sexualActivity)
    }

    /// Covered in bulk by `testSignOutClearsLocalHealthData`, and pinned separately anyway: this is
    /// the most sensitive thing she records, and a future change that clears logs field-by-field
    /// rather than by key should fail loudly here rather than leave it on the device for whoever
    /// signs in next.
    func testSignOutClearsSexualActivity() {
        let store = makeStore()
        let c = AppContainer(store: store, backend: nil)
        c.dailyLog.upsert(DailyLog(sexualActivity: true), on: .today())

        c.session.signOut()

        XCTAssertFalse(c.dailyLog.log(on: .today()).sexualActivity)
        XCTAssertFalse(DailyLogRepository(store: store).log(on: .today()).sexualActivity)
    }

    func testHydrationRestoresFromBackendDailyLogList() async {
        let backend = FakeDailyLogBackend()
        let today = CalendarDate.today()
        backend.remote[today] = DailyLog(waterMl: 2_250)
        let repo = DailyLogRepository(store: makeStore(), backend: backend)

        await repo.refresh()

        XCTAssertEqual(repo.waterMl(on: today), 2_250)
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

    /// The v1.2 data-loss defect. `PhRecord.dto` dropped `measurementType`, so a cold start decoded
    /// every saved reading as legacy urine and the tracker hid the lot — "No pH readings yet", with
    /// the calendar markers and the logging streak going with it. The other pH tests all read back
    /// from the same live instance, which is why they never saw it; a second repository over the
    /// same store is the relaunch.
    func testPhReadingsSurviveARelaunch() {
        let store = makeStore()
        let recordedAt = Date(timeIntervalSince1970: 1_000_000)
        PhRepository(store: store).create(PhReading(id: "x", phValue: 4.2, recordedAt: recordedAt, measurementType: .vaginal))

        let relaunched = PhRepository(store: store)

        XCTAssertEqual(relaunched.readings.map(\.phValue), [4.2], "her pH history must survive a cold start")
        XCTAssertEqual(relaunched.readings.first?.measurementType, .vaginal)
    }

    /// The other half of that invariant, so the fix can't be "treat an absent type as vaginal":
    /// builds 12–13 recorded real readings on the urine scale, and dragging those into the vaginal
    /// trend would corrupt her fertility reading and the shared backend Android also pulls from.
    func testLegacyUrineReadingsStayHiddenAcrossARelaunch() {
        let store = makeStore()
        let legacy = PhReadingDTO(id: "legacy", phValue: 6.5, recordedAt: Date(timeIntervalSince1970: 1_000_000))
        store.save([legacy], forKey: "ph_readings")

        XCTAssertTrue(PhRepository(store: store).readings.isEmpty, "a pre-migration urine row stays hidden")
    }

    /// A first launch must land on the designed light palette, not on whatever scheme the phone
    /// happens to be in.
    func testThemeDefaultsToLightBeforeAnyChoice() {
        XCTAssertEqual(PreferencesRepository(store: makeStore()).themeMode, .light)
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

    /// Stored as what she muted, not what she kept — so a category shipped in a later build arrives
    /// switched on, rather than silently off for everyone who upgraded.
    func testEveryNotificationCategoryStartsOnAndMutingSurvivesRelaunch() {
        let store = makeStore()
        XCTAssertTrue(PreferencesRepository(store: store).mutedNotifications.isEmpty)

        let prefs = PreferencesRepository(store: store)
        prefs.mutedNotifications = [.ph, .milestones]

        XCTAssertEqual(PreferencesRepository(store: store).mutedNotifications, [.ph, .milestones])
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

    /// The client's "offline symbol appears and stays". `syncState` reads the owed-days set, so the
    /// save draws the unsynced badge and the push that clears it a moment later has to announce
    /// itself — otherwise the icon sits over a day the server already has until some unrelated edit
    /// happens to redraw the row.
    func testDrainingTheLastOwedDayRedrawsTheRow() async {
        let store = makeStore()
        DailyLogRepository(store: store).setWater(500)     // local-only: owed, and no push in flight
        let repo = DailyLogRepository(store: store, backend: FakeDailyLogBackend())
        XCTAssertEqual(repo.syncState(on: .today()), .pendingSync)

        var redraws = 0
        let watch = repo.objectWillChange.sink { _ in redraws += 1 }
        await repo.drainPending()
        watch.cancel()

        XCTAssertEqual(repo.syncState(on: .today()), .synced)
        XCTAssertGreaterThan(redraws, 0, "nothing told the row its day had landed")
    }

    // MARK: - Connectivity

    /// The other half of the client's complaint, and the part the redraw fix did not touch: the
    /// badge said "Will sync when online" over an app that was plainly online. An unsynced row is a
    /// fact about the row; only the offline case may mention the network.
    func testTheUnsyncedBadgeOnlyBlamesTheNetworkWhenSheIsActuallyOffline() {
        XCTAssertEqual(DailyLogSyncState.pendingSync.label(online: true), "Saved on this phone")
        XCTAssertFalse(DailyLogSyncState.pendingSync.label(online: true).lowercased().contains("online"),
                       "a working connection must never be described to her as being offline")
        XCTAssertTrue(DailyLogSyncState.pendingSync.label(online: false).lowercased().contains("online"))
        // And the two settled states say the same thing either way — connectivity explains an
        // unsynced row, it does not re-describe a synced one.
        XCTAssertEqual(DailyLogSyncState.synced.label(online: false), DailyLogSyncState.synced.label(online: true))
        XCTAssertEqual(DailyLogSyncState.saved.label(online: false), DailyLogSyncState.saved.label(online: true))
    }

    /// A reconnect is the moment the backlog can actually move. Before this the only trigger was
    /// foregrounding the app, so a phone that stayed in her hand through a dead-spot kept its queue.
    func testComingBackOnlineDrainsTheQueueWithoutWaitingForAForeground() async {
        let reachability = Reachability(monitoring: false)
        let drained = expectation(description: "coming back online drains the queue")
        var drains = 0
        reachability.onReconnect = { @MainActor in
            drains += 1
            drained.fulfill()
        }

        reachability.simulate(online: false)
        XCTAssertFalse(reachability.isOnline)
        XCTAssertEqual(drains, 0, "going offline is not a reason to retry")

        reachability.simulate(online: true)
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertTrue(reachability.isOnline)

        // Wi-Fi to cellular re-reports `.satisfied` without ever leaving it; that is not a reconnect
        // and must not fire a second walk of the whole queue.
        reachability.simulate(online: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(drains, 1, "a repeated online report is not a reconnect")
    }

    /// `NWPathMonitor` says nothing until its queue first runs, so a monitor that started at
    /// `false` would flash "offline" across every cold launch — the exact false alarm being fixed.
    func testConnectivityStartsOptimisticSoALaunchNeverFlashesOffline() {
        XCTAssertTrue(Reachability(monitoring: false).isOnline)
    }

    /// The log-loss question itself, end to end and across a relaunch: she logs with no usable
    /// connection, the app is killed, and the day must still reach the server afterwards. The
    /// existing drain tests all reuse one live repository, so none of them crosses the process
    /// boundary — and this queue is the only record that the day is owed.
    ///
    /// Two days, not one, and that is the point. `pendingDates` falls back to "every logged day is
    /// owed" when the key is absent, which is right for a v1.0 install but would also mask a broken
    /// save: with a single day the fallback alone passes this test. The synced day is the control —
    /// it can only still read `.synced` after the relaunch if the set was genuinely persisted.
    func testADayLoggedOfflineSurvivesARelaunchAndStillReachesTheServer() async {
        let store = makeStore()
        let today = CalendarDate.today()
        let alreadySynced = today.minusDays(2)
        let backend = DrainProbeDailyLogBackend()

        let beforeCrash = DailyLogRepository(store: store, backend: backend)
        beforeCrash.upsert(DailyLog(waterMl: 400), on: alreadySynced)
        await beforeCrash.drainPending()
        XCTAssertEqual(beforeCrash.syncState(on: alreadySynced), .synced)

        backend.transportFail = true                    // she walks into a dead-spot
        beforeCrash.upsert(DailyLog(mood: .good, symptoms: ["Cramps"], waterMl: 900), on: today)
        await beforeCrash.drainPending()
        XCTAssertEqual(beforeCrash.syncState(on: today), .pendingSync)
        XCTAssertNil(backend.remote[today], "nothing can have reached the server yet")

        // Relaunch: a brand-new repository over the same store, nothing carried in memory.
        let afterRelaunch = DailyLogRepository(store: store, backend: backend)
        XCTAssertEqual(afterRelaunch.log(on: today).waterMl, 900, "the day itself must survive")
        XCTAssertEqual(afterRelaunch.syncState(on: today), .pendingSync, "and must still be known to be owed")
        XCTAssertEqual(afterRelaunch.syncState(on: alreadySynced), .synced,
                       "the owed set itself must survive — not be rebuilt from 'everything is owed'")

        backend.transportFail = false
        await afterRelaunch.drainPending()

        XCTAssertEqual(afterRelaunch.syncState(on: today), .synced)
        XCTAssertEqual(backend.remote[today]?.waterMl, 900)
        XCTAssertEqual(backend.remote[today]?.mood, .good)
        XCTAssertEqual(backend.remote[today]?.symptoms, ["Cramps"])
    }

    /// Losing the connection mid-session must not lose the edit made during it, and the recovery
    /// must carry the *newest* value — not the one that was in flight when the network died.
    func testAnEditMadeWhileOfflineIsNotOverwrittenByTheServerOnReconnect() async {
        let store = makeStore()
        let today = CalendarDate.today()
        let backend = DrainProbeDailyLogBackend()
        let repo = DailyLogRepository(store: store, backend: backend)

        repo.setWater(500, on: today)
        await repo.drainPending()
        XCTAssertEqual(backend.remote[today]?.waterMl, 500)

        backend.transportFail = true
        repo.setWater(1_500, on: today)              // her correction, made in a dead-spot
        await repo.drainPending()
        XCTAssertEqual(repo.syncState(on: today), .pendingSync)

        backend.transportFail = false
        await repo.refresh()                         // pushes what is owed, then pulls

        XCTAssertEqual(repo.waterMl(on: today), 1_500, "a pull must not replace her correction with the stale copy")
        XCTAssertEqual(backend.remote[today]?.waterMl, 1_500)
        XCTAssertEqual(repo.syncState(on: today), .synced)
    }

    // MARK: - Auth

    /// With "Confirm email" on, Supabase's sign-up returns a user but no session. She is not signed
    /// in until she clicks the link — claiming otherwise would leave every write failing the
    /// server's auth check while the UI insisted all was well.
    func testSignUpWithoutASessionDoesNotSignHerIn() async {
        let auth = FakeAuthBackend()
        auth.grantsSessionOnSignUp = false          // the project requires email confirmation
        let session = SessionRepository(store: makeStore(), auth: auth)

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
        let session = SessionRepository(store: makeStore(), auth: FakeAuthBackend())   // confirmation off: session granted

        try await session.authenticate(email: "a@b.com", password: "password123", name: "Ada", signUp: true)

        XCTAssertTrue(session.isSignedIn)
        XCTAssertEqual(session.displayName, "Ada")
    }

    /// The Supabase SDK restores the session across a relaunch, but her name and address were only
    /// ever held in memory — so a returning user was greeted as "Guest", and Personal Details
    /// opened prefilled with that word ready to be saved over her real name.
    func testHerNameAndAddressSurviveARelaunch() async throws {
        let store = makeStore()
        let auth = FakeAuthBackend()
        try await SessionRepository(store: store, auth: auth)
            .authenticate(email: "ada@x.com", password: "password123", name: "Ada", signUp: false)

        let relaunched = SessionRepository(store: store, auth: auth)   // SDK restored the session

        XCTAssertTrue(relaunched.isSignedIn)
        XCTAssertEqual(relaunched.displayName, "Ada")
        XCTAssertEqual(relaunched.email, "ada@x.com")
    }

    /// Sign-in never asks for a name, so a re-authentication carries none. Falling straight through
    /// to the address renamed her to the part before the @ every time her session was refreshed.
    func testSigningInAgainDoesNotRenameHerToHerEmail() async throws {
        let session = SessionRepository(store: makeStore(), auth: FakeAuthBackend())
        try await session.authenticate(email: "ada@x.com", password: "password123", name: "Ada", signUp: false)

        try await session.authenticate(email: "ada@x.com", password: "password123", name: nil, signUp: false)

        XCTAssertEqual(session.displayName, "Ada")
    }

    /// Sign-out leaves the app usable — onboarding does not re-run, so the tabs are still there and
    /// every write queues. Those writes belong to whoever last held the session, and hydrating them
    /// into the next account files one person's cycle and logs into another person's history.
    func testADifferentAccountSigningInWipesTheDeviceFirst() async throws {
        let store = makeStore()
        let auth = FakeAuthBackend()
        var wipes = 0

        let first = SessionRepository(store: store, auth: auth)
        first.onClearLocalState = { wipes += 1 }
        try await first.authenticate(email: "ada@x.com", password: "password123", name: "Ada", signUp: false)
        let afterFirstSignIn = wipes                       // a fresh device has no identity yet

        auth.signInUserId = "user-2"
        let second = SessionRepository(store: store, auth: auth)
        second.onClearLocalState = { wipes += 1 }
        try await second.authenticate(email: "bea@x.com", password: "password123", name: "Bea", signUp: false)

        XCTAssertEqual(wipes, afterFirstSignIn + 1, "a second account must not inherit the first one's data")
        XCTAssertEqual(second.displayName, "Bea", "and must not inherit her name either")
    }

    /// Onboarding runs before the account exists — the quiz, her cycle dates and anything she logged
    /// while deciding are all on the device before she ever signs up. A device that has never held a
    /// session has no previous owner, so there is nothing to protect anyone from by wiping it.
    func testHerFirstEverSignInKeepsWhatSheEnteredDuringOnboarding() async throws {
        let container = AppContainer(store: makeStore(), backend: nil)
        container.prefs.recordQuizAnswers(["stage": "trying"])
        container.cycle.upsert(CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 28, periodLength: 5))

        try await container.session.authenticate(email: "ada@x.com", password: "password123", name: "Ada", signUp: true)

        XCTAssertEqual(container.prefs.quizAnswers, ["stage": "trying"])
        XCTAssertNotNil(container.cycle.settings, "her first sign-in must not throw away her onboarding")
    }

    func testTheSameAccountSigningInAgainKeepsHerData() async throws {
        let store = makeStore()
        let auth = FakeAuthBackend()
        try await SessionRepository(store: store, auth: auth)
            .authenticate(email: "ada@x.com", password: "password123", name: "Ada", signUp: false)

        var wipes = 0
        let again = SessionRepository(store: store, auth: auth)
        again.onClearLocalState = { wipes += 1 }
        try await again.authenticate(email: "ada@x.com", password: "password123", name: nil, signUp: false)

        XCTAssertEqual(wipes, 0, "signing back in as yourself must not wipe your own logs")
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

    /// A drain reads the settings, awaits the server, then marks them synced. Correcting the date in
    /// that window used to clear the flag for a value the server had never been sent — so the next
    /// pull quietly replaced her correction with the copy the drain had just uploaded.
    func testACorrectionMadeDuringADrainIsStillOwed() async {
        let store = makeStore()
        let first = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 28, periodLength: 5)
        let corrected = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 3), cycleLength: 28, periodLength: 5)
        CycleRepository(store: store).upsert(first)          // local-only: owed, and no push in flight

        let backend = MidDrainCycleBackend()
        backend.refuse = corrected                           // her correction's own push can't get out
        let repo = CycleRepository(store: store, backend: backend)
        backend.duringUpsert = { repo.upsert(corrected) }
        await repo.drainPending()

        XCTAssertEqual(backend.remote, first, "the server only ever received the value the drain sent")

        await repo.refresh()

        XCTAssertEqual(repo.settings, corrected, "a correction the server never got must not be pulled away")
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

    /// The light default shipped, and still nobody who already had an account could see it. A first
    /// sync seeds the profile row from the device, so every account made before `560591e` stored the
    /// old `.system` default as though she had asked for it — and pulling that down put her back in
    /// dark on a dark phone. Corrected once, in the row as well as on the device.
    func testTheOldSystemDefaultDoesNotOverrideTheLightPaletteOnAnExistingAccount() async {
        let backend = FakeProfileBackend()
        backend.remote = ProfilePrefs(focusMode: .prep, themeMode: .system, pushEnabled: false)
        let repo = PreferencesRepository(store: makeStore(), backend: backend)

        await repo.refresh()
        XCTAssertEqual(repo.themeMode, .light, "she never chose `.system` — it was the old default")

        await repo.refresh()                               // drains the correction it owes
        XCTAssertEqual(backend.remote?.themeMode, .light,
                       "the artifact has to leave the row too, or the next pull reinstates it")
    }

    /// The other half of that fix, and the reason it keys on `.system` alone: dark is a scheme she
    /// had to open Profile and pick. Resetting it would be the same overreach in the other direction.
    func testADarkThemeSheActuallyChoseSurvivesTheMigration() async {
        let backend = FakeProfileBackend()
        backend.remote = ProfilePrefs(focusMode: .prep, themeMode: .dark, pushEnabled: false)
        let repo = PreferencesRepository(store: makeStore(), backend: backend)

        await repo.refresh()

        XCTAssertEqual(repo.themeMode, .dark)
    }

    /// One-shot, not a standing rule. Once the legacy value is cleared, `.system` goes back to being
    /// an ordinary preference — otherwise picking "match my phone" would silently never stick.
    func testSystemStaysChosenWhenShePicksItAfterTheMigration() async {
        let backend = FakeProfileBackend()
        backend.remote = ProfilePrefs(focusMode: .prep, themeMode: .system, pushEnabled: false)
        let store = makeStore()
        let repo = PreferencesRepository(store: store, backend: backend)
        await repo.refresh()                               // migration runs here

        repo.themeMode = .system                           // now she asks for it herself
        await repo.refresh()

        XCTAssertEqual(repo.themeMode, .system)
        XCTAssertEqual(PreferencesRepository(store: store, backend: backend).themeMode, .system,
                       "and it survives the relaunch that used to re-run the correction")
    }

    /// The whole of T8: the quiz is answered *before* she has an account, so at the moment she
    /// answers there is no session to write under. The answers have to sit on the device, owed to
    /// the server, until sign-in provides a user id — which is exactly the offline case the other
    /// repositories already handle, so it is handled the same way.
    func testQuizAnswersGivenBeforeSignInStillReachTheProfile() async {
        let backend = FakeProfileBackend()
        backend.online = false                             // no session yet: every write is refused
        let repo = PreferencesRepository(store: makeStore(), backend: backend)

        repo.recordQuizAnswers(["stage": "trying", "gender": "private"])
        XCTAssertNil(backend.remote, "there is nobody to write them under yet")

        backend.online = true                              // she signs in
        await repo.refresh()

        XCTAssertEqual(backend.remote?.quizAnswers, ["stage": "trying", "gender": "private"])
    }

    /// T7's real assertion: a skipped question must reach the server as *absent*, not as an option
    /// id standing in for silence. The danger is the reverse of the usual one — nothing is lost by
    /// skipping, so the only way to fail is to invent an answer she never gave.
    func testASkippedQuestionIsNeitherStoredNorInvented() async {
        let backend = FakeProfileBackend()
        let repo = PreferencesRepository(store: makeStore(), backend: backend)

        repo.recordQuizAnswers(["stage": "trying", "cycle": "mostly", "supplements": "no", "support": "nutrition"])
        await repo.refresh()

        XCTAssertNil(repo.quizAnswers["gender"], "skipping must leave no local answer")
        XCTAssertNil(backend.remote?.quizAnswers["gender"], "and none on the server either")
        XCTAssertEqual(backend.remote?.quizAnswers.count, 4, "the four she did answer still arrive")
    }

    /// Answering and then going back to skip has to erase, not merely stop re-writing. The push
    /// replaces `quiz_answers.answers` wholesale, so an answer dropped locally is dropped remotely.
    func testChangingHerMindToSkipClearsTheAnswerEverywhere() async {
        let backend = FakeProfileBackend()
        let store = makeStore()
        let repo = PreferencesRepository(store: store, backend: backend)

        repo.recordQuizAnswers(["stage": "trying", "gender": "girl"])
        await repo.refresh()
        repo.recordQuizAnswers(["stage": "trying"])
        await repo.refresh()

        XCTAssertNil(backend.remote?.quizAnswers["gender"], "the answer she withdrew must not survive")
        XCTAssertNil(PreferencesRepository(store: store).quizAnswers["gender"],
                     "nor come back on the next launch")
    }

    func testQuizAnswersSurviveARelaunchBeforeSheEverSignsIn() {
        let store = makeStore()
        PreferencesRepository(store: store).recordQuizAnswers(["stage": "preparing"])

        XCTAssertEqual(PreferencesRepository(store: store).quizAnswers, ["stage": "preparing"])
    }

    /// Sign-out does not re-run onboarding — that flag is device-local and stays set — so nothing
    /// would ever overwrite these. Left behind, the next user on the phone silently inherits what
    /// the previous one said about her conception journey.
    func testSignOutWipesTheQuizAnswers() {
        let container = AppContainer(store: makeStore(), backend: nil)
        container.prefs.recordQuizAnswers(["gender": "hope"])

        container.session.signOut()

        XCTAssertTrue(container.prefs.quizAnswers.isEmpty,
                      "her intake answers are as personal as a log and must leave with her")
    }

    /// The owed-write flag outlived the session that owed it. Left set, the next account's first
    /// refresh pushed *her* theme, focus mode and push setting into *their* profile row, then pulled
    /// the clobbered values straight back down.
    func testAProfileWriteSheOwedDoesNotFollowHerOutOfTheApp() async {
        let backend = FakeProfileBackend()
        backend.online = false                             // her push fails and stays owed
        let prefs = PreferencesRepository(store: makeStore(), backend: backend)
        prefs.focusMode = .pregnancy

        prefs.clearOwedProfileWrite()                      // what sign-out now does

        backend.online = true
        backend.remote = ProfilePrefs(focusMode: .prep, themeMode: .light, pushEnabled: true)
        await prefs.refresh()                              // the next account's first hydrate

        XCTAssertEqual(backend.remote?.focusMode, .prep, "the previous user's setting must not land in this row")
        XCTAssertEqual(prefs.focusMode, .prep)
    }

    /// `profiles` is partner-readable — `profiles_select` grants a linked partner the whole row —
    /// and Postgres RLS filters rows, never columns. So the only way to keep answers the quiz calls
    /// "just for you" out of his reach is to keep them out of that row entirely.
    func testTheProfileRowNeverCarriesHerQuizAnswers() throws {
        var prefs = ProfilePrefs(focusMode: .prep, themeMode: .dark, pushEnabled: true)
        prefs.quizAnswers = ["stage": "trying", "gender": "private"]

        XCTAssertFalse(try encodedColumns(ProfilePrefsRow(id: "u", prefs: prefs)).contains("quiz_answers"),
                       "a partner can read this row; her intake answers must live in their own table")
    }

    /// A device with no answers has *nothing to say* about the quiz, which is not the same as
    /// saying she answered nothing — onboarding runs once, so most installs are in that state. If
    /// an empty set were written, one theme toggle on a reinstalled phone would erase what she
    /// answered before.
    func testAnEmptyAnswerSetIsNotWrittenAtAll() {
        XCTAssertNil(QuizAnswersRow(userId: "u", answers: [:]),
                     "an empty set must not be sent, or it overwrites the server's copy")
        XCTAssertEqual(QuizAnswersRow(userId: "u", answers: ["stage": "trying"])?.answers,
                       ["stage": "trying"])
    }

    /// The column names a row actually writes — an omitted key leaves the server's value alone,
    /// which is the difference this test exists to see.
    private func encodedColumns<T: Encodable>(_ row: T) throws -> Set<String> {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(row))
        guard let object = json as? [String: Any] else { return [] }
        return Set(object.keys)
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
        XCTAssertFalse(LearnReadLog.readSlugs().contains("first-week"),
                       "the next user has not read the previous user's articles")
        XCTAssertTrue(PreferencesRepository(store: store).celebratedMilestones.isEmpty,
                      "and it must not come back from the store on next launch")
    }

    /// Sign-out must also wipe locally-stored custom supplements — they are user-entered and as
    /// personal as a log, so the next user on the device must not inherit them.
    func testSignOutClearsCustomSupplements() {
        let key = CustomSupplement.storageKey
        let saved = UserDefaults.standard.string(forKey: key)
        defer { if let saved { UserDefaults.standard.set(saved, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) } }

        let container = AppContainer(store: makeStore(), backend: nil)
        UserDefaults.standard.set(CustomSupplement.encodeList([
            CustomSupplement(name: "Magnesium", dose: "200 mg", time: "Evening")
        ]), forKey: key)
        XCTAssertFalse(CustomSupplement.decodeList(UserDefaults.standard.string(forKey: key) ?? "[]").isEmpty)

        container.session.signOut()

        XCTAssertTrue(CustomSupplement.decodeList(UserDefaults.standard.string(forKey: key) ?? "[]").isEmpty,
                      "custom supplements must not survive sign-out")
    }

    /// No supplement is reminded about until she says so, and what she chose has to survive a
    /// relaunch — a reminder time that quietly forgot itself would be worse than never offering one.
    func testSupplementRemindersStartEmptyAndSurviveRelaunch() {
        let store = makeStore()
        XCTAssertTrue(PreferencesRepository(store: store).supplementReminders.isEmpty)

        let prefs = PreferencesRepository(store: store)
        prefs.supplementReminders["mag"] = 8

        XCTAssertEqual(PreferencesRepository(store: store).supplementReminders, ["mag": 8])
    }

    /// They are keyed to supplements that are themselves wiped on sign-out. Left behind, the next
    /// user on this device would be woken at 8am for someone else's magnesium.
    func testSignOutClearsSupplementReminders() {
        let store = makeStore()
        let container = AppContainer(store: store, backend: nil)
        container.prefs.supplementReminders["mag"] = 8

        container.session.signOut()

        XCTAssertTrue(container.prefs.supplementReminders.isEmpty)
        XCTAssertTrue(PreferencesRepository(store: store).supplementReminders.isEmpty,
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

/// A distinct, non-transport error so a rejection is classified as poison rather than "offline".
private enum DrainProbeError: Error { case serverRejected }

/// Lets a drain test choose, per call, between an offline-style transport failure (`URLError`), a
/// missing session (`RemoteError.notAuthenticated`, what `requireUID` throws) and a server-side
/// rejection of one specific day, and counts how many upserts the drain actually made.
@MainActor
private final class DrainProbeDailyLogBackend: DailyLogBackend {
    var remote: [CalendarDate: DailyLog] = [:]
    var transportFail = false
    var authFail = false
    var reject: CalendarDate?
    private(set) var attempts = 0

    func fetch(date: CalendarDate) async throws -> DailyLog? { remote[date] }
    func list() async throws -> [CalendarDate: DailyLog] { remote }

    func upsert(_ log: DailyLog, on date: CalendarDate) async throws {
        attempts += 1
        if transportFail { throw URLError(.notConnectedToInternet) }
        if authFail { throw RemoteError.notAuthenticated }
        if date == reject { throw DrainProbeError.serverRejected }
        remote[date] = log
    }
}

/// Rejects one reading id with a non-transport error; stores every other reading.
@MainActor
private final class ProbePhBackend: PhBackend {
    var remote: [PhRecord] = []
    var reject: String?

    init(reject: String? = nil) { self.reject = reject }

    func list(sinceDays: Int?) async throws -> [PhRecord] { remote }

    func upsert(_ record: PhRecord) async throws {
        if record.id == reject { throw DrainProbeError.serverRejected }
        remote = remote.filter { $0.id != record.id } + [record.marking(pendingSync: false)]
    }
}

/// `grantsSessionOnSignUp = false` reproduces a project with "Confirm email" turned on: sign-up
/// succeeds, but no session exists until she clicks the link.
@MainActor
private final class FakeAuthBackend: AuthBackend {
    var currentUserId: String?
    var grantsSessionOnSignUp = true
    /// Who the next sign-in lands as, so a second account on the same device can be exercised.
    var signInUserId = "user-1"

    func signUp(email: String, password: String) async throws {
        if grantsSessionOnSignUp { currentUserId = signInUserId }
    }

    func signIn(email: String, password: String) async throws { currentUserId = signInUserId }
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

/// Runs `duringUpsert` while an upsert is in flight, so a test can reproduce her correcting the
/// date in the window between the drain reading the settings and the server accepting them.
/// `refuse` stands in for that correction's own push failing while she is still offline.
@MainActor
private final class MidDrainCycleBackend: CycleBackend {
    var remote: CycleSettings?
    var refuse: CycleSettings?
    var duringUpsert: (() -> Void)?

    func fetch() async throws -> CycleSettings? { remote }

    func upsert(_ settings: CycleSettings) async throws {
        if settings == refuse { throw URLError(.notConnectedToInternet) }
        remote = settings
        duringUpsert?()
        duringUpsert = nil
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
