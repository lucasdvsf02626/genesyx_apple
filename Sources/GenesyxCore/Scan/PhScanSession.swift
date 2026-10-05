import Foundation

/// What the camera flow needs to know about a strip's shape, whichever strip it is.
public protocol ScanStripGeometry: Sendable {
    /// Width divided by height of the strip as it is presented to the camera.
    var expectedAspectRatio: Double { get }
    var stableDetectionMilliseconds: Int { get }
}

/// A strip configuration the flow reducer can run: it knows how an analyser's outcome becomes a
/// resolution, and what a capture that produced no image resolves to.
public protocol ScanFlowRules: ScanStripGeometry, Hashable {
    associatedtype Outcome: Hashable & Sendable
    associatedtype Resolution: Hashable & Sendable
    func resolve(_ outcome: Outcome) -> Resolution
    static var captureFailed: Resolution { get }
}

/// Everything that can happen to a scan. The view turns taps, camera reports and finished work
/// into these; `ScanSession` decides what each one means.
public enum ScanFlowEvent<Outcome: Hashable & Sendable>: Hashable, Sendable {
    /// Open Camera, Scan Again, Try Again.
    case begin(CameraAccess)
    case permissionResolved(granted: Bool)
    case camera(ScanCameraStatus)
    /// Seconds on any monotonic clock.
    case frame(FrameAssessment, at: TimeInterval)
    /// Capture now (the DEBUG test image; later a manual shutter).
    case captureRequested
    case stillCaptured
    case captureFailed
    case analysed(Outcome)
    /// The app left the foreground.
    case suspended
    case resumed
}

/// The pH flow's events. Kept so every existing pH name still compiles.
public typealias ScanEvent = ScanFlowEvent<PhAnalysisOutcome>

/// The asynchronous job a state is waiting on. The view runs it; this type never does.
public enum ScanWork: Hashable, Sendable { case requestPermission, startCamera, captureAndAnalyse }

/// The scan flow as a value: one state, and the only rules for leaving it. An event that is not
/// legal in the current state is ignored, so a late answer from cancelled work changes nothing.
///
/// Only this type can produce `.result`, and it always goes through the configuration's own
/// rules, so no view can show an analyser's estimate that the strip's resolver has not accepted.
public struct ScanSession<Rules: ScanFlowRules>: Hashable, Sendable {
    public let configuration: Rules
    public private(set) var state: ScanFlowState<Rules.Resolution> = .idle
    /// When the current unbroken run of `ready` frames began. Time comes only from the events:
    /// no timer, no clock.
    private var readySince: TimeInterval?

    public init(configuration: Rules) {
        self.configuration = configuration
    }

    public mutating func handle(_ event: ScanFlowEvent<Rules.Outcome>) {
        switch event {
        case .begin(let access):
            guard canBegin else { break }
            switch access {
            case .authorised: state = .preparingCamera
            case .notDetermined: state = .requestingPermission
            case .denied: state = .permissionDenied
            case .restricted: state = .cameraUnavailable
            }
        case .permissionResolved(let granted):
            if state == .requestingPermission { state = granted ? .preparingCamera : .permissionDenied }
        case .camera(.idle), .camera(.preparing):
            break
        case .camera(.running):
            if state == .preparingCamera || isInterrupted { state = .searching }
        case .camera(.unavailable), .camera(.failed):
            if isUsingCamera || isInterrupted { state = .cameraUnavailable }
        case .camera(.interrupted(let reason)):
            if isUsingCamera { state = .interrupted(reason) }
        case .frame(let assessment, let time):
            guard state.isLiveGuidance else { break }
            handleFrame(assessment, at: time)
        case .captureRequested:
            if state.isLiveGuidance { state = .capturing }
        case .stillCaptured:
            if state == .capturing { state = .analysing }
        case .captureFailed:
            if state == .capturing { state = .result(Rules.captureFailed) }
        case .analysed(let outcome):
            if state == .analysing { state = .result(configuration.resolve(outcome)) }
        case .suspended:
            if isUsingCamera || state == .analysing || isInterrupted { state = .interrupted(.backgrounded) }
        case .resumed:
            if state == .interrupted(.backgrounded) { state = .preparingCamera }
        }
        if !state.isLiveGuidance { readySince = nil }
    }

    /// The stability rule: the strip must stay `ready` for the configuration's window before a
    /// capture is taken. Any other frame, or a timestamp that runs backwards, starts the wait again.
    private mutating func handleFrame(_ assessment: FrameAssessment, at time: TimeInterval) {
        switch assessment {
        case .searching: state = .searching
        case .stripDetected: state = .stripDetected
        case .issue(let issue): state = .qualityIssue(issue)
        case .ready:
            guard let since = readySince, time >= since else {
                readySince = time
                state = .ready
                return
            }
            let held = (time - since) * 1000 >= Double(configuration.stableDetectionMilliseconds)
            state = held ? .capturing : .ready
            return
        }
        readySince = nil
    }

    /// `begin` restarts the flow only from a state with nothing in flight.
    private var canBegin: Bool {
        switch state {
        case .idle, .permissionDenied, .cameraUnavailable, .result: return true
        default: return false
        }
    }

    /// Starting the camera, reading live frames or taking the still.
    private var isUsingCamera: Bool {
        state == .preparingCamera || state.isLiveGuidance || state == .capturing
    }

    private var isInterrupted: Bool {
        if case .interrupted = state { return true }
        return false
    }

    /// `capturing` and `analysing` share one value so the task that takes the still is the task
    /// that analyses it, and is not cancelled between the two.
    public var work: ScanWork? {
        switch state {
        case .requestingPermission: return .requestPermission
        case .preparingCamera: return .startCamera
        case .capturing, .analysing: return .captureAndAnalyse
        default: return nil
        }
    }

    /// Whether the camera should be running. A system interruption ends by itself, so the camera
    /// is kept; a backgrounded scan gives it up and starts again on return.
    public var wantsCamera: Bool {
        switch state {
        case .interrupted(let reason): return reason != .backgrounded
        case .analysing: return true
        default: return isUsingCamera
        }
    }
}

/// The pH flow. Its results always go through `PhScanResolver`.
public typealias PhScanSession = ScanSession<PhStripConfiguration>

extension PhStripConfiguration: ScanFlowRules {
    public func resolve(_ outcome: PhAnalysisOutcome) -> PhScanResolution {
        PhScanResolver.resolve(outcome, configuration: self)
    }

    public static var captureFailed: PhScanResolution { .unreadable([]) }
}

/// Decides which guidance lines VoiceOver speaks, so live guidance does not talk over itself:
/// never the same text twice in a row, and at most one line per `minimumInterval` unless urgent.
public struct ScanAnnouncementThrottle: Sendable {
    public static let minimumInterval: TimeInterval = 2.5

    private var lastText: String?
    private var lastTime: TimeInterval = 0

    public init() {}

    /// True when `text` should be spoken now, in which case it is recorded as the last line said.
    public mutating func shouldAnnounce(_ text: String, at time: TimeInterval, urgent: Bool) -> Bool {
        guard text != lastText else { return false }
        guard urgent || lastText == nil || time - lastTime >= Self.minimumInterval else { return false }
        lastText = text
        lastTime = time
        return true
    }
}
