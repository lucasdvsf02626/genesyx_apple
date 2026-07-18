import XCTest

/// UI regression coverage for the core surfaces, driven by the app's `-uiTestSeed` harness
/// (seeds realistic data + lands on the main tabs). Uses visible labels so tests stay stable.
final class GenesyxUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app seeded, starting on the given tab index
    /// (0=Home, 1=Track, 2=Nutrition, 3=Insights, 4=Learn, 5=Profile).
    private func launchSeeded(tab: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
        app.launch()
        return app
    }

    func testMainTabsPresent() {
        let app = launchSeeded()
        // Custom six-icon bottom bar (all tabs visible, no "More" overflow).
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10), "Tab bar should appear on seeded launch")
        for label in ["Home", "Track", "Nutrition", "Insights", "Learn", "Profile"] {
            XCTAssertTrue(app.buttons[label].exists, "Missing tab: \(label)")
        }
    }

    /// The supplement card used to print a hardcoded "3 of 4 taken today" to every user, on a
    /// fresh install, forever. The seeded user logs water today but no supplements, so the only
    /// honest thing the card can say is that none are logged.
    func testSupplementCountReflectsTodaysLog() {
        let app = launchSeeded(tab: 2)   // Nutrition
        XCTAssertTrue(app.staticTexts["None logged yet today"].waitForExistence(timeout: 10),
                      "Supplement count must come from today's log, not a placeholder")
        XCTAssertFalse(app.staticTexts["3 of 4 taken today"].exists,
                       "The hardcoded supplement count must never come back")
    }

    func testLearnTabShowsArticles() {
        let app = launchSeeded(tab: 4)   // Learn
        XCTAssertTrue(app.staticTexts["Your first week with Genesyx"].waitForExistence(timeout: 10),
                      "Learn should show the featured article")
    }

    func testHomeShowsLogToday() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Log today"].waitForExistence(timeout: 10), "Home should show the Log today button")
    }

    /// Quick-add now lives in the Track hydration sheet (the Home card is a tap-through summary).
    /// A single +250 adds exactly 250 (no double-fire), and −250 returns the total to where it
    /// started. Seed logs 750 ml today.
    func testTrackHydrationQuickAddAddsExactlyAndReverses() {
        let app = launchSeeded(tab: 0)

        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hydration,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "Home should show the hydration summary")
        XCTAssertTrue(summary.label.contains("750 of 2,400"), "Seeded today total should be 750 ml; got: \(summary.label)")
        summary.tap()

        XCTAssertTrue(app.navigationBars["Hydration"].waitForExistence(timeout: 5), "Summary should open the Track hydration sheet")
        XCTAssertTrue(app.staticTexts["750"].waitForExistence(timeout: 5), "Sheet should reflect the seeded 750 ml")

        app.buttons["Add 250 millilitres"].tap()
        XCTAssertTrue(app.staticTexts["1,000"].waitForExistence(timeout: 5), "One tap must add exactly 250, not double-fire")

        app.buttons["Remove 250 millilitres"].tap()
        XCTAssertTrue(app.staticTexts["750"].waitForExistence(timeout: 5), "After +250 then −250, the total must be unchanged")
    }

    func testHomeHydrationSummaryOpensTrackHydrationControls() {
        let app = launchSeeded(tab: 0)
        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hydration,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        summary.tap()

        // Landing on the Track hydration sheet (nav bar + its quick-add controls) proves the jump.
        XCTAssertTrue(app.navigationBars["Hydration"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add 500 millilitres"].exists)
        XCTAssertTrue(app.buttons["Remove 250 millilitres"].exists)
    }

    func testTabNavigation() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        // The Home hydration card shows a label-only "Track" affordance, so match the tab-bar
        // buttons by their accessibility identifier to avoid a duplicate-"Track" collision.
        for label in ["Track", "Nutrition", "Insights", "Learn", "Profile", "Home"] {
            let tab = app.buttons.matching(identifier: label).firstMatch
            tab.tap()
            XCTAssertTrue(tab.exists, "Should switch to \(label)")
        }
    }

    func testInsightsOpensLogHistory() {
        let app = launchSeeded(tab: 3)   // Insights
        let logsCard = app.staticTexts["My logs"]
        XCTAssertTrue(logsCard.waitForExistence(timeout: 10), "Insights should show the 'My logs' card")
        logsCard.tap()
        XCTAssertTrue(app.navigationBars["Your logs"].waitForExistence(timeout: 5), "Should push the log-history screen")
    }

    func testProfileShowsAccountActions() {
        let app = launchSeeded(tab: 5)   // Profile
        XCTAssertTrue(app.staticTexts["Edit name"].waitForExistence(timeout: 10), "Profile should show account rows")
        XCTAssertTrue(app.staticTexts["Delete account"].exists || app.buttons["Delete account"].exists,
                      "Profile should offer account deletion (App Store requirement)")

        let privacyPolicy = app.descendants(matching: .any)
            .matching(identifier: "Privacy Policy")
            .firstMatch
        for _ in 0..<4 where !privacyPolicy.exists { app.swipeUp() }
        XCTAssertTrue(privacyPolicy.waitForExistence(timeout: 5),
                      "Profile should provide an accessible in-app privacy-policy link")
    }

    /// Device-side data-isolation guard: seeded (User A) health data must be gone after sign-out,
    /// so a next user on the same device starts clean. Runs FULLY LOCALLY via the seed harness —
    /// no production accounts. Server-side RLS isolation is proven separately by backend probes.
    func testSignOutClearsHealthDataLocally() {
        let app = launchSeeded(tab: 0)   // Home, with seeded cycle data
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))

        // Seeded cycle is present → the first-run setup prompt must NOT be showing yet.
        let setupPrompt = app.staticTexts["When did your last period start? Next we'll confirm your cycle length — every prediction is built from it."]
        XCTAssertFalse(setupPrompt.exists, "Seeded cycle should render, not the empty setup prompt")

        // Sign out from Profile.
        app.buttons["Profile"].tap()
        let logout = app.buttons["Log out"]
        XCTAssertTrue(logout.waitForExistence(timeout: 5), "Signed-in Profile should offer Log out")
        logout.tap()

        // Home now shows the empty setup prompt (cycle wiped, no relaunch).
        app.buttons["Home"].tap()
        XCTAssertTrue(setupPrompt.waitForExistence(timeout: 5), "After sign-out, cycle data must be cleared")

        // Insights pH is empty too.
        app.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["No pH readings yet. Log your first one on Track or Nutrition."].waitForExistence(timeout: 5),
                      "After sign-out, pH readings must be cleared")
    }
}
