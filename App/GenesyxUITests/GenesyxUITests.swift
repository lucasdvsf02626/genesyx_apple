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

    func testLearnTabShowsArticles() {
        let app = launchSeeded(tab: 4)   // Learn
        XCTAssertTrue(app.staticTexts["Your first week with Genesyx"].waitForExistence(timeout: 10),
                      "Learn should show the featured article")
    }

    func testHomeShowsLogToday() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Log today"].waitForExistence(timeout: 10), "Home should show the Log today button")
    }

    func testTabNavigation() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        for label in ["Track", "Nutrition", "Insights", "Learn", "Profile", "Home"] {
            app.buttons[label].tap()
            XCTAssertTrue(app.buttons[label].exists, "Should switch to \(label)")
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
    }

    /// Device-side data-isolation guard: seeded (User A) health data must be gone after sign-out,
    /// so a next user on the same device starts clean. Runs FULLY LOCALLY via the seed harness —
    /// no production accounts. Server-side RLS isolation is proven separately by backend probes.
    func testSignOutClearsHealthDataLocally() {
        let app = launchSeeded(tab: 0)   // Home, with seeded cycle data
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))

        // Seeded cycle is present → the first-run setup prompt must NOT be showing yet.
        let setupPrompt = app.staticTexts["When did your last period start? We'll map your cycle from there."]
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
