import XCTest
@testable import GenesyxCore

/// Guards the LH flow's copy: nothing diagnostic, nothing that names a condition, nothing that
/// says or implies when ovulation will happen, house style.
final class LhScanCopyTests: XCTestCase {

    /// True when `term` appears in `text` as a whole word, so "sti" does not match "testing".
    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    // ── Banned-phrase guard ──

    /// The scan flow's clinical list plus everything that would turn one test result into a
    /// statement about ovulation, timing or conceiving. Stems match anywhere in a word; the short
    /// words match as whole words only, which is where they would actually appear.
    func testLhCopyHasNoBannedClinicalOrPredictiveTerms() {
        let bannedAnywhere = ["thrush", "infection", "candida", "vaginosis", "diagnos", "treat", "cure", "prescrib",
                              "guaranteed", "infertil",
                              "you are ovulating", "you ovulated", "you will ovulate", "ovulation confirmed",
                              "confirms ovulation", "confirmed", "peak fertility", "most fertile", "best time",
                              "conceive", "conception", "pregnan", "intercourse", "have sex", "baby", "gender",
                              "shettles", "sex selection"]
        let bannedWords = ["bv", "sti", "stis", "boy", "girl"]

        XCTAssertGreaterThanOrEqual(LhScanCopy.allSurfaces.count, 55, "the registry must not shrink")
        for s in LhScanCopy.allSurfaces {
            let lower = s.lowercased()
            for term in bannedAnywhere {
                XCTAssertFalse(lower.contains(term), "Banned term \"\(term)\" in LH copy: \(s)")
            }
            for term in bannedWords {
                XCTAssertFalse(containsWord(term, in: s), "Banned term \"\(term)\" in LH copy: \(s)")
            }
        }
    }

    /// The matcher has to be able to fail, or the test above proves nothing.
    func testTheWholeWordMatcherCatchesWhatItShould() {
        XCTAssertTrue(containsWord("sti", in: "This may be an STI."))
        XCTAssertTrue(containsWord("boy", in: "More likely a boy."))
        XCTAssertTrue(containsWord("girl", in: "Girl or not"))
        XCTAssertFalse(containsWord("sti", in: "Reading your test, still testing"))
        XCTAssertFalse(containsWord("boy", in: "Keep it buoyant"))
    }

