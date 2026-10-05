import XCTest
@testable import GenesyxCore

/// Guards the scan flow's copy: nothing diagnostic, nothing that names a condition, house style.
final class PhScanCopyTests: XCTestCase {

    /// Every state the flow can be in. `ScannerState` carries associated values, so it cannot be
    /// `CaseIterable`; the quality issues at least come from `allCases`.
    private var everyState: [ScannerState] {
        [.idle, .requestingPermission, .permissionDenied, .cameraUnavailable, .preparingCamera,
         .searching, .stripDetected, .ready, .capturing, .analysing,
         .interrupted(.other), .interrupted(.backgrounded),
         .result(.unreadable([])), .result(.unreadable([.glare])),
         .result(.reading(value: 4.2, metadata: PhScanMetadata(scannerVersion: "0.1.0", configurationID: "c",
                                                               configurationVersion: "v", confidence: 0.9)))]
            + ScanQualityIssue.allCases.map(ScannerState.qualityIssue)
    }

    /// True when `term` appears in `text` as a whole word, so "sti" does not match "testing".
    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    // ── Banned-phrase guard ──

    /// The pH tracker's own banned list plus the words that would turn a number into advice.
    /// Stems match anywhere in a word; the two short abbreviations match as whole words only,
    /// which is where they would actually appear and avoids tripping on "testing".
    func testScanCopyHasNoBannedClinicalOrDietTerms() {
        let bannedAnywhere = ["thrush", "infection", "candida", "vaginosis", "leafy greens", "whole grains",
                              "mineral water", "diagnos", "treat", "cure", "prescrib", "guaranteed", "infertil"]
        let bannedWords = ["bv", "sti", "stis"]

        XCTAssertGreaterThanOrEqual(PhScanCopy.allSurfaces.count, 52, "the registry must not shrink")
        for s in PhScanCopy.allSurfaces {
            let lower = s.lowercased()
            for term in bannedAnywhere {
                XCTAssertFalse(lower.contains(term), "Banned term \"\(term)\" in scan copy: \(s)")
            }
            for term in bannedWords {
                XCTAssertFalse(containsWord(term, in: s), "Banned term \"\(term)\" in scan copy: \(s)")
            }
        }
    }

    /// The matcher has to be able to fail, or the test above proves nothing.
    func testTheWholeWordMatcherCatchesWhatItShould() {
        XCTAssertTrue(containsWord("sti", in: "This may be an STI."))
        XCTAssertTrue(containsWord("bv", in: "a sign of BV"))
        XCTAssertFalse(containsWord("sti", in: "Analysing test, still testing"))
    }

