# Change-list audit — 17 August 2026

**Question asked:** *"can you make sure is all working well in the app and it followed what i asked for from the list"*

**Method.** Five independent read-only audits, one per section group, each instructed to walk the surface the way a woman using the app reaches it — tap → data write → re-read → display — and to treat a passing test as a claim to be checked rather than as proof. No files were edited, no builds run, during the audit itself.

**Scope.** Sections 1A, 1B, 1C, 1D, 2A, 2B, 2C, 2D, 3A, 3B. **Section 4 is explicitly out of scope** by Lucas's instruction (partner function, Apple Health/wearables, home-screen widget, barcode/photo food logging) — to be scheduled after these changes land.

**Tree audited.** `main` @ `3a9e934`; release candidate `c9aa8ba`.

---

## 1. Headline

| Section | Rows | Done | Partial | Missing |
|---|---|---|---|---|
| 1A — Vaginal pH | 8 | 5 | 1 | 2 |
| 1B — Tracking & calendar | 9 | 4 | 5 | 0 |
| 1C / 1D / 2A | 9 | 9 | 0 | 0 |
| 2B / 2C / 2D | 12 | 8 | 4 | 0 |
| 3A / 3B | 7 | 5 | 1 | 1 (descoped D4) |
| **Total** | **45** | **31** | **11** | **3** |

**The important finding is not the three Missing rows. It is that roughly a dozen real, user-facing defects sit *inside* rows already ticked Done.** That is the same pattern the previous seven audit batches found. Two of them are release-grade.

**Refuted leads.** The standing suspicion that "no network monitoring exists" is wrong — `App/Genesyx/Data/Reachability.swift` uses `NWPathMonitor` and is injected at `GenesyxApp.swift:53`. The suspicion that a past-day edit files a duplicate row is also wrong; all four editable entry types were traced and write to the entry's own date/id.

---

## 1b. Fix status as of 17 Aug (end of day)

Every fix below was proved by falsification: the fix was removed, the new test was shown to fail with its intended message, the fix was restored.

| ID | Severity | State |
|---|---|---|
| R1 — tracker Nutrition row blind to food groups | HIGH | **Fixed** |
| R2 — supplement plan ≠ tick-list | HIGH | **Fixed** |
| R3 — password-reset `redirectTo` | HIGH | **Open — needs a live production check, not a code change** |
| R4 — pH chart domain | MEDIUM | **Fixed** |
| R5 — hardcoded water target | MEDIUM | **Divergence fixed**; the settings field is still open |
| R6 — theme migration latches per-device | MEDIUM | **Fixed** |
| R7 — phase card links to one article | MEDIUM | **Fixed** |
| R8 — peak day unnamed on short cycles | LOW-MED | **Fixed** |
| M1 / M2 / M3 | — | Open (M3 descoped) |

**Suite after the fixes:** `swift test` **293 / 0**; `GenesyxAppTests` green; the new customer walkthrough **6 / 0**; `xcodebuild build` **BUILD SUCCEEDED**.

**Full sweep over the end-of-day tree, 17 Aug 10:26–10:44 (`/tmp/fullsuite.log`, `-derivedDataPath /tmp/dd-guides`):** Core **294 / 0** · `GenesyxAppTests` **315 / 0** · `GenesyxUITests` **93 / 0** in 1,061 s. **`** TEST SUCCEEDED **`, no flakes, no retries.** This is the first full 93-test UI sweep over a single tree since `8580dd6`, which `HANDOFF.md` recorded as still owed.

**Also added:** `App/GenesyxUITests/CustomerWalkthroughUITests.swift` — the walkthrough a customer actually performs. It exists because `testTabNavigation` tapped each tab and then asserted the *tab button* still existed, which is true whether the tab rendered or not. All seven tabs are now proved to put their own screen on screen. See `docs/LAUNCH_READINESS.md`.

**Also added — in-app signposting (3B).** The app already contained ten "How X works" guides, reachable only by knowing to tap the "Guides" chip in Learn. Three routes in were added, no new content written:

- **`AppGuide`** (`LearnModels.swift`) — the index of twelve guides grouped by the tab each explains, rendered by **`HowToUseView`** and reached from a card at the top of Learn and a row in Profile → About.
- **`HowThisWorksLink`** (`LearnViews.swift`) — one reusable component, used by Home, Track, Nutrition and Insights. Written once because the deep link is two coupled statements (`pendingLearnSlug`, then `selection`) and getting only the first right leaves her on the Learn list with no explanation. pH keeps its own pre-existing link (L14).
- **`AppGuideTests`** (8 tests) and two new walkthrough tests, all falsified.

