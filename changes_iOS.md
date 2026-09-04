# Genesyx iOS Release Candidate Changes

Date: 2026-09-01

This document summarizes the iOS work completed for the Genesyx 1.2.0 build 25 release candidate. It is a companion summary to `CHANGES.md`, focused on what changed, how it behaves, and what still needs physical-device verification.

> **Superseded on 2026-09-04.** The release configuration below described build 25 and is now
> stale on both counts. Builds 25 and 26 have both been uploaded to App Store Connect, so
> neither number is available. The tree is at **1.2.1 build 27**, verified from the built
> product's own `Info.plist` (`CFBundleShortVersionString 1.2.1`, `CFBundleVersion 27`) rather
> than from the config alone, with `project.yml` and `project.pbxproj` agreeing. Build 27 also
> carries the new brand artwork and the dark-mode sign-in fix; see the 2026-09-04 evening entry
> in `to do list.md` for the evidence.

## Release Configuration

- Marketing version remains `1.2.0`.
- Build number is `25`, matching the next App Store Connect build after live build `24`.
- Bundle identifier remains `com.genesyx.app`.
- Direct App Store URL is configured as:
  `https://apps.apple.com/gb/app/genesyx/id6787682466`
- `project.yml` now carries the same App Store URL for future project regeneration.
- `App/Genesyx/Info.plist` contains the literal App Store URL because the generated Xcode project does not currently expose `APPSTORE_URL` as an effective build setting.
- No dependency versions were changed.
- No commit, archive, upload, or `app_config` deployment was performed.

## Task 1 - Incremental Sync

Implemented per-table incremental sync for growing history data to reduce repeated Supabase egress:

- Daily logs now support `updatedSince` pulls.
- pH records now support full first sync followed by incremental pulls.
- Supplements now support full first sync followed by incremental pulls.
- Sync cursors advance only after successful pulls.
- Cursors are cleared on local state wipe/sign-out/account switch.
- pH and supplement merges now have subset-safe incremental merge paths so unchanged local rows are not incorrectly marked pending.

`consent_events` intentionally remains a full fetch because its schema lacks a server-monotonic `updated_at` or `created_at` cursor column. Using the client-set `occurred_at` could miss backdated legal consent rows.

## Task 2 - Auth Email Rate Limits

Implemented rate-limit-aware email handling:

- Supabase email-send failures now map HTTP 429 and GoTrue over-limit codes to `RemoteError.rateLimited`.
- Confirmation resend applies a 60 second cooldown after any tap.
- Confirmation resend extends to five minutes when Supabase confirms rate limiting.
- Password reset shows rate-limit copy and applies a five minute cooldown on 429.
- Sign-up now surfaces the rate-limit message instead of a generic credential error when the confirmation email send is throttled.
- User-facing copy:
  `Too many attempts right now. Please wait a few minutes and try again.`

## Task 3 - Minimum-Version Gate

Implemented a fail-open minimum-version gate:

- Added pure `VersionGate` helpers for build parsing, comparison, current build lookup, and App Store URL resolution.
- Added `RootDestination.updateRequired`, ranked before other app routes.
- Added backend support for reading `app_config` key `min_supported_build`.
- `AppContainer.checkMinimumVersion()` runs at launch.
- Missing table, missing row, malformed value, and network errors all fail open.
- Added update-required UI with an Update button that opens `VersionGate.appStoreURL`.

Important release note: do not activate the server-side minimum-version gate until build `25` is live. Activating it while only build `24` is public could lock out current users.

## Task 4 - Privacy Log, Supabase Sign-Out, Preferences Pending Sync

Completed privacy and pending-sync fixes:

- Removed the email address from the unconditional Google sign-in success log.
- Preserved the non-PII success signal and `hasIDToken` status:
  `[GoogleSignIn] SDK sign-in OK. hasIDToken=...`
- Verified the installed `supabase-swift` dependency is `2.50.0` at revision `102a146b1a7066602d0d9d03bfa65936d123ed6a`.
- Verified `auth.signOut(scope: .global)` removes the SDK persisted session through `sessionManager.remove()`, `sessionStorage.delete()`, and the configured Apple `KeychainLocalStorage`.
- No manual Keychain clear was added, and no Keychain identifier was invented.
- Reused the existing pending-sync UI pattern in Profile.
- Profile preferences now expose a pending-sync flag and show a visible pending-sync row while an owed preference write remains.

## Release-Safe Concurrency Fix

The `FakeAuthBackend` test helper no longer carries a broad `@MainActor` annotation for the whole class. The smallest fix was applied by annotating only `emit(_:)`, which calls the main-actor lifecycle handler. This resolved the actor-isolation warning without using `@unchecked Sendable` or disabling concurrency diagnostics.

Removing the class-level annotation made `signIn` genuinely suspend, which is what the real Supabase backend does. That changed task ordering enough to expose the account-safety defect below — the concurrency fix did not cause the defect, it stopped hiding it.

## Account-Safety Fix - Owed Rename Across An Account Switch

`SessionRepository.drainPendingName()` pushed a pending display-name change without re-checking who was signed in at the moment of the write. `applySignIn` clears `pendingNamePush` when the identity changes, but a drain already scheduled holds that flag in memory and never sees the clear, so a rename owed by the previous account could land on the incoming account's `profiles` row.

- Added `signedInIdentity`, the account this repository instance signed in as, set in `applySignIn` and `restoreSignedIn` and seeded from the store on init.
- `drainPendingName()` now stands down when `signedInIdentity` no longer matches the device's current `session_identity`.
- The guard deliberately performs no write. Clearing `pendingNamePush` there would persist through its `didSet` and discard a rename the incoming account legitimately owes.

