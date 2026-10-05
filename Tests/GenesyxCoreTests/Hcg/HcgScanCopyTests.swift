import XCTest
@testable import GenesyxCore

/// Guards the pregnancy test flow's copy: it describes the test and never the person, names no
/// condition, celebrates nothing, consoles nothing, and carries the product name in four approved
/// strings only. Widening any list here is the owner's compliance decision, not a code change.
final class HcgScanCopyTests: XCTestCase {

    // ── The guard ──

    /// Stems that match anywhere in a word: the scan flow's clinical and sex-selection list, plus
    /// everything that would turn a line on a strip into a statement about her.
    private let bannedAnywhere = ["thrush", "infection", "candida", "vaginosis", "diagnos", "treat", "cure", "prescrib",
                                  "guaranteed", "infertil", "conceive", "conception", "intercourse", "have sex",
                                  "gender", "shettles", "sex selection",
                                  "pregnan", "congratulat", "baby", "due date", "miscarr", "unfortunately", "sorry",
                                  "positive", "negative", "expecting", "celebrat"]
    /// Short words that match as whole words only, which is where they would actually appear.
    private let bannedWords = ["bv", "sti", "stis", "boy", "girl", "week", "weeks", "hcg"]

    /// The only four strings allowed to carry the product name, pinned here as literals so a
    /// fifth cannot be approved by editing the registry alone.
    private let approvedProductNameLiterals = ["Pregnancy Test", "Scan Pregnancy Test",
                                               "Delete all pregnancy test results",
                                               "Delete all pregnancy test results?"]

    /// True when `term` appears in `text` as a whole word, so "sti" does not match "testing".
    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Every banned term found in `text`. An approved string has the product phrase removed and
    /// the remainder scanned with the full list; every other string is scanned whole.
    private func bannedTerms(in text: String) -> [String] {
        let scanned = approvedProductNameLiterals.contains(text)
            ? text.replacingOccurrences(of: "pregnancy test", with: "", options: .caseInsensitive)
            : text
        let lower = scanned.lowercased()
        return bannedAnywhere.filter { lower.contains($0) } + bannedWords.filter { containsWord($0, in: scanned) }
    }

    func testCopyHasNoBannedTerms() {
        XCTAssertGreaterThanOrEqual(HcgScanCopy.allSurfaces.count, 60, "the registry must not shrink")
        for s in HcgScanCopy.allSurfaces {
            XCTAssertEqual(bannedTerms(in: s), [], "Banned term in pregnancy test copy: \(s)")
        }
    }

