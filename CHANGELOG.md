# Changelog

All notable changes to Genesyx (iOS) are recorded here.

## Unreleased — client change list, Sprint 1 (main, `71567c8` … `998b5c2`, 10 Aug 2026)

Twelve items from the client's "Simplified Consolidated Changes" list, all chosen because they need
no client or medical-reviewer sign-off. Audit and plan in `docs/CHANGE_LIST_PLAN.md`.

### Corrections
- **Urine → vaginal pH in Learn** (`71567c8`). Slug `guide-urine-tracker-with-stick` →
  `guide-vaginal-ph-tracker`, with an old→new map in `LearnReadLog` so the rename does not reset read
  history or re-offer an article she has finished. Deleted three orphaned `urine*` image assets.
  Fixed a Learn article that claimed logging is blocked offline — `LogView.save()` never blocked, and
  this is the likely origin of the client's "offline symbol" report.
- **Light mode is the default** (`560591e`); the dark toggle stays in Profile.
- **pH disclaimer collapses** into an expandable panel on the card. It stays permanently visible on
  the log sheet — the moment she is entering a reading is not the moment to hide the safety note.

### Tracking
- **Sexual activity** (`f082d31`, `ca28088`). A plain `Bool` on `DailyLog`, an Intimacy chip in the
  log sheet, and `daily_logs.sexual_activity` in Supabase. Carries its privacy promise on screen:
  *"Private to you. A linked partner sees your name — never your logs."* That claim is test-asserted,
  not just written. Reaches no partner surface and no notification copy.
  ⚠️ Deliberately **not** counted by `TrackingEngine.isMeaningfulLog` / `StreakEngine.hasAnyEntry`:
  those are the cross-platform contract, so flipping one client alone gives iOS and Android different
  streaks for identical data. Needs one coordinated change across both clients and
  `tracking_test_vectors.json`, or none.
- **Calendar markers** (`8c9f1f1`) for pH tests, symptoms/notes and intimacy, with the legend
  extended to name all three. Water, mood, energy, sleep and supplements are deliberately unmarked —
  a grid where most days carry most dots marks nothing.
  Fixed en route (pre-existing): every cell squared the day *number* rather than the cell, so
  two-digit days rendered as "…" — 8 of 31 days unreadable on the August grid.
- **Onboarding quiz answers are kept** (`148e754`), to `profiles.quiz_answers` (`jsonb`). The quiz
  runs before sign-up, so answers are written on-device and stay owed to the server until sign-in
  drains them. Nothing reads them yet by design — the consumer is the Girl/Boy question, which is
  blocked on sign-off.

### Notifications
- **Fertile-window alert** (`d35cfa0`) the morning her predicted window opens, with discreet
  lock-screen wording by default.
- **Per-category toggles** (`5dda691`) — one global switch would not hold eight categories.
- **Per-supplement reminder times** (`39a19e6`), with "No reminder" a first-class choice.
- **Weekly article drop** (`855a9be`, `998b5c2`). The Sunday nudge, a new Learn tab badge and a new
  Home dashboard card all pick through one rule, so the three can never name different articles. The
  badge counts *new-and-unread* only: zero on a first install, because badging all sixteen articles
  would read as a backlog rather than an invitation.

### Owed
- Two migrations are **not applied** — `20260810_daily_logs_sexual_activity.sql` and
  `20260810_profiles_quiz_answers.sql` need running by hand in the Supabase SQL Editor. Until then
  those columns exist only in the app's decoders, which tolerate their absence.
- `profiles` carries a partner-read policy, and her answer to the baby's-sex question now lives in
  that row. If the policy selects whole rows rather than named columns, the "just for you" promise is
  false. The check is written into the migration §2 and must run before production.

## Unreleased — database & docs (main, build 16 source `547d2d4`)

### Database — pH constraint codified in version control
- Added migration `supabase/migrations/20260722_ph_conditional_value_range.sql`. It captures the
  production reality (applied via the dashboard on 22 Jul 2026) in version control: the
  `measurement_type` column + `ph_measurement_type_check` (`urine`/`vaginal`), and a **conditional
  `ph_value_range`** — vaginal `3.5–7.0`, legacy urine `4.5–9.0` — replacing the old unconditional
  4.5–9.0 CHECK. Idempotent; drops the old check name-agnostically (a `pg_constraint` `DO` block) so a
  future `db push`/rebuild reproduces prod instead of reintroducing the single-range rule.
- Updated `docs/supabase_schema.sql` `ph_readings` to show `measurement_type` + the conditional check.
- **Not auto-applied** from the repo; a no-op against the live DB (which already has this).

### Docs
- Refreshed `App_Inventory.md` to `main`/`547d2d4`, 1.1.1 (16): vaginal-pH two-band model, the Home
  "Check your pH" card, sleep ISO-week alignment, the medical-citation system + Medical Sources
  screen, the reviewer/demo account, and the pH DB constraint. Corrected the stale FEATURES.md note.

