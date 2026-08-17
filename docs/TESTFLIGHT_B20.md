# TestFlight — Genesyx 1.2.0 (20)

The first build that can complete a password reset. Everything else here is the 1.2.0 change list,
which testers have not seen yet either, because **build 18 was never uploaded** (`to do list.md:94`)
and build 19's upload status is not recorded anywhere in this repo.

> **Read this before writing the release notes in App Store Connect.**
>
> - **Build 18** was archived 13 Aug and never uploaded. Its notes live in `TESTFLIGHT_B18.md` and
>   describe a binary no tester ever ran.
> - **Build 19** was archived 17 Aug at 12:48 from `fb37e2a`. Whether it reached TestFlight is
>   **NOT VERIFIED** from this repo. Check App Store Connect before assuming testers have it. If it
>   did go up, items 2 to 8 below are already familiar to them and only item 1 is new.
> - **Build 20** is `8df44db`. It is build 19 plus the password recovery flow.
>
> If 19 never went up, the last build testers hold is **1.1.1 (17)**, and they are receiving the
> entire 1.2.0 change list at once. In that case `TESTFLIGHT_B18.md` §"What to Test" items 1 to 33
> **all apply to this build** and should be pasted in alongside what follows. They are not repeated
> here, because duplicating 33 items across two documents is how they drift apart.

---

## Pre-flight — do these before uploading

| # | Check | State |
|---|---|---|
| 1 | **`genesyx://reset-password` is on the Supabase Auth redirect allow-list** | ✅ **Added 17 Aug 2026**, project `epltxklawpcxxbaleswg`, branch `main` PRODUCTION. Verified after a hard reload: the list now reads `https://genesyx.co.uk/**`, `genesyx://`, `genesyx://reset-password`, Total URLs 3. **This is not optional and its absence is silent.** Without the exact string, Supabase discards `redirect_to` and substitutes the project Site URL, so the email points at a web page and the app never sees the link. The pre-existing bare `genesyx://` entry did **not** cover it: the allow-list matches literally unless the entry carries a wildcard. `DeepLink.passwordRecoveryURL` pins the string in code and `DeepLinkTests.testTheRecoveryRedirectIsTheExactStringAllowListedInSupabase` asserts it, so the dashboard and the binary are held in agreement by a test rather than by memory |
| 2 | **Recovery email template still uses `{{ .ConfirmationURL }}`** | ✅ Verified 17 Aug. Authentication → Emails shows "Set up custom SMTP to edit templates", so all templates are Supabase defaults and unedited. The default recovery template honours `redirect_to`. A hand-edited template with a hardcoded https link would have made pre-flight 1 pointless |
| 3 | **Custom SMTP is NOT configured** | ⬜ **Open, and it will look exactly like the bug this build fixes.** Reset emails go through Supabase's built-in sender, which is rate limited to a handful per hour and is documented as not for production. For a small internal tester group it will survive. For an external group it will not, and the symptom is identical to the old fault: she asks for a reset and no email arrives. Not a blocker for an internal TestFlight pass; is a blocker before external testers or public release |
| 4 | **Build number is 20, not 19** | ✅ `8df44db`. `project.yml:89` and both configs in `project.pbxproj` read 20, verified at HEAD rather than in the working tree. Build 19 stays frozen at `fb37e2a`. Reusing 19 would put two different binaries behind one number and App Store Connect rejects the second |

---

## "What to Test" (paste into TestFlight → Build 20 → Test Details)

### 1. Resetting a forgotten password — the headline, and it has one rule

**Open the reset email on the same iPhone that asked for it.** Not your Mac, not a second phone,
not a tablet. If you open it anywhere else the app will correctly tell you the link has expired,
and you will have found nothing except this instruction being right. The reason is that asking for
the reset stores a one-time secret on the device that asked, and only that device can complete the
exchange. It is a security property, not a defect, and it is worth knowing before you go hunting
for the email on whatever screen is nearest.

Please walk it in this order:

1. Sign out. On the sign-in screen tap **Forgot password?** and enter your address.
2. You should see: *"If that email has an account, we've sent a reset link. Open it on this phone."*
   The wording is deliberately the same whether or not the address has an account, so that this
   screen cannot be used to find out who has one.
3. Open the email **on that iPhone** and tap the link. The app should come straight to the front on
   a **Set a new password** screen. It should **not** open Safari, and it should **not** dump you
   back on the sign-in screen with nothing said.
4. Try a password of fewer than 8 characters. Save should stay unavailable and tell you why.
5. Type two passwords that do not match. Same: blocked, with the reason on screen.
6. Now set a valid one. You should be **signed out** and returned to login. That is intentional. A
   reset is what you do when someone else may know your old password, so every other session ends
   with it and you get to prove the new one works while you still remember typing it.
7. Sign in with the **old** password. It must fail.
8. Sign in with the **new** password. It must work, and your data must all still be there: cycle,
   logs, pH readings, supplements.
