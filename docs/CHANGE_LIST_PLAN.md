# Genesyx iOS — Client Change List: Audit & Execution Plan

> Response to the client's "Simplified Consolidated Changes" list (received 2026-08-10).
> Historical execution journal for builds 17–18, refreshed against **HEAD `d0b0c9f` on
> 13 Aug 2026** plus the current working tree. The latest clean full-suite baseline through
> H0 · H5 · T7 · H3-interim · H4 · H4-log-sheet · H7-celebration · sleep-contract is
> **239 domain, 238 app and 57 UI tests** — 0 failures and 1 pre-existing permission-dependent skip.
> Legend: ✅ complete · 🟡 partial/in progress · ⬜ missing · ⚠️ decision or external gate

---

## 0. Read this first

**Current item-by-item result for Sections 1–3: 35 of 44 client sub-items Done (80%), 2 In progress,
3 In review, 3 Blocked and 1 To do. Section 4 remains excluded.** This replaces the earlier rough
count with the row-level assessment in `PROGRESS_CHECKLIST.md`. The original 25/44 count pre-dated
the pH relaunch/history fix, optional onboarding, honest cycle-card copy and live Supabase
corrections. Section **6A** remains the source of truth for the hard work and external gates.

| Client item | Current verified reality |
|---|---|
| 1A vaginal pH | 🟡 The dedicated tab, correct wording, logging, chart, Insights, full dated history, edit/delete, guidance and expandable disclaimer now work. A real second-process cold-relaunch test proves vaginal type persists. No migration or pH reclassification is permitted. The remaining client-list item is the approved Genesyx website links for science and Shettles (H12). |
| 1B dated logs/calendar | 🟡 Hydration, sleep, symptoms, mood, energy, notes, supplements, food groups, pH and intimacy all survive relaunch on their correct dates, and calendar markers work. Food groups gained their dated Track/My Logs/Insights wiring on 13 Aug (H4). Live Profile journeys remain H8. |
| 1C preference question | ✅ Girl / Boy / No preference / Prefer not to say are implemented safely, and it is now the one question she may skip outright — skipping stores no key at all, locally or on the server. |
| 1D connectivity | 🟡 Reachability wording, local-first queues and the pH offline/cold-relaunch path are implemented and automated. Only real cellular, dead-zone, reconnect and lock-screen privacy testing remains on a physical iPhone (H10). |
| 2A presentation | 🟡 Light mode, egg artwork, shorter cards and dark/light contrast work are implemented. The subjective warm/premium review and approved recipe photography remain H11. |
| 2B Nutrition | 🟡 Food-group logging, recipes and supplement reminders work, and food groups now feed Track, My Logs, a “Days with meals” Insights tile and the shared streak contract on both clients. Only the Android editor UI is outstanding — iOS remains the one place meals can be logged. |
| 2C Hydration | ✅ Glasses/ml, custom glass size, correction, target progress, persistence and Insights work. Display unit/glass preferences are still device-local. |
| 2D contextual cycle guidance | ✅ Phase-change card, article route and personalised Home greeting are implemented. |
| Cycle Insights | 🟡 Predictions work, but only one `cycle_settings` row exists. The card no longer claims regularity — it is titled “Current cycle length” — but real regularity still needs the H3 period-event model. |
| 3A streak | 🟡 Visible and data-linked, and meal-only days now hold a streak identically on both clients (H4). Milestones now celebrate in-app on both clients and follow the logging streak on both (H7). The last divergence inside the predicate is closed too: a 0h sleep counted toward her milestones but not toward her Consistency streak, because `TrackingEngine` read `> 0` where `StreakEngine`, both Android predicates and the vectors changelog read `!= nil` — iOS is now in line with the three, and Android needed no change. The day-detail summary followed the predicate, so a day whose only entry is a 0h night no longer reads “No log for this day” under a streak that has just counted it. Cycle edits and article reads still do not count (H6), and streak restore remains an open product decision (H7). |
| 3B education | ✅ All 12 topics, dashboard/new-article delivery and opt-in-gated notifications exist. Production `profiles.push_enabled` now defaults to `false`; all 18 existing rows were deliberately left unchanged. |

### Medical and compliance guardrails

The codebase forbids unsupported sex-selection, diet/pH causation, diagnosis and treatment claims.
Those guards remain correct and must not be weakened to make a feature easier to ship.

The four preference answers now record preference without claiming an outcome. The Shettles article
is a clearly framed, cited debunking piece, and the vaginal-health guidance explains when to seek
professional help without diagnosing the user. These are no longer implementation blockers.

Remaining rule: do not reinterpret legacy urine rows as vaginal, infer a diagnosis from pH,
manufacture meal/nutrient effects, or put intimacy/medical detail into notifications or partner
surfaces. Any future clinical thresholds or recommendations still require written approval.

---

## 1. Gate 0 — decisions before any code