Scope: `App/Genesyx/Data/SessionRepository.swift` only. No version, Supabase, Android, or app-configuration change.

Tests:

- Added `testADrainHeldByTheReplacedAccountCannotPushOntoTheNewOne`, which drains the replaced account's repository explicitly instead of relying on a background task firing at the right moment.
- Falsified: with the new guard removed, that test fails with `XCTAssertNil failed: "Ada Lovelace"`.
- Modified the pre-existing `testADifferentAccountSigningInDropsTheOwedRename`. An interim version of this change reordered the test so the fake backend only came online after the switch; that made it deterministic but cost it the ability to detect this defect. It has since been restored to its original ordering — see the test-fidelity section below, which removed the reason the reorder was needed.

## Test-Fidelity Correction - Per-Account Profile Rows In `FakeProfileBackend`

No production file was edited in this task. The `drainPendingName` guard above is unchanged.

`display_name` lives on a per-account row, but `FakeProfileBackend` held a single global `displayName` shared by roughly fifteen tests. That made an account switch unreadable: a write the signed-in account was entitled to make could be read back after a switch as though it had landed on the account that replaced her. A test could only separate the two by controlling when the server was reachable, which left the result at the mercy of task scheduling.

- `FakeProfileBackend` now stores `namesByUserId` and resolves the row through `authenticatedUserId`, which stands in for `auth.uid()` — the thing the real backend resolves the row from. Neither `fetchDisplayName()` nor `upsert(displayName:)` takes an account, exactly as in production.
- `displayName` remains as a computed property over the authenticated row, so the single-account tests are untouched; `authenticatedUserId` defaults to a `soleAccount` key they never set.
- Added `displayName(of:)` so an account-switch test can assert against each woman's row independently instead of inferring a leak from one shared slot.
- `MidFetchProfileBackend`, the other profile double, is single-account only and was left unchanged.

`testADifferentAccountSigningInDropsTheOwedRename` is restored to its original ordering, with the server reachable throughout as it is on a real handover, and now asserts on Bea's row specifically. Its subject is the `applySignIn` clear, not the drain race.

`testADrainHeldByTheReplacedAccountCannotPushOntoTheNewOne` now gives Bea a real name on her row before the stale drain resumes, so the assertion distinguishes "Ada's name landed on Bea" from "Bea's name was wiped". It also asserts the legitimate case first: a rename Ada makes while signed in reaches her row and no other.

Falsification, run after the double was corrected:

- Guard present: both focused tests pass.
- Guard temporarily disabled: `testADrainHeldByTheReplacedAccountCannotPushOntoTheNewOne` fails with `XCTAssertEqual failed: ("Optional("Ada Byron")") is not equal to ("Optional("Bea Nightingale")")` — Ada's queued rename overwrote Bea's row, which is the defect exactly.
- Guard restored and byte-compared against a pre-experiment copy: identical, `+17` lines, no falsification markers remaining.
- Separately, with `applySignIn`'s `pendingNamePush = false` removed and the guard present, the restored pre-existing test fails with `XCTAssertNil failed: "Bea"`, confirming it still guards its own distinct subject.

## Verification Performed

- Xcode source diagnostics were clean on the touched Swift files checked through Xcode.
- `plutil -lint App/Genesyx/Info.plist` passed.
- `git diff --check` passed.
- `git diff --cached --check` passed.
- Effective Xcode build settings reported:
  - `MARKETING_VERSION = 1.2.0`
  - `CURRENT_PROJECT_VERSION = 25`
  - `PRODUCT_BUNDLE_IDENTIFIER = com.genesyx.app`
- Apple lookup for app id `6787682466` returned the real Genesyx listing with bundle id `com.genesyx.app`.
- No service-role key, database password, or health-data logging was introduced.

## Test Status

An earlier pass recorded that no concrete iOS simulator was available and that only `Any iOS Device` and `Any iOS Simulator Device` were offered. That was incorrect. `xcrun simctl list devices available` reports twelve available iOS 26.5 simulators under Xcode 26.6, two of them already booted.

All three suites were executed on 2026-09-01 against `iPhone 17 Pro`, iOS 26.5, simulator `6505B00C-85D3-4A48-B312-A016545787F2`.

| Target | Executed | Passed | Failed | Notes |
| --- | ---: | ---: | ---: | --- |
| `GenesyxCorePackageTests` | 314 | 314 | 0 | `swift test`, macOS host |
| `GenesyxAppTests` | 383 | 383 | 0 | 125 of them `RepositoryTests` |
| `GenesyxUITests` | 99 | 94 | 4 | 1 skipped; none attributable to this work, see below |

Exact commands:

- `swift test`
- `xcodebuild test -scheme Genesyx -destination 'platform=iOS Simulator,id=6505B00C-85D3-4A48-B312-A016545787F2' -only-testing:GenesyxAppTests`
- `xcodebuild test -scheme Genesyx -destination 'platform=iOS Simulator,id=6505B00C-85D3-4A48-B312-A016545787F2' -only-testing:GenesyxUITests`
- `xcodebuild build -scheme Genesyx -destination 'platform=iOS Simulator,id=6505B00C-85D3-4A48-B312-A016545787F2'` - `** BUILD SUCCEEDED **`

Build warnings: one, unrelated and pre-existing - `appintentsmetadataprocessor ... Metadata extraction skipped. No AppIntents.framework dependency found.` Zero compiler warnings.

