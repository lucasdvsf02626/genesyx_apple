# Post-launch-audit patch — CHANGES

Running log of every file touched, per task.

## Task 1 — Incremental sync (egress vs Free-tier 5 GB cap)

Per-table `updated_at` cursors for the three growing history tables so a launch pulls
only rows changed since the last successful sync, instead of full history every time.

**`consent_events` is deliberately EXCLUDED** and keeps its current full fetch. It has no
column that can safely drive an incremental cursor: verified schema
(`supabase/migrations/20260818_consent_events.sql`) has no `updated_at`/`created_at`, only
`occurred_at`, which is **client-set and backdated** (onboarding runs before sign-up, so the
row is inserted minutes-to-hours after the timestamp it carries — see
`RemoteModels.swift` `ConsentEventRow` and `ConsentRepository.swift`). A cursor on
`occurred_at` could silently miss a backdated consent row inserted by another device after a
sync — an unacceptable gap in a legal Article 9 audit trail. It is also a tiny, non-growing
table, so it contributes nothing to the egress problem. The spec's "safe by construction"
note assumed a server-monotonic timestamp this table does not have.

### Design
- Cursor = the **request start time** of the last *successful* pull, persisted per repository
  via the existing `LocalStore` pattern (same mechanism as `pendingDates`). Never advanced on
  a failed fetch.
- The query filters `updated_at >= (cursor − 60s)` (60s overlap margin for clock skew). The
  margin is applied in the repository so it is unit-testable; the backend just formats the date.
- First run after this update (no stored cursor) fetches full history once — identical to
  current behaviour — then stores the cursor. This is the migration path for existing users.
- Merge: `DailyLog`'s existing overwrite loop is already subset-safe (touches only returned
  keys). `PhSync.merge`/`SupplementSync.merge` assume a *complete* snapshot (they re-flag any
  local record absent from `remote` as pending), so a subset-safe `mergeIncremental` was added
  next to each; the full first sync still uses `merge`.
- Sign-out / account-switch: each repository's `clearLocalState()` (already called by
  `AppContainer.clearLocalState`) now also clears its cursor.

### Files touched
- `Sources/GenesyxCore/Ph/PhSync.swift` — added `mergeIncremental(local:remote:)`.
- `Sources/GenesyxCore/Models/SupplementSync.swift` — added `mergeIncremental(local:remote:)`.
- `App/Genesyx/Data/Remote/RemoteBackend.swift` — `DailyLogBackend.list`, `PhBackend.list`,
  `SupplementBackend.list` now take `updatedSince: Date?`.
- `App/Genesyx/Data/Remote/RemoteModels.swift` — `DailyLogRow` now decodes `updated_at`
  (decode-only; omitted on write so the server trigger stamps it).
- `App/Genesyx/Data/Remote/SupabaseBackend.swift` — the three `list` implementations apply the
  `updated_at >= since` filter when a cursor is supplied.
- `App/Genesyx/Data/DailyLogRepository.swift` — cursor + `#if DEBUG` row-count log.
- `App/Genesyx/Data/PhRepository.swift` — cursor + full/incremental branch + row-count log.
- `App/Genesyx/Data/SupplementsRepository.swift` — cursor + full/incremental branch + row-count log.
- `App/GenesyxTests/RepositoryTests.swift` — updated mock `list` signatures; added cursor and
  `mergeIncremental` tests.

Note on `user_supplements.updated_at`: nullable in schema but defaulted `now()` on insert and
always sent by the client on upsert, so a changed row always carries a non-null `updated_at`;
the incremental filter cannot miss a real change. First full sync covers the baseline.

## Task 2 — Resend cooldown + rate-limit-aware copy

- **429 detection** lives in the Supabase layer (the only place that can see `AuthError`): a new
  `mapRateLimit` maps `AuthError.api` with HTTP `statusCode == 429` or a GoTrue
  `over_email_send_rate_limit` / `over_request_rate_limit` / `over_sms_send_rate_limit` code to a
  new `RemoteError.rateLimited`. Applied to `signUp`, `resetPassword`, `resendConfirmation`.
- **App-facing seam** `AuthEmailFailure` (in `AuthView.swift`, file-scope/internal so it is
  unit-testable): maps an error to the copy and cooldown. `RemoteError.rateLimited` → the wait copy
  + 300s cooldown; anything else → the existing generic copy + 60s.
