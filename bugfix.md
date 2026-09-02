# bugfix.md

Issues found while trying to run the full test build + demo walkthrough on the
simulator (iPhone 17 Pro, iOS 26.5) on 2026-09-02. Ordered by severity.

## Summary of what *does* work

- App builds clean in Release configuration for the simulator and launches with no crash.
- `GenesyxCoreTests` — **314/314 pass**.
- `GenesyxAppTests` — **393/393 pass**.
- `CustomerWalkthroughUITests` — **10/10 pass** (all seven tabs open, tab bar has
  no overflow, navigation/state restore, first-run logging, Learn/pH/Insights).
- Home, pH, Nutrition, Insights screens render correctly with seeded data.

---

## 1. Demo walkthrough was never actually running (DEMO_PASSWORD not forwarded)

- **Severity:** High — the test has almost certainly *never* passed end to end.
- **Symptom:** `testDemoWalkthrough` fails instantly with
  `DEMO_PASSWORD is not set in the runner environment`.
- **Root cause:** The test doc comment claims the scheme's Test action forwards
  `DEMO_PASSWORD = $(DEMO_PASSWORD)` (`App/GenesyxUITests/DemoWalkthroughTests.swift:9-11`),
  but the shared scheme `Genesyx.xcodeproj/xcshareddata/xcschemes/Genesyx.xcscheme`
  defined **no such environment variable**, and its Test action had
  `shouldUseLaunchSchemeArgsEnv = "YES"` (inherit from Run, which also has none).
  The runner reads `ProcessInfo.processInfo.environment["DEMO_PASSWORD"]`
  (`DemoWalkthroughTests.swift:24-26`) and always got empty.
- **Fix applied (test/scheme only, no secret on disk):** In the scheme's Test
  action set `shouldUseLaunchSchemeArgsEnv = "NO"` and added an
  `EnvironmentVariables` entry `DEMO_PASSWORD = $(DEMO_PASSWORD)` (a *reference*,
  not the literal). It then expands from the value passed on the `xcodebuild`
  command line. After this the test runs and reaches sign-in.
- **Status:** fixed in both `project.yml` and the generated shared scheme so the
  setting survives XcodeGen regeneration. CI still needs to supply the secret.

## 2. `signIn()` taps an ambiguous "Sign in" button → walkthrough blocked

- **Severity:** High — blocks the demo walkthrough at step a on a clean device.
- **Symptom:**
  `Failed to tap "Sign in" Button: Multiple matching elements found`
  (`DemoWalkthroughTests.swift:400`, from the `tapWhenSettled(app.buttons["Sign in"])`
  at line 295).
- **Root cause:** Two buttons carry the identical accessibility label **"Sign in"**
  and are in the hierarchy at the same time when the auth screen is presented over
  the onboarding splash:
  - onboarding splash ghost button — `OnboardingFlowView.swift:124` (`GxGhostButton(title: "Sign in")`)
  - auth submit button — `AuthView.swift:359` (`Text(... "Sign in")`)
  `app.buttons["Sign in"]` therefore matches 2 elements and `.tap()` throws.
- **FIXED (verified 2026-09-02):** the splash and submit controls now have stable,
  distinct identifiers (`auth.splash.signIn` and `auth.submit`), and the test uses
  those identifiers. Sign-in succeeds and reaches Home as "Demo". See also #3.

## 3. Duplicate "Sign in" accessibility label (app-side)

- **Severity:** Low (accessibility smell; the cause of #2).
- **Symptom:** Two simultaneously-present controls expose the same "Sign in"
  label; VoiceOver announces two identical buttons and UI tests can't target one.
- **Root cause:** splash ghost button (`OnboardingFlowView.swift:124`) and submit button
  (`AuthView.swift:359`) share the label with no distinguishing
  `accessibilityIdentifier`.
- **FIXED:** the splash button now uses `auth.splash.signIn` and the submit button
  uses `auth.submit`; the visible VoiceOver label remains natural for customers.

## 4. Demo test is not hermetic — silently validates the wrong account

- **Severity:** Medium — produces misleading failures.
- **Symptom:** On a simulator that already had a signed-in session (a leftover
  production session for **"lucas valenca"** from a prior manual launch), the
  walkthrough ran against *that* account instead of `demo@genesyx.co.uk`. Steps
  a/c/e/f failed ("greeting must be 'Demo'", "needs a cycle phase", "could not
  read stage answer", "no Personal Details name field") purely because it was the
  wrong account — not real demo-account defects.
- **Root cause:** `signIn()` early-returns if the tabs are already up
  (`DemoWalkthroughTests.swift:271`), assuming a fresh install. A persisted
  session (session token lives in the simulator keychain and survives app
  reinstall) defeats that assumption.
- **Suggested fix:** make the test hermetic — sign out / erase the app's session
  at the start (or `xcrun simctl erase` in the test lane) so it always drives the
  real sign-in. Workaround used this session: `xcrun simctl erase <device>` before
  the run.

## 5. VERIFIED: demo account signs in and is fully populated

- Clean-session run 2026-09-02 (after #2 fix + `simctl erase`): sign-in against
  production **succeeds**. Home greets **"Demo"** (step a ✅) with a real
  **LUTEAL PHASE** card, the supplement plan renders "GENESYX ESSENTIALS"
  (step b ✅), and the Learn "How to use" card renders (step d ✅). Customer
  sign-in and account data are healthy.

## 6. Demo steps c/e/f fail on reachability, not broken features (test reliability)

- **Severity:** Medium — demo walkthrough not green; NOT a customer-facing defect.
- **Symptom:** step c (`:137` focus-foods card), step e (`:169` stage answer),
  step f (`:238` `displayNameField`) all fail to *find/reach* their target.
- **Evidence the app is fine — every target element exists:**
  - focus-foods heading `Text("Your focus foods this phase")` — `NutritionView.swift:347`
  - stage options `quizOption.stage.<id>` — built at `ProfileView.swift:1026`
  - name field `displayNameField` — `ProfileView.swift:786`
- **Root cause:** the iOS **"Save Password?" system sheet** was still on screen in
  the step-a snapshot; its backdrop swallows touches/scrolls, so the later
  navigation (scroll to focus-foods, open Tracking Preferences, open Personal
  Details) doesn't land. The test's `savePasswordSheetIsInTheWay` /
  `addUIInterruptionMonitor` handling (`DemoWalkthroughTests.swift:36-42, 378-404`)
  is not dismissing it reliably.
- **FIX APPLIED (test-only):** the test now checks and dismisses the Save Password
  sheet before accepting Home, checks it again after Home appears, requires targets
  to be hittable, and scrolls in either direction according to the target frame.
- **Verification remaining:** rerun this one production-account walkthrough with
  `DEMO_PASSWORD` supplied. The current Codex process does not have that secret, so
  the updated reachability path has compiled but has not been rerun end to end.

---

## Environment note (not a code bug)

- A physical iPhone is **not required** to create an App Store archive or upload it
  to TestFlight. The generic iOS archive uses the App Store distribution profile.
- Direct physical-device verification is still outstanding because no device is
  registered locally. Perform that check later through TestFlight on a borrowed
  device or with an external tester; it does not block creating the upload artifact.
