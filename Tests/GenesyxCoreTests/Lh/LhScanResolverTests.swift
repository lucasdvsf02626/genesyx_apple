import XCTest
@testable import GenesyxCore

/// Pins the one rule that decides what an LH scan becomes: uncertainty is never a result, a
/// missing control line is never low or positive, and every threshold is the configuration's.
final class LhScanResolverTests: XCTestCase {

    /// The test configuration. Its numbers are its own, not the placeholder's.
    private func configuration(risingEnabled: Bool = false, minimumControl: Double = 0.20) -> LhStripConfiguration {
        LhStripConfiguration(
            id: "t", version: "1", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: minimumControl, positiveThreshold: 0.90, risingThreshold: 0.50,
            risingEnabled: risingEnabled, minimumConfidence: 0.85,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: 100
        )
    }

    private func outcome(control: Double, test: Double, confidence: Double = 0.95, flags: [ScanQualityIssue] = [],
                         id: String = "t", version: String = "1") -> LhAnalysisOutcome {
        .result(LhAnalysisResult(testSignal: test, controlSignal: control, confidence: confidence,
                                 qualityFlags: flags, configurationID: id, configurationVersion: version))
    }

    private func resolve(_ outcome: LhAnalysisOutcome, rising: Bool = false) -> LhScanResolution {
        LhScanResolver.resolve(outcome, configuration: configuration(risingEnabled: rising))
    }

    /// The classification, asserting it is the same whether or not rising is enabled.
    private func eitherWay(_ outcome: LhAnalysisOutcome, line: UInt = #line) -> LhScanResolution {
        let off = resolve(outcome, rising: false)
        XCTAssertEqual(resolve(outcome, rising: true).classification, off.classification,
                       "rising must not change this row", line: line)
        return off
    }

    private func measurement(_ resolution: LhScanResolution) -> LhScanMeasurement? {
        if case .reading(_, let measurement) = resolution { return measurement }
        return nil
    }

    // MARK: - Rule 1: unreadable passes through

    func testAnUnreadableOutcomeStaysUnreadableWithItsIssues() {
        XCTAssertEqual(resolve(.unreadable([.glare, .blurred])), .unreadable([.glare, .blurred]))
        XCTAssertEqual(resolve(.unreadable([.unrecognisedStrip]), rising: true), .unreadable([.unrecognisedStrip]))
        XCTAssertEqual(resolve(.unreadable([])), .unreadable([]))
    }

    // MARK: - Rule 2: configuration id and version

    /// A result judged against thresholds it was not produced under is not a result.
    func testAResultFromAnotherConfigurationIsUnreadable() {
        XCTAssertEqual(resolve(outcome(control: 0.5, test: 0.8, id: "another_strip")), .unreadable([]))
        XCTAssertEqual(resolve(outcome(control: 0.5, test: 0.8, version: "9.9.9")), .unreadable([]))
        XCTAssertEqual(resolve(outcome(control: 0.0, test: 0.0, id: "another_strip")), .unreadable([]),
                       "not invalid: nothing is known about a strip read under other thresholds")
        XCTAssertEqual(resolve(outcome(control: 0.5, test: 0.8, flags: [.glare], version: "9.9.9")), .unreadable([]),
                       "rule 2 comes before rule 4")
    }

    // MARK: - Rule 3: unusable configuration

    func testAnUnusableConfigurationMakesEveryResultUnreadable() {
        let unusable = configuration(minimumControl: 0)
        XCTAssertFalse(unusable.isUsable)

        let wouldBe: [(String, LhAnalysisOutcome)] = [
            ("low", outcome(control: 0.60, test: 0.06)),
            ("positive", outcome(control: 0.50, test: 0.80)),
            ("invalid", outcome(control: 0.00, test: 0.80)),
            ("flagged", outcome(control: 0.60, test: 0.60, flags: [.glare])),
        ]
        for (name, outcome) in wouldBe {
            XCTAssertEqual(LhScanResolver.resolve(outcome, configuration: unusable), .unreadable([]), name)
        }
    }

    // MARK: - Rule 4: quality flags