### `GenesyxUITests` Failures

The UI suite is order- and load-dependent. Three full runs on the same commit produced three different failing sets, all drawn from the pool below, with only the first two constant. No UI test file was edited.

The test-double change in this task cannot reach the UI suite at all, and this is structural rather than a judgement: `project.yml` gives `GenesyxAppTests` the sources `App/GenesyxTests` and `GenesyxUITests` the sources `App/GenesyxUITests`. `RepositoryTests.swift` lives in the former, so it is never compiled into the UI test bundle.

A full clean-`HEAD` baseline was then run in a detached `git worktree` at `/private/tmp/genesyx_head`, on the same simulator, to settle the question with evidence rather than reasoning. It executed 98 tests, skipped 1, and failed 2: `testAnAlreadyLoggedPastDayCanBeCorrectedWithoutLosingWhatWasThere` and `testTheOptionalAnswerCanBeWithdrawnInTrackingPreferences`. The working tree executed 99, skipped 1, and failed 4. The two runs therefore disagree in *both* directions - clean `HEAD` failed a test the working tree passed - which is the signature of a load-dependent suite, not of a regression. The count differs by one because `testDemoWalkthrough` only exists in the UI target in the working tree.

- `testDemoWalkthrough` - environmental, every run. The missing requirement is the `DEMO_PASSWORD` environment variable in the command-line runner; the test asserts its own precondition and reports it. It passes when run through the Xcode scheme, which supplies `DEMO_PASSWORD = $(DEMO_PASSWORD)`. No clean-`HEAD` baseline is available for this one, because at `HEAD` the file is still at `Genesyx.xcodeproj/GenesyxUITests/DemoWalkthroughTests.swift` and is not a member of the UI target, so it does not run there at all.
- `testAnAlreadyLoggedPastDayCanBeCorrectedWithoutLosingWhatWasThere` - date-dependent, every run. `AppContainer.uiTestSeeded()` writes daily logs at `today().minusDays(1)` and `minusDays(3)`, while the test asserts a logged day exists in the *current* calendar month. Run on 1 September those seeds land on 31 and 29 August, so the September calendar carries none. **Baseline: reproduced on a clean `HEAD` worktree**, failing at the same `GenesyxUITests.swift:495` with the same message. A genuine defect in the test rather than the app; worth fixing by seeding a day guaranteed to fall inside the displayed month.
- `testMandatorySignInOffersPasswordRecovery` - order/load-dependent. Failed in one run, passed in the next two, and passes in isolation on clean `HEAD`. The `auth.forgotPassword` identifier is present on the mandatory sign-in screen.
- `testASupplementIsAddedWithOneOfTheFourSharedTimes` - order/load-dependent. `Failed to not hittable: Button ... label: 'Review Plan'`. Passes in isolation in the working tree **and** on clean `HEAD`, and did not fail in the full clean-`HEAD` run either, so it is not attributable to this change.
- `testCancellingAPhEditKeepsTheReadingAndDeletingAsksFirst` - order/load-dependent. `Failed to tap "ph.deleteReading" Button: No matches found`. Passes in isolation in the working tree **and** on clean `HEAD`, and did not fail in the full clean-`HEAD` run either, so it is not attributable to this change.
- `testTheOptionalAnswerCanBeWithdrawnInTrackingPreferences` - order/load-dependent, and the clearest evidence of it. This one failed **only** on clean `HEAD`, in the full baseline run, and passed in every working-tree run. A change cannot cause a failure that happens without it.
- `testTurningOnRemindersExplainsFirstThenAsksPermission` - skipped, not failed, and self-documenting: notification permission is already determined for the install, so the pre-prompt is correctly not shown. Exercising the full opt-in path needs a fresh install.

## Runtime Verification On Simulator

Performed on the same simulator, build `25`:

- The app installs, launches and reaches the sign-in screen with no crash.
- The minimum-version gate fails open as designed. The live project returns `PGRST205 Could not find the table 'public.app_config'` and the app proceeds, which also confirms the server-side gate is still inactive.
- All seven tabs render real content: Home, Track, pH, Nutrition, Insights, Learn, Profile.
- The compiled `Info.plist` in the built app reports `CFBundleShortVersionString 1.2.0`, `CFBundleVersion 25`, `CFBundleIdentifier com.genesyx.app`.
- The Google sign-in success log prints only `hasIDToken=`, with no email address.
- No service-role key or database password appears in the app sources or in `Secrets.xcconfig`.

One observation for the physical-device script below: uninstalling the app does **not** sign the user out. After `simctl uninstall` followed by a fresh install, the app returned already signed in, because the Supabase session lives in the Keychain and the Keychain survives app deletion. The account-deletion checks should be read with that in mind.

## Physical-Device QA Script

This pass has not been executed yet. Run it on a connected iPhone or a concrete iOS simulator, using a real tester mindset and recording every failed expectation with screen, action, observed result, expected result, and account state.

### Install And Launch

- Build and install `Genesyx` build `25` from Xcode.
- Confirm the app launches without crash.
- Confirm the first visible route is correct for the current auth state.
- Confirm there is no unsupported-version block while `app_config.min_supported_build` is absent.
- Confirm no generic App Store fallback is used when the update button is exercised in a controlled gate test.

### Auth

