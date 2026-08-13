# Genesyx iOS — Session Handoff

> Written 2026-08-11, reconstructed from the 2026-08-10 session (which ended on token exhaustion
> before this could be saved). Companion to `CHANGE_LIST_PLAN.md`, which tracks the client's
> change list task-by-task. This file tracks **what is in flight right now**.

**Branch:** `main` · **HEAD:** `b1ab67b` (plus the uncommitted T24 working tree, §4e) · **Version:** 1.2.0 (18)
· **Test baseline:** 239 domain + 238 app + 57 UI, 0 failures — all three verified green
2026-08-13, the UI suite in full (~9.5 min; a `TEST FAILED` inside a minute is the simulator
refusing to install the runner, not your code — see `TESTFLIGHT_B18.md` build facts)

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
| `daily_logs.sexual_activity` column | ✅ **Applied & verified 12 Aug 2026** — `information_schema.columns` returned the row. `20260810_daily_logs_sexual_activity.sql` |
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
| ✅ | Verify `daily_logs.sexual_activity` applied | — | Done 12 Aug — **pre-flight 1** in `TESTFLIGHT_B18.md` |
| — | Apply `20260811_waitlist_emails.sql` | — | Supabase SQL Editor — **pre-flight 2**. Idempotent |
| ✅ | ~~Apply `20260812_daily_logs_food_groups.sql`~~ | — | **Applied 13 Aug** (`TESTFLIGHT_B18.md` §pre-flight 3). This row said "Verified MISSING" for a day after it was live — the audit that cleared it is the authority, not this table. Both clients now read and write the column (H4) |
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
so at `scheduleSupplementReminders` (`NotificationService.swift:444`) and `checkMilestones` (`:394`).
An alarm she set herself should ring; a celebration should not wait for a budget. A third one now
looks like a gap and is not: `checkMilestones()` runs *outside* the `guard isActive` that holds back
the whole schedule. That is H7 — the in-app half of a milestone must reach the woman who declined
notifications, and she is the majority. Only the banner inside it is permission-gated. **Do not
"fix" any of these three.**

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

## 4j. A second-opinion audit, and the two things it caught that I had wrong (2026-08-13)

An external audit was run against `480bcfc`. Its headline recommendation was **"do not archive yet."**
That recommendation does not survive checking, but two of its findings do, and one of them is a
correction to me rather than to the code. Every claim below was verified against the repo or the live
site rather than taken on trust — in both directions.

**Where it was right, and I was wrong.**

- **The published privacy policy was never inaccurate.** I had reported that it claimed the app
  collects nothing, and raised a Guideline 5.1.1 blocker on that basis. Fetching
  <https://genesyx.co.uk/policies/privacy-policy> shows an accurate, current policy: **Genesyx Ltd**,
  Unit 8 Axiom, Orbital Park, Ashford, TN24 0AA; vaginal pH, cycle and daily logs all declared;
  Article 9(2)(a) explicit consent stated; Supabase, Apple, Google, Shopify and Klaviyo named;
  deletion immediate. What was stale was `docs/PRIVACY_POLICY.md`, a repo file nobody publishes. I
  read one as the other. **P0-10 is retracted**, and the invented blocker is the more instructive
  half: it would have delayed a release for a document that was already correct.
- **I then filled that file's data-controller field with `SF MEDIA & PR LTD`** — the archive's
  code-signing identity. A signing certificate is not a legal entity, and inferring one from the
  other is exactly the kind of plausible-looking guess that a "verified, not assumed" note makes
  worse rather than better. Corrected to Genesyx Ltd with the registered address.
- **App Privacy under-declared, in both places.** Neither the table in `APP_STORE_SUBMISSION.md` §2
  nor `PrivacyInfo.xcprivacy` listed **Name** or **Other User Content**, and the app collects both:
  `SupabaseBackend.swift:151` upserts the display name and `:173` shows it to a linked partner, and
  `DailyLog.swift:41` is free text. Fixed in both, archive rebuilt — the manifest is baked into the
  bundle. This is the real 5.1.1 exposure, and it is the one I missed while reporting the fake one.
- **`delete_account` never revokes the Sign in with Apple token.** Read the function end to end;
  there is no call to Apple's revocation endpoint. Also true: the `waitlist_emails` delete is
  best-effort and `{ok: true}` is returned even when it fails (`:84-108`). Both now P0-15.
