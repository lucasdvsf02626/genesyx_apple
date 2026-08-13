# Genesyx iOS — Session Handoff

> Written 2026-08-11, reconstructed from the 2026-08-10 session (which ended on token exhaustion
> before this could be saved). Companion to `CHANGE_LIST_PLAN.md`, which tracks the client's
> change list task-by-task. This file tracks **what is in flight right now**.

**Branch:** `main` · **HEAD:** `b1ab67b` (plus the uncommitted T24 working tree, §4e) · **Version:** 1.2.0 (18)
· **Test baseline:** 180 domain + 202 app + 46 UI (45 + 1 skipped on a simulator that has already
answered the notification prompt) — all three verified green 2026-08-12, the UI suite in full

```bash
swift test && xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:GenesyxUITests
```
Do **not** pass `-quiet` — it has returned exit 0 with no summary and hidden a real result.

---

## 1. Shipped 2026-08-10 (committed)

| Commit | What it did |
|---|---|
| `998b5c2` | T28 second half — Learn unread badge + Home dashboard card, one shared rule |
| `24f8255` | T25 — Nutrition phase-change card linking to `eating-with-your-cycle` |
| `9d08d82` | Privacy — moved `quiz_answers` off the partner-readable `profiles` row |
| `1e6ec6f`, `e9a5518` | Security — closed the self-declared-partner exposure |
| `a61d571` | Doc note: `ProfileRow.partner_id` is write-guarded, so a future write fails loud |
| `db9cb07` | Changelog — **Sprint 1 only**, does not yet cover the privacy/security batch |

## 2. Supabase state (dashboard — leaves no trace in this repo)

This is the part git cannot tell you. Verify here before assuming.

| Change | Status |
|---|---|
| `quiz_answers` owner-only table + RLS policy | ✅ Applied & verified |
| `partner_id` UPDATE revoke (`authenticated` + `anon`) | ✅ Applied & verified — 0 pre-existing bad links found |
| `daily_logs.sexual_activity` column | ⚠️ **Unconfirmed — verify first.** Written `20260810_daily_logs_sexual_activity.sql`, never recorded as applied |
| `join_waitlist` RPC + `waitlist_emails` table | ⚠️ **Unconfirmed — verify first.** `20260811_waitlist_emails.sql`, written 11 Aug; the objects were never in this repo at all before that |
| `created_at` / `updated_at` UPDATE revoke | ⬜ Written, **held** pending web check (task 18) |
| `alter table profiles drop column quiz_answers` | ⬜ Written, **held** pending web check (task 18) — *not* on build 18, see §4 |

Both ⚠️ rows fail **silently**, which is why they are pre-flight items in `TESTFLIGHT_B18.md` rather
than something a test could catch. The decoders tolerate a missing `sexual_activity` column, so
intimacy logging would work on screen and sync nothing. The waitlist is the sharper of the two: the
client has called `join_waitlist` since the screen was wired up, but no migration in this repo ever
created it, so the schema existed only in whatever was typed into the dashboard — if it was typed at
all. The new migration is idempotent, so applying it is safe either way.

## 3. Client audits — who writes `profiles`

| Client | `partner_id` write | `quiz_answers` touch | timestamp write | Verdict |
|---|---|---|---|---|
| iOS (this repo) | No — write-guarded | No — repointed to new table | No | Clear |
| Android | No — sole caller hardcodes `null` | No — discarded after onboarding | No | Clear, latent hazard (task 24) |
| Web | Unknown | Unknown | Unknown | **Not checked — blocks 19 and 23** |

## 4. Open tasks

