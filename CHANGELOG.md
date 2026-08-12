# Changelog

All notable changes to Genesyx (iOS) are recorded here.

## 1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026)

Version 1.2.0 rather than 1.1.2: this is new surface, not a fix pass. Pre-flight checks and release
checklist in `docs/TESTFLIGHT_B18.md`; current state of play in `docs/HANDOFF.md`.

### Privacy & security
- **Quiz answers moved off the partner-readable `profiles` row** (`9d08d82`). The RLS audit that
  Sprint 1 asked for came back badly: `profiles_select` is a bare row-level clause, and Postgres RLS
  filters *rows*, never columns — so a linked partner read the whole profile row, including what she
  said about her baby's sex on a screen that promises the answer is just for her. Narrowing the
  policy cannot fix that; only moving the data can. The answers now live in their own owner-only
  table. `ProfileBackend` and the domain shape are unchanged — only the Supabase implementation
  differs, reading and writing two tables behind the same two methods. No backfill: the column
  landed the same day and has never shipped, so this is a pure move while there is nothing to move.
- **A user can no longer declare themselves someone else's partner** (`1e6ec6f`, `e9a5518`).
  `profiles_update` permitted a self-row write with no column restriction and nothing guarding
  `partner_id`, so anyone could point their own `partner_id` at any UUID and have `profiles_select`
  hand them that person's whole row — no reciprocation, and nothing the victim could observe or
  refuse. Fixed by revoking the `UPDATE` privilege on the column rather than adding a trigger: the
  service role bypasses RLS but *not* triggers, so a trigger would have raised on the Edge Functions
  that legitimately write it. Consent already exists in the right form —
  `accept_partner_invite` matches a pending invite against the caller's own email — it was just in
  the wrong place. Revoked from `anon` as well as `authenticated`, because the privilege audit found
  all four roles holding the stock full table grant.
  Held back deliberately: taking `created_at`/`updated_at` off the same grant is also right, but it
  is a second change with a different blast radius and only the iOS client is in this repo to verify
  against.
- `ProfileRow` is now documented select-only (`a61d571`). It carries `partnerId` and is `Codable`, so
  it looks upsertable; a write through it now fails with `42501`, which is a confusing error to meet
  without knowing the column is deliberately out of reach of every client role.

### Features
- **Vaginal pH is its own tab** (T1 + T2). It used to be a card most of the way down Nutrition, filed
  under supplements — which is where the client's "I can't find pH" came from, and also a category
  error: vaginal pH is not something you eat. It is now the third tab, and Nutrition opens straight
  into focus foods.
  Shipped as one change, not two: removing the card without the tab would have left pH reachable only
  from Track, strictly *less* discoverable than before.
  Seven tabs, and the SE worry that gated this (G2) did not survive measurement — iOS 16 drops the
  320pt SE 1, so the narrowest supported device is 375pt: ~53pt a tab against a ~48pt widest label.
  Verified on an SE (3rd gen) simulator, nothing truncated.
  Inserting a tab mid-order shifts every raw value above it, and three structures encode that order
  with no runtime linkage between them (`MainTabView`, `NotificationTab`, `NotificationTarget`). They
  moved together, and `NotificationTests` now compares them **pairwise**: the old
  `NotificationTab(rawValue:) != nil` check passes happily while a nudge lands one tab off. One
  accepted edge — a notification queued before the update carries the old raw `tab` and misroutes by
  one until the next replan.
  `guide-track-ph-in-nutrition` was rewritten around the trend chart, **slug intact**. A slug is a
  route and a read-history key; and while `LearnReadLog` carries a rename map, `LearnLibraryLog`
  does not, so renaming it would have re-announced a year-old article as new.
- **A Learn article a week** (T28, `185b99e`). Eleven pieces drip-released on `CalendarDate` with no
  server involved, an unread badge, a Home card and an opt-in-gated Sunday nudge. The badge reads
  zero on a first run rather than eleven.
- **Three more how-to guides** (T29a): cycle & phases, sleep, symptoms. The client asked for seven
  covering cycle, pH, nutrition, symptoms, sleep and hydration; an audit of the existing library
  found four of those already written — pH three times over (`guide-vaginal-ph-tracker`,
  `guide-how-to-log-ph`, `guide-track-ph-in-nutrition`), plus nutrition, hydration and general
  logging. Writing the other four would have been duplication filed as delivery, so only the three
  genuine gaps were written.
  Every claim was checked against the code rather than against how the feature is described
  elsewhere, which caught two: the Insights sleep chart is the ISO week Mon–Sun, not the trailing
  seven nights the Track sparkline uses (the draft conflated them), and the symptom-pattern card
  waits for seven *days carrying symptoms*, not seven calendar days. Both would have read as true.
  Only the cycle guide carries a disclaimer and a Sources footer; the other two describe what the app
  does and state no external health fact, matching the precedent set by `guide-how-the-log-works`.
  Watch for markdown here: `.bulletList` items render through `Text(String)`, which does *not* parse
  it, so `**bold**` ships as literal asterisks.
