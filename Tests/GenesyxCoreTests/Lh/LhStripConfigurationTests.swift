import XCTest
@testable import GenesyxCore

final class LhStripConfigurationTests: XCTestCase {

    /// A coherent configuration; each test breaks one thing in it.
    private func configuration(minimumControl: Double = 0.2, positive: Double = 0.9, rising: Double = 0.5,
                               risingEnabled: Bool = false, minimumConfidence: Double = 0.85) -> LhStripConfiguration {
        LhStripConfiguration(
            id: "t", version: "1", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: minimumControl, positiveThreshold: positive, risingThreshold: rising,
            risingEnabled: risingEnabled, minimumConfidence: minimumConfidence,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: 100
        )
    }

    // MARK: - isUsable

    func testACoherentConfigurationIsUsable() {
        XCTAssertTrue(configuration().isUsable)
        XCTAssertTrue(configuration(risingEnabled: true).isUsable)
    }

    func testAThresholdThatIsNotFiniteIsNotUsable() {
        for bad in [Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(configuration(minimumControl: bad).isUsable, "minimum control \(bad)")
            XCTAssertFalse(configuration(positive: bad).isUsable, "positive \(bad)")
            XCTAssertFalse(configuration(rising: bad).isUsable, "rising \(bad), even with rising off")
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

    func testThePositiveThresholdMustBeAboveNought() {
        XCTAssertFalse(configuration(positive: 0).isUsable)
        XCTAssertFalse(configuration(positive: -0.9).isUsable)
        XCTAssertTrue(configuration(positive: 1.6).isUsable, "a ratio above one is a legitimate threshold")
    }

    func testTheMinimumConfidenceMustBeInsideNoughtToOne() {
        XCTAssertFalse(configuration(minimumConfidence: -0.01).isUsable)
        XCTAssertFalse(configuration(minimumConfidence: 1.01).isUsable)
        XCTAssertTrue(configuration(minimumConfidence: 0).isUsable)
        XCTAssertTrue(configuration(minimumConfidence: 1).isUsable)
    }

    func testAnEnabledRisingThresholdMustSitBetweenNoughtAndThePositiveThreshold() {
        for bad in [0.0, -0.5, 0.9, 1.2] {
            XCTAssertFalse(configuration(rising: bad, risingEnabled: true).isUsable, "\(bad)")
            XCTAssertTrue(configuration(rising: bad, risingEnabled: false).isUsable, "\(bad) is not read with rising off")
        }
        XCTAssertTrue(configuration(rising: 0.89, risingEnabled: true).isUsable)
    }

    // MARK: - Placeholder

    func testThePlaceholderIsMarkedAsDevelopmentDataAndIsCoherent() {
        let placeholder = LhStripConfiguration.developmentPlaceholder

        XCTAssertEqual(placeholder.id, "genesyx_lh_strip_v1")
        XCTAssertEqual(placeholder.version, "0.0.0-dev")
        XCTAssertFalse(placeholder.risingEnabled)
        XCTAssertTrue(placeholder.isUsable)
        XCTAssertGreaterThan(placeholder.expectedAspectRatio, 1, "the strip is scanned lying on its side")
        // A ratio of one is not assumed to mean positive.
        XCTAssertNotEqual(placeholder.positiveThreshold, 1.0)
        // The real times are on the leaflet; none is made up here.
        XCTAssertEqual(placeholder.developmentTimeSeconds, 0)
        XCTAssertNil(placeholder.maximumReadTimeSeconds)
    }
}
