# Genesyx iOS — Client Change List: Audit & Execution Plan

> Response to the client's "Simplified Consolidated Changes" list (received 2026-08-10).
> Audited against **v1.1.1 (build 17)**, baseline green at **125 domain + 139 app tests**.
> Legend: ✅ already shipped · 🟡 partial · ⬜ not started · ⚠️ needs a decision (off-code)

---

## 0. Read this first

**Roughly 40% of the client's list is already implemented.** Several items described as broken
are not broken. Verify before quoting or building.

| Client item | Verified reality |
|---|---|
| 3A "Add a daily logging streak" | ✅ Built, tested (17 tests), wired into Home/Track/Insights/Nutrition. `StreakEngine.swift` |
| 4A "Confirm what Add Partner does" | ✅ Works end to end: invite → DB code → email + share sheet → deep link → accept → unlink. Partner sees **name only**; logs/readings/notes already private |
| 1B "Entries don't stay on the right date" | ✅ No defect found. `DailyLogRepository.swift:29` keys on timezone-free `CalendarDate` day-number |
| 1D "Offline symbol appears" | ✅ No offline indicator exists. Zero hits for `NWPathMonitor`/`Reachability`/`isOffline`. No `.wifi`-only check, so cellular already works. Offline writes queue and drain on foreground |
| 1A pH add / history / interpretation | ✅ Log sheet, 7/30/90/All chart, healthy vs elevated bands |
| 1A "Why pH matters" explanation | ✅ `PhSpine` section in `PhTrackerSection.swift` |
| 2C Hydration by glasses or ml + progress | ✅ Shipped in `2dcbfd8`. Only *custom* glass size missing |
| 2D Personalised greeting | ✅ `HomeView.swift:63` uses display name |
| 3B Weekly article notification | ✅ Sunday 09:00 Learn nudge already ships |
| 2B "Hide greyed-out explanatory text" | ✅ Already behind disclosure toggles in `NutritionView.swift:145` |

### ⚠️ The compliance blocker

The codebase **forbids the content requested in items 1A and 1C — enforced by tests, not docs.**

Seven test files assert user-facing copy never contains `"sex selection"`, `"boy or girl"`,
`"gender sway"`, `"sway the sex"`, `"choose the sex"`, `"alkaline diet"`, `"balance your ph"`,
`"detox"`, `"flush toxins"`. pH articles additionally ban `"infection"`, `"thrush"`, `"candida"`,
`"vaginosis"`, `"bv"` (`PhContentGuardTests.swift:9`).

Enforcing files: `LearnContentTests`, `QuizContentTests`, `NotificationTests`, `RealInsightsTests`,
`HydrationInsightTests`, `NutritionHydrationTests`, `PhContentGuardTests`.

Three requests collide with these rails:

1. **Shettles method content** — Shettles *is* a sex-selection theory.
2. **Girl / Boy preference options** — `QuizContentTests.swift:8` bans `"boy or girl"`.
3. **"When to seek professional help" for vaginal health** — cannot say "signs of an infection"
   without failing the pH guard.

Item 1A also asks to **hide the medical disclaimer behind an info icon** while *adding* unproven
-theory content. Those point in opposite directions for App Store health-app review.

**This ground has already been walked.** `QuizContent.swift:91` carries an explicit note that a
previous "Did you know?" claim — that diet/pH can influence a baby's sex — was **deliberately
removed as unsupported and contradictory to the Learn content**. The Shettles request asks to
reintroduce that exact territory. Raise this directly with the client.

**Do not quietly edit these tests.** Relaxing them is a client + medical-reviewer decision.

---

## 1. Gate 0 — decisions before any code

- [ ] ⚠️ **G1 — Shettles + Girl/Boy sign-off.** Written client + medical-reviewer approval to relax
      the banned-phrase guards. *Blocks T7, T29b, all Shettles copy.*
- [ ] ⚠️ **G2 — pH tab placement.** 6 tabs exist today (`MainTabView.swift:12`) via a **custom** bar,
      because iOS collapses past five. A 7th is cramped on an iPhone SE. Decide: 7 tabs, or demote
      Insights into Home/Track. *Blocks T2.*
- [ ] ⚠️ **G3 — Offline symbol.** Request build number + screenshot from client. No code path exists;
      likely an older build or the Android client. *Blocks T9.*
