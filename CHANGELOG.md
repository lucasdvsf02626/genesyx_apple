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
