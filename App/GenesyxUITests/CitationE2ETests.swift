import XCTest

/// Journey 9 — the Guideline 1.4.1 citation fix. Every screen with a health claim must carry a
/// tappable source; the pH screens must show a caveat and NO leftover dietary advice; the Medical
/// Sources screen must list all references. Driven by the `-uiTestSeed` harness (pH readings +
/// cycle data present, so the citation screens render with data).
final class CitationE2ETests: XCTestCase {

    override func setUp() { super.setUp(); continueAfterFailure = false }

    private func launch(tab: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
        app.launch()
        return app
    }

    /// Insights: the vaginal-pH card shows its cycle caveat, and no dietary advice anywhere.
    func testInsightsCitationsPresent() {
        let app = launch(tab: 3)
        XCTAssertTrue(app.buttons["Insights"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["phCaveat"].firstMatch.waitForExistence(timeout: 10), "Insights pH card should show the vaginal-pH caveat")
        assertNoDietaryAdvice(app)
    }

    /// Nutrition: water-goal EFSA citation + the expandable "Why hydration?" Sources footer.
    func testNutritionGoalAndWhyHydrationSources() {
        let app = launch(tab: 2)
        XCTAssertTrue(app.buttons["Nutrition"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["citation.efsa-water"].waitForExistence(timeout: 10), "Water goal should show an EFSA citation")

        let whyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Why hydration")).firstMatch
        XCTAssertTrue(whyButton.waitForExistence(timeout: 5))
        whyButton.tap()
        // Must expand the section — a regression here would navigate to the Track hydration sheet
        // instead (the card's tap-to-open winning over this button).
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "eight glasses")).firstMatch.waitForExistence(timeout: 5),
                      "Tapping 'Why hydration?' must expand the section, not navigate to Track (navigatedToTrack=\(app.navigationBars["Hydration"].exists))")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "source.")).firstMatch.waitForExistence(timeout: 5),
                      "Why-hydration should reveal a Sources footer")
        for id in ["source.armstrong-2012", "source.valtin-2002", "source.nhs-water"] {
            XCTAssertTrue(app.buttons[id].exists, "Why-hydration Sources footer missing \(id)")
        }
    }

    /// The one-time vaginal-pH migration notice fires on the first pH-section visit, and does not
    /// re-fire after it's dismissed. Opt into it with `-uiTestPhNotice YES` (seeds suppress it otherwise).
    func testOneTimeVaginalNoticeFiresOnceThenPersists() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "2", "-uiTestPhNotice", "YES"]
        app.launch()

        let gotIt = app.alerts.buttons["Got it"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 15), "one-time vaginal-pH notice should appear on first pH-section visit")
        gotIt.tap()

        // Leave the pH section and return — the notice must not re-fire (flag persisted).
        app.buttons.matching(identifier: "Home").firstMatch.tap()
        app.buttons.matching(identifier: "Nutrition").firstMatch.tap()
        XCTAssertFalse(app.alerts.buttons["Got it"].waitForExistence(timeout: 3), "notice must not re-fire after dismissal")
    }

    /// pH tracker: the vaginal-pH caveat is present, and NO leftover dietary-recommendation strings.
    func testPhTrackerCaveatAndNoDietaryAdvice() {
        let app = launch(tab: 2)
        XCTAssertTrue(app.staticTexts["phCaveat"].firstMatch.waitForExistence(timeout: 15))
        assertNoDietaryAdvice(app)
    }

    /// A Learn article (reached from the Nutrition articles list) ends with a Sources footer.
    func testLearnArticleHasSourcesFooter() {
        let app = launch(tab: 2)
        let article = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Eating with your cycle")).firstMatch
        XCTAssertTrue(article.waitForExistence(timeout: 15))
        article.tap()
        XCTAssertTrue(app.staticTexts["Sources"].waitForExistence(timeout: 10), "Article should end with a Sources footer")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "source.")).firstMatch.waitForExistence(timeout: 5),
                      "Article Sources footer should list tappable references")
    }

    /// Settings → Medical Sources & Disclaimer lists all 11 sources (first + last render) plus the disclaimer.
    func testMedicalSourcesScreenListsAllEleven() {
        let app = launch(tab: 5)
        let row = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10), "First source row should render")
        XCTAssertTrue(app.staticTexts["Medical Disclaimer"].exists, "Disclaimer section should be present")
        let last = app.buttons["medSource.nhs-vitamin-b"]
        var tries = 0
        while !last.exists && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(last.exists, "All 11 sources should render — last row reached after scrolling")
    }

    /// Regression guard: the Home "Check your pH" card is a navigational nudge — no health claim,
    /// therefore no citation, and none required.
    func testHomePhCardHasNoUncitedClaim() {
        let app = launch(tab: 0)
        // The card sets .accessibilityElement(children:.ignore), so it isn't exposed as a .button —
        // match the identifier on any element type.
        let card = app.descendants(matching: .any).matching(identifier: "home.phCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        // Guard: the card is a pure navigational nudge — its accessibility label carries no health
        // claim (only "Check your pH"). A future edit adding a claim here would change this label.
        // (An app-wide citation count is not used: the tab ZStack keeps other tabs' citations
        // queryable even while Home is active.)
        XCTAssertEqual(card.label, "Check your pH", "Home pH card must stay a navigational nudge, no health claim")
        assertNoDietaryAdvice(app)
    }

    /// Tapping a source leaves the app for the browser. URL validity is verified manually, not here.
    func testCitationTapOpensBrowser() {
        let app = launch(tab: 2)
        let efsa = app.buttons["citation.efsa-water"]
        XCTAssertTrue(efsa.waitForExistence(timeout: 15))
        efsa.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15) || app.wait(for: .runningBackground, timeout: 5),
                      "Tapping a source should open the browser")
    }

    /// No leftover pH dietary-recommendation strings. Uses fragments UNIQUE to the removed pH advice
    /// (generic food words like "leafy greens" legitimately appear in nutrition content, so they are
    /// not used here).
    private func assertNoDietaryAdvice(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for phrase in ["shift toward optimal", "reduce excess mineral water", "meal rhythm; consistency"] {
            let hits = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", phrase)).count
            XCTAssertEqual(hits, 0, "Removed pH dietary advice reappeared: '\(phrase)'", file: file, line: line)
        }
    }
}
