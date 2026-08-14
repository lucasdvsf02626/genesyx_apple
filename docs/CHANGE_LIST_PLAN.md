# Genesyx iOS — Client Change List: Audit & Execution Plan

> Response to the client's "Simplified Consolidated Changes" list (received 2026-08-10).
> Historical execution journal for builds 17–18. The working tree was frozen and committed on
> 14 Aug 2026 as **`8580dd671d95f1eab04cc23ba4175927a4e651b2`** (`8580dd6`) — **the release SHA**. The authoritative baseline is a
> **single sweep of all three suites over one byte-identical tree** on 14 Aug:
> **267 domain / 288 app / 79 UI** — 0 failures, 1 pre-existing permission-dependent skip
> (`NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission`).
> Logs: `/tmp/genesyx_h22i_full_ui.log` (886.043 s, 79 exec / 1 skip / 0 fail, 14:16),
> `/tmp/genesyx_h22_final_app.log` (288/0, 14:20), `/tmp/genesyx_h22_final_domain.log`
> (267/0, 14:18). The UI run was made adversarial on purpose — `simctl keychain reset` first,
> to re-arm iOS's "Save Password?" sheet — on a simulator with no other `xcodebuild` attached.
> Historical H21/H11 UI logs (67/1/0) remain valid for those batches and are superseded
> as the overall baseline.
> Legend: ✅ complete · 🟡 partial/in progress · ⬜ missing · ⚠️ decision or external gate

---

## 0. Read this first

### 0.0 FROZEN PRODUCT DECISIONS — 14 Aug 2026 · DO NOT REOPEN

The client froze these to stop every assistant and reviewer re-litigating them. **They are settled
input, not open questions.** Do not re-analyse, re-propose, re-estimate or "improve" any of them.
If a future request appears to contradict one, stop and ask rather than assuming it was reversed.

| # | Decision | Ruling | What it closes |
|---|---|---|---|
| **D1** | Warm / premium presentation | ✅ **APPROVED** | The subjective design sign-off that item 2A / group 5 was waiting on. Group 5 is now complete. |
| **D2** | Deleting a whole daily log | ❌ **No — not in this release** | The data-retention ruling item 1B was half-blocked on. No delete path is to be built on either client. |
| **D3** | Cycle edits and article reads counting toward the streak | ❌ **No — not in this release** | H6 / item 7. **No new production column, no Android migration.** |
| **D4** | Occasional streak restore | ❌ **No — not in this release** | H7 / item 8. Same descoped column and migration as D3. |
| **D5** | The bundled guide PDF | ⚠️ **Usable internally — NOT App Store-ready** | The guide ships in internal/TestFlight builds. It is a release blocker for public submission until §11.1c's four content corrections and the medical/content-source review are done. |

**D3 and D4 are descoped, not done.** Do not present them as delivered. They are two of the 44 items
and they are being consciously left unbuilt for this release, which is a different thing from being
finished. The same applies to D2.

**What D1 does *not* license.** Approval is of the presentation direction and closes the sign-off
gate. It is not a licence to restyle screens freely: every visual change still goes through the same
tests, the same accessibility expectations and the same compliance guards as any other change.

### 0.1 Website status — re-fetched 14 Aug 2026, and item 1 is still blocked

Two new slugs appeared today. They were fetched live and **must not be wired**.

- `https://genesyx.co.uk/pages/ph-tracking` — product/marketing page (unchanged).
- `https://genesyx.co.uk/pages/vaginal-ph-fertility-science` — **same product copy** as
  `/pages/ph-tracking` (H1 “Track your vaginal pH at home”, Play-store CTAs, “A small signal
  that says a lot”). **No citations, no studies, no science article.**
- `https://genesyx.co.uk/pages/shettles-method-evidence-limitations` — empty Shopify page.
  The H1 is the slug. It does **not** call the method unproven and does not cite Wilcox 1995.

App grep of those two paths: **0**. H12 / item 1 stays **BLOCKED**. Do not substitute a
marketing page or an empty slug for a cited science page and a framed Shettles page. The
in-app Shettles article already carries the framing and the Wilcox 1995 citation (§1, G1).

---

**Current item-by-item result for Sections 1–3, after the 14 Aug freeze: 37 of 44 Done (84%),
2 descoped by decision (D3, D4), 5 still open. Section 4 remains excluded.** Against the agreed
release scope — the 42 items left once D3 and D4 are removed — that is **37 of 42 (88%)**. Both
numbers are given deliberately: the first is what the client asked for, the second is what this
release is committed to deliver, and quoting only the second would flatter the result.

The one item that moved is 2A's warm/premium review, closed by **D1** (the subjective
sign-off) plus the bounded splash lockup that followed it (`Image("brand_lockup")` at 220×54).
**All five remaining open items need a person, a page or a device — none is code waiting to
be written.** This replaces the earlier rough
count with the row-level assessment in `PROGRESS_CHECKLIST.md`, which is the source of truth for the
tally and was re-counted row by row on 14 Aug 2026 — this line had drifted one behind it. The original 25/44 count pre-dated
the pH relaunch/history fix, optional onboarding, honest cycle-card copy and live Supabase
corrections. Section **6A** remains the source of truth for the hard work and external gates.

| Client item | Current verified reality |
|---|---|
| 1A vaginal pH | 🟡 The dedicated tab, correct wording, logging, chart, Insights, full dated history, edit/delete, guidance and expandable disclaimer now work. A real second-process cold-relaunch test proves vaginal type persists. No migration or pH reclassification is permitted. The remaining client-list item is the approved Genesyx website links for science and Shettles (H12). |
| 1B dated logs/calendar | 🟡 Hydration, sleep, symptoms, mood, energy, notes, supplements, food groups, pH and intimacy all survive relaunch on their correct dates, and calendar markers work. Food groups gained their dated Track/My Logs/Insights wiring on 13 Aug (H4). Live Profile journeys remain H8. |
| 1C preference question | ✅ Girl / Boy / No preference / Prefer not to say are implemented safely, and it is now the one question she may skip outright — skipping stores no key at all, locally or on the server. |
| 1D connectivity | 🟡 Reachability wording, local-first queues and the pH offline/cold-relaunch path are implemented and automated. Code audit found no cellular restriction. Physical cellular / dead-zone QA is **DEFERRED** (H10) — no physical iPhone is available. Not Done. |
| 2A presentation | ✅ **Approved 14 Aug 2026.** Bounded warm/premium presentation signed off; all eight recipe photographs approved; full Genesyx lockup on the initial splash (`Image("brand_lockup")`, identifier `onboarding.brandLogo`). |
| 2B Nutrition | 🟡 Food-group logging, recipes and supplement reminders work, and food groups now feed Track, My Logs, a “Days with meals” Insights tile and the shared streak contract on both clients. Her own supplements now sync to `user_supplements` with tombstones and carry the same four time options Android uses (H19, 14 Aug), so a reinstall no longer loses them. Only the Android editor UI is outstanding — iOS remains the one place meals can be logged. |
| 2C Hydration | ✅ Glasses/ml, custom glass size, correction, target progress, persistence and Insights work. Display unit/glass preferences are still device-local. |
| 2D contextual cycle guidance | ✅ Phase-change card, article route and personalised Home greeting are implemented. |
| Cycle Insights | 🟡 Predictions work, but only one `cycle_settings` row exists. The card no longer claims regularity — it is titled “Current cycle length” — but real regularity still needs the H3 period-event model. |
| 3A streak | 🟡 Visible and data-linked, and meal-only days now hold a streak identically on both clients (H4). Milestones celebrate in-app and follow the logging streak. Cycle edits / article reads (**D3**) and streak restore (**D4**) are **descoped, not Done** — no new production column, no Android migration. |
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
- [x] ✅ **T22 — Warm/premium visual pass.** **Done 14 Aug 2026.** User approved the bounded warm/premium presentation, the eight recipe photographs, and the full Genesyx lockup on the initial splash. Splash `Text("GENESYX")` replaced with `Image("brand_lockup")` at 220×54; eggs, copy, quiz/sign-in and disclaimer unchanged. `BrandAssetTests.testBrandLockupArtworkExists` plus `onboarding.brandLogo` on the onboarding UI path. Falsified once (`brand_lockup_missing` → `XCTAssertNotNil failed`, 0.066 s), restored, green.

## 5. Phase 4 — nutrition (15–20d)