- [x] ✅ **G1 — Shettles and preference framing.** Resolved 12 Aug 2026. The gate assumed the
      guards would have to be relaxed; they did not, and were not. `bannedPhrases` bans *claims* —
      "choose the sex", "gender sway", "alkaline diet" — and its own docstring says the list is drawn
      deliberately narrow so that debunking prose does not trip it. An honest piece stating the theory
      is unsupported clears every guard untouched, and is also the only version publishable in the UK
      (CAP Code 3.7 wants substantiation for the efficacy claim, and there is none to give).
      Shipped as `shettles-method`, week 12, revealed 2026-11-08, cited to Wilcox 1995.
      Girl / Boy / No preference / Prefer not to say also shipped without an efficacy claim. The
      only open part of T7 was making that question optional, which shipped 13 Aug 2026. **G1 is
      fully closed**, and closed without the sign-off it was assumed to need.
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
- [x] ✅ **T7 — Four preference options, and the question is now genuinely optional.** *Closed
      13 Aug 2026.* `QuizContent.swift` contains Girl / Boy / No preference / Prefer not to say, with
      stable storage ids and no promise that sex can be influenced. `QuizQuestion.isOptional` is now
      true for `gender` **and nothing else**; `OnboardingFlowView` offers "Skip this question", which
      *removes* the key rather than storing a stand-in id. No schema or wire change: the push
      replaces `quiz_answers.answers` wholesale, so a key dropped locally is dropped remotely.
      `TrackingPreferencesSheet` clears an optional answer on a second tap, so the first tap there is
      not a one-way door back into a compulsory question. **Android must match the scope** —
      `testOnlyTheSexPreferenceQuestionIsOptional` pins it. See `HANDOFF.md` §4l.
- [x] ✅ **T8 — Persist quiz answers.** `OnboardingFlowView.swift:155` collected answers into a local
      dict and **discarded them on completion**. They now go to the owner-only `quiz_answers` table
      (`answers jsonb`, keyed by question id) via `PreferencesRepository.recordQuizAnswers`.

      The quiz runs *before* sign-up, so at the moment she answers there is no session to write
      under — the answers are written on-device and stay **owed** to the server until sign-in
      drains them, which is the same queue the other repositories already use for offline writes.
      Wiped on sign-out: onboarding does not re-run (that flag is device-local), so without the wipe
      the next user on the phone would inherit them.

      `jsonb` rather than a column per question because the questions are content and T7 rewrites
      one of them. **Question ids are now storage keys** — renaming one orphans every answer already
      given to it, on both clients. `QuizContentTests.testFiveQuestionsInOrder` pins them.

      Tracking Preferences reads and updates the stored answers. The original
      `profiles.quiz_answers` design was rejected because profiles is partner-readable; the deployed
      owner-only table keeps the “This is just for you” promise. The deprecated empty profiles
      column is a separate cleanup item and must not be dropped until every shipped client has
      stopped selecting it.
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
- [ ] 🟡 **T19 — Password reset is wired; live account journey remains.** Profile now sends the
      signed-in address a Supabase password-reset email and reports success/failure. Complete it only
      after verifying delivery, universal/deep-link return, the reset form and a successful login with
      the new password on a disposable account. Local/guest mode must keep the action unavailable or
      explain why it cannot run.

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
- [x] ✅ **T24 — Nutrition text pass.** The disclosures were already there, so the copy ask really was
      as small as this line predicted. What the read turned up instead was a screen that was mostly
      *absent*: `supplementPlanCard` and `articlesSection` were both wrapped in `if let phase` while
      reading no phase data at all. Cycle setup is skippable, so skipping it removed the supplement
      plan — and with it every per-supplement reminder from T30, which has no other entry point in
      the app — plus the whole nutrition articles section. Same shape as the no-cycle calendar
      (Sprint 2 row 20), and the hydration card two cards below already had the right instinct:
      `contextLine(phase: nil)` degrades to "Log your cycle to get phase-aware hydration guidance"
      rather than vanishing. Only the phase-change card and focus foods stay gated; they genuinely
      need a phase.

      **The "Coming soon" card was ranked second**, above the supplement plan and hydration — and
      first with no cycle set up, so a skipped setup opened Nutrition on a placeholder. Moved below
      both, above articles: still discoverable, no longer the headline.

      **One line of genuine duplication cut.** `insightLine` appends "`N`-day streak going" at a
      streak ≥3 (`HydrationInsightLogic.swift:47`), which the card already showed in the pill at
      top-right — the same number twice, beside a third consistency line in `weeklyStreakLabel`. The
      insight sentence renders in Track's hydration detail (`TrackView.swift:1048`), which is exactly
      where this card's "Track ›" button and tap gesture already go, so it is one tap away rather
      than gone. `weeklyStreakLabel` **stayed**: Nutrition is its only render site, so cutting it
      would have deleted a shipped line rather than thinned a repeated one.