- Sign in with an existing confirmed email/password user.
- Sign out and confirm the app returns to the auth gate.
- Create a new throwaway account.
- Confirm the confirmation-email-required state is clear and usable.
- Tap resend confirmation once and confirm the 60 second cooldown appears.
- If Supabase rate limits the request, confirm the five minute cooldown and copy:
  `Too many attempts right now. Please wait a few minutes and try again.`
- Confirm the received confirmation email opens the app/session correctly.
- Trigger forgot password from the sign-in screen.
- Confirm the reset email is received and the link route works.
- Exercise Google sign-in and confirm the app session is created without logging the email address.
- Exercise Sign in with Apple if available on the test device.

### Main Navigation

- Visit every tab from `MainTabView`.
- Confirm each tab renders without empty/error placeholder states unless expected.
- Confirm tab switching preserves reasonable state and does not trigger auth loss.
- Rotate or background/foreground the app if supported by the target device settings.

### Home

- Confirm Home loads after login.
- Confirm any summary cards, today's status, reminders, or primary actions render with real account state.
- Tap every visible primary action and confirm the destination is correct.

### Track And Daily Log

- Create a daily log entry.
- Edit the same daily log entry.
- Leave the screen and return; confirm the data remains.
- Force relaunch and confirm the data reloads.
- Make an offline edit, close/reopen, reconnect, and confirm pending sync drains.

### pH

- Add a pH entry.
- Edit or remove an entry if the UI supports it.
- Confirm the pH history/chart/list updates.
- Force relaunch and confirm the pH entry reloads.
- Make an offline pH entry and confirm pending sync drains after reconnect.

### Supplements

- Add or update a supplement entry.
- Confirm the supplement appears in the expected screen.
- Force relaunch and confirm it reloads.
- Make an offline supplement change and confirm pending sync drains after reconnect.

### Profile And Preferences

- Change a profile preference.
- Confirm the preferences pending-sync row appears while a write is owed.
- Confirm it disappears after sync succeeds.
- Edit cycle settings and confirm the changed values persist.
- Open medical sources and confirm citations/source links still render.
- Confirm sign-out clears local private data from the UI.

### Learn, Nutrition, Insights, Invite

- Open Learn and at least one article/guide.
- Open the free guide PDF flow.
- Open Nutrition and confirm hydration/nutrition values render correctly.
- Open Insights and weekly summary.
- Open Invite/share flow and confirm the system share sheet appears.

### Account Deletion

- Delete the throwaway account.
- Confirm the app returns to the signed-out state.
- Confirm local daily logs, pH entries, supplements, profile preferences, and session state disappear after deletion.
- Relaunch the app and confirm the deleted account is not silently restored.

### Production Safety Checks During QA

- Watch Xcode console for PII. The Google success log must not print email addresses.
- Confirm no health values are emitted to logs.
- Confirm no service-role key or database password appears in logs or runtime config.
- Do not activate server-side minimum-version gating until build `25` is live.

## Files Changed By The iOS Release Work

- `App/Genesyx/Data/App/AppContainer.swift`
- `App/Genesyx/Data/App/GenesyxApp.swift`
- `App/Genesyx/Data/App/RootRouting.swift`
- `App/Genesyx/Data/App/RootView.swift`
- `App/Genesyx/Data/DailyLogRepository.swift`
- `App/Genesyx/Data/PhRepository.swift`
- `App/Genesyx/Data/PreferencesRepository.swift`
- `App/Genesyx/Data/Remote/RemoteBackend.swift`
- `App/Genesyx/Data/Remote/RemoteModels.swift`
- `App/Genesyx/Data/Remote/SupabaseBackend.swift`
- `App/Genesyx/Data/SessionRepository.swift`
- `App/Genesyx/Data/SupplementsRepository.swift`
- `App/Genesyx/Info.plist`
- `App/Genesyx/UI/Auth/AuthView.swift`
- `App/Genesyx/UI/Profile/ProfileView.swift`
- `App/GenesyxTests/PasswordResetTests.swift`
- `App/GenesyxTests/RepositoryTests.swift`
- `App/GenesyxTests/RootRoutingTests.swift`
- `CHANGES.md`
- `Sources/GenesyxCore/Models/SupplementSync.swift`
- `Sources/GenesyxCore/Ph/PhSync.swift`
- `project.yml`

## Other Dirty Files Observed

These files were present in the working tree but were not part of the release feature implementation:

- `.gitignore` - local/tool ignore additions.
- `Genesyx.xcodeproj/project.pbxproj` - contains pre-existing project membership changes plus the confirmed build `25` setting.
- `App/GenesyxUITests/DemoWalkthroughTests.swift` - relocated from the Xcode project path into the app UI test folder.
- `App_Inventory.md` - documentation/status note.
- `docs/LAUNCH_READINESS.md` - launch/security documentation.
- `to do list.md` - planning/status log.
- `graphify-out/*` - generated/tool output.

These were not reverted or discarded.

## Release Diff Review - 1.2.1 (25) Candidate

A read-only code review was run over the working-tree production changes intended for 1.2.1, covering the four clusters: incremental sync, the minimum-version gate, the auth email cooldown, and the account/profile surfaces. No file was modified during the review itself. Green tests were explicitly not treated as a substitute for reading the diff, and the review found a defect the suites do not detect.

### The incremental sync cursor is written from the wrong clock

Each of the three synced repositories now stores a cursor and sends it to PostgREST as a `.gte("updated_at", ...)` filter. The cursor is taken from `let startedAt = Date()` - *this* device's clock - at `DailyLogRepository.refresh()` line 205, `PhRepository.refresh()` line 102 and `SupplementsRepository.refresh()` line 115.

