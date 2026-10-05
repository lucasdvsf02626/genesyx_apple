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

    // MARK: scan provenance (source + scan metadata)

    private let scanMeta = PhScanMetadata(scannerVersion: "s1", configurationID: "cfg", configurationVersion: "2", confidence: 0.83)
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func scanned() -> PhReading {
        PhReading(id: "s", phValue: 4.6, recordedAt: t0, measurementType: .vaginal, source: .cameraScan, scan: scanMeta)
    }

    private func keys(of row: PhReadingRow) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(row))
        return Set(try XCTUnwrap(object as? [String: Any]).keys)
    }

    func testLegacyLocalJSONWithoutScanKeysDecodesAsManual() throws {
        let json = #"{"id":"x","phValue":4.2,"recordedAt":0,"measurementType":"vaginal"}"#
        let dto = try JSONDecoder().decode(PhReadingDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.domain.source, .manual)
        XCTAssertNil(dto.domain.scan)
    }

    func testStoredScanMissingAMetadataFieldDecodesAsManualWithNoScan() {
        var dto = PhRecord(reading: scanned(), updatedAt: t0, pendingSync: false).dto
        dto.scanConfidence = nil
        XCTAssertEqual(dto.domain.source, .manual)
        XCTAssertNil(dto.domain.scan)
    }

    func testCameraScanSurvivesTheLocalDTORoundTrip() throws {
        let record = PhRecord(reading: scanned(), updatedAt: t0, pendingSync: true)
        let decoded = try JSONDecoder().decode(PhReadingDTO.self, from: JSONEncoder().encode(record.dto))
        XCTAssertEqual(decoded.domain, scanned())
    }

    func testUnknownLocalSourceDecodesAsManualAndStaysVisible() throws {
        var dto = PhRecord(reading: scanned(), updatedAt: t0, pendingSync: false).dto
        dto.source = "hologram"
        let store = makeStore()
        store.save([dto], forKey: "ph_readings")
        let readings = MainActor.assumeIsolated { PhRepository(store: store).readings }
        XCTAssertEqual(readings.map(\.phValue), [4.6], "an unknown source must not hide the reading")
        XCTAssertEqual(readings.first?.source, .manual)
        XCTAssertNil(readings.first?.scan)
    }

    func testManualRemoteRowSendsNoScanKeys() throws {
        let reading = PhReading(id: "x", phValue: 4.2, recordedAt: t0, measurementType: .vaginal)
        let row = PhReadingRow(userId: "u", record: PhRecord(reading: reading, updatedAt: t0, pendingSync: false))
        XCTAssertEqual(try keys(of: row), ["id", "user_id", "ph_value", "recorded_at", "updated_at", "measurement_type"])
    }

    func testScannedRemoteRowSendsTheFiveScanKeys() throws {
        let row = PhReadingRow(userId: "u", record: PhRecord(reading: scanned(), updatedAt: t0, pendingSync: false))
        let sent = try keys(of: row)
        XCTAssertEqual(sent.subtracting(["id", "user_id", "ph_value", "recorded_at", "updated_at", "measurement_type"]),
                       ["source", "scan_confidence", "scan_configuration_id", "scan_configuration_version", "scanner_version"])
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(row), encoding: .utf8))
        XCTAssertTrue(json.contains("\"source\":\"camera_scan\""), json)
    }

    func testRemoteRowWithoutOrWithNullScanColumnsDecodesAsManual() throws {
        let base = #""id":"x","user_id":"u","ph_value":4.2,"recorded_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","measurement_type":"vaginal""#
        let nulls = #","source":null,"scan_confidence":null,"scan_configuration_id":null,"scan_configuration_version":null,"scanner_version":null"#
        for json in ["{\(base)}", "{\(base)\(nulls)}"] {
            let reading = try JSONDecoder().decode(PhReadingRow.self, from: Data(json.utf8)).domain.reading
            XCTAssertEqual(reading.source, .manual)
            XCTAssertNil(reading.scan)
        }
    }

    func testFullScannedRemoteRowRestoresTheMetadata() throws {
        let row = PhReadingRow(userId: "u", record: PhRecord(reading: scanned(), updatedAt: t0, pendingSync: false))
        let back = try JSONDecoder().decode(PhReadingRow.self, from: JSONEncoder().encode(row)).domain.reading
        XCTAssertEqual(back.source, .cameraScan)
        XCTAssertEqual(back.scan, scanMeta)
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

    /// A seeded launch starts light, whatever theme the last one left behind.
    ///
    /// `uiTestSeeded()` opens by wiping the app's defaults, but `removePersistentDomain` does not
    /// actually clear `theme_mode` — it stays readable, which is why `onboardingComplete` beside it
    /// is set outright rather than trusted to the wipe. So a single `-uiTestTheme dark` run latched
    /// dark mode on for every seeded launch after it on that simulator: the whole UI suite, the
    /// demo walkthrough and the onboarding quiz all rendered dark on a light phone.
    ///
    /// The leaked value is planted in the registration domain because that is the only one a test
    /// can write that behaves like the real thing: `removePersistentDomain` leaves it standing, so
    /// `uiTestSeeded()` reads it exactly as it read the stale `dark` on the simulator. Planting it
    /// with `set(_:forKey:)` instead proves nothing — the wipe clears that.
    @MainActor
    func testASeededLaunchStartsLightWhateverTheLastOneLeftBehind() {
        UserDefaults.standard.register(defaults: ["genesyx.theme_mode": ThemeMode.dark.rawValue])
        defer { UserDefaults.standard.register(defaults: ["genesyx.theme_mode": ThemeMode.light.rawValue]) }
        XCTAssertEqual(AppContainer.uiTestSeeded().prefs.themeMode, .light)
    }

    /// The other half of the same guard: silencing the leak by ignoring `-uiTestTheme` would leave
    /// every dark colour in `GenesyxColor` untestable again.
    @MainActor
    func testASeededLaunchStillHonoursAnExplicitDarkRequest() {
        UserDefaults.standard.register(defaults: ["uiTestTheme": ThemeMode.dark.rawValue])
        defer { UserDefaults.standard.register(defaults: ["uiTestTheme": ""]) }
        XCTAssertEqual(AppContainer.uiTestSeeded().prefs.themeMode, .dark)
    }
}
