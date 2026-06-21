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
}
