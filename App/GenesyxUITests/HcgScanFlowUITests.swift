import XCTest

/// The pregnancy test flow end to end, on the simulated camera: Scan home, the pregnancy test
/// screen, the camera cover, what the strip showed, an invalid test or an unreadable scan, saving,
/// manual entry and the saved results behind their control.
///
/// `-uiTestHcgScenario <value>` scripts what the strip shows; `-uiTestScanScenario <value>` scripts
/// the camera, as it does for the pH scan. What is under test is everything around that script:
/// that the two outcomes are presented alike, that an invalid or uncertain scan never shows
/// either, that nothing is saved unless she saves it, that saved results stay closed until asked
/// for, and that nothing on any of these screens speaks about her instead of the strip. The seeded
/// container holds no pregnancy test result unless `-uiTestHcgSeed YES` adds two typed-in ones.
final class HcgScanFlowUITests: XCTestCase {

    private static let detectedTitle = "Test line detected"
    private static let notDetectedTitle = "No test line detected"
    private static let resultNote = "The instructions that came with your test explain what this means. A GP, midwife, pharmacist or sexual health clinic can confirm a result."
    private static let indeterminateMessage = "This scan wasn't clear enough to record a result. Please repeat the test as its instructions describe. A GP, midwife, pharmacist or sexual health clinic can also help."
    private static let seed = ["-uiTestHcgSeed", "YES"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// The one place that knows where the pregnancy test screen lives. A fresh launch opens on
    /// More with Scan home pushed; the third card is then tapped. `TEST_RUNNER_SCAN_THEME=dark`
    /// runs the whole class in dark mode, for the screenshots.
    @discardableResult
    private func openHcgHome(_ scenario: String = "notDetected", camera: String? = nil, extra: [String] = [],
                             file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "6", "-uiTestMore", "scan", "-uiTestHcgScenario", scenario]
        if let camera { app.launchArguments += ["-uiTestScanScenario", camera] }
        if let theme = ProcessInfo.processInfo.environment["SCAN_THEME"] { app.launchArguments += ["-uiTestTheme", theme] }
        app.launchArguments += extra
        app.launch()
        openCard(app, file: file, line: line)
        return app
    }

