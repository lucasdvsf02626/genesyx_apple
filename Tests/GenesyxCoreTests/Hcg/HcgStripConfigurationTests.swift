import XCTest
@testable import GenesyxCore

final class HcgStripConfigurationTests: XCTestCase {

    /// A coherent configuration; each test breaks one thing in it.
    private func configuration(minimumControl: Double = 0.2, lower: Double = 0.05, threshold: Double = 0.15,
                               minimumConfidence: Double = 0.85) -> HcgStripConfiguration {
        HcgStripConfiguration(
            id: "strip-test", version: "9.9.9", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: minimumControl, indeterminateLowerBound: lower, detectionThreshold: threshold,
            minimumConfidence: minimumConfidence,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: 100
        )
    }

    // MARK: - isUsable

    func testACoherentConfigurationIsUsable() {
        XCTAssertTrue(configuration().isUsable)
    }

    func testAThresholdThatIsNotFiniteIsNotUsable() {
        for bad in [Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(configuration(minimumControl: bad).isUsable, "minimum control \(bad)")
            XCTAssertFalse(configuration(lower: bad).isUsable, "lower bound \(bad)")
            XCTAssertFalse(configuration(threshold: bad).isUsable, "threshold \(bad)")
            XCTAssertFalse(configuration(minimumConfidence: bad).isUsable, "minimum confidence \(bad)")
        }
    }

    /// A minimum of zero would accept a strip with no control line at all.
    func testTheMinimumControlSignalMustBeAboveNoughtAndAtMostOne() {
        for bad in [0.0, -0.1, 1.01] {
            XCTAssertFalse(configuration(minimumControl: bad).isUsable, "\(bad)")
        }
        XCTAssertTrue(configuration(minimumControl: 1.0).isUsable)
        XCTAssertTrue(configuration(minimumControl: 0.001).isUsable)
    }

    /// A lower bound of zero would put "no line at all" inside the band.
    func testTheLowerBoundMustBeAboveNought() {
        XCTAssertFalse(configuration(lower: 0).isUsable)
        XCTAssertFalse(configuration(lower: -0.05).isUsable)
        XCTAssertTrue(configuration(lower: 0.001).isUsable)
    }

    /// The band cannot be switched off: an empty band and an inverted one are both unusable.
    func testAnEmptyOrInvertedBandIsNotUsable() {
        XCTAssertFalse(configuration(lower: 0.15, threshold: 0.15).isUsable, "lower == threshold is an empty band")
        XCTAssertFalse(configuration(lower: 0.16, threshold: 0.15).isUsable, "lower > threshold is inverted")
        XCTAssertFalse(configuration(lower: 0.5, threshold: 0.05).isUsable)
        XCTAssertTrue(configuration(lower: 0.149, threshold: 0.15).isUsable, "any room at all is a band")
    }

    func testTheDetectionThresholdMustBeAtMostOne() {
        XCTAssertTrue(configuration(threshold: 1.0).isUsable)
        XCTAssertFalse(configuration(threshold: 1.01).isUsable)
    }

    func testTheMinimumConfidenceMustBeInsideNoughtToOne() {
        XCTAssertFalse(configuration(minimumConfidence: -0.1).isUsable)
        XCTAssertFalse(configuration(minimumConfidence: 1.1).isUsable)
        XCTAssertTrue(configuration(minimumConfidence: 0).isUsable)
        XCTAssertTrue(configuration(minimumConfidence: 1).isUsable)
    }

    // MARK: - Placeholder

    func testThePlaceholderIsMarkedAsDevelopmentDataAndIsCoherent() {
        let placeholder = HcgStripConfiguration.developmentPlaceholder

        XCTAssertEqual(placeholder.id, "genesyx_hcg_strip_v1")
        XCTAssertTrue(placeholder.version.hasSuffix("-dev"))
        XCTAssertTrue(placeholder.isUsable)
        XCTAssertGreaterThan(placeholder.expectedAspectRatio, 1, "the strip is scanned lying on its side")
        XCTAssertLessThan(placeholder.indeterminateLowerBound, placeholder.detectionThreshold, "the band has room")
        // The real times are on the leaflet; none is made up here.
        XCTAssertEqual(placeholder.developmentTimeSeconds, 0)
        XCTAssertNil(placeholder.maximumReadTimeSeconds)
    }

    // MARK: - Codable

    func testAConfigurationSurvivesACodableRoundTrip() throws {
        for original in [configuration(), HcgStripConfiguration.developmentPlaceholder] {
            let decoded = try JSONDecoder().decode(HcgStripConfiguration.self, from: JSONEncoder().encode(original))
            XCTAssertEqual(decoded, original)
        }
    }
}
