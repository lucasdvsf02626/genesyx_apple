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

    // MARK: sexual_activity (T10 · T11)

    func testDailyLogDTOCarriesSexualActivity() {
        let log = DailyLog(waterMl: 500, sexualActivity: true)
        XCTAssertEqual(log.dto.domain, log)
    }

    /// A day persisted before the field existed was never asked the question, so `false` is the only
    /// honest reading of it. Decoding it as anything else would invent an answer she never gave.
    func testALocalDayWrittenBeforeTheFieldExistedDecodesAsNotRecorded() throws {
        let json = #"{"symptoms":[],"supplements":[],"waterMl":750}"#
        let dto = try JSONDecoder().decode(DailyLogDTO.self, from: Data(json.utf8))
        XCTAssertFalse(dto.domain.sexualActivity)
    }

    func testRemoteRowSendsSexualActivityAsItsColumn() throws {
        let row = DailyLogRow(userId: "u", date: CalendarDate(2026, 8, 10),
                              log: DailyLog(sexualActivity: true))
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(row), encoding: .utf8))

        XCTAssertTrue(json.contains("\"sexual_activity\":true"), json)
    }

    func testARemoteRowMissingTheColumnDecodesAsNotRecorded() throws {
        let json = #"{"user_id":"u","date":"2026-08-10","symptoms":[],"supplements":[],"water_ml":0}"#
        let row = try JSONDecoder().decode(DailyLogRow.self, from: Data(json.utf8))
        XCTAssertFalse(row.domain.sexualActivity)
    }

    func testPhReadingDTORoundTrip() {
        let r = PhReading(id: "abc", phValue: 6.8, recordedAt: Date(timeIntervalSince1970: 1_000_000), notes: "am")
        let record = PhRecord(reading: r, updatedAt: Date(timeIntervalSince1970: 1_000_000), pendingSync: false)
        XCTAssertEqual(record.dto.domain, r)
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

    /// Must go through `PhRecord.dto` — that is the only DTO `PhRepository` persists. An earlier
    /// version of this test encoded a `PhReading.dto` helper the repository never called, so it
    /// stayed green while every saved reading lost its type and vanished on the next launch.
    func testLocalDTORoundTripPreservesVaginal() throws {
        let reading = PhReading(phValue: 4.2, recordedAt: Date(timeIntervalSince1970: 1_000_000), measurementType: .vaginal)
        let record = PhRecord(reading: reading, updatedAt: Date(timeIntervalSince1970: 1_000_000), pendingSync: true)
        let data = try JSONEncoder().encode(record.dto)
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
