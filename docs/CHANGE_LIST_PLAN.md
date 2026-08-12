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
- [x] ✅ **G2 — pH tab placement.** Resolved 11 Aug 2026: **7 tabs**, Insights stays. The SE worry did
      not survive measurement — iOS 16 drops the 320pt SE 1, so the narrowest supported device is
      375pt, giving ~53pt a tab against a ~48pt widest label ("Nutrition"). Verified on an
      iPhone SE (3rd gen) simulator: no truncation, all seven tappable. Unblocked T1/T2.
- [x] ✅ **G3 — Offline symbol.** Resolved 11 Aug 2026, and the client was right. The earlier "no code
      path exists" finding searched for `NWPathMonitor`/`Reachability`; the symbol is not reachability
      at all. `DailyLogRepository.syncState(on:)` reads the owed-days set, and that set was not
      `@Published` — so the save drew `icloud.slash` "Will sync when online" and the push that cleared
      it a moment later published nothing. The icon then sat over a day the server already had until
      some unrelated edit happened to redraw the row. Fixed in Phase 2; no client screenshot needed.
      Unblocked T9.
- [x] ✅ **G4 — Egg artwork.** Resolved: the files were already in the catalog (dated 10 July), so
      the blocker was stale, not outstanding — nothing was ever waiting on the client. Wired in T21.

---

## 2. Phase 1 — corrections (8–10d)

T3–T5 are independent of every gate. Cleanest starting point — **all three shipped in `71567c8`**.

**T1 and T2 are one change, not two.** Removing pH from Nutrition without the dedicated tab leaves
pH reachable only from Track — strictly *less* discoverable, the opposite of the client's goal. So
T1 inherits G2's block. Do not ship T1 alone.

- [x] ✅ **T1 — Remove pH from Nutrition.** The card is gone from `NutritionView`; the tab now opens
      straight into focus foods. `guide-track-ph-in-nutrition` was rewritten around the trend chart —
      **slug kept**, because it is a route and a read-history key, and `LearnLibraryLog.newSlugs`
      (unlike `LearnReadLog.renamed`) has no rename map, so a rename would re-announce the article as
      new. Home's pH card and Insights' empty state now point at the tab, as does Profile's help copy.
- [x] ✅ **T2 — Dedicated pH tab.** Seventh tab at index 2 (Home, Track, **pH**, Nutrition, Insights,
      Learn, Profile). Inserting mid-order shifted every raw value above it, so three structures moved
      in lockstep: `MainTabView`'s ordering, `NotificationTab`, and `NotificationTarget`. They have no
      runtime linkage, so `NotificationTests` now asserts them **pairwise** — the old
      `NotificationTab(rawValue:) != nil` check still passed while a nudge landed one tab off.
      Known and accepted: a notification queued before the update carries the old raw `tab` in its
      `userInfo` and lands one tab off until the next replan. `PhSpineVariant` went with it — `.full`
      is now unconditional, `.compact` had no consumer left once Nutrition dropped the card.
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
- [x] ✅ **T8 — Persist quiz answers.** `OnboardingFlowView.swift:155` collected answers into a local
      dict and **discarded them on completion**. They now go to `profiles.quiz_answers` (`jsonb`,
      keyed by question id) via `PreferencesRepository.recordQuizAnswers`.

      The quiz runs *before* sign-up, so at the moment she answers there is no session to write
      under — the answers are written on-device and stay **owed** to the server until sign-in
      drains them, which is the same queue the other repositories already use for offline writes.
      Wiped on sign-out: onboarding does not re-run (that flag is device-local), so without the wipe
      the next user on the phone would inherit them.

      `jsonb` rather than a column per question because the questions are content and T7 rewrites
      one of them. **Question ids are now storage keys** — renaming one orphans every answer already
      given to it, on both clients. `QuizContentTests.testFiveQuestionsInOrder` pins them.

      **Nothing reads the answers yet**, by design: the consumer is T7's personalised copy, which
      needs G1. This is the plumbing only, as scoped.

      ⚠️ **Raised for G3/security:** `profiles` carries a partner-read policy, and her answer to the
      baby's-sex question now lives in that row — under a helper line that promises "This is just
      for you." If that policy selects whole rows rather than named columns, the promise is false.
      The check is written into `supabase/migrations/20260810_profiles_quiz_answers.sql` §2 and must
      be run before this reaches production.
