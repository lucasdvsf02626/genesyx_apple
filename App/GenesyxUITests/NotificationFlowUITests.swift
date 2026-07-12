import XCTest

/// Drives the real notification opt-in the way she would: Profile → toggle → the pre-prompt sheet
/// that explains what she'll get → the system permission dialog. Nothing in the unit tests can
/// prove this path works, because the permission dialog belongs to iOS, not to us.
///
/// With permission granted, the app plans and schedules from her seeded data — and the DEBUG
/// schedule dump (`📬 GENESYX SCHEDULE`) prints exactly what landed in the notification centre, so
/// the run can be checked against what the planner intended.
final class NotificationFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTurningOnRemindersExplainsFirstThenAsksPermission() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "5"]   // Profile

        // iOS owns the permission alert, so it has to be tapped through SpringBoard.
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            for label in ["Allow", "Allow Notifications", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()

        let toggle = app.switches["Weekly reminders"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "the reminders toggle should be on Profile")
        XCTAssertEqual(toggle.value as? String, "0", "reminders must start off — we never opt her in")

        toggle.tap()

        // The pre-prompt: she is told what she's agreeing to BEFORE iOS asks. The system dialog can
        // only be shown once, so it must never be spent on someone who doesn't know what it's for.
        let explain = app.buttons["Turn on reminders"]
        XCTAssertTrue(explain.waitForExistence(timeout: 5), "the toggle must explain before it asks")
        explain.tap()

        // Nudge the interruption monitor into firing (iOS delivers the alert to SpringBoard).
        app.tap()

        // The toggle only reads "on" when she asked AND iOS agreed — so this passing means the
        // whole chain worked: pre-prompt → system dialog → Allow → authorized → scheduled.
        let switchedOn = NSPredicate(format: "value == '1'")
        expectation(for: switchedOn, evaluatedWith: toggle)
        waitForExpectations(timeout: 20)
    }
}
