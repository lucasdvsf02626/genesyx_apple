import XCTest
@testable import GenesyxCore

/// Pins the one rule that decides what a pregnancy test scan becomes: uncertainty is never a
/// result, a missing control line is never "no test line", a signal inside the band is never a
/// result, and every threshold is the configuration's.
final class HcgScanResolverTests: XCTestCase {

    /// The test configuration. Its numbers are its own, not the placeholder's.
    private func configuration(lower: Double = 0.05, threshold: Double = 0.15) -> HcgStripConfiguration {
        HcgStripConfiguration(
            id: "strip-test", version: "9.9.9", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: 0.20, indeterminateLowerBound: lower, detectionThreshold: threshold,
            minimumConfidence: 0.85,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: 100
        )
    }

    private func outcome(control: Double, test: Double, confidence: Double = 0.95, flags: [ScanQualityIssue] = [],
                         id: String = "strip-test", version: String = "9.9.9") -> HcgAnalysisOutcome {
        .result(HcgAnalysisResult(testSignal: test, controlSignal: control, confidence: confidence,
                                  qualityFlags: flags, configurationID: id, configurationVersion: version))
    }

    private func resolve(_ outcome: HcgAnalysisOutcome) -> HcgScanResolution {
        HcgScanResolver.resolve(outcome, configuration: configuration())
    }

    private var provenance: HcgScanProvenance {
        HcgScanProvenance(scannerVersion: HcgScanResolver.scannerVersion,
                          configurationID: "strip-test", configurationVersion: "9.9.9")
    }

    private var detected: HcgScanResolution { .reading(.testLineDetected, provenance) }
    private var notDetected: HcgScanResolution { .reading(.noTestLineDetected, provenance) }
    private let indeterminate = HcgScanResolution.unreadable(.indeterminateTestLine)
    private let unreadable = HcgScanResolution.unreadable(.quality([]))

    // MARK: - Rule 1: unreadable passes through

    func testAnUnreadableOutcomeStaysUnreadableWithItsIssues() {
        XCTAssertEqual(resolve(.unreadable([.blurred])), .unreadable(.quality([.blurred])))
        XCTAssertEqual(resolve(.unreadable([.glare, .blurred])), .unreadable(.quality([.glare, .blurred])))
        XCTAssertEqual(resolve(.unreadable([])), unreadable)
    }

    // MARK: - Rule 2: configuration id and version

