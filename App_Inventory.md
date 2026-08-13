# Genesyx iOS — Repository and App Inventory

**Purpose:** the code-backed map of the current Genesyx iOS app: product surfaces, tracked data,
derived logic, persistence and sync, notifications, backend boundaries, privacy and verification.

This inventory was refreshed from the working repository on **12 August 2026**. The official iOS
source version is **1.2.0 (build 18)**. That source identity is separate from App Store Connect or
TestFlight availability; this audit did not inspect App Store Connect.

| Repository snapshot | Current value |
|---|---|
| Branch | `main` |
| HEAD at audit | `b1ab67b` plus documented uncommitted work; run `git status --short` before release |
| Official iOS version | **1.2.0 (18)** (`project.yml` and generated Xcode project agree) |
| Store/TestFlight state | Not live-verified by this inventory; do not infer upload or publication from source version |
| Bundle ID | `com.genesyx.app` |
| Deployment target | iOS 16.0 |
| Main stack | SwiftUI, Swift Charts, GenesyxCore, Supabase Swift, Google Sign-In |
| Main navigation | Seven persistent custom tabs: Home, Track, pH, Nutrition, Insights, Learn, Profile |
| Local storage | `UserDefaults` plus Codable records through `LocalStore` |
| Cloud storage | Supabase Auth, PostgREST tables, RPCs and Edge Functions |
| Analytics/ads | None in this repository |

## 1. Product and truth model

Genesyx is a native fertility-preparation, cycle-awareness and wellbeing-tracking app. It combines
cycle projections, daily logging, hydration and nutrition guidance, vaginal pH tracking, real-data
summaries, educational content with medical citations, local reminders and optional partner linking.

The app must keep four types of information distinct:

- **Recorded data:** what the customer entered: mood, energy, symptoms, sleep, water, supplements,
  notes, private intimacy, cycle settings and pH readings.
- **Derived information:** phase, fertile window, streaks, consistency, summaries and coaching
  calculated from recorded data.
- **Guidance:** educational, nutrition and Learn content. It is not a diagnosis or treatment plan.
- **Predictions:** cycle phase, ovulation and fertile-window estimates from one saved cycle setup.
  They are not measurements, and the app does not yet learn across historical period events.

## 2. Runtime architecture

```text
SwiftUI screen
    ↓ reads and writes
Observable repository
    ├─ LocalStore / UserDefaults (immediate local persistence)
    └─ optional Supabase backend
          ├─ Auth
          ├─ profiles + quiz_answers
          ├─ cycle_settings
          ├─ daily_logs
          ├─ ph_readings
          ├─ partner_invites
          ├─ waitlist RPC
          └─ Edge Functions

Repository data
    ↓
GenesyxCore deterministic logic
    ↓
Track, Insights, Home, Nutrition and local notifications
```

`AppContainer` is the composition root. It creates the repositories, chooses the optional backend,
hydrates cloud data, retries owed writes on foreground, and clears account-scoped local state on
sign-out or account deletion. Repositories update locally first; `GenesyxCore` contains most
UI-independent calculation and notification-planning logic.

The working tree may contain changes beyond `b1ab67b`. This file describes the inspected working
source, not only the last commit. A release must first commit or deliberately exclude that work.

## 3. App shell, onboarding, authentication and routing

### Root and onboarding

`RootView` gates the app behind onboarding and authentication. The flow contains Splash,
Introduction, Quiz, Readiness Summary, Waitlist and Auth. Completion is stored on-device.

Quiz answers are now retained locally before sign-up, pushed after authentication and stored in the
owner-only `quiz_answers` table. Profile → Tracking Preferences can edit the same answers. The
waitlist confirms success only after the `join_waitlist` RPC stores the address.

### Authentication

- Supabase email/password sign-up and sign-in.
- Email-confirmation handling and resend.
- Sign in with Apple using nonce verification.
- Google ID-token authentication through Supabase.
- Password-reset email from Profile.
- Sign-out with account-scoped local-data cleanup.
- Permanent deletion through the `delete_account` Edge Function.
- Debug/test local authentication exists only when the backend is absent; Release must not pretend
  an authenticated session exists when production configuration is missing.

### Seven-tab navigation

The persistent custom bar contains, in order:

1. Home
2. Track
3. pH
4. Nutrition
5. Insights
6. Learn
7. Profile

