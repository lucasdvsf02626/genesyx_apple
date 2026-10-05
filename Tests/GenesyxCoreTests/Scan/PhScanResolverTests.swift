import XCTest
@testable import GenesyxCore

/// Pins the one rule that decides whether a scan becomes a reading: uncertainty is never a
/// result, and a scanned value is never clamped into range.
final class PhScanResolverTests: XCTestCase {

    private let configuration = PhStripConfiguration.developmentPlaceholder

    private func result(_ ph: Double, confidence: Double = 0.95, flags: [ScanQualityIssue] = []) -> PhAnalysisOutcome {
        .result(PhAnalysisResult(estimatedPH: ph, confidence: confidence, qualityFlags: flags,
                                 configurationID: configuration.id, configurationVersion: configuration.version))
    }

    private func resolve(_ outcome: PhAnalysisOutcome) -> PhScanResolution {
        PhScanResolver.resolve(outcome, configuration: configuration)
    }

    private func value(_ resolution: PhScanResolution) -> Double? {
        if case .reading(let value, _) = resolution { return value }
        return nil
    }

    private func assertUnreadable(_ resolution: PhScanResolution, _ message: String = "", line: UInt = #line) {
        guard case .unreadable = resolution else {
            return XCTFail("expected unreadable, got \(resolution). \(message)", line: line)
        }
    }

    // MARK: - Unreadable passes through

    func testAnUnreadableOutcomeStaysUnreadableWithItsIssues() {
        XCTAssertEqual(resolve(.unreadable([.glare, .blurred])), .unreadable([.glare, .blurred]))
        XCTAssertEqual(resolve(.unreadable([])), .unreadable([]))
    }

    // MARK: - Confidence

    func testConfidenceBelowTheThresholdIsUnreadable() {
        let justBelow = configuration.minimumConfidence - 0.001
        assertUnreadable(resolve(result(4.2, confidence: justBelow)))
        XCTAssertEqual(resolve(result(4.2, confidence: justBelow, flags: [.tooDark])), .unreadable([.tooDark]),
                       "the analyser's flags should survive, so the screen can say what to change")
    }

    func testConfidenceAtOrAboveTheThresholdIsAReading() {
        XCTAssertEqual(value(resolve(result(4.2, confidence: configuration.minimumConfidence))), 4.2)
        XCTAssertEqual(value(resolve(result(4.2, confidence: 1.0))), 4.2)
    }

    /// A NaN compares false against everything, so a `confidence < minimum` check lets it through.
    func testAConfidenceThatIsNotANumberIsUnreadable() {
        assertUnreadable(resolve(result(4.2, confidence: .nan)))
        assertUnreadable(resolve(result(4.2, confidence: .infinity)))
        assertUnreadable(resolve(result(4.2, confidence: -.infinity)))
    }

    /// A percent-scale 85 is a bug in the analyser, not a very sure reading.
    func testAConfidenceOutsideNoughtToOneIsUnreadable() {
        for confidence in [1.01, 85.0, -0.1] {
            XCTAssertEqual(resolve(result(4.2, confidence: confidence)), .unreadable([]), "\(confidence)")
        }
    }

    // MARK: - Quality flags

    func testAConfidentResultWithAQualityFlagIsUnreadableAndReturnsTheFlags() {
        XCTAssertEqual(resolve(result(4.2, confidence: 0.99, flags: [.glare])), .unreadable([.glare]))
        XCTAssertEqual(resolve(result(4.2, confidence: 1.0, flags: [.blurred, .tooDark])), .unreadable([.blurred, .tooDark]))
    }

    // MARK: - Configuration

