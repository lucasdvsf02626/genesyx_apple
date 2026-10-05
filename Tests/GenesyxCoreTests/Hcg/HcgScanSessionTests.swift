import XCTest
@testable import GenesyxCore

/// The pregnancy test flow's wiring into the shared reducer. The transition table itself is
/// proved once, by `PhScanSessionTests`; these show that a session ends in an `HcgScanResolution`,
/// that it goes through `HcgScanResolver`, and that the stability window is the configuration's.
final class HcgScanSessionTests: XCTestCase {

    /// The test configuration. Its numbers are its own, not the placeholder's.
    private func configuration(stableMilliseconds: Int = 100) -> HcgStripConfiguration {
        HcgStripConfiguration(
            id: "strip-test", version: "9.9.9", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: 0.20, indeterminateLowerBound: 0.05, detectionThreshold: 0.15,
            minimumConfidence: 0.85,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: stableMilliseconds
        )
    }

    private func outcome(control: Double, test: Double, confidence: Double = 0.95) -> HcgAnalysisOutcome {
        .result(HcgAnalysisResult(testSignal: test, controlSignal: control, confidence: confidence,
                                  configurationID: "strip-test", configurationVersion: "9.9.9"))
    }

    private let provenance = HcgScanProvenance(scannerVersion: HcgScanResolver.scannerVersion,
                                               configurationID: "strip-test", configurationVersion: "9.9.9")

    /// From `idle` to `capturing` the way the app gets there: permission, camera, then `ready`
    /// frames held across the configuration's stability window.
    private func capturingSession(line: UInt = #line) -> HcgScanSession {
        var session = HcgScanSession(configuration: configuration())
        XCTAssertEqual(session.state, .idle, line: line)
        let events: [HcgScanEvent] = [.begin(.authorised), .camera(.running),
                                      .frame(.ready, at: 0), .frame(.ready, at: 0.1)]
        events.forEach { session.handle($0) }
        XCTAssertEqual(session.state, .capturing, "the stability window did not capture", line: line)
        return session
    }

    /// The whole flow, ending with the analyser's `outcome`.
    private func state(after outcome: HcgAnalysisOutcome, line: UInt = #line) -> HcgScannerState {
        var session = capturingSession(line: line)
        session.handle(.stillCaptured)
        XCTAssertEqual(session.state, .analysing, line: line)
        session.handle(.analysed(outcome))
        return session.state
    }

    // MARK: - An outcome reaches `.result` only through the resolver

    func testADetectedOutcomeEndsInADetectedReading() {
        XCTAssertEqual(state(after: outcome(control: 0.60, test: 0.80)),
                       .result(.reading(.testLineDetected, provenance)))
    }

    func testANotDetectedOutcomeEndsInANotDetectedReading() {
        XCTAssertEqual(state(after: outcome(control: 0.60, test: 0.00)),
                       .result(.reading(.noTestLineDetected, provenance)))
    }

    /// The analyser's estimate is not shown as it stands: a strong line it was unsure of is unreadable.
    func testALowConfidenceDetectedOutcomeEndsUnreadable() {
        XCTAssertEqual(state(after: outcome(control: 0.60, test: 0.80, confidence: 0.84)),
                       .result(.unreadable(.quality([]))))
    }

    func testABandSignalEndsUnreadableWithTheIndeterminateReason() {
        XCTAssertEqual(state(after: outcome(control: 0.60, test: 0.10)),
                       .result(.unreadable(.indeterminateTestLine)))
    }

    func testAMissingControlLineEndsInInvalid() {
        XCTAssertEqual(state(after: outcome(control: 0.00, test: 0.80)), .result(.invalid))
    }

    func testAnUnreadableOutcomeEndsInUnreadableWithItsIssues() {
        XCTAssertEqual(state(after: .unreadable([.glare])), .result(.unreadable(.quality([.glare]))))
    }

    /// The session resolves against its own configuration, not one the outcome names.
    func testAnOutcomeFromAnotherConfigurationIsUnreadable() {
        let foreign = HcgAnalysisOutcome.result(HcgAnalysisResult(
            testSignal: 0.80, controlSignal: 0.60, confidence: 0.95,
            configurationID: "strip-test", configurationVersion: "1.0.0"))
        XCTAssertEqual(state(after: foreign), .result(.unreadable(.quality([]))))
    }

    func testCaptureFailedIsUnreadableForNoNameableReason() {
        XCTAssertEqual(HcgStripConfiguration.captureFailed, .unreadable(.quality([])))

        var session = capturingSession()
        session.handle(.captureFailed)
        XCTAssertEqual(session.state, .result(.unreadable(.quality([]))))
    }

    // MARK: - The stability window is the configuration's

    func testTheStabilityWindowComesFromTheConfiguration() {
        var session = HcgScanSession(configuration: configuration(stableMilliseconds: 1000))
        let events: [HcgScanEvent] = [.begin(.authorised), .camera(.running),
                                      .frame(.ready, at: 0), .frame(.ready, at: 0.9)]
        events.forEach { session.handle($0) }
        XCTAssertEqual(session.state, .ready, "0.9 s is inside a 1000 ms window")
        XCTAssertNil(session.work)

        session.handle(.frame(.ready, at: 1.0))
        XCTAssertEqual(session.state, .capturing)
        XCTAssertEqual(session.work, .captureAndAnalyse)
    }

    // MARK: - Backgrounding and late answers

    /// A scan in flight is dropped when the app leaves the foreground; its answer never lands.
    func testSuspendedWhileAnalysingIsInterruptedAndALateAnswerIsIgnored() {
        var session = capturingSession()
        session.handle(.stillCaptured)
        XCTAssertEqual(session.state, .analysing)

        session.handle(.suspended)
        XCTAssertEqual(session.state, .interrupted(.backgrounded))

        session.handle(.analysed(outcome(control: 0.60, test: 0.80)))
        XCTAssertEqual(session.state, .interrupted(.backgrounded), "a late answer must not become a result")
    }

    func testBeginFromAResultRestarts() {
        for finished in [outcome(control: 0.60, test: 0.80), outcome(control: 0.00, test: 0.80),
                         outcome(control: 0.60, test: 0.10), .unreadable([])] {
            var session = capturingSession()
            session.handle(.stillCaptured)
            session.handle(.analysed(finished))
            guard case .result = session.state else { return XCTFail("\(finished) did not end in a result") }
            XCTAssertFalse(session.wantsCamera)

            session.handle(.begin(.authorised))
            XCTAssertEqual(session.state, .preparingCamera)
            XCTAssertEqual(session.work, .startCamera)
        }
    }
}
