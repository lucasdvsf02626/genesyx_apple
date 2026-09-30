import XCTest

/// Thursday's demo, driven end to end against the LIVE production demo account
/// (`demo@genesyx.co.uk`), in demo order, so the five fixes can be watched on the simulator and
/// captured as a screenshot after every numbered step.
///
/// This is the only UI test in the suite that signs in for real. It launches WITHOUT
/// `-uiTestSeed`, so the app talks to production Supabase instead of the local mock every other
/// UI test uses. The password is never in code or in the launch arguments: it is read from the
/// `DEMO_PASSWORD` environment variable, forwarded to the runner by the scheme's Test action
/// (`DEMO_PASSWORD = $(DEMO_PASSWORD)`). `DEMO_EMAIL` optionally points it at a separate QA
/// account (first name "Demo"), so the App Review login never has to change; unset, it is the
/// demo account above.
///
/// Because steps (e) and (f) mutate the client-facing account, every change is captured and
/// restored INLINE within the same step. `continueAfterFailure = true`, so a failed assertion is
/// recorded and the walkthrough — including the restores — keeps running to the end, and all
/// failures are reported together rather than stopping at the first.
///
/// `tapWhenSettled` / `savePasswordSheetIsInTheWay` are copied from `LifecycleE2ETests` on purpose:
/// they are `private` there, and the brief is one new file with no edits to the existing suite.
final class DemoWalkthroughTests: XCTestCase {

    private var app: XCUIApplication!

    private var demoPassword: String {
        ProcessInfo.processInfo.environment["DEMO_PASSWORD"] ?? ""
    }

    /// The scheme forwards `$(DEMO_EMAIL)`, which arrives as "" when unset, so empty means default.
    private var demoEmail: String {
        let email = ProcessInfo.processInfo.environment["DEMO_EMAIL"] ?? ""
        return email.isEmpty ? "demo@genesyx.co.uk" : email
    }

