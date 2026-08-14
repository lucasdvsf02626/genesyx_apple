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

    /// iOS intermittently offers a system "Save Password?" sheet after a credential submission it
    /// judges to be a successful sign-in. It belongs to another process, so it never appears in the
    /// test log, and its backdrop swallows every touch — which surfaces as the app's own controls
    /// going unhittable rather than as an interruption. Declining it also keeps the simulator
    /// keychain empty, so a later run is not offered an AutoFill toolbar instead.
    private func dismissSystemSavePasswordSheet(_ app: XCUIApplication) {
        for root in [app, XCUIApplication(bundleIdentifier: "com.apple.springboard")] {
            let notNow = root.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 3) { notNow.tap(); return }
        }
    }

    /// Background → foreground keeps the citation screen intact.
    func testBackgroundForegroundKeepsCitations() {
        let app = launch(tab: 3)
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
        let app = launch(tab: 6)
        let row = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10))
        app.terminate()

        let app2 = launch(tab: 6)
        let row2 = app2.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row2.waitForExistence(timeout: 15))
        row2.tap()
        XCTAssertTrue(app2.buttons["medSource.nhs-water"].waitForExistence(timeout: 10),
                      "Medical Sources must re-render after relaunch (no blank screen)")
    }

    /// Sources are bundle-sourced, not user data — but a signed-out user must not read them
    /// from Profile. After re-authentication the same row still renders.
    func testSignOutDoesNotBlankMedicalSources() {
        let app = launch(tab: 6)
        let row = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        let logout = app.buttons["Log out"]
        XCTAssertTrue(logout.waitForExistence(timeout: 10))
        logout.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "auth.screen").firstMatch
                        .waitForExistence(timeout: 10),
                      "signed-out users must not keep Profile")
        XCTAssertFalse(app.buttons["Medical Sources & Disclaimer"].exists)
        XCTAssertFalse(app.buttons["Profile"].exists)

        // DEBUG local-only: mock auth accepts any 8+ character password.
        let email = app.textFields["you@example.com"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("maya@example.com")
        let password = app.secureTextFields.firstMatch
        password.tap()
        password.typeText("password1")
        app.buttons["Sign in"].tap()

        let profile = app.buttons["Profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10),
                      "re-authentication must restore the tabs")
        if !profile.isHittable { dismissSystemSavePasswordSheet(app) }
        profile.tap()
        let rowAgain = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(rowAgain.waitForExistence(timeout: 10))
        rowAgain.tap()
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10),
                      "sources must still render after the sign-out wipe and a new sign-in")
    }
}