- [ ] ⚠️ **G4 — Egg artwork.** Request original design files. `egg_female`/`egg_male` are orphaned
      (zero code references) and onboarding orbs are a self-described stand-in
      (`OnboardingFlowView.swift:49`). *Blocks T21.*

---

## 2. Phase 1 — corrections (8–10d)

T3–T5 are independent of every gate. Cleanest starting point — **all three shipped in `71567c8`**.

**T1 and T2 are one change, not two.** Removing pH from Nutrition without the dedicated tab leaves
pH reachable only from Track — strictly *less* discoverable, the opposite of the client's goal. So
T1 inherits G2's block. Do not ship T1 alone.

- [ ] ⬜ **T1 — Remove pH from Nutrition.** Delete `PhTrackerSection()` at `NutritionView.swift:50`.
      Also update the `guide-track-ph-in-nutrition` article, which documents the behaviour removed.
      *Needs G2 — ship with T2.*
- [ ] ⬜ **T2 — Dedicated pH tab.** Add to `MainTabView.swift:12`, pointing at
      `PhTrackerSection(variant: .full)`. *Needs G2.*
- [x] ✅ **T3 — Rename the urine slug.** `guide-urine-tracker-with-stick` → `guide-vaginal-ph-tracker`.
      Touched `LearnContent.swift:314`, `LearnSourceMap.swift:12`, `LearnContentTests.swift:57`,
      `PhContentGuardTests.swift:10`. `LearnReadLog` now carries an old→new slug map, so the rename
      does not reset read history or re-offer a read article in the Sunday nudge.
- [x] ✅ **T4 — Delete orphaned assets** `urine45`, `urinetrack34`, `urinetrack67` from
      `Assets.xcassets`. Verified unreferenced in any `.swift`/`.plist`/`.yml`/`.json`.
- [x] ✅ **T5 — Fix false offline copy.** `LearnContent.swift:365` claimed "Offline, it blocks the save
      and tells you to reconnect". `LogView.save()` (line 87) never blocks. Likely origin of the
      client's "offline" confusion.
- [x] ✅ **T6 — Disclaimer into expandable panel.** `PhTrackerSection.swift:97` and `:315`. Kept
      permanently visible on the **log sheet**; only the card copy collapses.
- [ ] ⬜ **T7 — Gender question → 4 options.** `Sources/GenesyxCore/Content/QuizContent.swift:83`:
      Girl / Boy / No preference / Prefer not to say, and skippable. Current options only record
      *that* a preference exists ("hope" / "either" / "private"), never which. *Needs G1.*
- [ ] ⬜ **T8 — Persist quiz answers.** `OnboardingFlowView.swift:155` collects answers into a local
      dict and **discards them on completion**. T7 is pointless without this. Needs a model field,
      repository write, and Supabase column.
- [ ] ⬜ **T9 — Connectivity write-up** for the client. *Needs G3.*

## 3. Phase 2 — the real gaps (15–18d)

- [x] ✅ **T10 — `sexualActivity` on `DailyLog`.** A plain `Bool` (default `false`), not
      protected/unprotected: this is a conception-prep app, so the question the data answers is
      whether it fell inside the fertile window. `false` means nothing recorded — the same collapse
      `waterMl == 0` and an empty `symptoms` already make.
- [x] ✅ **T11 — Persist it.** `DailyLogDTO`, `DailyLogRow` (`sexual_activity`), and
      `supabase/migrations/20260810_daily_logs_sexual_activity.sql`. Absent decodes as `false`
      everywhere: a day written before the column existed was never asked the question.

      ⚠️ **Deliberately NOT in `TrackingEngine.isMeaningfulLog`.** It plainly is a meaningful log,
      but that predicate is the cross-platform contract — the same rule runs in the Android
      `TrackingEngine` against the same `tracking_test_vectors.json`, so counting it here alone would
      give the two clients different streak numbers for identical data with nothing to report the
      divergence. **Android coordination item:** flip it in both clients and the vectors in one
      change. `MeaningfulLogTests.testStreakContractIgnoresSexualActivity` fails if someone flips it
      unilaterally. Until then a sex-only day does not extend her streak. **The dormancy half of that
      problem is solved in T12** — see below.