| # | Task | Blocked by | Where |
|---|---|---|---|
| 18 | Confirm whether a live web client writes `profiles` | — | Supabase Edge Logs → `PATCH /rest/v1/profiles`, group by user agent |
| ~~21~~ | ~~CHANGELOG entry for the privacy/security batch **+ T23**~~ | — | ✅ Done — the 1.2.0 (18) section carries both (`CHANGELOG.md` §Privacy & security, and the glass-size entry). Row was stale |
| 25 | Sync hydration display prefs (unit **and** glass size) to `profiles` | — | New — see below. One change with Android, not half of one here |
| 24 | Android: drop `partner_id` from the DTO write path | — | Android repo — harmless today only because the caller passes `null` |
| — | Verify `daily_logs.sexual_activity` applied | — | Supabase SQL Editor — **pre-flight 1** in `TESTFLIGHT_B18.md` |
| — | Apply `20260811_waitlist_emails.sql` | — | Supabase SQL Editor — **pre-flight 2**. Idempotent |
| — | Apply `20260812_daily_logs_food_groups.sql` | — | Supabase SQL Editor — **pre-flight 3**. Verified MISSING on the live project. Meal logging fails silently without it: she ticks food groups all week, watches them persist locally, and syncs none of it |
| ✅ | ~~Deploy all six Edge Functions~~ | — | **pre-flight 4 — done 13 Aug.** The deploy also turned `verify_jwt` on; see §4i |
| 19 | Supabase: revoke UPDATE on `created_at` / `updated_at` | 18 | One-liner once web is cleared; triggers unaffected |
| 22 | Ship build 18 to TestFlight | pre-flight 1–5 | Version bumped to 1.2.0 (18) and notes written — `TESTFLIGHT_B18.md`. **This said "1–3" while the table grew to five**; two of the additions are load-bearing, so do not stop at three. Then archive and upload |
| 23 | Supabase: drop `profiles.quiz_answers` | 18 | ~~Blocked on build 18 being live~~ — it never was. See below |

**Critical path:** 18 → 23, and 22 on its own. Everything else runs in parallel.

### Task 23 is not blocked by build 18 — corrected 2026-08-11

This table used to read `18, 22`, on the grounds that "build 17 users still select that column." They
do not, and the dates settle it: build 17 was cut at `6bc452d` and its TestFlight notes written at
`ddce23f`, **both on 29 July**. `quiz_answers` was first added to the client's `profiles` select at
`148e754` on **10 August** — twelve days later — and was moved off the row again at `9d08d82` the
same day. So the column was never in a shipped binary's select list; it existed only in commits that
have never been uploaded. That is the same fact the migration states in its own words: *"the column
landed today and has never shipped in a TestFlight build."*

Nor does the build-18 candidate write it: `ProfilePrefsRow` (`RemoteModels.swift:202`) encodes
`id, focus_mode, theme, push_enabled` and nothing else, which `RepositoryTests.swift:580` already
asserts. Both directions are clear.

What remains is task 18 alone — a web client nobody has checked could still be selecting the column,
and that has nothing to do with which iOS build is live. Shipping 22 first was doing no work.

### Task 25 — why it exists

T23 shipped the custom glass size **device-local**, matching `hydration_unit`, which was already
device-local (read straight from `UserDefaults` at four call sites, now consolidated into
`HydrationPrefs`). Syncing the glass size on its own would be incoherent: she would arrive on a new
phone with her 300 ml glass honoured but the unit reset to millilitres, where a glass size means
nothing. So the real task is moving **both** to her `profiles` row — one migration, one coordinated
change with Android, which also closes the display-parity gap T23 opens (iOS can now describe the
same water as a different number of glasses than Android). No data divergence either way: storage
is always `waterMl`.

## 4b. Shipped 2026-08-11 — committed as `185b99e`

> Landed as one commit because the tree could not be untangled into commits that each still build:
> `mlPerUnit` became a method taking `glassMl`, so `HomeView` cannot be split from `HydrationUnit`;
> and `OnboardingFlowView` carries both the egg artwork and the waitlist wiring.

**T23 — custom glass size.** The last gate-free item on the client change list.
- `Sources/GenesyxCore/Insights/HydrationUnit.swift` — `glassRangeMl` (50–1000), `resolvedGlassMl`,
  `mlPerUnit` property → method taking `glassMl`, `HydrationFormat` threads `glassMl` throughout
- `App/Genesyx/UI/HydrationPrefs.swift` — **new**; the two keys read in one place
- `ProfileView` — glass-size field, shown only when the unit is glasses
- `HomeView` · `TrackView` · `NutritionView` — call sites updated; Home's card also moved from an
  unobserved `UserDefaults` read to `@AppStorage`, so it no longer went stale when the unit changed
- `Tests/GenesyxCoreTests/HydrationUnitTests.swift` — +5 tests (bounds, fallback, cups/ml ignore the
  setting, divide-by-zero, pre-T23 default behaviour preserved)