- [x] ✅ **T23 — Custom glass size.** A glass is now hers to size (50–1000 ml, default 250); a cup
      stays fixed at 240 ml because it is a recipe measure, not an object she owns, and millilitres
      are the storage unit itself. Out-of-range values fall back to 250 rather than clamping, so a
      corrupted store shows the familiar default instead of a number she never picked —
      `HydrationUnit.resolvedGlassMl` is the single place that decision is made.

      That fallback covers a *stored* value, not a typed one, and the difference mattered: what she
      typed was dropped in silence and left on screen looking saved. Fixed in **H14** — the field is
      now clamped to the nearest allowed size when she leaves it, so `resolvedGlassMl` only ever sees
      an out-of-range value from a corrupted store, which is the case it was written for.

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

      **Photography has since shipped — this paragraph described the position up to 13 Aug and is
      kept for the reasoning, not the status.** The original call was to ship no images rather than
      stock photos of somebody else's food (Apple Guideline 2.1 territory), so each card rendered on
      the phase accent and `Recipe.imageName` was a nil seam. All eight recipes now carry their own
      photograph, and the guard swapped rather than vanished:
      `testNoRecipeClaimsAnImageTheAppDoesNotHave` is gone, replaced by
      `testEveryRecipeHasAUniqueImageMapping` (domain — no recipe imageless, no two sharing a plate)
      and `testEveryRecipeImageAssetExists` (app target — each name loaded through `UIImage(named:)`).
      **The split is the point:** SwiftUI's string-based `Image` lookup fails silently, so a typo
      renders an empty card rather than falling back to the gradient, and only a UIKit-side load
      proves the asset ships. `imageName` stays optional so a newly-authored recipe can use the
      gradient while its artwork is prepared. **The eight photographs were approved 14 Aug 2026
      (D1 / H11).** Shipping remains verified by the two image tests; approval is no longer open.

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
| H1 | ~~P0 backend~~ | ~~**Complete account-deletion backstop for `user_supplements`**~~ | The live table already had owner-only RLS and `auth.users ON DELETE CASCADE`, but the hardened RPC lacked an explicit defence-in-depth delete. | ✅ **Production done 13 Aug.** Project `epltxklawpcxxbaleswg` now has the line exactly once before profile/auth deletion; partner unlink, owned-data deletes, email-keyed invite/waitlist cleanup, owner, ACL, `SECURITY DEFINER` and `search_path=''` were preserved. Row counts identical before and after: profiles = 18, user_supplements = 1, genesyx_products = 0, ph_readings = 61. `delete_current_user()` was **redefined, not executed** — no account was deleted to obtain this evidence. **Repository work closed 14 Aug:** the exact applied migration is checked into **this repo** at `supabase/migrations/20260813_user_supplements_delete_backstop_and_push_default_false.sql`, verbatim and `cmp`-identical (md5 `55c387ecc1fc940b892bd8bdc3e1cfb5`, 3424 bytes); Android keeps only an audit pointer under its `docs/migrations/`. **Still owed, and it is remaining behavioural QA rather than missing implementation:** run a disposable-account deletion test. Production DDL is not proof of runtime behaviour. |
| H2 | ~~P1 backend~~ | ~~**Make push consent semantically opt-in**~~ | iOS already requires preference + system authorization; the server default had contradicted that model. | ✅ **Production done 13 Aug.** `profiles.push_enabled` now defaults to `false`. No existing profile row was rewritten: distribution stayed 18 true / 0 false. Android reminder behaviour still deserves parity QA, but the shared default is fixed. |
| H3 | P1 product + backend | **Real cycle history and honest regularity** | Both apps have one current `cycle_settings` row. A configured 28-day length cannot prove regularity. This needs a dated-event model, offline conflict rules and migration on both clients. | **Product + iOS + Android + Supabase.** Approve what counts as a period start/end/correction. Then design an owner-only `cycle_periods`/equivalent table with client ids, timestamps and tombstones; implement local-first sync on both platforms; derive regularity only from sufficient completed cycles. 🟡 **Interim implemented 13 Aug, iOS only:** the card is renamed “Current cycle length”, guarded by `testInsightsReportsCycleLengthWithoutClaimingRegularity`, which asserts no static text on Insights contains “regularity” — proven to bite by reverting the title. Full suite green at 236/238/52. The `CycleRegularityLogic`/`CycleRegularityInsights` types keep the old name so the Android mirror still matches; rename them together when period events land. The modelling work below is untouched and still owed. |
| H4 | ~~P1 cross-platform~~ | ~~**Connect meals to Track, My Logs, Insights and streaks**~~ | `daily_logs.food_groups` was live, but iOS Insights counted supplements only and both shared streak engines deliberately excluded food groups. An iOS-only change would have produced different streaks from identical backend data. | 🟡 **iOS done 13 Aug; Android at read parity. No SQL was needed or written.** Both iOS engines now count meals (`TrackingEngine.isMeaningfulLog`, `StreakEngine.hasAnyEntry`), so a meal-only day holds a streak. Track's dated summary lists “N food groups”; the My Logs day card lists them by known case, so a group written by a newer build renders as nothing rather than a raw token; Nutrition Insights gained a separate **“Days with meals N / 7”** tile. Android received the whole read/write half — Room v9 (`MIGRATION_8_9`, nullable `foodGroups TEXT`, generated `9.json` verified against the ALTER), DTO field omitted-while-empty, Supabase read/write, and the same widened `isMeaningful()` — so both clients compute identical streaks from the same rows. Two real defects were fixed on the way: Android's log form rebuilt the whole row and would have **deleted iOS-written meals on every save** (now carried through, plus `upsertPreservingWater` preserves them against a mid-edit sync), and meal-only days no longer render as empty in Android history. **The two `tracking_test_vectors.json` files never mirrored each other byte-for-byte and never had** — the false claim is now corrected in both repos, each file extended in its own schema, and the Android additions falsification-tested (removing the predicate term makes them fail). A v8→v9 Room migration test was also added, since every prior `daily_logs` migration had one and this did not; it runs on a real emulator and fails if the ALTER grows a `DEFAULT`. All three new iOS surfaces are covered end to end by `testAMealLoggedTodayReachesTrackMyLogsAndInsights`, which cooks a recipe and then goes looking for the meal on Track, My Logs and Insights; each of the three assertions was falsification-tested by breaking that surface alone and watching only it fail. It writes to *today* deliberately, because the Insights tile counts within the current ISO week and seeding a past day would make a Monday run legitimately read zero. Green at 236 domain / 238 app / 53 UI / 380 Android unit / 3 Android instrumented, 0 failures *at that point in the day*. **What H4 left owed:** a food-group control in the daily log sheet on **both** clients — on iOS the Track day sheet reported “N food groups” while “Edit this day” could not change them, and on Android there was no way to record a meal at all — plus offline/relaunch/sync QA on both devices. The QA and the Android control are still owed; the iOS control is not, see below. **The “Days with meals” metric is my reading of the plan's open “agree the insight metric” item — redirect it if the product owner wants something else.** **Closed on iOS later the same day:** `LogView` gained a `foodGroupsSection` of the same six `FoodGroup` cases Nutrition offers, so “Edit this day” can now change the meals the day sheet reports and a meal can be entered from the tracker rather than Nutrition only. It is a *toggle*, unlike the recipe card's deliberately additive `logFoodGroups` — this is the day's editor, and an editor that cannot un-tick is not one. That made `save()` start writing `foodGroups` rather than carrying them through, which is precisely the shape of the bug already found and fixed on Android, so it is guarded by its own test: `testSavingTheLogSheetKeepsAMealLoggedFromNutrition` logs a recipe, saves an unrelated field from the sheet, and asserts *both* that the save landed and that the meal survived it. Deleting the `populate()` read makes it fail with `Logged: 0.8 L water, pH test, intimacy.` — the meal gone, exactly as predicted. `testTheLogSheetCanRecordAndClearAMeal` covers the round trip including un-ticking. Green after that change at 236 domain / 238 app / 55 UI, 0 failures. Android still has no such control and remains read-only for meals. |
| H5 | ~~P1 iOS~~ | ~~**Complete pH history editing**~~ | The premise was generous: a `.sheet(isPresented:)`/`editing` race meant **no** reading was editable — every tap opened a blank new-reading sheet and saving filed a duplicate. | ✅ **Done 13 Aug.** One `PhSheetMode?` presented with `.sheet(item:)`, plus a collapsible dated "Reading history (N)" opening any reading for edit or delete. Legacy urine stays hidden. **Android parity review still owed.** `HANDOFF.md` §4k. |
| H6 | P2 product + cross-platform | **Decide how article reads and cycle actions count toward streaks** | Article read state currently stores only device-local slugs, not dates. A read cannot honestly count for a specific day or sync across phones. Cycle-setting changes are likewise not event history. | ❌ **Descoped 14 Aug (D3). Never Done.** Cycle edits and article reads do not count in this release. The dated column and Android migration are cancelled. |
| H7 | 🟡 P2 product | **In-app milestone celebration and optional restore** | Milestones scheduled local notifications and nothing else. Restore affects the canonical meaning of the streak and could become a paid/gamified entitlement. | 🟡 **Celebration done 13 Aug on both clients; restore still an open product decision. No schema, no migration, no SQL.** The premise understated it: the milestone check ran inside `replan()`, behind `guard isActive`, so the woman who *declined* notifications logged for a week and the app said nothing at all — the missing in-app moment was not a polish gap, it was the whole feature for the majority case. `checkMilestones()` now runs outside that gate, from `reconcile()` (launch and every foreground) and from the `dailyLog.$logByDate` observer; only the banner half still needs permission. Ordering is load-bearing and documented: `replan()` opens with `cancelAll()`, which would sweep away a milestone scheduled ahead of it, so `replanAndCelebrate()` fixes the sequence. **The trigger was repointed, on both clients in the same sitting:** the 7- and 14-day milestones followed *hydration* while Home headlines the *logging* streak, so a woman who logged a meal and her symptoms every day for a fortnight watched that number climb and was congratulated for nothing. Both engines now key off the activity streak — the number she is actually shown — matching the client's 3A wording. `MilestoneCelebrationView` reuses `NotificationContent.milestoneTitle`/`milestoneBody` rather than writing fresh copy, so the banner and the app cannot congratulate her for different things and the words stay inside the reach of the banned-phrase and no-guilt scans. Only the largest crossed milestone is shown — day7 and week1 together is one good week, not two stacked modals — and `celebration` is only ever assigned non-`nil`, because writing `nil` on the next call would tear the moment off screen the instant she logged anything else. Two UI tests cover it: `testMilestoneIsCelebratedInTheAppWithoutNotificationPermission` (running with no permission granted *is* the test) and `testACelebratedMilestoneDoesNotReturnOnTheNextLaunch`, a cold relaunch against the same store. Three falsifications, each rebuilt and re-run: restoring the `isActive` guard, flipping `.last` to `.first`, and deleting `prefs.celebrate(...)` each fail exactly one assertion. **Two real defects were found on the way.** A VoiceOver one: an `accessibilityIdentifier` on the card container does not name the card — SwiftUI lets the outermost one win, so it renamed the only control inside and the whole celebration collapsed into a single button called “Thanks”, with the words she had earned unreadable. That was first worked around by leaving the container unnamed, which left the UI test no handle on the card at all. The settled fix is `.accessibilityElement(children: .contain)` **plus** the identifier: `.contain` declares the card a container whose children stay their own elements, so the card can carry a name and the title and button keep theirs. Removing `.contain` reproduces the original bug exactly, and the UI test now asserts both halves — the card exists *and* still has its button inside it. And a test-harness one: with the celebration no longer gated, the base UI seed crosses `week1` on most weekdays, so a full-screen modal would have opened over the tab bar in every unrelated test and eaten its taps — and with `continueAfterFailure = false` that aborts the whole suite. The non-milestone seed now pre-flags every milestone as spent. **Finished 13 Aug and re-verified end to end at 241 domain / 241 app / 57 UI (1 skip) / 381 Android unit, 0 failures** — the earlier 238/238/57 predates the final UI changes and must not be quoted as the current baseline. Three tests were added to close the gaps the first pass left: `testAMilestoneIsCelebratedInAppEvenWithPushTurnedOff` pins the whole point of the feature at the service (push off, `isActive` false, celebration still delivered); `testMutingMilestonesRemovesTheModalTooAndStillSpendsTheFlag` defines muting, which was implemented but undefined — muted means *none*, the modal goes with the banner, and the flag is still spent so unmuting months later delivers silence rather than a backlog of modals; and `testSevenMealAndSymptomDaysEarnDay7WithNoWaterAtAll` joins a real `DailyLog` to a real milestone, which no fixture did because `FakeLog` hardcodes `hasAnyEntry: true`. **Falsification found two defects in the new tests themselves, and one real coverage hole.** A `pendingNotificationRequests` assertion could never fail — iOS silently refuses to register requests from an unauthorised app, so the queue is empty whether or not our own gate is there; it was deleted rather than re-run. A test written around `authorizationStatus == .notDetermined` failed because the test host reports `.authorized`: system permission is host state that varies by simulator, so the gate is now pinned on `pushEnabled`, the only term a test can control. And deleting `!symptoms.isEmpty` from `hasAnyEntry` left **all 241 domain tests green** — a day whose only entry was how she felt would have stopped counting on iOS while Android went on counting it, the exact divergence the file exists to prevent; `testEveryFieldInTheContractMakesADayCountOnBothPredicates` now walks every term of the contract on both predicates, one field at a time. **Still owed:** restore — approve grace and allowance first, and add backend state only if restores must follow the account across devices. |
| H8 | 🟡 P2 account QA | **Finish Profile account journeys** | Name has a local success path but remote errors are not clearly surfaced. Password change is an email/deep-link flow; email change is deliberately unsupported. | 🟡 **The code-side audit is now done; only the account QA is still owed.** Reading the section rather than deferring it wholesale found five real defects, and the premise above was wrong about the first: the name had no working remote path at all, not merely unclear errors — fixed under **H13**. The other four are fixed under **H14** (out-of-range glass size dropped in silence, the master reminder switch mislabelled "Weekly", the Pregnancy segment persisting an unimplemented mode, and two dead references). **What genuinely still needs a person:** on disposable accounts, verify reset-email delivery, the deep-link return, sign-in with the replacement password, and how remote failures read to her. Decide explicitly whether email change is in scope. Account creation and password entry are actions the delivery agent is not permitted to take. |
| H9 | P2 cross-platform | **Sync hydration display preferences** | Water is correctly canonical in ml, but unit and custom glass size remain device-local; identical water can render differently on iOS and Android. | **iOS + Android + Supabase.** Move display unit and glass size together, validate allowed values, preserve ml storage/calculations, add owner-only profile columns or an owner-only preferences object, and test old clients/defaults. |
| H10 | Release gate | **Physical-iPhone connectivity/privacy QA** | Simulator Wi-Fi cannot prove cellular transport, dead-zone recovery, lock-screen copy or notification permissions. | **DEFERRED 14 Aug 2026.** No physical iPhone is available. Code audit found no cellular restriction (`NWPathMonitor()` unconstrained; no `isExpensive` / `isConstrained` / `allowsCellularAccess`). Do not claim cellular testing from a simulator. Do not leave this In progress for missing hardware. |
| H11 | ~~Design gate~~ | ~~**Warm/premium review and recipe-imagery sign-off**~~ | Subjective approval plus the splash lockup. | ✅ **Done 14 Aug 2026.** User approved (a) the bounded warm/premium presentation, (b) all eight recipe photographs, (c) the full Genesyx lockup on the initial splash. Implemented as `Image("brand_lockup")` at 220×54 — existing light/dark imageset, no duplicate SVG. Falsified once (`brand_lockup_missing` → `BrandAssetTests.swift:47` `XCTAssertNotNil failed`, 0.066 s, exit 65). Restored green: BrandAssetTests **5/0**; `testTheOnboardingQuizRunsEndToEnd` **passed 15.552 s** (logo asserted before the quiz tap); GenesyxAppTests **276/0**; full UI **67 exec / 1 skip / 0 fail**, 785.772 s (`/tmp/genesyx_h11_full_ui2.log`). First full-UI pass after the lockup had one citation flake (`testCitationTapOpensBrowser`, y=658 under the tab bar); isolated rerun **passed 5.633 s**. |
| H22 | P0 iOS | **Mandatory authentication gate** | `RootView` mounted `MainTabView` from `onboardingComplete` alone. Logout, deletion, a missing session and an expired token therefore left all seven private tabs usable. Existing UI tests encoded that as expected behaviour. | ✅ **Engineering Done; simulator verified; physical-device QA deferred.** 14 Aug 2026, iOS only. No SQL. Session has `resolving` / `signedOut` / `signedIn`. Root routes from session first (`RootRouting.swift`); splash/quiz/guide stay pre-auth; the seven tabs require a validated session. Mandatory `AuthView(allowsDismissal: false)` has no “Back to app” and shows `brand_lockup`. **Two evidence gaps found and closed 14 Aug by a second audit pass** — the first version of this row was green on tests that did not prove what their names claimed. (a) **The expired/revoked-token path had zero coverage at any level.** The UI test that appeared to cover it launched with `-uiTestSignedOut`, which seeds *no credential* — the *missing*-session path, a different mechanism from a cached credential the server has stopped honouring. `App/GenesyxTests/SessionExpiryTests.swift` (new, 4 tests) now drives that path through an injected `AuthBackend` fake — no Supabase, no network, no account: expiry signs out *and* fires `onBecameSignedOut` (the hook that drops the held notification destination and cancels the schedule); neither `.tokenRefreshed` nor `.initialSession(userId: nil)` can resurrect it; a cold launch whose `currentUserId` is non-nil but whose `validatedSession()` is nil resolves `.resolving` → `.signedOut`, never `.signedIn`; and a genuine new `.signedIn` still works, so the gate is not "correct" by refusing everything. The UI test was renamed `testMissingSessionNeverShowsPrivateContent` to stop it claiming the other path. (b) **`testNotificationTapWhileSignedOutDoesNotOpenATab` performed no notification action** — it was a strict subset of the test above it and its name claimed evidence it did not provide. Replaced by a pair: a DEBUG-only launch argument (`-uiTestPendingNotification`, `GenesyxApp.swift:26-38`, inside `#if DEBUG` and referenced nowhere else in product code) injects a destination through the *same* `payload` → `destination` decode the real `didReceive` handler uses, so the assertion is against a genuinely held destination rather than an app that simply has nothing pending. `testPendingNotificationWhileSignedOutNeverOpensItsTab` proves the gate holds it; **`testPendingNotificationOpensItsTabOnceAuthenticated` is the control** — the same injection on a signed-in launch does land on Insights, which is what makes the signed-out result evidence of the gate rather than of an inert hook. **Falsified:** re-inserting `case .sessionExpired: break` in `SessionRepository.swift` → exit 65, `Executed 4 tests, with 6 failures`, `** TEST FAILED **` (`/tmp/genesyx_h22_expiry_falsify.log`); 3 of the 4 failed on exactly the right assertions, and the 4th correctly still passed because it exercises the bootstrap path rather than the lifecycle event. Restored and re-verified. `AuthGateUITests` is now **12 exec / 0 fail**, 87.085 s. Physical logout/relaunch is **DEFERRED** — no iPhone — and does not keep this row In progress. **Every UI test runs `backend: nil`, so they prove the routing table and the view wiring, never Supabase's real session restore** — keychain persistence across a genuine cold boot, a token revoked from another device, and Sign in with Apple on real hardware are unproven, not passed. |
| H12 | P2 content + iOS | **Link the pH science and Shettles website content** | The app contains cited in-app articles and a generic `https://genesyx.co.uk` share root, but no approved Genesyx URLs for these two promised external destinations. Guessing paths could ship a 404 or unsupported efficacy copy. | 🔴 **Still BLOCKED — re-fetched 14 Aug.** Two slugs now exist and are **not** the required pages and are **not wired** (app grep = 0). `https://genesyx.co.uk/pages/vaginal-ph-fertility-science` is the same uncited product copy as `/pages/ph-tracking`. `https://genesyx.co.uk/pages/shettles-method-evidence-limitations` is an empty slug title — no “unproven”, no Wilcox. Do not wire marketing or empty pages. Unblock only when a cited science page and a framed Shettles page are published. |
| H13 | ~~P0 iOS~~ | ~~**Her name never reached the server**~~ | Found by actually performing the H8 Profile audit rather than recording it as "needs live QA". The display name had never been part of the sync contract every other field follows. | ✅ **Done 13 Aug, iOS only. No schema change, no SQL — `profiles.display_name` already existed and was already written.** Three faults, one cause. **(1)** A rename was pushed fire-and-forget — `Task { try? await profile.upsert(displayName:) }` — with no owed flag and appearing in no drain, so a correction made on the train was lost the moment the request failed, the device still showing the new name and the server keeping the old one forever. **(2)** `applySignIn` never pushed at all, so the name she typed at **sign-up** — the one screen that asks for it — never left the device. Her `profiles` row was created with `display_name` null, and `SupabasePartner.fetchPartner()` fell through to its `?? "Partner"`, which is why her partner's app showed her as the literal word "Partner". **(3)** Nothing ever read the column back: `SupabaseProfile.fetch()` selects `id,focus_mode,theme,push_enabled` and `ProfilePrefs` has no name field, so the name was **write-only** — a reinstall or a second phone had nothing to restore from and fell through to the part of her address before the @. She set up her new phone and the app called her "ada". It now follows `PreferencesRepository`'s owed-write contract exactly: `pendingNamePush` persisted under `session_name_pending`, `drainPendingName()` called from `hydrate()`, from `drainPending()` (foreground) and from the reconnect drain, and `refreshDisplayName()` which pushes *before* it pulls so a rename still owed is never overwritten by the copy it is on its way to replace. `onPushDisplayName` returns `Bool` rather than `Void` deliberately — a `Void` closure cannot distinguish a write that landed from one that threw, which is the exact shape of fault (1). The read was added as `ProfileBackend.fetchDisplayName()` rather than by widening `ProfilePrefs`, because a prefs struct carrying the name would let a prefs push overwrite a name that push never read. **Two data-loss traps were designed out rather than discovered later.** Only a name she actually *typed* is ever owed: pushing the resolved name would send the email prefix on every sign-in, overwriting the real "Ada Lovelace" on her row with "ada". And a row whose `display_name` is null leaves hers alone, because every account created before this fix has one, and letting null win would blank the name on screen for all 18 of them at their next hydrate. The flag is cleared on sign-out and on an identity change — the same defect `PreferencesRepository.clearOwedProfileWrite()` exists to prevent, or one woman's owed rename lands in the next account's row. **9 tests, 7 falsifications, each rebuilt and re-run.** Falsification is what earned the sign-out test its current shape: the first version signed the next account in as a *different* user, which the identity-change branch already covers, so removing the sign-out clear failed nothing at all. The case sign-out uniquely protects is signing back in as *herself* — sign-out forgets the stored name, so a still-owed flag would push the email prefix over her own row. Rewritten to that scenario it fails exactly once when the clear is removed. Green at **241 domain / 250 app**, 0 failures. **Still owed:** Android has all three faults and is untouched by instruction (this is the iOS delivery), and because `profiles.display_name` is shared, an Android rename made offline is still lost the same way. |
| H14 | ~~P1 iOS~~ | ~~**Four Profile defects the audit catalogued, and the past-day edit nobody had proved**~~ | The H8 audit listed these rather than fixing them. Each is small alone; together they are most of what "every edit works" means, and one of them silently disabled the feature the client calls critical. | ✅ **Done 13 Aug, iOS only. No schema change, no SQL, no new files.** **(1) A custom glass size outside 50–1000 ml was discarded without a word.** The per-keystroke rule stores nothing out of range, so "3000" sat in the field looking exactly like a setting that had taken, while the glass it described was still 250 ml — and the only thing that ever put the field right was switching units, which nobody does to check a number they believe they saved. Corrected on blur (`glassSizeFocused`), and **clamped to the nearest allowed size rather than reverted**: reverting would answer a woman who typed 3000 with "300", the in-range prefix the keystroke rule happened to store on the way, which is a number she neither typed nor had. Held as text (`glassSizeField`) so a half-typed "3" is never read as a 3 ml glass. **(2) The reminders master switch was labelled "Weekly reminders".** It is neither weekly nor one category: `NotificationService.isActive` gates all eight categories on `pushEnabled`, so a woman declining what read as a weekly digest was silently declining the daily supplement reminders, the evening check-in and **the fertile-window nudge** — a group-2 critical item, turned off by a label. Relabelled "All reminders". **(3) The Pregnancy segment persisted a mode the app does not have.** Tapping it wrote `focusMode = .pregnancy` *and synced it* — to the server and therefore to Android — while the sheet it opened said "Coming soon" and its own button said "Keep tracking". No screen behaves differently in pregnancy mode, so the segment sat there claiming a state nothing implemented, permanently, on every device. It now opens the teaser and stores nothing. **(4) Two dead references removed** — the never-called `switchRow` helper, and `ProfileView`'s unused `@EnvironmentObject partner` (safe: SwiftUI's environment still reaches `PartnerSectionView`, which declares its own). **(5) Correcting an already-logged past day is now proven.** The only existing test back-filled an *empty* day; nothing covered opening a day that already had symptoms and a note. The dangerous failure there is silent — an edit that saved a fresh entry over the old one would take her symptoms and note with it, and she would find out later — so the new test asserts the correction **merges**: both markers on the one cell afterwards, and the day still offers "Edit this day" when she returns. **Falsification, each rebuilt and re-run.** The glass-size break showed the field reading `"3000"` — the client-reported symptom exactly. For the past-day test I deliberately broke `populate()`'s prefill rather than `upsert(entry, on:)`, because breaking the upsert also fails the pre-existing back-fill test and would have proved nothing new; breaking the prefill fails **exactly one** test, with `testAPastDayCanBeLoggedAndTheEntryStaysOnIt` still green, which is what proves the new test covers a guarantee nothing else did. **Two XCUITest mechanics were wrong and are now documented in the helper**, because both had made an assertion pass for the wrong reason: a raw `coordinate(withNormalizedOffset:).tap()` does not scroll an element into view (only `element.tap()` does, so the first tap landed under the tab bar), and `XCUIKeyboardKey.delete` is a no-op when the caret sits at position 0 — which is where a centre tap lands it in a trailing-aligned 56 pt field, so the deletes did nothing and new digits were **prepended**: "10" became "101000" and clamped straight back to the value under test. `field.doubleTap()` selects the whole number and typing replaces it; the helper now also asserts the field reads what she typed *while she is still in it*, so it can no longer mis-enter a value in silence. The focus segments gained `.isSelected`/`.isButton` traits on the way — selection had been expressed in colour and background alone, which VoiceOver cannot read and no test can see. **Still owed:** `HydrationDetailSheet` (`TrackView.swift:866`) is hardcoded to `today` (line 871), so hydration cannot be corrected for a past day from that sheet — water is still editable for a past day through `LogView`, so this is a missing route, not lost data. And **no daily log can be deleted at all**: `DailyLogRepository` has no `delete()`. Both are catalogued rather than fixed, because deletion is a data-retention decision and the sheet is surface shared with Android. |
| H15 | ~~P1 iOS~~ | ~~**Six pH- and hydration-surface defects, one of them destructive**~~ | Found by walking the pH surfaces the way a user reaches them rather than the way the code is organised. One destroyed data on a single tap; one printed a safety-critical instruction pointing at a control that does not exist; one certified a false sentence as shipped copy. | ✅ **Done 14 Aug, iOS only. No schema change, no SQL, no new files.** **(1) The pH delete button sat in the Cancel slot and fired on the first tap.** `PhLogSheet`'s destructive action was a `ToolbarItem(placement: .cancellationAction)` — the top-left position every other screen in iOS gives to Cancel — and it called `onDelete` immediately with no confirmation. Opening a reading to change it and deciding against the change destroyed the reading. Moved into the scroll body, away from Save and Cancel, behind a confirmation; the toolbar slot is now an unconditional `Cancel` that only dismisses. **An `.alert`, not a `.confirmationDialog`** — the dialog silently drops a custom `.cancel` label, so `Button("Keep it", role: .cancel)` rendered as a bare "Cancel", the same word as the toolbar button she had just learned does not delete anything. Proved empirically: with the dialog presenting, the app-wide button list read `Cancel \| Save \| Delete` and contained no "Keep it". **(2) The Insights pH card carried no disclaimer.** It is the most clinical-looking surface in the app — a pH value, an `ELEVATED` badge and a GP signpost — and `PhCopy.disclaimer` appeared only twice in the codebase, both in `PhTrackerSection`. A woman who reads her pH result on Insights and never opens the pH tab saw the badge and the signpost with no small print at all. Given the same collapsible "Safety note" treatment used on the tracker, under distinct `insights.*` identifiers so the two do not collide. This is the change list's group-1 "medical disclaimer behind an info icon", on the surface that was missing it. **(3) Two pH cards told her to log a cycle day into a field that does not exist.** The copy read "log your cycle day alongside each reading"; the log sheet has a pH value, a date and a note, and no cycle-day control anywhere. The instruction was unfollowable. Rewritten to name the note field, which does exist, and **lifted into `PhCopy.cycleContextCaveat`** — the file's own doc comment says it exists so the same string cannot drift between surfaces, and this one was duplicated verbatim in two cards. The grep found **seven** occurrences, not the four assumed: the three in `LearnContent.swift` were left alone deliberately, because line 335 there ("add a note if you want") immediately precedes the instruction, so the Learn prose is truthful in context and editing it would have risked the banned-phrase guards for no gain. **(4) Past-day water is now correctable from the hydration history.** `HydrationDetailSheet` shows a seven-day strip; the tiles were inert, so seeing a wrong total on a day she knows she drank on offered nothing to do about it, and the only route was Track → that day → Edit this day, which is not where she is looking. The tiles are now buttons opening that day's `LogView`. The sheet itself stays a today editor by design — this adds the missing route rather than redesigning the sheet. This closes the first of the two items H14 left catalogued. **(5) Dead legacy copy removed, and with it a false statement the tests certified.** `PhCopy.oneTimeNotice` read "Your earlier readings are kept and marked 'urine (legacy)'" and `testCopyStringsAreVerbatim` asserted it character-for-character — but `PhRepository.displayReadings` filters `measurementType != .urine`, so iOS **hides** legacy readings entirely and marks nothing. Neither constant rendered anywhere in the app. The test was the trap: a future engineer wiring up the notice would have shipped a sentence that is false about the app's actual behaviour, with a green suite vouching for it. Both constants and their three test references deleted. Hiding rather than marking is a deliberate, documented product decision and was not reversed. **(6) The pH range selector had no readable selected state.** Which of 7d/30d/90d/all was showing was expressed in foreground colour and background fill alone — VoiceOver read four bare labels, and no test could assert which chart was on screen. Given `.isSelected`/`.isButton` traits and stable identifiers. **4 UI tests, 4 falsifications, each broken individually and re-run.** Each break failed **exactly one** test with the other three still green: restoring the one-tap delete failed only the delete test ("deleting has to ask before it destroys a reading"); dropping `.isSelected` failed only the range test; suppressing the disclaimer body failed only the Insights test; making the hydration tile inert failed only the hydration test ("a history tile has to open that day's log, not today's"). The hydration test deliberately taps the **oldest** tile (`lastSevenDays` runs today−6 → today, so index 0 is six days back) — a tile that opened today's log would satisfy a naive "the log opened" assertion while leaving the past day exactly as uncorrectable as it was. **Still owed:** **Android and iOS now disagree about the same pH history.** Android displays legacy urine readings marked "urine (legacy)" (`HomeScreen.kt:659,669`, `TrackerSummaryLogic.kt:99`, `LogDaySummary.kt:61`, `PhTrackerCard.kt:141`) and still shows a live migration notice (`PhCopy.kt` `NOTICE_TITLE`/`NOTICE_BODY`/`NOTICE_DISMISS`), while iOS hides those readings entirely — so one account shows different pH history on an iPhone than on an Android phone. Not fixed here: the resolution is either an Android change (excluded from this delivery by instruction) or reversing a deliberate iOS decision, and it needs a product ruling on which client is right. And **no daily log can be deleted** — H14's second catalogued item stands, unchanged. |
| H16 | ~~P1 iOS~~ | ~~**Four notification defects, one of which stopped the app speaking to the women who use it most**~~ | Found by auditing the notification engine end to end — planner, service and copy — rather than trusting that a green suite over eight categories meant the queue was right. Three of the four are invisible from inside a single session: they only appear across a cancel, a foreground and a night. | ✅ **Done 14 Aug, iOS only. No schema change, no SQL, no new files.** **(1) The evening check-in went silent for the woman who logged everything, and stayed silent until she happened to open the app.** `NotificationPlanner.hydration()` returned `nil` once she had both logged her day and met her water goal — correct as "nothing to say tonight", catastrophic as a queue. Requests are `UNCalendarNotificationTrigger(repeats: false)` and the queue is only ever rebuilt when the app is foregrounded, so a `nil` is not "not tonight" — it queues nothing, and nothing re-queues it until she next opens the app. She completes her day, has no particular reason to open it again that evening, and the check-in simply stops. The nudge went missing on precisely her best days, and — see the next paragraph — her queue can empty altogether. The most engaged user was the one the app went quietest on. It now returns tomorrow's invitation at `dayOffset: 1`, which is still true on the morning it lands, because she cannot log tomorrow without opening the app and opening it re-plans. **Why this reaches zero rather than merely thinning out:** the weekly nudges do not save her, because the ones still standing are the ones written for a lapse. `track()` requires `daysSinceLastLog >= trackNudgeAfterDays` and returns nil for someone who never has a gap; `ph()` goes quiet when she has logged recently; `insights()` and `learn()` are each rationed to once in seven days. So the four survivors are individually weekly at best and two of them have nothing to say to a consistent user *by design* — which means her queue can empty completely, and the emptier it gets the less likely anything brings her back to refill it. **Scope this honestly when quoting it:** the fix restores the daily rhythm, it does not make the schedule self-sustaining, and a woman who is not opening the app still runs out. **(2) Cancelling remembered fire times it had just cancelled.** Delivery cannot be observed while the app is closed, so `recordWhatHasFired()` infers it — a scheduled fire time now in the past is counted as sent. `cancelAll()` cleared the requests but left `notification_scheduled_fire` intact, so every cancelled-but-not-yet-due nudge was promoted to "sent" at the next foreground — and a slot believed to have spoken then serves out its full repeat guard in silence. That is seven days for the evergreen nudges and **fourteen for the fertile one** (`fertileRepeatGuardDays = 14`), so turning reminders off and back on in the same evening cost her a fortnight of the one nudge the change list calls critical. `cancelAll()` now clears the map; the ordering is safe because `replan()` calls `recordWhatHasFired()` *before* `cancelAll()`, so genuine fires are banked first. **(3) A fertile nudge a full week out stole tonight's check-in.** `hydrationRestDays` stood the evening check-in down on any weekday a weekly nudge lands, using the weekday as a proxy. That proxy is sound for the four evergreen nudges, which genuinely recur — but the fertile nudge is a single date, and seven days from today is *today's own weekday*, so a fertile nudge at the far edge of its horizon silenced tonight for something firing next week. Now excludes `dayOffset == 7`. **(4) The safety scans were reading copy the app never sends.** `SupplementReminder.allPossibleCopy` is the surface the banned-phrase and no-guilt scans walk, and it was built from three invented fixtures — so the scans cleared a "Magnesium" that does not ship and **never once read "Time for Folate (400–800 mcg)"**, which is what actually reaches her lock screen. An essential carries its dose inside its name, which is precisely why the fixtures missed it. Now built from `NutritionContent.supplementPlan` exactly as `all()` builds it, with the fixture retained only to reach the has-a-dose branch and carry the personalised sentences. **Investigated and deliberately not changed:** the audit also reported that a fertile nudge is lost if the app is opened after 08:00 on the day itself. It is not a defect. `fireDate` returns nil for a moment that has already passed, and the reason is written down at `NotificationService.swift:293-302`: the plan is only ever rebuilt because the app was opened, so a nudge about a window that opened this morning would be telling her something the screen in front of her is already showing. Read against the source and rejected rather than patched — the finding was right about the behaviour and wrong about it being a fault. **6 tests (5 domain, 1 app) and 4 falsifications, each break rebuilt and re-run, every one failing exactly the expected test.** Dropping the `dayOffset != 7` filter failed only `testAFertileNudgeAWeekOutDoesNotCostTonightsCheckIn` with its companion green; restoring `return nil` failed exactly the two check-in tests; shrinking `allPossibleCopy` back to one fixture failed only the coupling test, naming all four unscanned strings; removing the `scheduledFireKey` clear failed only `testCancellingForgetsTheFireTimesSoNothingCountsAsDelivered`. **One existing test was rewritten rather than obeyed** — `testEveningCheckInSaysNothingWhenTheDayIsComplete` asserted the plan was empty, which is the defect written down as a spec. Silence *tonight* was right; silence full stop was not, so it became two tests stating the new contract, with the reasoning in the doc comment. This is the opposite call to H15's citation pin, and the distinction is deliberate: a compliance guard that catches you is obeyed and the code reverted; a behavioural spec encoding harmful behaviour is rewritten. **Still owed:** the deeper limitation stands. With no `BGTaskScheduler` and no background refresh, a woman who stops opening the app still runs out of queue — the 14-day dormant hand-back can never fire. Closing that is a background-execution change, not a planner change, and is catalogued rather than attempted here. |
| H17 | ~~P1 iOS~~ | ~~**A pull could overwrite an edit she made while it was in flight**~~ | Found by auditing the owed-write sync contract across all five repositories rather than trusting that the pattern was applied uniformly. Two of the five re-read the pending flag after the fetch; two did not, and one of those loses the edit outright rather than merely reverting it on screen. | ✅ **Done 14 Aug, iOS only. No schema change, no SQL, no new files. Two lines of source.** The contract is "the local write always wins", and `refresh()` implements it by draining first, then checking `!pendingPush`, then pulling. The check was correct and it was in the wrong place: it was evaluated **before** `await backend.fetch()` and never repeated, so anything she changed during the round trip was measured against a flag read before she touched it. `apply(remote)` then wrote the server's copy over hers. **On `PreferencesRepository` this loses the change, not merely displays the old one.** `apply` runs inside `isApplyingRemote = true`, which exists to stop a pull bouncing back up as a fresh push — so the overwrite was not queued for retry, it was silently un-owed. Her theme, focus mode or push toggle reverted and nothing anywhere still knew she had asked. **On `CycleRepository` (`refresh()`, the compound `guard !pendingPush, let remote = try? await backend.fetch()`) it is milder**: `upsert`'s own `Task` had already carried the edit to the server, so only the device reverted and the next refresh healed it. Both now re-read the flag after the suspension, which is the idiom already proven in this codebase at `DailyLogRepository.swift:150` (`for (date, log) in remote where !pendingDates.contains(date)`) and in `PhSync.merge` — the two repositories that were immune, and the reason the bug was findable at all. **Window: launch and sign-in, not foreground.** `refresh()` is reached only from `AppContainer.hydrate()`; the foreground path at `GenesyxApp.swift:42-51` calls `drainPending()`, which has no pull in it. So this needed her to change a setting during the first seconds after a cold start or a sign-in — narrow, and exactly the moment a slow network makes the fetch long enough to hit. **2 app tests, falsified together and separately.** Reverting both guards fails **three** assertions across exactly the two new tests and nothing else in the 84-test file — and the third is the one worth reading: `testAPreferenceChangedDuringAPullIsNotOverwrittenByWhatComesBack` also asserts the choice reaches the server *afterwards*, and without the fix it never does. That is the `isApplyingRemote` consequence, reproduced rather than argued. Two fakes were added rather than extending `MidDrainCycleBackend`, whose name describes the drain window; these fire during the *fetch* window, and `MidFetchProfileBackend` flips `online` from inside the hook so the edit's own push fails and the flag stays genuinely owed instead of racing a `Task`. **Also audited and found sound:** all eight `drainPending` definitions are reachable from a call site — the H13 defined-but-never-called pattern is gone. ~~**Still owed:** custom supplements are outside this contract entirely~~ — **closed by H19 on 14 Aug**: they now follow the same owed-write contract, tombstones included. |