**The trap these tests exist for.** Every route resolves through `LearnLibrary.articles`, which withholds future-dated articles — so a slug can be spelled perfectly and still land her on an "unavailable" screen, or vanish from the index entirely. Nothing crashes, nothing looks broken in review, and she simply cannot get an answer. All twelve `w*` weekly articles are date-gated (23 Aug – 8 Nov 2026); the tests assert that every signposted slug is one that is published from day one.

**Plain-English product report written:** `docs/HOW_THE_APP_WORKS.md` — what each tab is for, the goal of every feature, how the parts connect, and what a real first week looks like. Written for the client to read and sign off without an engineer present.

---

## 2. Defects that should block the archive

### R1 — The tracker's Nutrition row cannot see the nutrition she logs
**Section 1B row 1, ticked Done. Severity: HIGH.**

`TrackSignalSummary.nutrition` (`App/Genesyx/UI/Track/TrackView.swift:588-597`) and `NutritionDetailView` (`:1404-1414`) count `supplements` **exclusively**. `foodGroups` — the field the tracker's own log sheet collects (`LogView.swift:290-315`), the field the Nutrition tab writes, and the field the day-detail sheet reports (`TrackView.swift:1579`) — never reaches either.

A woman ticks six food groups and no supplements, taps **Nutrition** in the tracker, and reads *"No entries yet — log today to start."*

This is the same shape as the calendar/ovulation defect already fixed: four surfaces name the data, one refuses to.

**FIXED.** `NutritionDaySignal` now owns the fill and the summary line, and both the tracker row and the detail view read supplements *and* food groups through it.

### R2 — The supplement plan and the supplement tick-list are two different lists
**Section 2B row 4, ticked Done 14 Aug. Severity: HIGH.**

`NutritionView.swift:435-439` prints "N of 4 taken today" against `NutritionContent.supplementPlan` = **Folate / Omega-3 / Vitamin D / Zinc** (`Sources/GenesyxCore/Content/NutritionContent.swift:243-248`).

The only place to tick a supplement is `LogView.swift:21`: `["Folic acid", "Vitamin D", "Iron", "Omega-3"]`.

Consequences:
- **Zinc can never be logged.** "4 of 4" is mathematically unreachable.
- **Iron, which is not in her plan, counts toward it.**
- Custom supplements added in "Review Plan" (`NutritionView.swift:758-792`, synced via `SupplementsRepository`) can be given a reminder that wakes her at 8am, but can never be recorded as taken.

The food-group card guards against exactly this by design (`NutritionView.swift:525-526`). The supplement card does not.

**FIXED.** `LogView.supplements` is now derived from `NutritionContent.supplementLogOptions`, so the tick-list is the plan. There is one list, and a test asserts it stays that way.

### R3 — "Change password" may dead-end outside the app
**Section 1B row 7. Severity: HIGH (release risk). Needs a manual check, not a code fix.**

`resetPasswordForEmail(email)` is called with **no `redirectTo`** (`SupabaseBackend.swift:50`). `RootView.onOpenURL` handles only Google OAuth and invite codes (`RootView.swift:38-43`) — there is no recovery deep-link handler and no set-new-password screen anywhere in the app.

The emailed link therefore resolves to whatever the Supabase project's **Site URL** is, which is outside this repo and cannot be verified read-only. Meanwhile the in-app copy says *"Check your inbox."*

**Action:** trigger a real password reset against the production project and follow the email. If the Site URL is not a working reset page, this row fails end-to-end for every user who forgets her password.

---

## 3. Defects worth fixing before submission

### R4 — The pH trend chart is unreadable
**Section 1A row 4. Severity: MEDIUM, highly visible.**

`PhTrackerSection.swift:315` scales the Y axis to the full loggable domain 3.8–7.0, but real readings live in 3.8–4.5. The band maths at `:327-332` therefore paints **78% of the chart amber ("elevated") and only 22% green**, and every point she logs is crushed into the bottom fifth.

A woman logging weekly for two months sees a flat line hugging the floor of a mostly-amber box — the opposite of the "read the shape, not the point" instruction the Learn guide gives her (`LearnContent.swift:509, 528`).

**Fix:** clamp the visible domain to the meaningful range (e.g. 3.8–5.2) with the 4.5 threshold at a readable position.

**FIXED.** `PhStatus.chartDomain(for:)` now returns the visible span. The floor stays at 3.8 so charts from different months are comparable; the ceiling is 5.2 — which puts the 4.5 threshold exactly on the halfway line — and opens up only if she has actually logged higher, so a genuinely high reading is never clamped flat against the top edge. Falsification reproduced the audited numbers exactly: healthy occupied **21.9%** of the height and an ordinary eight-week history spanned only 12.5% of it vertically.