The values it is compared against are not written by that clock. `PhReadingRow.updatedAt` is a non-optional field the client always fills from `record.updatedAt` (`RemoteModels.swift` lines 67 and 102), and `UserSupplementRow.updatedAt` does the same at lines 345 and 381 against a column that carries only `default now()` and has no bump trigger in `20260813_android_supplements_backend.sql`. So phone B's cursor is being compared against timestamps authored by phone A's clock. The 60-second `cursorOverlap` absorbs ordinary drift and nothing more. Beyond it, rows are silently skipped and the cursor still advances past them, so they are never fetched again - the loss is permanent short of a sign-out, and it is health data.

The review also raised `daily_logs` as a second, separate P0, on the grounds that `DailyLogRow.updatedAt` is written as `nil` at `RemoteModels.swift` line 171 while the only `daily_logs` trigger in the repository is `before update` (`20260712_sync_hardening.sql` lines 62-64) and no `create table` for it exists in any migration here. **That finding was wrong and is withdrawn.** The schema verification below shows the live column is `not null default now()`, and because Swift's synthesized `Codable` encoder uses `encodeIfPresent`, a `nil` optional omits the JSON key entirely rather than sending `null` - so the default fires and the server stamps the row. Corroborating: a `not null` column with no default and an omitted key would fail every insert, and daily-log inserts work in production.

`20260712_sync_hardening.sql` also contradicts itself about `ph_readings`: lines 34-39 state that a server trigger owns the column, and lines 72-77 warn that no trigger may bump it and say to drop one if found. Which is true in the live database changes the shape of the first finding but not the fact of it, because a client-authored cursor and a server-authored column are just as mismatched as two client clocks.

The fix for all of it is one change: take the next cursor from the maximum `updated_at` in the rows just returned, falling back to the existing cursor when the response is empty. Server-authored timestamps compared against server-authored timestamps have no skew to absorb and no dependence on which side stamps the column.

### What the review cleared

The merge logic itself is right. `PhSync.mergeIncremental` (line 71) and `SupplementSync.mergeIncremental` (line 79) correctly drop the clause that flags a local-only row as pending: under a partial pull, a row's absence from the response proves nothing about the server, whereas under a full snapshot it proved the row was never sent. Local pending work is protected from being overwritten by the incoming copy.

Failure handling is also correct. Every repository returns before assigning the cursor when the fetch fails, so an offline or timed-out refresh cannot advance past data it never received. Backward compatibility needs no migration: with no stored cursor the first launch after the update takes the `since == nil` branch and runs a full fetch through the original `merge`, and `clearLocalState()` nils the cursor so the next account starts from a full history rather than inheriting the previous one's position.

The version gate fails open at every step in `AppContainer.checkMinimumVersion()` lines 84-91 - no backend, a nil minimum, or a thrown error all return without gating - so neither a missing `public.app_config` nor a malformed value can block launch. It is inert in this build regardless, since the table does not exist. `VersionGate.appStoreURL` reads `APPSTORE_URL` from the app's own bundle and never from the server, so there is no open-redirect path, and both build systems deliver the value: `Info.plist` carries the literal and the pbxproj app target uses `INFOPLIST_FILE` with no `GENERATE_INFOPLIST_FILE` at lines 867 and 893.

The Google sign-in log line at `AuthView.swift` line 236 previously printed her email address and now prints only whether an ID token was returned. That is a straight privacy improvement in the shipped build. `ChangePasswordSheet.submit()` lines 900-916 deliberately swallows the raw error rather than surfacing or logging it, on the stated grounds that it can carry token and account detail.

All four profile sub-tabs were traced from the tap through to the backend write. Personal Details, Change Password, Health Profile and Tracking Preferences each pass. The refused-save case on Tracking Preferences is properly closed on three levels: the Save button is disabled while consent is withdrawn, `ConsentWithdrawnBanner` explains why above the questions, and `recordQuizAnswers` returning false keeps the sheet open so a refused write cannot dismiss exactly as a successful one did.

### Held for follow-up

The version gate has no un-gate path. `updateRequired` is set once at launch from `GenesyxApp.swift` line 59 and is never re-checked or reset, so once `public.app_config` exists a wrong `min_supported_build` becomes an irreversible lockout with no client-side recourse. A re-check on foreground should land before that table is ever created, and the anon RLS policy on it must expose the `min_supported_build` row and nothing else.

Two smaller items. `pendingPush` in `PreferencesRepository` is not `@Published`, so the new pending-sync chip appears reliably - it is always set alongside a published write - but `drainPending()` clears it at line 270 with no published change on the success path, and the chip can therefore linger after the sync has actually landed. And the comment at `RootRouting.swift` lines 85-87 claims a missing `CFBundleVersion` fails open, when `0 < minimum` is true for any minimum at all; the behaviour is unreachable under `INFOPLIST_FILE` and only the comment is wrong.

## Production Schema Verification - `updated_at` Ownership

Read-only catalogue queries were run against the live shared backend (project `epltxklawpcxxbaleswg`). No table, policy, function, trigger, index or row was created, altered or dropped, and no application-row data was read.

| table | `updated_at` nullable | default | insert trigger | update trigger |
| --- | --- | --- | --- | --- |
| `daily_logs` | no | `now()` | none | `daily_logs_bump_updated_at`, `set_daily_logs_updated_at` |
| `ph_readings` | no | `now()` | none | `trg_ph_readings_updated_at` |
| `user_supplements` | yes | `now()` | none | none |

