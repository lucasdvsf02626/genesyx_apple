# Genesyx iOS — Repository and App Inventory

**Purpose:** the current, code-backed map of everything in Genesyx iOS: product surfaces, domain logic, tracked data, persistence and sync, insights, notifications, backend, privacy boundaries, and repository layout.

This document describes the repository as it exists on **16 July 2026**. It is an implementation inventory, not a promise that device-only integrations have been production-verified.

| Repository snapshot | Value |
|---|---|
| Branch | `feature/v1.1-contract` |
| HEAD at audit | `e006187` |
| App version | `1.1.0` (build `12`) |
| Bundle ID | `com.genesyx.app` |
| Deployment target | iOS 16.0 |
| Main stack | SwiftUI, Swift Charts, GenesyxCore, Supabase Swift, Google Sign-In |
| Main navigation | Six persistent custom tabs: Home, Track, Nutrition, Insights, Learn, Profile |
| Local storage | `UserDefaults` plus Codable records through `LocalStore` |
| Cloud storage | Supabase Auth, PostgREST tables, and Edge Functions |
| Analytics/ads | None in this repository |

> The working tree contained active, uncommitted v1.1 hydration and screen changes during this audit. This inventory includes those files as present, without modifying them.

## 1. Product in one view

Genesyx is a native fertility-preparation and cycle-awareness app. It combines cycle predictions, daily wellbeing logging, hydration and nutrition guidance, urine pH tracking, personalised pattern summaries, educational content, reminders, and optional partner account linking.

The app deliberately distinguishes:

- **Recorded data:** values the user entered, such as water, sleep, mood, symptoms, supplements, notes, cycle settings, and pH readings.
- **Derived information:** phase, fertile-window, streak, consistency, weekly-summary, and coaching outputs computed from recorded data.
- **Guidance:** static, evidence-informed nutrition and Learn content.
- **Predictions:** cycle and ovulation estimates based on the user's settings; these are not clinical measurements.

## 2. Runtime architecture and data flow

```text
SwiftUI screen
    ↓ reads and writes
Observable repository
    ├─ LocalStore (immediate on-device persistence)
    └─ optional Supabase backend
          ├─ Auth
          ├─ profiles
          ├─ cycle_settings
          ├─ daily_logs
          ├─ ph_readings
          ├─ partner_invites
          └─ Edge Functions

Repository data
    ↓
GenesyxCore pure logic
    ↓
screen cards, trends, summaries, reminders, and coaching copy
```

`AppContainer` is the composition root. It constructs the repositories, selects an optional backend, hydrates cloud data, retries pending pushes when the app returns to the foreground, and clears account-scoped local health data on sign-out or deletion.

The app is local-first at interaction time and online-sync capable when Supabase is configured. UI code observes repository state; calculation code lives mainly in the UI-free `GenesyxCore` Swift package.

## 3. App shell, authentication, and routing

### Root flow

`RootView` gates the six-tab app behind onboarding and authentication. Onboarding contains splash, introduction, quiz, readiness summary, and waitlist/auth steps. Completion is persisted so returning users do not repeat the flow.

### Authentication

- Email/password sign-up and sign-in through Supabase.
- Email-confirmation-required handling and confirmation resend support.
- Sign in with Apple using nonce verification.
- Google Sign-In followed by Supabase ID-token authentication.
- Password-reset email from Profile.
- Sign-out with account-scoped local-data cleanup.
- In-app permanent account deletion through the `delete_account` Edge Function.
- Local permissive authentication exists only in debug/test builds; Release does not fake a session when the backend is unavailable.

### Navigation and deep links

The custom tab bar keeps all six tabs visible and keeps each tab alive in a `ZStack`, preserving its scroll/navigation state while switching tabs. `TabRouter` also routes notification taps.

Supported app routing includes the `genesyx://` custom scheme for invite and notification destinations. Learn reminders can open a specific article by slug. Universal Links remain a deployment/configuration concern and should not be assumed active from the route code alone.

## 4. Screens and user-visible behavior