### R5 — The "daily target" is not the user's
**Section 2C row 8, ticked Done. Severity: MEDIUM.**

`Sources/GenesyxCore/Tracking/TrackingEngine.swift:82` — `defaultWaterGoalMl = 2400`, a constant. No settings surface exists anywhere (`grep -i goal` across `ProfileView`/onboarding returns nothing). Every "progress towards target", the 7-day "on goal" count, the water challenge, and the goal-reached notification (`NotificationService.swift:545`) key off it.

`NutritionView.swift:13` additionally hardcodes `2400` as its own literal rather than referencing the constant — a silent divergence waiting to happen.

**Minimum fix:** make `NutritionView` reference the constant (one line, removes the divergence). **Full fix:** a goal field in Profile.

**MINIMUM FIX DONE.** `NutritionView.swift:16` now reads `TrackingEngine.defaultWaterGoalMl`. The Profile field remains open — it is a feature, not a defect.

### R6 — The light-mode migration latches per-device and survives sign-out
**Section 1D row 6. Severity: MEDIUM.**

`themeMigratedKey = "theme_default_migrated"` (`PreferencesRepository.swift:56`) is set on first run (`:203`) and is **never cleared** — grep across `App/`, `Sources/`, `Tests/` returns only those three lines. `AppContainer.clearLocalState()` (`:113-139`) clears quiz answers, focus mode and the owed profile write, but not this flag.

User A signs in, her legacy `.system` is corrected to `.light`, flag latches. She signs out. User B — a legacy account whose server row still holds `.system` — signs in on the same phone. `refresh()` pulls `.system` (`:218`), `migrateLegacySystemTheme()` returns at the guard on `:202`, and B lands in dark mode with the warm palette nowhere in sight.

**Fix:** clear the flag in `AppContainer.clearLocalState()` alongside the other sign-out clears.

**FIXED.** `PreferencesRepository.clearThemeMigrationFlag()` is called from `AppContainer.clearLocalState()` (`:131`). The regression test holds a strong reference to the container — the `onClearLocalState` hook is `[weak self]`, so a temporary container is deallocated before the hook fires and the test passes for the wrong reason. That trap cost an hour; the test carries a note about it.

### R7 — Phase card links to the same article in every phase
**Section 2D row 10, ticked Done. Severity: MEDIUM.**

`NutritionView.swift:278-289` always pushes `Self.phaseArticleSlug` (`:297`) → `eating-with-your-cycle`. The client's stated example — luteal phase and common symptoms — is not delivered; she gets the same nutrition article regardless of which phase she just entered.

**FIXED, with a caveat worth knowing.** Each phase now has its own preferred slug. But every phase-relevant article in the twelve-week series is date-gated between **23 Aug and 8 Nov 2026**, and `LearnLibrary.articleBySlug` filters through the published list — so a naive per-phase map would have shipped four links that dead-end on *"That article isn't available"* (`LearnViews.swift:559-570`; the reader degrades gracefully rather than going blank, but it is still a dead end reached from a card promising phase-specific reading). The map therefore resolves *through* the published list and falls back to the always-published `eating-with-your-cycle`, and the link is labelled with the resolved article's own title so the label can never describe a piece it no longer opens. As each article's date arrives, its phase starts pointing at it, with no code change.

### R8 — Home never names the peak day on short cycles
**Section 1B row 5, ticked Done. Severity: LOW-MEDIUM.**

`CycleContent.swift:72` gates on `phase != .ovulatory`, but on 21/7, 22/8, 23/9 and 24/10 — all selectable cycle lengths — ovulation day resolves to `.period`, so Home shows *"Fertile window is open"* and never says peak. The calendar was fixed for exactly this case (`TrackView.swift:163`); Home was not.

**FIXED.** The peak-day decision moved off `phase` and onto the day: `CyclePhaseInfo.isOvulationDay` and `.isFertileButNotPeak`. The four `CycleContent` hero functions now take `CyclePhaseInfo` rather than `(Phase, Bool)`, so a caller can no longer derive the fertile flag itself and get it wrong — Home's own `&& info.phase != .ovulatory` was half the bug. Falsification produced 16 failures across all four short cycles.

---

## 4. The three Missing rows

### M1 — 1A row 5: no explanation of pH's relevance **to fertility**
The "Why pH matters" spine copy stops at *"a signal of intimate wellbeing"* (`Sources/GenesyxCore/Ph/PhCopy.swift:33`). `grep -i fertil` over `Sources/GenesyxCore/Ph/` and `App/Genesyx/UI/Ph/` returns **nothing**.

