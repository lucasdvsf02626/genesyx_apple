# Genesyx iOS — Full App Inventory (A → Z)

**Purpose:** the single source of truth for what the iOS app does, what works, what doesn't, and what's left — a clear roadmap to v1 and beyond. Every entry is verified from the repo, build, and test run, not from memory.

| | |
|---|---|
| Branch verified | `build-12-data-honesty` |
| HEAD | `457326a` |
| Version | `MARKETING_VERSION 1.1.0` · build `12` (`project.yml`) — *confirm store version before submit* |
| Bundle id | `com.genesyx.app` |
| Stack | SwiftUI · GenesyxCore (pure domain Swift package) · Supabase · Google Sign-In |
| Tests this pass | App **96 pass / 0 fail** · UI **9 (1 skipped) / 0 fail** → `** TEST SUCCEEDED **` |
| Not re-run this pass | `swift test` (GenesyxCore ~104 tests) · `xcodebuild archive` |

**Status legend:** ✅ working & shipping · 🟢 built + surfaced, needs device confirm · 🟡 honest teaser / dormant by design · 🔵 built in core, **not surfaced** in UI · ⚪ dead code (unreachable) · ⏳ built, not committed · ❌ not built

---

## A. App shell & navigation

| Item | Status | Evidence / notes |
|---|---|---|
| Launch → onboarding gate | ✅ | `RootView.swift` — main tabs gated behind `OnboardingFlowView`; `onboardingComplete` flips only after successful sign-in (Android parity) — dashboard is unreachable without auth |
| 6-tab custom bottom bar | ✅ | `MainTabView.swift` — Home, Track, Nutrition, Insights, Learn, Profile |
| Deep-link routing | 🟢 | `DeepLink.swift`, `NotificationRouter.swift` — custom scheme `genesyx://…`; notification tap lands on tab + Learn article; Universal Links **off** (see §K) |
| Theming (light/dark/system) | ✅ | `Theme.swift`, `GenesyxColors.swift`, `Typography.swift`; user-selectable in Profile |

---

## B. Onboarding

| Item | Status | Evidence |
|---|---|---|
| Onboarding flow | ✅ | `UI/Onboarding/OnboardingFlowView.swift` — ends in auth; sets `onboardingComplete` |
| Quiz/focus content in onboarding | 🟢 | `GenesyxCore/Content/QuizContent.swift` (+ `QuizContentTests`) referenced from onboarding; confirm full flow on device |

---

## C. Authentication (real, Supabase-backed)

| Method | Status | Evidence |
|---|---|---|
| Email + password sign-in/up | ✅ | `AuthView.swift` → `SessionRepository.authenticate` → Supabase |
| Sign in with Apple | 🟢 | `SignInWithAppleButton`, nonce+SHA256, `signInWithIdToken` — device-only proof |
| Continue with Google | 🟢 | `GIDSignIn` → `signInWithIdToken` — device-only proof |
| Email-confirmation handling | ✅ | sign-up w/o session → `RemoteError.emailConfirmationRequired`, no fake "signed in" |
| Resend confirmation email | ⏳ | **built this session, NOT committed** — see §M |
| Password reset | ✅ | Profile → `SessionRepository.resetPassword()` → `resetPasswordForEmail` |
| Account deletion (5.1.1) | ✅ | `deleteAccount()` → edge fn `delete_account` → local wipe |
| Sign-out | ✅ | clears session + wipes on-device health data + notification state |
| **Mock-path safety** | ✅ | permissive local sign-in is `#if DEBUG` only; Release throws `notConfigured` rather than faking |

---

## D. Cycle tracking (Track tab) ✅

- Month calendar with phase colours, current-phase card, fertile window + ovulation day.
- Phases computed by `CycleEngine.cyclePhase(settings:target:)` (core, not hardcoded).
- Empty state: "Tell us when your last period started…".
- Enter/update via `CycleSettingsSheet` → `CycleRepository.upsert`; persisted local-first + `cycle_settings` (Supabase).

## E. Daily logging (Log tab) ✅