- [x] ✅ **T9 — Connectivity.** G3 turned out to be a real defect rather than a question, so this is a
      fix and not a write-up. Shipped with the Phase 2 reliability batch: the stuck "Will sync when
      online" badge, a cycle correction lost when it was made mid-drain, and an owed profile write
      that followed one account into the next one's row.

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
- [x] ✅ **T13 — Calendar markers.** pH test, symptoms/notes and intimacy as dots under the day
      number, with the legend extended to name all three. The rule lives in `DayMarkers`
      (GenesyxCore) rather than the view, so it is unit-tested and shaped to mirror on Android.
      Deliberately *not* marked: water, mood, energy, sleep, supplements — a grid where most days
      carry most dots marks nothing. The day sheet now accounts for every dot, since a marked day
      described as "No log for this day" reads as the app having lost what she entered.

      **Fixed en route (pre-existing, not introduced here):** every calendar cell was squaring the
      day *number* rather than the cell, so cells collapsed to one line of text and two-digit days
      rendered as "…" — on 2026-08-10 that was 8 of 31 days unreadable. Verified against a
      screenshot of `main` before the marker work. The square now comes from `Color.clear`, the same
      shape the empty leading cells already used.
- [x] ✅ **T14 — Fertile-window notification.** Extends `NotificationPlanner.plan()`; `OvulationLogic`
      already computed the window. Discreet lock-screen wording by default (sensitive health data is
      visible to anyone holding the phone).
- [x] ✅ **T15 — Per-category notification toggles.** `ProfileView.swift:176`. One global switch would
      not hold 8 categories.
- [x] ✅ **T16 — Health Profile editor.** Opens the existing `CycleSettingsSheet`. Her cycle *is* the
      health profile the app holds, and until now it could only be reached from the Home setup card,
      which disappears once it has been filled in — so a wrong period date was uncorrectable.
- [x] ✅ **T17 — Tracking Preferences editor.** Re-opens the five onboarding answers through the
      existing `recordQuizAnswers` sync path. They shape her plan and guidance but were asked once and
      then frozen: someone who answered "just starting to think about it" a year ago had no way to say
      she is trying now, and kept being guided as if she weren't. All five are editable, including the
      baby's-sex question — an answer she cannot change is worse than one she was never asked.
      The Hydration and Notification controls stay where they are: they are already live on this
      screen, and duplicating them into a sheet would give the same setting two homes.
- [x] ✅ **T18 — Personal details editor.** Display name is editable; the sign-in address is shown but
      not. **No DOB field, deliberately** — the doc says "email, DOB", but nothing in the app consumes
      age, and a date of birth is PII in a row this release has just spent a batch of work moving PII
      out of. Raise it with the client if a real consumer for it appears.
      Email is display-only because changing it is a re-verification flow, not a text field; leaving
      it off the screen entirely meant "which account am I in?" had no answer anywhere in the app.
- [ ] ⬜ **T19 — Password change.** `SessionRepository.swift:99` throws in local mode and surfaces an
      error. Either gate the row or wire the backend.

## 4. Phase 3 — design (10–20d, design-gated)

- [x] ✅ **T20 — Light mode default.** One line at `PreferencesRepository.swift:66`
      (`.system` → `.light`). Toggle already existed in Profile.
- [x] ✅ **T21 — Restore egg artwork.** `BrandEgg` (`GenesyxControls.swift`) draws the crescent at
      two tints; the four splash `BrandOrb` stand-ins are now eggs at the same tuned positions.
      Re-exported 1024px → 512px first (**1.4MB → 222KB**; 512 is 1:1 for the largest 170pt use at
      3x). Guarded by `BrandAssetTests`. The summary-screen `BrandOrb(size: 80)` at
      `OnboardingFlowView.swift:261` is a centred emblem, not background texture — left as an orb
      pending a design call.
- [ ] ⬜ **T22 — Warm/premium visual pass.** Open-ended — require a design spec or this will sprawl.

## 5. Phase 4 — nutrition (15–20d)

- [x] ✅ **T23 — Custom glass size.** A glass is now hers to size (50–1000 ml, default 250); a cup
      stays fixed at 240 ml because it is a recipe measure, not an object she owns, and millilitres
      are the storage unit itself. Out-of-range values fall back to 250 rather than clamping, so a
      corrupted store shows the familiar default instead of a number she never picked —
      `HydrationUnit.resolvedGlassMl` is the single place that decision is made.

      `mlPerUnit` became a method taking `glassMl` specifically so the compiler had to be satisfied
      at every existing call site; a defaulted property would have let a surface keep reading 250
      silently. Storage is untouched (`DailyLog.waterMl` is always ml), so resizing the glass
      re-describes her logged water and can never rewrite it.

      **Device-local, deliberately.** `hydration_unit` already was — read straight from
      `UserDefaults` at four call sites — so syncing the glass size alone would strand her on a new
      phone with a 300 ml glass honoured but the unit reset to millilitres, where glass size means
      nothing. New `HydrationPrefs` reads both keys in one place. *Owed: move **both** hydration
      display prefs to `profiles`, as one change with Android — see `HANDOFF.md`.*

      **Android parity note:** 250/240 were documented as shared constants. A custom size on iOS
      alone means the two clients describe identical water as different glass counts. Display-only —
      no data divergence, unlike the `isMeaningfulLog` case — but it is a visible difference.