The only fertility mention in any pH article is a negation — *"It is not a fertility score"* (`LearnContent.swift:774`) — and that article is date-gated to 30 Aug 2026 (`:786`), i.e. invisible at submission.

**This is a content authoring task, and it needs the clinical reviewer's sign-off**, because the honest scientific position (pH is a marker of the vaginal environment sperm must survive; the evidence linking it to conception outcomes is contested) is exactly the nuance the two website science pages already draft. Reuse that copy.

### M2 — 1A row 8: no website links to the science page or the Shettles page
Confirmed Missing on **both halves**. The only `genesyx.co.uk` reference in Learn is a share root (`LearnViews.swift:18`, used at `:492`). No outbound science/Shettles link exists on any pH surface. And the two target pages on the website are still placeholders — see `docs/website/WEBSITE_PLAN.md`.

**Where the link belongs:** `App/Genesyx/UI/Ph/PhTrackerSection.swift:354-356` — the "Why pH matters" spine already renders a `SourcesFooter`, so a second `Link` row needs no new layout.

**Launch-visibility trap:** the in-app Shettles article is honest and well-written (`LearnContent.swift:1077-1113`) but is date-gated to **8 Nov 2026** (`:1112`), so at launch it renders as a disabled "Arrives 8 November" row (`LearnViews.swift:247, 259, 273`) — unreadable. A launch-visible Shettles caveat needs a second home; the simplest is a new block in the ungated `guide-understanding-vaginal-ph` (`LearnContent.swift:702`).

### M3 — 3A row 4: occasional streak restore
Verified genuinely absent — no restore/freeze/repair path anywhere in `Sources/GenesyxCore/Streaks/` or `App/Genesyx`. **This is correct**: it was descoped as D4. Recorded here only so the row is not mistaken for an oversight.

---

## 5. Partial row: 1A row 6 — "supporting vaginal health" is entirely absent

*When to seek help* exists in five places (`PhCopy.swift:13, 16`; `LearnContent.swift:344, 526, 702`). *Supporting vaginal health* does not: `grep -i "douch\|unscented\|cotton\|scented\|probiotic\|soap"` finds only two mentions of douches as things that **distort a reading** (`PhCopy.swift:22`, `LearnContent.swift:697`), never as guidance. The only "support" content on the pH tab is a supplements plug (`PhCopy.swift:44`).

**Critical correction to a standing assumption:** the content guard is *not* what hollowed this row out. The banned list is `["bv","thrush","infection","candida","vaginosis", …]` (`PhContentGuardTests.swift:9`). Symptom vocabulary — discharge, odour, itching, soreness, burning — is **not banned**, and none of it appears anywhere in `LearnContent.swift`. Useful, non-diagnostic advice ("if you notice a change in discharge or smell that is new for you, a pharmacist can help") is **fully writable inside the current guard**.

Row 6's thinness is an authoring gap, not a compliance constraint. No guard needs relaxing.

**WRITTEN.** `PhCopy.spineSupportTitle` / `spineSupportBody` / `spineSupportSignpost`, rendered on the pH spine as section c2 (`PhTrackerSection.swift`, identifier `phSpine.support`). Shown unconditionally, unlike the interpretation sections — it is the one part of the spine that is useful before she has ever logged a reading. Everyday habits only (warm water, unscented products, cotton, not douching) plus a pharmacist signpost that states no appointment is needed. A test asserts it names those habits *and* that it never drifts into "treat / cure / diagnose / prescribe".

**Two things about this that matter beyond row 6:**

1. **The guard was scanning less than it appeared to.** `testPhCopyHasNoBannedClinicalOrDietTerms` held its own hand-written list of `PhCopy` constants, so every constant added after it was written was unguarded — and nothing failed to say so. It now scans `PhCopy.allSurfaces`. Falsification: inserting "infection" into the new copy is caught; under the old list it passed silently.
2. **This copy is new health-adjacent text and has not been through the reviewer.** It is standard NHS-style public guidance and sits inside the guard, but it should go to the same clinician as the PDF and the website science pages before submission.

---

## 6. Governance items — decisions only Lucas or the client can make

### G1 — Article 7 ships as week 12
**Section 3B row 7.**

The client's #7 "The Shettles Method: Theory Versus Evidence" is `id: "w12"`, `publishedAt: CalendarDate(2026, 11, 8)` (`LearnContent.swift:1078-1112`). The client's #8–#12 each moved one week **earlier** into slots w7–w11 (`LearnContent.swift:915, 946, 977, 1011, 1046`). The plan screen sorts by publish date and numbers rows by index (`LearnViews.swift:234-235`), so it will display Shettles as "Week 12".