- Mood, energy, symptoms, sleep, water, supplements → `DailyLogRepository` → `daily_logs`.
- Past-day detail shows real logged summary (data-honesty fix).
- Deletes handled as tombstones so they sync across devices.

## F. pH tracking ✅

- Entry from Track/Nutrition (`UI/Ph/PhTrackerSection.swift`) → `PhRepository` → `ph_readings`.
- Real Swift Charts trend; status logic `GenesyxCore/Ph/PhStatus.swift`, `PhInsightLogic.swift`.
- Honest empty state; trend needs ≥2 readings.

## G. Nutrition tab ✅

- Focus-foods content (`GenesyxCore/Content/NutritionContent.swift`).
- Honest supplement count from the daily log (fake "3 of 4" removed).
- pH entry point surfaced here too.

## H. Insights tab ✅ (six real cards — richer than previously documented)

| Card | Source logic | Status |
|---|---|---|
| Consistency / streak | `StreakEngine` + `ConsistencyInsightLogic` | ✅ |
| Hydration | `HydrationInsightLogic` | ✅ |
| Cycle regularity | `CycleRegularityLogic` | ✅ |
| Symptom patterns | `SymptomPatternLogic` | ✅ |
| Ovulation | `OvulationLogic` | ✅ |
| pH insights | `PhInsightLogic` | ✅ |

All compute from real user data with honest empty states (`InsightsView.swift:30–110`).

## I. Learn tab ✅

- 16 distinct real articles, native Swift content (`LearnContent.swift`), list + detail.
- Notification tap deep-links to the specific article (`router.pendingLearnSlug`).
- Read log persistence: `Notifications/LearnReadLog.swift`. Covered by `LearnContentTests`.
- *Device-confirm:* intro gate, search/filter, share CTA, related articles.

## J. Profile tab ✅

- Account (email/name), sign-out, delete account, change/reset password.
- Focus mode toggle; theme + push preferences (`PreferencesRepository`).
- Partner section (see §K).

---

## K. Partner linking (real UI, partial backend)

| Piece | Status | Evidence |
|---|---|---|
| Create invite | ✅ | `ProfileView` `PartnerSectionView` → `PartnerRepository.sendInvite` → `partner_invites` |
| Share invite link | ✅ | `InviteShareSheet.swift` (share sheet, honest "Invite ready/sent" copy) |
| **Email the invite** | 🟡 | edge fn `send_partner_invite` built; needs Resend domain + secrets → falls back to share sheet safely |
| Accept invite | 🟢 | edge fn `accept_partner_invite`; device/2-account proof |
| Unlink | ✅ | edge fn `unlink_partner` |
| **What a linked partner sees** | 🟡 | name only; RLS owner-only by design — data-sharing is a deferred product/privacy decision |

---

## L. Notifications (local, no APNs)

| Item | Status | Evidence |
|---|---|---|
| Local scheduling engine | 🟢 | `GenesyxCore/Notifications/NotificationPlanner.swift`, `App/.../NotificationService.swift` (builds 10/11) |
| Content from user data | 🟢 | `NotificationContent.swift` — weekly nudges, hydration, streak milestones, Learn nudge |
| Push toggle | ✅ | Profile preference; `push_enabled` default false (migration) |
| Actual firing | 🟢 | **device-only** — simulator can't fully prove |

---

## M. Features I built / fixed

### Resend confirmation email — ⏳ built this session, **NOT committed**
Adds a "Resend confirmation email" affordance right where the app tells her to check her inbox; unblocks turning Supabase "Confirm email" ON later. Mirrors `resetPassword`; local/mock backends get a default no-op. Build + 96 app tests pass with it in the tree.
- `Data/Remote/RemoteBackend.swift`, `Data/Remote/SupabaseBackend.swift`, `Data/SessionRepository.swift`, `UI/Auth/AuthView.swift`
- **Action needed:** commit or stash before archiving.

### Data-honesty fixes — ✅ committed (`068b396`)
Nutrition real supplement count · Track past-day real summary · Pregnancy stub removed (teaser only) · friendly auth errors + silenced cancels · password reset end-to-end.

---

