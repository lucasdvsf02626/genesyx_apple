import XCTest
@testable import GenesyxCore

/// The LH flow's wiring into the shared reducer. The transition table itself is proved once, by
/// `PhScanSessionTests`; these show that an LH session ends in an LH resolution, that it goes
/// through `LhScanResolver`, and that the stability window is the LH configuration's.
final class LhScanSessionTests: XCTestCase {

    /// The test configuration. Its numbers are its own, not the placeholder's.
    private func configuration(stableMilliseconds: Int = 100) -> LhStripConfiguration {
        LhStripConfiguration(
            id: "t", version: "1", expectedAspectRatio: 10,
            testLineRegion: NormalisedRect(x: 0.4, y: 0, width: 0.05, height: 1),
            controlLineRegion: NormalisedRect(x: 0.5, y: 0, width: 0.05, height: 1),
            minimumControlSignal: 0.20, positiveThreshold: 0.90, risingThreshold: 0.50,
            risingEnabled: false, minimumConfidence: 0.85,
            developmentTimeSeconds: 0, maximumReadTimeSeconds: nil, stableDetectionMilliseconds: stableMilliseconds
        )
    }

    private func outcome(control: Double, test: Double, confidence: Double = 0.95) -> LhAnalysisOutcome {
        .result(LhAnalysisResult(testSignal: test, controlSignal: control, confidence: confidence,
                                 configurationID: "t", configurationVersion: "1"))
    }

    private func measurement(control: Double, test: Double) -> LhScanMeasurement {
        LhScanMeasurement(testSignal: test, controlSignal: control, testControlRatio: test / control,
                          confidence: 0.95, scannerVersion: LhScanResolver.scannerVersion,
                          configurationID: "t", configurationVersion: "1")
    }

    /// From `idle` to `capturing` the way the app gets there: permission, camera, then `ready`
    /// frames held across the configuration's stability window.
    private func capturingSession(line: UInt = #line) -> LhScanSession {
        var session = LhScanSession(configuration: configuration())
        XCTAssertEqual(session.state, .idle, line: line)
        let events: [LhScanEvent] = [.begin(.authorised), .camera(.running),
                                     .frame(.ready, at: 0), .frame(.ready, at: 0.1)]
        events.forEach { session.handle($0) }
        XCTAssertEqual(session.state, .capturing, "the stability window did not capture", line: line)
        return session
    }

    /// The whole flow, ending with the analyser's `outcome`.
    private func state(after outcome: LhAnalysisOutcome, line: UInt = #line) -> LhScannerState {
        var session = capturingSession(line: line)
        session.handle(.stillCaptured)
        XCTAssertEqual(session.state, .analysing, line: line)
        session.handle(.analysed(outcome))
        return session.state
    }

    // MARK: - An outcome becomes an LH resolution

    func testALowOutcomeEndsInALowReading() {
        XCTAssertEqual(state(after: outcome(control: 0.60, test: 0.06)),
                       .result(.reading(.low, measurement(control: 0.60, test: 0.06))))
    }

    func testAPositiveOutcomeEndsInAPositiveReading() {
        XCTAssertEqual(state(after: outcome(control: 0.50, test: 0.80)),
                       .result(.reading(.positive, measurement(control: 0.50, test: 0.80))))
    }

    func testAMissingControlLineEndsInInvalid() {
        XCTAssertEqual(state(after: outcome(control: 0.00, test: 0.80)), .result(.invalid))
    }

    func testAnUnreadableOutcomeEndsInUnreadableWithItsIssues() {
        XCTAssertEqual(state(after: .unreadable([.glare])), .result(.unreadable([.glare])))
    }

    /// Invalid is a confident statement, so an unsure read of a missing control is unreadable.
    func testALowConfidenceOutcomeWithNoControlIsUnreadableNotInvalid() {
        XCTAssertEqual(state(after: outcome(control: 0.00, test: 0.00, confidence: 0.84)), .result(.unreadable([])))
    }

    /// The session resolves against its own configuration, not one the outcome names.
    func testAnOutcomeFromAnotherConfigurationIsUnreadable() {
        let foreign = LhAnalysisOutcome.result(LhAnalysisResult(testSignal: 0.80, controlSignal: 0.50, confidence: 0.95,
                                                                configurationID: "t", configurationVersion: "2"))
        XCTAssertEqual(state(after: foreign), .result(.unreadable([])))
    }

    func testAFailedCaptureEndsInUnreadable() {
        var session = capturingSession()
        session.handle(.captureFailed)
        XCTAssertEqual(session.state, .result(.unreadable([])))
    }

    // MARK: - The stability window is the LH configuration's

    func testTheStabilityWindowComesFromTheLhConfiguration() {
        var session = LhScanSession(configuration: configuration(stableMilliseconds: 1000))
        let events: [LhScanEvent] = [.begin(.authorised), .camera(.running),
                                     .frame(.ready, at: 0), .frame(.ready, at: 0.9)]
        events.forEach { session.handle($0) }
        XCTAssertEqual(session.state, .ready, "0.9 s is inside a 1000 ms window")
        XCTAssertNil(session.work)

        session.handle(.frame(.ready, at: 1.0))
        XCTAssertEqual(session.state, .capturing)
        XCTAssertEqual(session.work, .captureAndAnalyse)
    }

    // MARK: - Restart and late answers

    func testBeginFromAnLhResultRestarts() {
        for finished in [outcome(control: 0.50, test: 0.80), outcome(control: 0.00, test: 0.80), .unreadable([])] {
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

    func testAnAnalysedEventWhileNotAnalysingIsIgnored() {
        let positive = outcome(control: 0.50, test: 0.80)

        var idle = LhScanSession(configuration: configuration())
        idle.handle(.analysed(positive))
        XCTAssertEqual(idle.state, .idle)

        var capturing = capturingSession()
        capturing.handle(.analysed(positive))
        XCTAssertEqual(capturing.state, .capturing)

        var backgrounded = capturingSession()
        backgrounded.handle(.stillCaptured)
        backgrounded.handle(.suspended)
        backgrounded.handle(.analysed(positive))
        XCTAssertEqual(backgrounded.state, .interrupted(.backgrounded), "a late answer must not become a result")
    }
}