- [x] ✅ **T25 — Phase-change card** linking to the `eating-with-your-cycle` article. Announced once
      per transition, never on a first install — she is mid-phase then, not crossing into one, and
      the card would be reporting something that happened days before she opened the app. Carries no
      nutrition claim of its own (every line is a phase label or a statement about the screen), so it
      needs no medical sign-off; the reviewed guidance stays in the focus-foods card below it.
- [x] ✅ **T26 — Meal logging**, in food-group terms. Replaces the "Coming soon" placeholder that
      stood where `foodLogCard` now is (`NutritionView.swift:433`). The screen has always told her
      what to eat this phase and never let her say she had; six Eatwell-Guide chips close that loop.

      **Groups, not nutrients.** The client asked for "food-group *or* nutrient tracking". Nutrients
      need a food database — the deferred barcode work — and every nutrient count is a claim needing
      substantiation. Naming a category and listing what is in it is a definition, so this card
      carries no citation, no disclaimer and no medical sign-off, unlike the focus-foods card
      directly above it which has all three. `testFoodLogCopyMakesNoHealthClaim` is what keeps it
      that way: the realistic failure is not a banned phrase but one warm sentence added later
      ("protein supports egg quality") sliding the card into CAP Code 3.7 with every other guard
      still green. Proven by mutation — that exact sentence sails past the banned-phrase guard.

      **Synced, not device-local** (`food_groups text[]`, migration `20260812_daily_logs_food_groups.sql`,
      **applied to the live project 13 Aug 2026**). Stored as raw tokens like `symptoms`,
      so a group a future Android build knows and this one does not survives the round trip instead
      of failing the whole row's decode and taking the day's mood, sleep and water with it.

      **⚠️ Excluded from `isMeaningfulLog`/`hasAnyEntry`**, so a day she logs *only* meals does not
      extend her streak. That is the cross-platform contract, not an oversight: widening it here
      alone would give iOS and Android different streaks for identical data with nothing to report
      the divergence. Costs a real thing and is paid until Android carries `food_groups` and
      `tracking_test_vectors.json` moves with it. `NotificationService` folds food groups in
      separately (iOS-only, mirrors nothing), so she is never nudged to log on a day she logged.

      **Found en route:** `LogView.save` rebuilt a whole `DailyLog` from its own `@State`, resetting
      every field the sheet does not show. Harmless until a second surface wrote the same day —
      then saving a note would have silently erased what she ticked off in Nutrition. Now a
      read-modify-write, which holds for every future field and not just this one.
- [x] ✅ **T27 — Recipe cards.** Eight recipes, two per phase, in a horizontal row directly beneath
      the focus foods (`RecipeContent.swift`, `NutritionView.recipesSection`). Tapping one opens the
      ingredients, a numbered method, and a button that logs the food groups it covers — so the
      answer to "what do I do with iron-rich foods?" is a meal, and cooking it feeds the log card
      further down the same screen without re-typing anything.

      **Why these need no medical sign-off** while the card above them has a citation, a disclaimer
      and a reviewer. A recipe adds no claim of its own: it names a focus food the reviewed content
      *already* recommends for that phase and then says how to cook it. `usesFocusFood` is not a
      label, it is a foreign key — `testEveryRecipeNamesAFocusFoodThatExistsInItsOwnPhase` fails if
      it does not match a `PhaseFood.name` in the same phase, byte for byte. Proven by mutation:
      pointing the ovulatory salad at the period focus food "Iron-rich foods" fails the test naming
      the reviewed list it was checked against. The moment a recipe starts explaining *why* it
      helps, it has stopped repeating a reviewed claim and started making a new one, which is what
      `testRecipeCopyMakesNoHealthClaim` catches.

      **No photography, no placeholders.** The asset catalogue has Learn heroes and brand art and
      nothing edible. Rather than ship stock images of somebody else's food — Apple Guideline 2.1
      territory — each card carries a gradient in the phase accent, and `Recipe.imageName` is a nil
      seam for real photography later. `testNoRecipeClaimsAnImageTheAppDoesNotHave` is deleted in
      the same commit as the assets.

      **Logging is additive, not a toggle** (`DailyLogRepository.logFoodGroups`). The obvious
      implementation — call `toggleFoodGroup` once per group — would silently *un*-tick every group
      she had already logged by hand, under a button labelled "log". One upsert per tap, not one per
      group, and a no-op guard so reopening a recipe does not re-queue a day the server already has.

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
- [x] ✅ **T29b — Shettles.** Shipped 12 Aug 2026 as week 12 of the series, revealed 2026-11-08,
      cited to Wilcox 1995 (NEJM), disclaimer on. No guard was relaxed — see G1 for why none needed
      to be. `testShettlesArticleIsAbsent` is replaced by four framing guards, each proven under
      mutation: the negations must stay, no efficacy claim may appear (and none of the ones tested
      for is a banned phrase, so the existing scan passes on all of them), the citation must hold,
      and no cited source *title* may carry a banned phrase — `SourcesFooter` renders titles verbatim
      and the article scan never sees them.
