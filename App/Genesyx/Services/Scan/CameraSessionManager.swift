@preconcurrency import AVFoundation
import CoreImage
import GenesyxCore
import SwiftUI
import UIKit

/// Owns the rear camera session for the Scan Test feature.
///
/// Still capture reuses the newest full-resolution video frame instead of adding an
/// `AVCapturePhotoOutput`: the analyser works on pixels, not on a processed photo, so one output
/// and one pipeline is enough, and there is no shutter sound or flash path to manage. Nothing is
/// ever written to disk, Photos or logs.
@MainActor
final class CameraSessionManager: NSObject, ObservableObject, ScanFrameSource {
    @Published private(set) var status: ScanCameraStatus = .idle {
        didSet { if status != oldValue { continuation?.yield(.status(status)) } }
    }

    nonisolated let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.genesyx.scan.session")
    // Frames get their own queue so an assessor or a still render never blocks stopRunning().
    private let videoQueue = DispatchQueue(label: "com.genesyx.scan.video")
    private let frameSink: FrameSink
    private let videoOutput = AVCaptureVideoDataOutput()
    private var continuation: AsyncStream<ScanFrameSourceEvent>.Continuation?
    /// Bumped by every start() and stop(), so a start that was overtaken never publishes its result.
    private var generation = 0
    private var observers: [NSObjectProtocol] = []

    init(frameRate: Double = 8) {
        frameSink = FrameSink(minimumInterval: 1 / max(frameRate, 1))
        super.init()
        observe()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func events(assessor: any ScanFrameAssessing, configuration: any ScanStripGeometry) -> AsyncStream<ScanFrameSourceEvent> {
        // Finishing the previous stream runs its onTermination, so it must happen before the new handler is set.
        continuation?.finish()
        let sink = frameSink
        let (stream, continuation) = AsyncStream.makeStream(of: ScanFrameSourceEvent.self)
        self.continuation = continuation
        continuation.yield(.status(status))
        sink.onFrame = { buffer in
            let assessment = assessor.assess(buffer, configuration: configuration)
            continuation.yield(.frame(assessment, at: ProcessInfo.processInfo.systemUptime))
        }
        continuation.onTermination = { _ in sink.onFrame = nil }
        return stream
    }

    func start() async {
        guard status == .idle || status == .failed else { return }
        status = .preparing
        generation += 1
        let started = generation
        let queue = sessionQueue
        let videoQueue = videoQueue
        let session = session
        let output = videoOutput
        let sink = frameSink

        let result: ScanCameraStatus = await withCheckedContinuation { continuation in
            queue.async {
                // Decided here, on the queue that owns the session: a start that was stopped before
                // it finished has still added its input, and must not configure a second time.
                if session.inputs.isEmpty {
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                          let input = try? AVCaptureDeviceInput(device: device) else {
                        continuation.resume(returning: .unavailable)
                        return
                    }
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    guard session.canAddInput(input), session.canAddOutput(output) else {
                        session.commitConfiguration()
                        continuation.resume(returning: .failed)
                        return
                    }
                    session.addInput(input)
                    output.alwaysDiscardsLateVideoFrames = true
                    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    output.setSampleBufferDelegate(sink, queue: videoQueue)
                    session.addOutput(output)
                    // Portrait capture, so frames and stills arrive upright.
                    if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                        // Moving to videoRotationAngle is deferred to the physical-device session (ADR D7).
                        connection.videoOrientation = .portrait
                    }
                    session.commitConfiguration()
                    if (try? device.lockForConfiguration()) != nil {
                        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                        device.unlockForConfiguration()
                    }
                }
                #if DEBUG
                sink.armDiagnostic()
                #endif
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: session.isRunning ? .running : .failed)
            }
        }

