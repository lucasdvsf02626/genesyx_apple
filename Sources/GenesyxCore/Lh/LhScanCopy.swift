import Foundation

/// Every user-facing string in the ovulation (LH) test flow (British English), kept in Core like
/// `PhScanCopy` so the banned-phrase guard can read all of it. A result reports what one test
/// showed and nothing more: this copy names no condition and never says or implies when
/// ovulation will happen.
public enum LhScanCopy {
    // ── Scan home card ──

    public static let cardTitle = "Ovulation Test Strip"
    public static let cardDescription = "Scan your ovulation (LH) test strip"

    // ── Instructions ──

    public static let instructionsTitle = "Scan your ovulation test"
    public static let instructionSteps: [String] = [
        "Complete the test following the product instructions.",
        "Wait for the development time shown in the instructions leaflet.",
        "Place the strip horizontally on a flat, neutral surface.",
        "Make sure the test line area and the control line area are both visible.",
        "Scan before the maximum reading time in the leaflet, if it gives one.",
    ]

    // ── Buttons and messages shared with the pH scan, so the camera has one wording ──

    public static let openCamera = PhScanCopy.openCamera
    public static let enterManually = PhScanCopy.enterManually
    public static let saveResult = PhScanCopy.saveResult
    public static let scanAgain = PhScanCopy.scanAgain
    public static let tryAgain = PhScanCopy.tryAgain
    public static let resultSaved = PhScanCopy.resultSaved
    public static let saveFailed = PhScanCopy.saveFailed
    public static let cancel = PhScanCopy.cancel
    public static let privacyNote = PhScanCopy.privacyNote

    // ── Camera ──

    public static let cameraTitle = "Scan Ovulation Test"
    public static let analysing = "Reading your test…"
    public static let unrecognisedStrip = "We can't recognise this strip"
    public static let lineAreasNotFound = "Make sure both line areas are visible"

    // ── Result ──

    public static let lowTitle = "Low LH"
    public static let lowBody = "No LH surge detected on this test."
    public static let positiveTitle = "LH surge detected"
    public static let positiveBody = "Your ovulation test appears positive."
    // Not reviewed. Shown only if a strip configuration enables rising.
    public static let risingTitle = "LH rising"
    public static let risingBody = "This test shows more LH than a low result, but it is not positive."
    public static let invalidTitle = "Test invalid"
    public static let invalidBody = "We couldn't detect the control line. Please repeat the test using a new strip."
    public static let unreadableTitle = "We couldn't read this test."
    public static let unreadableBody = "Try scanning again in good, even lighting."
    public static let scanNewTest = "Scan New Test"
    /// Shown with every result, so a test result is not read as one of the app's predicted dates.
    public static let resultNote = "This is the result of one test. It does not tell you when ovulation will happen, and it does not change the predicted dates shown elsewhere in Genesyx."
    public static let disclaimer = "This is for your own record and isn't medical advice. If you have questions about your results, please speak to a GP, nurse, or pharmacist."
    public static let done = "Done"

    // ── Manual entry ──

    public static let manualTitle = "Enter your result"
    public static let manualPrompt = "Choose the result shown on your test, following the product leaflet."
    public static let manualLow = "Negative / Low"
    public static let manualPositive = "Positive"
    public static let manualInvalid = "Invalid"
    public static let manualDateLabel = "Date and time of test"

    // ── Recent results ──

    public static let historyTitle = "Recent results"
    public static let historyEmpty = "No ovulation test results yet."
    public static let sourceScanned = "Scanned"
    public static let sourceManual = "Entered manually"
    public static let deleteResult = "Delete this result"
    public static let deleteConfirmTitle = "Delete this result?"

    public static func title(for classification: LhClassification) -> String {
        switch classification {
        case .low: return lowTitle
        case .rising: return risingTitle
        case .positive: return positiveTitle
        case .invalid: return invalidTitle
        case .unreadable: return unreadableTitle
        }
    }

    public static func body(for classification: LhClassification) -> String {
        switch classification {
        case .low: return lowBody
        case .rising: return risingBody
        case .positive: return positiveBody
        case .invalid: return invalidBody
        case .unreadable: return unreadableBody
        }
    }

    public static func cycleDayLabel(_ day: Int) -> String {
        "Cycle day \(day)"
    }

    /// One short instruction per quality problem. Only the two that would name pH pads have
    /// their own wording; the rest is the pH scan's, so one camera speaks one way.
    public static func message(for issue: ScanQualityIssue) -> String {
        switch issue {
        case .unrecognisedStrip: return unrecognisedStrip
        case .reagentAreaNotFound: return lineAreasNotFound
        default: return PhScanCopy.message(for: issue)
        }
    }

    /// The line under the camera frame (and its VoiceOver announcement) for each state of the LH flow.
    public static func guidance(for state: LhScannerState) -> String {
        switch state {
        case .idle, .preparingCamera: return PhScanCopy.preparingCamera
        case .requestingPermission, .permissionDenied: return PhScanCopy.permissionNeeded
        case .cameraUnavailable: return PhScanCopy.cameraUnavailable
        case .searching: return PhScanCopy.searching
        case .stripDetected: return PhScanCopy.stripDetected
        case .qualityIssue(let issue): return message(for: issue)
        case .ready, .capturing: return PhScanCopy.holdSteady
        case .analysing: return analysing
        case .result(let resolution): return title(for: resolution.classification)
        case .interrupted: return PhScanCopy.paused
        }
    }

    /// Every user-facing string in this file, so the banned-phrase guard scans all of them.
    /// A new constant belongs in this list in the same change that adds it.
    public static let allSurfaces: [String] = [
        cardTitle, cardDescription, instructionsTitle,
        openCamera, enterManually, saveResult, scanAgain, tryAgain, resultSaved, saveFailed,
        cancel, privacyNote,
        cameraTitle, analysing, unrecognisedStrip, lineAreasNotFound,
        PhScanCopy.preparingCamera, PhScanCopy.permissionNeeded, PhScanCopy.cameraUnavailable,
        PhScanCopy.searching, PhScanCopy.stripDetected, PhScanCopy.holdSteady, PhScanCopy.paused,
        lowTitle, lowBody, positiveTitle, positiveBody, risingTitle, risingBody,
        invalidTitle, invalidBody, unreadableTitle, unreadableBody,
        scanNewTest, resultNote, disclaimer, done,
        manualTitle, manualPrompt, manualLow, manualPositive, manualInvalid, manualDateLabel,
        historyTitle, historyEmpty, sourceScanned, sourceManual, deleteResult, deleteConfirmTitle,
        cycleDayLabel(1),
    ] + instructionSteps + ScanQualityIssue.allCases.map(message(for:))
}