| H18 | ~~P1 iOS~~ | ~~**Four defects in the cycle calendar, the countdown, the log read-back and the setup sheet**~~ | Found by auditing the tracking and calendar surfaces against the client's group 2 rather than only against the list's own wording. Each one is a place where the app told her something the rest of the app contradicted. | ✅ **Done 14 Aug, iOS only. No schema change, no SQL, no new files.** Four fixes, each falsified separately. **(1) On a short cycle the predicted ovulation day was never drawn or named.** `CycleEngine.dayType` gives period precedence, so wherever `cycleLength - 14 ≤ periodLength` — 21/7, 22/8, 23/9 and 24/10, all selectable in the settings sheet — her peak day came back `.period` and rendered as an ordinary bleeding day. Home, Insights *and* the cycle sheet each still printed "Predicted ovulation: Day 7", so three screens named a day the calendar refused to show, on a TTC app, on the one day the client's list calls out ("a clear highlight when entering the most fertile stage"). Fixed in the view, not the engine: `dayType` is shared with Android and its precedence is deliberate. The idiom was already there — `isFertile` is derived from the window rather than from `type`, with a comment explaining this exact class of failure for the *window*; nobody had carried it one day further to the *day*. Ovulation now thickens the fertile ring where the fill cannot say it (1.5→3pt, only when not already on the solid ovulation fill) and the cell says "your predicted ovulation day" aloud. **(2) Every period countdown was one day short.** `cycleLength - dayOfCycle`: the next period starts on day 1 of the *next* cycle, which is `cycleLength + 1` from this one, so the expression needed `+ 1`. On the last day of the cycle it returned 0 — the value Home renders as "Next period: Today" and Track as "Your next period is due today", a full day early, every cycle, for everyone. `CycleEngineTests:105-106` asserted the wrong numbers, which is how a fully green suite proved nothing here; rewritten, plus a new test for day 28 specifically. **Android `CycleEngine.kt:51` and web `cycle.ts` still carry the old expression — flagged for parity, not touched.** **(3) A day whose only entry was intimacy or food groups vanished from "Your logs".** `InsightsView`'s private `isBlank` was a hand-written copy of the streak predicate that had drifted: it never gained the `foodGroups` term when H4 added one to both engines *and* to `LogHistoryCard`. So the calendar drew the dot, the day sheet named it, the streak counted it — and the one screen whose job is reading her logs back dropped the day, in the same file that already knew how to render it. Now delegates to the shared `hasAnyEntry` so it cannot drift again, plus `sexualActivity` on top as presentation only (folding it into `hasAnyEntry` would change her streak against Android's; `NotificationService` already uses this exact shape for the same reason), and the card renders an Intimacy row. **(4) "Choose a date" fabricated today.** `CycleSetup.swift` exists solely to stop a new user's last-period date being invented as "today", and `canSave` enforced it — but the empty-state button did `lastPeriod = Date()`, because showing a `DatePicker` requires handing it a date to bind to. Opening the picker and choosing a date were the same event, and the second one silently meant today, with Save enabled on the way past. Split into `CycleSetup.showsDatePicker(lastPeriod:isPicking:)`, so the picker can be on screen with nothing chosen. Because SwiftUI may not fire the binding when the already-shown day is tapped, "today" stays reachable as an explicit "My period started today" button rather than as a default. **Falsification:** reverting (2) and (4) fails exactly 4 assertions in 3 tests of 248; reverting (1) and (3) fails exactly 6 in 2 tests, and the messages reproduce the bug verbatim — `7, Period, also in your fertile window` for all four short-cycle configurations. **Not changed:** the legend still shows ovulation as a solid swatch, which on a short cycle points at a fill that appears nowhere in that month's grid. Cosmetic, and cycle-aware legend copy is a design decision, not a correction. |

| H19 | ~~P1 iOS~~ | ~~**Custom supplements never left the phone, and the free-text time could never reach Android**~~ | The last unsynced surface in the app. Everything else she records — her cycle, her logs, her pH, her preferences, her name — is written locally and then owed to the server until it lands. Custom supplements were `@AppStorage` JSON and nothing more. | ✅ **Done 14 Aug, iOS only. No schema change, no SQL — `user_supplements` and its RLS, cascade and CHECK constraints have been live since 13 Aug and Android has read and written the table since.** **(1) A reinstall lost her supplement list, and two phones on one account showed two different lists with neither device aware of the other.** The list now follows the same owed-write contract as pH: the device is the source of truth, a failed push stays queued and is retried, `refresh` MERGES rather than replaces so an empty cloud cannot wipe her, and a delete is a **tombstone** so it reaches her other devices instead of being resurrected by the next pull. **(2) The time field was free text and could never round-trip.** iOS offered a text box; Android offers four fixed options, and the server's `time_of_day` CHECK accepts only `morning`/`afternoon`/`evening`/`anytime` or null — so anything she typed was either rejected by the database or silently meaningless to her other phone. Replaced with the four shared options, decided by the client. `SupplementTime.parse` lowercases and trims, so a typed "Evening" is **recovered** rather than discarded; only genuinely unrecognisable strings become nil. **Three data-loss traps were caught before they shipped, and each is now a test.** **(a) `LocalStore` namespaces every key it writes under `genesyx.`; `@AppStorage` wrote to raw `UserDefaults.standard`.** Reading the existing list through the store would have found nothing and silently discarded every supplement on every device that had one. The unprefixed defaults are now injected explicitly, and `testTheListFromBeforeTheSyncIsAdoptedAndCarriedUp` fails with `[]` if that read is routed back through the store. **(b) A typed enum with synthesized `Codable` would have lost the whole list, not the time.** Array decoding is all-or-nothing — one stored "with breakfast" and `decodeList` returns `[]`. `CustomSupplement` decodes by hand; the falsification shows exactly that, `[]` where `["Magnesium", "Vitamin C"]` belongs. **(c) `updated_at` is nullable on purpose** — the server stamps it only on an update, so a row added on Android and never edited arrives without one. `parseISO` answers an unparseable string with `Date()`, so without the `?? createdAt` fallback that row would be dated **now**, win every merge it is part of, and overwrite what is on this phone. The falsification measured the gap at 20 hours. **The migration gets exactly one chance and is taken deliberately:** an existing local-only list is adopted as `pendingSync: true` with spaced synthetic timestamps, so it is pushed up on her next sign-in rather than replaced by an empty server; the old key is left in place rather than deleted, because it costs nothing and is the only copy if a downgrade ever happens. It is not re-read once the store holds records — otherwise deleting her last supplement would be undone at the next launch. **`product_id` and `created_at` are omitted from the upsert rather than sent as null**, which is what preserves a catalogue link Android set: Swift leaves nil optionals out of the encoded body. **`NotificationService` was rewired off raw `UserDefaults` onto the repository** and now re-plans when the list changes — the reminder hour is device-local and keyed by id, so a supplement she deleted on her Android phone would otherwise have kept its alarm here. Sign-out clears both copies. **18 domain + 12 app tests; 5 falsifications, each break rebuilt and re-run, each failing exactly its own test.** **One test premise was wrong and was corrected rather than made to pass:** the first draft asserted that a tombstone from Android beats an unpushed local record. It does not, deliberately — an unpushed change is one the server has never seen — and the state was unreachable anyway, so the test now syncs first and asserts the reachable scenario. **This batch also introduced a crash, and the UI suite catching it is the most transferable thing in this row.** Moving supplements onto a repository made `SupplementPlanSheet` depend on `@EnvironmentObject var supplements`, and `GenesyxApp.swift` injected nine repositories without it — so SwiftUI `fatalError`ed and **tapping "Review Plan" terminated the app**. All 30 new tests were green while that was true and always would have been: the domain tests never touch SwiftUI, and the app tests construct the repository themselves, which is precisely the dependency the app was failing to provide. `testEachSupplementCanBeGivenItsOwnReminderTime` failed on the first UI run, exactly as its own doc comment had predicted. Fixed by `.environmentObject(container.supplements)` in `GenesyxApp.swift:39` **and `PreviewSupport.swift:50`** — miss the second and every Nutrition `#Preview` crashes in Xcode. **Carry the rule forward: a new `@EnvironmentObject` is an edit to two files, and the 12-minute UI suite runs before a batch is called done, not after.** **Still owed:** cross-device QA on real hardware, which needs the disposable account (H8). |
| H20 | ~~P1 iOS~~ | ~~**What one account leaves behind for the next, plus three surfaces contradicting themselves**~~ | Found by auditing four areas already marked Done — onboarding, Learn, Home/cycle and the session lifecycle — on the standing rule that "Done" has repeatedly meant "the feature exists", not "it is safe to use". Twenty-one findings; six were corrections inside the client's scope guard and were fixed, thirteen are recorded below as needing a decision or a rebuild, two were rejected on inspection. | ✅ **Done 14 Aug, iOS only. No schema change, no SQL, no new files.** **(1) Focus mode survived sign-out.** Fertility Prep vs Pregnancy is a health answer about her body and it was being kept as a device preference alongside theme and push — `clearNotificationState()`'s own doc comment asserted it "belongs to the device". Nothing cleared it. The next person to sign in on that handset found Pregnancy pre-selected; for a *new* sign-up it is materially worse, because no `profiles` row exists yet, so `PreferencesRepository.refresh()` seeds one from what the device still holds and writes a stranger's pregnancy status permanently into her record. New `clearFocusMode()`, called from `clearLocalState()`, bracketed in `isApplyingRemote` — the naive `focusMode = .prep` fires `didSet` → `pushPrefs()` and would reset the **departing** user's row, destroying the answer she actually gave. Her value stays server-side and returns on her next pull. **(2) `deleteAccount()` had both halves of the handover backwards, and it is the only path that did** — `signOut()` was already right, which is what made the divergence findable. The owed rename was left set, so the next sign-in resolved a name from the only thing it still had, the email prefix, and drained *that* onto the incoming user's row over the real name she registered under. And `store.remove(forKey: identityKey)` discarded the marker `applySignIn` uses to recognise an owner change: `previous == nil` is exactly how a device that has never held a session looks, so the wipe was skipped and anything logged between the deletion and the next sign-in was filed as the new user's **and pushed to her rows**. The identity key now outlives the account deliberately, with the reasoning at the call site so it is not "tidied up" again. **(3) Home was routing around H18's fix from the other door.** `CycleSetup` exists solely to forbid inventing a new user's last-period date as today, and H18 fixed the sheet — but `HomeView` held its own `@State private var lastPeriod = Date()` and passed a fabricated `CycleSettings` in, so `initialLastPeriod` resolved to today, `canSave` was satisfied on open and the "My period started today" confirmation was hidden. Home now passes `cycle.settings` unchanged (`nil` for a new user, which is what keeps the empty state reachable) and the inline `DatePicker` is gone. `TrackView:55` and `ProfileView:79` were checked in the same pass and were already correct. **A fix to a guarded screen is not done until every caller of that screen has been read.** **(4) The Sunday nudge advertised articles the app refuses to open.** `learnCandidates()` read the raw `learnArticles` instead of `LearnLibrary.articles`, whose doc comment names this nudge as a caller that must go through the gate. Because the "new" pool is *exclusive*, the raw array meant the nudge drew **only** from the twelve date-withheld pieces — a push headed "New this week" naming an article that resolves to "That article isn't available" — and `markAnnounced` then spent the slug, so the real release day arrived with no notification and no badge. Every existing test rebuilt the candidate list from `LearnLibrary.articles` itself and so was structurally incapable of catching the one production caller that differed; `learnCandidates()` was widened from `private` to internal to open the seam. **(5) On the single day she is ovulating, the app said it had not arrived.** `.ovulatory` is entered only on `dayOfCycle == ovulationDay` and left the next day, so it is always today, never a forecast — but the sub-line read "Ovulation expected in 1–2 days" beneath its own hero "High chance of conception today", above Home's "Predicted ovulation: Day 14", while Track said "Day 14 · Predicted ovulation day". Three surfaces right, one wrong, on the one day the app exists to identify. **(6) Backing out of the readiness summary erased all five quiz answers.** SwiftUI destroys `@State` when a view leaves the hierarchy, so returning to change one answer dropped her on question 1 of 5 with everything cleared — the likeliest point of abandonment in onboarding. `QuizView` now takes `initialAnswers` from `prefs.quizAnswers` through an explicit `init` and opens on the first *unanswered* question. **4 app + 1 domain test; all falsified.** The app falsification broke all three source fixes at once and produced 18 assertion failures across exactly the 4 new tests and nothing else in the 272-test target; the domain one was broken, failed on its own message, and restored. **Thirteen findings were deliberately NOT fixed** and are listed in §11 — they are product decisions, accessibility work or personalisation engines, and the client's brief says in terms that this "is not a request to redesign or rebuild the app". |

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
| Cycle history | ⬜ No table | Design and review H3 first; do not invent/apply a table during the quick backend patch. 🔴 **This is also what blocks "count cycle edits toward the streak" (group 8), investigated 14 Aug.** `CycleSettings` is three fields — `lastPeriodDate`, `cycleLength`, `periodLength` — and `CycleSettingsRow` is the same three plus `user_id`. **There is no `updated_at`, locally or remotely, and no dated history**, so the app cannot tell an edit made today from one made in March; a streak needs a date and there is none to read. Two tempting proxies were checked and both are wrong: counting *projected* period days would award a streak to someone who has not opened the app, because those days are arithmetic derived from `lastPeriodDate` + `cycleLength` rather than logged events; counting the recorded period window is retroactive and inflates the streak for a range typed in one sitting. Unblocking needs a dated table, or at minimum an `updated_at` column, on the shared backend plus an Android migration — the same blocker as dated article reads, one row down. |
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
5. Complete H8 on disposable auth accounts. **Do not wire H12** until a cited science page
   and a framed Shettles page exist — the 14 Aug slugs are not those pages. H10 physical
   cellular QA is **DEFERRED** (no iPhone). **H11 and H22 engineering are Done.** Physical
   H22 logout/relaunch is also **DEFERRED**.

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

**Repository work — CLOSED 14 Aug 2026.** The exact applied file is now checked in verbatim at
`supabase/migrations/20260813_user_supplements_delete_backstop_and_push_default_false.sql`
(md5 `55c387ecc1fc940b892bd8bdc3e1cfb5`, 3424 bytes, mtime 13 Aug 15:35, `cmp`-identical to the
recovered original). It had never existed in git on any branch and appeared in no session
transcript; it was recovered from `~/Downloads/`, where the dashboard SQL-editor copy was saved on
the day it was applied, and copied without a byte changed. **It was not reconstructed from the
summary above** — §6A.3 step 2 forbids that, and the file itself shows why that would have been
wrong: it never retypes the function. It splices the line in with
`pg_get_functiondef -> replace -> execute` behind an anchor-count assertion, so the deployed body,
owner, ACL, `SECURITY DEFINER` and `search_path=''` survive byte-for-byte. Its pre-commit block
re-asserts all of those plus the `push_enabled` default and aborts the transaction on any
mismatch, and it refuses to apply twice (`ABORT: user_supplements already referenced`). Every
claim in the two numbered points above was checked against the recovered text and matches.
This is the shared-backend repo and the only place an executable copy belongs.
Android's `docs/migrations/2026-07-29_user_supplements.sql`
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
  waitlist cleanup failure honest before public submission. **14 Aug — partly closed, and the split
  matters.** Waitlist cleanup is now honest: a failure returns 500 instead of `{ok: true}`, and
  because it runs before the profile and auth-user steps her account survives it and the retry is
  the same call. The same change added the explicit `user_supplements` delete iOS lacked, restoring
  parity with Android's RPC backstop. **Both are repo-only until `supabase functions deploy
  delete_account` runs.** The server-side `/auth/revoke` call is **still open** and needs the Apple
  `.p8` in Supabase's secret store — a person's action, not engineering. The client-side half is
  done: `SessionRepository.handleAppleCredentialRevoked`, wired in `RootView` to
  `ASAuthorizationAppleIDProvider.credentialRevokedNotification`, ends the local session on
  revocation, guarded on how the live session was obtained so an app-wide notification cannot end an
  unrelated email session. Three tests in `SessionExpiryTests`, both behaviours falsified.
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
- **T21 · T22** (artwork, visual pass) — G4 / no design spec. *Superseded 14 Aug 2026: T21
  shipped with the eggs; T22 is Done after D1 approved the bounded warm/premium pass, the
  eight recipe photographs and the splash lockup.*
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
H3-interim · H4 · H4-log-sheet · H7-celebration · sleep-contract · H13-display-name · H14-profile-audit ·
H15-ph-surfaces · H16-notifications · H17-refresh-race · H18-calendar-truth · H19-supplement-sync ·
H20-account-handover
is **267 domain, 272 app and 66 UI tests** — 0 failures, 1 skip
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

---

## 11. H20 audit — the thirteen findings deliberately not fixed

The H20 audit produced twenty-one findings. Six were corrections and were fixed (see the H20 row in
§6A). Two were rejected on inspection. **These thirteen were left alone on purpose**, and the reason
is the client's own scope guard, quoted verbatim from the brief:

> This is a focused list of amendments to the existing app. It is not a request to redesign or
> rebuild the app. Critical corrections and broken functions should be completed first; larger new
> features can be scoped separately.

Every item below is either a product decision, an accessibility programme, or a feature that does
not exist yet. Fixing any of them inside a defect batch would have been a rebuild wearing a bug
report's clothes. They are recorded here so the decision is visible rather than quiet.

### Needs a product decision

| # | Finding | Why it is not a patch |
|---|---|---|
| 1 | **Four of the five quiz answers are stored and never read.** Only the gender-preference answer reaches a screen. Age band, time trying, cycle regularity and prior support are written to the quiz record and consumed by nothing. | The fix is not "read them" — it is deciding what the app should *do* differently for a woman who has been trying for two years versus two months. That is a personalisation engine, and it is a product design exercise before it is code. |
| 2 | ~~**"Unlock My Free Guide" unlocks nothing.**~~ **DECIDED AND IMPLEMENTED 14 Aug 2026 — see §11.1.** The decision came back from the client, the guide now exists and the button opens it. Kept in this table struck through rather than deleted, so the reason it sat here for a fortnight stays legible. |
| 3 | **The readiness summary is identical for every user.** The screen shown after the quiz renders the same copy regardless of what she answered. | Same root as #1. Making it responsive means defining the segments and writing copy for each, with the compliance guards applying to every new line. |
| 4 | **The phase-change card can never announce ovulation.** `.ovulatory` lasts exactly one day, and the card is presented on a phase *transition* checked when Home appears — so unless she opens the app on that one day, the transition is consumed silently by the next check. | Making the peak day reliably announce itself is a notification-scheduling change, not a card change, and it overlaps the fertile-window nudge that already exists. Whether she should get both, or one, is a product call. |
| 5 | **Correcting cycle settings falsely pops "Your phase just changed".** Editing her cycle length recomputes the phase, so the card fires for a transition her body did not make. | The honest fix needs the app to distinguish "her phase changed" from "our estimate of her phase changed", which is a new concept in the model and affects Android and the shared vectors. |
| 6 | **Learn's badge and Home card are frozen at launch.** Both read their state once when the view is constructed; an article that lands mid-session does not appear until relaunch. | Real, but it is a reactive-state refactor of the Learn surfaces, and the window is a single session. Recorded rather than folded into a defect batch. |
| 7 | **Notification history outlives the account.** Sign-out clears milestone flags and the read-article list, but the per-slot "last fired" record is device-local and survives — so a new user on that handset can start inside another woman's repeat guards and hear nothing for up to fourteen days. | Adjacent to the H20 fixes and arguably the same class, but the record is keyed by slot rather than by user and clearing it interacts with the H16 cancellation fix. Wanted a deliberate decision rather than a fourth edit to the same teardown in one batch. |
| 8 | **There is no identity check at launch.** `applySignIn` compares the incoming identity against the stored one, which covers sign-in. Nothing re-checks at cold start, so a session restored by the Supabase SDK is trusted to match whatever is on disk. | In practice the SDK restores the same session that was saved, so this is defence in depth rather than a live defect. Adding a launch-time comparison is a change to the app's startup contract and deserves its own review. |

### Accessibility — a programme, not a batch

| # | Finding |
|---|---|
| 9 | **Learn's intro card is unreachable by VoiceOver** — it is decorative-grouped and its text is never announced. |
| 10 | **Learn's filter chips signal selection by colour alone**, with no `.isSelected` trait, so a screen-reader user cannot tell which filter is active. |
| 11 | **`GxOptionPill` has no `.isSelected` trait** — the same defect on the onboarding quiz options, which is where a first-time user meets it. |
| 12 | **The onboarding back chevron is unlabelled**, announced only as "Button". |
| 13 | **Home's metric tiles are unlabelled to VoiceOver** — the numbers are read without the words that give them meaning. |

These five are the same finding five times: a component signals state visually and does not tell the
accessibility layer. Fixing them properly means a pass over every custom control in the app with a
consistent trait vocabulary, plus UI tests that assert the traits — not five spot edits. It is a
bounded piece of work and a good candidate for the next scoped batch, but it is **not** a correction
to a broken function, which is what the brief asks to be done first.

---

## 11.1 The free guide — decision, delivery, and what is still owed

**Status: implemented and Done (14 Aug 2026). Not App Store-ready — four content corrections plus
medical review are still owed by a person (§11.1c).**

### 11.1a The product decision, as approved

> **"Open My Free Guide" must open a bundled offline PDF immediately — without login, email,
> waiting list or Supabase — and the same guide must also be available after login under
> Learn → Guides.**

Unpacked into the eight points that were signed off:

1. The CTA reads **"Open My Free Guide"** (it read "Unlock My Free Guide").
2. Tapping it opens the bundled *7-Day Fertility Nutrition Starter Guide* immediately.
3. It works **before registration, offline, with no email, no waiting list, no authentication and
   no Supabase call**.
4. Closing the guide returns to the readiness summary.
5. **"Register / Login to continue" stays a separate action** — she is not pushed into an account
   to read what she was promised.
6. The same guide is reachable after login under **Learn → Guides**.
7. The onboarding CTA **no longer routes to `WaitlistView`**.
8. The backend waiting-list API is **not deleted** — only this CTA was disconnected.

This closes a promise the app had now broken twice: first by offering to email a guide when no code
in the repository could send mail, then by opening a waiting list that told her the guide was
"inside the app" when it was not.

### 11.1b What shipped

| Area | Change |
|---|---|
| Resource | `Genesyx_7_Day_Fertility_Nutrition_Starter_Guide.pdf` (6.3 MB) added under `App/Genesyx/Resources`, picked up by XcodeGen into Copy Bundle Resources. **Confirmed present in the built `.app`, not merely in the repository.** |
| Reader | New `FreeGuideView.swift` — a `FreeGuide` resource descriptor plus a SwiftUI-wrapped `PDFView`, presented as a sheet from both entry points so dismissing lands back where it opened by construction. |
| Onboarding | CTA relabelled and repointed at the sheet. `WaitlistView` (81 lines) deleted; the `.waitlist` step, its `AppContainer` dependency and its `joinWaitlist` call are gone. |
| Learn | A `GuideBookRow` appears when the **Guides** category is selected, opening the same reader. |
| Network | The reader implements `pdfViewWillClick(onLink:)` as a no-op, so a link embedded in the PDF **cannot silently hand the user to Safari** — which would have broken both the offline and the pre-registration promise. |

Two deliberate non-changes, both load-bearing:

- **The guide is not a `LearnArticle`.** The library is a fixed, counted, dated set with sources and
  disclaimers — `LearnContentTests` asserts `articles.count == 32`, and `LearnReadLog.markRead` runs
  on article appearance. Modelling a PDF as an article would have broken the count *and* let opening
  one PDF register as having read ten written guides. The brief explicitly forbade the latter.
- **`RemoteBackend.joinWaitlist`, `SupabaseBackend.joinWaitlist`, the `join_waitlist` RPC and the
  `waitlist_emails` table are untouched.** Requirement 8 said do not delete without proving there is
  no other consumer; Android shares this backend and that proof was not attempted. Only the iOS UI
  was disconnected.

### 11.1c The four content corrections still owed — a person's job, not a code fix

The PDF is a **temporary integration asset**. It is wired in correctly and it renders, but it is
**not fit to ship** until these are supplied. None can be fixed from the app side.

| # | Correction | Why it blocks release |
|---|---|---|
| 1 | **Filename and internal PDF metadata must read "7-Day Fertility Nutrition Starter Guide."** | The file was supplied as a recipe book. The app promises a named deliverable; a user who shares or saves the file gets a different title from the one she was shown. |
| 2 | **Page 20 typo — "Download out free app" → "our".** | A spelling error on the call-to-action page of the first thing a new user is given. |
| 3 | **Page 20's QR code / app-download call-to-action must be removed or rewritten.** | It tells a reader who is *already inside the app* to go and download the app. In-app it is nonsense, and the QR route is exactly the silent exit to Safari the reader now blocks. |
| 4 | **The PDF must be accessibility-tagged, or the app must carry an accessible text equivalent.** | VoiceOver currently lands on an untagged document. The reader names it so the user is not stranded on an unlabelled view, but a label is not a text equivalent, and shipping an inaccessible core deliverable is an App Store and equality-of-access risk. |

**Plus, separately tracked: medical and content-source review of the guide has not been done.** Every
other piece of shipping content in this app carries a citation, a disclaimer and a sign-off — that
is the compliance model the banned-phrase guards enforce. This PDF entered through a different door
and has had none of it. It must be read against the same guardrails (§0, *Medical and compliance
guardrails*) before public release.

### 11.1d Verification status — honest

Re-verified 14 Aug 2026 against the release commit `8580dd6`.
Fresh backup `/tmp/onb_h21_prod_20260814T104552.swift`. `WaitlistView` was not reconstructed.

| Check | Result |
|---|---|
| Production route | ✅ `OnboardingFlowView.swift` is 342 lines, **zero** matches for `waitlist` / `joinWaitlist`, `Step` has no `.waitlist` case, and the CTA "Open My Free Guide" calls `onOpenGuide` → `showGuide = true` → `.sheet { FreeGuideScreen() }` |
| Falsification | ✅ One-line no-op `onOpenGuide: { }`. Exit 65. `GenesyxUITests.swift:130` `XCTAssertTrue failed - the bundled PDF should render — a blank reader means it is not in the app bundle` (28.044 s). Restored from the fresh backup; `cmp` byte-identical (`md5 b85686926825890766d64990ae2f747e`). |
| `build-for-testing` after restore | ✅ `** TEST BUILD SUCCEEDED **` |
| Guide UI tests after restore | ✅ **2 executed / 0 failures**, 32.091 s — onboarding 20.740 s, Learn 11.351 s · `** TEST SUCCEEDED **` |
| `FreeGuideBundleTests` (app target) | ✅ **3 executed / 0 failures**, 0.003 s |
| PDF present **inside the built `.app`** | ✅ 6,568,029 bytes, md5 `618149b77247080cc9061f971886d379` — **byte-identical to the repository copy** |
| Domain (`swift test`) | ✅ 267 passed / 0 failed (prior session this day) |
| App suite in full (`-only-testing:GenesyxAppTests`) | ✅ 275 passed / 0 failed (prior session this day; was 272; +3 bundle tests) |
| Full UI suite | ✅ **67 executed, 1 skipped, 0 failures**, 785.545 s · `** TEST SUCCEEDED **` (`/tmp/genesyx_h21_full_ui.log`). |

§11.1c's four PDF content blockers and the medical review **remain open**. This item is Done as an
engineering delivery, not as an App Store asset.