Adding `HydrationPrefs.swift` required `xcodegen generate`; regeneration was verified diff-clean
beforehand, and `project.yml` already pins the version keys so it cannot clobber the build number.

**T28 — the weekly Learn series.** Eleven articles released one a week, with hero art, an unread
badge, a Home card and an opt-in-gated Sunday nudge. The articles are a `let` array in the binary;
the drip is date-gated on `CalendarDate`, so no server is involved. Guarded by 11 new tests — 6 on
the drip gate, 3 on citation integrity, 1 hero-asset existence, 1 end-to-end drop.

**T21 — egg artwork.** `BrandEgg` in `GenesyxControls.swift` replaces the four `BrandOrb` stand-ins
on the onboarding splash. The blocker G4 said "request original design files from client"; the files
had been sitting in the asset catalog since 10 July with zero Swift references, so nobody was ever
waiting on anyone. Re-exported 1024px → 512px first (1.4 MB → 222 KB; 512 is exactly 1:1 for the
largest 170pt use at 3x). `BrandAssetTests` — **new file, needed `xcodegen generate`** — guards both
existence and minimum resolution, because `Image("egg_female")` renders nothing when the asset is
missing and says so nowhere.

**Waitlist.** Copy fix, backend wiring, and `supabase/migrations/20260811_waitlist_emails.sql` —
which is new not because the schema changed but because it had never been written down. RLS on with
zero policies as the lock, one `SECURITY DEFINER` RPC as the only door.

**P0-4 — `drainPending()`.** `SyncError.isTransport` → `shouldHaltDrain`, now also true for
`RemoteError.notAuthenticated`. A regression **inside this uncommitted batch, never shipped** —
build 17 stops the drain on any failure and has no `SyncError` at all. Introducing "step over a
rejected row" was right, but it also made a missing session look like a per-row rejection, so a
signed-out foreground would have walked the whole backlog one doomed call at a time instead of
stopping at the first. Full reasoning in `TESTFLIGHT_B18.md`.

**Version.** `project.yml` → 1.2.0 (18), `xcodegen generate` run. The pbxproj delta was exactly the
four version lines plus eight for `HydrationPrefs.swift` and `BrandAssetTests.swift`.

## 4c. Shipped 2026-08-11, later session — committed as `5b507a3` · `b08a9d9`

Five items, none of which needed `xcodegen generate` — every new type was added to a file the
project already knows about, deliberately, to keep the pbxproj out of the diff.

**Past-day logging and editing.** `LogView` takes a `date` (defaulting to `.today()`) instead of
hard-coding it, and the calendar's day sheet offers "Add a log" or "Edit this day" according to what
is already there. Future days keep the close-only sheet.
- `TrackView` — `showLog: Bool` → `logTarget: LogTarget?`, because a bool plus a separate "which
  date" flag can be read before it is written. The day sheet hands over **on dismiss**: SwiftUI drops
  the second sheet if it is raised while the first is still going down.
- `LogView` — titles itself with the day when it is not today. Without that, a back-filled entry
  looks identical to today's and she cannot tell which she is about to overwrite.
- +2 `RepositoryTests` (a backfill leaves today alone; a re-edit replaces rather than duplicates),
  +2 UI tests. The repository always supported this — until the sheet took a date, nothing reached it.

**T16 / T17 / T18 — the three inert Profile rows.** Each raised a paragraph of text and changed
nothing. Now: *Personal Details* (display name editable, sign-in address shown but not), *Health
Profile* (the existing `CycleSettingsSheet`), *Tracking Preferences* (the five onboarding answers,
through the existing `recordQuizAnswers` sync path). No new copy strings, so the banned-phrase guards
are untouched. **No DOB field** — see `CHANGE_LIST_PLAN.md` T18 for why. +2 UI tests, one of which
asserts the answer *persists*, since a picker that forgets on dismiss looks identical to the alert it
replaced.

**`page_background`.** One `gxPageBackground()` modifier on the seven tab-screen roots; sheets keep the
flat fill. Light mode only — the art's field matches the light background exactly, which is what
makes it read as a backdrop rather than a picture. One opacity constant is the dial.
- The asset shipped as a single 1323×2868 file **declared 1x**, i.e. a 3x export that SwiftUI would
  have laid out at three times its intended size. Re-exported at proper 1x/2x/3x.