### Home

Home is the daily overview and action surface. It shows the current cycle context when cycle settings exist, a hydration progress card with goal pacing/coaching, recent tracking context, a pH prompt, and the pregnancy-pathway preview. If cycle data is missing, Home gives an honest setup prompt instead of displaying invented predictions.

### Track

Track is the operational tracking hub.

- Month calendar with phase colouring and selected-day state.
- Cycle setup/edit sheet for last period date, typical cycle length, and period length.
- Predicted phase, fertile-window, and ovulation timing derived by `CycleEngine`.
- Tracker cards and detail views for cycle, urine pH, hydration, sleep, symptoms, and nutrition.
- Hydration detail supports manual entry, quick-add amounts, today's percentage, streak, seven-day goal view, and daily history.
- Sleep, symptoms, and nutrition detail surfaces read from the daily-log repository.
- Day detail shows the actual record for that date and supports logging/editing rather than filling an empty day with sample content.

### Log Today

The daily log is opened as a sheet/action flow rather than a seventh tab. One record exists per calendar day and may contain:

- Mood: great, good, okay, or low.
- Energy: low, normal, or high.
- Symptoms: a set of selected symptoms.
- Sleep duration in minutes.
- Water total in millilitres.
- Supplements taken.
- Free-text notes.

Water, sleep, and supplements have dedicated entry sheets. Deleting a log is represented locally so the removal can propagate instead of reappearing after a cloud refresh.

### Nutrition

Nutrition combines phase-aware guidance with real tracking state.

- Current nutrition focus and phase-specific focus foods from `NutritionContent`.
- Hydration progress and a direct track action.
- Supplement plan guidance for folate, omega-3, vitamin D, and zinc.
- Actual supplement completion based on the current day's log.
- Urine pH tracker entry point and history.

The content is guidance; it does not diagnose deficiencies or claim that logged supplements were prescribed.

### Insights

Insights compute from repository data and show explicit empty states when the evidence is missing. The current screen includes:

| Surface | Inputs | What it derives |
|---|---|---|
| Weekly summary | Current and prior seven-day logs | Logged-day totals, mood/energy tallies, hydration/sleep/supplement deltas, and a narrative line |
| Consistency | Meaningful daily logs | Current and best logging streaks plus weekly activity |
| Urine pH | pH reading history | Latest classification, trend/delta, and reading-count context |
| Hydration | Seven daily water totals | Goal days, current streak, average/percentage, trend, and coaching context |
| Nutrition consistency | Daily supplement counts | Days logged and weekly consistency pattern |
| Sleep | Daily sleep minutes | Logged nights, average duration, and a contextual insight line |
| Cycle regularity | Cycle settings | User cycle length compared with the typical 21–35 day range |
| Symptom patterns | Four weeks of daily logs | Most frequent symptoms and week-by-week frequency |
| Ovulation | Cycle settings and today's date | Estimated ovulation day/window and current-cycle context |
| My logs | Full daily-log history | Chronological access to everything recorded |

These are deterministic summaries of app data, not medical diagnoses. A single configured cycle length is not a longitudinal regularity measurement; the UI labels that card as the current setup.

### Learn

Learn is native content stored in Swift, with landing, featured content, category browsing, search, article detail, related articles, and share actions. Read state is stored by `LearnReadLog`. Notification routing can open an article directly; missing slugs fail into an honest unavailable-article state.

### Profile

Profile contains:

- Display name and signed-in email.
- Focus mode and light/dark/system theme preference.
- Gentle-reminder toggle and reminder time.
- Notification permission status and Settings guidance.
- Password reset, sign-out, and permanent account deletion.
- Partner invite, pending invite, linked partner, and unlink controls.
- App/legal/support information exposed by the profile UI, including external Privacy Policy and
  Help & Support links.

### Pregnancy preview

`PregnancyView` is a coming-soon/preview pathway. Pregnancy tracking is not an implemented v1 data model and must not be described as active tracking.

## 5. Tracking model and patterns

