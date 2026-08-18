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
    ///
    /// Reports whether the sheet is in the way, dismissing it when it is far enough along to accept
    /// a touch. Presence is judged by existence alone, deliberately: while the sheet animates in,
    /// "Not Now" is not yet hittable but its backdrop already swallows touches, so treating
    /// not-yet-hittable as "nothing there" is exactly how a tap gets lost.
    private func savePasswordSheetIsInTheWay(_ app: XCUIApplication) -> Bool {
        for root in [app, XCUIApplication(bundleIdentifier: "com.apple.springboard")] {
            let notNow = root.buttons["Not Now"]
            if notNow.exists {
                if notNow.isHittable { notNow.tap() }
                return true
            }
        }
        return false
    }

    /// Taps `element` from a state that is not about to eat the touch.
    ///
    /// The flake this replaces was a single `isHittable` check before a tap, which fails two ways:
    /// the sheet is posted by another process on its own schedule, so it can arrive in the gap
    /// between the check and the tap; and while it animates in, the element underneath still answers
    /// `isHittable == true`, so the tap lands on the backdrop and is swallowed with no error at all
    /// — the test then fails several assertions later, somewhere that reads like a product defect.
    ///
    /// So the wait is on the sheet being gone and *staying* gone for a beat, and nothing here waits
    /// on `isHittable`. That distinction matters: `tap()` scrolls an off-screen element into view by
    /// itself, and gating on hittability would forbid every target below the fold.
    private func tapWhenSettled(_ element: XCUIElement, in app: XCUIApplication,
                                timeout: TimeInterval = 20,
                                file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if savePasswordSheetIsInTheWay(app) { Thread.sleep(forTimeInterval: 0.3); continue }
            Thread.sleep(forTimeInterval: 0.4)
            if savePasswordSheetIsInTheWay(app) { continue }
            if element.exists { element.tap(); return }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTFail("\(element) never became tappable within \(timeout)s", file: file, line: line)
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

        // Signing out wipes the local consent trail, and this DEBUG local-only build has no server
        // to restore it from — so she is asked again. Asking twice is the safe direction to fail in
        // (the alternative is writing to her body data on a permission the app cannot evidence),
        // so the test agrees again rather than treating the second ask as a defect.
        let agree = app.buttons["consent.agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 10),
                      "with no local trail left, permission must be asked for again — not assumed")
        tapWhenSettled(agree, in: app)
        tapWhenSettled(app.buttons["consent.continue"], in: app)

        let profile = app.buttons["Profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10),
                      "re-authentication must restore the tabs")
        tapWhenSettled(profile, in: app)
        let rowAgain = app.buttons["Medical Sources & Disclaimer"]
        XCTAssertTrue(rowAgain.waitForExistence(timeout: 10))
        tapWhenSettled(rowAgain, in: app)
        XCTAssertTrue(app.buttons["medSource.nhs-water"].waitForExistence(timeout: 10),
                      "sources must still render after the sign-out wipe and a new sign-in")
    }
}
