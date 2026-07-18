# Genesyx — Project Status & Inventory

_Snapshot: 2026-07-16 · branch `main` · version 1.1.0 (build 12)_

This is the "where we are" document: what shipped, what's uploaded, what's live on
the backend, and what still needs a human. It is a status report, not a spec.

---

## 1. At a glance

| Thing | State |
|---|---|
| **App Store** | Version 1.1.0 build 12 — **Waiting for Review** (submitted 16 July 2026, 23:53 BST) |
| **Previous submission** | Version 1.0 build 8 rejected under Guideline 2.1 and replaced by build 12 |
| **Review access fix** | Production reviewer account created, password login verified, fictional sample data seeded |
| **Current dev version** | 1.1.0, build 12 |
| **Build 12 IPA** | Signed, uploaded, processed, attached to App Review, and assigned to internal TestFlight |
| **Build 11 IPA** | Validated + **uploaded to TestFlight** (`build/Export/Genesyx.ipa`, 6.3 MB) |
| **Build 10** | Uploaded but **dead** — ignore/expire it (had the notification bug below) |
| **Supabase backend** | Live: schema + RLS + auth + migrations all applied |
| **1.1 review submission** | **Waiting for Review**; manual release selected |

---

## 2. What was built (three workstreams)

### WS1 — StreakEngine v2 + Consistency insights
- `Sources/GenesyxCore/Streaks/StreakEngine.swift` — pure streak logic, fully tested.
- Consistency data surfaced in **Insights** and **Nutrition** UI.
- Commits: `f3324a9`, `50fc597`.

### WS2 — Local notifications (no APNs)
- Scheduled via `UNUserNotificationCenter`. No push server, no APNs certs.
- **`NotificationPlanner`** (pure, in GenesyxCore) computes copy *from her data*, not a
  string table. **`NotificationService`** schedules + routes taps to the right tab/article.
- Four invariants locked as tests — most important:
  - **A broken streak is never named** (body may not contain broke/broken/lost/missed/failed/streak).
  - **14 silent days → one hand-back, then silence** (never nags).
- Commit: `3d39352`, rewritten in `2f28fac`.

### WS3 — Real Supabase data layer
- `SupabaseBackend` (real `supabase-swift` client) behind a `RemoteBackend` protocol.
- Sync hardening: **`PhSync.merge`** resolves pH conflicts by id, last-`updated_at` wins,
  and **never overwrites an unsynced local edit** (`pending_sync=true`).
- Cycle / daily-log sync tested so stale cloud never overwrites newer local.
- Commits: `f3324a9`, `0e45437`, `5f6695e`, `6119be3`, `20f6094`.

---

## 3. Source inventory

### App (`App/Genesyx/`)
- **Data/** — `PreferencesRepository`, `PartnerRepository`, `AppContainer`, `DeepLink`.
- **Data/Remote/** — `RemoteBackend` (protocol), `RemoteModels` (row DTOs), `SupabaseBackend`.
- **Notifications/** — `NotificationService`, `NotificationContent`, `NotificationRouter`, `LearnReadLog`.
- **UI/** — Home, Track, Nutrition, Insights, Learn, Profile, Log, Ph, Invite, plus `MainTabView` (custom 6-tab bar).

### Core (`Sources/GenesyxCore/`) — pure, `swift test`-able
- **Streaks/** `StreakEngine` · **Notifications/** `NotificationPlanner`
- **Ph/** `PhSync`, `PhStatus`, `PhInsightLogic` · **Cycle/**, **Insights/**, **Models/**

### Tests
- App: 11 test files (incl. `AuthPartnerBackendTests`).
- Core: 8 files — `NotificationPlannerTests`, `PhSyncTests`, `StreakEngineTests`,
  `ConsistencyInsightLogicTests`, etc.

---

## 4. Backend state (Supabase project `epltxklawpcxxbaleswg`)

- **RLS**: enabled, owner-only on all four tables (`profiles`, `cycle_settings`,
  `daily_logs`, `ph_readings`); `profiles` keeps its extra partner-read policy.
- **Migration `20260712_sync_hardening.sql`** applied — added `profiles.focus_mode`,
  `profiles.push_enabled`, the `ph_readings_user_recorded_idx`, and `bump_updated_at`
  triggers on profiles/cycle_settings/daily_logs.
- **`trg_ph_readings_updated_at` is KEPT** (deliberately not dropped). Consequence,
  documented: ph_readings resolves last-**push**-wins server-side; the real protection
  (local unsynced edit always beats server) lives in `PhSync.merge` on-device.
- **Auth**: email + Google + Apple enabled. "Confirm email" is **OFF** on purpose —
  do not flip it ON until build 11 is live.
- **Edge functions** present: `delete_account`, `accept_partner_invite`,
  `unlink_partner` (+ `_shared/client.ts`). Service-role key is auto-injected into the
  function only — never in the app, CLI, or chat.
- Anon key `sb_publishable_eR7nEFBHD_4ATbjEeRbicA_Z3Qj_Elb` is public/safe by design (RLS is the boundary).

---

## 5. The bug build 11 exists to fix

`push_enabled` defaulted to **true**, so the Profile toggle rendered "on" while iOS had
never been asked for permission → nothing was ever scheduled → **dead notifications for
everyone**. Only a real Simulator run caught it (the UI claim disagreed with iOS state).

**Fix** (`0883477`): default `push_enabled=false`; the toggle now reads `notifications.isOn`
("she asked *and* iOS agreed"). Cut build 11.

---

## 6. Git state

- `main` HEAD: **`de70acf`** — "Sign-out leaked the previous user's notification state to
  the next one." ⚠️ **This fix landed *after* the build 11 archive**, so the uploaded IPA
  does **not** contain it. If it matters for TestFlight, cut a **build 12**.
- Baseline `c258921` (`claude/blissful-carson-wsdb54`) is frozen in App Store review.
- **Uncommitted work in progress** on `main`: a partner-invite share flow
  (`UI/Invite/InviteShareSheet.swift` new, `DeepLink`, `PartnerRepository`,
  `SupabaseBackend`, `ProfileView`) — ~164 lines across 10 files, not yet committed.

---

## 7. Outstanding

**Human / device (not agent-doable)**
- Install build 12 from TestFlight on a real phone → grant permission via toggle → cold-start a
  notification tap → confirm banner renders → two-device pH sync sanity check.
- Monitor App Review messages and keep the verified reviewer account active throughout review.
- If Apple approves, use the manual release control only after the final live-readiness check.

**Sequenced later**
- Flip Supabase **Confirm-email ON** only after the approved build is live and the sign-up flow is
  retested with confirmation enabled.
- Apple Sign-in key expires ~6 months out — set a reminder.

---

## 8. Guardrails (keep these true)

- Never merge feature work into frozen baseline `c258921` while v1.0 is in review.
- Never ship mock auth in Release; never commit credentials.
- Service-role key lives **only** in the edge function.
- Don't hand-edit `project.pbxproj` — regenerate via `xcodegen generate` from `project.yml`.
- Keep `trg_ph_readings_updated_at`; don't drop pre-existing dead code.