        // A stop() during the await wins; it has already queued its stopRunning behind the block above.
        guard started == generation, status == .preparing else { return }
        status = result
    }

    func stop() {
        guard status != .idle, status != .unavailable else { return }
        status = .idle
        generation += 1
        let session = session
        let videoQueue = videoQueue
        let sink = frameSink
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
            // Cleared behind any frame still in flight on the video queue, so none outlives the scan.
            videoQueue.async { sink.clear() }
        }
    }

    /// Returns the newest full-resolution frame as an upright image.
    func captureStill() async throws -> CGImage {
        guard status != .unavailable else { throw CameraCaptureError.unavailable }
        guard status == .running else { throw CameraCaptureError.notRunning }
        let sink = frameSink
        let image: CGImage? = await withCheckedContinuation { continuation in
            sessionQueue.async { continuation.resume(returning: sink.latestImage()) }
        }
        guard let image else { throw CameraCaptureError.captureFailed }
        return image
    }

    func makePreview() -> AnyView {
        AnyView(CameraPreviewView(session: session))
    }

    nonisolated static func interruption(forReason rawValue: Int?) -> ScanInterruption {
        switch rawValue.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:)) {
        case .videoDeviceNotAvailableInBackground: return .backgrounded
        case .videoDeviceInUseByAnotherClient: return .inUseByAnotherApp
        case .videoDeviceNotAvailableWithMultipleForegroundApps: return .multitasking
        case .videoDeviceNotAvailableDueToSystemPressure: return .systemPressure
        default: return .other
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        let session = session
        observers = [
            center.addObserver(forName: .AVCaptureSessionWasInterrupted, object: session, queue: .main) { [weak self] note in
                let reason = Self.interruption(forReason: note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                MainActor.assumeIsolated { self?.markInterrupted(reason) }
            },
            center.addObserver(forName: .AVCaptureSessionInterruptionEnded, object: session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.markResumed() }
            },
            center.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: .main) { [weak self] note in
                let code = (note.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.code
                MainActor.assumeIsolated { self?.recoverFromRuntimeError(code) }
            },
        ]
    }

    private func markInterrupted(_ reason: ScanInterruption) {
        // A still taken after the interruption must never be a frame from before it.
        frameSink.clear()
        if status == .running { status = .interrupted(reason) }
    }

    private func markResumed() {
        if case .interrupted = status { status = .running }
    }

    /// A media services reset stops the session; restart it once and report the interruption until
    /// it is back. Any other runtime error is final, because restarting on it can loop.
    private func recoverFromRuntimeError(_ code: AVError.Code?) {
        frameSink.clear()
        guard status == .running || status.isInterrupted else { return }
        guard code == .mediaServicesWereReset else {
            status = .failed
            return
        }
        status = .interrupted(.other)
        let session = session
        sessionQueue.async { [weak self] in
            if !session.isRunning { session.startRunning() }
            let running = session.isRunning
            Task { @MainActor in
                guard let self, self.status.isInterrupted else { return }
                self.status = running ? .running : .failed
            }
        }
    }
}

private extension ScanCameraStatus {
    var isInterrupted: Bool {
        if case .interrupted = self { return true }
        return false
    }
}

/// Receives frames on the video queue. Isolated from the main actor on purpose, with `lock`
/// guarding the few fields shared with the main actor and the session queue.
private final class FrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let minimumInterval: Double
    private var handler: (@Sendable (CVPixelBuffer) -> Void)?
    private var lastDelivered = 0.0
    // Retained only so captureStill() can render it; replaced every frame, never persisted.
    private var latest: CVPixelBuffer?
    private let ciContext = CIContext()
    #if DEBUG
    private var diagnosticPending = false
    #endif

    init(minimumInterval: Double) {
        self.minimumInterval = minimumInterval
    }

    var onFrame: (@Sendable (CVPixelBuffer) -> Void)? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    func clear() {
        lock.withLock { latest = nil }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        #if DEBUG
        printDiagnosticOnce(buffer)
        #endif
        let now = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let deliver: (@Sendable (CVPixelBuffer) -> Void)? = lock.withLock {
            latest = buffer
            guard now - lastDelivered >= minimumInterval else { return nil }
            lastDelivered = now
            return handler
        }
        deliver?(buffer)
    }

    func latestImage() -> CGImage? {
        guard let buffer = lock.withLock({ latest }) else { return nil }
        let image = CIImage(cvPixelBuffer: buffer)
        return ciContext.createCGImage(image, from: image.extent)
    }

    #if DEBUG
    func armDiagnostic() {
        lock.withLock { diagnosticPending = true }
    }

    /// Buffer geometry and colour space for the first frame after each start. Never pixel data.
    private func printDiagnosticOnce(_ buffer: CVPixelBuffer) {
        let pending = lock.withLock {
            defer { diagnosticPending = false }
            return diagnosticPending
        }
        guard pending else { return }
        let colourSpace = CVBufferCopyAttachment(buffer, kCVImageBufferCGColorSpaceKey, nil)
            .map { ($0 as! CGColorSpace).name.map { $0 as String } ?? "unnamed" } ?? "none"
        print("[Scan] first frame \(CVPixelBufferGetWidth(buffer))x\(CVPixelBufferGetHeight(buffer)) format \(CVPixelBufferGetPixelFormatType(buffer)) colour space \(colourSpace)")
    }
    #endif
}