- **Article 9(2)(a) is asserted publicly and evidenced nowhere.** The live policy says health data is
  processed on explicit consent. Explicit consent has to be an affirmative act you can produce later;
  onboarding has no consent statement, no tickbox and no stored timestamp. P0-13. This is a lawyer's
  call, not an engineer's — either add the step and record it, or change the lawful basis.

**Where it was wrong.**

- **"Disable Partner behind a flag or get written approval."** Partner linking is not unreleased
  work. It is **live in build 17** (`to do list.md:121`), so disabling it is a regression shipped to
  women already using it, not a deferral. The audit reached this by reading
  `CHANGE_LIST_PLAN.md:364` as an omitted requirement; that line sits under **Phase 6, quoted
  separately at 40–60d**, and it describes *partner data-sharing scopes* — a permission model that
  does not exist and was never in this build. The real open item is narrower and already recorded:
  `profiles_select` returns the whole row, so RLS is broader than the UI.
- **Stale by four commits.** It audited `480bcfc` and therefore missed the Release-build fix, the
  theme default (applied and verified `'light'::text`), the archive, and the bracket fills. Several
  of its ⬜ items were ✅ before it was written.

**What it gave us that we could not get ourselves.** The `profiles.theme` row counts — **8 dark,
8 light, 2 system**, 18 rows. That read was declined twice here, and it is the number the step-3
decision in `20260813_profiles_theme_default_light.sql` was waiting on.

**Net:** nothing blocks a TestFlight upload. P0-13 (consent) and P0-14 (declarations, now fixed)
belong to public App Store submission, and P0-13 needs a decision from someone qualified to make it.

## 4k. The pH data-loss blocker, and the edit path that never worked (2026-08-13)

An external audit against `d0b0c9f` reported one release blocker: vaginal pH readings vanish across a
cold restart. It is real, the cause is one line, and chasing it turned up a second defect the audit
had rated as working.

**The data loss.** `PhRecord.dto` did not carry `measurementType`. Every local save dropped it, every
reload decoded the row as legacy `urine` (`PersistenceDTOs.swift:81`), and `PhRepository` hides urine
(`PhRepository.swift:28`) — so her whole history disappeared, taking the calendar markers and the
logging streak with it. Introduced 22 Jul in `8053318`, present in every build since, **including 17
and 18**.

**Why 233 tests stayed green.** There were *two* `.dto` extensions on the pH types. `PhRecord.dto`
was the one the repository persists through and the one missing the field; `PhReading.dto` was
correct and **called nowhere in production**. Both DTO tests asserted against the dead one. The decoy
is deleted and the tests now go through the real path. Every other tracker had a
`...SurvivesARelaunch` test and pH did not — that gap is what the suite was actually missing, so
`testPhReadingsSurviveARelaunch` is added and was confirmed to fail (`[]` vs `[4.2]`) before the fix.

**A repository test was not enough, so there is now a real one.** Every test that could have caught
this ran in one process; the defect only shows when a *second* process reads what the first wrote.
`testAVaginalPhReadingSurvivesKillingAndReopeningTheApp` saves a reading through the sheet, calls
`app.terminate()`, and relaunches with the new `-uiTestKeepStore YES` flag — same local-only
container, no wipe, no re-seed. It stays backend-less on purpose: a relaunch without `-uiTestSeed`
resolves the real Supabase project, and no test may point there. Reverting the one-line fix makes it
fail on "her pH history must still be there after a cold start", which is the audit's symptom
word for word. This closes the manual create → terminate → relaunch step in the §10 gate.

**Recovery — decided: no migration.** Readings that reached the server self-heal on their own:
`AppContainer.hydrate()` calls `ph.refresh()`, and `PhSync.merge` takes the server copy for anything
not locally pending, where `measurement_type` was always written correctly
(`RemoteModels.swift:100`). The residue is readings that never synced, and **that residue cannot be
resolved on the device**: builds 12 and 13 (13–22 Jul) recorded genuine urine-scale readings whose
on-disk shape is byte-identical to a post-migration vaginal one, so "absent type means vaginal" would
drag real urine numbers into her vaginal trend and push them to the backend Android reads. Left
hidden deliberately. `testLegacyUrineReadingsStayHiddenAcrossARelaunch` pins that, so the tempting
"fix" fails a test instead of corrupting data.

**Do not read the live backend's urine rows as purely legacy.** A reading created offline, then
reloaded as urine and drained, pushes `measurement_type='urine'` over a row that was vaginal. Some of
the urine rows the audit found in production are likely corrupted vaginal readings from that path.