    /// The product name may appear in exactly these four strings.
    func testTheApprovedProductNameSurfacesAreExactlyTheFourPinnedStrings() {
        XCTAssertEqual(HcgScanCopy.approvedProductNameSurfaces, approvedProductNameLiterals)
        for s in HcgScanCopy.approvedProductNameSurfaces {
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(s), "\(s) is not in allSurfaces")
        }
        let carryingTheName = Set(HcgScanCopy.allSurfaces.filter { $0.lowercased().contains("pregnan") })
        XCTAssertEqual(carryingTheName, Set(approvedProductNameLiterals))
    }

    /// The guard has to be able to fail, or the tests above prove nothing.
    func testTheGuardCatchesAPlantedBannedString() {
        XCTAssertEqual(bannedTerms(in: "You are pregnant"), ["pregnan"])
        XCTAssertEqual(Set(bannedTerms(in: "Pregnancy Test result: positive")), ["pregnan", "positive"],
                       "the product name outside the four approved strings is not excused")
        XCTAssertEqual(bannedTerms(in: "Congratulations"), ["congratulat"])
        XCTAssertEqual(bannedTerms(in: "We're sorry, unfortunately this was a miscarriage"),
                       ["miscarr", "unfortunately", "sorry"])
        XCTAssertEqual(bannedTerms(in: "About 4 weeks"), ["weeks"])
        XCTAssertEqual(bannedTerms(in: "hCG detected"), ["hcg"])
        XCTAssertEqual(bannedTerms(in: "pregnancy test"), ["pregnan"], "the allow-list is exact, case included")

        // "Pregnancy Test" passes only through the allow-list: the same words scanned whole fail.
        XCTAssertEqual(bannedTerms(in: "Pregnancy Test"), [])
        XCTAssertTrue("Pregnancy Test".lowercased().contains("pregnan"))
        XCTAssertEqual(bannedTerms(in: "Pregnancy Test "), ["pregnan"])
        XCTAssertEqual(bannedTerms(in: "Test line detected"), [])
    }

    /// The remainder of an approved string is still scanned with the full list.
    func testAnApprovedStringsRemainderIsStillScanned() {
        for s in approvedProductNameLiterals {
            let remainder = s.replacingOccurrences(of: "pregnancy test", with: "", options: .caseInsensitive)
            XCTAssertFalse(remainder.lowercased().contains("pregnan"), s)
            XCTAssertNotEqual(remainder, s, "\(s) does not carry the product phrase")
        }
    }

    func testTheWholeWordMatcherCatchesWhatItShould() {
        XCTAssertTrue(containsWord("sti", in: "This may be an STI."))
        XCTAssertTrue(containsWord("boy", in: "More likely a boy."))
        XCTAssertTrue(containsWord("girl", in: "Girl or not"))
        XCTAssertTrue(containsWord("week", in: "One week late"))
        XCTAssertTrue(containsWord("hcg", in: "An hCG strip"))
        XCTAssertFalse(containsWord("sti", in: "Reading your test, still testing"))
        XCTAssertFalse(containsWord("boy", in: "Keep it buoyant"))
    }

    func testCopyFollowsHouseStyle() {
        for s in HcgScanCopy.allSurfaces {
            XCTAssertFalse(s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty string registered")
            XCTAssertFalse(s.contains("\u{2014}"), "em dash in pregnancy test copy: \(s)")
            XCTAssertFalse(s.lowercased().contains("analyz"), "US spelling in pregnancy test copy: \(s)")
        }
    }

    // ── Registry ──

    func testEveryClassificationHasATitleAndABodyAndBothAreGuarded() {
        for classification in HcgClassification.allCases {
            let title = HcgScanCopy.title(for: classification)
            let body = HcgScanCopy.body(for: classification)
            XCTAssertFalse(title.isEmpty, "no title for \(classification)")
            XCTAssertFalse(body.isEmpty, "no body for \(classification)")
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(title), "title for \(classification) is not in allSurfaces")
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(body), "body for \(classification) is not in allSurfaces")
        }
    }

    func testEveryQualityIssueHasAMessageAndAllOfThemAreGuarded() {
        for issue in ScanQualityIssue.allCases {
            let message = HcgScanCopy.message(for: issue)
            XCTAssertFalse(message.isEmpty, "no message for \(issue)")
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(message), "message for \(issue) is not in allSurfaces")
        }
    }

    /// Only the two messages that would mention pH pads differ; the camera otherwise speaks one way.
    func testQualityMessagesAreThePhScansExceptWhereTheyWouldNamePads() {
        for issue in ScanQualityIssue.allCases where issue != .unrecognisedStrip && issue != .reagentAreaNotFound {
            XCTAssertEqual(HcgScanCopy.message(for: issue), PhScanCopy.message(for: issue), "\(issue)")
        }
        XCTAssertEqual(HcgScanCopy.message(for: .unrecognisedStrip), HcgScanCopy.unrecognisedStrip)
        XCTAssertEqual(HcgScanCopy.message(for: .reagentAreaNotFound), HcgScanCopy.lineAreasNotFound)
        XCTAssertFalse(HcgScanCopy.message(for: .reagentAreaNotFound).lowercased().contains("pad"))
    }

    func testBothUnreadableReasonsHaveARegisteredMessage() {
        XCTAssertEqual(HcgScanCopy.unreadableMessage(for: .indeterminateTestLine), HcgScanCopy.indeterminateMessage)
        XCTAssertTrue(HcgScanCopy.allSurfaces.contains(HcgScanCopy.indeterminateMessage))

        for issue in ScanQualityIssue.allCases {
            let message = HcgScanCopy.unreadableMessage(for: .quality([issue]))
            XCTAssertEqual(message, HcgScanCopy.message(for: issue), "\(issue)")
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(message ?? ""), "\(issue)")
        }
        XCTAssertEqual(HcgScanCopy.unreadableMessage(for: .quality([.glare, .blurred])),
                       HcgScanCopy.message(for: .glare), "the first issue speaks")
        XCTAssertNil(HcgScanCopy.unreadableMessage(for: .quality([])), "no reason the screen can name")
    }

    func testInstructionStepsAreAllRegistered() {
        XCTAssertEqual(HcgScanCopy.instructionSteps.count, 5)
        for step in HcgScanCopy.instructionSteps {
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(step))
        }
    }

    func testSharedWordingIsThePhScansAndIsRegistered() {
        XCTAssertEqual(HcgScanCopy.openCamera, PhScanCopy.openCamera)
        XCTAssertEqual(HcgScanCopy.enterManually, PhScanCopy.enterManually)
        XCTAssertEqual(HcgScanCopy.saveResult, PhScanCopy.saveResult)
        XCTAssertEqual(HcgScanCopy.scanAgain, PhScanCopy.scanAgain)
        XCTAssertEqual(HcgScanCopy.tryAgain, PhScanCopy.tryAgain)
        XCTAssertEqual(HcgScanCopy.resultSaved, PhScanCopy.resultSaved)
        XCTAssertEqual(HcgScanCopy.saveFailed, PhScanCopy.saveFailed)
        XCTAssertEqual(HcgScanCopy.cancel, PhScanCopy.cancel)
        XCTAssertEqual(HcgScanCopy.privacyNote, PhScanCopy.privacyNote)
        for shared in [HcgScanCopy.openCamera, HcgScanCopy.enterManually, HcgScanCopy.saveResult,
                       HcgScanCopy.scanAgain, HcgScanCopy.tryAgain, HcgScanCopy.resultSaved, HcgScanCopy.saveFailed,
                       HcgScanCopy.cancel, HcgScanCopy.privacyNote,
                       // Drawn by the shared camera screen, so they pass through this guard too.
                       PhScanCopy.permissionDeniedBody, PhScanCopy.openSettings] {
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(shared), shared)
        }
    }

    // ── Guidance ──

    /// `HcgScannerState` carries associated values, so it cannot be `CaseIterable`: this list is
    /// every plain case, every quality issue, both kinds of interruption and every kind of result.
    private var everyState: [HcgScannerState] {
        let provenance = HcgScanProvenance(scannerVersion: "s", configurationID: "strip-test",
                                           configurationVersion: "9.9.9")
        return [
            .idle, .requestingPermission, .permissionDenied, .cameraUnavailable, .preparingCamera,
            .searching, .stripDetected, .ready, .capturing, .analysing,
            .interrupted(.other), .interrupted(.backgrounded),
            .result(.reading(.testLineDetected, provenance)), .result(.reading(.noTestLineDetected, provenance)),
            .result(.invalid), .result(.unreadable(.quality([]))), .result(.unreadable(.quality([.glare]))),
            .result(.unreadable(.indeterminateTestLine)),
        ] + ScanQualityIssue.allCases.map(HcgScannerState.qualityIssue)
    }

    func testEveryStateHasGuidanceAndAllOfItIsGuarded() {
        for state in everyState {
            let guidance = HcgScanCopy.guidance(for: state)
            XCTAssertFalse(guidance.isEmpty, "no guidance for \(state)")
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(guidance), "guidance for \(state) is not in allSurfaces")
        }
    }

    /// Nothing a copy function can return escapes the guard: every string from every function,
    /// over every input it has, is in `allSurfaces`.
    func testEveryStringReturnedByEveryCopyFunctionIsRegistered() {
        var returned: [String] = []
        returned += HcgClassification.allCases.map(HcgScanCopy.title(for:))
        returned += HcgClassification.allCases.map(HcgScanCopy.body(for:))
        returned += ScanQualityIssue.allCases.map(HcgScanCopy.message(for:))
        returned += ScanQualityIssue.allCases.compactMap { HcgScanCopy.unreadableMessage(for: .quality([$0])) }
        returned += [HcgScanCopy.unreadableMessage(for: .indeterminateTestLine)].compactMap { $0 }
        returned += everyState.map(HcgScanCopy.guidance(for:))

        XCTAssertEqual(returned.count, 3 + 3 + 13 + 13 + 1 + everyState.count, "an input was skipped")
        for s in returned {
            XCTAssertTrue(HcgScanCopy.allSurfaces.contains(s), "not in allSurfaces: \(s)")
            XCTAssertEqual(bannedTerms(in: s), [], s)
        }
    }

    func testGuidanceUsesItsOwnWordingWhereItHasItAndThePhScansElsewhere() {
        let provenance = HcgScanProvenance(scannerVersion: "s", configurationID: "strip-test",
                                           configurationVersion: "9.9.9")
        XCTAssertEqual(HcgScanCopy.guidance(for: .analysing), "Reading your test…")
        XCTAssertEqual(HcgScanCopy.guidance(for: .qualityIssue(.unrecognisedStrip)), "We can't recognise this strip")
        XCTAssertEqual(HcgScanCopy.guidance(for: .qualityIssue(.reagentAreaNotFound)),
                       "Make sure both line areas are visible")
        XCTAssertEqual(HcgScanCopy.guidance(for: .result(.reading(.testLineDetected, provenance))), "Test line detected")
        XCTAssertEqual(HcgScanCopy.guidance(for: .result(.reading(.noTestLineDetected, provenance))),
                       "No test line detected")
        XCTAssertEqual(HcgScanCopy.guidance(for: .result(.invalid)), "Test invalid")
        XCTAssertEqual(HcgScanCopy.guidance(for: .result(.unreadable(.quality([.glare])))), "We couldn't read this test.")
        XCTAssertEqual(HcgScanCopy.guidance(for: .result(.unreadable(.indeterminateTestLine))),
                       "We couldn't read this test.", "an indeterminate scan is announced as unreadable, not as an outcome")
        XCTAssertEqual(HcgScanCopy.guidance(for: .idle), PhScanCopy.preparingCamera)
        XCTAssertEqual(HcgScanCopy.guidance(for: .permissionDenied), PhScanCopy.permissionNeeded)
        XCTAssertEqual(HcgScanCopy.guidance(for: .cameraUnavailable), PhScanCopy.cameraUnavailable)
        XCTAssertEqual(HcgScanCopy.guidance(for: .searching), PhScanCopy.searching)
        XCTAssertEqual(HcgScanCopy.guidance(for: .stripDetected), PhScanCopy.stripDetected)
        XCTAssertEqual(HcgScanCopy.guidance(for: .ready), PhScanCopy.holdSteady)
        XCTAssertEqual(HcgScanCopy.guidance(for: .interrupted(.other)), PhScanCopy.paused)
    }

    // ── The result describes the test, never the person ──

    func testTheOutcomeTitlesSayNothingAboutAPerson() {
        for title in [HcgScanCopy.detectedTitle, HcgScanCopy.notDetectedTitle] {
            XCTAssertFalse(containsWord("you", in: title), title)
            XCTAssertFalse(containsWord("your", in: title), title)
        }
    }

    /// Neither outcome's wording may leak into a scan that produced no outcome.
    func testInvalidAndUnreadableCopyNeverSaysDetected() {
        for s in [HcgScanCopy.invalidTitle, HcgScanCopy.invalidBody, HcgScanCopy.unreadableTitle,
                  HcgScanCopy.unreadableBody, HcgScanCopy.indeterminateMessage] {
            XCTAssertFalse(s.lowercased().contains("detected"), s)
        }
    }

    /// Both outcomes are presented identically: one note, whichever the strip shows.
    func testTheResultNoteIsOneStringForBothOutcomes() {
        XCTAssertEqual(HcgScanCopy.allSurfaces.filter { $0 == HcgScanCopy.resultNote }.count, 1)
        XCTAssertEqual(HcgScanCopy.manualDetected, HcgScanCopy.title(for: .testLineDetected))
        XCTAssertEqual(HcgScanCopy.manualNotDetected, HcgScanCopy.title(for: .noTestLineDetected))
    }

    // ── Verbatim copy (PROPOSED, awaiting owner and legal review: pinned so it cannot drift) ──

    func testVerbatimCardAndInstructionCopy() {
        XCTAssertEqual(HcgScanCopy.cardTitle, "Pregnancy Test")
        XCTAssertEqual(HcgScanCopy.screenTitle, "Pregnancy Test")
        XCTAssertEqual(HcgScanCopy.cardDescription, "Scan a test strip or enter its result")
        XCTAssertEqual(HcgScanCopy.instructionSteps, [
            "Complete the test following the instructions that came with it.",
            "Wait for the time the instructions give before reading the result.",
            "Place the strip horizontally on a flat, neutral surface.",
            "Make sure the test line area and the control line area are both visible.",
            "Read or scan the test within the time the instructions allow. A test read too early or too late may not be reliable.",
        ])
        XCTAssertEqual(HcgScanCopy.aboutNote,
                       "Genesyx records what your test strip shows. It does not tell you what a result means. The instructions that came with your test explain that.")
        XCTAssertEqual(HcgScanCopy.privacyNote, "Your camera image is read on your phone. It is never stored or uploaded.")
        XCTAssertEqual(HcgScanCopy.storageNote,
                       "Results are saved on this phone only, not to your Genesyx account. They are removed when you sign out and will not appear on another phone.")
    }

    func testVerbatimButtonAndCameraCopy() {
        XCTAssertEqual(HcgScanCopy.openCamera, "Open Camera")
        XCTAssertEqual(HcgScanCopy.enterManually, "Enter result manually")
        XCTAssertEqual(HcgScanCopy.saveResult, "Save Result")
        XCTAssertEqual(HcgScanCopy.scanAgain, "Scan Again")
        XCTAssertEqual(HcgScanCopy.tryAgain, "Try Again")
        XCTAssertEqual(HcgScanCopy.cancel, "Cancel")
        XCTAssertEqual(HcgScanCopy.resultSaved, "Result saved")
        XCTAssertEqual(HcgScanCopy.saveFailed, "We couldn't save your result. Please try again.")
        XCTAssertEqual(HcgScanCopy.scanNewTest, "Scan New Test")
        XCTAssertEqual(HcgScanCopy.done, "Done")
        XCTAssertEqual(HcgScanCopy.cameraTitle, "Scan Pregnancy Test")
        XCTAssertEqual(HcgScanCopy.analysing, "Reading your test…")
        XCTAssertEqual(HcgScanCopy.unrecognisedStrip, "We can't recognise this strip")
        XCTAssertEqual(HcgScanCopy.lineAreasNotFound, "Make sure both line areas are visible")
    }

    func testVerbatimResultCopy() {
        XCTAssertEqual(HcgScanCopy.title(for: .testLineDetected), "Test line detected")
        XCTAssertEqual(HcgScanCopy.body(for: .testLineDetected), "A line was detected in the test line area of this strip.")
        XCTAssertEqual(HcgScanCopy.title(for: .noTestLineDetected), "No test line detected")
        XCTAssertEqual(HcgScanCopy.body(for: .noTestLineDetected), "No line was detected in the test line area of this strip.")
        XCTAssertEqual(HcgScanCopy.resultNote,
                       "The instructions that came with your test explain what this means. A GP, midwife, pharmacist or sexual health clinic can confirm a result.")
        XCTAssertEqual(HcgScanCopy.disclaimer, "Genesyx records what the test strip shows. This isn't medical advice.")
        XCTAssertEqual(HcgScanCopy.title(for: .invalid), "Test invalid")
        XCTAssertEqual(HcgScanCopy.body(for: .invalid),
                       "We couldn't detect the control line, so this test can't be read. Please repeat the test with a new strip, following its instructions.")
        XCTAssertEqual(HcgScanCopy.unreadableTitle, "We couldn't read this test.")
        XCTAssertEqual(HcgScanCopy.unreadableBody, "Try scanning again in good, even lighting, or enter the result yourself.")
        XCTAssertEqual(HcgScanCopy.indeterminateMessage,
                       "This scan wasn't clear enough to record a result. Please repeat the test as its instructions describe. A GP, midwife, pharmacist or sexual health clinic can also help.")
    }

    func testVerbatimManualEntryAndSavedResultsCopy() {
        XCTAssertEqual(HcgScanCopy.manualTitle, "Enter your result")
        XCTAssertEqual(HcgScanCopy.manualPrompt, "Choose what your test strip shows, following its instructions.")
        XCTAssertEqual(HcgScanCopy.manualDetected, "Test line detected")
        XCTAssertEqual(HcgScanCopy.manualNotDetected, "No test line detected")
        XCTAssertEqual(HcgScanCopy.manualInvalid, "Invalid")
        XCTAssertEqual(HcgScanCopy.manualDateLabel, "Date and time of test")
        XCTAssertEqual(HcgScanCopy.historyTitle, "Saved results")
        XCTAssertEqual(HcgScanCopy.showHistory, "Show saved results")
        XCTAssertEqual(HcgScanCopy.hideHistory, "Hide saved results")
        XCTAssertEqual(HcgScanCopy.historyEmpty, "No results saved yet.")
        XCTAssertEqual(HcgScanCopy.sourceScanned, "Scanned")
        XCTAssertEqual(HcgScanCopy.sourceManual, "Entered manually")
        XCTAssertEqual(HcgScanCopy.deleteResult, "Delete this result")
        XCTAssertEqual(HcgScanCopy.deleteConfirmTitle, "Delete this result?")
        XCTAssertEqual(HcgScanCopy.deleteAll, "Delete all pregnancy test results")
        XCTAssertEqual(HcgScanCopy.deleteAllConfirmTitle, "Delete all pregnancy test results?")
        XCTAssertEqual(HcgScanCopy.deleteAllConfirmMessage,
                       "This removes every saved result from this phone. It can't be undone.")
        XCTAssertEqual(HcgScanCopy.deleteAllConfirmButton, "Delete all")
    }
}