- [x] ✅ **T30 — Per-supplement reminders.** Each supplement carries its own time, the Genesyx
      essentials included; "No reminder" stays a first-class choice in the menu.

## 6A. Current hard remaining work — 13 Aug 2026

This section supersedes old effort estimates wherever they conflict. It covers Sections 1–3 and 5
only; every Section 4 item remains deferred. Genesyx has one live Supabase project shared by iOS and
Android, so shared schema, privacy, deletion and streak rules must move as one contract.

### 6A.1 Priority and ownership

| ID | Priority | Work | Why it is hard / safe boundary | Owner and definition of done |
|---|---:|---|---|---|
| H0 | ~~P0~~ | ~~**Vaginal-pH cold-relaunch fix**~~ | `PhRecord.dto` omitted `measurementType`, while the test exercised the unused `PhReading.dto`. Builds 12–13 may contain genuine urine readings, so “missing type means vaginal” is unsafe. | ✅ **Done 13 Aug, iOS only.** Real type now persists through the production path; the dead `PhReading.dto` decoy is deleted; missing legacy type still decodes as urine. Reverting the fix reproduces the empty history, so the new relaunch test is proven to bite. No SQL, no conversion. `HANDOFF.md` §4k. |
| H1 | ~~P0 backend~~ | ~~**Complete account-deletion backstop for `user_supplements`**~~ | The live table already had owner-only RLS and `auth.users ON DELETE CASCADE`, but the hardened RPC lacked an explicit defence-in-depth delete. | ✅ **Production done 13 Aug.** Project `epltxklawpcxxbaleswg` now has the line exactly once before profile/auth deletion; partner unlink, owned-data deletes, email-keyed invite/waitlist cleanup, owner, ACL, `SECURITY DEFINER` and `search_path=''` were preserved. Row counts identical before and after: profiles = 18, user_supplements = 1, genesyx_products = 0, ph_readings = 61. `delete_current_user()` was **redefined, not executed** — no account was deleted to obtain this evidence. **Still owed, and it is remaining behavioural QA rather than missing implementation:** check the exact applied migration into **this repo** — it is the shared-backend repo, and the executable copy belongs here alone; Android keeps only an audit pointer under its `docs/migrations/` — and run a disposable-account deletion test. Production DDL is not proof of runtime behaviour. |
| H2 | ~~P1 backend~~ | ~~**Make push consent semantically opt-in**~~ | iOS already requires preference + system authorization; the server default had contradicted that model. | ✅ **Production done 13 Aug.** `profiles.push_enabled` now defaults to `false`. No existing profile row was rewritten: distribution stayed 18 true / 0 false. Android reminder behaviour still deserves parity QA, but the shared default is fixed. |
| H3 | P1 product + backend | **Real cycle history and honest regularity** | Both apps have one current `cycle_settings` row. A configured 28-day length cannot prove regularity. This needs a dated-event model, offline conflict rules and migration on both clients. | **Product + iOS + Android + Supabase.** Approve what counts as a period start/end/correction. Then design an owner-only `cycle_periods`/equivalent table with client ids, timestamps and tombstones; implement local-first sync on both platforms; derive regularity only from sufficient completed cycles. 🟡 **Interim implemented 13 Aug, iOS only:** the card is renamed “Current cycle length”, guarded by `testInsightsReportsCycleLengthWithoutClaimingRegularity`, which asserts no static text on Insights contains “regularity” — proven to bite by reverting the title. Full suite green at 236/238/52. The `CycleRegularityLogic`/`CycleRegularityInsights` types keep the old name so the Android mirror still matches; rename them together when period events land. The modelling work below is untouched and still owed. |
| H4 | ~~P1 cross-platform~~ | ~~**Connect meals to Track, My Logs, Insights and streaks**~~ | `daily_logs.food_groups` was live, but iOS Insights counted supplements only and both shared streak engines deliberately excluded food groups. An iOS-only change would have produced different streaks from identical backend data. | 🟡 **iOS done 13 Aug; Android at read parity. No SQL was needed or written.** Both iOS engines now count meals (`TrackingEngine.isMeaningfulLog`, `StreakEngine.hasAnyEntry`), so a meal-only day holds a streak. Track's dated summary lists “N food groups”; the My Logs day card lists them by known case, so a group written by a newer build renders as nothing rather than a raw token; Nutrition Insights gained a separate **“Days with meals N / 7”** tile. Android received the whole read/write half — Room v9 (`MIGRATION_8_9`, nullable `foodGroups TEXT`, generated `9.json` verified against the ALTER), DTO field omitted-while-empty, Supabase read/write, and the same widened `isMeaningful()` — so both clients compute identical streaks from the same rows. Two real defects were fixed on the way: Android's log form rebuilt the whole row and would have **deleted iOS-written meals on every save** (now carried through, plus `upsertPreservingWater` preserves them against a mid-edit sync), and meal-only days no longer render as empty in Android history. **The two `tracking_test_vectors.json` files never mirrored each other byte-for-byte and never had** — the false claim is now corrected in both repos, each file extended in its own schema, and the Android additions falsification-tested (removing the predicate term makes them fail). A v8→v9 Room migration test was also added, since every prior `daily_logs` migration had one and this did not; it runs on a real emulator and fails if the ALTER grows a `DEFAULT`. All three new iOS surfaces are covered end to end by `testAMealLoggedTodayReachesTrackMyLogsAndInsights`, which cooks a recipe and then goes looking for the meal on Track, My Logs and Insights; each of the three assertions was falsification-tested by breaking that surface alone and watching only it fail. It writes to *today* deliberately, because the Insights tile counts within the current ISO week and seeding a past day would make a Monday run legitimately read zero. Green at 236 domain / 238 app / 53 UI / 380 Android unit / 3 Android instrumented, 0 failures *at that point in the day*. **What H4 left owed:** a food-group control in the daily log sheet on **both** clients — on iOS the Track day sheet reported “N food groups” while “Edit this day” could not change them, and on Android there was no way to record a meal at all — plus offline/relaunch/sync QA on both devices. The QA and the Android control are still owed; the iOS control is not, see below. **The “Days with meals” metric is my reading of the plan's open “agree the insight metric” item — redirect it if the product owner wants something else.** **Closed on iOS later the same day:** `LogView` gained a `foodGroupsSection` of the same six `FoodGroup` cases Nutrition offers, so “Edit this day” can now change the meals the day sheet reports and a meal can be entered from the tracker rather than Nutrition only. It is a *toggle*, unlike the recipe card's deliberately additive `logFoodGroups` — this is the day's editor, and an editor that cannot un-tick is not one. That made `save()` start writing `foodGroups` rather than carrying them through, which is precisely the shape of the bug already found and fixed on Android, so it is guarded by its own test: `testSavingTheLogSheetKeepsAMealLoggedFromNutrition` logs a recipe, saves an unrelated field from the sheet, and asserts *both* that the save landed and that the meal survived it. Deleting the `populate()` read makes it fail with `Logged: 0.8 L water, pH test, intimacy.` — the meal gone, exactly as predicted. `testTheLogSheetCanRecordAndClearAMeal` covers the round trip including un-ticking. Green after that change at 236 domain / 238 app / 55 UI, 0 failures. Android still has no such control and remains read-only for meals. |
| H5 | ~~P1 iOS~~ | ~~**Complete pH history editing**~~ | The premise was generous: a `.sheet(isPresented:)`/`editing` race meant **no** reading was editable — every tap opened a blank new-reading sheet and saving filed a duplicate. | ✅ **Done 13 Aug.** One `PhSheetMode?` presented with `.sheet(item:)`, plus a collapsible dated "Reading history (N)" opening any reading for edit or delete. Legacy urine stays hidden. **Android parity review still owed.** `HANDOFF.md` §4k. |
| H6 | P2 product + cross-platform | **Decide how article reads and cycle actions count toward streaks** | Article read state currently stores only device-local slugs, not dates. A read cannot honestly count for a specific day or sync across phones. Cycle-setting changes are likewise not event history. | **Product decision first.** Either narrow the requirement to existing meaningful logs, or define dated owner-only events and the shared engine rule. If cross-device consistency is required, draft an `article_reads`/activity-event migration; do not fake dates from the current slug set. |
| H7 | 🟡 P2 product | **In-app milestone celebration and optional restore** | Milestones scheduled local notifications and nothing else. Restore affects the canonical meaning of the streak and could become a paid/gamified entitlement. | 🟡 **Celebration done 13 Aug on both clients; restore still an open product decision. No schema, no migration, no SQL.** The premise understated it: the milestone check ran inside `replan()`, behind `guard isActive`, so the woman who *declined* notifications logged for a week and the app said nothing at all — the missing in-app moment was not a polish gap, it was the whole feature for the majority case. `checkMilestones()` now runs outside that gate, from `reconcile()` (launch and every foreground) and from the `dailyLog.$logByDate` observer; only the banner half still needs permission. Ordering is load-bearing and documented: `replan()` opens with `cancelAll()`, which would sweep away a milestone scheduled ahead of it, so `replanAndCelebrate()` fixes the sequence. **The trigger was repointed, on both clients in the same sitting:** the 7- and 14-day milestones followed *hydration* while Home headlines the *logging* streak, so a woman who logged a meal and her symptoms every day for a fortnight watched that number climb and was congratulated for nothing. Both engines now key off the activity streak — the number she is actually shown — matching the client's 3A wording. `MilestoneCelebrationView` reuses `NotificationContent.milestoneTitle`/`milestoneBody` rather than writing fresh copy, so the banner and the app cannot congratulate her for different things and the words stay inside the reach of the banned-phrase and no-guilt scans. Only the largest crossed milestone is shown — day7 and week1 together is one good week, not two stacked modals — and `celebration` is only ever assigned non-`nil`, because writing `nil` on the next call would tear the moment off screen the instant she logged anything else. Two UI tests cover it: `testMilestoneIsCelebratedInTheAppWithoutNotificationPermission` (running with no permission granted *is* the test) and `testACelebratedMilestoneDoesNotReturnOnTheNextLaunch`, a cold relaunch against the same store. Three falsifications, each rebuilt and re-run: restoring the `isActive` guard, flipping `.last` to `.first`, and deleting `prefs.celebrate(...)` each fail exactly one assertion. **Two real defects were found on the way.** A VoiceOver one: an `accessibilityIdentifier` on the card container does not name the card — SwiftUI lets the outermost one win, so it renamed the only control inside and the whole celebration collapsed into a single button called “Thanks”, with the words she had earned unreadable; the container is now deliberately unidentified. And a test-harness one: with the celebration no longer gated, the base UI seed crosses `week1` on most weekdays, so a full-screen modal would have opened over the tab bar in every unrelated test and eaten its taps — and with `continueAfterFailure = false` that aborts the whole suite. The non-milestone seed now pre-flags every milestone as spent. Green at **238 domain / 238 app / 57 UI / 381 Android unit**, 0 failures. **Still owed:** restore — approve grace and allowance first, and add backend state only if restores must follow the account across devices. |
| H8 | P2 account QA | **Finish Profile account journeys** | Name has a local success path but remote errors are not clearly surfaced. Password change is an email/deep-link flow; email change is deliberately unsupported. | **iOS + Supabase Auth QA.** On disposable accounts, verify display-name sync, reset-email delivery, deep-link return, new-password sign-in and user-facing failures. Decide explicitly whether email change is in scope. |
| H9 | P2 cross-platform | **Sync hydration display preferences** | Water is correctly canonical in ml, but unit and custom glass size remain device-local; identical water can render differently on iOS and Android. | **iOS + Android + Supabase.** Move display unit and glass size together, validate allowed values, preserve ml storage/calculations, add owner-only profile columns or an owner-only preferences object, and test old clients/defaults. |
| H10 | Release gate | **Physical-iPhone connectivity/privacy QA** | Simulator Wi-Fi cannot prove cellular transport, dead-zone recovery, lock-screen copy or notification permissions. | **Human/device.** Test Wi-Fi, cellular-only, forced connection drop, offline save/relaunch/reconnect, notification opt-in/denial and password-reset link on a real iPhone. Confirm data on the shared backend without exposing medical details. |
| H11 | Design gate | **Warm/premium review and real recipe imagery** | This is subjective and can sprawl. Generic recipe gradients are functional but not the requested food photography. | **Design/content owner.** Approve a small screen list and asset brief, then replace only approved placeholders and rerun SE/dark/light visual QA. |
| H12 | P2 content + iOS | **Link the pH science and Shettles website content** | The app contains cited in-app articles and a generic `https://genesyx.co.uk` share root, but no approved Genesyx URLs for these two promised external destinations. Guessing paths could ship a 404 or unsupported efficacy copy. | **Content owner + iOS.** Publish/approve the two exact HTTPS pages, keep Shettles framed as an unproven theory, add visible CTAs from the relevant Learn/pH surfaces, and test both routes on device. |