    func testLhCopyFollowsHouseStyle() {
        for s in LhScanCopy.allSurfaces {
            XCTAssertFalse(s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty string registered")
            XCTAssertFalse(s.contains("\u{2014}"), "em dash in LH copy: \(s)")
            XCTAssertFalse(s.lowercased().contains("analyz"), "US spelling in LH copy: \(s)")
        }
    }

    // ── Registry ──

    func testEveryClassificationHasATitleAndABodyAndBothAreGuarded() {
        for classification in LhClassification.allCases {
            let title = LhScanCopy.title(for: classification)
            let body = LhScanCopy.body(for: classification)
            XCTAssertFalse(title.isEmpty, "no title for \(classification)")
            XCTAssertFalse(body.isEmpty, "no body for \(classification)")
            XCTAssertTrue(LhScanCopy.allSurfaces.contains(title), "title for \(classification) is not in allSurfaces")
            XCTAssertTrue(LhScanCopy.allSurfaces.contains(body), "body for \(classification) is not in allSurfaces")
        }
    }

    func testEveryQualityIssueHasAMessageAndAllOfThemAreGuarded() {
        for issue in ScanQualityIssue.allCases {
            let message = LhScanCopy.message(for: issue)
            XCTAssertFalse(message.isEmpty, "no message for \(issue)")
            XCTAssertTrue(LhScanCopy.allSurfaces.contains(message), "message for \(issue) is not in allSurfaces")
        }
    }

    /// Only the two messages that would mention pH pads differ; the camera otherwise speaks one way.
    func testQualityMessagesAreThePhScansExceptWhereTheyWouldNamePads() {
        for issue in ScanQualityIssue.allCases where issue != .unrecognisedStrip && issue != .reagentAreaNotFound {
            XCTAssertEqual(LhScanCopy.message(for: issue), PhScanCopy.message(for: issue), "\(issue)")
        }
        XCTAssertEqual(LhScanCopy.message(for: .unrecognisedStrip), LhScanCopy.unrecognisedStrip)
        XCTAssertEqual(LhScanCopy.message(for: .reagentAreaNotFound), LhScanCopy.lineAreasNotFound)
        XCTAssertFalse(LhScanCopy.message(for: .reagentAreaNotFound).lowercased().contains("pad"))
    }

    func testInstructionStepsAreAllRegistered() {
        XCTAssertEqual(LhScanCopy.instructionSteps.count, 5)
        for step in LhScanCopy.instructionSteps {
            XCTAssertTrue(LhScanCopy.allSurfaces.contains(step))
        }
    }

    func testSharedCameraWordingIsThePhScansAndIsRegistered() {
        XCTAssertEqual(LhScanCopy.openCamera, PhScanCopy.openCamera)
        XCTAssertEqual(LhScanCopy.enterManually, PhScanCopy.enterManually)
        XCTAssertEqual(LhScanCopy.saveResult, PhScanCopy.saveResult)
        XCTAssertEqual(LhScanCopy.scanAgain, PhScanCopy.scanAgain)
        XCTAssertEqual(LhScanCopy.tryAgain, PhScanCopy.tryAgain)
        XCTAssertEqual(LhScanCopy.resultSaved, PhScanCopy.resultSaved)
        XCTAssertEqual(LhScanCopy.saveFailed, PhScanCopy.saveFailed)
        for shared in [LhScanCopy.openCamera, LhScanCopy.enterManually, LhScanCopy.saveResult, LhScanCopy.scanAgain,
                       LhScanCopy.tryAgain, LhScanCopy.resultSaved, LhScanCopy.saveFailed] {
            XCTAssertTrue(LhScanCopy.allSurfaces.contains(shared), shared)
        }
    }

    func testTheCycleDayLabelIsRegistered() {
        XCTAssertEqual(LhScanCopy.cycleDayLabel(12), "Cycle day 12")
        XCTAssertTrue(LhScanCopy.allSurfaces.contains(LhScanCopy.cycleDayLabel(1)))
    }

    // ── Guidance ──

    /// `LhScannerState` carries associated values, so it cannot be `CaseIterable`: this list is
    /// every plain case, every quality issue, both kinds of interruption and every kind of result.
    func testEveryStateHasGuidanceAndAllOfItIsGuarded() {
        let measurement = LhScanMeasurement(testSignal: 0.06, controlSignal: 0.6, testControlRatio: 0.1,
                                            confidence: 0.95, scannerVersion: "s", configurationID: "t",
                                            configurationVersion: "1")
        let states: [LhScannerState] = [
            .idle, .requestingPermission, .permissionDenied, .cameraUnavailable, .preparingCamera,
            .searching, .stripDetected, .ready, .capturing, .analysing,
            .interrupted(.other), .interrupted(.backgrounded),
            .result(.reading(.low, measurement)), .result(.reading(.positive, measurement)),
            .result(.invalid), .result(.unreadable([])),
        ] + ScanQualityIssue.allCases.map(LhScannerState.qualityIssue)

        for state in states {
            let guidance = LhScanCopy.guidance(for: state)
            XCTAssertFalse(guidance.isEmpty, "no guidance for \(state)")
            XCTAssertTrue(LhScanCopy.allSurfaces.contains(guidance), "guidance for \(state) is not in allSurfaces")
        }
    }

    func testGuidanceUsesLhWordingWhereLhHasItsOwn() {
        XCTAssertEqual(LhScanCopy.guidance(for: .analysing), "Reading your test…")
        XCTAssertEqual(LhScanCopy.guidance(for: .qualityIssue(.unrecognisedStrip)), "We can't recognise this strip")
        XCTAssertEqual(LhScanCopy.guidance(for: .qualityIssue(.reagentAreaNotFound)),
                       "Make sure both line areas are visible")
        XCTAssertEqual(LhScanCopy.guidance(for: .result(.invalid)), "Test invalid")
        XCTAssertEqual(LhScanCopy.guidance(for: .result(.unreadable([.glare]))), "We couldn't read this test.")
        XCTAssertEqual(LhScanCopy.guidance(for: .searching), PhScanCopy.guidance(for: .searching))
        XCTAssertEqual(LhScanCopy.guidance(for: .interrupted(.other)), PhScanCopy.paused)
    }

    // ── Verbatim copy ──

    func testVerbatimResultCopy() {
        XCTAssertEqual(LhScanCopy.title(for: .low), "Low LH")
        XCTAssertEqual(LhScanCopy.body(for: .low), "No LH surge detected on this test.")
        XCTAssertEqual(LhScanCopy.title(for: .positive), "LH surge detected")
        XCTAssertEqual(LhScanCopy.body(for: .positive), "Your ovulation test appears positive.")
        XCTAssertEqual(LhScanCopy.title(for: .rising), "LH rising")
        XCTAssertEqual(LhScanCopy.body(for: .rising), "This test shows more LH than a low result, but it is not positive.")
        XCTAssertEqual(LhScanCopy.title(for: .invalid), "Test invalid")
        XCTAssertEqual(LhScanCopy.body(for: .invalid),
                       "We couldn't detect the control line. Please repeat the test using a new strip.")
        XCTAssertEqual(LhScanCopy.title(for: .unreadable), "We couldn't read this test.")
        XCTAssertEqual(LhScanCopy.body(for: .unreadable), "Try scanning again in good, even lighting.")
        XCTAssertEqual(LhScanCopy.resultNote,
                       "This is the result of one test. It does not tell you when ovulation will happen, and it does not change the predicted dates shown elsewhere in Genesyx.")
    }

    func testVerbatimFlowCopy() {
        XCTAssertEqual(LhScanCopy.manualLow, "Negative / Low")
        XCTAssertEqual(LhScanCopy.manualPositive, "Positive")
        XCTAssertEqual(LhScanCopy.manualInvalid, "Invalid")
        XCTAssertEqual(LhScanCopy.analysing, "Reading your test…")
        XCTAssertEqual(LhScanCopy.unrecognisedStrip, "We can't recognise this strip")
        XCTAssertEqual(LhScanCopy.lineAreasNotFound, "Make sure both line areas are visible")
        XCTAssertEqual(LhScanCopy.cardTitle, "Ovulation Test Strip")
        XCTAssertEqual(LhScanCopy.cardDescription, "Scan your ovulation (LH) test strip")
        XCTAssertEqual(LhScanCopy.instructionsTitle, "Scan your ovulation test")
        XCTAssertEqual(LhScanCopy.cameraTitle, "Scan Ovulation Test")
        XCTAssertEqual(LhScanCopy.scanNewTest, "Scan New Test")
        XCTAssertEqual(LhScanCopy.disclaimer,
                       "This is for your own record and isn't medical advice. If you have questions about your results, please speak to a GP, nurse, or pharmacist.")
        XCTAssertEqual(LhScanCopy.instructionSteps[3],
                       "Make sure the test line area and the control line area are both visible.")
        XCTAssertEqual(LhScanCopy.instructionSteps[4],
                       "Scan before the maximum reading time in the leaflet, if it gives one.")
    }

    /// The result sits in an app that also shows predicted dates. The note keeps the two apart.
    func testTheResultNoteSaysATestDoesNotPredictOvulation() {
        XCTAssertTrue(LhScanCopy.resultNote.contains("does not tell you when ovulation will happen"))
    }
}