### Meaningful-day tracking

`TrackingEngine` centralises shared tracking metrics so screens do not invent their own definitions. A meaningful day is based on the presence of real user-entered daily-log data. From sets of qualifying calendar dates it derives:

- Current streak ending today or yesterday, depending on the engine's continuity rules.
- Best historical streak.
- Days on a hydration goal.
- Consecutive week-level performance.
- Hydration-specific and general logging day sets.

Calendar logic uses `CalendarDate`, an integer day abstraction, to avoid time-of-day and daylight-saving errors in streaks and day-keyed records.

### Hydration pattern

- Default goal: **2,400 ml/day** where no user-specific goal is supplied.
- UI stores a daily total, not individual drink events.
- Quick add and manual entry update the current day's `DailyLog.waterMl`.
- `HydrationInsightLogic` builds a seven-day series, goal-day count, streak, average, and insight copy.
- `HydrationStatusEvaluator` compares current percentage with expected progress for the hour of day.
- `HydrationCoach` chooses morning/afternoon/evening language, phase context, and streak wording without shaming missed days.

### Cycle pattern

`CycleEngine` uses the last period date, cycle length, and period length to calculate day of cycle, menstrual/follicular/fertile/ovulation/luteal classification, fertile window, ovulation day, and calendar cells. The settings are projections and do not learn a new average from historical period events because the current model stores one settings row, not a period-event history.

### pH pattern

pH readings contain an ID, numeric value, timestamp, and optional notes. `PhStatus` classifies the latest value; `PhInsightLogic` derives display status and trend only when enough readings exist. Swift Charts renders the history. Local sync metadata tracks update time, pending state, and tombstones so offline edits and deletions can merge safely.

### Nutrition, sleep, symptoms, and supplements

All four are fields of the day-keyed `DailyLog`; they are not separate event tables. Insight logic therefore measures days with data and daily totals/frequencies, not individual timestamps within a day.

## 6. Domain logic in GenesyxCore

`Sources/GenesyxCore` is UI-independent and covered by `swift test`.

| Area | Main types |
|---|---|
| Calendar/model | `CalendarDate`, `YearMonth`, `CycleSettings`, `DailyLog`, `PhReading`, `PartnerInvite` |
| Cycle | `CycleEngine`, `CycleSetup`, phase/fertile-window models |
| Tracking/streaks | `TrackingEngine`, `TrackingMetrics`, `StreakEngine` |
| Hydration | `HydrationInsightLogic`, `HydrationStatusEvaluator`, `HydrationCoach` |
| Other insights | `ConsistencyInsightLogic`, `NutritionConsistencyLogic`, `SleepInsightLogic`, `CycleRegularityLogic`, `SymptomPatternLogic`, `OvulationLogic`, `WeeklySummaryLogic` |
| pH | `PhStatus`, `PhInsightLogic`, `PhSync` |
| Notifications | `NotificationPlanner` |
| Content | `NutritionContent`, `CycleContent`, `QuizContent` |

The intended boundary is: core code decides facts and display models; repositories own persistence/sync; SwiftUI owns presentation and user interaction.

## 7. Persistence and cloud sync

### On-device

`LocalStore` namespaces values under `genesyx.*` in `UserDefaults`. Codable DTOs keep persistence details out of domain models. Repository state is updated locally first so tracking remains responsive without a network.

### Repository responsibilities

| Repository | Owns |
|---|---|
| `SessionRepository` | Auth state, account operations, display name hooks, hydrate/cleanup callbacks |
| `CycleRepository` | Cycle settings and their pending cloud update |
| `DailyLogRepository` | Day-keyed daily logs, water shortcuts, pending changes/deletions |
| `PhRepository` | Reading history, edits/deletes, merge and pending sync |
| `PreferencesRepository` | Focus mode, theme, reminders, notification-related local state |
| `PartnerRepository` | Invites, linked partner, acceptance refresh, unlink |

