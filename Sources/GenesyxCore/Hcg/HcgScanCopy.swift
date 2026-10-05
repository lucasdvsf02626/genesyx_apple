import Foundation

/// Every user-facing string in the pregnancy test flow (British English), kept in Core like
/// `PhScanCopy` so the banned-phrase guard can read all of it. A result reports what one test
/// strip showed and nothing more: this copy describes the test, never the person.
///
/// Every string is PROPOSED COPY awaiting owner and legal review.
public enum HcgScanCopy {
    // ── Scan home card ──

    public static let cardTitle = "Pregnancy Test"
    public static let cardDescription = "Scan a test strip or enter its result"
    public static let screenTitle = cardTitle

    // ── Instructions ──

    public static let instructionSteps: [String] = [
        "Complete the test following the instructions that came with it.",
        "Wait for the time the instructions give before reading the result.",
        "Place the strip horizontally on a flat, neutral surface.",
        "Make sure the test line area and the control line area are both visible.",
        "Read or scan the test within the time the instructions allow. A test read too early or too late may not be reliable.",
    ]
    public static let aboutNote = "Genesyx records what your test strip shows. It does not tell you what a result means. The instructions that came with your test explain that."
    public static let privacyNote = PhScanCopy.privacyNote
    public static let storageNote = "Results are saved on this phone only, not to your Genesyx account. They are removed when you sign out and will not appear on another phone."

    // ── Buttons and messages shared with the pH scan, so the camera has one wording ──

    public static let openCamera = PhScanCopy.openCamera
    public static let enterManually = PhScanCopy.enterManually
    public static let saveResult = PhScanCopy.saveResult
    public static let scanAgain = PhScanCopy.scanAgain
    public static let tryAgain = PhScanCopy.tryAgain
    public static let resultSaved = PhScanCopy.resultSaved
    public static let saveFailed = PhScanCopy.saveFailed
    public static let cancel = PhScanCopy.cancel

    // ── Camera ──

    public static let cameraTitle = "Scan Pregnancy Test"
    public static let analysing = "Reading your test…"
    public static let unrecognisedStrip = "We can't recognise this strip"
    public static let lineAreasNotFound = "Make sure both line areas are visible"

    // ── Result ──

    public static let detectedTitle = "Test line detected"
    public static let detectedBody = "A line was detected in the test line area of this strip."
    public static let notDetectedTitle = "No test line detected"
    public static let notDetectedBody = "No line was detected in the test line area of this strip."
    /// One string for both outcomes, so the screen says the same thing whichever the strip shows.
    public static let resultNote = "The instructions that came with your test explain what this means. A GP, midwife, pharmacist or sexual health clinic can confirm a result."
    public static let disclaimer = "Genesyx records what the test strip shows. This isn't medical advice."
    public static let invalidTitle = "Test invalid"
    public static let invalidBody = "We couldn't detect the control line, so this test can't be read. Please repeat the test with a new strip, following its instructions."
    public static let unreadableTitle = "We couldn't read this test."
    public static let unreadableBody = "Try scanning again in good, even lighting, or enter the result yourself."
    /// Shown when the test signal fell inside the configuration's band.
    public static let indeterminateMessage = "This scan wasn't clear enough to record a result. Please repeat the test as its instructions describe. A GP, midwife, pharmacist or sexual health clinic can also help."
    public static let scanNewTest = "Scan New Test"
    public static let done = "Done"

    // ── Manual entry ──

    public static let manualTitle = "Enter your result"
    public static let manualPrompt = "Choose what your test strip shows, following its instructions."
    public static let manualDetected = detectedTitle
    public static let manualNotDetected = notDetectedTitle
    public static let manualInvalid = "Invalid"
    public static let manualDateLabel = "Date and time of test"

    // ── Saved results ──