The custom `ZStack` keeps every tab alive so scroll and local navigation state survive switching.
The dedicated pH tab owns the canonical vaginal-pH tracker. Home, Track, Insights and notification
routes land on that tab rather than presenting duplicate pH trackers in Nutrition.

Notification taps route by `NotificationTab`; Learn destinations may carry a specific article slug.
Partner links accept `genesyx://invite/{code}` and the Genesyx HTTPS invite shape, but shared links
remain custom-scheme links while `DeepLink.universalLinksLive` is false. Production Universal Links
must not be claimed until the AASA file and entitlement are verified together.

## 4. User-visible surfaces

### Home

- Current cycle context when settings exist: phase, cycle day, next period and predicted ovulation.
- Honest cycle-setup prompt when settings are absent.
- Hydration progress, goal pacing and time-aware coaching.
- pH nudge that opens the dedicated pH tab.
- Today's nutrition focus and Log Today shortcut.
- Streak/milestone and newly available Learn content surfaces when earned.
- Pregnancy pathway preview; this is not an implemented pregnancy tracker.

### Track

- Month calendar with phase colour, predicted fertile-window treatment and selected-day state.
- Cycle setup/edit for last period, typical cycle length and period length.
- Tracker rows/details for cycle, vaginal pH, hydration, sleep, symptoms and nutrition.
- Backdated logging/editing from non-future calendar days.
- Calendar markers for logged fields, including symptoms/notes, supplements, water, pH and private
  intimacy where present.
- Hydration history, quick add/manual entry, goal days and streak.
- Sleep uses the current ISO week (Monday–Sunday).
- Symptoms use real daily logs and a four-week heatmap.

The cycle engine is predictive. Customer-facing copy must use “predicted” or “estimated” for fertile
window and ovulation. Any unqualified “You’re in your fertile window” copy is a content-safety defect,
not evidence that the app measured fertility.

### Daily log

One record exists per calendar day. It may contain:

- Mood: great, good, okay or low.
- Energy: low, normal or high.
- Symptoms, including customer-added symptom strings.
- Sleep duration in minutes, with the picker capped at 12 hours.
- Water total in millilitres.
- Supplements taken.
- Free-text notes.
- Private intimacy/sexual-activity flag.

Past-day logs open with the actual saved record and write back to that selected date. Private
intimacy stays owner-only, is excluded from notification copy and deliberately does not change the
cross-platform meaningful-day/streak contract.

### pH

- Dedicated persistent pH tab plus entry points from Home, Track and Insights.
- New vaginal reading range **3.8–7.0**, step 0.1, default 4.2.
- Two descriptive bands: **Healthy 3.8–4.5** and **Elevated >4.5**.
- Legacy urine readings remain labelled `urine (legacy)`, excluded from vaginal classifications and
  trends, and never silently reclassified.
- Current value, history, editable/deletable readings, chart and 7/30-day context.
- `PhCopy` centralises disclaimer, source attribution and professional signposting.
- No pH-based diet, diagnosis, condition claim or treatment recommendation.

The chart may display a broader fixed visual domain for legacy continuity; the **new-entry validation
contract** is 3.8–7.0.

### Nutrition and supplements

- Phase-aware nutrition focus and food guidance from compiled content.
- Hydration progress and direct tracking action.
- Suggested folate, omega-3, vitamin D and zinc plan with actual completion from the daily log.
- Customer-created supplements with name, optional dose and free-text time.
- Per-supplement optional reminder hour for both fixed-plan and custom supplements.
- Custom supplements are currently JSON in `UserDefaults` and therefore **device-local only**. They
  are cleared on sign-out, but no iOS Supabase supplement table/DTO is active yet.
- pH is no longer embedded in Nutrition; it has its own tab.
- Daily meal logging by **food group** — six chips (the Eatwell Guide's five, with fruit and
  vegetables separated), synced to `daily_logs.food_groups`. Groups only: no foods, no calories, no
  macros or micronutrients, and so no health claim on the card. Counting any of those would need a
  food database, which is the deferred barcode/photo work.
- Food groups do **not** count toward the daily or weekly logging streak. That predicate is shared
  byte-for-byte with Android via `tracking_test_vectors.json` and moves on both platforms or neither.
  Notifications do count them, because they mirror nothing.