    /// A result judged against thresholds it was not produced under is not a result.
    func testAResultWhoseConfigurationIDDiffersIsUnreadable() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, id: "another_strip")), unreadable)
        XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.00, id: "another_strip")), unreadable,
                       "not invalid: nothing is known about a strip read under other thresholds")
    }

    func testAResultWhoseConfigurationVersionDiffersIsUnreadable() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, version: "1.0.0")), unreadable)
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, flags: [.glare], version: "1.0.0")), unreadable,
                       "rule 2 comes before rule 4")
    }

    // MARK: - Rule 3: unusable configuration (the band cannot be switched off)

    func testAnEmptyBandMakesAStrongCleanResultUnreadable() {
        let empty = configuration(lower: 0.15, threshold: 0.15)
        XCTAssertFalse(empty.isUsable)
        XCTAssertEqual(HcgScanResolver.resolve(outcome(control: 0.60, test: 0.80), configuration: empty), unreadable)
        XCTAssertEqual(HcgScanResolver.resolve(outcome(control: 0.60, test: 0.00), configuration: empty), unreadable)
        XCTAssertEqual(HcgScanResolver.resolve(outcome(control: 0.00, test: 0.80), configuration: empty), unreadable,
                       "not invalid either")
    }

    func testAnInvertedBandMakesAStrongCleanResultUnreadable() {
        let inverted = configuration(lower: 0.30, threshold: 0.15)
        XCTAssertFalse(inverted.isUsable)
        XCTAssertEqual(HcgScanResolver.resolve(outcome(control: 0.60, test: 0.80), configuration: inverted), unreadable)
        XCTAssertEqual(HcgScanResolver.resolve(outcome(control: 0.60, test: 0.00), configuration: inverted), unreadable)
    }

    // MARK: - Rule 4: quality flags

    func testAFlaggedConfidentResultIsUnreadableAndReturnsItsFlags() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, flags: [.glare])), .unreadable(.quality([.glare])))
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.00, confidence: 1.0, flags: [.blurred, .tooDark])),
                       .unreadable(.quality([.blurred, .tooDark])))
        XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.00, flags: [.reagentAreaNotFound])),
                       .unreadable(.quality([.reagentAreaNotFound])), "a flagged read of no control line is not invalid")
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.10, flags: [.glare])), .unreadable(.quality([.glare])),
                       "a flagged band signal names the flag, so the screen can say what to change")
    }

    /// Rule 4 before rule 5, so the screen can say what to change.
    func testAFlaggedLowConfidenceResultReturnsItsFlags() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, confidence: 0.40, flags: [.tooDark])),
                       .unreadable(.quality([.tooDark])))
    }

    // MARK: - Rule 5: confidence

    /// A strong line with low confidence is not a result.
    func testAStrongLineWithLowConfidenceIsUnreadable() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, confidence: 0.84)), unreadable)
    }

    /// Invalid is a confident statement. An uncertain read of a missing control line is not one.
    func testLowConfidenceBeatsInvalid() {
        XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.00, confidence: 0.84)), unreadable)
    }

    /// Low confidence beats the band too: the specific indeterminate reason is a confident read.
    func testLowConfidenceBeatsTheBand() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.10, confidence: 0.84)), unreadable)
    }

    func testAConfidenceThatIsNotAProbabilityIsUnreadable() {
        for bad in [85, 1.01, Double.nan, .infinity] {
            XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, confidence: bad)), unreadable, "\(bad)")
        }
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, confidence: -0.5)), unreadable)
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80, confidence: -.infinity)), unreadable)
    }

    // MARK: - Rule 6: signals are never clamped

    func testATestSignalOutsideNoughtToOneIsUnreadable() {
        for bad in [1.40, -0.01, Double.nan] {
            XCTAssertEqual(resolve(outcome(control: 0.60, test: bad)), unreadable, "\(bad)")
        }
        XCTAssertEqual(resolve(outcome(control: 0.60, test: .infinity)), unreadable)
    }

    func testAControlSignalOutsideNoughtToOneIsUnreadable() {
        for bad in [Double.nan, 1.2] {
            XCTAssertEqual(resolve(outcome(control: bad, test: 0.80)), unreadable, "\(bad)")
        }
        XCTAssertEqual(resolve(outcome(control: -0.01, test: 0.80)), unreadable, "not invalid: never clamped to nought")
    }

    // MARK: - Rule 7: invalid

    func testNoControlLineAndNoTestLineIsInvalid() {
        XCTAssertEqual(resolve(outcome(control: 0.19, test: 0.00)), .invalid)
    }

    /// A test line with no control line is never detected.
    func testATestLineOnlyIsInvalid() {
        XCTAssertEqual(resolve(outcome(control: 0.00, test: 0.80)), .invalid)
    }

    func testInvalidBeatsTheBand() {
        XCTAssertEqual(resolve(outcome(control: 0.19, test: 0.10)), .invalid)
    }

    // MARK: - Rule 8: test line detected

    func testTheDetectionThresholdIsInclusive() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.15)), detected)
    }

    func testAStrongTestLineIsDetected() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.80)), detected)
    }

    func testTheTopOfBothRangesIsDetected() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 1.00, confidence: 1.00)), detected)
    }

    func testControlAndConfidenceExactlyAtTheirMinimumsAreRead() {
        XCTAssertEqual(resolve(outcome(control: 0.20, test: 0.80, confidence: 0.85)), detected)
    }

    // MARK: - Rule 9: the indeterminate band is never a result

    func testTheLowerBoundIsInsideTheBand() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.05)), indeterminate)
    }

    func testTheMiddleOfTheBandIsIndeterminate() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.10)), indeterminate)
    }

    func testJustUnderTheThresholdIsIndeterminate() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.1499)), indeterminate)
    }

    // MARK: - Rule 10: no test line detected

    func testAControlLineOnlyIsNoTestLine() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.00)), notDetected)
    }

    func testASignalBelowTheBandIsNoTestLine() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.04)), notDetected)
    }

    func testJustUnderTheBandIsNoTestLine() {
        XCTAssertEqual(resolve(outcome(control: 0.60, test: 0.0499)), notDetected)
    }

    // MARK: - Provenance and thresholds come from the configuration

    func testProvenanceCarriesTheConfigurationArgumentsIDAndVersionAndTheScannerVersion() {
        let other = HcgStripConfiguration(
            id: "other-strip", version: "2.0.0", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: 0.20, indeterminateLowerBound: 0.05, detectionThreshold: 0.15,
            minimumConfidence: 0.85,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: 100
        )
        let resolution = HcgScanResolver.resolve(
            outcome(control: 0.60, test: 0.80, id: "other-strip", version: "2.0.0"), configuration: other)

        XCTAssertEqual(resolution, .reading(.testLineDetected, HcgScanProvenance(
            scannerVersion: "0.1.0", configurationID: "other-strip", configurationVersion: "2.0.0")))
        XCTAssertEqual(HcgScanResolver.scannerVersion, "0.1.0")
    }

    /// Nothing in the resolver assumes where the band is: moving it moves the answer.
    func testTheBandIsTheConfigurations() {
        let wide = configuration(lower: 0.30, threshold: 0.70)
        func resolved(_ test: Double) -> HcgScanResolution {
            HcgScanResolver.resolve(outcome(control: 0.60, test: test), configuration: wide)
        }
        XCTAssertEqual(resolved(0.10), notDetected, "in the default band's middle, below this one")
        XCTAssertEqual(resolved(0.29), notDetected)
        XCTAssertEqual(resolved(0.30), indeterminate)
        XCTAssertEqual(resolved(0.69), indeterminate, "detected under the default band")
        XCTAssertEqual(resolved(0.70), detected)
    }

    /// The test signal is judged on its own: a faint control line does not make a line "detected".
    func testTheResolverJudgesTheAbsoluteTestSignalNotARatio() {
        XCTAssertEqual(resolve(outcome(control: 0.20, test: 0.04)), notDetected)
        XCTAssertEqual(resolve(outcome(control: 1.00, test: 0.15)), detected)
        XCTAssertEqual(resolve(outcome(control: 0.20, test: 0.10)), resolve(outcome(control: 1.00, test: 0.10)))
    }

    // MARK: - Sweep

    /// With a valid control line and a confident, clean read, the test signal alone decides: the
    /// answer is never invalid, a reading is only ever one of the two line outcomes, and the
    /// three regions meet exactly at the configuration's two numbers.
    func testSweepingTheTestSignalNeverYieldsInvalidAndReadsOnlyTheTwoLineOutcomes() {
        for step in 0...100 {
            let test = Double(step) / 100
            switch resolve(outcome(control: 0.60, test: test)) {
            case .invalid:
                XCTFail("invalid at \(test) with a valid control line")
            case .reading(let classification, let read):
                XCTAssertNotEqual(classification, .invalid, "a reading is never invalid (\(test))")
                XCTAssertEqual(classification, test >= 0.15 ? .testLineDetected : .noTestLineDetected, "\(test)")
                XCTAssertFalse(test >= 0.05 && test < 0.15, "a band signal became a result at \(test)")
                XCTAssertEqual(read, provenance)
            case .unreadable(let reason):
                XCTAssertEqual(reason, .indeterminateTestLine, "\(test)")
                XCTAssertTrue(test >= 0.05 && test < 0.15, "unreadable outside the band at \(test)")
            }
        }
    }
}
