import AVFoundation
import XCTest
@testable import Genesyx
import GenesyxCore

/// The parts of the camera service that can run on a simulator, which has no camera. Everything
/// that needs a real session (a stop during start, clearing the last frame) is reviewed by reading.
@MainActor
final class ScanCameraTests: XCTestCase {

    private struct SearchingAssessor: ScanFrameAssessing {
        func assess(_ frame: CVPixelBuffer, configuration: any ScanStripGeometry) -> FrameAssessment { .searching }
    }

    func testStartWithoutACameraEndsUnavailableAndStaysThere() async {
        let camera = CameraSessionManager()
        await camera.start()
        XCTAssertEqual(camera.status, .unavailable)
        await camera.start()                  // no-op
        XCTAssertEqual(camera.status, .unavailable)
        camera.stop()
        XCTAssertEqual(camera.status, .unavailable)
    }

    func testCaptureStillThrowsUnavailableWithoutACamera() async {
        let camera = CameraSessionManager()
        await camera.start()
        do {
            _ = try await camera.captureStill()
            XCTFail("captureStill() returned an image without a camera")
        } catch {
            XCTAssertEqual(error as? CameraCaptureError, .unavailable)
        }
    }

    /// A stop that lands while start() is still waiting wins, and the next start is not blocked.
    func testStopDuringStartWinsAndALaterStartStillCompletes() async {
        let camera = CameraSessionManager()
        let starting = Task { await camera.start() }
        while camera.status == .idle { await Task.yield() }
        XCTAssertEqual(camera.status, .preparing)
        camera.stop()
        await starting.value
        XCTAssertEqual(camera.status, .idle)
        await camera.start()
        XCTAssertEqual(camera.status, .unavailable)
    }

    func testEventsYieldTheCurrentStatusFirstThenEveryChange() async {
        let camera = CameraSessionManager()
        var events = camera.events(assessor: SearchingAssessor(), configuration: PhStripConfiguration.developmentPlaceholder).makeAsyncIterator()
        guard case .status(.idle)? = await events.next() else { return XCTFail("expected .status(.idle) first") }
        await camera.start()
        guard case .status(.preparing)? = await events.next() else { return XCTFail("expected .status(.preparing)") }
        guard case .status(.unavailable)? = await events.next() else { return XCTFail("expected .status(.unavailable)") }
    }

    func testASecondConsumerReplacesTheFirst() async {
        let camera = CameraSessionManager()
        var first = camera.events(assessor: SearchingAssessor(), configuration: PhStripConfiguration.developmentPlaceholder).makeAsyncIterator()
        var second = camera.events(assessor: SearchingAssessor(), configuration: PhStripConfiguration.developmentPlaceholder).makeAsyncIterator()
        guard case .status(.idle)? = await first.next() else { return XCTFail("expected the buffered status") }
        let ended = await first.next()
        XCTAssertNil(ended)
        guard case .status(.idle)? = await second.next() else { return XCTFail("expected .status(.idle) first") }
    }

    func testInterruptionReasonMapping() {
        typealias Reason = AVCaptureSession.InterruptionReason
        XCTAssertEqual(CameraSessionManager.interruption(forReason: Reason.videoDeviceNotAvailableInBackground.rawValue), .backgrounded)
        XCTAssertEqual(CameraSessionManager.interruption(forReason: Reason.videoDeviceInUseByAnotherClient.rawValue), .inUseByAnotherApp)
        XCTAssertEqual(CameraSessionManager.interruption(forReason: Reason.videoDeviceNotAvailableWithMultipleForegroundApps.rawValue), .multitasking)
        XCTAssertEqual(CameraSessionManager.interruption(forReason: Reason.videoDeviceNotAvailableDueToSystemPressure.rawValue), .systemPressure)
        XCTAssertEqual(CameraSessionManager.interruption(forReason: Reason.audioDeviceInUseByAnotherClient.rawValue), .other)
        XCTAssertEqual(CameraSessionManager.interruption(forReason: 9_999), .other)
        XCTAssertEqual(CameraSessionManager.interruption(forReason: nil), .other)
    }

    func testAccessMapsToOneOfTheFourCases() {
        let access = CameraSessionManager().access
        XCTAssertTrue([.notDetermined, .authorised, .denied, .restricted].contains(access))
    }
}