**The second defect: editing a pH reading never worked.** `PhTrackerSection` presented the log sheet
with `.sheet(isPresented:)` alongside a separate `editing` reading. SwiftUI evaluates the sheet body
before the sibling `@State` lands, so `existing` was still nil: tapping a reading opened a **blank
new-reading sheet at 4.2 with a Cancel button instead of Delete**, and saving filed a duplicate under
a fresh UUID. So the audit's 1A.4 ("only the latest result is directly editable") was generous —
nothing was editable, and nothing was deletable. Now one `PhSheetMode?` presented with
`.sheet(item:)`, which hands the value to the body instead of racing it. Caught only because the new
UI test drove a real tap; the unit suite cannot see it.

**Also shipped — audit item 5, the pH history list.** A collapsible "Reading history (N)" on the pH
card, newest first, every row opening that reading for edit or delete. It deliberately ignores the
`7d/30d/90d` range selector, which reads as a chart control: a reading she mistyped in March has to
stay reachable without her working out that the chart's "All" tab is also what unhides it in the
list. Closes 1B.9 and the editable half of 1A.4.

## 4l. T7 — the last open half: skipping the sex-preference question (2026-08-13)

Girl / Boy / No preference / Prefer not to say shipped in an earlier batch. What did not was the part
G1 named as the only thing still open: **making that question optional**. `OnboardingFlowView` kept
Continue disabled until an option was chosen, so the question was, in practice, compulsory.

`QuizQuestion` now carries `isOptional`, true for `gender` and nothing else, and
`QuizContentTests.testOnlyTheSexPreferenceQuestionIsOptional` pins that — **Android must match**.
Optionality is scoped on purpose: the other four answers drive personalisation, and making them
skippable is a product decision nobody has taken.

**Skip stores no key at all.** That is the whole point, and it is a different thing from "Prefer not
to say", which is an answer and is recorded. `skip()` *removes* the key rather than merely declining
to write one, because she can answer, go back, and skip. It shows no "Did you know?" either — the
fact is what follows engaging with the question.

Nothing had to change on the wire. `SupabaseBackend.upsert` replaces `quiz_answers.answers`
wholesale, so a key dropped locally is dropped remotely on the next push. Its `QuizAnswersRow`
init? — nil for an empty dict, so a reinstalled phone cannot erase what she said before — still
holds, and still should: skipping one of five leaves four, so the row is never empty by this route.

**The editor half.** `TrackingPreferencesSheet` had no way to un-pick an answer, which would have
made the first tap in Profile a one-way door back into a permanently answered question. Tapping the
chosen option again now clears it — **only where the question is optional**; a second tap on a
required answer is not an escape hatch, and a UI test asserts both.

## 4m. H3, the half that needs no schema: the card stopped claiming regularity (2026-08-13)

H3 in `CHANGE_LIST_PLAN.md` §6A is a cross-platform modelling job — period events, tombstones,
offline conflict rules, a migration on both clients — and none of that is done. But it carried one
instruction that needs no table and no agreement: **"Until then rename the card to 'Current cycle
length.'"**

The Insights card was titled "Cycle regularity" and its empty state read "Log your last period to
see cycle regularity." Regularity is a property of several *completed* cycles. The app stores one
`cycle_settings` row — a number she typed during setup — so the card was naming a measurement that
had never been taken. Everything under the title was already honest: the "Current setup" scope
badge, "Your cycle: {n} days", and an insight sentence that only ever says where her configured
length sits in the 21–35 range. The title was the single dishonest element, which is why this is a
copy change and not a logic change.

`GenesyxUITests.testInsightsReportsCycleLengthWithoutClaimingRegularity` asserts the new title, the
seeded length, and that **no** static text on Insights contains "regularity". The last of those is
the part that matters: it is a claim guard, not a string check, so re-adding the word anywhere on
that screen fails the suite. It matches on "regularity" and not "regular" on purpose — the
phase-nutrition copy says "regular meals", which is a different word doing honest work.

`CycleRegularityLogic` and `CycleRegularityInsights` keep their names. They are mirrored on Android,
and renaming shared symbols for a copy fix would desynchronise the two codebases for no user-visible
gain; the doc comment on the Core type now records that the card and the type deliberately disagree,
and that both should be renamed when real period events land.

## 4n. H1 and H2 applied to production, and the migration that would now revert H1 (2026-08-13)

**Production result — confirmed.** Live project `epltxklawpcxxbaleswg` received one guarded
transaction, `20260813_user_supplements_delete_backstop_and_push_default_false`, making exactly two
changes:

1. **H1** — spliced `delete from public.user_supplements where user_id = v_uid;` into the deployed
   hardened `delete_current_user()` **exactly once**, immediately before the profiles/auth deletion.
2. **H2** — changed only the `profiles.push_enabled` column **default** to `false`.

**Verification evidence, post-apply.** Function owner `postgres`, `SECURITY DEFINER`,
`search_path=''`, and EXECUTE for `postgres`/`authenticated`/`service_role` only — all preserved.
Every hardened cleanup block survived: partner unlink, owned-data deletes, email-keyed invite and
waitlist cleanup. Row counts identical before and after: **profiles = 18, user_supplements = 1,
genesyx_products = 0, ph_readings = 61**. Existing push distribution unchanged at **18 true / 0
false** — no profile row was rewritten, which was the explicit constraint on H2. The migration never
called deletion, never touched pH, and changed no RLS policy, grant or foreign key.

**The distinction to keep.** `delete_current_user()` was **redefined, not executed**. Nothing was
deleted to produce the evidence above, and nothing should be: the project holds 18 live profiles
including Apple's reviewer. So this is DDL proof, not runtime proof — **end-to-end deletion remains
unproven**. That is remaining behavioural QA, not missing implementation, and it needs two disposable
accounts before it can be claimed.

### The footgun this leaves behind

The exact applied file is not yet in `supabase/migrations/`, which `CHANGE_LIST_PLAN.md` §6A.4
already records. What it does not record is that the absence is not merely untidy.