- +2 `BrandAssetTests`. The resolution one asserts the laid-out **point** width (441), not the file's
  pixel size — that is the number SwiftUI uses and the one that catches this class of bug.

**T1 + T2 — pH becomes a tab.** Item 1 of the client's recommended order. `PhTabView` was added to
`PhTrackerSection.swift` rather than its own file, again to keep `xcodegen generate` and the pbxproj
out of the diff.

- **Seven tabs, index 2** (Home, Track, pH, Nutrition, Insights, Learn, Profile). G2 asked whether an
  SE could take a seventh; it can. The objection assumed the 320pt SE 1, which iOS 16 does not run.
  375pt is the floor, giving ~53pt a tab against ~48pt for "Nutrition". Checked on an SE (3rd gen)
  simulator, not by arithmetic alone.
- **The renumbering is the risky part, not the tab.** Three structures encode tab order with no
  runtime linkage: `MainTabView`'s raw ints, `NotificationTab`, `NotificationTarget`. Inserting at 2
  shifts all five above it in each. `NotificationTests` now asserts them **pairwise** — the previous
  `NotificationTab(rawValue:) != nil` check passes perfectly well while every nudge lands one tab off,
  which is exactly the failure an insertion causes.
- **Accepted edge:** `userInfo["tab"]` stores the raw Int, so a notification scheduled before the
  update fires into the old index and misroutes by one. Self-healing at the next replan; not worth a
  migration.
- **`guide-track-ph-in-nutrition` kept its slug** while being rewritten around the trend chart. Slugs
  are routes *and* read-history keys, and although `LearnReadLog.renamed` maps old→new,
  `LearnLibraryLog.newSlugs` does not consult it — a rename would have badged the article as new and
  pushed it in the Sunday nudge to everyone who had already read it.
- `PhSpineVariant` is gone. `.compact` existed only to hide the educational spine on Nutrition's
  version of the card; with Nutrition no longer carrying one, `.full` is unconditional.
- Copy that pointed at the old location moved with it: Home's pH card, Insights' empty state,
  Profile's Help & Support text, and three Learn CTAs (new `CtaType.openPh`).

**T29c — three how-to guides** (`guide-cycle-and-phases`, `guide-sleep-tracking`,
`guide-logging-symptoms`). The ask was seven, covering cycle, pH, nutrition, symptoms, sleep and
hydration. Four existed already — pH three times over — so three were written and the audit is the
deliverable for the rest.

- **Check every claim against the code, not against the docs.** Two errors survived a careful draft
  and died on inspection: the Insights sleep chart is the ISO week (Mon–Sun, four empty bars on a
  Wednesday), *not* the trailing seven nights the Track sparkline draws; and the symptom-pattern card
  holds back until seven **days carrying symptoms**, not seven calendar days. Both read as true.
- **`.bulletList` items do not render markdown.** `LearnViews.swift:355` is `Text(item)` with a
  `String`, and only `Text(LocalizedStringKey)` string literals parse. `**bold**` ships as asterisks.
- Adding an article moves four test invariants in `LearnContentTests`, none of which is the article
  itself: `articles.count`, both uniqueness counts, `undated.count` (16 → 19), and — if it carries a
  disclaimer — the pinned slug set. `guide-cycle-and-phases` does, so it also needed a
  `LearnSourceMap` entry; a disclaimer without sources is a claim with nothing behind it.
- The other two are `disclaimerRequired: false` on purpose: they describe what the app does and state
  no external health fact, which is the line `guide-how-the-log-works` already drew.

## 4d. Phase 3 — the calendar in both schemes (2026-08-12)

The client asked for colour-coded tracking markers and a fertile-stage highlight. The markers were
already colour-coded; what they were not was *visible*. Both the fills and the dots ran through
`tintOnWhite`, which is `.opacity()` — correct over a white card, mid-grey over `#1F1F1F`. Measured
before touching anything: day number **4.23:1** on the dark fertile fill (floor 4.5), luteal tint
**1.46:1** against its own card, dots **1.19–1.37** on the ovulation cell.

- Four adaptive fill tokens in `GenesyxColors.swift`. The light halves are the exact composites the
  old call produced, so light mode is pixel-unchanged and the approved appearance does not churn.