When a backend exists, `AppContainer.hydrate()` refreshes profile/preferences, cycle, daily logs, pH, and partner state. Repositories push owed local work before accepting remote state. `drainPending()` retries foregrounded work and refreshes partner state because acceptance may occur on another device.

On sign-out or deletion, cycle settings, daily logs, pH, notification milestone/read state, and partner state are cleared from the device so a later account cannot inherit them.

## 8. Supabase backend and security boundary

The backend project ID documented in this repository is `epltxklawpcxxbaleswg`.

### Tables

| Table | Shape and purpose |
|---|---|
| `profiles` | One row per auth user; display name, linked partner, focus/theme/push preferences after migrations |
| `cycle_settings` | One row per user; last period date, cycle length, period length, update timestamp |
| `daily_logs` | One row per user/date; mood, energy, symptoms, sleep, water, supplements, notes, update/deletion metadata after sync hardening |
| `ph_readings` | Many per user; value, recorded time, notes, update/deletion metadata |
| `partner_invites` | Inviter, invitee email, unique code, pending/accepted/revoked status |

The checked-in `docs/supabase_schema.sql` is a bootstrap schema; migrations under `supabase/migrations` add sync hardening and preference defaults. For the exact live-compatible shape, read the bootstrap and migrations together with `RemoteModels.swift`.

### Row-level security and privacy

- Health records are owner-scoped by `auth.uid()`.
- A user can read/update their own profile; linked-partner profile visibility is limited to the relationship fields allowed by policy.
- Linking accounts does **not** expose cycle, log, or pH data to the partner under the current owner-only health-data policies.
- Invite acceptance and account deletion use server-side Edge Functions where elevated operations are required.
- The publishable/anon client key is not the security boundary; RLS and server-side authorization are.

### Edge Functions

- `send_partner_invite`: creates/sends an invite when email delivery is configured and reports a safe fallback when it is not.
- `accept_partner_invite`: validates the signed-in invitee and links both profiles.
- `unlink_partner`: removes the relationship.
- `delete_account`: deletes the authenticated account and cascaded data.

## 9. Partner linking behavior

An authenticated user invites a specific email. The app can share the generated invite link even if transactional email is unavailable. Acceptance requires the invitee to authenticate with the invited address. Once accepted, both accounts show the relationship; current logs and readings remain private. Unlinking is supported.

Email delivery depends on external Resend/domain/secrets configuration and should be tested in the deployed environment. Invite creation and share-sheet fallback are separate from email delivery success.

## 10. Notifications and engagement pattern

Genesyx currently plans local notifications; this repository does not implement a general analytics or advertising pipeline.

`NotificationPlanner`, `NotificationContent`, and `NotificationService` coordinate:

- An evening check-in when today has no meaningful log.
- Weekly pH reminder.
- Weekly phase context.
- Nutrition check-in.
- Sunday Learn/article nudge.
- Positive milestone/streak messaging when earned.

The planner caps reminders to a gentle cadence (the Profile copy promises at most one a day) and avoids negative language about a missed streak. The user's push preference defaults off after migration; iOS permission and actual delivery require device verification. Taps route to the relevant tab/article through `NotificationRouter`.

`LearnReadLog` and notification milestone state are functional state for reminder relevance, not third-party behavioral analytics.

## 11. Content, design, and accessibility

- Native SwiftUI design system in `UI/Theme`: semantic colours, light/dark/system themes, an
  intentional Apple-system-font type scale, shared controls, cards, and pills.
- Swift Charts is used for real pH and tracking visualisations.
- Learn, cycle, nutrition, quiz, and notification copy is checked into the repository rather than fetched from a CMS.
- Primary tab buttons and important controls include accessibility labels/identifiers; full VoiceOver, Dynamic Type, contrast, and reduced-motion QA remains a release test responsibility.
- Six current-build App Store screenshots (Home, Track, Nutrition, Insights, Learn, Profile) live
  in `docs/appstore_screenshots` as opaque 1320×2868 PNGs. Simulator captures are prepared with
  `scripts/prepare_store_screenshots.sh`; additional working screenshots live in `docs/screenshots`.