- [x] ✅ **T12 — Private logging UI.** An Intimacy chip in `LogView.swift`, between Symptoms and the
      mini-cards, carrying the promise on screen: *"Private to you. A linked partner sees your name —
      never your logs."* That claim is literal and now test-asserted — `PartnerRepository` exchanges
      display names, and `daily_logs` is owner-only under RLS. A partner link is a row in `profiles`,
      not a read grant.

      The notification layer folds `sexualActivity` in at `NotificationService.snapshot()` and
      `lastActivityDay()`, so a sex-only day no longer reads as silence and she is not nudged to log
      on a day she logged. Safe there and not in the engines: local notifications are iOS-only and
      mirror nothing. The **streak** consequence above still stands, awaiting Android.

      `StreakEngine.hasAnyEntry` carries the same ⚠️ as `isMeaningfulLog`, pinned by
      `MeaningfulLogTests.testTheStreakEnginesPredicateExcludesItToo` — otherwise the divergence
      arrives by the side door. The field reaches no partner surface and no notification copy, which
      lands on a lock screen anyone holding the phone can read.
- [ ] ⬜ **T13 — Calendar markers.** `TrackView.swift:146`. Period/fertile/ovulation/luteal already
      render as backgrounds; **add pH test, symptoms/notes, sexual activity as dots** — more
      background tints will not stay legible.
- [x] ✅ **T14 — Fertile-window notification.** Extends `NotificationPlanner.plan()`; `OvulationLogic`
      already computed the window. Discreet lock-screen wording by default (sensitive health data is
      visible to anyone holding the phone).
- [x] ✅ **T15 — Per-category notification toggles.** `ProfileView.swift:176`. One global switch would
      not hold 8 categories.
- [ ] ⬜ **T16 — Health Profile editor.** `ProfileView.swift:167` currently opens a static alert only.
- [ ] ⬜ **T17 — Tracking Preferences editor.** `ProfileView.swift:169`, same problem.
- [ ] ⬜ **T18 — Personal details editor** (email, DOB). Currently read-only.
- [ ] ⬜ **T19 — Password change.** `SessionRepository.swift:99` throws in local mode and surfaces an
      error. Either gate the row or wire the backend.

## 4. Phase 3 — design (10–20d, design-gated)

- [x] ✅ **T20 — Light mode default.** One line at `PreferencesRepository.swift:66`
      (`.system` → `.light`). Toggle already existed in Profile.
- [ ] ⬜ **T21 — Restore egg artwork.** Replace orbs at `OnboardingFlowView.swift:49`; wire
      `egg_female`/`egg_male`; add background motifs. *Needs G4.*
- [ ] ⬜ **T22 — Warm/premium visual pass.** Open-ended — require a design spec or this will sprawl.

## 5. Phase 4 — nutrition (15–20d)

- [ ] ⬜ **T23 — Custom glass size.** `Sources/GenesyxCore/Insights/HydrationUnit.swift:14` is 3
      fixed presets (glasses 250ml / cups 240ml / ml).
- [ ] ⬜ **T24 — Nutrition text pass.** Smaller than the client thinks; disclosures already exist.
- [ ] ⬜ **T25 — Phase-change card** linking to the `eating-with-your-cycle` article.
- [ ] ⬜ **T26 — Meal logging** model + UI. Replaces the "Coming soon" placeholder at
      `NutritionView.swift:304`. **Most expensive item on the list — scope separately.**
- [ ] ⬜ **T27 — Recipe cards** with imagery. Needs content + design, not just code.

## 6. Phase 5 — education (6–8d + medical review)

- [~] 🟡 **T28 — Weekly article drop + unread badge/dashboard card.** Notification half ✅ (the Sunday
      Learn nudge now names the new article). Unread badge + dashboard card still ⬜. 16 articles ship
      today; adding one is ~30 min in `LearnContent.swift`.
- [ ] ⬜ **T29 — Write and wire the 12 articles** (~0.5d each). **T29b (Shettles) needs G1.**
- [x] ✅ **T30 — Per-supplement reminders.** Each supplement carries its own time, the Genesyx
      essentials included; "No reminder" stays a first-class choice in the menu.

## 7. Phase 6 — quote separately (40–60d)

- [ ] ⬜ HealthKit / Apple Watch / Oura (~15–20d) — zero code, no entitlement, no Info.plist keys
- [ ] ⬜ Home-screen widget (~8–12d) — no WidgetKit target in `project.yml`
- [ ] ⬜ Barcode / photo food logging (~15–20d) — no AVFoundation or VisionKit
- [ ] ⬜ Partner data-sharing scopes (~5–8d) — no permission model exists; today it is name-only

---

## 8. Notification logic