9. **The one people skip.** Go back to the email and tap the same link a second time. You should get
   a clear message that the link has expired or has already been used, with a way back to sign-in.
   A blank screen, a spinner that never stops, or a silent return to login is a bug, and it is the
   single most valuable thing you can report here.

Also worth a try: tap the link while the app is already open and signed in as someone else. You
should land on the reset screen, not be dropped into that other account's data.

### 2. You now have to be signed in

Private tabs no longer open without a valid session. Sign out and confirm you cannot reach Home,
Track, Insights, Nutrition or Profile by any route. Force quit and reopen while signed out: still
the sign-in screen. Then sign in, force quit, reopen, and confirm you are **not** asked to sign in
again. Staying signed in across a genuine cold start is the half of this that a simulator cannot
prove, so it is real-device work.

### 3. Deleting your account now actually deletes it

**Use a throwaway account, never your own.** Delete from Profile → Delete account. Then sign in
with a second throwaway and confirm it sees its own name and none of the first account's logs.
Until 17 Aug the server function behind this was written but not deployed, so deletion could report
success over data it had not removed. It is deployed now.

### 4. Revoking Sign in with Apple ends your session

If you signed in with Apple: go to iOS Settings → your name → Sign in with Apple → Genesyx → stop
using. Return to the app. You should be signed out. If you signed in with **email**, revoking a
different app's Apple access must **not** sign you out.

### 5. The free guide

Profile has the 7-day starter guide, which opens in a reader inside the app rather than throwing you
into Safari. Please check it opens, scrolls, and that nothing in it navigates you out of the app.

### 6. Partner linking is gone on purpose

There is no Partner section on Profile and an invite link does nothing. That is a deliberate scope
decision for this release, not a feature that broke. Please do not file it. If you find **any**
surviving route to partner linking, that one we do want.

### 7. Your own supplements now follow the account

Nutrition → Supplement plan → "Add your own". Add one, force quit, reopen: still there. Add one on a
second device or the Android app on the same account and pull to refresh here: it should arrive.
**Look at your existing list first:** every supplement should still be there with its name and dose,
but a time you typed by hand ("with breakfast", "8pm") will now be blank, because the time field is a
picker now. That is intended and cannot be undone. A supplement that **vanished entirely** is a bug.

### 8. Everything in build 18's notes

If build 19 did not reach you, this is your first 1.2.0 build and `TESTFLIGHT_B18.md` items 1 to 33
all apply: the weekly article series, intimacy logging, calendar markers, meal logging, recipes,
the pH tab, per-supplement reminder times, glass size, the period countdown correction, and the
rest. Ask for that list and it will be pasted in with these notes.

Please report anything wrong with a screenshot and the steps to reproduce. Thank you.

---

## Beta App Review Information

- **Sign-in required:** Yes.
- **Demo account:** `demo@genesyx.co.uk` — password is in the password manager. Do not paste it into
  this file, a log, a commit or a chat.
- **Verify path for reviewers:** Nutrition → expand "Why hydration?" → Sources footer; and
  Settings → Medical Sources & Disclaimer.
- **Notes:** Educational fertility and wellness app. All health statements carry inline citations
  (NHS / EFSA / NCBI-StatPearls / PubMed). The pH tracker records vaginal pH for personal wellness
  tracking only. It is not a medical device and not for contraception. Intimacy logging is a private
  record with no sharing surface. Partner-linking code is present in the binary but unreachable
  behind a compile-time flag, because the same backend serves the Android app, which does ship it.

---

## What is NOT in this build

- **Password reset on a different device.** By design, and stated on screen. The flow uses a
  device-bound exchange, so the link only completes on the phone that requested it.
- **A web page that handles the reset link.** The link is a custom scheme, `genesyx://`, chosen over
  the https form deliberately: Universal Links need an `apple-app-site-association` file served from
  genesyx.co.uk, which is not served, and a reset link that opens Safari to a 404 is a woman locked
  out of her account. She must have the app installed to be resetting its password, so nothing is
  lost by requiring it.
- **Custom SMTP.** See pre-flight 3. Reset and invite emails ride Supabase's built-in sender.
- **Apple token revocation on account deletion.** The client half is done: revoking the app under
  iOS Settings ends the local session. The **server** call to Apple's `/auth/revoke` is still not
  implemented in `delete_account`. Apple requires it of apps offering Sign in with Apple, and
  `auth.identities` showed real Apple accounts in use, so this is engaged for live users. It is a
  public-release blocker, not a TestFlight one.
- **An in-app consent step for health data.** The published privacy policy cites Article 9(2)(a)
  explicit consent, and the app has no consent screen or stored record to evidence it. That is a
  legal decision, not an engineering one. Public-release blocker.
- **Dynamic Type.** The app sizes its own text throughout, by documented design
  (`Typography.swift:5-9`). Larger Text in iOS Settings changes nothing. The reset screen matches
  the rest of the app rather than being the one screen that behaves differently.
- **Widget, barcode scanning, photo meal logging, nutrient counting.** Never built. Future scope.

---

## Build facts