### 6A.2 Supabase action matrix

Live read-only audit on 13 Aug 2026 found nine public tables, including the newly deployed
`user_supplements` and `genesyx_products`. Core health tables remain owner-only. The product catalogue
is authenticated read-only; user supplements are owner-only; `user_supplements.user_id` cascades
from `auth.users`; `product_id` becomes null if a catalogue item is removed.

| Backend item | Live state | Action now |
|---|---|---|
| `ph_readings.measurement_type` and conditional range | ✅ Deployed | **No migration. Never relabel or bulk-update existing pH rows.** H0 is local iOS serialization. |
| `daily_logs.food_groups` | ✅ Deployed | **No schema work was needed and none was done.** Both clients now read and write the column and count it toward the shared streak rule. Android's DTO omits the field while empty, so the server's `'{}'` default applies. Only the Android editor UI and device sync QA remain. |
| `quiz_answers` | ✅ Owner-only table | No schema work for optional onboarding. Keep question ids stable. |
| `user_supplements` / `genesyx_products` | ✅ Deployed with correct RLS/FKs; H1 deletion backstop is also live | Do not change production again. Check the exact applied migration into this repo (the shared-backend one); Android keeps an audit pointer, not a second executable copy. Then prove deletion only with a disposable account. Never delete catalogue rows during account deletion. |
| `profiles.push_enabled` | ✅ Default is `false` | H2 is complete. Existing rows remain 18 true / 0 false by design; do not bulk-reset them. |
| Cycle history | ⬜ No table | Design and review H3 first; do not invent/apply a table during the quick backend patch. |
| Dated article reads/activity events | ⬜ No table | Product decision H6 first; current slug-only read state cannot be safely backfilled with dates. |
| Hydration display preferences | ⬜ Not in shared profile | Design H9 with Android before adding fields. Keep canonical water in ml. |