    override func setUp() {
        super.setUp()
        // The whole point of this pass: keep going after a failure so every step is exercised and
        // the inline restores in (e)/(f) still run.
        continueAfterFailure = true

        // iOS posts a system "Save Password?" sheet from another process after a sign-in it judges
        // successful. This is the belt to `savePasswordSheetIsInTheWay`'s braces.
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            for label in ["Not Now", "Not now"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    // MARK: - The walkthrough, in demo order

    func testDemoWalkthrough() {
        guard !demoPassword.isEmpty else {
            XCTFail("DEMO_PASSWORD is not set in the runner environment. Export it and run via the "
                    + "scheme (DEMO_PASSWORD = $(DEMO_PASSWORD)); the walkthrough cannot sign in without it.")
            return
        }

        app = XCUIApplication()
        // No -uiTestSeed: this must reach the real demo account and its production data.
        app.launch()

        stepA_signInAndGreeting()
        stepB_phSupplementPlan()
        stepC_nutritionFocusFoods()
        stepD_learnHowToUseCard()
        stepE_trackingPreferencesAndConsent()
        stepF_personalDetails()
    }

    // MARK: a. Launch → sign in → Home greeting

    private func stepA_signInAndGreeting() {
        signIn()

        let name = app.staticTexts["Demo"]
        XCTAssertTrue(name.waitForExistence(timeout: 20),
                      "a. Home must greet her by name 'Demo' (exact capitalisation) once signed in")
        XCTAssertFalse(app.staticTexts["demo"].exists,
                       "a. the greeting must not render her name in lower case")
        snapshot("step-a-home-greeting")
    }

    // MARK: b. pH → Genesyx supplements card → See your supplement plan

    private func stepB_phSupplementPlan() {
        tapTab("pH")
        XCTAssertTrue(app.staticTexts["Vaginal pH Tracker"].waitForExistence(timeout: 20),
                      "b. the pH tab must open")

        let cta = app.buttons["See your supplement plan"]
        XCTAssertTrue(swipeUntilHittable(cta),
                      "b. the 'See your supplement plan' button must be reachable by scrolling the pH tab")
        XCTAssertTrue(app.staticTexts["Genesyx supplements"].exists,
                      "b. the Genesyx supplements card must be on the pH tab")
        tapWhenSettled(cta)

        // The button opens the supplement-plan sheet over the Nutrition tab. The nav title is unique
        // to the sheet; "Your nutrition focus" (the Nutrition root) also has a "Your supplement plan"
        // card, so we prove the sheet positively rather than by the root's absence.
        let planTitle = app.navigationBars["Your supplement plan"]
        XCTAssertTrue(planTitle.waitForExistence(timeout: 15),
                      "b. 'See your supplement plan' must open the supplement plan, not the Nutrition root")

        // Loud flag if the plan renders but its contents are empty.
        let essentials = app.staticTexts["GENESYX ESSENTIALS"]
        if planTitle.exists && !essentials.waitForExistence(timeout: 5) {
            XCTFail("b. ⚠️ THE SUPPLEMENT PLAN OPENED BUT RENDERED EMPTY — the genesyx_products table "
                    + "may not be seeded yet. This is the screen the client sees on Thursday.")
        }
        snapshot("step-b-supplement-plan")

        // Leave the sheet so the walkthrough can carry on from Nutrition.
        let gotIt = app.buttons["Got it"]
        if gotIt.waitForExistence(timeout: 5) { tapWhenSettled(gotIt) }
    }

    // MARK: c. Nutrition → article → See this phase's foods → focus-foods card

    private func stepC_nutritionFocusFoods() {
        tapTab("Nutrition")
        XCTAssertTrue(app.staticTexts["Your nutrition focus"].waitForExistence(timeout: 20),
                      "c. the Nutrition tab must open")

        // "Eating with your cycle, not against it" is the nutrition article whose CTA is
        // "See this phase's foods" (LearnContent a5). Its row label carries a reading-time suffix,
        // so match the title as a prefix.
        let articleRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Eating with your cycle")).firstMatch
        XCTAssertTrue(swipeUntilHittable(articleRow),
                      "c. the Nutrition tab must list the 'Eating with your cycle' article")
        tapWhenSettled(articleRow)

        let foodsCta = app.buttons["See this phase's foods"]
        XCTAssertTrue(swipeUntilHittable(foodsCta),
                      "c. the article must offer 'See this phase's foods'")
        tapWhenSettled(foodsCta)

        XCTAssertTrue(app.staticTexts["Your nutrition focus"].waitForExistence(timeout: 15),
                      "c. tapping 'See this phase's foods' must land back on the Nutrition root")
        let focusCard = app.staticTexts["Your focus foods this phase"]
        XCTAssertTrue(swipeUntilHittable(focusCard),
                      "c. the focus-foods card must be visible on the Nutrition root (needs a cycle phase)")
        snapshot("step-c-focus-foods")
    }

    // MARK: d. Learn → "How to use Genesyx" gradient card

    private func stepD_learnHowToUseCard() {
        tapTab("Learn")
        let card = app.buttons["learn.howToUse"]
        // The card's background is a LinearGradient + SF Symbol drawn unconditionally, so it cannot
        // fail to load. XCUITest can't inspect pixels; the strongest available proxy for "rendered
        // the gradient treatment, not a blank frame" is that the whole card exists and is hittable.
        XCTAssertTrue(swipeUntilHittable(card),
                      "d. the 'How to use Genesyx' card must render as a real, tappable card")
        XCTAssertTrue(card.isHittable,
                      "d. the card must be hittable, not a blank/failed frame")
        snapshot("step-d-learn-how-to-use")
    }

    // MARK: e. Profile → Tracking Preferences persist, then consent withdraw/re-grant

    private let stageOptions = ["exploring", "preparing", "trying", "support"]

    private func stepE_trackingPreferencesAndConsent() {
        tapTab("Profile")
        XCTAssertTrue(app.staticTexts["Personal Details"].waitForExistence(timeout: 20),
                      "e. Profile must render")

        // --- e.1 change an answer, save, reopen, assert it persisted ---
        openTrackingPreferences()
        guard let original = selectedStageOption() else {
            XCTFail("e. could not read the current 'stage' answer to change it")
            dismissSheetIfOpen()
            return
        }
        let changed = stageOptions.first { $0 != original } ?? original

        tapWhenSettled(app.buttons["quizOption.stage.\(changed)"])
        tapWhenSettled(app.buttons["trackingPreferences.save"])

        openTrackingPreferences()
        let changedRow = app.buttons["quizOption.stage.\(changed)"]
        XCTAssertTrue(changedRow.waitForExistence(timeout: 10) && changedRow.isSelected,
                      "e. the changed tracking answer must persist across a save and reopen")
        snapshot("step-e1-tracking-pref-persisted")
        dismissSheetIfOpen()

        // --- e.2 withdraw consent, reopen, assert banner + Save disabled ---
        let withdraw = app.buttons["consent.withdraw"]
        if swipeUntilHittable(withdraw) {
            tapWhenSettled(withdraw)
            let confirm = app.alerts.buttons["Withdraw consent"]
            if confirm.waitForExistence(timeout: 5) { confirm.tap() }
        } else {
            XCTFail("e. the 'Withdraw consent' control must be on Profile while consent is active")
        }

        openTrackingPreferences()
        let banner = app.descendants(matching: .any).matching(identifier: "consent.blocked").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10),
                      "e. withdrawing consent must show the withdrawn banner in Tracking Preferences")
        XCTAssertFalse(app.buttons["trackingPreferences.save"].isEnabled,
                       "e. Save must be disabled while consent is withdrawn")
        snapshot("step-e2-consent-withdrawn-banner")
        dismissSheetIfOpen()

        // --- e.3 RESTORE: re-grant consent, then restore the original answer (clean state) ---
        let restore = app.buttons["consent.restore"]
        if swipeUntilHittable(restore) {
            tapWhenSettled(restore)
            let agree = app.buttons["consent.agree"]
            if agree.waitForExistence(timeout: 10) {
                tapWhenSettled(agree)
                tapWhenSettled(app.buttons["consent.continue"])
            }
        } else {
            XCTFail("e. RESTORE FAILED: could not find 'Turn collection back on' — demo consent may be "
                    + "left withdrawn. Re-grant it manually before Thursday.")
        }

        openTrackingPreferences()
        if app.buttons["quizOption.stage.\(original)"].waitForExistence(timeout: 10) {
            tapWhenSettled(app.buttons["quizOption.stage.\(original)"])
            let save = app.buttons["trackingPreferences.save"]
            if save.isEnabled {
                tapWhenSettled(save)
            } else {
                XCTFail("e. RESTORE FAILED: Save still disabled, original tracking answer not restored.")
            }
        }
        dismissSheetIfOpen()
    }