## 1.1.1 (16) — external TestFlight

- Bumped `MARKETING_VERSION` 1.1.1 / `CURRENT_PROJECT_VERSION` 16 for external TestFlight testing.
- Signed, uploadable archive built from `main @ 547d2d4`; `strings`-verified free of user-facing
  "Urine pH" (only the neutral `urine (legacy)` marker, enum raw value, and slug remain).
- Reviewer/demo account (`demo@genesyx.co.uk`) verified against production: profile + cycle +
  ~21 daily logs + pH readings present, so App Review lands on a populated app.

## build 17 — in flight (`fix/privacy-links-b17`, PR #2, not merged)

- Unifies both in-app privacy entry points on `https://genesyx.co.uk/policies/privacy-policy`
  (Profile row + the disclaimer alert's "Read our full privacy policy" button).
- Deletes the stale `docs/PRIVACY_POLICY.md`. Not required for the build-16 submission.

## Unreleased — build 15

### Vaginal pH migration (complete)
Full clinical migration of the pH tracker from the legacy urine model to vaginal pH. The Supabase
migration was already applied on 22 Jul 2026 (column `measurement_type text NOT NULL DEFAULT 'urine'`
with constraint `ph_measurement_type_check` in {'urine','vaginal'}) — **no DB work in this build**.

- **Scale & bands** (`PhStatus`): range **3.5–7.0**, step 0.1; two-band model **Healthy (≤4.5) /
  Elevated (>4.5)** replacing acidic/optimal/alkaline. Two band colours (`phHealthy`/`phElevated`).
  Chart domain 3.5–7.0 with a two-band background; log dial defaults to 4.2 and clamps to range.
- **measurement_type wired end-to-end** (`PhReading` → `PhReadingRow` remote DTO → `PhReadingDTO`
  local DTO → `PhRepository`): new readings written as `vaginal`; rows/records missing the field
  decode as `urine` (legacy tolerance — never defaulted to vaginal).
- **Legacy exclusion**: `PhInsightLogic` filters to vaginal-only before computing; all-legacy input
  returns the empty state. Legacy rows show the neutral `urine (legacy)` marker (one canonical
  lowercase string) on the pH card and Track row, and are clamped on the chart — never classified.
- **One-time notice** on first pH-section visit (`ph_vaginal_notice_seen`), dismissible, no re-fire.
- **Copy** (`PhCopy`, British English): Healthy / Elevated insight lines, an Elevated GP/pharmacist
  signpost, a detail+log disclaimer, and the migration notice — all rendered from one source.
- **Learn rewrite**: the pH guides now describe vaginal pH (typical range 3.8–4.5, cycle variation,
  when to speak to a GP); all urine-collection instructions removed. No user-visible "urine" remains
  except the legacy marker. No diet advice, condition names, or treatment claims in pH copy.
- **Citations re-pointed**: removed `statpearls-urinalysis`; added `vaginal-ph` (NHS *Bacterial
  vaginosis*) and `statpearls-vaginitis` (StatPearls *Vaginitis*); all pH guides + the pH footer
  now cite these.
- **Tests**: rewrote `PhInsightLogicTests` for the vaginal model (boundaries, clamp, legacy
  exclusion, verbatim copy, pH-copy banned-phrase guard); added `measurement_type` DTO round-trip
  tests, a Learn pH-content banned-phrase guard (`PhContentGuardTests`), and a one-time-notice UI
  test. Green: core 116, app unit 138, UI 23 (1 intentional skip), 0 failures.

Delivered across commits `4f73d9e` (1/5 scale+bands), `8053318` (2/5 measurement_type+legacy),
`fd6de38` (3/5 copy+Learn+citations), `f234641` (4/5 tests).

## Unreleased — build 14 (superseded by build 15)

### pH tracker relabel: Urine → Vaginal pH

### pH tracker relabel: Urine → Vaginal pH
- Renamed the pH feature wording from "Urine pH" to "Vaginal pH" across the visible UI:
  - Track: tracker row title + pH detail sheet title (`TrackView.swift`).
  - Insights: pH card title + the pushed "Open tracker" screen title (`InsightsView.swift`).
  - Shared pH card (`PhTrackerSection.swift`, used by Nutrition + the Insights tracker screen):
    "Urine Tracker" → "Vaginal pH Tracker"; log-sheet label → "Track your vaginal pH from 4.5 to 9.0."
- Caveat copy rewritten (cycle-tied, no numeric range, no citation), on both the Insights pH card
  and the shared card: "Vaginal pH naturally shifts across your cycle. Logging your cycle day
  alongside each reading helps you understand your own patterns."
- Removed the urine-specific hydration claim "…concentrated urine reads more acidic" and its
  `statpearls-urinalysis` citation from the Insights hydration card (false for vaginal pH).
- Updated `CitationE2ETests` to drop the removed urinalysis-citation assertions. Build green;
  CitationE2ETests 7/7 pass on iPhone 17 Pro.

**Known follow-ups — ✅ RESOLVED in build 15:** the pH input scale/bands, the Nutrition
"Why hydration?" copy, and the Learn urine-strip guides were all migrated to the vaginal model in
build 15 (see above).

## 2026-07-18 — build 1.1.0 (13)

### App Store Guideline 1.4.1 — medical citations (release-critical)
- Added a reusable citation system: `MedicalSource` model, bundled `medical_sources.json`
  (11 verified NHS / EFSA / NCBI-StatPearls / PubMed references), `MedicalSourceStore`,
  and `CitationLink` + `SourcesFooter` SwiftUI components.
- Insights → Hydration card: added a "Source" link under the pH-comparability claim.
- Insights → pH card: added a pH-range caveat + citation; removed dietary advice.
- Nutrition → daily water goal: added an EFSA basis line + citation.
- Nutrition → "Why hydration?": added a 4-source Sources footer.
- Nutrition / Track → Urine Tracker: added pH-range caveat + citation to the header.
- pH logic (`PhInsightLogic`): removed dietary recommendations; the tracker now shows
  descriptive trends only (recommendations to return, sourced, in 1.2.0).
- Learn: added a per-article Sources footer for the 8 articles/guides that make external
  health-fact claims (`LearnSourceMap`); behavioural articles keep the existing disclaimer.
- Profile → About: added a "Medical Sources & Disclaimer" screen (`MedicalSourcesView`)
  listing all 11 references with tappable links; existing disclaimer row kept.

### Sleep tracking
- Track sleep detail now uses the current ISO week (Mon–Sun), matching the Insights Sleep card.
- Sleep entry: capped the minute picker/stepper at 12h so the saved value always matches the pick.

### Home
- Added a compact "Check your pH" card that taps through to the Track pH tracker
  (via a new `TabRouter.pendingPh` flag).

### Tests
- Updated `PhInsightLogicTests` for the removed pH recommendations.
- Rewrote 3 stale Home UI tests to match the current hydration design (Track hydration
  sheet quick-add; disambiguated the "Track" query).
- Full suite green: 143 passing, 1 intentional skip. Existing UI suite passes on both
  iPhone 17 Pro and iPad Air 11-inch (M4).

### E2E QA + BUG-1 fix (final pre-release pass)
- Added E2E coverage: `CitationE2ETests` (7 — every 1.4.1 surface), `LifecycleE2ETests`
  (3 — background/foreground, relaunch, sign-out wipe not blanking sources),
  `SleepSmokeUITests` (1 — log→persist). Minimal a11y identifiers added to citation
  views only (copy/JSON/disclaimer unchanged).
- **BUG-1 (fixed):** on the reviewer's verification path (Nutrition → "Why hydration?"),
  the hydration card's whole-card `.background(...).onTapGesture` was winning taps over
  the inner button, so tapping the row navigated to Track instead of expanding the Sources
  footer. Moved tap-to-open-Track to an outer `.contentShape` + `.onTapGesture` so inner
  buttons win; added `.contentShape` to the header row. Verified on both devices.
- Result: full UI suite 21 pass / 1 skip / 0 fail on iPhone 17 Pro AND iPad Air 11-inch (M4);
  unit suite 133 pass. PR #1 (`feature/v1.1-contract` → `main`). Verdict: READY TO SHIP.

### App Store Connect — resubmission (manual, performed in browser by account holder)
Rejected submission `0bf33ae3-5e8d-4bae-a98d-5629b1363984` — Guideline 1.4.1. Steps:
1. My Apps → Genesyx → App Review page; confirm the rejected submission ID matches.
2. iOS 1.1.0 page: remove build (12), attach build (13). If (13) is not processed, stop.
3. App Review Information → Notes: replace with the reviewer notes (below).
4. Resolution Center: reply to the 1.4.1 message (dated July 17) with the same text.
5. Review the summary, then Submit for Review.

Reviewer notes / Resolution Center reply (verbatim):

> We've addressed Guideline 1.4.1 in build 13:
> 1. Inline 'Source' links now appear on every screen containing health or medical
>    information — hydration insights, the daily water goal, the 'Why hydration?' section,
>    the urine pH tracker, and every Learn article containing health information — linking
>    to NHS, EFSA, NCBI/StatPearls, and peer-reviewed sources (11 references in total).
> 2. A dedicated 'Medical Sources & Disclaimer' screen is available at Settings → Medical
>    Sources, listing all references with direct links.
> 3. Dietary recommendations based on pH readings have been removed; the tracker now shows
>    descriptive trends only, with a caveat that readings are for general wellness tracking,
>    plus a citation to the NCBI urinalysis reference.
> Path to verify: Nutrition tab → expand 'Why hydration?' → Sources footer; or Settings →
> Medical Sources & Disclaimer.
