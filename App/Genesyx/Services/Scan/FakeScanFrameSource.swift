#if DEBUG
import CoreGraphics
import CoreVideo
import Foundation
import GenesyxCore
import SwiftUI

/// A camera that is not one, for the simulator and for UI tests. Frames are a tiny dummy buffer
/// handed to the assessor; nothing is read from a device or written anywhere.
@MainActor
final class FakeScanFrameSource: ScanFrameSource {
    private let scenario: MockScanScenario
    private let frameInterval: TimeInterval
    private let sink = FakeFrameSink()
    private var continuation: AsyncStream<ScanFrameSourceEvent>.Continuation?
    private var frameTask: Task<Void, Never>?
    private var requested = false
    private let buffer: CVPixelBuffer?

    private var status: ScanCameraStatus = .idle {
        didSet { if status != oldValue { continuation?.yield(.status(status)) } }
    }

    init(scenario: MockScanScenario, frameInterval: TimeInterval = 0.125) {
        self.scenario = scenario
        self.frameInterval = frameInterval
        var made: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, nil, &made)
        buffer = made
    }

    var access: CameraAccess {
        switch scenario {
        case .permissionDenied: return .denied
        case .cameraUnavailable: return .restricted
        default: return requested ? .authorised : .notDetermined
        }
    }

    func requestAccess() async -> Bool {
        requested = true
        if case .permissionDenied = scenario { return false }
        return true
    }

    func events(assessor: any ScanFrameAssessing, configuration: any ScanStripGeometry) -> AsyncStream<ScanFrameSourceEvent> {
        continuation?.finish()
        let sink = sink
        let (stream, continuation) = AsyncStream.makeStream(of: ScanFrameSourceEvent.self)
        self.continuation = continuation
        continuation.yield(.status(status))
        sink.handler = { buffer, time in
            continuation.yield(.frame(assessor.assess(buffer, configuration: configuration), at: time))
        }
        continuation.onTermination = { _ in sink.handler = nil }
        return stream
    }

    func start() async {
        guard status == .idle || status == .failed, let buffer else { return }
        status = .preparing
        status = .running
        let sink = sink
        let interval = frameInterval
        // Synthetic time: exactly 0.125 s per frame whatever the real interval, so a test can run
        // fast and still satisfy the stability window.
        frameTask = Task.detached(priority: .utility) {
            var time: TimeInterval = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                time += 0.125
                sink.deliver(buffer, at: time)
            }
        }
    }

    func stop() {
        guard status != .idle, status != .unavailable else { return }
        frameTask?.cancel()
        frameTask = nil
        status = .idle
    }

    func captureStill() async throws -> CGImage {
        guard status == .running else { throw CameraCaptureError.notRunning }
        guard let context = CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { throw CameraCaptureError.captureFailed }
        return image
    }

    func makePreview() -> AnyView {
        AnyView(
            // In a corner, clear of the strip outline drawn over the middle of the preview.
            ZStack(alignment: .bottomLeading) {
                Color(white: 0.1)
                Text("Simulated camera").foregroundColor(.white).padding(12)
            }
        )
    }
}

/// Hands frames from the delivery task to whichever consumer is attached.
private final class FakeFrameSink: @unchecked Sendable {
    private let lock = NSLock()
    private var current: (@Sendable (CVPixelBuffer, TimeInterval) -> Void)?

    var handler: (@Sendable (CVPixelBuffer, TimeInterval) -> Void)? {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    func deliver(_ buffer: CVPixelBuffer, at time: TimeInterval) {
        handler?(buffer, time)
    }
}
#endif
