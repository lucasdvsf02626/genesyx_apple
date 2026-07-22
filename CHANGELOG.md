# Changelog

All notable changes to Genesyx (iOS) are recorded here.

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
