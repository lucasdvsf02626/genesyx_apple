# Genesyx iOS Release Candidate Changes

Date: 2026-09-01

This document summarizes the iOS work completed for the Genesyx 1.2.0 build 25 release candidate. It is a companion summary to `CHANGES.md`, focused on what changed, how it behaves, and what still needs physical-device verification.

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

Automated tests were not executed in the final verification pass because Xcode reported no concrete iOS simulator or connected iPhone. Only placeholder destinations were available:

- `Any iOS Device`
- `Any iOS Simulator Device`

Per release restrictions, tests were not run against a placeholder simulator.

Current totals:

| Target | Passed | Failed | Skipped | Not Executed |
| --- | ---: | ---: | ---: | --- |
| `GenesyxAppTests` | 0 | 0 | 0 | All tests |
| `GenesyxUITests` | 0 | 0 | 0 | All tests |

Status: Waiting for a usable iOS simulator or connected physical device.

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

## Current Verdict

READY FOR PHYSICAL-DEVICE SMOKE TEST

Not ready for upload until physical-device smoke testing and executable unit/UI test verification complete.