Not a from-scratch build. `NotificationService.swift` is a complete **local** scheduler (no APNs
server needed): triple-gated on feature flag + user pref + system authorization, permission asked
from a Profile pre-prompt sheet (never at launch), tap-routing deep links into the right
tab/article, and a "never guilt" invariant enforced by tests.

Already scheduled: daily hydration · Monday pH reminder · Wednesday insights · Friday track nudge ·
Sunday Learn article · instant streak milestones.

New work is extending `NotificationPlanner.plan()` — **~3–4 days total**:

| Notification | Effort | Task |
|---|---|---|
| Fertile-window entry alert | 1.5d | T14 |
| Weekly new-article alert | 0.5d | T28 |
| Per-supplement reminders | 1d | T30 |
| Per-category opt-in toggles | 1d | T15 |

---

## 9. Timeline

One experienced iOS dev. Excludes copywriting, medical review and design assets — those are the
critical path, not the code.

| Phase | Effort |
|---|---|
| 1 — Corrections | 8–10d |
| 2 — Real gaps | 15–18d |
| 3 — Design (design-gated) | 10–20d |
| 4 — Nutrition | 15–20d |
| 5 — Education | 6–8d |
| **Phases 1–5** | **55–75d ≈ 11–15 working weeks (3–4 months)** |
| 6 — Separate quote | 40–60d |

Phases 1–2 only — where the actual defects live — is **6–8 weeks**.

### 9.1 Sprint 1 — what actually fits in 14 days

Everything below is **gate-free**: no client decision, no medical review, no design asset. It can
start today and finish inside one sprint. Ordered so each day ships something demonstrable.

| # | Task | Effort | Status |
|---|---|---|---|
| 1 | T3 · T4 · T5 — Learn pH corrections | 0.5d | ✅ `71567c8` |
| 2 | T20 — light mode default | 0.25d | ✅ `560591e` |
| 3 | T6 — disclaimer → expandable (log sheet stays pinned) | 0.5d | ✅ `560591e` |
| 4 | T14 — fertile-window notification | 1.5d | ✅ `d35cfa0` |
| 5 | T15 — per-category notification toggles | 1d | ✅ |
| 6 | T28 (notification half) — weekly new-article alert | 0.5d | ✅ |
| 7 | T30 — per-supplement reminders | 1d | ✅ |
| 8 | T10 · T11 — `sexualActivity` model + persistence + migration | 2.5d | ✅ |
| 9 | T12 — private logging UI (excluded from partner surfaces) | 1.5d | ✅ |
| 10 | T13 — calendar dot markers (pH, symptoms, activity) | 2d | ⬜ |
| 11 | T8 — persist quiz answers (plumbing only; T7's copy needs G1) | 1.5d | ⬜ |
| | **Total** | **12.75d** | 1.25d QA buffer |

**7-day option — "start the scope."** Rows 1–7 only: the complete notification layer plus the quick
UX wins. ≈5.25d of work, ~1.75d buffer. This is the fastest path to something the client can hold in
their hand, and it closes the one item they raised that was genuinely missing.

### 9.2 What Sprint 1 deliberately excludes

- **T1 · T2** (pH tab) — G2. Shipping T1 alone makes pH *harder* to find.
- **T7 · T29b** (Girl/Boy, Shettles) — G1. Blocked on written sign-off, not on engineering.
- **T9** (offline symbol) — G3. Cannot reproduce; no such code path exists.
- **T21 · T22** (artwork, visual pass) — G4 / no design spec. T22 will sprawl without one.
- **T16–T19** (profile editors) — real work, but no defect; they are unbuilt features.
- **T23–T27** (nutrition) and **Phase 6** — separate scope.

**The honest constraint:** AI compresses *engineering* days, not *approval* days. Gate-free work
moves at AI speed. G1 in particular is calendar time — client sign-off plus medical review — and no
amount of tooling shortens it. That is why Sprint 1 is built entirely from work that needs neither.

---

## 10. Verification gate

Green baseline is **160 domain + 157 app tests** (was 125 + 139 before Sprint 1), plus **25 UI tests**
(1 skipped) behind the `-uiTestSeed` harness. Run after every task:

```bash
swift test && xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:GenesyxUITests
```

- **Do not use `-quiet`** — it returned exit 0 with no summary and hid the result.
- If the simulator reports `Application failed preflight checks` / `Busy`:
  `xcrun simctl shutdown all`, then re-boot and retry. That is a simulator flake, not a code failure.