- A fertile ring spanning the whole window, driven by `fertileWindow.contains(dayOfCycle)` rather
  than by `dayType` — on a short cycle the window opens while she is still bleeding and `dayType`
  gives period precedence, so the fill alone erases the overlap. Concentric with today's stroke.
- Ring and dots each carry a **bright variant used on the solid ovulation cell**, in both schemes.
  Not a new rule: it is the flip the day number already makes to white. No single colour clears 3:1
  against both a white card and a `#4D4DAA` fill, so two variants is the floor, not a preference.
- The Current phase card gained a "Fertile window" badge, because it headlined "Follicular Phase"
  directly above a line saying she was in her fertile window.
- `CalendarContrastTests` (+4 app) resolves each token per trait collection and asserts the floors.
  Verified it can actually fail — forcing the floor to 99 reported dark fertile at 8.83 against
  light's 12.41, which proves the resolution is real and not silently reading light twice.

⚠️ **The one thing not fixed.** The three marker hues are near-equiluminant (1.02–1.14 between
them), so they are distinguished by hue alone. The VoiceOver cell label names each marker and the
day sheet accounts for every dot in words, so the information is never *only* in the colour — but a
sighted user with a colour-vision deficiency still cannot tell two dots apart at a glance. Fixing it
properly means shape, not colour, which is a design decision rather than a token change.

Verified on screen in both schemes; the one combination the seed cannot produce is a dot on the
ovulation cell, since ovulation is in the future and future days cannot be logged. That pair is
proven numerically only (3.34–4.29:1).

## 4e. T24 — the Nutrition text pass (2026-08-12)

The last gate-free item on the client change list. The copy ask was as small as the plan predicted —
the disclosures the client wanted hidden were already behind toggles — so the read turned up
something else instead: **the screen was gated on a cycle it mostly did not use.**

`supplementPlanCard` and `articlesSection` were both inside `if let phase` while reading no phase
data at all. Cycle setup is skippable, so skipping it removed the supplement plan, and with it every
per-supplement reminder from T30 — `SupplementPlanSheet` has no other entry point in the app. This
is the same defect as the no-cycle calendar (§4c, Sprint 2 row 20), and the hydration card two cards
below already had the right instinct: `contextLine(phase: nil)` degrades to a prompt rather than
vanishing. The phase-change card and focus foods stay gated; they genuinely need a phase.

The **"Coming soon" meal card ranked second**, above the supplement plan and hydration — and *first*
with no cycle, so a skipped setup opened Nutrition on a placeholder. Moved below both, above
articles.

**One duplicated line cut.** `HydrationInsightLogic.insightLine` appends "`N`-day streak going" at a
streak ≥3, which the card already showed in the pill top-right — the same number twice, next to a
third consistency line in `weeklyStreakLabel`. The insight sentence renders in Track's hydration
detail (`TrackView.swift:1048`), which is where this card's "Track ›" button and tap gesture already
go, so it moved one tap away rather than disappearing. `weeklyStreakLabel` **stayed** — Nutrition is
its only render site, so cutting it would have deleted a shipped line, not thinned a repeated one.

`testNutritionKeepsWhatDoesNotNeedACycle` (+1 UI) pins the ungating, and was confirmed to fail
against the old gating before being kept.

## 4f. Items 5 and 7 of the client's own running order (2026-08-12)

Two findings, one of them a correction to something this repo asserted about itself.

**Item 7 — the notification architecture does not need building; it exists.** The ask was for "a real
architecture of notification". It is already three clean layers: `NotificationPlanner` (pure, 465
lines, zero system dependencies, 54 tests), `NotificationService` (the only thing that touches
`UNUserNotificationCenter`), and observable preferences that make a toggle in Profile replan without
anyone wiring a message. Four invariants are enforced at plan time rather than checked afterwards —
no filler, one a day, never guilt, dormancy after 14 days.

A survey pass flagged two "gaps" that are neither. Supplement reminders sit outside the weekly budget
and the one-a-day rule, and milestones fire outside both as well — both are deliberate and both say
so at `NotificationService.swift:411` and `:381`. An alarm she set herself should ring; a celebration
should not wait for a budget. **Do not "fix" these.**