    // MARK: f. Profile → Personal Details edit/persist/restore

    private func stepF_personalDetails() {
        tapTab("Profile")
        tapWhenSettled(app.buttons["Personal Details"])

        let field = app.textFields["displayNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "f. Personal Details must offer the name field")
        let original = (field.value as? String) ?? ""
        XCTAssertFalse(original.isEmpty, "f. the demo account should already have a display name")

        let edited = original + " QA"
        replaceText(field, with: edited)
        tapWhenSettled(app.buttons["Save"])

        tapWhenSettled(app.buttons["Personal Details"])
        let reopened = app.textFields["displayNameField"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 15))
        XCTAssertEqual(reopened.value as? String, edited,
                       "f. an edited personal detail must persist across a save and reopen")
        snapshot("step-f-personal-details-persisted")

        // RESTORE: put the original name back — this is the name the client sees greeted on Home.
        replaceText(reopened, with: original)
        tapWhenSettled(app.buttons["Save"])

        tapWhenSettled(app.buttons["Personal Details"])
        let restored = app.textFields["displayNameField"]
        if restored.waitForExistence(timeout: 15) {
            XCTAssertEqual(restored.value as? String, original,
                           "f. RESTORE: the original display name must be back so Thursday's greeting is intact")
        }
        dismissSheetIfOpen()
    }

    // MARK: - Sign in

    private func signIn() {
        // A fresh install opens on the onboarding splash; its "Sign in" ghost button is the way to
        // the gate. If a session somehow already exists, the tabs are up and there is nothing to do.
        if app.buttons["Home"].waitForExistence(timeout: 5) { return }

        let splashSignIn = app.buttons["auth.splash.signIn"]
        let authScreen = app.descendants(matching: .any).matching(identifier: "auth.screen").firstMatch
        if splashSignIn.waitForExistence(timeout: 30), !authScreen.exists {
            tapWhenSettled(splashSignIn)
        }
        guard authScreen.waitForExistence(timeout: 20) else {
            XCTFail("a. never reached the sign-in screen")
            return
        }

        let email = app.textFields["you@example.com"]
        guard email.waitForExistence(timeout: 10) else {
            XCTFail("a. the sign-in screen has no email field")
            return
        }
        email.tap()
        email.typeText(demoEmail)

        let password = app.secureTextFields.firstMatch
        password.tap()
        password.typeText(demoPassword)

        tapWhenSettled(app.buttons["auth.submit"])

        // Real backend: the demo account carries server-side Article 9 consent, so we expect the
        // tabs. If a consent screen is shown instead (refreshed wording / no local trail), agree so
        // the run can proceed — that is the account's normal state and is left as-is.
        let home = app.buttons["Home"]
        let consent = app.buttons["consent.agree"]
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            // Dismiss the SpringBoard "Save Password?" prompt FIRST. Home exists *behind* the prompt,
            // so checking `home.exists` before clearing the sheet breaks the loop with the prompt
            // still up, and its backdrop then swallows step a/b's first tab tap.
            savePasswordSheetIsInTheWay(app)
            if home.exists { break }
            if consent.exists {
                tapWhenSettled(consent)
                tapWhenSettled(app.buttons["consent.continue"])
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        // The prompt can also pop the instant Home appears; clear it once more before returning.
        savePasswordSheetIsInTheWay(app)
        XCTAssertTrue(home.waitForExistence(timeout: 10),
                      "a. signing in as the demo account must reach the private tabs")
    }

    // MARK: - Navigation helpers

    /// The seven-icon custom bar exposes each tab button by its title as the identifier.
    private func tapTab(_ title: String) {
        let tab = app.buttons.matching(identifier: title).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "the \(title) tab must be on the bar")
        tapWhenSettled(tab)
    }