    func testAFlaggedConfidentResultIsUnreadableAndReturnsItsFlags() {
        XCTAssertEqual(eitherWay(outcome(control: 0.60, test: 0.60, flags: [.glare])), .unreadable([.glare]))
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.06, confidence: 1.0, flags: [.blurred, .tooDark])),
                       .unreadable([.blurred, .tooDark]))
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.06, flags: [.reagentAreaNotFound])),
                       .unreadable([.reagentAreaNotFound]), "regions not found is unreadable, never invalid")
        XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.00, flags: [.reagentAreaNotFound])),
                       .unreadable([.reagentAreaNotFound]), "a flagged read of no control line is not invalid")
    }

    /// Rule 4 before rule 5, so the screen can say what to change.
    func testAFlaggedLowConfidenceResultReturnsItsFlags() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.60, confidence: 0.40, flags: [.tooDark])),
                       .unreadable([.tooDark]))
    }

    // MARK: - Rule 5: confidence

    func testConfidenceBelowTheMinimumIsUnreadable() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.06, confidence: 0.84)), .unreadable([]))
        XCTAssertEqual(resolve(outcome(control: 0.50, test: 0.80, confidence: 0.849)), .unreadable([]))
    }

    func testConfidenceAtTheMinimumIsRead() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.06, confidence: 0.85)).classification, .low)
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.06, confidence: 1.0)).classification, .low)
    }

    /// Invalid is a confident statement. An uncertain read of a missing control line is not one.
    func testLowConfidenceWithNoControlLineIsUnreadableNotInvalid() {
        XCTAssertEqual(eitherWay(outcome(control: 0.00, test: 0.00, confidence: 0.84)), .unreadable([]))
        XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.80, confidence: 0.84)), .unreadable([]))
    }

    /// A percent-scale 85 is a bug in the analyser, not a very sure read. A NaN compares false
    /// against everything, so a `confidence < minimum` check would let it through.
    func testAConfidenceOutsideNoughtToOneOrNotANumberIsUnreadable() {
        for confidence in [85.0, 1.01, -0.1, .nan, .infinity, -.infinity] {
            XCTAssertEqual(eitherWay(outcome(control: 0.60, test: 0.60, confidence: confidence)), .unreadable([]),
                           "\(confidence)")
            XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.00, confidence: confidence)), .unreadable([]),
                           "\(confidence) with no control line must not be invalid")
        }
    }

    // MARK: - Rule 6: signals, never clamped

    func testASignalOutsideNoughtToOneIsUnreadableNotClamped() {
        XCTAssertEqual(eitherWay(outcome(control: 0.60, test: 1.40)), .unreadable([]),
                       "1.4 must not be clamped to 1.0 and read as positive")
        XCTAssertEqual(resolve(outcome(control: 1.40, test: 0.60)), .unreadable([]))
        XCTAssertEqual(resolve(outcome(control: 0.60, test: -0.01)), .unreadable([]))
        XCTAssertEqual(resolve(outcome(control: -0.01, test: 0.60)), .unreadable([]),
                       "a negative control is a broken measurement, not a missing line")
    }

    func testASignalThatIsNotFiniteIsUnreadable() {
        for bad in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(resolve(outcome(control: 0.60, test: bad)), .unreadable([]), "test \(bad)")
            XCTAssertEqual(resolve(outcome(control: bad, test: 0.60)), .unreadable([]), "control \(bad)")
        }
    }

    // MARK: - Rule 7: invalid

    func testAControlLineBelowTheMinimumIsInvalid() {
        XCTAssertEqual(eitherWay(outcome(control: 0.19, test: 0.00)), .invalid)
        XCTAssertEqual(eitherWay(outcome(control: 0.00, test: 0.00)), .invalid)
    }

    /// The ratio would be far above the positive threshold. It is never computed.
    func testATestLineWithNoControlLineIsInvalidAndNeverPositive() {
        XCTAssertEqual(eitherWay(outcome(control: 0.00, test: 0.80)), .invalid)
        XCTAssertEqual(eitherWay(outcome(control: 0.19, test: 0.80)), .invalid)
        XCTAssertEqual(eitherWay(outcome(control: 0.19, test: 1.00)), .invalid)
    }

    func testAControlLineExactlyAtTheMinimumIsValid() {
        XCTAssertEqual(resolve(outcome(control: 0.20, test: 0.02)).classification, .low)
        XCTAssertEqual(resolve(outcome(control: 0.20, test: 0.20)).classification, .positive)
    }

    // MARK: - Rules 8 to 10: the ratio

    func testAFaintTestLineIsLow() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.06)).classification, .low)
    }

    func testAControlLineAloneIsLow() {
        let resolution = resolve(outcome(control: 0.60, test: 0.00))

        XCTAssertEqual(resolution.classification, .low)
        XCTAssertEqual(measurement(resolution)?.testControlRatio, 0)
    }

    func testARatioBetweenTheThresholdsIsLowUnlessRisingIsEnabled() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.36), rising: false).classification, .low)
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.36), rising: true).classification, .rising)
    }

    func testTheRisingThresholdIsInclusive() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.30), rising: true).classification, .rising)
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.2999), rising: true).classification, .low)
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.30), rising: false).classification, .low)
    }

    func testTheRatioExactlyAtThePositiveThresholdIsPositive() {
        XCTAssertEqual(eitherWay(outcome(control: 0.50, test: 0.45)).classification, .positive)
    }

    func testTheRatioJustBelowThePositiveThresholdIsNotPositive() {
        XCTAssertEqual(resolve(outcome(control: 0.50, test: 0.4499), rising: false).classification, .low)
        XCTAssertEqual(resolve(outcome(control: 0.50, test: 0.4499), rising: true).classification, .rising)
    }

    func testATestLineDarkerThanTheControlIsPositive() {
        let resolution = eitherWay(outcome(control: 0.50, test: 0.80))

        XCTAssertEqual(resolution.classification, .positive)
        XCTAssertEqual(measurement(resolution)?.testControlRatio ?? 0, 1.60, accuracy: 1e-12)
    }

    /// Nothing in the resolver assumes that a test line as dark as the control is a positive.
    func testThePositiveCutIsTheConfigurationsNotARatioOfOne() {
        let strict = LhStripConfiguration(
            id: "t", version: "1", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: 0.20, positiveThreshold: 1.50, risingThreshold: 0.50, risingEnabled: false,
            minimumConfidence: 0.85, developmentTimeSeconds: 0, maximumReadTimeSeconds: nil,
            stableDetectionMilliseconds: 100
        )

        XCTAssertEqual(LhScanResolver.resolve(outcome(control: 0.50, test: 0.50), configuration: strict).classification, .low)
        XCTAssertEqual(LhScanResolver.resolve(outcome(control: 0.50, test: 0.75), configuration: strict).classification, .positive)
        XCTAssertEqual(resolve(outcome(control: 0.50, test: 0.50)).classification, .positive)
    }

    // MARK: - Measurement

    func testAReadingCarriesWhatWasMeasured() {
        guard case .reading(let classification, let measurement) = resolve(outcome(control: 0.60, test: 0.06, confidence: 0.91)) else {
            return XCTFail("expected a reading")
        }
        XCTAssertEqual(classification, .low)
        XCTAssertEqual(measurement.testSignal, 0.06)
        XCTAssertEqual(measurement.controlSignal, 0.60)
        XCTAssertEqual(measurement.testControlRatio, 0.06 / 0.60)
        XCTAssertEqual(measurement.confidence, 0.91)
        XCTAssertEqual(measurement.scannerVersion, LhScanResolver.scannerVersion)
        XCTAssertFalse(measurement.scannerVersion.isEmpty)
    }

    func testTheMeasurementsVersionsComeFromTheConfigurationArgument() {
        let other = LhStripConfiguration(
            id: "another_strip", version: "2.0.0", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: 0.10, positiveThreshold: 0.70, risingThreshold: 0.30, risingEnabled: false,
            minimumConfidence: 0.50, developmentTimeSeconds: 0, maximumReadTimeSeconds: nil,
            stableDetectionMilliseconds: 100
        )
        let analysed = outcome(control: 0.50, test: 0.40, confidence: 0.60, id: other.id, version: other.version)

        guard case .reading(.positive, let measurement) = LhScanResolver.resolve(analysed, configuration: other) else {
            return XCTFail("expected a positive reading under the other configuration's thresholds")
        }
        XCTAssertEqual(measurement.configurationID, "another_strip")
        XCTAssertEqual(measurement.configurationVersion, "2.0.0")
        XCTAssertEqual(resolve(analysed), .unreadable([]), "the same result against the test configuration is not a reading")
    }

    // MARK: - Classification of a resolution

    func testEachResolutionHasItsClassification() {
        let measurement = LhScanMeasurement(testSignal: 0.1, controlSignal: 0.5, testControlRatio: 0.2, confidence: 0.9,
                                            scannerVersion: "0.1.0", configurationID: "t", configurationVersion: "1")

        for classification in [LhClassification.low, .rising, .positive] {
            XCTAssertEqual(LhScanResolution.reading(classification, measurement).classification, classification)
        }
        XCTAssertEqual(LhScanResolution.invalid.classification, .invalid)
        XCTAssertEqual(LhScanResolution.unreadable([]).classification, .unreadable)
        XCTAssertEqual(LhScanResolution.unreadable([.glare]).classification, .unreadable)
    }

    /// A reading is only ever low, rising or positive, whatever the analyser reports.
    func testTheResolverNeverPutsInvalidOrUnreadableInsideAReading() {
        let signals = [0.0, 0.1, 0.19, 0.2, 0.3, 0.45, 0.5, 0.8, 1.0]
        for control in signals {
            for test in signals {
                for rising in [false, true] {
                    let resolution = resolve(outcome(control: control, test: test), rising: rising)
                    if case .reading(let classification, let measurement) = resolution {
                        XCTAssertTrue([.low, .rising, .positive].contains(classification), "\(control) \(test)")
                        XCTAssertGreaterThanOrEqual(control, 0.20, "a reading needs a valid control line")
                        XCTAssertEqual(measurement.testControlRatio, test / control)
                        XCTAssertTrue(rising || classification != .rising, "rising without it being enabled")
                    } else {
                        XCTAssertEqual(resolution, .invalid, "\(control) \(test)")
                        XCTAssertLessThan(control, 0.20)
                    }
                }
            }
        }
    }
}