- [ ] ⬜ **T24 — Nutrition text pass.** Smaller than the client thinks; disclosures already exist.
- [x] ✅ **T25 — Phase-change card** linking to the `eating-with-your-cycle` article. Announced once
      per transition, never on a first install — she is mid-phase then, not crossing into one, and
      the card would be reporting something that happened days before she opened the app. Carries no
      nutrition claim of its own (every line is a phase label or a statement about the screen), so it
      needs no medical sign-off; the reviewed guidance stays in the focus-foods card below it.
- [ ] ⬜ **T26 — Meal logging** model + UI. Replaces the "Coming soon" placeholder at
      `NutritionView.swift:304`. **Most expensive item on the list — scope separately.**
- [ ] ⬜ **T27 — Recipe cards** with imagery. Needs content + design, not just code.

## 6. Phase 5 — education (6–8d + medical review)

- [x] ✅ **T28 — Weekly article drop + unread badge/dashboard card.** The Sunday nudge, the Learn tab
      badge and the Home card all pick through one rule (`NotificationPlanner.nextRead`), so they can
      never name different articles. The badge counts *new-and-unread* only — zero on a first install,
      because badging all 19 would read as a backlog. 19 undated articles ship today; adding one is
      ~30 min in `LearnContent.swift`.
- [x] ✅ **T29a — The eleven weekly pieces, written and cited.** Shipped in one build, revealed one
      Sunday at a time. Every piece states external health facts, so every piece carries a disclaimer
      and a Sources footer *in the build that ships it* — they are withheld by date, not by
      readiness, and there is no later pass. `testEveryWeeklyArticleIsCited` pins that.
- [x] ✅ **T29c — The three missing how-to guides** (cycle & phases, sleep, symptoms). A separate ask
      from the twelve-week series: seven in-app how-tos covering cycle, pH, nutrition, symptoms,
      sleep and hydration. Four already existed — pH three times over — so only the genuine gaps were
      written. See `CHANGELOG.md` for the two factual errors that checking against the code caught.