Where the 7/10/30-day challenge programme plugs in, when it is specified: a `Challenge` model, a
field on `NotificationSnapshot`, and a `challenge()` slot in the planner competing for the same
`weeklyBudget = 4` as pH, insights, track and learn. Nothing structural has to move.

**Item 5 — the text is not the problem; the type scale is.** Screens were measured before being
edited: three prose strings over 80 characters in Insights, one in Track, two in Home, none in Log.
The text-heavy screens the client remembers were largely thinned already. One genuine duplicate went:
the intro standfirst named cycle awareness, nutrition and insights immediately above three cards that
name the same three things with icons — and the splash had said it one screen earlier.

The real finding is underneath. **The app has no Dynamic Type support at all.** All nine names in
`Typography.swift` are `Font.system(size:)`, which is a fixed point size and takes no part in Dynamic
Type; so are ~150 further call sites that size their own text; and `dynamicTypeSize`, `@ScaledMetric`
and `relativeTo:` appear exactly zero times in the app target. Larger Text in iOS Settings changes
nothing in Genesyx. The file's own doc comment claimed the opposite — "Dynamic Type rendering remains
reliable" — and has been corrected.

This was found the hard way, and the detour is worth recording. A fix went in first for the splash
and the quiz, the only two screens that distribute themselves with flexible `Spacer()`s and so cannot
scroll when their content outgrows the screen. It was **reverted**: a UI test driving the quiz at
`UICTContentSizeCategoryAccessibilityXXXL` passed identically with and without it, on an iPhone 17 Pro
and on a created iPhone SE (3rd gen). It passed because nothing grew. The overflow it guarded against
cannot happen while type is fixed, so the guard was speculation.

Scope, if the client wants it: the 239 `.font(.gx*)` sites are cheap because they funnel through nine
constants, but `@ScaledMetric` is a view modifier rather than a `Font`, so those nine constants have
to become a modifier and every call site changes shape. The ~150 inline sizes are individual. And the
splash and the quiz then genuinely do need to scroll — that revert comes back. Estimate 1–2 days plus
a visual pass, and it is invisible at default settings by construction.

## 4g. T26 — meal logging, and the bug it uncovered (2026-08-12)

The Nutrition screen has told her what to eat this phase since the first build and never let her say
she had. Six food-group chips close that loop, in the place the "Coming soon" card used to sit.

**Groups rather than nutrients is the compliance position, not a scoping compromise.** The client
asked for "food-group *or* nutrient tracking". Nutrients need a food database — the deferred barcode
work — and turn every line on the card into a claim wanting substantiation under CAP Code 3.7. Naming
a category and listing what falls in it is a definition, so the card carries no citation, no
disclaimer and no medical sign-off, while the focus-foods card *directly above it* has all three.
The six groups are the NHS Eatwell Guide's five with fruit and vegetables split apart, because a day
with fruit and no vegetables is exactly the day worth being able to record.

`testFoodLogCopyMakesNoHealthClaim` is what holds that position over time, and it was written because
the realistic failure here is not a banned phrase — nobody will type "alkaline diet" into a food log.
It is one warm sentence added next year, "protein supports egg quality", moving the card into the
category that needs a reviewer with every other guard still green. **Proven by mutation:** that exact
sentence was planted, the pre-existing banned-phrase guard passed it (12 tests, 0 failures), and only
the new guard failed — twice, on `supports` and on `fertility`.

**⚠️ A day of only meals does not extend her streak, and that is deliberate.** `isMeaningfulLog` and
`hasAnyEntry` are the cross-platform contract driven by `tracking_test_vectors.json`; widening them
on iOS alone gives the two clients different streak numbers for identical data, with nothing anywhere
to report the divergence. This one costs something visible, and is paid until Android ships
`food_groups` and the shared vectors move in the same commit. `testStreakContractIgnoresFoodGroups`
fails if someone widens it unilaterally — also mutation-proven. `NotificationService.snapshot` folds
food groups in *separately* (iOS-only, mirrors nothing), so she is never nudged to log on a day she
logged.

**The bug found on the way is the more valuable half.** `LogView.save` rebuilt a whole fresh
`DailyLog` from its own `@State` and wrote it over the day — silently resetting every field the sheet
does not display. That was harmless for as long as the sheet was the only writer. The moment food
groups became loggable from Nutrition, saving a note would have erased what she ticked off, with no
error and no undo. It is now a read-modify-write on the stored day, which holds for every field added
after this one and not just this one. `testLoggingOneSurfaceDoesNotEraseTheOther` pins the repository
half.

