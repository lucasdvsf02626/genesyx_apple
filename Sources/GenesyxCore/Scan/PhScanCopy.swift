import Foundation

/// Every user-facing string in the Scan Test flow (British English), kept in Core like `PhCopy`
/// so the banned-phrase guard can read all of it. A scan reports a number and nothing more: this
/// copy names no condition and tells her to do nothing beyond scanning again or asking someone.
public enum PhScanCopy {
    // ── Tab and scan home ──

    public static let tabTitle = "Scan"
    public static let homeTitle = "Scan Test"
    public static let homeSubtitle = "Choose the test you want to scan."
    public static let phCardTitle = "pH Test Strip"
    public static let phCardDescription = "Scan your vaginal pH test strip"

    // ── Instructions ──

    public static let instructionsTitle = "Scan your pH test"
    public static let privacyNote = "Your camera image is read on your phone. It is never stored or uploaded."
    public static let instructionSteps: [String] = [
        "Complete the test following the product instructions.",
        "Wait for the development time shown in the instructions leaflet.",
        "Place the strip on a flat, neutral surface.",
        "Use even lighting and avoid shadows and reflections.",
        "Keep the whole strip inside the frame.",
    ]

    // ── Buttons ──

    public static let openCamera = "Open Camera"
    public static let enterManually = "Enter result manually"
    public static let saveResult = "Save Result"
    public static let scanAgain = "Scan Again"
    public static let tryAgain = "Try Again"
    public static let openSettings = "Open Settings"
    public static let cancel = "Cancel"
    public static let viewHistory = "View pH history"

    // ── Camera ──

    public static let cameraTitle = "Scan pH Test"
    public static let searching = "Position the whole strip inside the frame"
    public static let stripDetected = "Strip detected"
    public static let holdSteady = "Hold steady"
    public static let preparingCamera = "Starting the camera…"
    public static let analysing = "Analysing test…"
    public static let permissionNeeded = "Camera access is needed to scan your test."
    public static let permissionDeniedBody = "Turn on camera access for Genesyx in Settings, or enter your result manually."
    public static let paused = "Scanning is paused"
    public static let cameraUnavailable = "The camera isn't available on this device. You can enter your result manually."

    /// The `NSCameraUsageDescription` sentence. Held here so the text iOS shows in the permission
    /// prompt goes through the same guard as the rest of the flow; the Info.plist must match it.
    public static let cameraUsageDescription = "Genesyx uses your camera to scan supported test strips and read your result."

    // ── Result ──

    public static let resultTitle = "Your pH result"
    public static let resultRecorded = "Result recorded"
    public static let resultSaved = "Result saved"
    public static let unreadableTitle = "We couldn't read this test."
    public static let unreadableBody = "Try scanning again in good, even lighting."
    public static let saveFailed = "We couldn't save your result. Please try again."

    /// Shown with a scanned result above the usual range. The tracker's own signpost, not a
    /// second wording of it: a scan must not say more about a number than typing it in does.
    public static let elevatedNote = PhCopy.elevatedSignpost
    /// Shown under every scanned result, as it is under every logged one.
    public static let disclaimer = PhCopy.disclaimer

    /// One short instruction per quality problem: what to change, never what went wrong with her.
    public static func message(for issue: ScanQualityIssue) -> String {
        switch issue {
        case .noStrip: return "Place your strip inside the frame"
        case .partialStrip: return "Make sure the entire strip is visible"
        case .tooFar: return "Move closer"
        case .tooClose: return "Move your phone back"
        case .badAngle: return "Hold your phone directly above the strip"
        case .tooDark: return "More light needed"
        case .overexposed, .glare: return "Reduce glare"
        case .blurred, .moving: return holdSteady
        case .multipleStrips: return "Scan one strip at a time"
        case .unrecognisedStrip: return "We don't recognise this strip"
        case .reagentAreaNotFound: return "Make sure the coloured pads are visible"
        }
    }

    /// The line under the camera frame (and its VoiceOver announcement) for each state.
    public static func guidance(for state: ScannerState) -> String {
        switch state {
        case .idle, .preparingCamera: return preparingCamera
        case .requestingPermission, .permissionDenied: return permissionNeeded
        case .cameraUnavailable: return cameraUnavailable
        case .searching: return searching
        case .stripDetected: return stripDetected
        case .qualityIssue(let issue): return message(for: issue)
        case .ready, .capturing: return holdSteady
        case .analysing: return analysing
        case .result(.reading): return resultTitle
        case .result(.unreadable): return unreadableTitle
        case .interrupted: return paused
        }
    }

    /// Every user-facing string in this file, so the banned-phrase guard scans all of them.
    /// A new constant belongs in this list in the same change that adds it.
    public static let allSurfaces: [String] = [
        tabTitle, homeTitle, homeSubtitle, phCardTitle, phCardDescription,
        instructionsTitle, privacyNote,
        openCamera, enterManually, saveResult, scanAgain, tryAgain, openSettings, cancel, viewHistory,
        cameraTitle, searching, stripDetected, holdSteady, preparingCamera, analysing,
        permissionNeeded, permissionDeniedBody, paused, cameraUnavailable, cameraUsageDescription,
        resultTitle, resultRecorded, resultSaved, unreadableTitle, unreadableBody, saveFailed,
        elevatedNote, disclaimer,
    ] + instructionSteps + ScanQualityIssue.allCases.map(message(for:))
}