- Eight recipes, two per cycle phase, in a horizontal row beneath the focus foods. Each opens to
  ingredients, a numbered method, and a one-tap log of the food groups it covers (additive — a second
  tap never removes a group). Recipes carry no citation, disclaimer or medical reviewer because each
  is tied by a tested foreign key to a focus food the reviewed content already recommends for that
  phase, so they repeat a signed-off claim rather than making a new one.
- No food photography exists in the app. Recipe cards render on the phase accent colour, with a nil
  image field as the seam for real assets later.

Hydration supports millilitres, glasses and cups as display units. Glass size is customer-configurable
within the allowed range; cups remain 240 ml. Storage, sync, goals, streaks and calculations remain
millilitres, so changing display units never changes tracked totals.

### Insights

Every Insights surface derives from repositories and has an honest empty state.

| Surface | Inputs | Current derivation |
|---|---|---|
| Weekly summary | Current/prior seven-day logs | Logged days, mood/energy, hydration, sleep and supplement comparisons when data exists |
| Consistency | Meaningful daily logs | Current/best streaks and weekly activity |
| Vaginal pH | Vaginal-only reading history | Latest band, direction/delta, reading count and cycle caveat |
| Hydration | Seven daily totals + goal | Goal days, streak, average/percentage, trend and coaching |
| Nutrition consistency | Daily supplement sets | Logged days and weekly consistency |
| Sleep | Current ISO-week sleep minutes | Logged nights, average and contextual line |
| Cycle setup | One cycle-settings row | Current configured length, not longitudinal regularity |
| Symptom patterns | Four weeks of logs | Most frequent symptoms and 4×7 heatmap with date navigation |
| Ovulation | Cycle setup + today | Estimated ovulation day/window and current-cycle context |
| My logs | Full log and pH history | Chronological access to recorded entries |

These are deterministic summaries, not clinical conclusions. The current app has useful weekly and
rolling-window cards, but it does **not** yet implement a single unified 7/14/21/30-day intelligent
partner report with evidence maturity, cross-signal conclusions or a reviewed/dismissed insight ledger.

### Learn

- Native compiled content with category browsing, search, detail, related articles, share and CTAs.
- Thirty articles are compiled in the current iOS source; future-dated weekly pieces are withheld
  until their `publishedAt` date.
- All entry paths—including search, related links, deep links, Home and notifications—resolve through
  the same published library.
- Read state, newly arrived state and unread-new badge are device-local.
- Health-fact articles show mapped sources; unsupported or unreleased slugs fail honestly.

### Profile

- Personal Details editor for display name and signed-in email display.
- Health Profile editor for cycle settings.
- Tracking Preferences editor for onboarding answers.
- Light/dark/system theme, with light the fresh/default designed appearance.
- Notification master control, time and eight category toggles.
- Hydration unit and custom glass-size settings.
- Password reset, sign-out and permanent account deletion.
- Partner invite/pending/linked/unlink controls where enabled.
- Privacy Policy, Help & Support and Medical Sources & Disclaimer.

## 5. Shared domain and pattern contracts

### Meaningful day and streaks

`TrackingEngine` is the shared definition. Mood, energy, symptoms, sleep, water, supplements and
notes can qualify a day. Private intimacy is intentionally excluded so the existing cross-platform
tracking vectors and customer-visible streak meaning do not change silently.

### Hydration

- Default goal is 2,400 ml where no individual goal is supplied.
- One daily total is stored; the app has no drink-event timestamps.
- Seven-day averages, goal days, streaks and pacing are descriptive.
- Time-aware coaching compares progress with an expected portion of the day without shaming.

### Cycle

`CycleEngine` projects cycle day, phase, predicted fertile window and estimated ovulation using one
last-period date and typical lengths. No period-event history means no truthful multi-cycle learning,
cycle-to-cycle regularity or measured fertility claim.

### Sleep, symptoms and supplements

These are facets of the daily log, not timestamped event tables. The app can describe dated totals
and frequencies. It cannot truthfully infer exact bedtime routines, dosing times, causation or
time-of-day symptom patterns from the present schema.

## 6. Notifications

Notifications are local `UNUserNotificationCenter` requests; there is no general remote-push,
advertising or analytics pipeline.

Eight customer-facing categories are available:

1. Evening check-in
2. Cycle
3. pH readings
4. Logging reminders
5. Supplement reminders
6. Insights
7. Weekly read
8. Milestones

