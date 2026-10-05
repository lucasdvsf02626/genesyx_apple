import XCTest
@testable import GenesyxCore

final class HcgResultTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    func testAResultWithoutAScanIsManual() {
        let result = HcgResult(recordedAt: date, classification: .noTestLineDetected)
        XCTAssertNil(result.scan)
        XCTAssertEqual(result.source, .manual)
    }

    func testAResultWithAScanIsACameraScan() {
        let provenance = HcgScanProvenance(scannerVersion: "0.1.0", configurationID: "strip-test",
                                           configurationVersion: "9.9.9")
        let result = HcgResult(recordedAt: date, classification: .testLineDetected, scan: provenance)
        XCTAssertEqual(result.source, .cameraScan)
        XCTAssertEqual(result.scan, provenance)
    }

    func testEachResultGetsItsOwnIDUnlessOneIsGiven() {
        XCTAssertNotEqual(HcgResult(recordedAt: date, classification: .invalid).id,
                          HcgResult(recordedAt: date, classification: .invalid).id)
        XCTAssertEqual(HcgResult(id: "a", recordedAt: date, classification: .invalid).id, "a")
    }

    /// Raw values are stored on the device: renaming a case would orphan saved results.
    func testClassificationRawValuesArePinned() {
        XCTAssertEqual(HcgClassification.testLineDetected.rawValue, "testLineDetected")
        XCTAssertEqual(HcgClassification.noTestLineDetected.rawValue, "noTestLineDetected")
        XCTAssertEqual(HcgClassification.invalid.rawValue, "invalid")
    }

    /// There is no unreadable case, so an unreadable scan cannot be stored.
    func testThereAreExactlyThreeClassificationsAndNoneIsUnreadable() {
        XCTAssertEqual(HcgClassification.allCases.count, 3)
        XCTAssertNil(HcgClassification(rawValue: "unreadable"))
    }

    /// A scanned result keeps three version strings and nothing that was measured.
    func testProvenanceEncodesOnlyVersions() throws {
        let provenance = HcgScanProvenance(scannerVersion: "0.1.0", configurationID: "strip-test",
                                           configurationVersion: "9.9.9")
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(provenance)) as? [String: Any]
        XCTAssertEqual(Set(object?.keys.map { $0 } ?? []),
                       ["scannerVersion", "configurationID", "configurationVersion"])
    }
}