### 6A.3 Safe order from here

1. ✅ **Done 13 Aug:** H0 pH persistence, H5 full history/editing, T7 optional onboarding, H1
   deletion backstop, H2 push-default correction, H3's honest iOS “Current cycle length” copy and
   H4's meal wiring (iOS complete, Android at read parity).
2. **Repository reconciliation:** copy the exact production migration into **this repo's**
   `supabase/migrations/` so git matches project `epltxklawpcxxbaleswg`. Do not replace it with
   either older draft. **One executable copy, not two:** this is the shared-backend repo and the
   backend is applied from here, so Android must not grow a `supabase/migrations/` directory — its
   SQL records stay under `docs/migrations/` as audit history pointing at the canonical file. Two
   runnable copies of the same migration is how a stale one gets applied. Then run the H1
   disposable-account deletion test; production DDL alone does not prove runtime behaviour.
3. **Decide the shared contracts before more SQL:** H3 period events, H6 article/cycle streak
   events, H7 restores and H9 hydration display preferences. H4's contract is now settled in code —
   a meal-only day is a meaningful log on both clients — but the **“Days with meals” Insights metric
   is still open to a product ruling**, and any change to it must move in both repos together.
4. **Largest visible implementation gap:** the Android food-group editor, so meals can be logged
   from either phone rather than only from iOS. Then implement whichever of H3/H6/H7/H9 received an
   explicit product decision.
