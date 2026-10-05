import XCTest
@testable import GenesyxCore

/// The scan fields on `PhReading`, and the placeholder strip configuration.
final class PhScanModelTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let metadata = PhScanMetadata(scannerVersion: "0.1.0", configurationID: "genesyx_ph_multizone_v1",
                                          configurationVersion: "0.0.0-dev", confidence: 0.93)

    // MARK: - PhReading

    /// Every reading written before scanning existed, and every existing call site, is manual.
    func testAReadingIsManualWithNoScanUnlessToldOtherwise() {
        let reading = PhReading(phValue: 4.2, recordedAt: t0)

        XCTAssertEqual(reading.source, .manual)
        XCTAssertNil(reading.scan)
        XCTAssertEqual(reading.measurementType, .vaginal)
    }

    func testAScannedReadingKeepsItsSourceAndMetadata() {
        let reading = PhReading(id: "a", phValue: 4.2, recordedAt: t0, source: .cameraScan, scan: metadata)

        XCTAssertEqual(reading.source, .cameraScan)
        XCTAssertEqual(reading.scan, metadata)
    }

    func testEqualityAndHashTellAScanFromAManualEntry() {
        let manual = PhReading(id: "a", phValue: 4.2, recordedAt: t0)
        let scanned = PhReading(id: "a", phValue: 4.2, recordedAt: t0, source: .cameraScan, scan: metadata)
        let lessSure = PhReading(id: "a", phValue: 4.2, recordedAt: t0, source: .cameraScan,
                                 scan: PhScanMetadata(scannerVersion: "0.1.0", configurationID: "genesyx_ph_multizone_v1",
                                                      configurationVersion: "0.0.0-dev", confidence: 0.9))

        XCTAssertEqual(manual, PhReading(id: "a", phValue: 4.2, recordedAt: t0))
        XCTAssertEqual(manual.hashValue, PhReading(id: "a", phValue: 4.2, recordedAt: t0).hashValue)
        XCTAssertNotEqual(manual, scanned)
        XCTAssertNotEqual(scanned, lessSure)
        XCTAssertEqual(Set([manual, scanned, lessSure, manual]).count, 3)
    }

    /// The raw values are what gets persisted, so renaming a case is a data migration.
    func testSourceRawValuesArePinned() {
        XCTAssertEqual(PhReadingSource.manual.rawValue, "manual")
        XCTAssertEqual(PhReadingSource.cameraScan.rawValue, "cameraScan")
        XCTAssertNil(PhReadingSource(rawValue: "photo"))
    }

    func testSourceAndMetadataRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(metadata)
        XCTAssertEqual(try JSONDecoder().decode(PhScanMetadata.self, from: data), metadata)

        let source = try JSONEncoder().encode([PhReadingSource.cameraScan])
        XCTAssertEqual(try JSONDecoder().decode([PhReadingSource].self, from: source), [.cameraScan])
    }

    // MARK: - Placeholder configuration

    func testThePlaceholderIsIdentifiedAndCarriesNoInventedColourChart() {
        let placeholder = PhStripConfiguration.developmentPlaceholder

        XCTAssertEqual(placeholder.id, "genesyx_ph_multizone_v1")
        XCTAssertFalse(placeholder.version.isEmpty)
        XCTAssertTrue(placeholder.referenceProfiles.isEmpty, "there is no manufacturer chart; do not make one up")
    }

    func testThePlaceholderThresholdsAreUsable() {
        let placeholder = PhStripConfiguration.developmentPlaceholder

        XCTAssertTrue((0.0...1.0).contains(placeholder.minimumConfidence))
        XCTAssertGreaterThan(placeholder.expectedAspectRatio, 0)
        XCTAssertGreaterThan(placeholder.stableDetectionMilliseconds, 0)
        XCTAssertGreaterThanOrEqual(placeholder.developmentTimeSeconds, 0)
    }

    func testEveryPlaceholderRegionSitsInsideTheStrip() {
        let placeholder = PhStripConfiguration.developmentPlaceholder
        let regions = placeholder.reagentRegions + placeholder.calibrationRegions

        XCTAssertFalse(placeholder.reagentRegions.isEmpty)
        for rect in regions {
            XCTAssertGreaterThan(rect.width, 0, "\(rect)")
            XCTAssertGreaterThan(rect.height, 0, "\(rect)")
            for edge in [rect.x, rect.y, rect.x + rect.width, rect.y + rect.height] {
                XCTAssertTrue((0.0...1.0).contains(edge), "\(rect) leaves the strip")
            }
        }
    }

    func testAConfigurationRoundTripsThroughJSON() throws {
        let placeholder = PhStripConfiguration.developmentPlaceholder
        let data = try JSONEncoder().encode(placeholder)
        XCTAssertEqual(try JSONDecoder().decode(PhStripConfiguration.self, from: data), placeholder)
    }
}
