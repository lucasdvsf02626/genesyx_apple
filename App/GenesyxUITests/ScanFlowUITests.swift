import XCTest

/// The Scan Test flow end to end, on the simulated camera: More, Scan home, instructions, the camera
/// cover, a result or an unreadable scan, saving, and every way out.
///
/// The simulator has no camera, so `-uiTestScanScenario <value>` scripts what the "camera" sees
/// and what the analyser answers. What is under test is everything around that script: that an
/// uncertain scan never shows a number, that nothing is saved unless she saves it, and that the
/// tab hands her on to the right place afterwards. The seeded container has no backend, so a
/// simulated reading may be saved here (it may not on a signed-in developer build).
///
/// Not driven here: "Use Test Image" opens the system photo picker, which runs out of process.
final class ScanFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// The one place that knows where Scan home lives: every test reaches it through here. A
    /// fresh launch opens on the More tab (index 6) with Scan home already pushed and the scan
    /// scripted; given an app that is already running, it goes there by the More tab and its
    /// Scan Test row.
    @discardableResult
    private func openScanHome(_ scenario: String = "reading-4.4", in running: XCUIApplication? = nil, extra: [String] = [],
                              file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = running ?? launch(scenario, tab: 6, extra: ["-uiTestMore", "scan"] + extra)
        if running != nil {
            tabButton(app, "More").tap()
            element(app, "more.scan").tap()
        }
        XCTAssertTrue(element(app, "scan.home.phCard").waitForExistence(timeout: 15),
                      "Scan home must be showing", file: file, line: line)
        return app
    }

    /// Seeded, with the scan scripted. Only `openScanHome` and the tab-bar test call this.
    private func launch(_ scenario: String, tab: Int, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)", "-uiTestScanScenario", scenario] + extra
        app.launch()
        return app
    }

    /// Several scan identifiers sit on text or on containers, so the element type is not assumed.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tabButton(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(identifier: label).firstMatch
    }

    private func openInstructions(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        element(app, "scan.home.phCard").tap()
        XCTAssertTrue(element(app, "scan.openCamera").waitForExistence(timeout: 10),
                      "the pH card must open the instructions", file: file, line: line)
    }

    private func openCamera(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openInstructions(app, file: file, line: line)
        element(app, "scan.openCamera").tap()
        XCTAssertTrue(element(app, "scan.capture").waitForExistence(timeout: 10),
                      "Open Camera must raise the scan cover", file: file, line: line)
    }

    /// Opens the pH tab's history list and returns its toggle, whose label carries the count.
    private func openPhHistory(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let toggle = app.buttons["phHistoryToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "the pH tab must be showing", file: file, line: line)
        for _ in 0..<10 where !toggle.isHittable { app.swipeUp() }
        toggle.tap()
        return toggle
    }

    private func historyRow(_ app: XCUIApplication, containing value: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'phHistoryRow' AND label CONTAINS %@", value)).firstMatch
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

    // MARK: - Tab, home, instructions

    /// Scan has no tab of its own: the seventh tab is More, which lists Profile and Scan Test.
    /// The only test that asserts what is on the tab bar.
    func testMoreTakesTheSeventhTabAndListsProfileAndScanTest() {
        let app = launch("reading-4.4", tab: 0)
        XCTAssertTrue(tabButton(app, "Home").waitForExistence(timeout: 15), "the tab bar must appear")

        let bar = ["Home", "Track", "pH", "Nutrition", "Insights", "Learn", "More"]
        for label in bar {
            XCTAssertTrue(tabButton(app, label).exists, "\(label) is missing from the bar")
            XCTAssertTrue(tabButton(app, label).isHittable, "\(label) is on the bar but cannot be tapped")
        }
        // Left to right, so More is the seventh.
        let positions = bar.map { tabButton(app, $0).frame.midX }
        XCTAssertEqual(positions, positions.sorted(), "the bar must read \(bar) left to right")
        XCTAssertFalse(tabButton(app, "Profile").exists, "Profile lives inside More, not on the bar")
        XCTAssertFalse(tabButton(app, "Scan").exists, "Scan lives inside More, not on the bar")
        XCTAssertFalse(element(app, "scan.home.phCard").exists, "Scan home must not exist before it is opened")

        tabButton(app, "More").tap()
        XCTAssertTrue(element(app, "more.home").waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["More"].exists)
        XCTAssertTrue(element(app, "more.profile").isHittable)
        XCTAssertTrue(element(app, "more.scan").isHittable)
        snap("01-more-list-seven-tabs")

        element(app, "more.profile").tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10), "the Profile row must open Profile")
        XCTAssertTrue(app.buttons["Log out"].exists, "Profile's own content must be showing")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(element(app, "more.scan").waitForExistence(timeout: 10), "back from Profile is the More list")
        element(app, "more.scan").tap()
        XCTAssertTrue(element(app, "scan.home.phCard").waitForExistence(timeout: 10), "the Scan Test row must open Scan home")
        XCTAssertTrue(element(app, "scan.home.phCard").isHittable)
        XCTAssertTrue(app.staticTexts["Scan Test"].exists)
        XCTAssertTrue(element(app, "scan.home").exists)
        snap("01b-scan-home-from-more")
    }

    func testThePhCardOpensTheInstructions() {
        let app = openScanHome("reading-4.4")
        openInstructions(app)

        XCTAssertTrue(element(app, "scan.instructions").exists)
        for step in 1...5 {
            XCTAssertTrue(element(app, "scan.instructions.step.\(step)").exists, "instruction step \(step) is missing")
        }
        XCTAssertFalse(element(app, "scan.instructions.step.6").exists, "there are five steps")
        XCTAssertTrue(element(app, "scan.privacyNote").exists, "the privacy note must be on the instructions")
        XCTAssertTrue(element(app, "scan.openCamera").isEnabled)
        XCTAssertTrue(element(app, "scan.enterManually").isEnabled)
        XCTAssertFalse(element(app, "consent.blocked").exists, "no consent banner while consent stands")
        snap("02-instructions")
    }

    // MARK: - Readings

    /// The whole happy path: scan, read, save, and find the reading in the pH history.
    func testAnElevatedReadingIsShownSavedAndFiledInHerHistory() {
        let app = openScanHome("reading-5.2")
        openCamera(app)

        let value = element(app, "scan.result.value")
        XCTAssertTrue(value.waitForExistence(timeout: 15), "a confident scan must end in a result")
        XCTAssertEqual(value.label, "pH 5.2")
        XCTAssertEqual(value.value as? String, "Elevated", "the status is a word, read with the number")
        XCTAssertTrue(element(app, "scan.result.elevatedNote").exists, "an elevated reading carries the tracker's signpost")
        XCTAssertTrue(element(app, "scan.result.disclaimer").exists)
        XCTAssertTrue(element(app, "scan.debug.simulatedBanner").exists, "a scripted number must say that it is one")
        XCTAssertFalse(element(app, "scan.debug.saveBlocked").exists, "no backend here, so saving is allowed")
        XCTAssertFalse(element(app, "scan.result.saved").exists, "nothing is saved until she saves it")
        snap("05-result-5.2-elevated")

        element(app, "scan.result.save").tap()
        XCTAssertTrue(element(app, "scan.result.saved").waitForExistence(timeout: 10), "Save must confirm")
        XCTAssertFalse(element(app, "scan.result.save").exists, "a saved result offers no second Save")
        XCTAssertFalse(element(app, "scan.result.saveFailed").exists)
        XCTAssertFalse(element(app, "scan.capture.cancel").exists, "Cancel after a save would read as undoing it")
        snap("06-result-saved")

        element(app, "scan.result.viewHistory").tap()
        XCTAssertTrue(app.navigationBars["Vaginal pH"].waitForExistence(timeout: 10),
                      "View pH history must land on the pH tab")
        XCTAssertFalse(element(app, "scan.capture").exists, "the cover must be gone")

        let toggle = openPhHistory(app)
        XCTAssertTrue(app.buttons["phHistoryRow3"].waitForExistence(timeout: 10), "three seeded readings plus the scan")
        XCTAssertEqual(toggle.label, "Reading history (4)")
        XCTAssertTrue(historyRow(app, containing: "5.2").exists, "the scanned 5.2 must be in her history")
        XCTAssertFalse(app.buttons["phHistoryRow4"].exists, "one scan files one reading")

        // More is back at its list, not parked on the scan screens she finished with.
        openScanHome(in: app)
        XCTAssertFalse(element(app, "scan.openCamera").exists)
    }

    func testAHealthyReadingCarriesNoElevatedNote() {
        let app = openScanHome("reading-4.4")
        openInstructions(app)
        element(app, "scan.openCamera").tap()
        // The live camera lasts about two seconds on this script and XCUITest waits for the
        // spinner to settle before it answers a query, so it is photographed blind, not asserted.
        Thread.sleep(forTimeInterval: 0.6)
        snap("03-camera-live")

        let value = element(app, "scan.result.value")
        XCTAssertTrue(value.waitForExistence(timeout: 15))
        XCTAssertEqual(value.label, "pH 4.4")
        XCTAssertEqual(value.value as? String, "Healthy")
        XCTAssertFalse(element(app, "scan.result.elevatedNote").exists, "a reading in range carries no signpost")
        XCTAssertTrue(element(app, "scan.result.disclaimer").exists)
        snap("04-result-4.4-healthy")
    }

    /// On the slow script, so the second scan is still analysing when it is looked at: a Scan
    /// Again that only redrew the old result would never show that.
    func testScanAgainStartsANewScan() {
        let app = openScanHome("slowReading")
        openCamera(app)
        let value = element(app, "scan.result.value")
        XCTAssertTrue(value.waitForExistence(timeout: 15))

        element(app, "scan.scanAgain").tap()
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10),
                      "Scan Again must go back through the camera, not redraw the old result")
        XCTAssertFalse(element(app, "scan.result").exists)
        XCTAssertTrue(value.waitForExistence(timeout: 15), "the second scan must also finish")
        XCTAssertEqual(value.label, "pH 4.4")
        XCTAssertFalse(element(app, "scan.result.saved").exists, "the new result starts unsaved")
    }

    // MARK: - Unreadable: never a number

    func testALowConfidenceScanIsUnreadableAndShowsNoNumber() {
        let app = openScanHome("lowConfidence")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.unreadable").waitForExistence(timeout: 15),
                      "a result the analyser is unsure of is not a result")
        XCTAssertFalse(element(app, "scan.result.value").exists, "an uncertain scan must never show a number")
        XCTAssertFalse(element(app, "scan.result").exists)
        XCTAssertFalse(element(app, "scan.result.save").exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '4.4'")).firstMatch.exists,
                       "the value the analyser guessed must not leak onto the screen")
        XCTAssertTrue(element(app, "scan.scanAgain").exists)
        XCTAssertTrue(element(app, "scan.enterManually").exists)
        snap("07-unreadable")
    }

    func testAnOutOfRangeValueIsUnreadableAndNeverClamped() {
        let app = openScanHome("outOfRange")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.unreadable").waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, "scan.result.value").exists)
        for number in ["7.0", "7.6"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", number)).firstMatch.exists,
                           "7.6 is outside the scale: it must be neither shown nor clamped to 7.0 (\(number) is on screen)")
        }
    }

    func testGlareIsUnreadableWithItsInstructionAndBothWaysOn() {
        let app = openScanHome("unreadable-glare")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.unreadable").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "scan.unreadable.issue").label, "Reduce glare")
        XCTAssertFalse(element(app, "scan.result.value").exists)
        snap("08-unreadable-glare")

        // That Scan Again really rescans is `testScanAgainStartsANewScan`; here, only where it ends.
        element(app, "scan.scanAgain").tap()
        XCTAssertTrue(element(app, "scan.unreadable").waitForExistence(timeout: 15), "the same strip is unreadable again")
        XCTAssertFalse(element(app, "scan.result.value").exists)

        // The other way on: type it in. The sheet belongs to the tab, so the cover goes first.
        element(app, "scan.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Log pH reading"].waitForExistence(timeout: 10),
                      "Enter result manually must open the pH log sheet")
        XCTAssertFalse(element(app, "scan.capture").exists)
    }

    /// A live quality problem is guidance, not a result: the camera keeps waiting and never captures.
    func testTooDarkShowsGuidanceAndNeverCaptures() {
        let app = openScanHome("issue-tooDark")
        openCamera(app)

        let guidance = app.staticTexts.matching(NSPredicate(format: "identifier == 'scan.capture.guidance' AND label == 'More light needed'")).firstMatch
        XCTAssertTrue(guidance.waitForExistence(timeout: 10), "the camera must say what to change")
        // The simulated preview is drawn only while the scene counts as active inside the cover.
        XCTAssertTrue(app.staticTexts["Simulated camera"].exists, "the preview must be showing, not obscured")
        XCTAssertTrue(element(app, "scan.debug.useTestImage").exists)
        snap("09-camera-too-dark")

        Thread.sleep(forTimeInterval: 4)
        XCTAssertTrue(guidance.exists, "four seconds on, it is still asking for light")
        for identifier in ["scan.analysing", "scan.result", "scan.unreadable", "scan.capture.progress"] {
            XCTAssertFalse(element(app, identifier).exists, "a frame with a quality problem must never be captured (\(identifier))")
        }

        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "scan.openCamera").waitForExistence(timeout: 10), "Cancel returns to the instructions")
        XCTAssertTrue(element(app, "scan.openCamera").isHittable)
    }

    // MARK: - No camera

    func testPermissionDeniedOffersSettingsAndManualEntry() {
        let app = openScanHome("permissionDenied")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.permissionDenied").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "scan.openSettings").exists)
        XCTAssertTrue(element(app, "scan.enterManually").exists)
        XCTAssertTrue(element(app, "scan.capture.cancel").exists)
        XCTAssertFalse(element(app, "scan.result").exists)
        snap("10-permission-denied")
    }

    func testCameraUnavailableLeadsToAManualReadingInHerHistory() {
        let app = openScanHome("cameraUnavailable")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.cameraUnavailable").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "scan.tryAgain").exists)
        snap("11-camera-unavailable")
        element(app, "scan.tryAgain").tap()
        XCTAssertTrue(element(app, "scan.cameraUnavailable").waitForExistence(timeout: 10), "still no camera after Try Again")

        element(app, "scan.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Log pH reading"].waitForExistence(timeout: 10),
                      "Enter result manually must close the cover and open the pH log sheet")
        XCTAssertEqual(app.staticTexts["ph.currentValue"].label, "4.2")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Vaginal pH"].waitForExistence(timeout: 10), "a manual save lands on the pH tab")
        _ = openPhHistory(app)
        XCTAssertTrue(app.buttons["phHistoryRow3"].waitForExistence(timeout: 10))
        XCTAssertTrue(historyRow(app, containing: "4.2").exists, "the typed 4.2 must be in her history")
    }

    // MARK: - Manual entry, cancel, consent

    func testEnterResultManuallyFromTheInstructionsFilesAReading() {
        let app = openScanHome("reading-4.4")
        openInstructions(app)

        element(app, "scan.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Log pH reading"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "scan.capture").exists, "typing a result in must not open the camera")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Vaginal pH"].waitForExistence(timeout: 10))
        let toggle = openPhHistory(app)
        XCTAssertTrue(app.buttons["phHistoryRow3"].waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "Reading history (4)")
        XCTAssertTrue(historyRow(app, containing: "4.2").exists)
    }

    func testCancellingDuringAnalysisSavesNothing() {
        let app = openScanHome("slowReading")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "scan.openCamera").waitForExistence(timeout: 10), "Cancel returns to the instructions")
        // Longer than the three-second analysis: a result arriving late must go nowhere.
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(element(app, "scan.result").exists)

        tabButton(app, "pH").tap()
        let toggle = openPhHistory(app)
        XCTAssertTrue(app.buttons["phHistoryRow2"].waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "Reading history (3)", "only the three seeded readings: a cancelled scan saves nothing")
        XCTAssertFalse(app.buttons["phHistoryRow3"].exists)
    }

    /// With consent withdrawn she still reaches the tabs, and the flow stops before any image is
    /// taken: both ways in are greyed out and the banner says why.
    func testWithdrawnConsentBlocksTheCameraAndManualEntry() {
        // Reaching Scan home at all is the first assertion: a withdrawal must not lock her out.
        let app = openScanHome(extra: ["-uiTestConsentWithdrawn", "YES"])
        XCTAssertTrue(element(app, "consent.blocked").exists, "Scan home must say why recording is off")
        openInstructions(app)

        let open = element(app, "scan.openCamera")
        XCTAssertFalse(open.isEnabled, "no scan without consent")
        XCTAssertFalse(element(app, "scan.enterManually").isEnabled, "no manual reading without consent")
        XCTAssertTrue(element(app, "consent.blocked").exists)
        snap("12-consent-withdrawn")

        open.tap()
        XCTAssertFalse(element(app, "scan.capture").waitForExistence(timeout: 2), "a disabled Open Camera must do nothing")
    }

    // MARK: - Leaving the app mid-scan

    /// Backgrounded while analysing, for longer than the analysis takes. The scan must be dropped,
    /// not finished behind her back, and must start again from the camera when she returns.
    func testBackgroundingDuringAScanPausesItAndReturningRestarts() {
        let app = openScanHome("slowReading")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))

        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 10)
        XCTAssertTrue(element(app, "scan.paused").waitForExistence(timeout: 5), "going to the background must pause the scan")
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(element(app, "scan.result").exists, "the analysis must not finish while she is away")

        app.activate()
        XCTAssertFalse(element(app, "scan.result").exists, "returning must restart the scan, not reveal a result made in the background")
        XCTAssertTrue(element(app, "scan.result.value").waitForExistence(timeout: 20), "the restarted scan must finish")
        XCTAssertFalse(element(app, "scan.paused").exists)
        XCTAssertFalse(element(app, "scan.result.saved").exists, "nothing was saved meanwhile")
    }
}