**The test that should catch this asserts the repo's order, not the client's** — `App/GenesyxTests/LearnContentTests.swift:144-157` hard-codes the shipped sequence with Shettles last, so it is green and proves nothing about spec compliance.

Either the reorder was agreed (**get it in writing**) or five weeks of the plan are mis-scheduled.

### G2 — The release schedule is anchored to absolute dates, not install date
`publishedAt` is a hard-coded `CalendarDate` per article: 12 consecutive Sundays, 2026-08-23 → 2026-11-08, filtered by `LearnLibrary.published(asOf: .today())` (`LearnModels.swift:141-146`).

Consequences for a user installing in week 9 (≈2026-10-18): all nine due articles unlock at once on first launch; only three weekly drops remain; and because `LearnLibraryLog.newSlugs` seeds everything visible as already-known on first run (`LearnReadLog.swift:44-48`), **none of the nine are announced** by card or badge. After 2026-11-08 the "one new article each week" promise ends permanently, while the Sunday nudge keeps firing generic "A read for your week" copy (`NotificationPlanner.swift:365-367, 396-398`).

First drop is **6 days from today**. Any review slip compresses the run further. This is acknowledged in-repo at `LearnContent.swift:9-13` but has never been decided.

### G3 — Two different numbers are both labelled "streak"
Home shows `dailyLog.streak()`, which is **hydration-only** (`DailyLogRepository.swift:140-142`), rendered as a bare `"\(streak)-day streak"` (`HomeView.swift:194, 233`; repeated `TrackView.swift:458, 481, 911, 1070`). Insights' Consistency card shows `dailyLogging` under the label **"Daily streak"** (`InsightsView.swift:218`, `ConsistencyInsightLogic.swift:60`).

A woman who logs symptoms daily but no water sees "Daily streak 14 days" on Insights and no flame at all on Home. The Home eyebrow reads HYDRATION so it is defensible in context, but the two labels are not distinguishable to a user.

### G4 — 2B row 5's "replaced" is not what shipped
The eight photographed recipe cards were *added below* the text-only focus-food list, which still renders first (`NutritionView.swift:56-62`). Foods are still named as categories ("Iron-rich foods", "Leafy greens") with eggs/salmon/avocado buried in the grey expanded text (`NutritionContent.swift:130-218`).

The client asked for text-only suggestions to be **replaced**. They were supplemented. Cards and photos are real and verified (all 8 `imageName` values resolve to imagesets with 292–588 KB JPEGs and matching `Contents.json`), so this is a layout/ordering decision, not a build.

### G5 — The guard bans "vaginosis" in prose, then the pH tab displays it as a link label
`PhSpine.sourceIDs = ["vaginal-ph", "statpearls-vaginitis"]` (`PhTrackerSection.swift:347`) renders through `SourcesFooter` (`CitationLink.swift:42`) as literally **"• Bacterial vaginosis — NHS (UK)"** and "• Vaginitis (StatPearls)", directly under "Why pH matters". `PhContentGuardTests.swift:4-6` exempts source titles by design.

Net effect: the app cannot say *"if you notice unusual discharge, speak to a pharmacist"*, but it **does** show every user a clickable diagnosis name. That is the worst of both positions. Worth raising with the medical reviewer alongside the guide sign-off.

---

## 7. Lower-severity findings (recorded, not blocking)