`supabase/migrations/20260813_delete_current_user_hardening.sql` is headed **"✅ APPLIED to
production... Idempotent — re-running is safe"**, and it is a `create or replace function
public.delete_current_user()`. Its body deletes pH readings, daily logs, cycle settings, quiz
answers, invites, waitlist rows and the profile — and, by a decision documented in the file itself,
does **not** name `user_supplements`. That was correct when written: the table did not exist on the
live project, and plpgsql resolves table names at run time, so naming it would have created the
function happily and then aborted every deletion call.

H1 then spliced exactly that line into the deployed body later the same day. So the two are now out
of step in the worst direction: **re-running the checked-in file would replace production's function
with the older body and drop H1's backstop, and would report success while doing it.** That is the
same failure shape as §4i — a migration that reports success and does less than it claims.

I did not reconstruct the applied SQL. §6A.3 step 2 says to copy the exact production migration and
not to substitute a draft, and a body rebuilt from a prose summary is a draft. What I did instead is
make the file refuse to be trusted: a ⛔ banner at the top naming the superseding migration and the
project, and a correction to the "needs no line here, ever" rationale, which H1 overruled — the FK
cascade is the foreign key's promise, not this function's, and defence in depth was the point.

### Android side of the reconciliation

Android has **no `supabase/migrations/` directory and must not grow one** — its SQL records live in
`docs/migrations/`, and the backend is applied from this repo. Its one file,
`docs/migrations/2026-07-29_user_supplements.sql`, was a July draft that was never applied anywhere.
It now carries a ⛔ **SUPERSEDED — DO NOT APPLY** banner naming what actually shipped and pointing at
this repo's `supabase/migrations/`, with the original header preserved verbatim below it for audit
history. Applying it today would try to recreate live objects, and its grant shape predates the
13 Aug TRUNCATE fix (this project's default privileges hand `authenticated` the full `arwdDxtm` at
`CREATE TABLE` time, and TRUNCATE is not subject to RLS — see `TESTFLIGHT_B18.md` P1-2).

**Still owed:** the exact applied SQL for
`supabase/migrations/20260813_user_supplements_delete_backstop_and_push_default_false.sql`, which has
to come from the session that ran it — it is deliberately not reconstructed here — and the
disposable-account deletion test. Production DDL is not proof of runtime behaviour.

## 4o. H4 — meals now count, and the silent deletion Android was one save away from (2026-08-13)

`daily_logs.food_groups` had been live since 12 Aug and iOS had been writing to it, but nothing read
it back out: Insights counted supplements only, and both shared streak predicates excluded meals. A
woman could tick her food groups every day for a week and see a zero streak.

The fix had to land on both clients at once, because the streak is a shared contract computed from
shared rows. iOS: `TrackingEngine.isMeaningfulLog` and `StreakEngine.hasAnyEntry` both gained
`|| !foodGroups.isEmpty`; Track's dated summary lists "N food groups"; the My Logs day card lists
them; Nutrition Insights gained a **"Days with meals N / 7"** tile. Android got the entire read/write
half — Room v9, DTO, Supabase mapping, and the same widened `isMeaningful()`.

**Two things worth carrying forward.**

*The insight metric is deliberately not folded into the supplement bars.* `NutritionConsistencyLogic`
draws each day as `count / planSize` against her four-supplement plan. A meal-only day pushed through
that would fill a bar, and the card would then report supplements she never took. So meals get their
own tile beside the bars, not inside them. This is a product-visible choice standing in for
§6A's open "agree the insight metric" item — it can be redirected, but not by quietly summing the
two, because the copy around the bars is supplement-specific and banned-phrase guarded.

*Android's log form would have deleted iOS-written meals on every save.* `LogForm` rebuilds the whole
`DailyLog` and `viewModel.save(edited)` writes it, so a field the form does not know about is not
merely ignored — it is written back as empty. Android cannot edit food groups by design, so it now
carries `initial.foodGroups` through untouched, and `upsertPreservingWater` preserves them too in
case a sync lands mid-edit. **This was found by grepping for every site that lists all `DailyLog`
fields, not by a failing test — no test covered it, because no test knew the field existed.** Any
future field added on one client only needs the same sweep. Drop the preservation term when Android
gains a meal editor: at that point the form owns the field and must be allowed to clear it.

Two guards were falsification-tested rather than assumed. Removing `foodGroups.isNotEmpty()` from
Android's predicate makes `TrackingVectorTest` fail, so the new vectors exercise the rule instead of
restating it. And `DailyLogMigrationTest.migrate8To9_…` — which had to be added, because every prior
`daily_logs` migration has one and v9 did not — fails the moment the ALTER grows a `DEFAULT ''`,
confirming Room really does compare column defaults and that the default-less nullable column is
what makes v8→v9 open cleanly. That test ran on a real emulator (`test_Pixel8.1`, API 17 image);
**unit tests cannot catch this class of defect at all**, since Room only validates DDL when it opens
a database. The iOS vectors structurally cannot falsification-test the predicate (see §6).

All three new iOS surfaces are now covered by one UI test,
`testAMealLoggedTodayReachesTrackMyLogsAndInsights`, which cooks a recipe and then goes looking for
that meal on Track, in My Logs and on the Insights tile. Each assertion was falsification-tested by
breaking that one surface and confirming only it failed — worth knowing, because before this the
three surfaces had **zero** UI coverage and the suite was green anyway. It writes to *today* on
purpose: the Insights tile counts within the current ISO week, so seeding a past day would make a
Monday run legitimately read zero. The `insights.foodGroupDays` accessibility identifier exists so
the test reads that tile's number rather than guessing which of three "N / 7" strings it found.

**The iOS half of that gap is now closed.** `LogView` has a `foodGroupsSection` offering the same six
`FoodGroup` cases Nutrition does, so "Edit this day" can change the meals the day sheet reports, and
a meal can be recorded from the tracker rather than Nutrition only. It toggles, unlike the recipe
card's deliberately additive `logFoodGroups`: this is the day's editor, and an editor that cannot
un-tick is not an editor.

That change has a sharp edge worth understanding before touching it. `save()` now *writes*
`foodGroups` instead of carrying them through, so a stale `populate()` would delete a meal logged in
Nutrition earlier the same day — the identical bug already found and fixed on Android's log form. It
is safe only because `populate()` snapshots the stored day on appear. `testSavingTheLogSheetKeeps
AMealLoggedFromNutrition` is the guard: it cooks a recipe, saves an unrelated field from the sheet,
and asserts both that the save landed *and* that the meal survived it. Removing the `populate()` read
makes it fail with `Logged: 0.8 L water, pH test, intimacy.` — the intimacy save landed and took the
meal with it, exactly as predicted. `testTheLogSheetCanRecordAndClearAMeal` covers the round trip
including un-ticking, and fails if the `save()` write is removed.

Green at 236 domain / 238 app / 55 UI / 380 Android unit / 3 Android instrumented migration tests —
*where H4 left it*. H7 later the same day added two domain, two UI and one Android test; the current
baseline is at the top of this file.

**Still owed:** the same control on Android, where there is still no way to record a meal at all —
it reads and syncs them only. Also owed: offline/relaunch/sync QA on both devices.

## 4p. H7 — the celebration that only reached the people who least needed it (2026-08-13)

The plan called this "no obvious in-app celebration", a polish gap. It was not. `fireDueMilestones()`
was called from exactly one place, `replan()`, and `replan()` opens with `guard isActive else
{ return }`. So the entire milestone feature — every one of the four — existed only for users who had
granted notification permission. Everyone who tapped *Don't Allow* could log for a fortnight and the
app would never once say well done. That is the common case, and it was silently the unsupported one.

`checkMilestones()` (renamed, `NotificationService.swift:394`) now runs outside that gate, from
`reconcile()` — launch and every foreground — and from the `dailyLog.$logByDate` observer. Only the
banner half inside it still checks `isActive`. Three things about the shape are load-bearing:

- **Order.** `replan()` begins with `cancelAll()`, which removes every pending `NotificationKind`
  including the four milestone ids. A milestone scheduled *before* `replan()` would be deleted by the
  call that was meant to follow it. `replanAndCelebrate()` exists to fix that order and says so.
- **One method, not two.** `prefs.celebrate(...)` consumes the milestone list. Split the modal from
  the banner and whichever ran second finds nothing left to show.
- **`if let`, not assignment.** `celebration = state.milestones.last` writes `nil` on every later
  call, so the modal would be torn off the screen the moment she logged anything else — which is the
  moment she is most likely to. It is only ever assigned non-`nil`; dismissal clears it.

**The trigger moved, on both clients in the same sitting.** `day7`/`day14` keyed off the *hydration*
streak while Home headlines the *logging* streak. A woman who logged a meal and her symptoms every
day for two weeks watched that number climb and was congratulated for nothing, while the hydration
tile — which has its own number and its own card — quietly held the badge. Both engines now follow
the activity streak, which is what the client's 3A wording asks for. This is the cross-platform
streak contract and nothing automated detects divergence, so iOS `StreakEngine.compute` and Android
`StreakEngine.kt` were changed together; the Android copy carries a dated comment pointing back here,
its two `HomeScreen` labels no longer say "of hydration", and it gained a test that fails if the rule
drifts back (written first, watched fail, then fixed).

`MilestoneCelebrationView` lives in `GenesyxControls.swift` rather than its own file **because the
pbxproj has no `PBXFileSystemSynchronizedRootGroup`** — every source file is hand-listed, so a new
`.swift` does not compile into the target without pbxproj surgery. It reuses
`NotificationContent.milestoneTitle`/`milestoneBody` instead of writing fresh copy: the banner and
the app then cannot congratulate her for different things, and the words stay inside the reach of the
banned-phrase and no-guilt scans in `NotificationTests`. Fresh strings would be user-facing copy that
nothing walks.

**Two real defects surfaced during the work, neither of them the feature.**

*VoiceOver.* An `.accessibilityIdentifier` on the card container does not name the card. SwiftUI lets
the **outermost** one win, so it renamed the only control inside it and the whole celebration
collapsed into a single element — a button labelled "Thanks", with the words she had just earned
unreadable. Removing `.accessibilityElement(children: .contain)` did **not** fix it; only removing
the container identifier did. The container is now deliberately unidentified and the comment there
explains why, because it looks like an oversight. `milestone.dismiss` on the button is the handle.

*The UI suite.* With the celebration no longer permission-gated, the base seeded launch crosses
`week1` on most weekdays — including the day this was written (Thursday: Mon–Thu is four logged days,
exactly `defaultWeeklyMinDays`). A full-screen modal would have opened over the tab bar in every
unrelated seeded test and eaten its taps, on some weekdays and not others, and `continueAfterFailure
= false` means the first one aborts the entire run. `AppContainer.uiTestSeeded()` now pre-flags every
milestone as already celebrated *except* under `-uiTestMilestone`, on the reasoning that the seeded
woman has been here a while. This was caught by reading `weeklyStreak`, not by a red suite.

Two UI tests: `testMilestoneIsCelebratedInTheAppWithoutNotificationPermission` — running under a
simulator with no permission granted is not a limitation of that test, it *is* the test — and
`testACelebratedMilestoneDoesNotReturnOnTheNextLaunch`, a cold relaunch (`-uiTestKeepStore`) against
the same store, because a celebration is a moment and not a badge. Falsified three times, each
rebuilt and re-run: restoring `guard isActive` fails "should be celebrated in the app, permission or
not"; `.last` → `.first` fails "the biggest thing she did"; deleting `prefs.celebrate(...)` fails
"she has already been congratulated for this week".

Green at 238 domain / 238 app / 57 UI (full run, ~10.5 min) / 381 Android unit.

**Still owed:** streak *restore*, which is the other half of the H7 row and a product decision, not
an implementation one — it changes what a streak means and could become a paid entitlement. Approve
grace and allowance first; add backend state only if a restore must follow the account across
devices.

## 4q. The sleep predicate, settled (2026-08-13)

Carried as an open contract question since before this batch, and closed with the streak work
because it is the same predicate. `TrackingEngine.isMeaningfulLog` read `(sleepMinutes ?? 0) > 0`.
`StreakEngine.hasAnyEntry`, **both** Android predicates (`DailyLog.kt:57`, `LogDay.kt:17`) and this
repo's own `tracking_test_vectors.json` changelog — "sleep meaningful when != null", recorded at v2 —
all read `!= nil`. One implementation of four, disagreeing with the written spec it is tested
against.

It was reachable, not theoretical: `SleepSheet` offers `0...12` hours and `0...55` minutes, so 0h 0m
is a selectable, saveable value, and `LogView.save()` writes it straight through. A day whose only
entry was a 0h night therefore counted toward her milestones and *not* toward her Consistency streak
— two different streak numbers, from one row, on one screen-full of app.

**The two sleep editors do not agree about zero, and that is left alone deliberately.** The log
sheet persists 0 as 0. The Track tab's sleep card goes through
`DailyLogRepository.setSleep` (`:131`), which coerces any non-positive value to `nil` — there 0h 0m
plus Save means *clear*, which is coherent because that card also has its own Clear action. So the
same 0h 0m is an entry from one screen and an erasure from the other. Not touched here: this batch
settled what the predicate *means*, and reconciling the two writers is a product decision about what
the Track card's Save button does, not a contract question. Whoever takes it: making the log sheet
coerce would put iOS back out of step with Android and with the rule above, so the only safe
direction is the other one.

One display site did have to follow the predicate. `TrackView`'s day-detail summary (`:1544`) read
`if let m = log.sleepMinutes, m > 0`, so once a 0h night started counting, a day whose only entry was
one would have shown "No log for this day" underneath a streak that had just counted it. Now `!= nil`
there too, and it renders "Logged: 0.0 h sleep." The remaining `?? 0` and `> 0` reads on sleep are
charts and the weekly *average*, where excluding a zero is arithmetic rather than meaning — left as
they are.

Settled toward the three. `isMeaningfulLog` now reads `sleepMinutes != nil`. The reasoning is in the
predicate and worth keeping: **sleep is `Int?`, so the optionality already carries "she never opened
the sheet"** — which makes a stored `0` an entry she made, not an empty value. `waterMl` is
non-optional and `notes` is empty-by-content; neither can draw that distinction, so both stay
zero-means-untouched, and `testAnUntouchedDayDoesNotCount` still pins them. It is also the only
direction that can *lengthen* a streak rather than take one back from someone already holding it.

`testAnAllNighterCountsOnBothPredicates` asserts both predicates together, because widening one
alone is precisely how this divergence arrived. Written first and watched fail before the engine was
touched. No vector encodes a sleep field, so none moved; the changelog gained a v4 line recording
that the *rule* did not change, only the iOS code that had drifted from it. **Android needed no
change** — it had implemented v2 correctly all along.

## 4r. A green UI baseline that was partly luck (2026-08-13)

Found by the verification run for §4q, not by looking: `testPhNotesFieldOffersAKeyboardDismiss`
failed on a change that provably cannot reach it — the pH tab renders nothing driven by
`isMeaningfulLog`, and the seed has no 0-minute night for the widened rule to catch. The same test
had passed 20 minutes earlier. So the failure was the test, and the run before it was luck.

`Log pH` lives in the pH section *header*, at the top of the tab. Both places that reach it ran
`for _ in 0..<10 where !logPh.isHittable { app.swipeUp() }` — a loop that scrolls **away** from a
top-anchored button. It normally passed because the button is hittable on arrival and the loop never
runs. On the failing launch the first `isHittable` landed at t=6.93s, before the tab had settled,
and the ten swipes then put the header above the viewport with no way back: every later check found
it, none could hit it, 24s to fail.

Fixed by swiping **down** at both sites. Nothing in `App/Genesyx` is `.refreshable`, so a swipe at
the top rubber-bands harmlessly and buys exactly the settle time the check was missing. The three
loops that target `phHistoryToggle` / `phHistoryRow*` keep `swipeUp` — those elements really are
below the fold.

The lesson generalises past this file: **`isHittable` immediately after `launch()` is a race**, and a
scroll-until-hittable loop pointed the wrong way converts that race into a permanent failure rather
than a retry. If a UI test fails on a change that cannot reach it, suspect the harness before the
change — and do not re-run until it passes.

## 5. Still gated on the client — nothing

| Gate | Needs | Blocks |
|---|---|---|
| ~~G1 (preference half)~~ | ~~Sign-off to remove `"boy or girl"` from `QuizContentTests`~~ — resolved 12 Aug: no removal was needed. The guard bans that *phrase*; two options labelled "Girl" and "Boy" never form it, and neither carries an efficacy claim. T7's last open half — making the question skippable — shipped 13 Aug (§4l). | — |
| ~~G1 (Shettles half)~~ | ~~Sign-off to relax the Learn banned-phrase guards~~ — resolved 12 Aug: no relaxation was needed. The list bans claims, not the subject, and is drawn deliberately narrow so debunking prose passes. Shipped as week 12, revealed 2026-11-08, cited to Wilcox 1995. T29b shipped. | — |
| ~~G2~~ | ~~pH tab placement~~ — resolved 11 Aug: 7 tabs, Insights stays. The SE objection was based on the 320pt SE 1, which iOS 16 drops; 375pt leaves ~53pt a tab. T1 + T2 shipped. | — |
| ~~G3~~ | ~~Build number + screenshot for the "offline symbol"~~ — resolved 11 Aug, and the client was right. The "no such code path" reading searched for `NWPathMonitor`/`Reachability`; the badge is driven by the owed-days set in `DailyLogRepository.syncState(on:)`, which was not `@Published`. Fixed in the Phase 2 reliability batch. T9 shipped. | — |
| ~~G4~~ | ~~Original egg artwork files~~ — never actually blocked; the files had been in the catalog since 10 Jul. T21 shipped. | — |

All four gates closed without the sign-off they were assumed to need. What still needs calendar time
is not approval but a physical device: H10 in `CHANGE_LIST_PLAN.md` §6A, which a simulator cannot
stand in for.

## 6. Carried constraints — do not trip these

- **Banned-phrase guards are test-enforced**, not documentation. Seven test files assert
  user-facing copy excludes `sex selection`, `boy or girl`, `gender sway`, `alkaline diet`,
  `detox` and others; pH articles also ban `infection`, `thrush`, `candida`, `vaginosis`, `bv`.
  Changing copy can fail the build. Relaxing them is a compliance decision, never a quiet test edit.
- **`sexualActivity` is deliberately excluded** from `TrackingEngine.isMeaningfulLog` and
  `StreakEngine.hasAnyEntry`. Those predicates mirror Android's `DailyLog.isMeaningful()`. Widening
  one alone gives the two platforms different streaks for identical data. Flip it in both clients
  and both vector files in one change, or not at all. `MeaningfulLogTests` fails if someone flips it
  unilaterally. **`foodGroups` was added to all three predicates together on 13 Aug (H4)** — that is
  the worked example of doing this correctly.
- **The two `tracking_test_vectors.json` files are NOT copies of each other and never were**, despite
  both having claimed so in their own headers until 13 Aug. Each repo keeps its own vectors, in its
  own schema, covering its own metrics. What the platforms share is the **rules**, not the fixture,
  and **nothing automated notices when one repo moves a rule and the other does not**. Also note the
  iOS vectors carry a precomputed `meaningful` boolean, so they pin the streak *arithmetic* and never
  call the predicate; `MeaningfulLogTests` is what pins the predicate here. Android's vectors build a
  real `DailyLog`, so theirs do both.
- **Quiz question ids are storage keys.** Renaming one orphans every answer already given to it,
  on both clients. `QuizContentTests.testFiveQuestionsInOrder` pins them.
- **A skipped question means an absent key, never a stand-in option id.** `private` ("Prefer not to
  say") is an answer she gave; skipping is her declining to put the subject on the record at all.
  Only `gender` is skippable — widening that changes what the four remaining answers can be relied
  on to contain, on both clients. `testOnlyTheSexPreferenceQuestionIsOptional` pins the scope.
- **An absent local `measurementType` must keep decoding as `urine`.** It is genuinely ambiguous —
  builds 12–13 wrote real urine readings in the same shape as the post-migration vaginal ones — so
  defaulting it to vaginal corrupts her trend and the shared backend. Recovery comes from the server
  via `PhSync.merge`, never from a local guess. See §4k;
  `testLegacyUrineReadingsStayHiddenAcrossARelaunch` fails if someone flips it.
- **Present the pH log sheet with `.sheet(item:)`.** The `isPresented` + separate-`editing` pair
  races: the body is evaluated before the sibling state lands, which silently turns every edit into
  a duplicate new reading. `testPhHistoryListOpensAnOlderReadingForEditing` is the guard.