- **A glass is hers to size** (T23, `185b99e`) — 50–1,000 ml, default 250. A cup stays fixed at 240:
  that is a recipe measure, not an object she owns. Out-of-range falls back to 250 rather than
  clamping, so a corrupted store shows the familiar default and not a number she never picked.
  Storage is untouched (`DailyLog.waterMl` is always ml), so resizing re-describes her water and can
  never rewrite it. Device-local for now, deliberately: `hydration_unit` already was, and syncing one
  without the other would strand her on a new phone with a 300 ml glass and the unit reset to
  millilitres, where a glass size means nothing.
- **The real egg artwork on the splash** (T21, `185b99e`). The change list said to request the design
  files from the client; they had been in the asset catalog since 10 July with zero code references,
  so nobody was ever waiting on anyone. Re-exported 1024px → 512px (1.4 MB → 222 KB; 512 is exactly
  1:1 for the largest 170pt use at 3x). `BrandAssetTests` guards existence *and* resolution, because
  `Image("egg_female")` renders nothing when the asset is missing and says so nowhere.
- **The waitlist screen actually calls the backend** (`185b99e`), and only says "you're on the list"
  once the write returns. The old copy promised a guide "sent straight to your inbox"; nothing sent
  it. `supabase/migrations/20260811_waitlist_emails.sql` is new not because the schema changed but
  because it had never been written down — the client has called `join_waitlist` since the screen was
  wired up and no migration in this repo ever created it. RLS on with no policies as the lock, one
  `SECURITY DEFINER` function as the only door.
- **Nutrition announces a phase change** (T25, `24f8255`), linking to the cycle-eating article. Her
  focus foods change the day her phase does and nothing on screen said so — the list simply looked
  different. Silent on a first install: a fresh device is mid-phase, not crossing into one, so
  announcing would report something that happened days before she opened the app. Dismissable, or it
  would sit there for the rest of the phase for anyone who didn't want to read the article. Carries
  no nutrition claim of its own, so it needs no medical sign-off.
- **Logging and editing a past day** (working tree). `LogView` takes a date instead of hard-coding
  `.today()`, and a calendar day sheet offers "Add a log" or "Edit this day" depending on what is
  already there. Future days keep the old close-only sheet — there is nothing to record about a day
  that has not happened. The sheet titles itself with the day it is on, because a back-filled entry
  otherwise looks identical to today's and she has no way to tell which she is about to overwrite.
  The repository always supported this; until the sheet took a date, nothing could reach it.
- **The three inert Profile rows are now real editors** (T16/T17/T18, working tree). *Personal
  Details*, *Health Profile* and *Tracking Preferences* each raised a paragraph of text and changed
  nothing. They now open, respectively: her display name (with the sign-in address shown but not
  editable — changing it is a re-verification flow, not a text field, and leaving it off the screen
  entirely meant "which account am I in?" had no answer anywhere in the app); the existing cycle
  editor, which until now could only be reached from a Home setup card that disappears once filled
  in; and her five onboarding answers, which were captured once and then frozen — someone who
  answered "just starting to think about it" a year ago had no way to say she is trying now, and kept
  being guided as if she weren't.
  No DOB field, despite the change-list wording: nothing in the app consumes age, and a date of birth
  is PII in a row this release has just spent a batch of work moving PII *out* of.
- **The brand backdrop is drawn on the seven tab screens** (working tree), via one `gxPageBackground()`
  modifier. Sheets keep the flat fill — a card raised over a backdrop should not repeat it — and the
  art is light-mode only, because its field matches the light background exactly, which is what makes
  it read as a backdrop rather than a picture. One opacity constant is the dial if the client wants
  it fainter or stronger.
  The asset shipped as a single 1323×2868 file *declared 1x*, which is how a 3x export ends up laid
  out at three times its intended size; re-exported at proper 1x/2x/3x. `BrandAssetTests` asserts the
  laid-out **point** width, since that is the number SwiftUI actually uses and the one that catches
  this class of bug.