- **Resend button**: 60s cooldown on any tap, with a live countdown label ("Resend available in
  Ns"), disabled while counting down; a confirmed 429 extends it to five minutes. Driven by a
  1-second timer that only ticks while a cooldown is live and stops once both are clear. Cooldown is
  `@State` (survives re-render, not app restart, per the brief).
- **Forgot password**: shows the wait copy and a five-minute cooldown on a 429; no baseline cooldown
  otherwise (the 60s baseline is scoped to resend, per the brief).
- **Sign-up path**: a rate-limited confirmation send now surfaces the wait copy via a new
  `catch RemoteError.rateLimited` in `submit()`, instead of the generic "check your details".
- New user-facing string (British English): "Too many attempts right now. Please wait a few minutes
  and try again."

### Files touched
- `App/Genesyx/Data/Remote/RemoteBackend.swift` — added `RemoteError.rateLimited`.
- `App/Genesyx/Data/Remote/SupabaseBackend.swift` — `mapRateLimit` + wrapped the three email sends.
- `App/Genesyx/UI/Auth/AuthView.swift` — `import Combine`; `AuthEmailFailure`; cooldown state,
  timer, and countdown/disabled on the resend and forgot-password buttons; 429 branches in
  `submit`, `sendReset`, `resendConfirmation`.
- `App/GenesyxTests/PasswordResetTests.swift` — added rate-limit copy/cooldown and propagation tests.

Note: the raw `AuthError` → `RemoteError.rateLimited` mapping runs in production (Supabase-only
code). The unit tests exercise the app-facing behaviour by injecting `RemoteError.rateLimited`,
which is exactly what that mapping produces — the "simulated 429" the acceptance calls for.

## Task 3 — Minimum-version gate

- Pure `VersionGate` (in `RootRouting.swift`): `parseBuild` (nil for absent/non-numeric/empty),
  `requiresUpdate(currentBuild:minimumSupportedBuild:)` (true only when a numeric minimum exists and
  the build is strictly below it), `currentBuild()` (`CFBundleVersion`), and `appStoreURL`.
- New `RootDestination.updateRequired`, checked FIRST in `RootRouting.destination` (outranks
  everything, including `unavailable`). New param defaults `false` so existing routing tests and the
  call site are unchanged until a real minimum is configured.
- Fetch: new `GenesyxBackend.minimumSupportedBuild()` with a default extension returning `nil` (so
  local/mock backends and the full-backend test mocks need no change). `SupabaseBackend` reads
  `app_config` anonymously: `.from("app_config").select("value").eq("key","min_supported_build").limit(1)`.
- `AppContainer.updateRequired` (@Published, fail-open false) is set by `checkMinimumVersion()`, run
  once at launch from `GenesyxApp`'s `.task`. **Fail open** on missing table/row, malformed value,
  or network error (logged under `#if DEBUG` only) — the check can never block launch by failing.
- Gate screen: `UpdateRequiredView`, copy "This version of Genesyx is no longer supported. Please
  update to continue." with an "Update" button (`openURL(VersionGate.appStoreURL)`).

**File-placement note:** the brief allowed one new view file, but the Xcode project uses **manual
target membership** (no file-system-synchronized groups — confirmed in `project.pbxproj`), so a new
`.swift` file would need hand-edited `pbxproj` entries and risk breaking the build. `UpdateRequiredView`
is therefore defined in `RootView.swift` beside the existing `ServiceUnavailableView` /
`SessionResolvingView` (same private-struct pattern, same file), so no `pbxproj` surgery is needed
and the change is guaranteed to compile. No new file was created.

**App Store URL:** no numeric App Store ID exists in the repo yet. `VersionGate.appStoreURL` reads an
optional `APPSTORE_URL` from Info.plist and otherwise opens the App Store app (`itms-apps://apps.apple.com/`).
Recommend setting `APPSTORE_URL` to the numeric listing (`https://apps.apple.com/app/idXXXXXXXX`) at
submission for a direct deep-link.

### Files touched
- `App/Genesyx/Data/App/RootRouting.swift` — `RootDestination.updateRequired`; `updateRequired`
  param (ranked first) in `destination`; `VersionGate`.
- `App/Genesyx/Data/Remote/RemoteBackend.swift` — `GenesyxBackend.minimumSupportedBuild()` + default.
- `App/Genesyx/Data/Remote/RemoteModels.swift` — `AppConfigRow`.
- `App/Genesyx/Data/Remote/SupabaseBackend.swift` — `minimumSupportedBuild()` implementation.
- `App/Genesyx/Data/App/AppContainer.swift` — `updateRequired` + `checkMinimumVersion()`.
- `App/Genesyx/Data/App/GenesyxApp.swift` — `.task { await container.checkMinimumVersion() }`.
- `App/Genesyx/Data/App/RootView.swift` — `.updateRequired` route, `updateRequired` argument, and
  `UpdateRequiredView`.
- `App/GenesyxTests/RootRoutingTests.swift` — version-compare, fail-open, and ranking tests.

## Task 4 — PII-safe Google log, Supabase sign-out verification, profile pending-sync visibility

- Google sign-in keeps the non-PII success breadcrumb and token-presence signal:
  `"[GoogleSignIn] SDK sign-in OK. hasIDToken=..."`. The unconditional success log no longer emits
  `result.user.profile?.email`; the email is still passed only to the auth/session layer as part of
  the Google sign-in flow.
- Verified the actual installed dependency:
  `Genesyx.xcodeproj/project/var/folders/ql/xph248657q37nx4n3qwdg4240000gn/T/simulator_screenshot_9473AC8D-8311-487F-8631-8A82612A6F63.png.xcworkspace/xcshareddata/swiftpm/Package/var/folders/ql/xph248657q37nx4n3qwdg4240000gn/T/simulator_screenshot_D8932204-10B7-4B42-95DD-25DE4237C48A.png.resolved` pins
  `supabase-swift` **2.50.0** at revision `102a146b1a7066602d0d9d03bfa65936d123ed6a`.
  In that checkout, `AuthClient.signOut(scope: .global)` calls `sessionManager.remove()` before the
  network logout, `LiveSessionManager.remove()` calls `sessionStorage.delete()`, and
  `SessionStorage.delete()` removes the configured storage key from `AuthLocalStorage`. On Apple
  platforms the default `AuthLocalStorage` is `KeychainLocalStorage`, so `client.auth.signOut()`
  clears the persisted Keychain-backed SDK session for the default global sign-out path. No manual
  credential clear was added, and no Keychain identifier was invented.
- Reused the existing pending-sync pattern in Profile: `PreferencesRepository` exposes read-only
  `hasPendingSync`, and `ProfileView` shows the same cloud / offline icon plus
  `DailyLogSyncState.pendingSync.label(...)` only while a profile preference write is owed.

### Files touched
- `App/Genesyx/UI/Auth/AuthView.swift` — removed email address from the unconditional Google SDK
  success `print`, preserving `hasIDToken`.
- `App/Genesyx/Data/PreferencesRepository.swift` — exposed read-only `hasPendingSync`.
- `App/Genesyx/UI/Profile/ProfileView.swift` — added conditional profile preferences pending-sync row.
- `App/GenesyxTests/RepositoryTests.swift` — added coverage for the visible pending-sync flag across
  offline edit, relaunch, and successful drain.

## Task 5 — Brand asset replacement (app icon + in-app lockup)

Asset-only change. No Swift file, view, or build setting was edited.

### Design
- **App icon must be full-bleed.** iOS masks the icon into its own squircle. The supplied artwork
  had rounded corners and white padding baked in, so shipping it as-is would have shown pale
  wedges inside the system mask. The gradient was extrapolated into the four corners instead:
  pixels at or above 225 in all channels inside a 20% corner box were treated as untrustworthy,
  dilated 8 iterations, seeded by nearest saturated interior colour via
  `distance_transform_edt`, then Gaussian-smoothed and blended through a feathered mask so no
  seam or starburst remains. Result is 1024x1024 RGB, no alpha (`sips` confirms `hasAlpha: no`).
  That corner pass left the *edges* short: a near-white fringe up to 7px deep ran along the middle
  ~60% of all four sides, which is exactly where the system mask touches the boundary — the mask
  clips the corners and keeps the edge midpoints, so the fringe would have shown as a faint rim
  (~1.2px at @3x) while the repaired corners were discarded. Fixed by resampling the artwork to
  1044x1044 and centre-cropping back to 1024, which pushes the gradient past all four midpoints.
  Measured after the fix: fringe depth 0px on every side, 0/1024 near-white pixels on each edge
  row and column, still 1024x1024 and `hasAlpha: no`.
- **Dark icon variant** uses the iOS 18 `luminosity`/`dark` appearance in `Contents.json`. It is
  built from the supplied `logo_white.png` (1254x1254, true alpha, glyph 1015x990) placed on
  transparency at 62% scale, so the system supplies the backing plate. That file is a later, cleaner
  rendition than the first source used — thinner ring stroke, dot properly detached — so the dark
  icon does not match the earlier build byte for byte. A supplied navy-background file was rejected
  for this slot: it had upscaling artefacts.
- **Lockup keeps its geometry.** `brand_lockup` stays 718x172 and the new mark was fitted into
  the same 124x125 box the old mark occupied, so no call site needed a layout change. The
  "ENESYX" wordmark was not modified; light keeps black text, dark keeps white. Both lockups are
  built from `logo_white.png` so every surface carries one rendition of the mark.
- **The light icon's glyph was left alone on purpose.** Its white knockout vs the `logo_white.png`
  glyph scores 0.913 shape IoU, so it already carries the current drawing. Redrawing it would
  require inventing a full-square gradient to knock the letter out of — regression risk for no
  visible gain. The old lockup mark was the real outlier (0.856) and is the one that was replaced.
  Only the framing changed, via the uniform resample described above; the glyph was not redrawn.

### Files touched
- `App/Genesyx/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` — replaced,
  full-bleed, no alpha.
- `App/Genesyx/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png` — new,
  dark-appearance variant.
- `App/Genesyx/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` — declares the dark
  variant.
- `App/Genesyx/Resources/Assets.xcassets/brand_lockup.imageset/brand_lockup.png` — new mark.
- `App/Genesyx/Resources/Assets.xcassets/brand_lockup.imageset/brand_lockup_dark.png` — new mark.

### Verification
Verified on the iPhone 17 simulator from a real build: the new home-screen icon renders, and the
new lockup renders in the auth and onboarding surfaces.

Asset-verified but **not** render-verified: the dark app icon. `xcrun assetutil --info` shows the
dark rendition compiled into `Assets.car` with `Opaque: false`, but the simulator rendered no dark
icon variant for any app, Apple's own included, so there is no render evidence. Needs a device or
TestFlight. The dark lockup is in the same position, because the app forces its colour scheme from
`PreferencesRepository.themeMode` (defaults `.light`) and the seeded container is in-memory, so the
launch argument cannot reach it.

### Version bump
`CURRENT_PROJECT_VERSION` is now `27` in **both** `project.yml` and `project.pbxproj`; build 26 went
to Apple on 3 September and duplicate build numbers are rejected. `MARKETING_VERSION` stays `1.2.1`.

The two files had **drifted**: pbxproj said `26`, `project.yml` still said `25`. Local archives read
the former and CI regenerates from the latter, so the same commit could have produced two builds
claiming different numbers. Both now agree.

**Build 26 does not contain this artwork.** `build/Genesyx-1.2.1-b26.xcarchive` was cut on
3 September at 16:50; every file in this change reached disk on 4 September. The icon inside that
archive is the previous pale-lavender mark, confirmed by eye against
`Products/Applications/Genesyx.app/AppIcon60x60@2x.png`. Build 27 is therefore the first build that
ships the new logo, and there is no way to correct the store listing without it — the App Store
icon is read from the uploaded binary and cannot be swapped from the web interface.

Verified from the product, not the config: built `Info.plist` reports `CFBundleVersion 27`,
`CFBundleShortVersionString 1.2.1`. No test pins the build number (searched all three targets).
Post-change: `GenesyxAppTests` 393 passed / 0 failed / 0 skipped; core 314 / 0.

### Still blocking upload
fastlane cannot run from this machine — no `Gemfile`, no `.bundle`, nothing on `PATH` — so the
committed `Fastfile` lanes are unusable here. `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH` are all
unset. Distribution must go via Xcode Organizer, or fastlane must be installed and keyed first.

The App Store listing icon is read from the binary, so this change reaches customers only through a
new build and a new review.