| # | Finding | Location |
|---|---|---|
| L1 | She cannot log when her period **actually** started — `DailyLog` has no flow/period field; three of six calendar markers are pure prediction. Only recourse is rewriting `lastPeriodDate`, which retro-shifts every past month. | `DailyLog.swift:35-65` |
| L2 | Silent row drop on sync if the Postgres `daily_logs.date` column is `timestamptz` rather than `date` — `if let date = CalendarDate(iso: row.date)` with no `else` and no logging. Schema is not in the repo. **Check the column type.** | `SupabaseBackend.swift:180` |
| L3 | pH marker day is device-timezone-derived; a reading logged near midnight then viewed after travel shifts one day. Symptoms/notes/intimacy unaffected. | `TrackView.swift:33, 548` |
| L4 | Cycle-edit pencil has no accessibility label; every sibling control does. VoiceOver announces "pencil". | `TrackView.swift:91-99` |
| L5 | Custom symptom chips are not remembered — `symptomOrder` is seeded only from that day's log, so a chip created yesterday must be retyped today. | `LogView.swift:104` |
| L6 | Correcting a **past** day's water is ml-only; `WaterSheet` has no unit awareness, so a glasses user is asked for millilitres. | `LogView.swift:405-438` |
| L7 | Manual water entry is ml while the readout above it is glasses ("3 / 9.6 glasses" over an ml field). | `TrackView.swift:967-1000` |
| L8 | Sign-out during a phase transition silently eats the next phase announcement; same if the stored raw string ever fails `Phase(rawValue:)`, which suppresses the card permanently. | `AppContainer.swift:138`, `NutritionView.swift:307-310` |
| L9 | Plan subtitle asserts a routine she never set: "Folate, Omega-3, Vitamin D, and Zinc — taken with breakfast." Hardcoded; reminders default to **off**. | `NutritionView.swift:449` |
| L10 | "New this week" card and Learn tab badge can miss a drop on a merely-suspended app — `LearnProgress.arrived` is captured once per process. | `LearnReadLog.swift:78-83`, `AppContainer.swift:40` |
| L11 | Sexual activity suppresses the evening nudge but does not count toward the streak. Documented as an Android-parity contract, but user-visible. | `TrackingEngine.swift:27-31` vs `NotificationService.swift:212, 240` |
| ~~L12~~ | ~~Chart-domain comment says "3.5–7.0"; `PhStatus.min` is 3.8.~~ **CLOSED** incidentally by R4 — the comment it described no longer exists; `PhChart` now points at `PhStatus.chartDomain` instead of restating the range. | `PhTrackerSection.swift:297` |
| ~~L13~~ | ~~`ProfilePrefsRow.domain` falls back to `.system`, not `.light`, for an unrecognised theme string.~~ **FIXED** — see below. | `RemoteModels.swift:226` |
| ~~L14~~ | ~~The pH tab has no route **into** the pH Learn content. Four pH guides all link into the tracker; the tracker links nowhere back.~~ **FIXED** — see below. | `PhTrackerSection.swift:7-24, 343-394` |
| L15 | "Seek help" trigger is conjunctive — help is signposted only when readings stay high **and** she notices symptoms. A woman with symptoms but normal readings is told nothing. `PhCopy.swift:13` uses readings alone: two thresholds on two surfaces. **Partly closed** by the new 1A row 6 signpost, which triggers on *"a change in discharge, smell, or comfort that is new for you"* with no reading threshold at all — so the symptoms-but-normal-readings woman is now told something on the pH tab. `LearnContent.swift:702` is unchanged and still conjunctive. | `LearnContent.swift:702` |

**L14, FIXED — and one trap found while fixing it.** The fix is small, because the route already
exists: `HomeView.swift:395-398` opens a named article with two lines (`router.pendingLearnSlug =
slug; router.selection = 5`), consumed by `LearnLandingView`. The pH tab needs the same callback it
already has for supplements (`onOpenSupplements`, threaded `PhTrackerSection` → `PhSpine`), pointed
at Learn instead of Nutrition.

**The trap:** the obvious target is `w2` / `vaginal-ph-explained` — *"What your vaginal pH is
actually telling you"* — and it would have been a **dead link on the day of release**. Learn
resolves every deep link through `LearnLibrary.articles`, which is `published(asOf: .today())`, and
`w2` carries `publishedAt: CalendarDate(2026, 8, 30)`. Today it resolves to nil and
`ArticleDetailView` renders its `unavailable` state. The correct target is **`g10` /
`guide-understanding-vaginal-ph`** (*"Understanding your vaginal pH"*), which has no `publishedAt`
and is therefore always visible.

Worth stating plainly: nothing would have failed. The link would have compiled, the tab would have
switched, and she would have arrived at a politely empty screen — the exact failure mode that a
green suite does not catch, since no test asserted that a signpost points at something published.

**What shipped.** `PhTabView.learnArticleSlug` names the target; `onOpenLearn` is threaded
`PhTabView` → `PhTrackerSection` → `PhTrackerCard` → `PhSpine` exactly as `onOpenSupplements`
already was, and the link sits under *"Why pH matters"* — where the question it answers actually
occurs to her. `PhDetailView` (the sheet pushed from Track) gets the same route, so the dead end is
closed on both surfaces rather than only the tab.

Two tests, both falsified against the *real* trap rather than an invented one — the withheld
article was pointed at deliberately and each was proved to fail:

- `LearnContentTests.testThePhTabSignpostsAnArticleSheCanActuallyOpen` — resolves the slug through
  `articleBySlug` (published today), not the full set. Falsified: *"vaginal-ph-explained" exists but
  is not published yet — the pH tab would send her to a blank screen.*
- `CustomerWalkthroughUITests.testThePhTabCanTakeHerToTheExplainerAndNotJustPromiseIt` — scrolls to
  the link, taps it, and requires a heading from *inside* the article. Falsified: *the link must
  open the explainer itself, not the Learn list or a blank screen.* The in-article heading is
  deliberate: the article's **title** also appears in the Learn tab's list, so asserting on the
  title would pass with her merely dumped on the Learn landing page.

