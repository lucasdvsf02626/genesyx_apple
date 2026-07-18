import XCTest

/// Journey 8 — lifecycle & interruptions, with a focus on the release-critical citation screens.
/// The citation content is sourced from the bundled `medical_sources.json`, so it must survive
/// background→foreground, terminate→relaunch, and the sign-out local-data wipe without blanking.
final class LifecycleE2ETests: XCTestCase {

    override func setUp() { super.setUp(); continueAfterFailure = false }

    private func launch(tab: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
        app.launch()
        return app
    }

    /// Background → foreground keeps the citation screen intact.
    func testBackgroundForegroundKeepsCitations() {
        let app = launch(tab: 2)
        XCTAssertTrue(app.buttons["citation.efsa-water"].waitForExistence(timeout: 15))
        XCUIDevice.shared.press(.home)
        // Best-effort background wait: the iPad simulator can skip straight past .runningBackground,
        // so we don't hard-assert the transition — the meaningful check is that the screen survives
        // re-activation intact.
        _ = app.wait(for: .runningBackground, timeout: 10)
        app.activate()
        XCTAssertTrue(app.buttons["citation.efsa-water"].waitForExistence(timeout: 15),
                      "Citation should survive background→foreground")
    }

    /// Terminate → relaunch re-renders the Medical Sources screen (no blank view).
    func testRelaunchRerendersMedicalSources() {
        let app = launch(tab: 5)
        let row = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10))
        app.terminate()

        let app2 = launch(tab: 5)
        let row2 = app2.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row2.waitForExistence(timeout: 15))
        row2.tap()
        XCTAssertTrue(app2.buttons["medSource.nhs-water"].waitForExistence(timeout: 10),
                      "Medical Sources must re-render after relaunch (no blank screen)")
    }

    /// The privacy data-wipe (sign-out clears local health data) must NOT blank the citation
    /// screens — sources are bundle-sourced, not user data.
    func testSignOutDoesNotBlankMedicalSources() {
        let app = launch(tab: 5)
        let logout = app.buttons["Log out"]
        XCTAssertTrue(logout.waitForExistence(timeout: 15))
        logout.tap()

        let row = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Medical Sources row should remain after sign-out")
        row.tap()
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10),
                      "Sources must still render after the sign-out data wipe")
    }
}
