import XCTest
@testable import Genesyx
import GenesyxCore

/// Drives a real `PhScanSession` with the simulated services and no UI.
@MainActor
final class ScanServiceTests: XCTestCase {

    private func testImage() -> CGImage {
        CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }

    /// Returns the final state and whether a capture ran.
    private func run(_ scenario: MockScanScenario) async -> (state: ScannerState, captured: Bool) {
        let services = ScanServices.debug(scenario: scenario)
        let source = FakeScanFrameSource(scenario: scenario, frameInterval: 0.005)
        var session = PhScanSession(configuration: services.configuration)
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

    func testReadingIsAcceptedWithConfigurationMetadata() async {
        let outcome = await run(.reading(4.4))
        guard case .result(.reading(let value, let metadata)) = outcome.state else { return XCTFail("\(outcome.state)") }
        XCTAssertEqual(value, 4.4)
        XCTAssertEqual(metadata.configurationID, "genesyx_ph_multizone_v1")
        XCTAssertEqual(metadata.confidence, 0.95)
    }

    func testAnotherReadingValue() async {
        guard case .result(.reading(let value, _)) = await run(.reading(5.2)).state else { return XCTFail() }
        XCTAssertEqual(value, 5.2)
    }

    func testLowConfidenceIsUnreadable() async {
        guard case .result(.unreadable) = await run(.lowConfidence).state else { return XCTFail() }
    }

    func testOutOfRangeIsUnreadableNeverClamped() async {
        let state = await run(.outOfRange).state
        guard case .result(.unreadable) = state else { return XCTFail("\(state)") }
    }

    func testUnreadableCarriesTheIssue() async {
        let state = await run(.unreadable(.glare)).state
        XCTAssertEqual(state, .result(.unreadable([.glare])))
    }

    func testLiveIssueNeverCaptures() async {
        let outcome = await run(.liveIssue(.tooDark))
        XCTAssertEqual(outcome.state, .qualityIssue(.tooDark))
        XCTAssertFalse(outcome.captured)
    }

    func testPermissionDeniedAndCameraUnavailable() async {
        let denied = await run(.permissionDenied).state
        let unavailable = await run(.cameraUnavailable).state
        XCTAssertEqual(denied, .permissionDenied)
        XCTAssertEqual(unavailable, .cameraUnavailable)
    }

    func testCancelledCaptureEmitsNoAnalysis() async {
        let scenario = MockScanScenario.slowReading
        let services = ScanServices.debug(scenario: scenario)
        let source = FakeScanFrameSource(scenario: scenario)
        _ = await source.requestAccess()
        await source.start()
        var emitted: [ScanEvent] = []
        let task = Task { @MainActor in
            await services.perform(.captureAndAnalyse, source: source) { emitted.append($0) }
        }
        while emitted.isEmpty { await Task.yield() }
        task.cancel()
        await task.value
        source.stop()
        XCTAssertEqual(emitted, [.stillCaptured])
    }

    func testSuppliedTestImageIsUsedWithoutACamera() async {
        let services = ScanServices.debug(scenario: .reading(4.4))
        let source = FakeScanFrameSource(scenario: .reading(4.4))     // never started: captureStill() would throw
        var emitted: [ScanEvent] = []
        await services.perform(.captureAndAnalyse, source: source, testImage: testImage()) { emitted.append($0) }
        XCTAssertEqual(emitted.first, .stillCaptured)
        XCTAssertEqual(emitted.count, 2)
    }

    func testCaptureWithoutARunningCameraFails() async {
        let services = ScanServices.debug(scenario: .reading(4.4))
        var emitted: [ScanEvent] = []
        await services.perform(.captureAndAnalyse, source: FakeScanFrameSource(scenario: .reading(4.4))) { emitted.append($0) }
        XCTAssertEqual(emitted, [.captureFailed])
    }

    func testLaunchValuesParse() {
        XCTAssertEqual(MockScanScenario(launchValue: "reading-4.4"), .reading(4.4))
        XCTAssertEqual(MockScanScenario(launchValue: "reading-5.2"), .reading(5.2))
        XCTAssertEqual(MockScanScenario(launchValue: "slowReading"), .slowReading)
        XCTAssertEqual(MockScanScenario(launchValue: "awayReading"), .awayReading)
        XCTAssertEqual(MockScanScenario(launchValue: "lowConfidence"), .lowConfidence)
        XCTAssertEqual(MockScanScenario(launchValue: "outOfRange"), .outOfRange)
        XCTAssertEqual(MockScanScenario(launchValue: "unreadable-glare"), .unreadable(.glare))
        XCTAssertEqual(MockScanScenario(launchValue: "issue-tooDark"), .liveIssue(.tooDark))
        XCTAssertEqual(MockScanScenario(launchValue: "permissionDenied"), .permissionDenied)
        XCTAssertEqual(MockScanScenario(launchValue: "cameraUnavailable"), .cameraUnavailable)
        XCTAssertNil(MockScanScenario(launchValue: "nonsense"))
    }

    func testDebugServicesAreSimulated() {
        XCTAssertTrue(ScanServices.debug(scenario: .reading(4.4)).isSimulated)
    }
}
