# Changelog

All notable changes to Genesyx (iOS) are recorded here.

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