## N. Deliberately off / not in v1 (honest, review-safe)

| Item | Status | Note |
|---|---|---|
| Pregnancy tracking | 🟡 | "Coming soon" teaser only, no fake data (`PregnancyView.swift`) |
| Universal Links | 🟡 | Code + AASA ready; entitlement commented out (keeps archive passing); needs domain hosting + 5 switches |
| Partner invite email | 🟡 | needs Resend setup; share-sheet fallback works |
| Partner data sharing | 🟡 | RLS owner-only; product decision pending |

---

## O. Dead / unreachable code

| Item | Status | Note |
|---|---|---|
| `UI/Components/PlaceholderScreen.swift` | ⚪ | **zero references** — unreachable from UI; safe but removable |

---

## P. Backend (Supabase — project `epltxklawpcxxbaleswg`)

- **Edge functions:** `delete_account`, `accept_partner_invite`, `unlink_partner`, `send_partner_invite`, shared `_shared/client.ts`.
- **Migrations:** `20260712_sync_hardening.sql`, `20260712_push_enabled_default_false.sql`.
- **Release config:** real `SUPABASE_URL` + publishable anon key baked in (`project.yml`); RLS owner-only is the security boundary.
- **Keep-alive:** GitHub Action (in `genesyx-android` repo) pings twice weekly so the project never auto-pauses — fixed & passing.

---

## Q. Test coverage (by area)

| Suite | Files | ~Tests | Result this pass |
|---|---|---|---|
| GenesyxAppTests | 12 files | 96 | ✅ 0 failures |
| GenesyxUITests | 2 files | 9 | ✅ 0 failures (1 skipped) |
| GenesyxCoreTests | 8 files | ~104 | ⏳ not run this pass (run `swift test`) |

Coverage spans: repositories, persistence, backend swap, deep links, partner, notifications, insights (real), hydration, Learn/quiz content, cycle engine, pH sync/insight, streaks, calendar dates.

---

## R. App Store readiness

| Point | Status |
|---|---|
| Privacy manifest (`PrivacyInfo.xcprivacy`) | ✅ present |
| Sign in with Apple entitlement | ✅ present |
| In-app account deletion | ✅ wired end-to-end |
| App icon (`AppIcon-1024.png`) | ✅ present |
| Export compliance (`ITSAppUsesNonExemptEncryption=false`) | ✅ set |
| Screenshots / support URL / privacy-policy URL / privacy labels | ⏳ verify in App Store Connect |
| `xcodebuild archive` | ⏳ **unverified this pass — run before submit** |

---

## S. Roadmap

### v1.0 — before submit (blocking, mostly non-code)
1. Commit or stash the resend-confirmation files → clean working tree.
2. Tag rollback anchor `v1-clean` on green HEAD.
3. Run `swift test` (GenesyxCore) + `xcodebuild archive`.
4. Confirm store version string (1.1.0 vs 1.0).
5. Device QA: Apple/Google sign-in, account deletion, cold-start persistence, Learn runtime, notification firing, 2-account partner accept.
6. Confirm App Store Connect metadata (screenshots, URLs, privacy labels, age rating).

### v1.0.1 — next (non-blocking)
- Turn on partner invite email (Resend domain verify + secrets + deploy).
- Turn on Universal Links (portal capability + host AASA + 5 switches).
- Decide + implement what a linked partner actually sees (new RLS policies).
- Turn Supabase "Confirm email" ON (resend affordance already built to support it).
- Remove dead `PlaceholderScreen.swift`.

---

## T. Danger notes (launch-day)
- **Do NOT merge `feature/learn-parity`** — 3,597 deletions behind; would delete builds 10–12 (notifications, sync, partner email, streaks).
- **Do NOT reset to `v1.0-baseline`** (`52fc94f`) — predates builds 10–12.
- `wip/v1.0.1-extras` is next-version staging — not for v1.
- If Learn or anything wobbles: reset to the tagged clean anchor and ship the honest narrower build. Revert beats delay.

---
_Last updated from live repo evidence at HEAD `457326a`. App tests green; archive + core suite pending re-run._
