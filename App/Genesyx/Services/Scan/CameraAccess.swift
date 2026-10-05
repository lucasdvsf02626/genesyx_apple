import AVFoundation
import GenesyxCore

/// Why `captureStill()` produced no image.
enum CameraCaptureError: Error {
    case unavailable
    case notRunning
    case captureFailed
}

extension CameraSessionManager {
    /// Camera permission, flattened from `AVAuthorizationStatus`.
    var access: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorised
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notDetermined
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