## 12. Repository map

```text
App/Genesyx/
├── Data/
│   ├── App/                 app entry, composition root, root gate, deep links
│   ├── Remote/              backend protocols, Supabase implementation, row DTOs
│   ├── *Repository.swift    observable feature repositories
│   ├── LocalStore.swift     Codable/UserDefaults storage
│   └── PersistenceDTOs.swift
├── Notifications/           planning content, service, router, Learn read state
├── UI/
│   ├── Auth, Onboarding
│   ├── Home, Track, Log, Nutrition, Insights, Learn, Profile
│   ├── Ph, Invite, Pregnancy
│   ├── Components
│   └── Theme
├── Resources/               assets, fonts, privacy manifest
├── Info.plist
└── Genesyx.entitlements

Sources/GenesyxCore/          pure models, engines, insight and content logic
Tests/GenesyxCoreTests/       Swift Package logic tests and shared tracking vectors
App/GenesyxTests/             repository, persistence, auth, insight, content tests
App/GenesyxUITests/           navigation, screen and notification UI tests
supabase/functions/           deployed server operations
supabase/migrations/          incremental database hardening
docs/                         backend, release, privacy and App Store operations
project.yml                   XcodeGen project definition and version settings
Package.swift                 GenesyxCore package definition
```

Generated folders such as `build_sim/` are build artifacts/dependency checkouts, not authored app source and should not be used as the product source of truth.

## 13. Tests and verification

### Test suites present

- GenesyxCore: calendar, cycle setup/engine, content, tracking vectors, streaks, pH sync/insights, notifications, consistency, hydration, nutrition, sleep, and weekly summaries.
- App unit tests: repositories, persistence, backend swap, auth/partner backend, partner behavior, deep links, Learn/quiz content, notifications, hydration/nutrition, and real insight wiring.
- UI tests: main user surfaces and notification routing flows.

Useful commands:

```bash
swift test
xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild archive -project Genesyx.xcodeproj -scheme Genesyx -archivePath /tmp/Genesyx.xcarchive
```

Passing tests prove deterministic logic and exercised app flows; Apple/Google OAuth, notification delivery, invite email, two-account partner linking, account deletion, and archive/signing still require the relevant configured environment or physical-device checks.

## 14. Implemented, conditional, and deferred capabilities

| Capability | Current state |
|---|---|
| Cycle settings and calculated calendar | Implemented |
| Daily mood/energy/symptom/sleep/water/supplement/note logging | Implemented |
| pH entry, history, trend, sync | Implemented |
| Hydration coaching and tracker detail | Implemented in the current working tree; complete regression verification still required |
| Real-data insights and weekly summary | Implemented with empty states |
| Learn library/search/detail/deep link/read state | Implemented |
| Email, Apple, and Google authentication | Implemented; provider/device configuration required |
| Local reminders and notification routing | Implemented; device delivery confirmation required |
| Partner invite/share/accept/unlink | Implemented; two-account deployed verification required |
| Partner email delivery | Conditional on Resend deployment configuration |
| Partner health-data sharing | Deliberately not enabled by current RLS |
| Pregnancy tracking | Preview only; no tracking model |
| Universal Links | Code/config work exists, but production activation is not assumed |
| Ads or third-party analytics | Not present |

## 15. Maintenance rules for this inventory

Update this file whenever a change adds or removes any of the following:

1. A screen, tab, sheet, or deep-link destination.
2. A tracked field, model, derived metric, insight, or prediction rule.
3. A repository, persistence key, sync/merge rule, table, RLS policy, or Edge Function.
4. Authentication, account deletion, partner, notification, privacy, or analytics behavior.
5. A capability that moves between preview, conditional, implemented, or removed.

When updating, verify the implementation files and tests rather than copying an older status report. Keep device/deployment verification separate from code presence, and never describe derived estimates as measured clinical facts.

---

_Last audited from the live repository on 16 July 2026 at `feature/v1.1-contract` / `e006187`._