- Version **1.2.0 (20)**, commit `8df44db`, bundle `com.genesyx.app`, team `M5L3MM75SG`.
- Contains build 19 (`fb37e2a`) plus `b78eee6`, `b6907c5`, `eded1c7` and the version bump.
- **Green baseline for the build-20 tree, 17 Aug 22:57 to 23:15:** 294 domain (`swift test`, 0
  failures) · 431 `xcodebuild test` of which 430 passed, 0 failed, 1 skipped, in 1,093 s.
  `** TEST SUCCEEDED **`. Counts read out of
  `/tmp/dd-b20/Logs/Test/Test-Genesyx-2026.08.17_22-57-24-+0100.xcresult`, not scraped from the log
  tail. Clean `-derivedDataPath /tmp/dd-b20`, destination iPhone 17 / iOS 26.5 simulator.
- **The tested binary really was build 20.** `Genesyx.app/Info.plist` under that derived-data path
  reads `CFBundleVersion 20`, `CFBundleShortVersionString 1.2.0`. `project.pbxproj` was last written
  at 22:52:50 and `8df44db` was committed at 22:57:05, both before the run opened at 22:57:24, so
  nothing moved underneath it. This is the check the earlier build-19 run failed, and it is why that
  run's numbers are not carried forward here.
- **The one skip is declared, not silent.**
  `NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission` throws `XCTSkip`
  when iOS notification permission is already determined for the install: the pre-prompt is then
  correctly not shown, and XCUITest cannot reset that state because it is not an
  `XCUIProtectedResource`. To exercise the full opt-in path, `xcrun simctl uninstall booted
  com.genesyx.app` first, then run that test. The notification opt-in is therefore **not** covered
  by this run and belongs on the physical-device list below.
- **Do not pass `-quiet`.** It has returned exit 0 with no summary and hidden a real result.
- **Use a clean `-derivedDataPath`.** Shared DerivedData produced 6 failures on one run and 7 on the
  next from identical code, with only one test overlapping between them, while a clean path produced
  430/430 on the same tree. A UI failure that does not reproduce on a clean path is the environment,
  not the diff. Prove it by measurement before attributing it to code.
- **There is no iPhone 16 simulator on the build machine.** `-destination` must name one that
  exists, for example `platform=iOS Simulator,name=iPhone 17,OS=26.5`. A wrong destination returns
  exit 0 through a pipe while running nothing at all.
- **Never cut a build on the two fast suites alone.** A previous batch had 30 new tests green while
  the app terminated on opening a screen, from a missing `@EnvironmentObject`. Neither fast suite
  can see that class of fault. Budget the full UI run.
- **A green suite is not evidence the thing builds.** Build 18 was never archivable: a `#if DEBUG`
  import meant the Release configuration did not compile while every test target, all Debug, stayed
  green. Archive before every submission.
- **Build 20 archives and exports.** `8df44db` archived 17 Aug 23:18, signed
  `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)` with the "Genesyx App Store" profile (valid to
  9 July 2027), then exported to a signed 18 MB App Store IPA at `build/Export/Genesyx.ipa`. The IPA
  was opened and checked, not assumed: `CFBundleShortVersionString 1.2.0` / `CFBundleVersion 20`,
  `MinimumOSVersion 16.0`, `ITSAppUsesNonExemptEncryption` false, `PrivacyInfo.xcprivacy` present at
  the app root and in every SPM bundle, a 1024×1024 `AppIcon-1024.png` in `Assets.car`, and
  `get-task-allow` false in the embedded entitlements. This is the first provable archive of HEAD
  since 12 July.
- **Do not pass signing settings on the `xcodebuild archive` command line.** `CODE_SIGN_STYLE=
  Automatic` contradicts the Release `PROVISIONING_PROFILE_SPECIFIER` in `project.yml` and fails at
  exit 65 with "Genesyx has conflicting provisioning settings". A command-line setting also leaks
  into every SPM package target (GoogleSignIn, AppAuth, …), which cannot take a profile at all. The
  Release config already signs manually; leave the command line to paths and destination.
- **Delete the old archive before building.** A completion check of "does the directory exist" reads
  a *failed* archive as a success when a previous run's `.xcarchive` is still sitting there. Build 20
  was reported OK off a 12 July build-11 archive for exactly this reason. Check the exit code, and
  print the archived version out of `Info.plist` to prove which tree you are holding.

---

## What still needs a physical iPhone

None of the following is provable from the build machine, and none of it should be written up as
passed until someone has done it on hardware:

1. The nine-step password reset walk above, start to finish, including the second tap on a used link.
2. Staying signed in across a genuine cold boot, with a session restored from the Keychain rather
   than seeded by a test harness.
3. A token revoked from another device ending the session on this one.
4. Sign in with Apple on real hardware.
5. Account deletion end to end, with two throwaway accounts, against a project holding live profiles.
6. Turning on reminders from a fresh install: the pre-prompt sheet, then the iOS permission dialog,
   then a reminder actually arriving. The simulator run skips this and cannot restore the state that
   would let it run.