**Outstanding:** `supabase/migrations/20260812_daily_logs_food_groups.sql` is **not applied**. Checked
against the live project 12 Aug — `food_groups` is absent, and `symptoms`/`supplements` are
`text[] NOT NULL DEFAULT '{}'::text[]`, so the migration's "STOP if these are jsonb" caveat is
cleared and it can go in as written. Until it does, the app works end to end and syncs this one field
into nothing, silently. Build-18 pre-flight row 3.

## 4h. T27 — recipes, and why they need no reviewer (2026-08-12)

Eight recipes, two per phase, in a horizontal row directly beneath the focus foods. Opening one gives
ingredients, a numbered method, and a button that logs the food groups it covers into the card
further down the same screen. The client asked for imagery and meals instead of ingredient names;
this is the meals half.

**The compliance argument is the whole design, so do not undo it by accident.** The focus-foods card
above carries a citation, a disclaimer and a medical reviewer because it makes claims about bodies.
The recipes carry none of the three because they make no claim at all — each one cooks a focus food
the reviewed content *already* recommends for that phase, and then says how. `Recipe.usesFocusFood`
is a foreign key, not a caption: `testEveryRecipeNamesAFocusFoodThatExistsInItsOwnPhase` fails unless
it matches a `PhaseFood.name` in the same phase byte for byte. Mutation-proven by pointing the
ovulatory salad at the period food "Iron-rich foods" — the failure names the reviewed list it was
checked against. `testRecipeCopyMakesNoHealthClaim` is the other half: the day a recipe starts saying
*why* it helps, it has begun making a new claim and needs everything `phaseFoods` has.

**No photography, deliberately.** The catalogue holds Learn heroes and brand art and nothing edible.
Shipping stock food photos as placeholder art is the Guideline 2.1 risk documented in
`docs/FIX_REPORT_2026-07-12_data_honesty.md`, so each card renders on the phase accent and
`Recipe.imageName` is a nil seam. `testNoRecipeClaimsAnImageTheAppDoesNotHave` asserts that and gets
deleted in the same commit as real assets.

**`logFoodGroups` is additive on purpose** — see the note on it in `DailyLogRepository`. Wiring the
button to `toggleFoodGroup` per group compiles, looks identical, and silently *un*-ticks groups she
logged by hand. `testARecipeCardOpensAndLogsWhatSheCooked` walks the whole path in the simulator and
was mutation-proven by making the sheet's callback a no-op: it fails on the chip count, not on
anything cosmetic.

## 4i. The backend batch — four defects that all reported success (2026-08-13)

One shape, four places: a call whose result was discarded, so the function returned `{ok:true}` for
work it had not done. None of them can be seen from the client, because the client is being told
they worked.

**`delete_account` could delete the auth user and leave the data.** Every statement discarded its
result. A table that refused to delete was stepped over, the auth user went anyway, the app got
`{ok:true}` — and the rows now belong to nobody, so nobody can retry. Guideline 5.1.1(v). Each
delete is checked now and a failure returns 500 with the auth user intact, which is what keeps the
account deletable. The auth user deliberately goes last: it is the handle everything else hangs off.
Worth knowing: `deleteAccount()` in `SupabaseBackend.swift:39` calls `signOut()` *after* the invoke,
so a 500 now correctly leaves her signed in and able to try again.

**Invites addressed to her outlived her.** Only `inviter_id` was cleaned. `invitee_email` is free
text with no FK — it has to be, an invite can go to someone with no account — so nothing cascaded
it, and `partner_invites_owner` is `using (inviter_id = auth.uid())`, so after deletion nobody could
see the row either. Matched case-insensitively now, but note the shape of it: `ilike` *narrows*, an
exact comparison *decides*. `_` and `%` are LIKE wildcards and both are legal in an address, so the
pattern over-matches — `a_b@x.com` also matches `axb@x.com` — and deleting on it alone would take a
stranger's pending invite. Verified with a runtime check on the filter, not by reading it.