So the effective owner of the clock differs per table and per path. `daily_logs` is server-authored on both insert and update, because the client omits the key and the default fires. `ph_readings` is **client-authored on insert** - the client sends a non-optional string - and server-authored on update. `user_supplements` is client-authored on both.

Three contradictions between the migrations in this repository and the live database were found and are recorded here rather than acted on. `20260712_sync_hardening.sql` lines 72-77 instruct dropping any bump trigger on `ph_readings`; production has one, and following that instruction would remove the only server stamping that table gets. `daily_logs` carries a second, undocumented trigger (`set_daily_logs_updated_at` calling `touch_updated_at()`) doing the same job as the documented one. And `daily_logs` still has no `create table` in any migration here. RLS is enabled on all three tables with one `authenticated`-only owner policy each and no `anon` policy.

## P0 Fix - The Sync Cursor Is Now Read Off The Server's Rows

The cursor is no longer minted by the device. A pull now returns the rows *and* the only cursor those rows license, and the repository stores that or nothing at all.

`SyncPage<Payload>` in `Remote/RemoteBackend.swift` carries `payload` plus `latestUpdatedAt`, and the three `list(updatedSince:)` signatures return it. The value is computed in `SupabaseBackend.swift` by `syncCursor(from:)`, reading the **raw `updated_at` column off the row structs before they are mapped to domain values**. That detail is the fix's own trap: the existing `parseISO` in `RemoteModels.swift` falls back to `Date()` for anything it cannot parse, so deriving the cursor from an already-decoded domain value would have smuggled the device clock straight back in. `serverTimestamp(_:)` is the same parse without that fallback, and `syncCursor(from:)` returns the greatest stamp across the page, or `nil` the moment any one row's stamp is missing or unreadable.

The rule the repositories apply:

- the next cursor is the maximum non-nil server `updated_at` among the rows *that specific fetch* returned;
- `nil` - no rows, or any unreadable stamp - holds the cursor exactly where it is;
- the cursor only ever moves forward, so a lagging replica cannot drag it backwards;
- a failed or refused fetch never reaches the assignment at all;
- the 60-second `cursorOverlap` rewind is unchanged, and can now only ever re-fetch rows, never step over them.

`daily_logs` needed the protocol change rather than a local calculation because `DailyLog` carries no timestamp of its own - it is the day's content, keyed by date - so the column is gone by the time the pull has a domain value to inspect.

**Residual risk, deliberately not fixed here.** `ph_readings` and `user_supplements` still have client-authored `updated_at` on insert. The cursor fix is a strict improvement for them - the cursor is now a value the server actually stored, and no local `Date()` reaches it - but a phone with a skewed clock can still write a row stamped in the past that another device's cursor has already moved beyond. Closing that requires a `before insert or update` trigger on both tables server-side and the client ceasing to send the column. That is a backend change and is outside this authorisation.

### Tests and falsification

Ten cursor tests were added to `App/GenesyxTests/RepositoryTests.swift`, covering: a server stamp decades behind the device clock (the skew case); the cursor being the maximum returned stamp rather than the first or last; an empty pull holding the cursor; a failed pull holding an already-established cursor; an unreadable stamp holding the cursor while still keeping the rows the pull did return; the cursor refusing to move backwards; `syncCursor`/`serverTimestamp` pinned directly, including that they have no `Date()` fallback; the same rules exercised through `DailyLogRepository`; and an overlapping re-fetch that must neither clobber a day still owed nor lose it once the transport recovers.

Two existing tests were adapted, not weakened. `testPhSyncIsFullThenIncremental` and `testPhCursorPersistsAndClearsOnWipe` previously pulled an *empty* remote and relied on the old behaviour of advancing the cursor anyway; each is now seeded with one server row, which preserves the property each was written to prove.

The old logic was falsified. Restoring `lastSyncedAt = Date()` in both `DailyLogRepository.refresh()` and `PhRepository.refresh()` turned 8 test cases red with 10 assertion failures, the clearest reading `("1788302027.92") is not equal to ("1000.0")` - the device clock where the server's stamp belongs. The safe implementation was restored immediately and no temporary code remains (`grep -r FALSIFICATION App/ Sources/` returns nothing).

Results after the fix: `GenesyxAppTests` 393 executed, 0 failures. `GenesyxCorePackageTests` 314 executed, 0 failures. `Genesyx` scheme build succeeded. `git diff --check` clean.

Files changed: `App/Genesyx/Data/Remote/RemoteBackend.swift`, `App/Genesyx/Data/Remote/RemoteModels.swift`, `App/Genesyx/Data/Remote/SupabaseBackend.swift`, `App/Genesyx/Data/DailyLogRepository.swift`, `App/Genesyx/Data/PhRepository.swift`, `App/Genesyx/Data/SupplementsRepository.swift`, `App/GenesyxTests/RepositoryTests.swift`, `changes_iOS.md`. Nothing was committed, archived, uploaded, or regenerated; no version or build number was touched; no Supabase object was modified.

## Password-Reset Parity Audit

The signed-out reset flow was audited end to end against the shared Supabase configuration: request in `AuthView.sendReset()`, send in `SupabaseAuth.resetPassword(email:)` with `redirectTo: DeepLink.passwordRecoveryURL`, callback recognition in `DeepLink.isPasswordRecovery(_:)`, delivery through `RootView.onOpenURL`, PKCE redemption in `completePasswordRecovery(url:)`, routing precedence in `RootRouting.destination`, and completion in `ResetPasswordView.submit()`.

