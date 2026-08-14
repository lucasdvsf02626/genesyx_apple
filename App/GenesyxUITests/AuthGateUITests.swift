import XCTest

/// P0 authentication gate. Private tabs require a valid session. The splash, quiz and
/// bundled guide may still appear before login.
final class AuthGateUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += args
        app.launch()
        return app
    }

    private var authScreen: XCUIElement {
        XCUIApplication().descendants(matching: .any).matching(identifier: "auth.screen").firstMatch
    }

    private func assertNoPrivateTabs(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for title in ["Home", "Track", "pH", "Nutrition", "Insights", "Learn", "Profile"] {
            XCTAssertFalse(app.buttons[title].exists, "\(title) must not be reachable", file: file, line: line)
        }
    }

    /// Fresh install: onboarding, no tab bar.
    func testFreshInstallCannotSeeTabsBeforeAuthentication() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestOnboarding", "YES"])
        XCTAssertTrue(app.buttons["Start Your Personalised Quiz"].waitForExistence(timeout: 10))
        assertNoPrivateTabs(app)
        XCTAssertFalse(authScreen.exists)
    }

    /// Completed onboarding + no session opens mandatory login, not the tabs.
    func testCompletedOnboardingWithNoSessionOpensMandatoryLogin() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestSignedOut", "YES"])
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Welcome back"].exists)
        XCTAssertFalse(app.buttons["auth.back"].exists, "mandatory auth has no dismiss")
        assertNoPrivateTabs(app)
    }

    /// The mandatory Sign In screen (Profile logout / returning user) carries the Genesyx lockup,
    /// not the old tracking text. Same asset as the splash; this identifier is this screen's.
    func testMandatorySignInShowsTheBrandLockup() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestSignedOut", "YES"])
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        let logo = app.descendants(matching: .any).matching(identifier: "auth.brandLogo").firstMatch
        XCTAssertTrue(logo.waitForExistence(timeout: 5),
                      "the Genesyx lockup must be on the Sign In screen")
    }

    /// The way back in for a woman who has forgotten her password.
    ///
    /// The gate is what makes this load-bearing. Profile's "Change password" is inside the private
    /// tabs, so it sits behind the very session she cannot obtain; if this control is not on the
    /// mandatory screen there is no in-app route to recovery at all, and a forgotten password is a
    /// permanent lockout. Asserted here rather than only in a unit test because the repository
    /// method is unreachable if nothing on this screen calls it.
    func testMandatorySignInOffersPasswordRecovery() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestSignedOut", "YES"])
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        let forgot = app.descendants(matching: .any).matching(identifier: "auth.forgotPassword").firstMatch
        XCTAssertTrue(forgot.waitForExistence(timeout: 5),
                      "a woman locked out by the gate must be able to start a password reset from it")
        assertNoPrivateTabs(app)
    }

    /// Back from the onboarding auth cover must not expose the tabs.
    func testCancellingOnboardingAuthNeverExposesTheTabs() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestOnboarding", "YES"])
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 10))
        app.buttons["Sign in"].tap()
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        let back = app.descendants(matching: .any).matching(identifier: "auth.back").firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "onboarding auth may dismiss back to the quiz")
        back.tap()
        XCTAssertTrue(app.buttons["Start Your Personalised Quiz"].waitForExistence(timeout: 10)
                      || app.staticTexts["A thoughtful starting point"].waitForExistence(timeout: 2)
                      || app.buttons["Sign in"].waitForExistence(timeout: 2))
        assertNoPrivateTabs(app)
    }

    func testLogoutRemovesEveryPrivateTab() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestTab", "6"])
        XCTAssertTrue(app.buttons["Log out"].waitForExistence(timeout: 10))
        app.buttons["Log out"].tap()
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        assertNoPrivateTabs(app)
    }

    func testAccountDeletionReturnsToAuthentication() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestTab", "6"])
        let delete = app.buttons["Delete account"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.tap()
        XCTAssertTrue(app.alerts["Delete your account?"].waitForExistence(timeout: 5))
        app.alerts["Delete your account?"].buttons["Delete"].tap()
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        assertNoPrivateTabs(app)
    }

    /// Keep-store relaunch after logout must stay on login.
    func testRelaunchAfterLogoutRemainsLocked() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestTab", "6"])
        XCTAssertTrue(app.buttons["Log out"].waitForExistence(timeout: 10))
        app.buttons["Log out"].tap()
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        app.terminate()

        let app2 = launch(args: ["-uiTestSeed", "YES", "-uiTestKeepStore", "YES"])
        XCTAssertTrue(app2.descendants(matching: .any).matching(identifier: "auth.screen")
                        .firstMatch.waitForExistence(timeout: 10),
                      "a relaunch with no session must stay on mandatory login")
        assertNoPrivateTabs(app2)
    }

    func testRestoredSessionReachesTheTabs() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestTab", "0"])
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        app.terminate()

        let app2 = launch(args: ["-uiTestSeed", "YES", "-uiTestKeepStore", "YES", "-uiTestTab", "0"])
        XCTAssertTrue(app2.buttons["Home"].waitForExistence(timeout: 10),
                      "a valid mock session must restore into the tabs")
    }

    /// Missing session on a completed-onboarding device. This is **not** the revoked-token
    /// path — `-uiTestSignedOut` seeds no credential. Expired/revoked tokens are
    /// `SessionExpiryTests`, which inject a fake `AuthBackend` and emit `.sessionExpired`.
    func testMissingSessionNeverShowsPrivateContent() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestSignedOut", "YES"])
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        assertNoPrivateTabs(app)
        XCTAssertFalse(app.buttons["Home"].waitForExistence(timeout: 1))
    }

    func testInviteLinkWhileSignedOutWaitsForAuthentication() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestSignedOut", "YES"])
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        if #available(iOS 16.4, *) {
            app.open(URL(string: "genesyx://invite/TESTCODE12AB")!)
        }
        XCTAssertTrue(authScreen.waitForExistence(timeout: 5),
                      "an invite must not mount private UI while signed out")
        assertNoPrivateTabs(app)
        XCTAssertFalse(app.staticTexts["You've been invited"].waitForExistence(timeout: 1))
    }

    /// A notification tapped while she is signed out must not open its tab. The destination is
    /// injected through the same `payload` → `destination` decode the real tap handler uses
    /// (`-uiTestPendingNotification`, DEBUG-only), so this asserts against a genuinely held
    /// destination rather than an app that simply has nothing pending.
    ///
    /// Paired with `testPendingNotificationOpensItsTabOnceAuthenticated`, which is the control:
    /// without it, this test would also pass if the injection did nothing at all.
    func testPendingNotificationWhileSignedOutNeverOpensItsTab() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestSignedOut", "YES",
                                "-uiTestPendingNotification", "4"])   // Insights
        XCTAssertTrue(authScreen.waitForExistence(timeout: 10))
        assertNoPrivateTabs(app)
        XCTAssertFalse(app.staticTexts["Your Insights"].waitForExistence(timeout: 2),
                       "a held notification destination must not render its tab behind the gate")
    }

    /// The control. The same injection on a signed-in launch does land on Insights, which is what
    /// makes the signed-out assertion above evidence of the gate rather than of an inert hook.
    /// Inactive tabs are `accessibilityHidden`, so "Your Insights" is only reachable when that
    /// tab is the selected one.
    func testPendingNotificationOpensItsTabOnceAuthenticated() {
        let app = launch(args: ["-uiTestSeed", "YES", "-uiTestPendingNotification", "4"])
        XCTAssertTrue(app.staticTexts["Your Insights"].waitForExistence(timeout: 15),
                      "a pending destination must be applied once the tabs are allowed to mount")
    }
}
