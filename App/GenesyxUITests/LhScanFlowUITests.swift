import XCTest

/// The ovulation (LH) test flow end to end, on the simulated camera: Scan home, the LH screen, the
/// camera cover, a result, an invalid test or an unreadable scan, saving, manual entry and the
/// Recent results list.
///
/// `-uiTestLhScenario <value>` scripts what the strip shows; `-uiTestScanScenario <value>` scripts
/// the camera, as it does for the pH scan. What is under test is everything around that script:
/// that an invalid or uncertain scan never shows a result, that nothing is saved unless she saves
/// it, and that a saved result is listed as what it was. The seeded container holds two results
/// (a low and a positive, both typed in) and has no backend, so a simulated result may be saved.
final class LhScanFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// The one place that knows where the LH screen lives: every test reaches it through here.
    /// A fresh launch opens on More with Scan home pushed; the LH card is then tapped.
    @discardableResult
    private func openLhHome(_ scenario: String = "low", camera: String? = nil, extra: [String] = [],
                            file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "6", "-uiTestMore", "scan", "-uiTestLhScenario", scenario]
        if let camera { app.launchArguments += ["-uiTestScanScenario", camera] }
        app.launchArguments += extra
        app.launch()
        XCTAssertTrue(element(app, "scan.home.lhCard").waitForExistence(timeout: 15),
                      "Scan home must be showing, with the LH card", file: file, line: line)
        element(app, "scan.home.lhCard").tap()
        XCTAssertTrue(element(app, "lh.home").waitForExistence(timeout: 10),
                      "the LH card must open the LH screen", file: file, line: line)
        return app
    }

    /// Several identifiers sit on text or on containers, so the element type is not assumed.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func openCamera(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        element(app, "lh.openCamera").tap()
        XCTAssertTrue(element(app, "lh.capture").waitForExistence(timeout: 10),
                      "Open Camera must raise the LH scan cover", file: file, line: line)
    }

    private func row(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        let row = element(app, "lh.history.row.\(index)")
        for _ in 0..<6 where row.exists && !row.isHittable { app.swipeUp() }
        return row
    }

    private func rowCount(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'lh.history.row.'")).count
    }

    /// True when anything inside the scan cover (or, with `container`, another screen) carries
    /// `text` in its label. Scoped, because the screens under a cover and the other tabs stay in
    /// the element tree.
    private func shows(_ app: XCUIApplication, _ text: String, in container: String = "lh.capture") -> Bool {
        element(app, container).descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch.exists
    }

    /// Kept in the result bundle, and written as a PNG when the run names a folder
    /// (`TEST_RUNNER_SCAN_SHOTS_DIR=<folder> xcodebuild test …`).
    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SCAN_SHOTS_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }

    // MARK: - Scan home and the LH screen

    func testTheLhCardOpensTheLhScreenWithFiveStepsAndRecentResults() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "6", "-uiTestMore", "scan", "-uiTestLhScenario", "low"]
        app.launch()
        XCTAssertTrue(element(app, "scan.home.lhCard").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "scan.home.phCard").isHittable, "the pH card stays beside the LH card")
        XCTAssertTrue(element(app, "scan.home.lhCard").isHittable)
        snap("lh-01-scan-home-both-cards")

        element(app, "scan.home.lhCard").tap()
        XCTAssertTrue(element(app, "lh.home").waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Scan your ovulation test"].exists)
        for step in 1...5 {
            XCTAssertTrue(element(app, "lh.instructions.step.\(step)").exists, "instruction step \(step) is missing")
        }
        XCTAssertFalse(element(app, "lh.instructions.step.6").exists, "there are five steps")
        XCTAssertTrue(element(app, "lh.privacyNote").exists)
        XCTAssertTrue(element(app, "lh.openCamera").isEnabled)
        XCTAssertTrue(element(app, "lh.enterManually").isEnabled)
        XCTAssertFalse(element(app, "consent.blocked").exists, "no consent banner while consent stands")
        XCTAssertFalse(element(app, "lh.capture").exists, "opening the screen must not open the camera")

        // The two seeded results, newest first, each read as one element.
        XCTAssertTrue(element(app, "lh.history").exists)
        XCTAssertEqual(rowCount(app), 2)
        XCTAssertTrue(row(app, 0).label.hasPrefix("LH surge detected, "), row(app, 0).label)
        XCTAssertTrue(row(app, 0).label.hasSuffix("Entered manually"), row(app, 0).label)
        XCTAssertTrue(row(app, 0).label.contains("Cycle day "), "the cycle day saved with the result is shown")
        XCTAssertTrue(row(app, 1).label.hasPrefix("Low LH, "), row(app, 1).label)
        XCTAssertFalse(element(app, "lh.history.empty").exists)
        snap("lh-02-lh-home-recent-results")
    }

    func testWithNoResultsTheListSaysSo() {
        let app = openLhHome(extra: ["-uiTestNoLh", "YES"])
        XCTAssertTrue(element(app, "lh.history.empty").exists)
        XCTAssertEqual(rowCount(app), 0)
    }

    // MARK: - Readings

    /// The whole happy path: scan, read, save, and find the result in Recent results.
    func testALowScanIsShownSavedAndListed() {
        let app = openLhHome("low")
        element(app, "lh.openCamera").tap()
        // The live camera lasts about two seconds on this script and XCUITest waits for the
        // spinner to settle before it answers a query, so it is photographed blind, not asserted.
        Thread.sleep(forTimeInterval: 0.6)
        snap("lh-03-camera-horizontal-guide")

        let title = element(app, "lh.result.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15), "a confident scan must end in a result")
        XCTAssertEqual(title.label, "Low LH, No LH surge detected on this test.", "the result is words, read as one element")
        XCTAssertTrue(element(app, "lh.result.note").exists)
        XCTAssertTrue(element(app, "lh.result.disclaimer").exists)
        XCTAssertTrue(element(app, "scan.debug.simulatedBanner").exists, "a scripted result must say that it is one")
        XCTAssertFalse(element(app, "scan.debug.saveBlocked").exists, "no backend here, so saving is allowed")
        XCTAssertFalse(element(app, "lh.result.saved").exists, "nothing is saved until she saves it")
        XCTAssertFalse(shows(app, "appears positive"), "a low result must not carry the positive wording")
        snap("lh-04-result-low")

        element(app, "lh.result.save").tap()
        XCTAssertTrue(element(app, "lh.result.saved").waitForExistence(timeout: 10), "Save must confirm")
        XCTAssertFalse(element(app, "lh.result.save").exists, "a saved result offers no second Save")
        XCTAssertFalse(element(app, "lh.result.saveFailed").exists)
        XCTAssertFalse(element(app, "scan.capture.cancel").exists, "Cancel after a save would read as undoing it")
        snap("lh-09-result-saved")

        element(app, "lh.result.done").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10), "Done returns to the LH screen")
        XCTAssertFalse(element(app, "lh.capture").exists, "the cover must be gone")
        XCTAssertEqual(rowCount(app), 3, "two seeded results plus the scan")
        XCTAssertTrue(row(app, 0).label.hasPrefix("Low LH, "), row(app, 0).label)
        XCTAssertTrue(row(app, 0).label.hasSuffix("Scanned"), "a scanned result is listed as scanned: \(row(app, 0).label)")
        snap("lh-10-saved-result-in-recent-results")
    }

    func testAPositiveScanCarriesTheResultNoteAndIsSavedAndListed() {
        let app = openLhHome("positive")
        openCamera(app)

        let title = element(app, "lh.result.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "LH surge detected, Your ovulation test appears positive.")
        XCTAssertTrue(element(app, "lh.result.note").label.contains("does not change the predicted dates"),
                      "a positive result must say it is one test and changes no predicted date")
        XCTAssertFalse(shows(app, "Low LH"))
        snap("lh-05-result-positive")

        element(app, "lh.result.save").tap()
        XCTAssertTrue(element(app, "lh.result.saved").waitForExistence(timeout: 10))
        element(app, "lh.result.done").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 3)
        XCTAssertTrue(row(app, 0).label.hasPrefix("LH surge detected, "), row(app, 0).label)
        XCTAssertTrue(row(app, 0).label.hasSuffix("Scanned"), row(app, 0).label)
    }

    /// The placeholder strip does not enable rising, so its signals read as low and the rising
    /// wording is never shown.
    func testARisingSignalIsShownAsLowWhileRisingIsOff() {
        let app = openLhHome("rising")
        openCamera(app)
        let title = element(app, "lh.result.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertTrue(title.label.hasPrefix("Low LH"), title.label)
        XCTAssertFalse(shows(app, "LH rising"))
    }

    /// On the slow script, so the second scan is still analysing when it is looked at.
    func testScanAgainStartsANewScanThatStartsUnsaved() {
        let app = openLhHome("low", camera: "slowReading")
        openCamera(app)
        XCTAssertTrue(element(app, "lh.result.title").waitForExistence(timeout: 15))

        element(app, "lh.scanAgain").tap()
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10),
                      "Scan Again must go back through the camera, not redraw the old result")
        XCTAssertFalse(element(app, "lh.result").exists)
        XCTAssertTrue(element(app, "lh.result.title").waitForExistence(timeout: 15), "the second scan must also finish")
        XCTAssertFalse(element(app, "lh.result.saved").exists, "the new result starts unsaved")
    }

    /// The Cancel button hides once a result is saved, so it must come back with the next scan:
    /// otherwise the camera, with no result to leave through, has no way out but manual entry.
    func testScanAgainAfterSavingOffersCancelAndSavesOnlyTheFirstResult() {
        let app = openLhHome("low", camera: "slowReading")
        openCamera(app)
        XCTAssertTrue(element(app, "lh.result.title").waitForExistence(timeout: 15))
        element(app, "lh.result.save").tap()
        XCTAssertTrue(element(app, "lh.result.saved").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "scan.capture.cancel").exists)

        element(app, "lh.scanAgain").tap()
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "scan.capture.cancel").exists, "a new scan must be cancellable after a save")

        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "lh.capture").exists, "the cover must be gone")
        XCTAssertEqual(rowCount(app), 3, "two seeded results plus the one saved scan")
    }

    // MARK: - Invalid: never a result, never saved

    private func assertInvalid(_ scenario: String, shot: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let app = openLhHome(scenario, camera: "slowReading")
        openCamera(app)

        XCTAssertTrue(element(app, "lh.invalid").waitForExistence(timeout: 15), "\(scenario) must end on the invalid screen", file: file, line: line)
        XCTAssertEqual(element(app, "lh.invalid.title").label,
                       "Test invalid, We couldn't detect the control line. Please repeat the test using a new strip.", file: file, line: line)
        for identifier in ["lh.result", "lh.result.save", "lh.result.saved", "lh.unreadable"] {
            XCTAssertFalse(element(app, identifier).exists, "an invalid test has no \(identifier)", file: file, line: line)
        }
        for word in ["Positive", "LH surge", "Low LH"] {
            XCTAssertFalse(shows(app, word), "an invalid test must never be given a result (\(word) is on screen)", file: file, line: line)
        }
        XCTAssertTrue(element(app, "lh.enterManually").exists, file: file, line: line)
        if let shot { snap(shot) }

        element(app, "lh.scanNewTest").tap()
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10),
                      "Scan New Test must go back through the camera", file: file, line: line)
        XCTAssertFalse(element(app, "lh.invalid").exists, file: file, line: line)
        XCTAssertTrue(element(app, "lh.invalid").waitForExistence(timeout: 15), "the same strip is invalid again", file: file, line: line)

        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertEqual(rowCount(app), 2, "an invalid scan saves nothing", file: file, line: line)
    }

    func testNoControlLineIsInvalidAndSavesNothing() {
        assertInvalid("invalidNoControl", shot: "lh-06-invalid")
    }

    /// A strong test line with no control line: the case that must never read as positive.
    func testATestLineWithoutAControlLineIsInvalidNeverPositive() {
        assertInvalid("invalidTestLineOnly")
    }

    // MARK: - Unreadable: never a classification

    private func assertUnreadable(_ scenario: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = openLhHome(scenario)
        openCamera(app)

        XCTAssertTrue(element(app, "lh.unreadable").waitForExistence(timeout: 15),
                      "a scan the analyser is unsure of is not a result", file: file, line: line)
        for identifier in ["lh.result", "lh.result.title", "lh.result.save", "lh.invalid"] {
            XCTAssertFalse(element(app, identifier).exists, "an unreadable scan has no \(identifier)", file: file, line: line)
        }
        for word in ["Low LH", "LH surge", "Positive", "Test invalid", "LH rising"] {
            XCTAssertFalse(shows(app, word), "an unreadable scan must show no classification (\(word) is on screen)", file: file, line: line)
        }
        XCTAssertTrue(element(app, "lh.tryAgain").exists, file: file, line: line)
        XCTAssertTrue(element(app, "lh.enterManually").exists, file: file, line: line)
        return app
    }

    func testALowConfidenceScanIsUnreadableAndSavesNothing() {
        let app = assertUnreadable("lowConfidence")
        XCTAssertFalse(element(app, "lh.unreadable.issue").exists)
        snap("lh-07-unreadable")
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 2, "an unreadable scan saves nothing")
    }

    func testASignalOutOfRangeIsUnreadableNeverClamped() {
        let app = assertUnreadable("signalOutOfRange")
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 2)
    }

    func testGlareIsUnreadableWithItsInstructionAndBothWaysOn() {
        let app = assertUnreadable("unreadable-glare")
        XCTAssertEqual(element(app, "lh.unreadable.issue").label, "Reduce glare")
        snap("lh-07b-unreadable-glare")

        element(app, "lh.tryAgain").tap()
        XCTAssertTrue(element(app, "lh.unreadable").waitForExistence(timeout: 15), "the same strip is unreadable again")

        // The other way on: type it in. The sheet belongs to the LH screen, so the cover goes first.
        element(app, "lh.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Enter your result"].waitForExistence(timeout: 10),
                      "Enter result manually must open the LH manual entry sheet")
        XCTAssertFalse(element(app, "lh.capture").exists)
        XCTAssertEqual(rowCount(app), 2, "nothing was saved on the way")
    }

    // MARK: - Camera states shared with the pH scan

    func testTooDarkShowsGuidanceOverAWideGuideAndNeverCaptures() {
        let app = openLhHome("positive", camera: "issue-tooDark")
        openCamera(app)

        let guidance = app.staticTexts.matching(NSPredicate(format: "identifier == 'scan.capture.guidance' AND label == 'More light needed'")).firstMatch
        XCTAssertTrue(guidance.waitForExistence(timeout: 10), "the camera must say what to change")
        XCTAssertTrue(app.staticTexts["Scan Ovulation Test"].exists)
        XCTAssertTrue(app.staticTexts["Simulated camera"].exists, "the preview must be showing, not obscured")
        snap("lh-03b-camera-too-dark")

        Thread.sleep(forTimeInterval: 4)
        XCTAssertTrue(guidance.exists, "four seconds on, it is still asking for light")
        for identifier in ["scan.analysing", "lh.result", "lh.invalid", "lh.unreadable", "scan.capture.progress"] {
            XCTAssertFalse(element(app, identifier).exists, "a frame with a quality problem must never be captured (\(identifier))")
        }
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10), "Cancel returns to the LH screen")
    }

    func testPermissionDeniedOffersSettingsAndManualEntry() {
        let app = openLhHome("low", camera: "permissionDenied")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.permissionDenied").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "scan.openSettings").exists)
        XCTAssertTrue(element(app, "scan.enterManually").exists)
        XCTAssertFalse(element(app, "lh.result").exists)
    }

    func testCameraUnavailableLeadsToManualEntry() {
        let app = openLhHome("low", camera: "cameraUnavailable")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.cameraUnavailable").waitForExistence(timeout: 10))
        element(app, "scan.tryAgain").tap()
        XCTAssertTrue(element(app, "scan.cameraUnavailable").waitForExistence(timeout: 10), "still no camera after Try Again")

        element(app, "scan.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Enter your result"].waitForExistence(timeout: 10),
                      "Enter result manually must close the cover and open the LH sheet, not the pH one")
    }

    // MARK: - Manual entry

    /// Each of the three choices is saved and listed as typed in. Rising is a scanner's reading
    /// and is never offered.
    func testEachManualChoiceIsSavedAndListedAsManualAndRisingIsNotOffered() {
        let app = openLhHome()
        let choices = [("low", "Low LH"), ("positive", "LH surge detected"), ("invalid", "Test invalid")]
        for (offset, choice) in choices.enumerated() {
            for _ in 0..<6 where !element(app, "lh.enterManually").isHittable { app.swipeDown() }
            element(app, "lh.enterManually").tap()
            XCTAssertTrue(app.navigationBars["Enter your result"].waitForExistence(timeout: 10))
            XCTAssertFalse(element(app, "lh.capture").exists, "typing a result in must not open the camera")

            for option in ["low", "positive", "invalid"] {
                XCTAssertTrue(element(app, "lh.manual.option.\(option)").exists)
                XCTAssertFalse(element(app, "lh.manual.option.\(option)").isSelected, "nothing is chosen for her")
            }
            XCTAssertFalse(element(app, "lh.manual.option.rising").exists, "rising is never offered")
            XCTAssertFalse(shows(app, "rising", in: "lh.manual"))
            XCTAssertFalse(element(app, "lh.manual.save").isEnabled, "no Save before a choice")
            if offset == 0 { snap("lh-08-manual-entry-sheet") }

            element(app, "lh.manual.option.\(choice.0)").tap()
            XCTAssertTrue(element(app, "lh.manual.option.\(choice.0)").isSelected)
            if offset == 0 { snap("lh-08b-manual-entry-chosen") }
            element(app, "lh.manual.save").tap()

            // Read in place, not scrolled to: on the smaller phone the newest row is above the
            // fold, and `row` only scrolls one way, so chasing it never succeeds. A label needs
            // no hit point.
            XCTAssertTrue(element(app, "lh.history.row.\(2 + offset)").waitForExistence(timeout: 10), "\(choice.0) must be listed after Save")
            XCTAssertFalse(app.navigationBars["Enter your result"].exists, "a saved entry closes the sheet")
            let newest = element(app, "lh.history.row.0").label
            XCTAssertTrue(newest.hasPrefix(choice.1 + ", "), newest)
            XCTAssertTrue(newest.hasSuffix("Entered manually"), newest)
        }
        XCTAssertEqual(rowCount(app), 5)
    }

    func testCancellingManualEntrySavesNothing() {
        let app = openLhHome()
        element(app, "lh.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Enter your result"].waitForExistence(timeout: 10))
        element(app, "lh.manual.option.positive").tap()
        element(app, "lh.manual.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Enter your result"].exists)
        XCTAssertEqual(rowCount(app), 2)
    }

    // MARK: - Delete, cancel, consent

    func testDeletingAResultAsksFirstAndThenRemovesIt() {
        let app = openLhHome()
        XCTAssertEqual(rowCount(app), 2)
        let delete = app.alerts.buttons["Delete this result"].firstMatch

        // Asked, and answered no: nothing goes.
        row(app, 0).tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "deleting must ask first")
        XCTAssertTrue(app.alerts["Delete this result?"].exists)
        XCTAssertEqual(rowCount(app), 2, "nothing is deleted until she confirms")
        snap("lh-11-delete-confirmation")
        app.alerts.buttons["Cancel"].firstMatch.tap()
        XCTAssertFalse(delete.waitForExistence(timeout: 2))
        XCTAssertEqual(rowCount(app), 2)

        row(app, 0).tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.tap()
        XCTAssertTrue(element(app, "lh.history.row.0").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 1, "the confirmed result is gone and the other stays")
        XCTAssertTrue(row(app, 0).label.hasPrefix("Low LH, "), "the positive one was deleted: \(row(app, 0).label)")
    }

    func testCancellingDuringAnalysisSavesNothing() {
        let app = openLhHome("positive", camera: "slowReading")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10), "Cancel returns to the LH screen")
        // Longer than the three-second analysis: a result arriving late must go nowhere.
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(element(app, "lh.result").exists)
        XCTAssertEqual(rowCount(app), 2, "only the two seeded results: a cancelled scan saves nothing")
    }

    func testCancellingAResultWithoutSavingSavesNothing() {
        let app = openLhHome("positive")
        openCamera(app)
        XCTAssertTrue(element(app, "lh.result.title").waitForExistence(timeout: 15))
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "lh.openCamera").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 2, "a result she did not save is not kept")
    }

    /// With consent withdrawn the flow stops before any image is taken and nothing can be typed
    /// in; what she already recorded stays listed and can still be deleted.
    func testWithdrawnConsentBlocksTheCameraAndManualEntryButNotDeleting() {
        let app = openLhHome(extra: ["-uiTestConsentWithdrawn", "YES"])
        XCTAssertTrue(element(app, "consent.blocked").exists, "the LH screen must say why recording is off")

        let open = element(app, "lh.openCamera")
        XCTAssertFalse(open.isEnabled, "no scan without consent")
        XCTAssertFalse(element(app, "lh.enterManually").isEnabled, "no manual result without consent")
        snap("lh-12-consent-withdrawn")
        open.tap()
        XCTAssertFalse(element(app, "lh.capture").waitForExistence(timeout: 2), "a disabled Open Camera must do nothing")
        element(app, "lh.enterManually").tap()
        XCTAssertFalse(app.navigationBars["Enter your result"].waitForExistence(timeout: 2), "a disabled manual entry must do nothing")

        XCTAssertEqual(rowCount(app), 2, "what she recorded before stays listed")
        row(app, 0).tap()
        let delete = app.alerts.buttons["Delete this result"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "deleting stays available after a withdrawal")
        delete.tap()
        XCTAssertTrue(element(app, "lh.history.row.0").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 1)
    }

    // MARK: - Leaving the app

    /// The app switcher, as far as a simulator shows it: with a result on screen the whole of the
    /// app's card is one flat colour, and the result is still there, unsaved, when she returns.
    func testAResultIsHiddenInTheAppSwitcher() {
        let app = openLhHome("positive")
        openCamera(app)
        let title = element(app, "lh.result.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))

        assertAppSwitcherCardIsFlat("lh-14-app-switcher-result-covered")

        app.activate()
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the result is still there on return")
        XCTAssertFalse(element(app, "lh.result.saved").exists)
        XCTAssertTrue(element(app, "lh.result.save").isEnabled)
        snap("lh-14-returned-result")
    }

    /// The same look at the LH screen with its saved results listed, and at the manual entry
    /// sheet with a choice marked.
    func testSavedResultsAndTheSheetAreHiddenInTheAppSwitcher() {
        let app = openLhHome()
        XCTAssertEqual(rowCount(app), 2, "the two seeded results are listed")
        assertAppSwitcherCardIsFlat("lh-14b-app-switcher-saved-results-covered")
        app.activate()
        XCTAssertTrue(element(app, "lh.home").waitForExistence(timeout: 10), "she is back on the screen she left")
        XCTAssertEqual(rowCount(app), 2)

        element(app, "lh.enterManually").tap()
        let option = element(app, "lh.manual.option.positive")
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        assertAppSwitcherCardIsFlat("lh-14c-app-switcher-manual-sheet-covered")
        app.activate()
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        XCTAssertTrue(option.isSelected, "her choice is kept")
    }


    /// Backgrounded while analysing, on the script whose analysis is over the moment the app stops
    /// being active: the hardest case, and no timer for the test to race. The scan must be dropped,
    /// not finished behind her back, and must start again from the camera when she returns.
    func testBackgroundingDuringAScanPausesItAndReturningRestarts() {
        let app = openLhHome("positive", camera: "awayReading")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))

        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 10)
        // Looked for inside the cover: searching the whole app for what is not drawn yet can hold
        // the app's main thread for a second or more, and that is the thread that has to draw it.
        let paused = element(app, "lh.capture").descendants(matching: .any).matching(identifier: "scan.paused").firstMatch
        XCTAssertTrue(paused.waitForExistence(timeout: 5), "going to the background must pause the scan")
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(element(app, "lh.result").exists, "the analysis must not finish while she is away")

        app.activate()
        XCTAssertFalse(element(app, "lh.result").exists, "returning must restart the scan, not reveal a result made in the background")
        XCTAssertTrue(element(app, "lh.result.title").waitForExistence(timeout: 20), "the restarted scan must finish")
        XCTAssertFalse(element(app, "scan.paused").exists)
        XCTAssertFalse(element(app, "lh.result.saved").exists, "nothing was saved meanwhile")
    }

    // MARK: - pH beside it

    /// The pH card and its flow from the same Scan home, with an LH script also on the command line.
    func testThePhCardAndFlowStillWorkBesideTheLhCard() {
        let app = openLhHome("positive", camera: "reading-5.2")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, "scan.home.phCard").waitForExistence(timeout: 10), "back from the LH screen is Scan home")

        element(app, "scan.home.phCard").tap()
        XCTAssertTrue(element(app, "scan.openCamera").waitForExistence(timeout: 10), "the pH card must open the pH instructions")
        XCTAssertFalse(element(app, "lh.home").exists)
        element(app, "scan.openCamera").tap()
        XCTAssertTrue(element(app, "scan.capture").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "lh.capture").exists, "the pH card opens the pH cover")

        let value = element(app, "scan.result.value")
        XCTAssertTrue(value.waitForExistence(timeout: 15))
        XCTAssertEqual(value.label, "pH 5.2")
        XCTAssertFalse(element(app, "lh.result").exists, "a pH scan must not show an LH result")
        XCTAssertFalse(shows(app, "LH surge", in: "scan.capture"))
    }
}