- **The Home pH card names the measurement site** (working tree): "Check your pH" → "Check your
  Vaginal pH", in the visible text and the accessibility label. `CitationE2ETests` pins that label to
  keep the card a navigational nudge with no health claim; the pinned string moved with it, since
  naming where a reading is taken is not a claim about what it means.

### Fixes
- **Hydration's Save button only worked if you hit the word** (working tree). Manual entry drew an
  88×48 capsule but sized it from *outside* the `Button`, so only the four letters of "Save" took the
  tap; every miss was swallowed by the background. She types a figure, presses what is plainly a
  button, and nothing happens. The same shape was on the sleep sheet's Save and Clear, where the
  capsule runs the full width of the sheet and the dead area is most of it. Fixed by moving size and
  fill into the label — which is what the quick-add buttons a few lines above already did, and why
  quick-add worked while Save did not.
  The guard took two attempts to be worth having, and the discarded one is the instructive part:
  `XCUIElement.tap()` hits an element's *centre*, which is over the glyphs, so it fires against the
  broken button too — and XCUITest reports the outer 88×48 frame either way, so asserting the frame
  proves nothing either. Both were confirmed green against the *unfixed* button before the test was
  changed to tap near the capsule's edge, which fails against it and passes after. The existing sleep
  smoke test was moved to an edge tap for the same reason.

### Reliability
- **A rejected row no longer starves the queue** (`185b99e`). Sync drains now step over a row the
  server refuses, so one poisoned write cannot block every newer one behind it. This needed a second
  look before landing: `requireUID` throws `notAuthenticated` before any request leaves the device
  and it is not a `URLError`, so a missing session would have read as "this one row is poison" and a
  signed-out foreground would have walked the whole backlog one doomed call at a time.
  `shouldHaltDrain` stops on both, which is what the old blanket `break` did for free.
- **The offline symbol that would not go away — G3, and the client was right** (working tree). The
  earlier "cannot reproduce, no such code path" reading searched for `NWPathMonitor` and
  `Reachability`; the badge has nothing to do with reachability. `DailyLogRepository.syncState(on:)`
  answers purely from the owed-days set, and that set was a plain `private var` — so saving a day
  published `logByDate`, drew `icloud.slash` "Will sync when online", and then the push that removed
  the day from the set a moment later published nothing at all. The icon sat over a day the server
  already had until some unrelated edit happened to redraw the row. One `@Published`.
- **A cycle correction made mid-sync was thrown away** (working tree). `drainPending` read the
  settings, awaited the server, then cleared the owed flag unconditionally — so correcting her period
  date inside that window marked a value synced that the server had never been sent, and the next
  pull replaced her correction with the copy the drain had just uploaded. It now re-checks that the
  settings still match what it sent, which is the guard `push` and the other three repositories were
  already using.
- **Her name and address survive a relaunch** (working tree). The Supabase SDK restores the session
  itself, but `SessionRepository` held the email and display name in memory only. A returning user
  was therefore greeted as "Guest" — and Personal Details opened prefilled with that literal word,
  ready to be saved over her real name. Both are now stored, and a sign-in that carries no name (all
  of them do — the sign-in screen never asks) no longer renames her to the part before the `@`.
- **One account's data can no longer follow another into the app** (working tree). Sign-out wipes,
  but the app stays usable signed out: onboarding does not re-run, the tabs are still there, and
  every write queues. Those writes belonged to whoever last held the session and were hydrated into
  whoever signed in next. Sign-in now compares the stored owner against the incoming user id and
  wipes first when they differ. A device that has never held a session is *not* treated as having a
  previous owner — onboarding runs before the account exists, so a first sign-in is carrying her own
  quiz answers and cycle dates in with her. Getting that wrong took out 21 UI tests, which is exactly
  what the seeded harness is for.
- **An owed profile write no longer lands in the next account's row** (working tree). The flag
  outlived the session that owed it, so the next user's first refresh pushed the previous user's
  theme, focus mode and push setting up into their `profiles` row, then pulled the clobbered values
  back down. Sign-out now drops it.

### Fixes — Profile and Track
- **The calendar exists before the cycle does** (working tree). Cycle setup is skippable, and
  skipping it took the entire month grid away — no cells, so nothing to tap, so no way to record or
  review any day at all. The calendar is *where logging happens*; gating it on a period date she
  had not given us made the app unusable for exactly the user who most needed to ease into it.
  `CalendarCell.day` and `DayInfo` now carry an optional `CyclePhaseInfo`, and `buildMonthGrid`
  takes optional settings: a full month of tappable days, none of them tinted, none of them claiming
  a phase. The phase key hides itself rather than explaining four colours that appear nowhere, the
  day sheet heads itself with the date instead of a cycle day that doesn't exist, and "Add your
  cycle" moves below the grid — still asked, no longer at the cost of the calendar.
  ⚠️ **Android parity:** `CalendarCell` mirrors a Kotlin sealed interface. The same nullability has
  to reach the Android client or the two calendars will disagree about whether a day can exist
  without a cycle.