`NotificationPlanner` receives a repository-built snapshot and chooses evidence-aware hydration,
pH, Track, Insights, Learn and predicted-fertile-window nudges. It has a weekly budget, avoids two
planner nudges on one day, avoids guilt language and goes quiet after prolonged inactivity.

Two exceptions sit outside the planner’s one-per-day/weekly budget:

- Milestones are event-based celebrations.
- Per-supplement reminders are repeating alarms explicitly set by the customer.

Therefore “at most one notification a day” is only true for planned intelligent nudges—not for the
combination of planner nudges, milestones and customer-configured supplement alarms.

Notification permission is explained before iOS is asked. Delivery, timing, lock-screen presentation
and tap routing still require real-device verification.

## 7. Persistence and sync

### On-device

`LocalStore` namespaces Codable values in `UserDefaults`. Repositories update observable state and
local persistence immediately. Device-local state also includes reminder schedules, notification
category mutes, Learn read/new state, milestone flags, hydration display preferences and custom
supplements.

### Repository ownership

| Repository | Responsibility |
|---|---|
| `SessionRepository` | Auth/session, account actions, display-name hooks and lifecycle callbacks |
| `CycleRepository` | Cycle settings plus owed cloud update |
| `DailyLogRepository` | Date-keyed logs, water helpers and pending changes/deletions |
| `PhRepository` | Reading history, measurement type, edits/deletes, merge and pending sync |
| `PreferencesRepository` | Theme, focus, push flag, quiz answers and device notification preferences |
| `PartnerRepository` | Invites, linked partner, accept/decline/revoke/unlink and refresh |
| `LearnProgress` | Read and newly arrived article state |

Backend-enabled hydration refreshes profile/quiz preferences, cycle settings, daily logs, pH and
partner state. Owed writes are attempted before remote state is accepted. Foregrounding drains
pending work. Sign-out/delete clears account health data, quiz answers, custom supplements,
notification-derived state, Learn progress and partner state from the device.

## 8. Supabase and privacy boundary

The documented Supabase project ID is `epltxklawpcxxbaleswg`.

### Source-backed tables and RPC surface

| Surface | Purpose |
|---|---|
| `profiles` | Display name, partner relationship and synced app preferences |
| `quiz_answers` | Owner-only onboarding/tracking-preference dictionary |
| `cycle_settings` | One current cycle setup per user |
| `daily_logs` | One owner-scoped row per date, including private `sexual_activity` |
| `ph_readings` | Owner-scoped vaginal/legacy readings with sync metadata/tombstones |
| `partner_invites` | Invite code, inviter, intended email and lifecycle status |
| `waitlist_emails` + `join_waitlist` | Pre-auth email capture through a restricted RPC |

The pH constraint is measurement-type-aware: vaginal **3.8–7.0**, legacy urine **4.5–9.0**.
Checked-in bootstrap schema, migrations, DTOs and deployed database state must be reviewed together;
a migration file is not proof that production has received it.

### Edge Functions

- `send_partner_invite`: emails an already-created invite when mail delivery is configured.
- `accept_partner_invite`: verifies the signed-in invitee, email, status and expiry, then links.
- `decline_partner_invite`: lets the intended recipient refuse without gaining table read access.
- `unlink_partner`: removes the linked relationship.
- `delete_account`: removes the authenticated account and owned data.

The app inserts the `partner_invites` row before asking `send_partner_invite` to email it. Email
delivery and invite creation are separate success states; a valid link can still be shared if email
delivery is unavailable.

### Security and privacy invariants

- Health records are owner-scoped by `auth.uid()` and RLS.
- Partner linking does not grant access to cycle, daily-log, intimacy or pH data.
- The publishable client key is not the security boundary; RLS/server authorization is.
- Quiz answers and intimacy are sensitive owner data and are cleared locally on account change.
- App and backend deletion must be verified together whenever a new owner-data table is introduced.
- The partner hardening migration and `decline_partner_invite` function present in the current
  working tree must be applied and verified before describing those behaviours as production-ready.

## 9. Medical content and citations

- Seventeen bundled medical sources currently back the iOS citation system.
- `MedicalSourceStore`, inline citation links and source footers serve screen/article claims.
- Profile → Medical Sources & Disclaimer lists the references.
- pH, hydration, nutrition and relevant Learn surfaces use the mapped source system.
- Medical copy remains educational and descriptive. Do not introduce diagnosis, treatment, causal
  claims or unsupported sex-selection guidance.