    func testScanCopyFollowsHouseStyle() {
        for s in PhScanCopy.allSurfaces {
            XCTAssertFalse(s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty string registered")
            XCTAssertFalse(s.contains("\u{2014}"), "em dash in scan copy: \(s)")
            XCTAssertFalse(s.lowercased().contains("analyz"), "US spelling in scan copy: \(s)")
        }
    }

    // ── Guidance ──

    func testEveryStateHasGuidanceAndAllOfItIsGuarded() {
        for state in everyState {
            let line = PhScanCopy.guidance(for: state)
            XCTAssertFalse(line.isEmpty, "no guidance for \(state)")
            XCTAssertTrue(PhScanCopy.allSurfaces.contains(line), "guidance for \(state) is not in allSurfaces: \(line)")
        }
        for issue in ScanQualityIssue.allCases {
            XCTAssertFalse(PhScanCopy.message(for: issue).isEmpty, "no message for \(issue)")
            XCTAssertEqual(PhScanCopy.guidance(for: .qualityIssue(issue)), PhScanCopy.message(for: issue))
        }
    }

    func testInstructionStepsAreAllRegistered() {
        XCTAssertEqual(PhScanCopy.instructionSteps.count, 5)
        for step in PhScanCopy.instructionSteps {
            XCTAssertTrue(PhScanCopy.allSurfaces.contains(step))
        }
    }

    // ── Verbatim copy ──

    func testVerbatimCopy() {
        XCTAssertEqual(PhScanCopy.tabTitle, "Scan")
        XCTAssertEqual(PhScanCopy.homeTitle, "Scan Test")
        XCTAssertEqual(PhScanCopy.homeSubtitle, "Choose the test you want to scan.")
        XCTAssertEqual(PhScanCopy.phCardTitle, "pH Test Strip")
        XCTAssertEqual(PhScanCopy.phCardDescription, "Scan your vaginal pH test strip")
        XCTAssertEqual(PhScanCopy.instructionsTitle, "Scan your pH test")
        XCTAssertEqual(PhScanCopy.cameraTitle, "Scan pH Test")
        XCTAssertEqual(PhScanCopy.permissionNeeded, "Camera access is needed to scan your test.")
        XCTAssertEqual(PhScanCopy.cameraUsageDescription,
                       "Genesyx uses your camera to scan supported test strips and read your result.")
        XCTAssertEqual(PhScanCopy.unreadableTitle, "We couldn't read this test.")
        XCTAssertEqual(PhScanCopy.unreadableBody, "Try scanning again in good, even lighting.")
        XCTAssertEqual(PhScanCopy.guidance(for: .searching), "Position the whole strip inside the frame")
        XCTAssertEqual(PhScanCopy.guidance(for: .stripDetected), "Strip detected")
        XCTAssertEqual(PhScanCopy.guidance(for: .ready), "Hold steady")
        XCTAssertEqual(PhScanCopy.guidance(for: .analysing), "Analysing test…")
        XCTAssertEqual(PhScanCopy.message(for: .tooFar), "Move closer")
        XCTAssertEqual(PhScanCopy.message(for: .tooClose), "Move your phone back")
        XCTAssertEqual(PhScanCopy.message(for: .badAngle), "Hold your phone directly above the strip")
        XCTAssertEqual(PhScanCopy.message(for: .tooDark), "More light needed")
        XCTAssertEqual(PhScanCopy.message(for: .overexposed), "Reduce glare")
        XCTAssertEqual(PhScanCopy.message(for: .glare), "Reduce glare")
        XCTAssertEqual(PhScanCopy.message(for: .blurred), "Hold steady")
        XCTAssertEqual(PhScanCopy.message(for: .moving), "Hold steady")
        XCTAssertEqual(PhScanCopy.message(for: .partialStrip), "Make sure the entire strip is visible")
        XCTAssertEqual(PhScanCopy.cancel, "Cancel")
        XCTAssertEqual(PhScanCopy.viewHistory, "View pH history")
        XCTAssertEqual(PhScanCopy.privacyNote,
                       "Your camera image is read on your phone. It is never stored or uploaded.")
        XCTAssertEqual(PhScanCopy.permissionDeniedBody,
                       "Turn on camera access for Genesyx in Settings, or enter your result manually.")
        XCTAssertEqual(PhScanCopy.paused, "Scanning is paused")
        XCTAssertEqual(PhScanCopy.guidance(for: .interrupted(.other)), "Scanning is paused")
    }

    /// Nothing has been saved when the result appears, so the line must not say it was recorded.
    func testAReadingIsAnnouncedWithTheResultTitle() {
        let metadata = PhScanMetadata(scannerVersion: "0.1.0", configurationID: "c", configurationVersion: "v",
                                      confidence: 0.9)
        XCTAssertEqual(PhScanCopy.guidance(for: .result(.reading(value: 4.2, metadata: metadata))),
                       PhScanCopy.resultTitle)
    }

    /// A scan says no more about a number than typing it in does: same sentences, not new ones.
    func testResultGuidanceReusesTheTrackersOwnWording() {
        XCTAssertEqual(PhScanCopy.elevatedNote, PhCopy.elevatedSignpost)
        XCTAssertEqual(PhScanCopy.disclaimer, PhCopy.disclaimer)
    }
}