Redirect compatibility is confirmed by construction rather than by assumption. `DeepLink.passwordRecoveryURL` is the literal `genesyx://reset-password`, `DeepLinkTests.testTheRecoveryRedirectIsTheExactStringAllowListedInSupabase` pins that exact string, and the installed simulator bundle declares the `genesyx` scheme in `CFBundleURLTypes`. A synthetic callback carrying a deliberately invalid code was opened against the installed build: the app came to the foreground, the URL was routed as recovery rather than as an invite, the PKCE exchange failed as it should for a code this device never issued, and the "That link didn't work" screen rendered with actionable copy and no token or raw error. No email was sent to obtain that result.

The routing precedence is the load-bearing part and it is correct: `passwordRecovery` is evaluated before session state, so the genuine session the link mints cannot drop her into the tabs with her old password still valid. It sits below `updateRequired` and `unavailable` and above `consentRequired`, which is the only workable order.

### Defect found: the reset button had no cooldown

`sendReset()` called `startResetCooldown` only in the confirmed-429 branch. A successful send left the button live, so "Forgot password?" could be tapped repeatedly and each tap sent a real email. The built-in Supabase sender is capped at two emails per hour for the whole project, so two taps could exhaust the allowance for every user and every kind of auth mail, including sign-up confirmations. The adjacent `resendConfirmation()` already applied the 60-second floor on any tap for exactly this stated reason, and the doc comment on `normalCooldown` already described the intended behaviour as "60s after any resend tap". `AuthEmailFailure.cooldownSeconds(for:)` existed and was covered by tests but was never called by the app.

The fix is confined to `sendReset()`: the 60-second floor is applied before the send, and the failure branch now derives its duration from `cooldownSeconds(for:)`. Both durations are unchanged - 60 seconds normally, 300 after a confirmed rate limit. No other file was touched.

### Verification

`git diff --check` clean. Focused password-reset, deep-link and routing tests: 59 executed, 0 failures. Full `GenesyxAppTests`: 393 executed, 0 failures. `GenesyxCorePackageTests`: 314 executed, 0 failures. `Genesyx` scheme builds.

**The cooldown gap is now closed, without sending anything.** The wiring is SwiftUI `@State`, which a unit test cannot reach, but a UI test can - and `-uiTestSeed` resolves a backend-less container, so the tap fails locally with `notConfigured` and cannot reach Supabase. `AuthGateUITests.testForgotPasswordDisablesItselfForOneMinuteAfterASingleTap` taps the control once and asserts it becomes disabled, relabels to "Try again in 60s", and shows the failure copy rather than the sent-link copy.

That test discriminates. Restoring the pre-fix behaviour locally - cooldown only inside the 429 branch - fails it on `label BEGINSWITH "Try again in"` never becoming true, because under the old code every non-429 outcome, a successful send included, left the button live. The fix was restored immediately and no temporary code remains.

Two more UI tests cover the link surface with synthetic URLs only: an unredeemable `genesyx://reset-password?code=...` reaches the error state and offers no password field, and neither a wrong host nor a look-alike https URL is routed into recovery. `AuthGateUITests`: 18 executed, 0 failures.

**What still needs a real device.** Email delivery, and redeeming a genuine PKCE link on the same install. The simulator cannot prove either, and neither is claimed here.

No email was sent during this audit. No archive, upload, commit, version change, or Supabase dashboard, schema or data change occurred.

## Current Verdict

READY FOR VERSION/URL EDITS

Executable test verification is complete. All suites were run on a concrete simulator after the fix: 393 app tests and 314 core tests, 0 failures, and the app scheme builds. The P0 the release-diff review found is fixed at its root, covered by tests, and falsified by restoring the defect and watching those tests go red.

Before upload:

1. `MARKETING_VERSION` is still `1.2.0` in both `project.yml` line 82 and `project.pbxproj` lines 872 and 898. Both must read `1.2.1`, since CI regenerates from `project.yml` while local archives build from the committed pbxproj. `CURRENT_PROJECT_VERSION` is already `25` in both.
2. Physical-device smoke testing, using the script below, with a two-device pass in which one device's clock is deliberately set forward fifteen minutes. Note that the Keychain survives app deletion, so an uninstall does not sign the tester out.
3. The `ph_readings` / `user_supplements` insert-stamping gap above. It does not block this release, but it is the remaining half of the same class of bug and should be closed server-side.
4. The date-dependent `testAnAlreadyLoggedPastDayCanBeCorrectedWithoutLosingWhatWasThere` seeding defect. A test bug rather than an app bug; it should be fixed so the suite is trustworthy on the first three days of any month.
5. The version gate still has no un-gate path (see "Held for follow-up"). It is inert while `public.app_config` does not exist, and a foreground re-check should land before that table is ever created.

## Brand Assets - Logo Replacement (4 September 2026)

The app icon and the in-app brand lockup were replaced with the new gradient "G" mark. This is an asset-only change. No Swift file was edited, no view was restructured, and no build setting was touched.

### App icon

`AppIcon-1024.png` is a new full-bleed 1024x1024 RGB image with no alpha channel, as the App Store requires. The supplied artwork arrived with rounded corners already drawn into it and white padding behind them, which would have shown as pale wedges once iOS applied its own squircle mask on top. The gradient was extended into those four corners instead, seeded from saturated interior colour and feathered so no seam is visible. Corner pixels now read (0,231,254), (0,59,249), (40,11,211) and (252,87,107) rather than white. `sips` confirms 1024x1024 and `hasAlpha: no`.

