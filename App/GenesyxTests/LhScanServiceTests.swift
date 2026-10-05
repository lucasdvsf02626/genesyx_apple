import XCTest
@testable import Genesyx
import GenesyxCore

/// Drives a real `LhScanSession` with the simulated LH services and no UI.
@MainActor
final class LhScanServiceTests: XCTestCase {

    /// Returns the final state and whether a capture ran.
    private func run(_ scenario: MockLhScenario, frames: MockScanScenario = .reading(4.4)) async -> (state: LhScannerState, captured: Bool) {
        let services = LhScanServices.debug(scenario: scenario, frames: frames, delay: 0)
        let source = FakeScanFrameSource(scenario: frames, frameInterval: 0.005)
        var session = LhScanSession(configuration: services.configuration)
        session.handle(.begin(source.access))

        while session.work == .requestPermission {
            await services.perform(.requestPermission, source: source) { session.handle($0) }
        }
        if session.work == .startCamera {
            await services.perform(.startCamera, source: source) { session.handle($0) }
            var frames = 0
            for await event in source.events(assessor: services.makeAssessor(), configuration: services.configuration) {
                switch event {
                case .status(let status): session.handle(.camera(status))
                case .frame(let assessment, let time):
                    session.handle(.frame(assessment, at: time))
                    frames += 1
                }
                if session.state == .capturing || !session.state.isLiveGuidance && session.state != .preparingCamera || frames >= 40 { break }
            }
        }
        var captured = false
        if session.state == .capturing {
            captured = true
            await services.perform(.captureAndAnalyse, source: source) { session.handle($0) }
        }
        source.stop()
        return (session.state, captured)
    }

    private func classification(_ scenario: MockLhScenario) async -> LhClassification? {
        guard case .result(.reading(let classification, _)) = await run(scenario).state else { return nil }
        return classification
    }

    func testLowAndAFaintTestLineAreLowReadings() async {
        let low = await classification(.low)
        let faint = await classification(.faintTestLine)
        XCTAssertEqual(low, .low)
        XCTAssertEqual(faint, .low, "a faint test line is not a positive")
    }

    func testPositiveIsAPositiveReadingWithConfigurationMetadata() async {
        let state = await run(.positive).state
        guard case .result(.reading(let classification, let measurement)) = state else { return XCTFail("\(state)") }
        XCTAssertEqual(classification, .positive)
        XCTAssertEqual(measurement.configurationID, LhStripConfiguration.developmentPlaceholder.id)
        XCTAssertEqual(measurement.confidence, 0.95)
    }

    /// The placeholder does not enable rising, so its signals read as low.
    func testRisingIsLowWhileThePlaceholderDisablesIt() async {
        XCTAssertFalse(LhStripConfiguration.developmentPlaceholder.risingEnabled)
        let rising = await classification(.rising)
        XCTAssertEqual(rising, .low)
    }

    func testAMissingControlLineIsInvalidNeverPositive() async {
        let none = await run(.invalidNoControl).state
        let testLineOnly = await run(.invalidTestLineOnly).state
        XCTAssertEqual(none, .result(.invalid))
        XCTAssertEqual(testLineOnly, .result(.invalid), "a test line without a control line is not a result")
    }

    func testLowConfidenceAndAnOutOfRangeSignalAreUnreadable() async {
        let unsure = await run(.lowConfidence).state
        let outOfRange = await run(.signalOutOfRange).state
        XCTAssertEqual(unsure, .result(.unreadable([])))
        XCTAssertEqual(outOfRange, .result(.unreadable([])), "a signal above 1 is never clamped into a result")
    }

    func testUnreadableCarriesTheIssue() async {
        let state = await run(.unreadable(.glare)).state
        XCTAssertEqual(state, .result(.unreadable([.glare])))
    }

    func testLiveIssueNeverCaptures() async {
        let outcome = await run(.positive, frames: .liveIssue(.tooDark))
        XCTAssertEqual(outcome.state, .qualityIssue(.tooDark))
        XCTAssertFalse(outcome.captured, "the analyser must never be asked about a frame with a quality problem")
    }

    func testPermissionDeniedAndCameraUnavailable() async {
        let denied = await run(.low, frames: .permissionDenied).state
        let unavailable = await run(.low, frames: .cameraUnavailable).state
        XCTAssertEqual(denied, .permissionDenied)
        XCTAssertEqual(unavailable, .cameraUnavailable)
    }

    func testCancelledCaptureEmitsNoAnalysis() async {
        let services = LhScanServices.debug(scenario: .positive, frames: .slowReading)
        let source = FakeScanFrameSource(scenario: .slowReading)
        _ = await source.requestAccess()
        await source.start()
        var emitted: [LhScanEvent] = []
        let task = Task { @MainActor in
            await services.perform(.captureAndAnalyse, source: source) { emitted.append($0) }
        }
        while emitted.isEmpty { await Task.yield() }
        task.cancel()
        await task.value
        source.stop()
        XCTAssertEqual(emitted, [.stillCaptured])
    }

    func testCaptureWithoutARunningCameraFails() async {
        let services = LhScanServices.debug(scenario: .low, frames: .reading(4.4), delay: 0)
        var emitted: [LhScanEvent] = []
        await services.perform(.captureAndAnalyse, source: FakeScanFrameSource(scenario: .reading(4.4))) { emitted.append($0) }
        XCTAssertEqual(emitted, [.captureFailed])
    }

    func testDebugServicesAreSimulated() {
        XCTAssertTrue(LhScanServices.debug(scenario: .low, frames: .reading(4.4)).isSimulated)
    }
}
