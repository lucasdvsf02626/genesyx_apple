import XCTest
@testable import Genesyx
import GenesyxCore

/// DTO round-trips + `LocalStore` read/write. Runs under the GenesyxAppTests target (⌘U / xcodebuild test).
final class PersistenceTests: XCTestCase {

    private func makeStore() -> LocalStore {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return LocalStore(defaults: defaults)
    }

    func testDailyLogDTORoundTrip() {
        let log = DailyLog(
            mood: .good, energy: .high, symptoms: ["Cramps", "Fatigue"],
            sleepMinutes: 420, supplements: ["Iron"], notes: "felt good", waterMl: 750
        )
        XCTAssertEqual(log.dto.domain, log)
    }

    func testDailyLogDTOEmptyRoundTrip() {
        let log = DailyLog()
        XCTAssertEqual(log.dto.domain, log)
    }

    func testPhReadingDTORoundTrip() {
        let r = PhReading(id: "abc", phValue: 6.8, recordedAt: Date(timeIntervalSince1970: 1_000_000), notes: "am")
        XCTAssertEqual(r.dto.domain, r)
    }

    func testLocalStoreSaveLoadCodable() {
        let store = makeStore()
        let settings = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 30, periodLength: 4)
        store.save(settings, forKey: "k")
        XCTAssertEqual(store.load(CycleSettings.self, forKey: "k"), settings)
    }

    func testLocalStorePrimitivesAndRemoval() {
        let store = makeStore()
        XCTAssertTrue(store.bool(forKey: "missing", default: true))
        store.setBool(false, forKey: "flag")
        XCTAssertFalse(store.bool(forKey: "flag", default: true))
        store.setString("hi", forKey: "s")
        XCTAssertEqual(store.string(forKey: "s"), "hi")
        store.remove(forKey: "s")
        XCTAssertNil(store.string(forKey: "s"))
    }
}
