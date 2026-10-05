import CoreGraphics
import CoreVideo
import GenesyxCore
import SwiftUI

/// Reads one captured image. Phase 1 has only a mock implementation.
protocol PhTestAnalyzing: Sendable {
    func analyse(_ image: CGImage, configuration: PhStripConfiguration) async -> PhAnalysisOutcome
}

/// Judges one live frame. Called on the frame delivery queue, never on the main thread.
protocol ScanFrameAssessing: Sendable {
    func assess(_ frame: CVPixelBuffer, configuration: any ScanStripGeometry) -> FrameAssessment
}

enum ScanFrameSourceEvent: Sendable {
    case status(ScanCameraStatus)
    case frame(FrameAssessment, at: TimeInterval)    // monotonic seconds, taken when the frame arrived
}

/// Everything the scan flow needs from a camera, so views and tests never touch AVFoundation.
@MainActor
protocol ScanFrameSource: AnyObject {
    var access: CameraAccess { get }
    func requestAccess() async -> Bool
    /// One consumer at a time. Yields the current status first, then every status change and one
    /// assessment per delivered frame. The assessor runs on the delivery queue; only its result
    /// crosses to the consumer. Ending the stream detaches the assessor.
    func events(assessor: any ScanFrameAssessing, configuration: any ScanStripGeometry) -> AsyncStream<ScanFrameSourceEvent>
    func start() async
    func stop()
    func captureStill() async throws -> CGImage
    func makePreview() -> AnyView
}