    private func openCard(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(app, "scan.home.hcgCard").waitForExistence(timeout: 15),
                      "Scan home must be showing, with the third card", file: file, line: line)
        element(app, "scan.home.hcgCard").tap()
        XCTAssertTrue(element(app, "hcg.home").waitForExistence(timeout: 10),
                      "the third card must open the pregnancy test screen", file: file, line: line)
    }

    /// Several identifiers sit on text or on containers, so the element type is not assumed.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reach(_ app: XCUIApplication, _ identifier: String, up: Bool = true) -> XCUIElement {
        let target = element(app, identifier)
        for _ in 0..<6 where target.exists && !target.isHittable { up ? app.swipeUp() : app.swipeDown() }
        return target
    }

    private func openCamera(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        reach(app, "hcg.openCamera", up: false).tap()
        XCTAssertTrue(element(app, "hcg.capture").waitForExistence(timeout: 10),
                      "Open Camera must raise the pregnancy test scan cover", file: file, line: line)
    }

    /// Cancel on the cover, back to the pregnancy test screen.
    private func cancelCover(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        element(app, "scan.capture.cancel").tap()
        XCTAssertTrue(element(app, "hcg.openCamera").waitForExistence(timeout: 10),
                      "Cancel returns to the pregnancy test screen", file: file, line: line)
        XCTAssertFalse(element(app, "hcg.capture").exists, "the cover must be gone", file: file, line: line)
    }

    private func openHistory(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = reach(app, "hcg.history.toggle")
        XCTAssertEqual(toggle.label, "Show saved results", "saved results must be closed until asked for", file: file, line: line)
        toggle.tap()
        XCTAssertTrue(element(app, "hcg.history").waitForExistence(timeout: 5), file: file, line: line)
    }

    private func row(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        reach(app, "hcg.history.row.\(index)")
    }

    private func rowCount(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'hcg.history.row.'")).count
    }

    /// True when anything inside the scan cover (or, with `container`, another screen) carries
    /// `text` in its label. Scoped, because the screens under a cover and the other tabs stay in
    /// the element tree.
    private func shows(_ app: XCUIApplication, _ text: String, in container: String = "hcg.capture") -> Bool {
        element(app, container).descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch.exists
    }

    /// Every label, title and string value under `root`, read in one snapshot.
    private func texts(in root: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> [String] {
        guard let snapshot = try? root.snapshot() else {
            XCTFail("no snapshot of \(root)", file: file, line: line)
            return []
        }
        var found: [String] = []
        func walk(_ node: XCUIElementSnapshot) {
            found += [node.label, node.title, node.value as? String ?? ""].filter { !$0.isEmpty }
            node.children.forEach(walk)
        }
        walk(snapshot)
        return found
    }

    /// The words these screens must never use. A literal on purpose: shortening it is a
    /// compliance decision. The four approved strings that carry the product name pass whole.
    private func assertNoBannedText(in root: XCUIElement, _ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let approved: Set<String> = ["pregnancy test", "scan pregnancy test",
                                     "delete all pregnancy test results", "delete all pregnancy test results?"]
        let stems = ["pregnan", "congratulat", "baby", "due date", "miscarr", "unfortunately", "sorry",
                     "positive", "negative", "expecting", "celebrat", "week", "hcg",
                     "thrush", "infection", "candida", "vaginosis", "diagnos", "guaranteed", "infertil",
                     "conceive", "conception", "gender", "sex selection"]
        let words: Set<String> = ["boy", "girl"]
        let found = texts(in: root, file: file, line: line)
        XCTAssertFalse(found.isEmpty, "\(screen): a sweep that reads nothing proves nothing", file: file, line: line)
        for text in found.map({ $0.lowercased() }) where !approved.contains(text) {
            for stem in stems where text.contains(stem) {
                XCTFail("\(screen): \"\(text)\" contains the banned \"\(stem)\"", file: file, line: line)
            }
            for word in text.components(separatedBy: CharacterSet.alphanumerics.inverted) where words.contains(word) {
                XCTFail("\(screen): \"\(text)\" contains the banned word \"\(word)\"", file: file, line: line)
            }
        }
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

    // MARK: - Scan home and the pregnancy test screen

    func testTheThirdCardOpensTheScreenWithFiveStepsThreeNotesAndSavedResultsClosed() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "6", "-uiTestMore", "scan"] + Self.seed
        if let theme = ProcessInfo.processInfo.environment["SCAN_THEME"] { app.launchArguments += ["-uiTestTheme", theme] }
        app.launch()
        XCTAssertTrue(element(app, "scan.home.hcgCard").waitForExistence(timeout: 15))
        for card in ["scan.home.phCard", "scan.home.lhCard", "scan.home.hcgCard"] {
            XCTAssertTrue(element(app, card).isHittable, "\(card) must be on Scan home")
        }
        XCTAssertFalse(shows(app, "test line", in: "scan.home"), "Scan home says nothing about a saved result")
        snap("hcg-01-scan-home-three-cards")

        openCard(app)
        XCTAssertTrue(app.navigationBars["Pregnancy Test"].exists)
        for step in 1...5 {
            XCTAssertTrue(element(app, "hcg.instructions.step.\(step)").exists, "instruction step \(step) is missing")
        }
        XCTAssertFalse(element(app, "hcg.instructions.step.6").exists, "there are five steps")
        XCTAssertTrue(element(app, "hcg.aboutNote").exists)
        XCTAssertTrue(element(app, "hcg.privacyNote").exists)
        XCTAssertTrue(element(app, "hcg.storageNote").label.contains("on this phone only"), "she must be told where results live")
        XCTAssertTrue(element(app, "hcg.storageNote").label.contains("removed when you sign out"))
        XCTAssertTrue(element(app, "hcg.openCamera").isEnabled)
        XCTAssertTrue(element(app, "hcg.enterManually").isEnabled)
        XCTAssertFalse(element(app, "consent.blocked").exists, "no consent banner while consent stands")
        XCTAssertFalse(element(app, "hcg.capture").exists, "opening the screen must not open the camera")
        snap("hcg-02-pregnancy-test-screen")

        // Two results are saved, and nothing on the screen says so until she asks.
        let toggle = reach(app, "hcg.history.toggle")
        XCTAssertEqual(toggle.label, "Show saved results")
        XCTAssertFalse(element(app, "hcg.history").exists)
        XCTAssertEqual(rowCount(app), 0, "no saved result is in the tree while the list is closed")
        XCTAssertFalse(element(app, "hcg.history.empty").exists)
        XCTAssertFalse(shows(app, "test line detected", in: "hcg.home"), "no outcome is on screen while the list is closed")
        XCTAssertFalse(shows(app, "2", in: "hcg.history.toggle"), "no count while closed")
        snap("hcg-02b-saved-results-closed")

        toggle.tap()
        XCTAssertTrue(element(app, "hcg.history").waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.label, "Hide saved results")
        XCTAssertEqual(rowCount(app), 2)
        XCTAssertTrue(row(app, 0).label.hasPrefix(Self.detectedTitle + ", "), row(app, 0).label)
        XCTAssertTrue(row(app, 0).label.hasSuffix("Entered manually"), row(app, 0).label)
        XCTAssertTrue(row(app, 1).label.hasPrefix(Self.notDetectedTitle + ", "), row(app, 1).label)
        XCTAssertTrue(reach(app, "hcg.history.deleteAll").exists)
        snap("hcg-10-saved-results-open")

        reach(app, "hcg.history.toggle", up: false).tap()
        XCTAssertFalse(element(app, "hcg.history").waitForExistence(timeout: 2), "the control closes the list again")
        XCTAssertEqual(rowCount(app), 0)
    }

    func testWithNoResultsTheOpenedListSaysSoAndOffersNoDeleteAll() {
        let app = openHcgHome()
        XCTAssertFalse(element(app, "hcg.history.empty").exists, "not even the empty line while closed")
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists)
        XCTAssertEqual(rowCount(app), 0)
        XCTAssertFalse(element(app, "hcg.history.deleteAll").exists)
    }

    // MARK: - The two outcomes

    /// Scan, read, save and find the result behind the control. Returns what the result screen
    /// was made of, without its title, so the two outcomes can be compared.
    private func scanSaveAndList(_ scenario: String, title: String, body: String, shot: String) -> [String] {
        let app = openHcgHome(scenario)
        reach(app, "hcg.openCamera", up: false).tap()
        if scenario == "detected" {
            // The live camera lasts about two seconds on this script and XCUITest waits for the
            // spinner to settle before it answers a query, so it is photographed blind.
            Thread.sleep(forTimeInterval: 0.6)
            snap("hcg-03-camera-wide-guide")
        }

        let heading = element(app, "hcg.result.title")
        XCTAssertTrue(heading.waitForExistence(timeout: 15), "a confident scan must end in a result")
        XCTAssertEqual(heading.label, "\(title), \(body)", "the result is words, read as one element, exactly as written")
        XCTAssertEqual(element(app, "hcg.result.note").label, Self.resultNote)
        XCTAssertEqual(element(app, "hcg.result.disclaimer").label, "Genesyx records what the test strip shows. This isn't medical advice.")
        XCTAssertTrue(element(app, "scan.debug.simulatedBanner").exists, "a scripted result must say that it is one")
        XCTAssertFalse(element(app, "scan.debug.saveBlocked").exists, "no backend here, so saving is allowed")
        XCTAssertFalse(element(app, "hcg.result.saved").exists, "nothing is saved until she saves it")
        XCTAssertTrue(element(app, "hcg.result.save").isEnabled)
        XCTAssertTrue(element(app, "hcg.scanAgain").exists)
        assertNoBannedText(in: element(app, "hcg.capture"), "result \(scenario)")
        snap(shot)

        var signature: [String] = []
        if let snapshot = try? element(app, "hcg.result").snapshot() {
            func walk(_ node: XCUIElementSnapshot) {
                // The title element and the two lines it is made of are the words: left out.
                guard node.identifier != "hcg.result.title" else { return signature.append("(title)") }
                guard node.label != title, node.label != body else { return signature.append("(words)") }
                signature.append("\(node.elementType.rawValue)|\(node.identifier)|\(node.label)|\(node.isEnabled)|\(node.isSelected)")
                node.children.forEach(walk)
            }
            walk(snapshot)
        }
        XCTAssertGreaterThan(signature.count, 5, "the result screen was not read")
        XCTAssertEqual(element(app, "hcg.result").images.count, 0, "the symbol is decoration: hidden from VoiceOver for both outcomes")

        element(app, "hcg.result.save").tap()
        XCTAssertTrue(element(app, "hcg.result.saved").waitForExistence(timeout: 10), "Save must confirm")
        XCTAssertEqual(element(app, "hcg.result.saved").label, "Result saved", "the confirmation names no outcome")
        XCTAssertFalse(element(app, "hcg.result.save").exists, "a saved result offers no second Save")
        XCTAssertFalse(element(app, "scan.capture.cancel").exists, "Cancel after a save would read as undoing it")
        if scenario == "detected" { snap("hcg-04b-result-saved") }

        element(app, "hcg.result.done").tap()
        XCTAssertTrue(element(app, "hcg.openCamera").waitForExistence(timeout: 10), "Done returns to the pregnancy test screen")
        XCTAssertFalse(element(app, "hcg.capture").exists, "the cover must be gone")
        XCTAssertEqual(rowCount(app), 0, "back on the screen the saved results are closed")
        XCTAssertFalse(shows(app, "test line detected", in: "hcg.home"), "and the outcome is nowhere on it")

        openHistory(app)
        XCTAssertEqual(rowCount(app), 1)
        XCTAssertTrue(row(app, 0).label.hasPrefix(title + ", "), row(app, 0).label)
        XCTAssertTrue(row(app, 0).label.hasSuffix("Scanned"), "a scanned result is listed as scanned: \(row(app, 0).label)")
        app.terminate()
        return signature
    }

    /// Both outcomes in one test, so they can be laid side by side: the same note, disclaimer,
    /// banner, buttons and hidden symbol, in the same order. Only the title element differs.
    func testBothOutcomesAreShownSavedAndListedAndDifferOnlyInTheirWords() {
        let detected = scanSaveAndList(
            "detected", title: Self.detectedTitle,
            body: "A line was detected in the test line area of this strip.", shot: "hcg-04-result-test-line-detected")
        let notDetected = scanSaveAndList(
            "notDetected", title: Self.notDetectedTitle,
            body: "No line was detected in the test line area of this strip.", shot: "hcg-05-result-no-test-line-detected")
        XCTAssertEqual(detected, notDetected, "apart from the title, the two result screens must be the same screen")
    }

    /// The fix for a fault found in the pH and LH covers: after Save and Scan Again the new scan
    /// had no Cancel. On the slow script, so the second scan is still analysing when looked at.
    func testScanAgainAfterSavingStartsUnsavedAndCanBeCancelled() {
        let app = openHcgHome("detected", camera: "slowReading")
        openCamera(app)
        XCTAssertTrue(element(app, "hcg.result.title").waitForExistence(timeout: 15))
        element(app, "hcg.result.save").tap()
        XCTAssertTrue(element(app, "hcg.result.saved").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "scan.capture.cancel").exists)

        element(app, "hcg.scanAgain").tap()
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10),
                      "Scan Again must go back through the camera, not redraw the old result")
        XCTAssertFalse(element(app, "hcg.result").exists)
        XCTAssertTrue(element(app, "scan.capture.cancel").exists, "a new scan must be cancellable")
        cancelCover(app)
        Thread.sleep(forTimeInterval: 4)
        openHistory(app)
        XCTAssertEqual(rowCount(app), 1, "only the result she saved: the cancelled second scan saved nothing")
    }

    // MARK: - A faint line: unreadable, never an outcome

    func testAFaintLineIsUnreadableWithItsOwnMessageAndIsNeverAnOutcome() {
        let app = openHcgHome("faintLine")
        openCamera(app)

        XCTAssertTrue(element(app, "hcg.unreadable").waitForExistence(timeout: 15), "a faint line is not a result")
        XCTAssertEqual(element(app, "hcg.unreadable.reason").label, Self.indeterminateMessage)
        XCTAssertFalse(shows(app, "test line detected"), "neither outcome may appear for a faint line")
        for identifier in ["hcg.result", "hcg.result.title", "hcg.result.save", "hcg.invalid"] {
            XCTAssertFalse(element(app, identifier).exists, "a faint line has no \(identifier)")
        }
        XCTAssertTrue(element(app, "hcg.tryAgain").exists)
        XCTAssertTrue(element(app, "hcg.enterManually").exists)
        assertNoBannedText(in: element(app, "hcg.capture"), "indeterminate")
        snap("hcg-08-unreadable-not-clear-enough")

        cancelCover(app)
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists, "a faint line saves nothing")
    }

    // MARK: - Invalid: never an outcome, never saved

    private func assertInvalid(_ scenario: String, shot: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let app = openHcgHome(scenario, camera: "slowReading")
        openCamera(app)

        XCTAssertTrue(element(app, "hcg.invalid").waitForExistence(timeout: 15), "\(scenario) must end on the invalid screen", file: file, line: line)
        XCTAssertEqual(element(app, "hcg.invalid.title").label,
                       "Test invalid, We couldn't detect the control line, so this test can't be read. Please repeat the test with a new strip, following its instructions.",
                       file: file, line: line)
        for identifier in ["hcg.result", "hcg.result.save", "hcg.result.saved", "hcg.unreadable"] {
            XCTAssertFalse(element(app, identifier).exists, "an invalid test has no \(identifier)", file: file, line: line)
        }
        XCTAssertFalse(shows(app, "test line detected"), "an invalid test must never be given an outcome", file: file, line: line)
        XCTAssertTrue(element(app, "hcg.enterManually").exists, file: file, line: line)
        assertNoBannedText(in: element(app, "hcg.capture"), "invalid", file: file, line: line)
        if let shot { snap(shot) }

        element(app, "hcg.scanNewTest").tap()
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10),
                      "Scan New Test must go back through the camera", file: file, line: line)
        XCTAssertFalse(element(app, "hcg.invalid").exists, file: file, line: line)
        XCTAssertTrue(element(app, "hcg.invalid").waitForExistence(timeout: 15), "the same strip is invalid again", file: file, line: line)

        cancelCover(app, file: file, line: line)
        openHistory(app, file: file, line: line)
        XCTAssertTrue(element(app, "hcg.history.empty").exists, "an invalid scan saves nothing", file: file, line: line)
    }

    func testNoControlLineIsInvalidAndSavesNothing() {
        assertInvalid("invalidNoControl", shot: "hcg-06-invalid")
    }

    /// A strong test line with no control line: the case that must never read as detected.
    func testATestLineWithoutAControlLineIsInvalidNeverDetected() {
        assertInvalid("invalidTestLineOnly")
    }

    // MARK: - Unreadable: never an outcome

    private func assertUnreadable(_ scenario: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = openHcgHome(scenario)
        openCamera(app)

        XCTAssertTrue(element(app, "hcg.unreadable").waitForExistence(timeout: 15),
                      "a scan the analyser is unsure of is not a result", file: file, line: line)
        XCTAssertEqual(element(app, "hcg.unreadable.title").label,
                       "We couldn't read this test., Try scanning again in good, even lighting, or enter the result yourself.",
                       file: file, line: line)
        for identifier in ["hcg.result", "hcg.result.title", "hcg.result.save", "hcg.invalid"] {
            XCTAssertFalse(element(app, identifier).exists, "an unreadable scan has no \(identifier)", file: file, line: line)
        }
        for words in ["test line detected", "Test invalid"] {
            XCTAssertFalse(shows(app, words), "an unreadable scan must show no classification (\(words) is on screen)", file: file, line: line)
        }
        XCTAssertTrue(element(app, "hcg.tryAgain").exists, file: file, line: line)
        XCTAssertTrue(element(app, "hcg.enterManually").exists, file: file, line: line)
        return app
    }

    private func assertNothingSavedAfterCancel(_ app: XCUIApplication) {
        cancelCover(app)
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists, "an unreadable scan saves nothing")
    }

    func testALowConfidenceScanIsUnreadableAndSavesNothing() {
        let app = assertUnreadable("lowConfidence")
        XCTAssertFalse(element(app, "hcg.unreadable.reason").exists, "no reason the screen can name, so none is given")
        assertNoBannedText(in: element(app, "hcg.capture"), "unreadable")
        snap("hcg-07-unreadable")
        assertNothingSavedAfterCancel(app)
    }

    func testASignalOutOfRangeIsUnreadableNeverClamped() {
        assertNothingSavedAfterCancel(assertUnreadable("signalOutOfRange"))
    }

    func testGlareIsUnreadableWithItsInstructionAndBothWaysOn() {
        let app = assertUnreadable("unreadable-glare")
        XCTAssertEqual(element(app, "hcg.unreadable.reason").label, "Reduce glare")
        snap("hcg-07b-unreadable-glare")

        element(app, "hcg.tryAgain").tap()
        XCTAssertTrue(element(app, "hcg.unreadable").waitForExistence(timeout: 15), "the same strip is unreadable again")

        // The other way on: type it in. The sheet belongs to the screen, so the cover goes first.
        element(app, "hcg.enterManually").tap()
        XCTAssertTrue(element(app, "hcg.manual.save").waitForExistence(timeout: 10),
                      "Enter result manually must open the manual entry sheet")
        XCTAssertFalse(element(app, "hcg.capture").exists)
        element(app, "hcg.manual.cancel").tap()
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists, "nothing was saved on the way")
    }

    // MARK: - Camera states shared with the pH scan

    func testTooDarkShowsGuidanceOverAWideGuideAndNeverCaptures() {
        let app = openHcgHome("detected", camera: "issue-tooDark")
        openCamera(app)

        let guidance = app.staticTexts.matching(NSPredicate(format: "identifier == 'scan.capture.guidance' AND label == 'More light needed'")).firstMatch
        XCTAssertTrue(guidance.waitForExistence(timeout: 10), "the camera must say what to change")
        XCTAssertTrue(app.staticTexts["Scan Pregnancy Test"].exists)
        XCTAssertTrue(app.staticTexts["Simulated camera"].exists, "the preview must be showing, not obscured")
        assertNoBannedText(in: element(app, "hcg.capture"), "live camera")
        snap("hcg-03b-camera-too-dark")

        Thread.sleep(forTimeInterval: 4)
        XCTAssertTrue(guidance.exists, "four seconds on, it is still asking for light")
        for identifier in ["scan.analysing", "hcg.result", "hcg.invalid", "hcg.unreadable", "scan.capture.progress"] {
            XCTAssertFalse(element(app, identifier).exists, "a frame with a quality problem must never be captured (\(identifier))")
        }
        cancelCover(app)
    }

    func testPermissionDeniedOffersSettingsAndManualEntry() {
        let app = openHcgHome("detected", camera: "permissionDenied")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.permissionDenied").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "scan.openSettings").exists)
        XCTAssertTrue(element(app, "scan.enterManually").exists)
        XCTAssertFalse(element(app, "hcg.result").exists)
        assertNoBannedText(in: element(app, "hcg.capture"), "permission denied")
    }

    func testCameraUnavailableLeadsToManualEntry() {
        let app = openHcgHome("detected", camera: "cameraUnavailable")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.cameraUnavailable").waitForExistence(timeout: 10))
        element(app, "scan.tryAgain").tap()
        XCTAssertTrue(element(app, "scan.cameraUnavailable").waitForExistence(timeout: 10), "still no camera after Try Again")

        element(app, "scan.enterManually").tap()
        XCTAssertTrue(element(app, "hcg.manual.option.testLineDetected").waitForExistence(timeout: 10),
                      "Enter result manually must close the cover and open the pregnancy test sheet, not another one")
    }

    // MARK: - Manual entry

    /// Each of the three choices is saved and listed as typed in.
    func testEachManualChoiceIsSavedAndListedAsManual() {
        let app = openHcgHome()
        let options = ["testLineDetected", "noTestLineDetected", "invalid"]
        let choices = [("testLineDetected", Self.detectedTitle), ("noTestLineDetected", Self.notDetectedTitle), ("invalid", "Test invalid")]
        for (offset, choice) in choices.enumerated() {
            reach(app, "hcg.enterManually", up: false).tap()
            XCTAssertTrue(app.navigationBars["Enter your result"].waitForExistence(timeout: 10))
            XCTAssertFalse(element(app, "hcg.capture").exists, "typing a result in must not open the camera")

            for option in options {
                XCTAssertTrue(element(app, "hcg.manual.option.\(option)").exists)
                XCTAssertFalse(element(app, "hcg.manual.option.\(option)").isSelected, "nothing is chosen for her")
            }
            XCTAssertEqual(options.map { element(app, "hcg.manual.option.\($0)").label },
                           [Self.detectedTitle, Self.notDetectedTitle, "Invalid"])
            XCTAssertFalse(element(app, "hcg.manual.save").isEnabled, "no Save before a choice")
            if offset == 0 {
                assertNoBannedText(in: element(app, "hcg.manual"), "manual entry")
                snap("hcg-09-manual-entry-sheet")
            }

            element(app, "hcg.manual.option.\(choice.0)").tap()
            XCTAssertTrue(element(app, "hcg.manual.option.\(choice.0)").isSelected)
            if offset == 0 { snap("hcg-09b-manual-entry-chosen") }
            element(app, "hcg.manual.save").tap()

            XCTAssertTrue(element(app, "hcg.home.saved").waitForExistence(timeout: 10), "\(choice.0) must be confirmed after Save")
            XCTAssertEqual(element(app, "hcg.home.saved").label, "Result saved", "the confirmation names no outcome")
            XCTAssertFalse(app.navigationBars["Enter your result"].exists, "a saved entry closes the sheet")
            XCTAssertEqual(rowCount(app), 0, "the saved results stay closed")
            if offset == 0 { snap("hcg-09c-manual-entry-saved") }

            openHistory(app)
            XCTAssertEqual(rowCount(app), offset + 1)
            XCTAssertTrue(row(app, 0).label.hasPrefix(choice.1 + ", "), row(app, 0).label)
            XCTAssertTrue(row(app, 0).label.hasSuffix("Entered manually"), row(app, 0).label)
        }
    }

    func testCancellingManualEntrySavesNothing() {
        let app = openHcgHome()
        element(app, "hcg.enterManually").tap()
        XCTAssertTrue(app.navigationBars["Enter your result"].waitForExistence(timeout: 10))
        element(app, "hcg.manual.option.testLineDetected").tap()
        element(app, "hcg.manual.cancel").tap()
        XCTAssertTrue(element(app, "hcg.openCamera").waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Enter your result"].exists)
        XCTAssertFalse(element(app, "hcg.home.saved").exists)
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists)
    }

    // MARK: - Delete, delete all, relaunch

    func testDeletingAResultAsksFirstAndThenRemovesIt() {
        let app = openHcgHome(extra: Self.seed)
        openHistory(app)
        XCTAssertEqual(rowCount(app), 2)
        let delete = app.alerts.buttons["Delete this result"].firstMatch

        // Asked, and answered no: nothing goes.
        row(app, 0).tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "deleting must ask first")
        XCTAssertTrue(app.alerts["Delete this result?"].exists)
        XCTAssertEqual(rowCount(app), 2, "nothing is deleted until she confirms")
        assertNoBannedText(in: app.alerts.firstMatch, "delete confirmation")
        snap("hcg-11-delete-confirmation")
        app.alerts.buttons["Cancel"].firstMatch.tap()
        XCTAssertFalse(delete.waitForExistence(timeout: 2))
        XCTAssertEqual(rowCount(app), 2)

        row(app, 0).tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.tap()
        XCTAssertTrue(element(app, "hcg.history.row.0").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 1, "the confirmed result is gone and the other stays")
        XCTAssertTrue(row(app, 0).label.hasPrefix(Self.notDetectedTitle + ", "), "the newer one was deleted: \(row(app, 0).label)")
    }

    private func relaunchKeepingTheStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["-uiTestSeed", "YES", "-uiTestKeepStore", "YES", "-uiTestTab", "6", "-uiTestMore", "scan"]
        app.launch()
        openCard(app)
        return app
    }

    func testDeleteAllAsksFirstLeavesNothingAndStaysEmptyAfterARelaunch() {
        let app = openHcgHome(extra: Self.seed)
        openHistory(app)
        let confirm = app.alerts.buttons["Delete all"].firstMatch

        reach(app, "hcg.history.deleteAll").tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "deleting everything must ask first")
        XCTAssertTrue(app.alerts["Delete all pregnancy test results?"].exists)
        XCTAssertTrue(app.alerts.staticTexts["This removes every saved result from this phone. It can't be undone."].exists)
        assertNoBannedText(in: app.alerts.firstMatch, "delete all confirmation")
        snap("hcg-12-delete-all-confirmation")
        app.alerts.buttons["Cancel"].firstMatch.tap()
        XCTAssertFalse(confirm.waitForExistence(timeout: 2))
        XCTAssertEqual(rowCount(app), 2, "Cancel keeps both")

        reach(app, "hcg.history.deleteAll").tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()
        XCTAssertTrue(element(app, "hcg.history.empty").waitForExistence(timeout: 10), "nothing is left")
        XCTAssertEqual(rowCount(app), 0)
        XCTAssertFalse(element(app, "hcg.history.deleteAll").exists)
        snap("hcg-12b-after-delete-all")

        let relaunched = relaunchKeepingTheStore()
        openHistory(relaunched)
        XCTAssertTrue(element(relaunched, "hcg.history.empty").exists, "deleted results must not come back")
    }

    func testASavedResultIsStillListedAfterARelaunch() {
        let app = openHcgHome()
        element(app, "hcg.enterManually").tap()
        element(app, "hcg.manual.option.noTestLineDetected").tap()
        element(app, "hcg.manual.save").tap()
        XCTAssertTrue(element(app, "hcg.home.saved").waitForExistence(timeout: 10))

        let relaunched = relaunchKeepingTheStore()
        XCTAssertFalse(element(relaunched, "hcg.home.saved").exists)
        openHistory(relaunched)
        XCTAssertEqual(rowCount(relaunched), 1)
        XCTAssertTrue(row(relaunched, 0).label.hasPrefix(Self.notDetectedTitle + ", "), row(relaunched, 0).label)
    }

    // MARK: - Cancel and consent

    func testCancellingDuringAnalysisSavesNothing() {
        let app = openHcgHome("detected", camera: "slowReading")
        openCamera(app)

        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))
        cancelCover(app)
        // Longer than the three-second analysis: a result arriving late must go nowhere.
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(element(app, "hcg.result").exists)
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists, "a cancelled scan saves nothing")
    }

    func testCancellingAResultWithoutSavingSavesNothing() {
        let app = openHcgHome("detected")
        openCamera(app)
        XCTAssertTrue(element(app, "hcg.result.title").waitForExistence(timeout: 15))
        cancelCover(app)
        openHistory(app)
        XCTAssertTrue(element(app, "hcg.history.empty").exists, "a result she did not save is not kept")
    }

    /// With consent withdrawn the flow stops before any image is taken and nothing can be typed
    /// in; what she already recorded can still be listed and deleted, one or all.
    func testWithdrawnConsentBlocksTheCameraAndManualEntryButNotDeleting() {
        let app = openHcgHome(extra: Self.seed + ["-uiTestConsentWithdrawn", "YES"])
        XCTAssertTrue(element(app, "consent.blocked").exists, "the screen must say why recording is off")

        let open = reach(app, "hcg.openCamera")
        XCTAssertFalse(open.isEnabled, "no scan without consent")
        XCTAssertFalse(element(app, "hcg.enterManually").isEnabled, "no manual result without consent")
        snap("hcg-13-consent-withdrawn")
        open.tap()
        XCTAssertFalse(element(app, "hcg.capture").waitForExistence(timeout: 2), "a disabled Open Camera must do nothing")
        element(app, "hcg.enterManually").tap()
        XCTAssertFalse(app.navigationBars["Enter your result"].waitForExistence(timeout: 2), "a disabled manual entry must do nothing")

        openHistory(app)
        XCTAssertEqual(rowCount(app), 2, "what she recorded before can still be listed")
        row(app, 0).tap()
        let delete = app.alerts.buttons["Delete this result"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "deleting stays available after a withdrawal")
        delete.tap()
        XCTAssertTrue(element(app, "hcg.history.row.0").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 1)

        reach(app, "hcg.history.deleteAll").tap()
        let confirm = app.alerts.buttons["Delete all"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "so does deleting everything")
        confirm.tap()
        XCTAssertTrue(element(app, "hcg.history.empty").waitForExistence(timeout: 10))
    }

    // MARK: - Leaving the app

    /// Backgrounded while analysing, for longer than the analysis takes. The scan must be dropped,
    /// not finished behind her back, and must start again from the camera when she returns: four
    /// seconds of a three-second analysis leave no result. This is also the proof that the scene
    /// phase reaches a cover raised two pushes deep.
    func testBackgroundingDuringAScanDropsItAndReturningRestarts() {
        let app = openHcgHome("detected", camera: "slowReading")
        openCamera(app)
        XCTAssertTrue(element(app, "scan.analysing").waitForExistence(timeout: 10))

        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 10)
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(element(app, "hcg.result").exists, "the analysis must not finish while she is away")

        app.activate()
        XCTAssertTrue(element(app, "scan.capture.cancel").waitForExistence(timeout: 5), "the cover comes back")
        XCTAssertFalse(element(app, "hcg.result").exists, "returning must restart the scan, not reveal a result made in the background")
        XCTAssertTrue(element(app, "hcg.result.title").waitForExistence(timeout: 20), "the restarted scan must finish")
        XCTAssertFalse(element(app, "scan.paused").exists)
        XCTAssertFalse(element(app, "hcg.result.saved").exists, "nothing was saved meanwhile")
    }

    /// The privacy cover over a result: gone from the accessibility tree while the app is away,
    /// back and still unsaved on return.
    func testAResultIsHiddenWhileTheAppIsAwayAndIsStillThereUnsavedOnReturn() {
        let app = openHcgHome("detected")
        openCamera(app)
        let title = element(app, "hcg.result.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))

        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 10)
        XCTAssertFalse(title.exists, "a result must be hidden while the app is not active")
        XCTAssertFalse(shows(app, "test line detected", in: "hcg.capture"))

        app.activate()
        XCTAssertTrue(title.waitForExistence(timeout: 10), "the result is still there on return")
        XCTAssertTrue(title.label.hasPrefix(Self.detectedTitle))
        XCTAssertFalse(element(app, "hcg.result.saved").exists)
        XCTAssertTrue(element(app, "hcg.result.save").isEnabled)
    }

    /// The app switcher, as far as a simulator shows it. The cover is one flat colour, so the
    /// middle of the app's card must be: a result, a list or a sheet showing through is not.
    func testAResultIsHiddenInTheAppSwitcher() {
        let app = openHcgHome("detected")
        openCamera(app)
        let title = element(app, "hcg.result.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))

        snapInAppSwitcher("hcg-14-app-switcher-result-covered")

        app.activate()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
    }

    /// The same look at the screen with its saved results open, and at the manual entry sheet.
    func testTheScreenAndTheSheetAreHiddenInTheAppSwitcher() {
        let app = openHcgHome(extra: Self.seed)
        openHistory(app)
        snapInAppSwitcher("hcg-14b-app-switcher-saved-results-covered")
        app.activate()

        reach(app, "hcg.enterManually", up: false).tap()
        let option = element(app, "hcg.manual.option.testLineDetected")
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        snapInAppSwitcher("hcg-14c-app-switcher-manual-sheet-covered")
        app.activate()
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        XCTAssertTrue(option.isSelected, "an overlay, so her choice is kept")
    }

    private func snapInAppSwitcher(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.999))
        let middle = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        bottom.press(forDuration: 0.1, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 1.5)
        Thread.sleep(forTimeInterval: 1)
        snap(name)

        // The middle of the screen lies well inside the app's card.
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { return XCTFail("no screenshot", file: file, line: line) }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        var lowest = [UInt8](repeating: 255, count: 3), highest = [UInt8](repeating: 0, count: 3)
        for y in stride(from: image.height * 3 / 10, to: image.height * 7 / 10, by: 4) {
            for x in stride(from: image.width * 3 / 10, to: image.width * 7 / 10, by: 4) {
                for channel in 0..<3 {
                    let value = pixels[(y * image.width + x) * 4 + channel]
                    lowest[channel] = min(lowest[channel], value)
                    highest[channel] = max(highest[channel], value)
                }
            }
        }
        let spread = (0..<3).map { Int(highest[$0]) - Int(lowest[$0]) }.max() ?? 255
        XCTAssertLessThan(spread, 8, "\(name): something shows through the privacy cover in the app switcher", file: file, line: line)
    }

    /// The screen itself: hidden while away, and the saved results closed again on return. The
    /// navigation bar is still read in the background, which shows the query itself works there.
    func testSavedResultsAreHiddenWhileAwayAndClosedOnReturn() {
        let app = openHcgHome(extra: Self.seed)
        openHistory(app)
        XCTAssertEqual(rowCount(app), 2)

        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 10)
        XCTAssertTrue(app.navigationBars["Pregnancy Test"].exists, "the app can still be read in the background")
        XCTAssertFalse(element(app, "hcg.home").exists, "the screen is hidden while the app is not active")
        XCTAssertEqual(rowCount(app), 0)

        app.activate()
        XCTAssertTrue(element(app, "hcg.home").waitForExistence(timeout: 10))
        XCTAssertEqual(rowCount(app), 0, "the saved results are closed again on return")
        XCTAssertFalse(element(app, "hcg.history").exists)
        XCTAssertEqual(reach(app, "hcg.history.toggle").label, "Show saved results")
    }

    /// The manual entry sheet keeps her choice under the cover. That the sheet is covered is shown
    /// in the app switcher test: XCUITest still reads a covered sheet's elements.
    func testTheManualSheetKeepsItsChoiceWhileAway() {
        let app = openHcgHome()
        element(app, "hcg.enterManually").tap()
        let option = element(app, "hcg.manual.option.testLineDetected")
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()

        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: 10)

        app.activate()
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        XCTAssertTrue(option.isSelected, "an overlay, so her choice is kept")
    }

    // MARK: - Words

    /// The screen with the list closed and open. The other screens are swept where they are
    /// reached: the camera, both outcomes, invalid, unreadable, the faint line, the manual sheet
    /// and both confirmations each call `assertNoBannedText` in their own test.
    func testThePregnancyTestScreenUsesNoBannedWordClosedOrOpen() {
        let app = openHcgHome(extra: Self.seed)
        assertNoBannedText(in: element(app, "hcg.home"), "screen, list closed")
        XCTAssertTrue(app.navigationBars["Pregnancy Test"].exists, "the bar carries the approved product name only")
        openHistory(app)
        assertNoBannedText(in: element(app, "hcg.home"), "screen, list open")
    }

    // MARK: - Nothing outside the Scan area

    /// A saved result is on Scan home, on no other tab and not in More's list.
    func testASavedResultAppearsNowhereOutsideThePregnancyTestScreen() {
        let app = openHcgHome("detected")
        openCamera(app)
        XCTAssertTrue(element(app, "hcg.result.title").waitForExistence(timeout: 15))
        element(app, "hcg.result.save").tap()
        XCTAssertTrue(element(app, "hcg.result.saved").waitForExistence(timeout: 10))
        element(app, "hcg.result.done").tap()
        XCTAssertTrue(element(app, "hcg.openCamera").waitForExistence(timeout: 10))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, "scan.home.hcgCard").waitForExistence(timeout: 10), "back from the screen is Scan home")
        XCTAssertFalse(shows(app, "test line", in: "scan.home"), "Scan home says nothing about a saved result")

        func assertNoTrace(_ place: String) {
            Thread.sleep(forTimeInterval: 1)
            let trace = texts(in: app).first { $0.lowercased().contains("test line detected") }
            XCTAssertNil(trace, "\(place) shows a pregnancy test result")
        }
        assertNoTrace("Scan home")
        for tab in ["Home", "Track", "pH", "Nutrition", "Insights", "Learn"] {
            let button = app.buttons.matching(identifier: tab).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(tab) tab is missing")
            button.tap()
            assertNoTrace(tab)
            if tab == "Home" { snap("hcg-15-home-after-a-saved-result") }
        }
        app.buttons.matching(identifier: "More").firstMatch.tap()
        for _ in 0..<3 where !element(app, "more.home").exists { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(element(app, "more.home").waitForExistence(timeout: 10), "More's list must be reachable")
        assertNoTrace("More")
        snap("hcg-15b-more-after-a-saved-result")
    }

    // MARK: - pH and LH beside it

    /// The pH card and the LH card from the same Scan home, each opening its own screen and cover.
    func testThePhAndLhCardsStillOpenTheirOwnFlows() {
        let app = openHcgHome("detected", camera: "reading-5.2")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, "scan.home.phCard").waitForExistence(timeout: 10), "back from the screen is Scan home")

        element(app, "scan.home.phCard").tap()
        XCTAssertTrue(element(app, "scan.openCamera").waitForExistence(timeout: 10), "the pH card must open the pH instructions")
        XCTAssertFalse(element(app, "hcg.home").exists)
        element(app, "scan.openCamera").tap()
        XCTAssertTrue(element(app, "scan.capture").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "hcg.capture").exists, "the pH card opens the pH cover")
        let value = element(app, "scan.result.value")
        XCTAssertTrue(value.waitForExistence(timeout: 15))
        XCTAssertEqual(value.label, "pH 5.2")
        XCTAssertFalse(shows(app, "test line detected", in: "scan.capture"), "a pH scan must not show a pregnancy test result")
        element(app, "scan.capture.cancel").tap()

        XCTAssertTrue(element(app, "scan.openCamera").waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, "scan.home.lhCard").waitForExistence(timeout: 10))
        element(app, "scan.home.lhCard").tap()
        XCTAssertTrue(element(app, "lh.home").waitForExistence(timeout: 10), "the LH card must open the LH screen")
        XCTAssertFalse(element(app, "hcg.home").exists)
        element(app, "lh.openCamera").tap()
        XCTAssertTrue(element(app, "lh.capture").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "lh.result.title").waitForExistence(timeout: 15), "the LH scan must finish in an LH result")
        XCTAssertFalse(element(app, "hcg.capture").exists)
        XCTAssertFalse(shows(app, "test line detected", in: "lh.capture"))
    }
}