- **Personal Details no longer offers to save the word "Guest"** (working tree). The sheet was handed
  the Profile card's display fallback rather than the stored name. Save is now disabled on an empty
  field instead of silently closing the sheet with no error and no change, which read as the app
  having lost the edit.
- **Change password tells her when it cannot help** (working tree). A social sign-in can leave us
  without an email address; offering to send a reset link there anyway ended in "please try again" on
  a call that could never succeed. It now says so and points at Help & Support.
- **A mis-entered pH reading can be corrected or deleted** (working tree). `PhLogSheet` had both an
  update path and a Delete button, and nothing could reach either: the state driving them was only
  ever assigned `nil`. The latest-reading panel is now tappable.
- **The Cycle row no longer draws a week she did not log** (working tree). It passed
  `Array(repeating: 1, count: 7)` as its sparkline, so seven fully saturated dots appeared the moment
  cycle settings existed — in a column where every other row's dots are seven days of her own data.
  Removed rather than faked. Relatedly, a pH reading of exactly 3.8 scaled to 0.0 and drew
  identically to a day with no reading at all; it now has a floor.
- **"About 0 days until your next period"** (working tree) now reads "Your next period is due today."
- **The day-detail sheet fits its contents** (working tree). A fully logged day's summary runs to nine
  clauses, and at the larger Dynamic Type sizes the fixed 280pt sheet pushed its buttons off-screen.

### Docs
- `docs/TESTFLIGHT_B18.md` (`510d43e`) follows the build-17 convention and adds a **pre-flight**,
  because two of this build's features depend on Supabase objects that nothing in this repo can check
  and that fail silently when absent. It also carries the P0 release checklist, which until now
  existed only in conversation and in nobody's notes.
- `docs/HANDOFF.md` was untracked — `git log` knew nothing about it and it was not ignored. Now
  tracked, and corrected: task 23 (`drop column quiz_answers`) was recorded as blocked on build 18
  being live because "build 17 users still select that column". They do not — build 17 was cut on
  29 July, and `quiz_answers` first entered the client's `profiles` select on 10 August and was moved
  off the row again the same day. The stale test baseline (169 app, 33 UI) was corrected to 186/39
  there, and stands at **179 domain + 198 app + 44 UI** with the working tree above.

### Owed
- ⚠️ **`daily_logs.sexual_activity` is unconfirmed.** The migration was written and never recorded as
  applied, and the decoders tolerate the column's absence — so she would log intimacy all week, see
  the calendar dots, and sync nothing. Pre-flight 1 in `docs/TESTFLIGHT_B18.md`.
- T20 made light the local default, but `apply(remote)` overwrites it on sign-in, and the server
  cannot tell "she chose system" from "she was defaulted to it before T20". A decision, not a check.
- `alter table public.profiles drop column quiz_answers` (task 23) is **not** part of this release.
  It now waits on the web client alone; do not run it as part of shipping 18.

## Unreleased — client change list, Sprint 1 (main, `71567c8` … `998b5c2`, 10 Aug 2026)

Twelve items from the client's "Simplified Consolidated Changes" list, all chosen because they need
no client or medical-reviewer sign-off. Audit and plan in `docs/CHANGE_LIST_PLAN.md`.

### Corrections
- **Urine → vaginal pH in Learn** (`71567c8`). Slug `guide-urine-tracker-with-stick` →
  `guide-vaginal-ph-tracker`, with an old→new map in `LearnReadLog` so the rename does not reset read
  history or re-offer an article she has finished. Deleted three orphaned `urine*` image assets.
  Fixed a Learn article that claimed logging is blocked offline — `LogView.save()` never blocked, and
  this is the likely origin of the client's "offline symbol" report.
- **Light mode is the default** (`560591e`); the dark toggle stays in Profile.
- **pH disclaimer collapses** into an expandable panel on the card. It stays permanently visible on
  the log sheet — the moment she is entering a reading is not the moment to hide the safety note.