5. Complete H8 on disposable auth accounts, approve/wire H12's exact website URLs, run H10 on a
   physical iPhone, and finish the H11 design review before calling Sections 1–3 release-complete.

### 6A.4 Applied shared Supabase result — 13 Aug 2026

Production project **`epltxklawpcxxbaleswg`** received one guarded transaction named
`20260813_user_supplements_delete_backstop_and_push_default_false` with exactly two changes:

1. It spliced `delete from public.user_supplements where user_id = v_uid;` into the deployed
   hardened `delete_current_user()` exactly once, immediately before profiles/auth deletion.
2. It changed only the `profiles.push_enabled` column default to `false`.

Post-apply checks passed: function owner `postgres`, `SECURITY DEFINER`, `search_path=''`, and EXECUTE
for postgres/authenticated/service_role only were preserved; all hardened cleanup blocks remained;
profiles = 18, user supplements = 1, products = 0 and pH readings = 61 before and after; existing
push distribution stayed 18 true / 0 false. The migration never called deletion, touched pH, or
changed RLS, grants or foreign keys.

**Remaining evidence/repository work:** the exact applied file is not yet present in this iOS repo's
`supabase/migrations/` and must be checked in **here**, verbatim — this is the shared-backend repo
and the only place an executable copy belongs. Android's `docs/migrations/2026-07-29_user_supplements.sql`
already carries a DO NOT APPLY banner pointing at this directory, and that pointer is the whole of
Android's obligation. Then run account deletion end to end on a disposable account and prove its
supplement, profile/auth row and email-keyed residue are removed. **This test is explicitly pending
and must never be run against an existing user** — the project holds 18 live profiles including
Apple's reviewer.

### 6A.5 Public App Store gates outside the 44-item client count

These do not change the client-list completion percentage, but they must not disappear from release
planning:

- **Article 9 explicit consent:** the live policy names Article 9(2)(a), but the app has no explicit
  consent step or stored policy version/timestamp. Legal must either approve a different lawful
  basis or engineering must implement an auditable consent record before public submission.
- **Sign in with Apple deletion:** the iOS `delete_account` Edge Function does not revoke Apple's
  refresh token, and two Apple identities exist live. Add Apple `/auth/revoke` handling and make
  waitlist cleanup failure honest before public submission.
- **Deletion behaviour:** after the migration is version-controlled, use disposable accounts to
  prove both the iOS Edge Function and Android SQL RPC erase the same shared-backend data.

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

The completed extension to `NotificationPlanner.plan()` was **~3–4 days total**:

| Notification | Effort | Task |
|---|---|---|
| Fertile-window entry alert | 1.5d | ✅ T14 |
| Weekly new-article alert | 0.5d | ✅ T28 |
| Per-supplement reminders | 1d | ✅ T30 |
| Per-category opt-in toggles | 1d | ✅ T15 |

---

## 9. Historical initial timeline

This was the pre-implementation estimate for one experienced iOS developer. Do not use it as the
current remaining estimate; use section 6A.

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
| 11 | T8 — persist quiz answers in the owner-only table | 1.5d | ✅ |
| | **Total** | **12.75d** | 1.25d QA buffer |

**Sprint 1 is complete** — all eleven rows shipped, `71567c8` … `148e754`. Two things it leaves
behind for whoever picks up next:

1. **Historical migration warning, now superseded.** Quiz answers, sexual activity, food groups,
   pH type/ranges, user supplements and the product catalogue are present live. Use section 6A.2
   for current backend work; never infer production state from this sprint journal.
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
- **T7** (optional preference answer) — the four safe options have shipped. What remains is a Skip
  path and tests proving that no answer is stored or invented when she skips.