That corner pass fixed the corners but left the edges short. A near-white fringe up to 7px deep survived along the middle 60 per cent of all four sides (top 5px, the other three 7px; 610 of 1024 pixels on each edge row or column read above 0.90 in all three channels). Those midpoints are the one part of the boundary the system mask keeps — the squircle is inscribed in the square, so it touches the centre of each side and discards the corners. The repaired corners were being thrown away and the unrepaired edges were what actually showed, as a faint white rim roughly 1.2px wide at @3x. Fixed by resampling the artwork to 1044x1044 and centre-cropping back to 1024, which carries the gradient past all four midpoints without redrawing anything. Re-measured after the fix: fringe depth 0px on all four sides and 0 of 1024 near-white pixels on every edge row and column, still 1024x1024 with `hasAlpha: no`.

`AppIcon-1024-dark.png` is new and is the iOS 18 dark-appearance variant, declared in `Contents.json` with `"appearance": "luminosity", "value": "dark"`. It is built from the supplied `logo_white.png` (1254x1254, true alpha, glyph 1015x990), placed on transparency at 62 per cent scale and centred, so the system supplies the dark backing plate. That file is a later and cleaner rendition of the mark than the first source used: the ring stroke is thinner and the dot is properly detached. A separate navy-background file was also supplied for this slot and was deliberately not used, because it carried visible upscaling artefacts.

### In-app lockup

`brand_lockup.png` and `brand_lockup_dark.png` were rebuilt at their existing 718x172 size, both from `logo_white.png` so that every surface now carries the same rendition of the mark. Only the mark was replaced; the "ENESYX" wordmark was not touched, and the light and dark files keep their existing black and white text respectively. The new mark was scaled into the same 124x125 box the old one occupied, so every call site keeps its current layout. Three views render this asset and none of them needed changing: `AuthView.swift:305`, `OnboardingFlowView.swift:103` and `ResetPasswordView.swift:84`.

The wordmark in both lockups has hard, un-anti-aliased edges. That is pre-existing in the shipped files, identical in the light and dark versions, and was measured rather than assumed: zero partial-alpha pixels across the wordmark region of both. It is not a regression from this change and is invisible at the 220pt render width.

### Consistency check on the light icon

The light `AppIcon-1024.png` glyph was deliberately **not** redrawn. Its white knockout was compared against the `logo_white.png` glyph at matched scale and the shape intersection-over-union is 0.913, so it already carries the current drawing. Redrawing it would have meant inventing a full-square gradient to knock the letter out of, which is a real risk of regression for no visible gain. The older lockup mark was the genuine outlier at 0.856, and that is the one that was replaced. Only the framing changed, through the uniform resample described above, which scales the glyph by 1.95 per cent and keeps it centred.

### Verification

Verified on the iPhone 17 simulator from a real build: the new home-screen icon renders, and the new lockup renders in the auth and onboarding surfaces.

Not verified, and not claimed: the dark app icon variant. `xcrun assetutil --info` confirms the dark rendition is compiled into `Assets.car` with `Opaque: false`, so the asset is correct, but the simulator did not render a dark variant for any app including Apple's own, so no render evidence exists. It needs a physical device or a TestFlight install. The dark lockup is likewise asset-verified only, because the app forces its own colour scheme from `PreferencesRepository.themeMode`, which defaults to `.light`, and the seeded UI-test container uses an in-memory store that the launch argument cannot reach.

### Before the next upload

`CURRENT_PROJECT_VERSION` is now `27` in both `project.yml` and `Genesyx.xcodeproj/project.pbxproj`, because build 26 was submitted to Apple on 3 September 2026 and App Store Connect rejects a duplicate build number. `MARKETING_VERSION` stays `1.2.1`.

The two files had drifted before this edit: the pbxproj read `26` while `project.yml` still read `25`. Local archives build from the pbxproj and CI regenerates from `project.yml`, so that gap would have produced two different builds claiming different numbers depending on where they were built. Both now agree.

This was verified from the product rather than from the config: the built `Genesyx.app/Info.plist` reports `CFBundleVersion 27` and `CFBundleShortVersionString 1.2.1`. No test pins the build number, confirmed by searching all three test targets.

**Build 26 does not carry the new logo.** The archive is at `build/Genesyx-1.2.1-b26.xcarchive`, not under `~/Library/Developer/Xcode/Archives/`, which is why the daily archive check in `to do list.md` reported no build after 25 — it only inspects the Xcode Organizer path. Its `Info.plist` reads `1.2.1` / `26` with a creation date of 3 September 16:50, and every file in this brand change reached disk on 4 September. The icon inside that archive is the previous pale-lavender mark. So the build now sitting in App Store Connect shows the old logo, and build 27 is the first one that ships the new one. An App Store icon is read from the uploaded binary and cannot be replaced from the App Store Connect web interface, so there is no way to correct the listing except by shipping 27.

Post-change test status on the iPhone 17 simulator: `GenesyxAppTests` 393 passed, 0 failed, 0 skipped; `GenesyxCorePackageTests` 314 passed, 0 failed.

### Not yet possible from this machine

fastlane is not installed. There is no `Gemfile`, no `.bundle`, and nothing on `PATH`, so the `Fastfile` lanes in this repo cannot run here despite being committed. `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH` are also all unset. Distribution therefore has to go through Xcode's Organizer, or fastlane has to be installed and the API key configured first.

An App Store icon cannot be swapped from the App Store Connect web interface. It is read from the uploaded binary, so this change reaches customers only through a new build and a new review.