### Tracking
- **Sexual activity** (`f082d31`, `ca28088`). A plain `Bool` on `DailyLog`, an Intimacy chip in the
  log sheet, and `daily_logs.sexual_activity` in Supabase. Carries its privacy promise on screen:
  *"Private to you. A linked partner sees your name — never your logs."* That claim is test-asserted,
  not just written. Reaches no partner surface and no notification copy.
  ⚠️ Deliberately **not** counted by `TrackingEngine.isMeaningfulLog` / `StreakEngine.hasAnyEntry`:
  those are the cross-platform contract, so flipping one client alone gives iOS and Android different
  streaks for identical data. Needs one coordinated change across both clients and
  `tracking_test_vectors.json`, or none.
- **Calendar markers** (`8c9f1f1`) for pH tests, symptoms/notes and intimacy, with the legend
  extended to name all three. Water, mood, energy, sleep and supplements are deliberately unmarked —
  a grid where most days carry most dots marks nothing.
  Fixed en route (pre-existing): every cell squared the day *number* rather than the cell, so
  two-digit days rendered as "…" — 8 of 31 days unreadable on the August grid.
- **Onboarding quiz answers are kept** (`148e754`), to `profiles.quiz_answers` (`jsonb`). The quiz
  runs before sign-up, so answers are written on-device and stay owed to the server until sign-in
  drains them. Nothing reads them yet by design — the consumer is the Girl/Boy question, which is
  blocked on sign-off.

### Notifications
- **Fertile-window alert** (`d35cfa0`) the morning her predicted window opens, with discreet
  lock-screen wording by default.
- **Per-category toggles** (`5dda691`) — one global switch would not hold eight categories.
- **Per-supplement reminder times** (`39a19e6`), with "No reminder" a first-class choice.
- **Weekly article drop** (`855a9be`, `998b5c2`). The Sunday nudge, a new Learn tab badge and a new
  Home dashboard card all pick through one rule, so the three can never name different articles. The
  badge counts *new-and-unread* only: zero on a first install, because badging all sixteen articles
  would read as a backlog rather than an invitation.

### Owed — resolved since, see 1.2.0 (18) above
- `20260810_daily_logs_sexual_activity.sql` is still unconfirmed against production; it is now
  pre-flight 1 for build 18.
- The partner-read check **came back badly**: `profiles_select` selects whole rows, so the "just for
  you" promise was false as written. `20260810_profiles_quiz_answers.sql` is therefore superseded and
  must not be applied to a fresh database — the answers moved to their own owner-only table in
  `9d08d82`.

## Unreleased — database & docs (main, build 16 source `547d2d4`)

### Database — pH constraint codified in version control
- Added migration `supabase/migrations/20260722_ph_conditional_value_range.sql`. It captures the
  production reality (applied via the dashboard on 22 Jul 2026) in version control: the
  `measurement_type` column + `ph_measurement_type_check` (`urine`/`vaginal`), and a **conditional
  `ph_value_range`** — vaginal `3.5–7.0`, legacy urine `4.5–9.0` — replacing the old unconditional
  4.5–9.0 CHECK. Idempotent; drops the old check name-agnostically (a `pg_constraint` `DO` block) so a
  future `db push`/rebuild reproduces prod instead of reintroducing the single-range rule.
- Updated `docs/supabase_schema.sql` `ph_readings` to show `measurement_type` + the conditional check.
- **Not auto-applied** from the repo; a no-op against the live DB (which already has this).

### Docs
- Refreshed `App_Inventory.md` to `main`/`547d2d4`, 1.1.1 (16): vaginal-pH two-band model, the Home
  "Check your pH" card, sleep ISO-week alignment, the medical-citation system + Medical Sources
  screen, the reviewer/demo account, and the pH DB constraint. Corrected the stale FEATURES.md note.

## 1.1.1 (16) — external TestFlight

- Bumped `MARKETING_VERSION` 1.1.1 / `CURRENT_PROJECT_VERSION` 16 for external TestFlight testing.
- Signed, uploadable archive built from `main @ 547d2d4`; `strings`-verified free of user-facing
  "Urine pH" (only the neutral `urine (legacy)` marker, enum raw value, and slug remain).
- Reviewer/demo account (`demo@genesyx.co.uk`) verified against production: profile + cycle +
  ~21 daily logs + pH readings present, so App Review lands on a populated app.

## build 17 — in flight (`fix/privacy-links-b17`, PR #2, not merged)

- Unifies both in-app privacy entry points on `https://genesyx.co.uk/policies/privacy-policy`
  (Profile row + the disclaimer alert's "Read our full privacy policy" button).
- Deletes the stale `docs/PRIVACY_POLICY.md`. Not required for the build-16 submission.

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
