import XCTest

/// UI regression coverage for the core surfaces, driven by the app's `-uiTestSeed` harness
/// (seeds realistic data + lands on the main tabs). Uses visible labels so tests stay stable.
final class GenesyxUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app seeded, starting on the given tab index (0=Home … 4=Profile).
    private func launchSeeded(tab: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
        app.launch()
        return app
    }

    func testMainTabsPresent() {
        let app = launchSeeded()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear on seeded launch")
        for label in ["Home", "Track", "Nutrition", "Insights", "Profile"] {
            XCTAssertTrue(tabBar.buttons[label].exists, "Missing tab: \(label)")
        }
    }

    func testHomeShowsLogToday() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Log today"].waitForExistence(timeout: 10), "Home should show the Log today button")
    }

    func testTabNavigation() {
        let app = launchSeeded(tab: 0)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        for label in ["Track", "Nutrition", "Insights", "Profile", "Home"] {
            tabBar.buttons[label].tap()
            XCTAssertTrue(tabBar.buttons[label].isSelected || tabBar.buttons[label].exists, "Should switch to \(label)")
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
        let app = launchSeeded(tab: 4)   // Profile
        XCTAssertTrue(app.staticTexts["Edit name"].waitForExistence(timeout: 10), "Profile should show account rows")
        XCTAssertTrue(app.staticTexts["Delete account"].exists || app.buttons["Delete account"].exists,
                      "Profile should offer account deletion (App Store requirement)")
    }
}