**A testability gap found on the way, pre-existing and left alone.** `phSpine.learn` is not
queryable by accessibility identifier from XCUITest — and neither is the long-standing
`phSpine.supplements`. Measured, not assumed: `exists=false` for both while a label query returned
two matches. So this is how these plain-styled buttons behave, not anything about the new link. Both
identifiers are dead weight for testing today. **Not changed** — it is unrelated to this release and
touching accessibility plumbing to satisfy a test is the wrong trade the week of a submission. The
test queries by label instead. Flagging it because the next person to write a pH UI test will
otherwise lose the same hour.

**L13, FIXED.** `ProfilePrefsRow.domain` decoded an unrecognised `theme` string into `.system`.
`.system` remains a perfectly valid stored choice, so this branch is only reached by a value no
build understands — but landing it on `.system` dropped her into precisely the state the theme
migration in `PreferencesRepository` (`:216-217`) exists to move people *off*, and it did so on the
sync path rather than once at migration. Now falls back to `.light`, which is what the local
default at `PreferencesRepository.swift:103` has always been. One line; no behaviour change for any
value the app recognises.

Covered by `RepositoryTests.testAnUnknownThemeFromTheServerLandsOnTheProductDefaultNotSystem`,
which builds the row **by decoding JSON** rather than by an initialiser, so it exercises the path a
real `profiles` row takes. Falsified: reverting the fallback to `.system` fails it with
*"("system") is not equal to ("light") — an unrecognised theme must not drop her into the state the
migration clears"*. The test also round-trips all three real `ThemeMode` cases, so a future change
cannot "fix" the fallback by collapsing every value onto `.light`.

**A CI hazard found by running the suite twice.** `LifecycleE2ETests.testSignOutDoesNotBlankMedicalSources`
was green all morning and then failed reliably — including in isolation, so not a flake in the
usual sense. It was **not** an app regression and not the L13 change (reverting L13 left it failing,
merely at a different line).

The cause is the **iOS save-password sheet**, which the system posts after the test's sign-in. The
test dismissed it only via a single `if !profile.isHittable` check, so a sheet that arrived *after*
that instant landed on the next row. Two different symptoms, one cause: sometimes the tap failed
outright (*"Failed to not hittable"*), sometimes it hit the sheet instead so the sources screen
never opened and the assertion below failed.

It became reproducible only once the simulator had accumulated saved credentials from repeated
runs — which is exactly the state a **CI machine reaches and a fresh laptop does not**. A guard now
dismisses the sheet before that tap; three consecutive runs pass with the credential state still
present, and removing the guard fails again. No assertion was weakened: the sheet is a system
window, not app behaviour.

**A 5× slowdown, chased and not fully explained — recorded rather than written off.** The same
suite has now run three times on the same machine:

| Run | Wall time | Result | 1-/5-min load at the time |
|---|---|---|---|
| A | 1004 s | green | — |
| B | **4925 s** | 1 failure | 9.46 / 14.44 |
| C | 996 s | green | 5.50 / 4.51 |

Run B was the outlier and it **did not reproduce**: C ran the identical suite, on a larger tree, in
essentially A's time. While B was slow I checked for a competing build — `ps` showed only my own
`xcodebuild`, so it was not another agent's test run. The load average is the only thing that moved
with it, and this machine carries hundreds of processes and a second booted simulator that this
work does not own.

What that supports honestly: the slowdown **correlates with machine contention and is not
attributable to any change in this release**. What it does not support: a claimed root cause. The
one failing test cannot explain 65 lost minutes — a failed `isHittable` burns its timeout in
seconds, not an hour. Anyone seeing a run of this shape on CI should suspect the host, not the
suite, but should confirm rather than inherit that assumption from this note.

---

## 8. Test-integrity notes

Three observations where a green test does **not** mean what its name implies:

1. **`LearnContentTests.swift:144-157`** hard-codes the *shipped* article sequence with Shettles last. It is green and proves nothing about compliance with the client's ordering (see G1).
2. **`GenesyxUITests.swift:1459-1464`** asserts tap-to-deselect on `quizOption.gender.girl`. That identifier is only produced by the **Profile → Tracking preferences** sheet (`ProfileView.swift:802`); onboarding tags every option `"quiz.option"` (`OnboardingFlowView.swift:245`) and does **not** support tap-to-deselect. The test is correct about the surface it exercises, but its name reads as onboarding coverage.
3. **No test covers the phase-card re-arm on the next phase change.** The UI tests (`GenesyxUITests.swift:600-642`) cover fresh-install silence, the article route, and dismissal persistence; only the pure `CycleEngineTests.swift:26-48` covers re-arm, and it asserts correctly.