## 10. Repository map

```text
App/Genesyx/
  Data/                 repositories, LocalStore, DTOs, remote backend, composition root
  Notifications/        service, content, routing, Learn state
  Resources/            medical sources and app resources
  UI/                    Home, Track, pH, Nutrition, Insights, Learn, Profile, onboarding
  Util/                  calendar and platform helpers

Sources/GenesyxCore/
  Cycle/                 cycle setup and projection engine
  Insights/              hydration, sleep, symptoms, supplements and weekly summaries
  Models/                day, cycle, log, pH, account and custom-supplement models
  Notifications/         pure planner, categories and supplement-reminder models
  Ph/                    validation, copy, insight and sync rules
  Streaks/Tracking/      shared meaningful-day and streak contracts

Tests/GenesyxCoreTests/  pure Swift-package tests
App/GenesyxTests/        app/repository/content/backend tests
App/GenesyxUITests/      simulator/UI journeys
supabase/                migrations and Edge Functions
docs/                    release, backend, design and handoff material
project.yml              XcodeGen source; official version 1.2.0 (18)
```

Generated build folders and dependency checkouts are not product source of truth.

## 11. Verification and release boundary

Independently rerun for this inventory refresh:

- `swift test`: **180 passed, 0 failed**.
- Generic iOS Simulator build with code signing disabled: **BUILD SUCCEEDED**.
- `project.yml` and `Genesyx.xcodeproj/project.pbxproj`: **1.2.0 (18)** and bundle ID agree.

Not independently rerun or live-verified in this audit:

- Full app unit/UI suite on a named simulator.
- Physical-device notification/OAuth/deep-link checks.
- Signed archive/export and uploaded binary identity.
- Current App Store Connect/TestFlight status.
- Live Supabase schema/function/RLS state for the newest working-tree backend changes.

A green source build does not prove an uploaded build, a published TestFlight build or a production
backend migration. Those are separate release gates.

## 12. Capability status

| Capability | Current source status |
|---|---|
| Seven-tab shell including dedicated pH tab | Implemented |
| Cycle setup and projected calendar | Implemented; single-setup prediction only |
| Backdated daily logging | Implemented |
| Mood/energy/symptom/sleep/water/supplement/note logging | Implemented |
| Private intimacy logging | Implemented; owner-only and excluded from streak semantics |
| Vaginal pH entry/history/two-band trend/sync | Implemented |
| Legacy urine readings | Preserved and excluded from vaginal insight |
| Hydration units and custom glass size | Implemented; display-only, ml remains canonical |
| Custom supplements | Implemented device-locally; iOS Supabase sync pending |
| Per-supplement reminder hours | Implemented device-locally |
| Real-data Insights | Implemented with empty states |
| Unified 7/14/21/30-day intelligent-partner programme | **Not implemented** |
| Thirty-article Learn library and dated weekly releases | Implemented in source |
| Quiz-answer persistence/editing | Implemented locally and through `quiz_answers` backend |
| Local notifications and routing | Implemented; device verification required |
| Partner invite/share/accept/decline/revoke/unlink | Implemented in source; newest deployment checks required |
| Partner health-data sharing | Deliberately not enabled |
| Pregnancy tracking | Preview only |
| Universal Links | Parser/config exists; activation not verified and sharing stays custom scheme |
| Ads or third-party analytics | Not present |

## 13. Maintenance rules

Update this file whenever a change adds or removes:

1. A screen, tab, route, sheet or notification destination.
2. A tracked field, data model, threshold, metric, prediction or insight.
3. A repository, persistence key, sync rule, table, RLS policy, migration or Edge Function.
4. Authentication, deletion, partner, privacy, citation or analytics behaviour.
5. A capability moving between preview, local-only, conditional, implemented or released.
6. A source version/build or store-verified release state.

Always inspect implementation and tests. Keep **official source version**, **compiled artifact**,
**store upload/publication** and **backend deployment** as separate evidence levels. Never describe
derived estimates as measurements or clinical facts.

---

_Last audited from the working iOS repository on 12 August 2026: `main` / `b1ab67b` plus documented
working-tree changes. Official iOS source version: **1.2.0 (18)**._