- **T9** (offline symbol) — G3. *Superseded 11 Aug 2026: reproduced and fixed. The original "no such
  code path" reading looked for reachability monitoring; the badge is driven by the owed-days set.*
- **T21 · T22** (artwork, visual pass) — G4 / no design spec. T22 will sprawl without one.
- **T16–T19** (profile editors) — real work, but no defect; they are unbuilt features.
- **T23–T27** (nutrition) and **Phase 6** — separate scope. *Superseded 12 Aug 2026: T23–T27 all
  shipped. None of them needed a gate — the nutrition work was scoped out of Sprint 1 for size, not
  for approval, and food groups rather than nutrients kept it that way.*

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
| 21 | Phase 3 — tracking markers, fertile-stage highlight, dark-mode contrast | 1d | ✅ |

T19 is no longer an unbuilt row: the Profile flow requests a Supabase reset email. It remains partial
until a disposable-account test proves email delivery, deep-link return, password replacement and
sign-in with the replacement credential.

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

**Row 21 — the markers were already colour-coded; what was missing was that they were only legible
in one scheme.** The client asked for colour-coded tracking markers and a fertile-stage highlight.
The dots existed and the fills existed, but both were built on `tintOnWhite`, which is `.opacity()`
and therefore silently wrong over a dark card: the day number fell to 4.23:1 on the fertile fill and
the dots to 1.19–1.37 on the ovulation cell. So the task was two-thirds a contrast fix wearing a
feature request's clothes. The four fills became adaptive tokens (light pixel-unchanged), the dots
grew to 5pt and gained a bright variant for the one solid cell, and the fertile window gained a ring
that spans the whole run — driven by the window rather than by the day's phase, so a short cycle's
period ∩ fertile overlap is still shown. `CalendarContrastTests` pins all of it in both schemes.

⚠️ **Android parity, lower stakes.** The same `tintOnWhite` pattern is the obvious way to have built
the Android grid, and it fails the same way. Worth a look before Android's own dark mode ships;
nothing in this repo can check it.

---

## 10. Verification gate

The independent baseline before Claude's pH patch was **236 domain, 233 app and 47 UI tests**, all
passed with no failures or skips. The latest clean full-suite baseline after H0 · H5 · T7 ·
H3-interim · H4 · H4-log-sheet · H7-celebration · sleep-contract is **239 domain, 238 app and 57 UI tests** — 0 failures, 1 skip
(`NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission`, which needs the
real device in H10 and skipped before this work too). The 52nd UI test is H3's claim guard,
`testInsightsReportsCycleLengthWithoutClaimingRegularity`; the 53rd is H4's,
`testAMealLoggedTodayReachesTrackMyLogsAndInsights`; the 54th and 55th are the log sheet's,
`testTheLogSheetCanRecordAndClearAMeal` and
`testSavingTheLogSheetKeepsAMealLoggedFromNutrition`.

H0's create → terminate → relaunch check is no longer a manual step: it is
`testAVaginalPhReadingSurvivesKillingAndReopeningTheApp`, which saves a reading, calls
`app.terminate()`, and relaunches into a **second process** via the new `-uiTestKeepStore YES` flag
(same local-only container, no wipe, no re-seed, still no backend — a relaunch without the seed flag
would resolve the real Supabase project). Reverting the one-line `PhRecord.dto` fix makes it fail on
"her pH history must still be there after a cold start", so the guard is proven to bite rather than
merely proven green. Run after every task:

```bash
swift test && xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:GenesyxUITests
```

- Record the `.xcresult` summary; terminal silence or exit 0 alone is not sufficient evidence.
- If the simulator reports `Application failed preflight checks` / `Busy`:
  `xcrun simctl shutdown all`, then re-boot and retry. That is a simulator flake, not a code failure.
  If it survives that (it has, twice in a row), go heavier —
  `killall -9 com.apple.CoreSimulator.CoreSimulatorService`, `xcrun simctl erase <device-id>`, then
  `xcrun simctl bootstatus <device-id> -b` to wait for ready before handing the device to `xcodebuild`.
- `testTheCalendarWorksWithoutACycleSetUp` is the suite's timing-sensitive one. It failed once on
  13 Aug at "the day she logged should carry the marker" **taking 24.5s against its usual 13–14s**,
  and passed in isolation and on a clean full re-run. Duration is the tell: if it fails at anything
  near its normal time, treat it as real; if it is slow, `xcrun simctl shutdown all` and re-run
  before believing it.
- **Never run two `xcodebuild test` processes at once.** They contend for the one simulator and the
  loser dies with `Test crashed with signal kill` — which reads exactly like a real crash, and cost a
  full afternoon of chasing a UI bug that did not exist. `ps aux | grep "xcodebuild test"` before you
  start; a run abandoned by a killed shell keeps its child alive.