- [ ] ⬜ **T29b — Shettles.** Needs G1 (written client + medical-reviewer sign-off). Not engineering
      time. `testShettlesArticleIsAbsent` fails the day it lands, which is the intended reminder that
      the banned-phrase guards have to be revisited first.
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
| 10 | T13 — calendar dot markers (pH, symptoms, activity) | 2d | ✅ |
| 11 | T8 — persist quiz answers (plumbing only; T7's copy needs G1) | 1.5d | ✅ |
| | **Total** | **12.75d** | 1.25d QA buffer |

**Sprint 1 is complete** — all eleven rows shipped, `71567c8` … `148e754`. Two things it leaves
behind for whoever picks up next:

1. **Migrations need running by hand** in the Supabase SQL Editor; this repo never pushes schema.
   Until then a column exists only in the app's decoders, which tolerate its absence — so nothing
   breaks, and nothing syncs either. *Superseded 2026-08-11: `profiles_quiz_answers` was replaced by
   the owner-only table in `9d08d82` and has been applied; `daily_logs_sexual_activity` is still
   unconfirmed. **See `HANDOFF.md` §2 for current Supabase state** — that is the live record.*
2. **An Android coordination item.** `sexualActivity` is deliberately *not* counted by
   `TrackingEngine.isMeaningfulLog` or `StreakEngine.hasAnyEntry`. Those two predicates are mirrored
   in the Android client and driven by a byte-for-byte shared `tracking_test_vectors.json`, so
   widening one alone gives the two platforms different streaks for identical data with nothing to
   report the divergence. Flipping it is one change across both clients and the vectors, or none.
   Until then a sex-only day does not extend her streak.

**7-day option — "start the scope."** Rows 1–7 only: the complete notification layer plus the quick
UX wins. ≈5.25d of work, ~1.75d buffer. This is the fastest path to something the client can hold in
their hand, and it closes the one item they raised that was genuinely missing.

### 9.2 What Sprint 1 deliberately excludes

- **T1 · T2** (pH tab) — G2. Shipping T1 alone makes pH *harder* to find.
- **T7 · T29b** (Girl/Boy, Shettles) — G1. Blocked on written sign-off, not on engineering.
- **T9** (offline symbol) — G3. *Superseded 11 Aug 2026: reproduced and fixed. The original "no such
  code path" reading looked for reachability monitoring; the badge is driven by the owed-days set.*
- **T21 · T22** (artwork, visual pass) — G4 / no design spec. T22 will sprawl without one.
- **T16–T19** (profile editors) — real work, but no defect; they are unbuilt features.
- **T23–T27** (nutrition) and **Phase 6** — separate scope.

**The honest constraint:** AI compresses *engineering* days, not *approval* days. Gate-free work
moves at AI speed. G1 in particular is calendar time — client sign-off plus medical review — and no
amount of tooling shortens it. That is why Sprint 1 is built entirely from work that needs neither.

### 9.3 After Sprint 1 — finishing the partials

Sprint 1 left exactly one row half-built. This batch closes it and takes the two smallest gate-free
nutrition items while the context is warm.

| # | Task | Effort | Status |
|---|---|---|---|
| 12 | T28 (remaining half) — Learn unread badge + Home dashboard card | 1d | ✅ |
| 13 | T25 — phase-change card linking to the cycle-eating article | 1d | ✅ |
| 14 | T23 — custom glass size | 1d | ✅ |

### 9.4 Sprint 2 — 11 Aug 2026

| # | Task | Effort | Status |
|---|---|---|---|
| 15 | Past-day logging + editing (§1B on the client list) | 1d | ✅ |
| 16 | T16 · T17 · T18 — the three inert Profile rows | 1d | ✅ |
| 17 | `page_background` — the brand backdrop on the seven tab screens | 0.5d | ✅ |
| 18 | T1 · T2 — dedicated pH tab, pH out of Nutrition (G2 resolved) | 1.5d | ✅ |
| 19 | Phase 2 reliability — G3 badge, mid-drain correction, identity bleed | 1.5d | ✅ |
| 20 | The calendar with no cycle set up | 0.5d | ✅ |

T19 (password change) is the one Profile row still unbuilt: `SessionRepository.swift:99` throws in
local mode. It is a backend decision, not a UI one, so it did not belong in the same batch.

**Row 20 — the calendar existed only after the cycle did.** Cycle setup is skippable, and skipping
it took the whole month grid away: no cells, so nothing to tap, so no way to record or review any
day at all — including the past days row 15 had just made loggable. `CalendarCell.day` and
`buildMonthGrid` now carry an *optional* `CyclePhaseInfo`, so a day exists without a phase; the grid
draws untinted, the phase key is hidden rather than pointing at four colours that appear nowhere,
and the day sheet heads itself with the date and declines to predict. The "Add your cycle" prompt
moved below the grid rather than replacing it.

⚠️ **Android coordination item.** `CalendarCell` mirrors a Kotlin sealed interface. The same
nullability has to reach the Android client, or the two calendars will disagree about whether a day
can exist without a cycle. Nothing shared enforces this — there is no `tracking_test_vectors.json`
equivalent for the grid — so it travels by this note alone.

---

## 10. Verification gate

Green baseline is **180 domain + 198 app tests** (was 125 + 139 before Sprint 1; T23 added 5 domain;
the app figure was 169 until the uncommitted `RepositoryTests` work took it to 172, the weekly
Learn series added 11 — 6 drip-gate, 3 citation-integrity, 1 hero-asset, 1 end-to-end drop — T21
added 2 brand-asset guards, the build-18 `drainPending` fix added 1, past-day logging added 2
`RepositoryTests`, and `page_background` added 2 more brand-asset guards; Sprint 2 then added 8 app
tests for the Phase 2 reliability batch and 1 domain test for the no-cycle grid),
plus **45 UI tests** behind the `-uiTestSeed` harness — the notification opt-in test skips itself once
that permission has been answered, so it counts 44 + 1 skipped on a simulator you have already run
against, and 45 on a freshly erased one. Run after every task:

```bash
swift test && xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:GenesyxUITests
```

- **Do not use `-quiet`** — it returned exit 0 with no summary and hid the result.
- If the simulator reports `Application failed preflight checks` / `Busy`:
  `xcrun simctl shutdown all`, then re-boot and retry. That is a simulator flake, not a code failure.
  If it survives that (it has, twice in a row), go heavier —
  `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, `xcrun simctl erase <device-id>`, then
  `xcrun simctl bootstatus <device-id> -b` to wait for ready before handing the device to `xcodebuild`.
- **Never run two `xcodebuild test` processes at once.** They contend for the one simulator and the
  loser dies with `Test crashed with signal kill` — which reads exactly like a real crash, and cost a
  full afternoon of chasing a UI bug that did not exist. `ps aux | grep "xcodebuild test"` before you
  start; a run abandoned by a killed shell keeps its child alive.