Verified-correct tests worth trusting: `RecipeContentTests.swift:86-88` and `NutritionHydrationTests.swift:54-59` do genuinely assert that recipe images load. `QuizContentTests.swift:44-47, 52` genuinely pin the question ids and the optional flag.

---

## 9. Verified clean — things that are genuinely right

Recorded so nobody re-litigates them:

- **Sections 1C, 1D and 2A are 9/9 Done**, no defects beyond R6 and L13.
- **The `gender` answer is recorded and never read.** `grep "gender"` outside tests returns only its declaration. Nothing personalises on it, so no surface can imply influence over the baby's sex.
- **Skipping the gender question removes the key**, not a sentinel (`OnboardingFlowView.swift:219-222`; re-clear at `ProfileView.swift:783-787`).
- **No cellular restriction exists.** Zero hits for `allowsCellularAccess`, `requiredInterfaceType`, `NSAppTransportSecurity`.
- **Logs are not lost on a connection drop.** Local-first writes plus per-repo outboxes; `AppContainer.drainPending()` fans out to six repositories, with foreground and reconnect triggers.
- **Sexual activity is genuinely private.** Owner-only RLS (`20260810_daily_logs_sexual_activity.sql:16-32`), absent from all notification copy and from `PartnerRepository`.
- **`CalendarDate` is genuinely day-number keyed**, no `TimeZone`, `yyyy-MM-dd` storage. Nothing re-derives a daily-log date from a timestamp.
- **Past-day edits do not duplicate.** All four editable entry types traced; the pH duplicate bug is fixed and its cause documented at `PhTrackerSection.swift:34-37`.
- **The cycle settings sheet never fabricates a date** (`CycleSettingsSheet.swift:26, 66-73, 90`).
- **Push is genuinely opt-in.** `replan()` returns early unless `isActive` for all four terms; authorization requested only from the Profile toggle; `isOn` blocks a server-defaulted `push_enabled = true`; sign-out cancels everything including milestone ids.
- **No guilt language exists.** No "you lost your streak" phrasing anywhere; the harshest surface is the factual "Daily streak 0 days" / "Best daily streak: N days", and lapsed milestone flags clear silently.
- **Shettles framing is correct and compliant** — "theory", "has never actually been demonstrated", "No controlled evidence supports", "not been shown to exist", disclaimer required, cited to wilcox-1995.
- **Egg graphics are genuinely restored**, assets present on disk (not just referenced): `egg_female.png` 108 KB, `egg_male.png` 114 KB, `page_background@{1,2,3}x.jpg`.
- **Nothing the client excluded is being shipped.** Cycle edits and article reads are correctly *not* counted as streak triggers, per D3.

---

## 10. Recommended order of work

**Before the archive:**
1. R3 — manually verify the password-reset email lands somewhere that works. *Cannot be fixed by reading code; needs a live test.* **← still the one open blocker**
2. ~~R1 — tracker Nutrition row must read `foodGroups`.~~ **Done**
3. ~~R2 — reconcile the supplement plan with the tick-list.~~ **Done**
4. ~~R6 — clear `theme_default_migrated` on sign-out.~~ **Done**
5. ~~R5 (minimum) — `NutritionView` references the constant instead of `2400`.~~ **Done**
6. L2 — check the `daily_logs.date` column type in Supabase.

**Before the archive, content:**
7. M1 — fertility-relevance copy on the pH spine, drawn from the website science draft. Needs clinical sign-off.
8. 1A row 6 — vaginal-health support guidance. **Writable inside the current guard** — no relaxation needed.
9. M2 — website links, once the two science pages are live and signed off (`docs/website/WEBSITE_PLAN.md`).

**Client decisions, in parallel:**
10. G1 — get the article reordering confirmed in writing, or reorder.
11. G2 — decide what happens to a late installer and to the plan after 8 Nov.
12. G4 — decide whether the focus-food list should move below the recipe cards.
13. G5 — raise the citation-label question with the medical reviewer.

**Nice-to-have, not blocking:**
14. ~~R4 — chart domain clamp.~~ **Done**
15. ~~R7 — per-phase article slug.~~ **Done**
16. ~~R8 — Home peak-day copy on short cycles.~~ **Done**
17. L4 — accessibility label on the cycle pencil.

---

*Audit performed 17 Aug 2026 against `main` @ `3a9e934`. Read-only: no files were edited and no builds or tests were run during the audit.*