    public static let historyTitle = "Saved results"
    public static let showHistory = "Show saved results"
    public static let hideHistory = "Hide saved results"
    public static let historyEmpty = "No results saved yet."
    public static let sourceScanned = "Scanned"
    public static let sourceManual = "Entered manually"
    public static let deleteResult = "Delete this result"
    public static let deleteConfirmTitle = "Delete this result?"
    public static let deleteAll = "Delete all pregnancy test results"
    public static let deleteAllConfirmTitle = "Delete all pregnancy test results?"
    public static let deleteAllConfirmMessage = "This removes every saved result from this phone. It can't be undone."
    public static let deleteAllConfirmButton = "Delete all"

    public static func title(for classification: HcgClassification) -> String {
        switch classification {
        case .testLineDetected: return detectedTitle
        case .noTestLineDetected: return notDetectedTitle
        case .invalid: return invalidTitle
        }
    }

    public static func body(for classification: HcgClassification) -> String {
        switch classification {
        case .testLineDetected: return detectedBody
        case .noTestLineDetected: return notDetectedBody
        case .invalid: return invalidBody
        }
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

    /// The line under the unreadable title: the first quality issue's instruction, or the
    /// indeterminate message. Nil when there is no reason the screen can name.
    public static func unreadableMessage(for reason: HcgUnreadableReason) -> String? {
        switch reason {
        case .indeterminateTestLine: return indeterminateMessage
        case .quality(let issues): return issues.first.map(message(for:))
        }
    }

    /// The line under the camera frame (and its VoiceOver announcement) for each state of the flow.
    public static func guidance(for state: HcgScannerState) -> String {
        switch state {
        case .idle, .preparingCamera: return PhScanCopy.preparingCamera
        case .requestingPermission, .permissionDenied: return PhScanCopy.permissionNeeded
        case .cameraUnavailable: return PhScanCopy.cameraUnavailable
        case .searching: return PhScanCopy.searching
        case .stripDetected: return PhScanCopy.stripDetected
        case .qualityIssue(let issue): return message(for: issue)
        case .ready, .capturing: return PhScanCopy.holdSteady
        case .analysing: return analysing
        case .result(.reading(let classification, _)): return title(for: classification)
        case .result(.invalid): return invalidTitle
        case .result(.unreadable): return unreadableTitle
        case .interrupted: return PhScanCopy.paused
        }
    }

    /// The only strings allowed to carry the product name. The guard test pins these four as
    /// literals: a fifth is a compliance decision, not a code change.
    public static let approvedProductNameSurfaces: [String] = [
        cardTitle, cameraTitle, deleteAll, deleteAllConfirmTitle,
    ]

    /// Every user-facing string in this file, so the banned-phrase guard scans all of them.
    /// A new constant belongs in this list in the same change that adds it.
    public static let allSurfaces: [String] = [
        cardTitle, cardDescription, screenTitle,
        aboutNote, privacyNote, storageNote,
        openCamera, enterManually, saveResult, scanAgain, tryAgain, resultSaved, saveFailed, cancel,
        cameraTitle, analysing, unrecognisedStrip, lineAreasNotFound,
        PhScanCopy.preparingCamera, PhScanCopy.permissionNeeded, PhScanCopy.cameraUnavailable,
        PhScanCopy.searching, PhScanCopy.stripDetected, PhScanCopy.holdSteady, PhScanCopy.paused,
        PhScanCopy.permissionDeniedBody, PhScanCopy.openSettings,
        detectedTitle, detectedBody, notDetectedTitle, notDetectedBody, resultNote, disclaimer,
        invalidTitle, invalidBody, unreadableTitle, unreadableBody, indeterminateMessage,
        scanNewTest, done,
        manualTitle, manualPrompt, manualDetected, manualNotDetected, manualInvalid, manualDateLabel,
        historyTitle, showHistory, hideHistory, historyEmpty, sourceScanned, sourceManual,
        deleteResult, deleteConfirmTitle,
        deleteAll, deleteAllConfirmTitle, deleteAllConfirmMessage, deleteAllConfirmButton,
    ] + instructionSteps + ScanQualityIssue.allCases.map(message(for:))
}