**`unlink_partner` could leave him reading her profile.** Both updates fired, both results dropped;
a failure on the second returned `{ok:true}` over a half-cleared link. `profiles_select` is
`using (id = auth.uid() or id = public.current_partner_id())`, so *his* `partner_id` is what grants
him *her* row. Her UI would then show no partner and never offer the unlink again. His row is
cleared first now, so any residue lands on the side that is harmless and retryable.

**`verify_jwt` was OFF on all six, and two functions were written as though it were on.** Probed
2026-08-12 — every one answered an anonymous POST from its own catch block. `send_partner_invite` and
`revoke_partner_invite` mapped the auth throw to 500 "unhandled" on that false premise; the other
four had the mirror bug, a blanket 401 that reported a malformed body or a database outage as an
auth failure and sent the app to a sign-in screen that could not fix it. `requireUser` now throws a
`NotAuthenticated` type and nothing else does, so each catch tests for it. **Mirror this in any new
function** — `supabase/functions/README.md` now carries the rule and the reason.

**Deployed 2026-08-13, and the deploy turned `verify_jwt` ON.** There is no `supabase/config.toml`
here, so `functions deploy` takes the CLI default of `true`. That was a real choice, not an
accident: suppressing it needs `--no-verify-jwt`, and leaving the gateway open when every one of
these functions requires a signed-in user anyway had nothing to recommend it. Re-probed immediately
after — all six now return the gateway's `{"code":"UNAUTHORIZED_NO_AUTH_HEADER"}` rather than their
own `{"error":"Not authenticated"}`, which is the only way to tell the two layers apart from
outside.

This changes nothing about the code. The `NotAuthenticated` split was written to be correct either
way, and `requireUser` stays in every function — the gateway proves a JWT is well-formed, it does
not hand you a user, and one `--no-verify-jwt` on a future deploy removes it silently.

## 5. Still gated on the client — G1 alone

| Gate | Needs | Blocks |
|---|---|---|
| G1 | Written client + medical-reviewer sign-off to remove `"boy or girl"` from `QuizContentTests` | T7 (Girl/Boy quiz option) only |
| ~~G1 (Shettles half)~~ | ~~Sign-off to relax the Learn banned-phrase guards~~ — resolved 12 Aug: no relaxation was needed. The list bans claims, not the subject, and is drawn deliberately narrow so debunking prose passes. Shipped as week 12, revealed 2026-11-08, cited to Wilcox 1995. T29b shipped. | — |
| ~~G2~~ | ~~pH tab placement~~ — resolved 11 Aug: 7 tabs, Insights stays. The SE objection was based on the 320pt SE 1, which iOS 16 drops; 375pt leaves ~53pt a tab. T1 + T2 shipped. | — |
| ~~G3~~ | ~~Build number + screenshot for the "offline symbol"~~ — resolved 11 Aug, and the client was right. The "no such code path" reading searched for `NWPathMonitor`/`Reachability`; the badge is driven by the owed-days set in `DailyLogRepository.syncState(on:)`, which was not `@Published`. Fixed in the Phase 2 reliability batch. T9 shipped. | — |
| ~~G4~~ | ~~Original egg artwork files~~ — never actually blocked; the files had been in the catalog since 10 Jul. T21 shipped. | — |

AI compresses engineering days, not approval days. G1 is calendar time.

## 6. Carried constraints — do not trip these

- **Banned-phrase guards are test-enforced**, not documentation. Seven test files assert
  user-facing copy excludes `sex selection`, `boy or girl`, `gender sway`, `alkaline diet`,
  `detox` and others; pH articles also ban `infection`, `thrush`, `candida`, `vaginosis`, `bv`.
  Changing copy can fail the build. Relaxing them is a compliance decision, never a quiet test edit.
- **`sexualActivity` is deliberately excluded** from `TrackingEngine.isMeaningfulLog` and
  `StreakEngine.hasAnyEntry`. Those predicates mirror the Android client against a shared
  `tracking_test_vectors.json`. Widening one alone gives the two platforms different streaks for
  identical data. Flip it in both clients and the vectors in one change, or not at all.
  `MeaningfulLogTests` fails if someone flips it unilaterally.
- **Quiz question ids are storage keys.** Renaming one orphans every answer already given to it,
  on both clients. `QuizContentTests.testFiveQuestionsInOrder` pins them.
