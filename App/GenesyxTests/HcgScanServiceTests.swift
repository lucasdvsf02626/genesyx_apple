import XCTest
@testable import Genesyx
import GenesyxCore

/// Drives a real `HcgScanSession` with the simulated pregnancy test services and no UI.
@MainActor
final class HcgScanServiceTests: XCTestCase {

    /// Returns the final state and whether a capture ran.
    private func run(_ scenario: MockHcgScenario, frames: MockScanScenario = .reading(4.4)) async -> (state: HcgScannerState, captured: Bool) {
        let services = HcgScanServices.debug(scenario: scenario, frames: frames, delay: 0)
        let source = FakeScanFrameSource(scenario: frames, frameInterval: 0.005)
        var session = HcgScanSession(configuration: services.configuration)
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

    func testDetectedIsAReadingWithConfigurationProvenance() async {
        let state = await run(.testLineDetected).state
        guard case .result(.reading(let classification, let provenance)) = state else { return XCTFail("\(state)") }
        XCTAssertEqual(classification, .testLineDetected)
        XCTAssertEqual(provenance.configurationID, HcgStripConfiguration.developmentPlaceholder.id)
        XCTAssertEqual(provenance.configurationVersion, HcgStripConfiguration.developmentPlaceholder.version)
        XCTAssertEqual(provenance.scannerVersion, HcgScanResolver.scannerVersion)
    }

    func testNoTestLineIsAReading() async {
        let state = await run(.noTestLineDetected).state
        guard case .result(.reading(let classification, _)) = state else { return XCTFail("\(state)") }
        XCTAssertEqual(classification, .noTestLineDetected)
    }

    func testAFaintLineIsUnreadableNeverAResult() async {
        let state = await run(.faintLine).state
        XCTAssertEqual(state, .result(.unreadable(.indeterminateTestLine)))
    }

    func testAMissingControlLineIsInvalidNeverDetected() async {
        let none = await run(.invalidNoControl).state
        let testLineOnly = await run(.invalidTestLineOnly).state
        XCTAssertEqual(none, .result(.invalid))
        XCTAssertEqual(testLineOnly, .result(.invalid), "a test line without a control line is not a result")
    }

    func testLowConfidenceAndAnOutOfRangeSignalAreUnreadable() async {
        let unsure = await run(.lowConfidence).state
        let outOfRange = await run(.signalOutOfRange).state
        XCTAssertEqual(unsure, .result(.unreadable(.quality([]))))
        XCTAssertEqual(outOfRange, .result(.unreadable(.quality([]))), "a signal above 1 is never clamped into a result")
    }

    func testUnreadableCarriesTheIssue() async {
        let state = await run(.unreadable(.glare)).state
        XCTAssertEqual(state, .result(.unreadable(.quality([.glare]))))
    }

    func testLiveIssueNeverCaptures() async {
        let outcome = await run(.testLineDetected, frames: .liveIssue(.tooDark))
        XCTAssertEqual(outcome.state, .qualityIssue(.tooDark))
        XCTAssertFalse(outcome.captured, "the analyser must never be asked about a frame with a quality problem")
    }

    func testPermissionDeniedAndCameraUnavailable() async {
        let denied = await run(.noTestLineDetected, frames: .permissionDenied).state
        let unavailable = await run(.noTestLineDetected, frames: .cameraUnavailable).state
        XCTAssertEqual(denied, .permissionDenied)
        XCTAssertEqual(unavailable, .cameraUnavailable)
    }

    func testCancelledCaptureEmitsNoAnalysis() async {
        let services = HcgScanServices.debug(scenario: .testLineDetected, frames: .slowReading)
        let source = FakeScanFrameSource(scenario: .slowReading)
        _ = await source.requestAccess()
        await source.start()
        var emitted: [HcgScanEvent] = []
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
        let services = HcgScanServices.debug(scenario: .noTestLineDetected, frames: .reading(4.4), delay: 0)
        var emitted: [HcgScanEvent] = []
        await services.perform(.captureAndAnalyse, source: FakeScanFrameSource(scenario: .reading(4.4))) { emitted.append($0) }
        XCTAssertEqual(emitted, [.captureFailed])
    }

    func testDebugServicesAreSimulated() {
        XCTAssertTrue(HcgScanServices.debug(scenario: .noTestLineDetected, frames: .reading(4.4)).isSimulated)
    }
}
