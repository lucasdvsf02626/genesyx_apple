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

    func testDailyLogRemoteRowCarriesSleepMinutes() throws {
        let date = CalendarDate(2026, 7, 16)
        let row = DailyLogRow(
            userId: "user-1",
            date: date,
            log: DailyLog(sleepMinutes: 455, waterMl: 1_200)
        )
        let data = try JSONEncoder().encode(row)
        let payload = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(payload.contains("\"sleep_minutes\":455"), payload)
        XCTAssertEqual(row.domain.sleepMinutes, 455)
    }

    func testPhReadingDTORoundTrip() {
        let r = PhReading(id: "abc", phValue: 6.8, recordedAt: Date(timeIntervalSince1970: 1_000_000), notes: "am")
        XCTAssertEqual(r.dto.domain, r)
    }

    // MARK: measurement_type (vaginal pH migration)

    func testRemoteRowSendsVaginalMeasurementType() throws {
        let reading = PhReading(id: "x", phValue: 4.2, recordedAt: Date(timeIntervalSince1970: 1_000_000), measurementType: .vaginal)
        let row = PhReadingRow(userId: "u", record: PhRecord(reading: reading, updatedAt: Date(timeIntervalSince1970: 1_000_000), pendingSync: false))
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(row), encoding: .utf8))
        XCTAssertTrue(json.contains("\"measurement_type\":\"vaginal\""), json)
    }

    func testRemoteRowMissingMeasurementTypeDecodesAsUrine() throws {
        // A row from before the column existed decodes as legacy urine — never vaginal.
        let json = #"{"id":"x","user_id":"u","ph_value":6.5,"recorded_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}"#
        let row = try JSONDecoder().decode(PhReadingRow.self, from: Data(json.utf8))
        XCTAssertEqual(row.domain.reading.measurementType, .urine)
    }

    func testLocalDTODefaultsLegacyUrineWhenFieldAbsent() {
        // An old on-device row (no measurementType) maps to urine.
        let dto = PhReadingDTO(id: "x", phValue: 6.5, recordedAt: Date())
        XCTAssertEqual(dto.domain.measurementType, .urine)
    }

    func testLocalDTORoundTripPreservesVaginal() throws {
        let reading = PhReading(phValue: 4.2, recordedAt: Date(timeIntervalSince1970: 1_000_000), measurementType: .vaginal)
        let data = try JSONEncoder().encode(reading.dto)
        XCTAssertTrue(try XCTUnwrap(String(data: data, encoding: .utf8)).contains("\"measurementType\":\"vaginal\""))
        let decoded = try JSONDecoder().decode(PhReadingDTO.self, from: data)
        XCTAssertEqual(decoded.domain.measurementType, .vaginal)
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
