import Foundation

/// What one live camera frame shows, before anything is captured.
public enum FrameAssessment: Hashable, Sendable {
    case searching, stripDetected, issue(ScanQualityIssue), ready
}

/// Camera permission as the flow sees it.
public enum CameraAccess: String, Hashable, Sendable { case notDetermined, authorised, denied, restricted }

/// Why the camera stopped delivering frames without being asked to.
public enum ScanInterruption: String, Hashable, Sendable {
    case backgrounded, inUseByAnotherApp, multitasking, systemPressure, other
}

/// What a frame source reports about itself.
public enum ScanCameraStatus: Hashable, Sendable {
    case idle, preparing, running, interrupted(ScanInterruption), unavailable, failed
}

/// Where the scan flow is. UI-free so the guidance copy for every state can be scanned by the
/// banned-phrase guard without a view in sight.
///
/// Generic over what a finished scan resolves to, so every strip type shares one flow.
public enum ScanFlowState<Resolution: Hashable & Sendable>: Hashable, Sendable {
    case idle, requestingPermission, permissionDenied, cameraUnavailable, preparingCamera
    case searching, stripDetected, qualityIssue(ScanQualityIssue), ready, capturing, analysing
    case result(Resolution)
    case interrupted(ScanInterruption)
}

/// The pH flow's state. Kept so every existing pH name still compiles.
public typealias ScannerState = ScanFlowState<PhScanResolution>

public extension ScanFlowState {
    /// True while live frames drive the guidance line (searching, stripDetected, qualityIssue, ready).
    var isLiveGuidance: Bool {
        switch self {
        case .searching, .stripDetected, .qualityIssue, .ready: return true
        default: return false
        }
    }
}