    /// A result judged against thresholds it was not produced under is not a reading.
    func testAResultFromAnotherConfigurationIsUnreadable() {
        let otherID = PhAnalysisResult(estimatedPH: 4.2, confidence: 0.95, configurationID: "another_strip",
                                       configurationVersion: configuration.version)
        let otherVersion = PhAnalysisResult(estimatedPH: 4.2, confidence: 0.95, configurationID: configuration.id,
                                            configurationVersion: "9.9.9")

        XCTAssertEqual(resolve(.result(otherID)), .unreadable([]))
        XCTAssertEqual(resolve(.result(otherVersion)), .unreadable([]))
    }

    // MARK: - Values that are not numbers

    func testANonFiniteEstimateIsUnreadable() {
        assertUnreadable(resolve(result(.nan)))
        assertUnreadable(resolve(result(.infinity)))
        assertUnreadable(resolve(result(-.infinity)))
    }

    // MARK: - Range: never clamped

    func testValuesOutsideTheLoggableRangeAreUnreadableNotClamped() {
        for outside in [0.0, 3.0, 3.7, 3.74, 7.06, 7.1, 9.0, 14.0, -1.0] {
            let resolution = resolve(result(outside))
            assertUnreadable(resolution, "\(outside)")
            XCTAssertNil(value(resolution), "\(outside) must not come back as \(PhStatus.clamped(outside))")
        }
    }

    func testTheEdgesOfTheLoggableRangeAreReadings() {
        XCTAssertEqual(value(resolve(result(3.8))), PhStatus.min)
        XCTAssertEqual(value(resolve(result(7.0))), PhStatus.max)
        // The range is judged on the rounded value, the one that would be saved.
        XCTAssertEqual(value(resolve(result(3.75))), 3.8)
        XCTAssertEqual(value(resolve(result(7.04))), 7.0)
    }

    // MARK: - Rounding

    /// Mirrors `PhRepository.round1`: `(value * 10).rounded() / 10`, halves away from zero.
    func testRoundingMatchesTheAppsOwn() {
        XCTAssertEqual(value(resolve(result(4.249))), 4.2)
        XCTAssertEqual(value(resolve(result(4.25))), 4.3)
        XCTAssertEqual(value(resolve(result(6.46))), 6.5)
        for raw in [3.8, 4.249, 4.25, 4.5, 4.51, 5.55, 6.46, 7.0] {
            XCTAssertEqual(value(resolve(result(raw))), (raw * 10).rounded() / 10, "\(raw)")
        }
    }

    // MARK: - Metadata

    func testAReadingCarriesWhatProducedIt() {
        guard case .reading(_, let metadata) = resolve(result(4.4, confidence: 0.91)) else {
            return XCTFail("expected a reading")
        }
        XCTAssertEqual(metadata.scannerVersion, PhScanResolver.scannerVersion)
        XCTAssertFalse(metadata.scannerVersion.isEmpty)
        XCTAssertEqual(metadata.configurationID, "genesyx_ph_multizone_v1")
        XCTAssertEqual(metadata.configurationVersion, configuration.version)
        XCTAssertEqual(metadata.confidence, 0.91)
    }

    func testMetadataComesFromTheConfigurationItWasResolvedAgainst() {
        let other = PhStripConfiguration(id: "another_strip", version: "2.0.0", expectedAspectRatio: 0.1,
                                         reagentRegions: [], calibrationRegions: [], referenceProfiles: [],
                                         minimumConfidence: 0.5, developmentTimeSeconds: 0,
                                         stableDetectionMilliseconds: 100)
        let outcome = PhAnalysisOutcome.result(PhAnalysisResult(estimatedPH: 4.4, confidence: 0.6,
                                                                configurationID: other.id,
                                                                configurationVersion: other.version))

        guard case .reading(_, let metadata) = PhScanResolver.resolve(outcome, configuration: other) else {
            return XCTFail("expected a reading")
        }
        XCTAssertEqual(metadata.configurationID, other.id)
        XCTAssertEqual(metadata.configurationVersion, other.version)
        assertUnreadable(resolve(outcome), "the same result against the placeholder is not a reading")
    }
}