    private func openTrackingPreferences() {
        let row = app.buttons["Tracking Preferences"]
        if swipeUntilHittable(row) { tapWhenSettled(row) }
        _ = app.buttons["trackingPreferences.save"].waitForExistence(timeout: 10)
    }

    /// Which of the `stage` question's options currently carries the selected trait, if any.
    private func selectedStageOption() -> String? {
        for option in stageOptions {
            let button = app.buttons["quizOption.stage.\(option)"]
            if button.waitForExistence(timeout: 5), button.isSelected { return option }
        }
        return nil
    }

    /// Dismisses the top sheet by its nav-bar Close/Cancel/Got it/back control if one is present.
    private func dismissSheetIfOpen() {
        for label in ["Got it", "Close", "Cancel", "Done"] {
            let button = app.buttons[label]
            if button.exists && button.isHittable { button.tap(); return }
        }
        // Fall back to a nav-bar back/close chevron if the sheet uses one.
        let navBack = app.navigationBars.buttons.firstMatch
        if navBack.exists && navBack.isHittable { navBack.tap() }
    }

    /// Clears a text field and types a new value. The demo name is never empty, so a plain
    /// delete-per-character clear is safe here.
    private func replaceText(_ field: XCUIElement, with newValue: String) {
        field.tap()
        let current = (field.value as? String) ?? ""
        if !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(newValue)
    }

    // MARK: - Screenshots

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Save Password interruption (copied from LifecycleE2ETests: those helpers are private)

    /// iOS intermittently offers a system "Save Password?" sheet after a credential submission. It
    /// belongs to another process, so it never appears in the test log, and its backdrop swallows
    /// every touch — surfacing as the app's own controls going unhittable rather than as an
    /// interruption. Declining it also keeps the simulator keychain empty for the next run.
    @discardableResult
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

    /// Taps `element` once it is genuinely pressable. We require `exists && isHittable` before
    /// tapping — `tap()` does not reliably auto-scroll an off-screen control across sheets, so an
    /// element below the fold is scrolled into view here (via `swipeUntilHittable`) rather than
    /// assumed reachable. The Save Password sheet is cleared first each pass so its backdrop cannot
    /// be what makes the target unhittable.
    private func tapWhenSettled(_ element: XCUIElement, timeout: TimeInterval = 20,
                                file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if savePasswordSheetIsInTheWay(app) { Thread.sleep(forTimeInterval: 0.3); continue }
            Thread.sleep(forTimeInterval: 0.4)
            if savePasswordSheetIsInTheWay(app) { continue }
            if element.exists && !element.isHittable { _ = swipeUntilHittable(element) }
            if element.exists && element.isHittable { element.tap(); return }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTFail("\(element) never became hittable within \(timeout)s", file: file, line: line)
    }

    /// Scrolls until `element` could actually be pressed. Hittability, not existence: the app keeps
    /// a lot of content in the hierarchy at once, so `exists` alone can be true from the wrong place.
    /// Direction is chosen from the target's own frame so it works whether the control is above or
    /// below the current viewport — a one-direction `swipeUp` can never reach a target that sits
    /// above the fold (e.g. after a sheet reopens scrolled down).
    @discardableResult
    private func swipeUntilHittable(_ element: XCUIElement, maxSwipes: Int = 20) -> Bool {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            if savePasswordSheetIsInTheWay(app) { continue }
            // Target above the viewport midline → scroll content down (swipeDown) to bring it in;
            // at/below the midline, or not yet in the hierarchy (content lives further down) → swipeUp.
            if element.exists && element.frame.minY < app.frame.midY {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
            swipes += 1
        }
        return element.isHittable
    }
}
