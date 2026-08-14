# TestFlight — Genesyx 1.2.0 (18)

The client change list, end to end. 1.2.0 rather than 1.1.2 because this is a feature batch, not a
fix pass — a weekly article series, intimacy logging, a fertile-window notification, and
per-supplement reminder times are all new surface.

> **This document describes build 18, archived 13 Aug. It predates H22 and does not contain the
> mandatory authentication gate.** H22 landed 14 Aug, after the archive, and is still uncommitted.
> Every row below is a statement about the pre-gate binary and must stay that way — do not rewrite
> them as though H22 shipped in this build. A **new archive with a new build number** is required
> before H22 can reach TestFlight. Row H22 in the release checklist has the detail.

---

## Pre-flight — do these before uploading

All five are Supabase, and Supabase leaves no trace in this repo, so nothing here could check them
for us. They failed **silently** by design — the app keeps working, the data just never lands.

**As of 13 Aug 2026 all five are resolved or verified present.** Two things are still open and both
are judgement calls, not checks: whether to rewrite existing users' stored `dark` theme (row 5), and
whether an end-to-end waitlist submission actually works, which existence alone does not prove
(row 2).

| # | Check | Why it matters | Where |
|---|---|---|---|
| 1 | ✅ **Verified present 12 Aug 2026** — `daily_logs.sexual_activity` column exists | Intimacy logging (T10–T13) is a headline feature of this build. The decoders tolerate the column being absent, so if it was never applied she can log intimacy all week, see the calendar dots, and sync nothing. No error, no warning. | SQL Editor: `select column_name from information_schema.columns where table_name = 'daily_logs' and column_name = 'sexual_activity';` — expect one row |
| 2 | ✅ **Both exist on the live project — confirmed 13 Aug 2026** by third-party audit read. `join_waitlist` RPC + `waitlist_emails` table | The onboarding waitlist screen calls this RPC under the anon key. Neither object was ever in this repo's migrations — the schema existed only in whatever was typed into the dashboard, and now we know it was. ⬜ **Existence is not function:** nobody has submitted an email end-to-end and seen the row land, so the RPC's signature and grants are still unproven. | `supabase/migrations/20260811_waitlist_emails.sql` is idempotent — running it is still worth it to bring the *definitions* under version control rather than leaving them as whatever the dashboard holds, then run its step-5 verify block |
| 3 | ✅ **APPLIED 13 Aug 2026.** Was verified missing on 12 Aug. `food_groups` now reads `ARRAY / NO / '{}'::text[]` — identical to `symptoms` and `supplements`, which is what the migration's own verify block demanded. `daily_logs` RLS re-checked after: still the single `daily_logs_owner` policy, `ALL`, `(user_id = auth.uid())`. `daily_logs.food_groups` column | Meal logging (T26) is new in this build and fails in exactly the same silent way as row 1: `DailyLogRow.foodGroups` is optional on decode, so without the column she ticks off six groups a day, sees them persist locally, and syncs none of it. A new phone shows an empty history and nothing anywhere says why. | Apply `supabase/migrations/20260812_daily_logs_food_groups.sql` (idempotent; one `add column if not exists`, no policy changes). The type caveat in its verify block is already cleared — `symptoms` and `supplements` were confirmed `text[] NOT NULL DEFAULT '{}'::text[]` on the live project, which is exactly what the migration writes |
| 4 | ✅ **DEPLOYED 13 Aug 2026** — all six, each carrying the updated `_shared/client.ts`. **The deploy turned `verify_jwt` ON** (no `config.toml`, so the CLI default of `true` applies); re-probed straight after and all six now answer an anonymous POST with the gateway's `{"code":"UNAUTHORIZED_NO_AUTH_HEADER"}` instead of their own `{"error":"Not authenticated"}`. See `HANDOFF.md` §4i. **All six Edge Functions** | Until this ran, the 13 Aug backend batch was in this repo and in none of production: account deletion reported success over data it had failed to delete, invites addressed to a deleted user kept her email address, and an expired token came back as a 500. All three are now live. Nothing here changes the client, so the order against the app upload did not matter. | `supabase functions deploy accept_partner_invite decline_partner_invite revoke_partner_invite send_partner_invite unlink_partner delete_account` — or one at a time; the list is in `supabase/functions/README.md`. `decline_partner_invite` additionally needs `20260812_partner_invite_hardening.sql` applied first, which it is |
| 5 | ✅ **Default fixed 13 Aug** (`column_default` now `'light'::text`). ⬜ **Existing rows are a decision, still open.** What `profiles.theme` says for existing users | T20 made light the *local* default (`PreferencesRepository.swift:102`), but `apply(remote)` at `:196` overwrites it from the server on sign-in, so the server's value is the one that counts. The old column default was `dark` — a row created by it handed a brand-new user a preference she never expressed on her first launch, and `migrateLegacySystemTheme()` (`:179`) deliberately leaves `dark` alone because from the client it is indistinguishable from a real choice. **Counts as of 13 Aug: 8 `dark`, 8 `light`, 2 `system`** (18 rows, from the third-party audit — I was blocked from running this read myself). Small enough that the whole question is worth ~30 seconds of the client's time, and too small to guess from: 8 `dark` on an app that shipped dark-by-default is *probably* mostly unexpressed defaults, but "probably" is not a basis for overwriting somebody's setting. The 2 on `system` need nothing — the client corrects those once on next sync. | Decision only. Step 3 of `20260813_profiles_theme_default_light.sql` holds the one-line `update`, deliberately commented out |

**Do NOT run** `alter table public.profiles drop column quiz_answers` as part of this release. It is
task 23, and it is gated on task 18 (whether a live web client reads that column) — not on this
build. See `HANDOFF.md` for why the old "blocked by build 18" note was wrong.

Pre-flight 5 is a decision, not just a check. The server cannot tell "she chose dark" from "the
column default wrote dark and she never touched it" — both are the same four characters in the same
column, with no audit trail to separate them. So it splits in two:

- **The default itself is not a judgement call** and is fixed in
  `20260813_profiles_theme_default_light.sql`: one `alter column theme set default 'light'`, which
  touches only rows created from here on. Apply it.
- **Rewriting existing `dark` rows is the judgement call.** The update is written out, commented, in
  step 3 of that same file. Run the count first. It repairs everyone who was defaulted and overrides
  everyone who genuinely chose dark, and there is no undo.

---

## "What to Test" (paste into TestFlight → Build 18 → Test Details)

This build works through the whole change list. Please focus on:

1. **A new article every week** — Learn now carries eleven new pieces that arrive one at a time
   rather than all at once. You should see a badge on the Learn tab when one is waiting, a card on
   Home pointing at it, and (if notifications are on) a Sunday nudge. Open the article and confirm
   the badge and the Home card both clear.
2. **Three new how-to guides** — Learn → Guides now explains your cycle and its phases, sleep
   tracking, and logging how you feel. They describe the app screen by screen, so please tell us
   anywhere the article and the app disagree — that is the most useful bug you can file here.
3. **Intimacy logging** — Track → Log has an Intimacy chip between Symptoms and Notes. It is private
   and the screen says so. Log it and check the day gets a dot on the calendar. Please confirm it
   survives closing and reopening the app.
4. **Calendar markers** — days you have recorded something now carry small dots underneath: a pH
   test, symptoms or notes, and intimacy. Check they match what you actually logged.
5. **Fertile-window notification** — you should get one on the morning your predicted window opens.
   This needs a cycle set up and a day to arrive, so it is the slowest item here to confirm.
6. **Choosing which reminders you get** — Profile → Notifications now has a switch per kind
   (hydration, weekly summary, fertile window, supplements) instead of one all-or-nothing toggle.
   Turn one off and confirm the others still arrive. The switch above them is now called
   **All reminders**, which is what it always did — it used to say "Weekly reminders", so anyone who
   turned it off expecting to lose a weekly digest was also losing their supplement reminders, the
   evening check-in and the fertile-window nudge without being told.
7. **A time per supplement** — Nutrition → Review Plan. Each supplement now carries its own reminder
   time rather than sharing one. Set two to different times and confirm both fire.
8. **Your own glass size** — Profile → Hydration. With the unit set to glasses you can now set what
   a glass means to you (50–1000 ml, default 250). Change it and check Home, Track and Nutrition all
   agree on the new count. Your totals should not move — only how they are described.
   Please also try a size we cannot use — 3000, or 10 — and tap away from the field. It should come
   back as the nearest size we allow (1000, or 50) rather than sitting there looking accepted.
   Until now it was dropped in silence: the number stayed on screen while the glass stayed 250.
9. **Light theme by default** — a fresh install should open light. Dark is still there under
   Profile → Appearance.
10. **The onboarding splash** — now carries the brand egg artwork rather than the plain shapes that
    stood in for it. Please check the "not medical advice" line at the bottom is still fully legible.
11. **Nutrition** — when your cycle moves to a new phase, a card says so and links to the article
    about eating for it. Appears once per phase change.
12. **pH has its own tab** — it used to be a card partway down Nutrition, under supplements. It is
    now the third tab along, and Nutrition opens straight into your focus foods. Please check the
    seven tabs all fit and read clearly on your device, especially if you have a smaller iPhone.
    Everything that pointed at the old location (the Home card, Insights, the Learn articles) should
    now take you to the tab.
13. **pH tracker** — the safety note is now a panel you can expand rather than a permanent block of
    text, and the old urine-test wording is gone throughout. The safety note is now on the pH card in
    **Insights** too, which previously showed your reading and an "elevated" badge with no small print
    at all. The chart's 7d / 30d / 90d / All buttons now clearly show which one you are looking at.
14. **Logging what you ate** — Nutrition now has "What you ate today" where the "coming soon" card
    used to be. Tap a group when you have eaten something from it; "What counts as what?" expands if
    you are unsure which is which. Please check it survives closing and reopening the app, and — the
    one we most want testing — tick a couple of groups, then open Track → Log, add a note and save.
    Your groups should still be there afterwards.
15. **Recipes** — under your focus foods, "Something to cook" holds two recipes for the phase you are
    in. Swipe the row sideways, open one, and check the ingredients and steps read clearly. At the
    bottom is a button that logs the food groups the recipe covers: tap it, close the recipe, and the
    groups should now be ticked in "What you ate today" further down the same screen. Tapping it
    twice must not un-tick anything.
16. **Going back and correcting a day** — Track, tap a day you have already logged, and choose
    "Edit this day". Change something and save. The day should keep everything that was already on
    it — your symptoms and your note — and simply gain what you just added. Please try it on a day
    with a note you would not want to lose.
17. **Your current focus** — Profile → Current focus. Tapping **Pregnancy** shows the "coming soon"
    note and leaves you on Fertility Prep, because there is nothing else in the app yet. It used to
    switch the setting over permanently even though no screen behaved any differently.
18. **Deleting a pH reading — please try to lose one on purpose.** Open the pH tab, expand your
    reading history and tap an older reading. **Delete** is now down at the bottom of the sheet with
    the rest of the form, and asks before it does anything. The top-left button is **Cancel** and only
    closes the sheet. Previously Delete was in that top-left slot and removed the reading on the first
    tap, with no question — so opening a reading to change it and then changing your mind destroyed
    it. Please check that Cancel leaves your reading alone, that "Keep it" leaves it alone, and that
    only "Delete" removes it.
19. **Fixing a past day's water where you notice it** — Home → tap the hydration summary. The row of
    the last seven days at the bottom is now tappable: tap any day to open that day and correct it.
    Before, that row showed you a wrong total and gave you nothing to do about it — the only way in
    was Track → that day → Edit this day.
20. **Reminders that keep arriving — this one needs a few days, not a few minutes.** Turn reminders
    on in Profile and then just use the app normally for a week. What we are asking you to notice is
    an *absence*: previously, on any evening you had logged your day and finished your water, the app
    queued no evening check-in at all — and because it can only line up the next reminder while it is
    open, the check-in went missing on precisely your best days. The weekly reminders did not fill the
    gap, because two of them are only sent when you have *stopped* logging. If you are a diligent
    logger and the reminders quietly thin out or stop, that is exactly the fault we are trying to
    confirm is gone, so please tell us. Also worth one deliberate try: **turn all reminders off and back on again in the same
    evening**, then keep an eye out over the following fortnight for the fertile-window nudge. That
    switch used to convince the app it had already sent things it never sent, and the fertile-window
    nudge waits a full two weeks before it will send again.
21. **Recipe photographs — does the picture match the plate?** Nutrition → open each recipe card.
    Every recipe now has its own photograph. Automated checks prove each card has a picture, that no
    two cards share one, and that every image actually ships — but nothing can check that the *soup*
    card shows soup. Please look at all eight and tell us if any photograph belongs to a different
    recipe, or shows something the recipe does not contain.
22. **When your next period is due — please check the number, not just that one appears.** Home says
    "Next period" and Track says "Your next period is due in N days". Both were **one day short**,
    on every cycle, for everyone. The way to see it is to look on the *last* day of your cycle: the
    app used to say your period was due **today**, a day before it predicted it. It should now say
    tomorrow. Day 1 still correctly says today, because that is the day it started.
23. **If your cycle is 21–24 days, look at your ovulation day on the calendar.** On a short cycle the
    predicted ovulation day falls inside your period, and the calendar was drawing it as an ordinary
    period day — no ovulation colour, and VoiceOver just said "Period" — while Home, Insights and the
    cycle sheet all still named it. It now carries a heavier ring and, if you use VoiceOver, says
    "your predicted ovulation day". Please confirm the day the calendar highlights is the same day
    the other screens name. (Cycles of 25 days or more never had this; the two never overlapped.)
24. **"Your logs" should not skip a day you logged.** Insights → Your logs. A day where the only
    thing you did was tick a food group, or log intimacy, used to disappear from this list entirely —
    even though the calendar showed a dot for it and it counted towards your streak. Please try it:
    tick one food group and nothing else, then check that day appears here with what you ticked. Same
    with intimacy on its own, which now shows as its own row.
25. **Setting up your cycle for the first time — it must not guess for you.** On a fresh install, go
    to your cycle settings. The last-period field starts **empty** and Save stays greyed out until
    you choose a date. "Choose a date" used to silently fill in **today** and enable Save, so anyone
    who tapped it to see the calendar and then tapped Save had every prediction in the app built on a
    date they never picked. If your period genuinely did start today there is now a
    **"My period started today"** button under the calendar — please use it and confirm Save turns on.
26. **Your own supplements now follow the account, and the time field changed shape.** Nutrition →
    Supplement plan → the "Add your own" row. The time box used to be free text; it is now a picker
    with four options and a "No time" choice. **If you already had supplements in this app, please
    look at them before anything else:** every one should still be listed with its name and dose, but
    a time you typed by hand ("with breakfast", "8pm") will now be blank. That is intended and cannot
    be undone — please report the opposite, a supplement that vanished entirely. Then: add one, force
    quit, reopen — it should still be there. If you have a second device or the Android app on the
    same account, add one there and pull-to-refresh here; it should arrive. Delete one on either
    device and confirm it does **not** come back on the other after a refresh. Finally, try a very
    long name — past about 60 characters the Add button greys out rather than accepting it.
27. **Adding a supplement with no signal.** Turn on aeroplane mode, add a supplement, then turn it
    off and reopen the app. It must still be in your list, and it must reach your other device.
    Nothing you type should ever depend on having signal at that moment.
28. **Signing out and signing in as someone else — please use two throwaway accounts, never your
    own.** Set your focus to **Pregnancy** in Profile, sign out, then sign in with a *different*
    account. That second account must open Profile and see **Fertility Prep**, not Pregnancy, and
    must see none of the first account's logs, cycle dates, pH readings or supplements. Then check it
    the other way round: sign back in as the first account and confirm your own Pregnancy setting has
    come back. This is the fix we are least able to prove without real accounts, so it is the most
    valuable thing you can test.
29. **Deleting an account and then using the phone again.** With a throwaway account, change your
    display name in Profile, then delete the account from Profile → Delete account. Log a little
    something afterwards — some water, a symptom. Now sign in with a second throwaway account. It
    must be greeted by **its own** name, not the deleted account's, and it must **not** have inherited
    anything you logged in between.
30. **The quiz back button.** In onboarding, answer all five questions, reach the summary, then tap
    back. You should land on the last question with **all five answers still selected** — not on
    question one with the quiz emptied.
31. **What the app says on your ovulation day.** On the day the app predicts you ovulate, Home should
    say it is happening **today** — it used to say ovulation was "expected in 1–2 days" on the very
    day it had already named. Please report any screen that still describes that day as being in the
    future.
32. **The Sunday "new this week" notification.** If you get one, tap it. It must open a real article.
    If it ever opens a page saying "That article isn't available", screenshot the notification text —
    that is the exact fault we fixed and we want to know if any route to it survives.
33. **General** — sign in, complete cycle setup, and sanity-check Home, Insights and Learn.

Please report anything that looks wrong with a screenshot and the steps to reproduce. Thank you!

---

## Beta App Review Information (for the External test submission)

- **Sign-in required:** Yes.
- **Demo account:** `demo@genesyx.co.uk` / (password — from the password manager; do NOT paste into logs)
- **Verify path for reviewers:** Nutrition → expand "Why hydration?" → Sources footer; and
  Settings → Medical Sources & Disclaimer.
- **Notes:** Educational fertility/wellness app. All health statements carry inline citations
  (NHS / EFSA / NCBI-StatPearls / PubMed). The pH tracker records vaginal pH for personal wellness
  tracking only; it is not a medical device and not for contraception. Intimacy logging is a private
  on-device-and-account record with no sharing surface.

## What's NOT in this build (say so if asked)

- ~~**Custom-supplement cloud sync**~~ — **this now ships, on 14 Aug; the entry is kept because every
  earlier build lacked it and because the migration it performs is one-way.** Custom supplements were
  the last user-entered thing on iOS sitting entirely outside the owed-write contract: `@AppStorage`
  JSON with no pending flag, no drain, no read-back. They now go through `SupplementsRepository` like
  everything else — local write wins, a failed push stays pending and is retried, a pull merges
  rather than replaces, and a delete is a tombstone so it propagates instead of being resurrected.
  Three things about it are worth a tester's attention:
  - **The time field is now a four-option picker** (Morning / Afternoon / Evening / Anytime), matching
    Android's `SupplementTime` labels exactly, because the live constraint is
    `time_of_day is null or time_of_day in ('morning','afternoon','evening','anytime')` and free text
    would simply be rejected. **A value an existing user typed by hand no longer displays** — the
    supplement itself is kept, only the unrecognisable time is dropped, and recognisable ones
    ("Evening", " MORNING ") are recovered. This was the client's decision on 14 Aug; the discarded
    text cannot be recovered afterwards because it never left the phone, so there is no way to count
    how many users it affects.
  - **The name field now refuses anything over 60 characters** rather than accepting it, because the
    server's `check (char_length(btrim(name)) between 1 and 60)` would reject the row forever inside
    the retry queue. The Add button greys out instead of failing silently.
  - **First sign-in on an existing device carries the list up, it does not pull an empty one down.**
    Every pre-sync user has a full phone and an empty `user_supplements`; if that pull won, the
    feature would launch by deleting her list. The merge treats a local-only list as pending upload.

  The one-way part: the legacy `@AppStorage` key is read exactly once, when the repository has no
  records of its own. Once records exist it is never consulted again, so a downgrade to build 17
  would show a stale list.
- **Hydration display preferences** (unit and glass size) — device-local, not synced to the account.
  A new phone starts at millilitres with a 250 ml glass. Tracked as task 25; it is one coordinated
  change with Android, because storage is always `waterMl` and only the description differs.
- ~~**Food photography**~~ — **this now ships; the entry below is kept because earlier builds did
  not have it.** All 8 recipes carry their own photograph. `imageName` stays optional only so a
  newly-authored recipe can fall back to the phase gradient while its artwork is prepared. Two tests
  hold it, and the split matters: `testEveryRecipeHasAUniqueImageMapping` (domain) proves no recipe
  is left imageless and no two share a plate, while `testEveryRecipeImageAssetExists` (app target)
  loads each one through `UIImage(named:)` — because SwiftUI's string-based `Image` lookup **fails
  silently**, so a typo renders an empty card rather than falling back to the gradient. What no test
  can check is whether the right photograph is on the right card; see tester item 21.
- **Nutrient counting** — meal logging records food *groups*, not calories, macros or micronutrients.
  Counting needs a food database, which is the deferred barcode/photo work.
- **Logging food groups on Android** — meals now count toward your streak, so a day where meals are
  the only thing you logged keeps it alive, and both platforms compute that identically from the
  same rule. What Android still lacks is the *editor*: it reads, syncs and counts your food groups,
  but iOS remains the only place you can tick them.
- **Deleting a logged day** — you can correct any past day, but you cannot remove one. There is no
  delete path for a daily log on either platform; whether there should be is a data-retention
  decision, not an oversight. pH readings *can* be deleted individually.
- **Old urine-scale pH readings, if you also use the Android app** — readings taken before the switch
  to vaginal pH are on a different scale, so this build hides them rather than mixing them into your
  trend. They are not deleted: they are stored and synced, and they are excluded from your averages
  either way. But the Android app still *shows* them, labelled "urine (legacy)", so the same account
  will show a longer pH history there than here. Which behaviour is right is an open product
  question. *(Editing the hydration sheet's own day range is no longer on this list — the seven-day
  strip became tappable on 14 Aug; see item 19 above.)*
- **Reminders for someone who has stopped opening the app.** The app schedules one reminder at a
  time and can only schedule the next one while it is open. That is fine while you are using it — a
  fault where a completed day left nothing queued at all is fixed in this build — but it means the
  message aimed at someone who has gone quiet for a fortnight is the one message that cannot get
  through, because by then the app is not being opened to schedule it. Closing that needs background
  refresh, which is a capability with its own battery and App Store-review implications and a change
  in its own right, not a tweak to the reminder rules.
- **The Android app's period countdown is still a day short.** The fix in item 22 above is iOS only.
  Android and the website share the same expression and were never corrected, so on the last day of
  a cycle the same account will say "due tomorrow" on iPhone and "due today" on Android. iOS is the
  one that is right. Correcting the other two is a change to those codebases, not this one.
- **The calendar key still shows ovulation as its own colour.** On a 21–24 day cycle that colour
  never appears in the grid, because the ovulation day is drawn as a period day (item 23). The day
  itself is now named correctly; making the *key* change wording depending on cycle length is a
  design decision rather than a correction, so it was left alone.
- **The girl/boy quiz framing** — still held pending written client and medical-reviewer approval to
  remove `"boy or girl"` from `QuizContentTests`. Calendar time, not engineering time.
  *(The Shettles article is no longer on this list: it shipped 12 Aug as week 12 of the series,
  revealed 2026-11-08, and needed no guard relaxed. See G1 in `docs/CHANGE_LIST_PLAN.md`.)*

## Build facts

- Version **1.2.0 (18)**.
- Contains build 17 plus the client change list: T1–T6, T8, T10–T18, T20, T21, T23–T27, T28,
  T29a/T29c, T30, the waitlist wiring, and the privacy/security batch (quiz answers moved off the
  partner-readable `profiles` row; a user can no longer declare themselves someone else's partner).
- **Green baseline:** 267 domain · 272 app · 66 UI, 0 failures. Verified 14 Aug 2026. Do not pass
  `-quiet` — it has returned exit 0 with no summary and hidden a real result.
- **The UI number is not ceremonial — never cut a build on the two fast suites alone.** The supplement
  batch had 30 new tests green while the app *terminated* on tapping "Review Plan" (a missing
  `@EnvironmentObject` injection). Neither fast suite can see that class of fault: the domain tests
  never touch SwiftUI, and the app tests build the screen's dependencies themselves. The ~12-minute
  UI run caught it on the first attempt. Budget the 12 minutes before every submission.
- **"Application failed preflight checks" is a simulator fault, not a test failure.** The UI runner
  refused to install twice on 13 Aug, aborting in ~30 s with `TEST FAILED` and no test counts. Boot
  the device first and `simctl uninstall` both `com.genesyx.app` and
  `com.genesyx.app.uitests.xctrunner`, then re-run; it passed 52/52 straight after. A real UI run
  takes ~9.5 minutes, so any `TEST FAILED` inside a minute is this, not your code.
- **A UI test that reports thousands of seconds is a sleeping Mac, not a failure.** An overnight run
  had `SleepSmokeUITests` "take" 33,189 seconds and fail; the same test passes in 13 on a machine
  that is awake. Check the elapsed time before chasing the assertion.

---

## Release checklist

This list lived only in conversation until now, which is why it is written down here.

| # | Item | State |
|---|---|---|
| P0-1 | Waitlist: copy fix + a migration for the objects it calls | ✅ Copy and backend wiring were already in the tree; `supabase/migrations/20260811_waitlist_emails.sql` written. **Still needs applying** — pre-flight 2 |
| P0-2 | Commit the working tree | ✅ `6000f2d`, 13 Aug — 63 modified + 14 untracked, on `main`. **Not pushed.** `graphify-out/` (17M of generated skill output) went in at the client's explicit instruction; it was scanned for credentials first and is clean |
| P0-3 | Version bump 1.1.1 (17) → 1.2.0 (18) + this document | ✅ `project.yml` bumped, `xcodegen generate` run — pbxproj delta was exactly the 4 version lines plus the 8 for two new Swift files, no collateral churn |
| P0-4 | `drainPending()` — stop the drain on a missing session | ✅ See below |
| P0-5 | Correct the docs that were wrong | ✅ `CHANGE_LIST_PLAN.md` test baseline; `HANDOFF.md` task 23's fictional dependency on build 18 |
| P0-6 | Full green regression | ✅ 13 Aug, after the backend batch and the sign-in fix. **236 domain · 233 app · 46 UI** (45 + 1 skipped), 0 failures, both exit codes 0 — exactly the recorded baseline, so nothing this batch touched moved it. UI suite took 505s, which is normal for it |
| P0-7 | Verify the live `theme` default | ✅ **Fixed 13 Aug.** The default was `dark`; `20260813_profiles_theme_default_light.sql` step 1 applied to the live project and verified — `column_default` now reads `'light'::text`, so every profile created from here on starts light. ⬜ **Existing rows are untouched and still a decision** — run `select theme, count(*) from public.profiles group by 1;` and see step 3 of that migration before rewriting anyone's stored `dark` |
| P0-10 | ~~**Privacy policy — release blocker**~~ **Retracted. It was never a blocker** | ⚠️ **This row was wrong and is corrected here.** It said the published policy claimed the app collects nothing. It does not, and never did. The live page at <https://genesyx.co.uk/policies/privacy-policy> is accurate: it names **Genesyx Ltd**, Unit 8 Axiom, Orbital Park, Ashford, TN24 0AA, declares vaginal pH, cycle and daily logs, cites **Article 9(2)(a) explicit consent**, lists Supabase/Apple/Google/Shopify/Klaviyo, and promises immediate deletion. What was wrong was the **repo file** `docs/PRIVACY_POLICY.md`, a stale engineering document nobody publishes. I conflated the two, invented a 5.1.1 rejection risk that does not exist, and filled the controller bracket with the archive's **code-signing identity** (`SF MEDIA & PR LTD`) — a signing identity is not a data controller. Both fixed 13 Aug. **What actually remains, none of it blocking the archive:** (a) **Resend is a US processor not named in the live provider list** — add it, or move the invite to Resend's EU region, a one-line change at `send_partner_invite/index.ts:22`; (b) the live policy asserts Article 9(2)(a) explicit consent but **the app has no consent step or stored record** — see P0-13; (c) children's age is written as 18 and the App Store age rating is still unset; (d) a practitioner's read, health data being Article 9 |
| P0-8 | Backend batch: `delete_account` retention gaps, `unlink_partner` half-clear, auth status codes | ✅ Written and typechecked (`deno check`, all six clean). **Still needs deploying** — pre-flight 4. See `HANDOFF.md` §4i |
| P0-9 | Google sign-in: the `-5` swallow that could hide the failure entirely | ✅ `AuthView.swift` domain-checks `GIDSignInError` now. Do the console read *after* this, not before — see `to do list.md` §1 |
| P0-11 | **The Release build did not compile** | ✅ Fixed 13 Aug. `AppContainer.swift` imported `GenesyxCore` inside `#if DEBUG`, and since `dad4afb` the sign-out wipe named `CustomSupplement.storageKey` in release code — so `archive` failed on `cannot find 'CustomSupplement' in scope` while every test target, all of them Debug, stayed green. Build 18 was never archivable and the full green suite could not have told anyone. Import moved out of the conditional; swept the rest of `App/Genesyx/` for the same shape and `PreviewSupport.swift` is the only other conditional import, correctly so because the whole file is `#if DEBUG`. **Add an archive to the pre-release routine — a green suite is not evidence the thing builds** |
| P0-12 | Signed archive, version 1.2.0 (18) | ✅ 13 Aug — `build/Genesyx_1.2.0_18.xcarchive`, `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)`, `com.genesyx.app`, 1.2.0 (18), dSYM present. **Not uploaded.** Nothing blocks a TestFlight upload — P0-10 was retracted. P0-13 and P0-14 should be settled before a *public App Store* submission, not before internal TestFlight |
| P0-13 | **Article 9 explicit consent has no in-app step and no record** | ⬜ Found 13 Aug by third-party audit, verified. The live policy states health data is processed under **Article 9(2)(a) — explicit consent**, and explicit consent has to be a clear affirmative act that can be evidenced. Onboarding asks for cycle data and a sex preference without a consent statement, a tickbox, or a stored timestamp, so there is nothing to produce if the ICO or a user asks what she agreed to and when. Two ways out: add a consent step in onboarding and persist `consented_at` + policy version, or move the lawful basis to Article 9(2)(h)/(i) if a practitioner says that fits — **that is a legal call, not an engineering one**. Not a TestFlight blocker; is a public-release one |
| P0-14 | **App Privacy declarations understate what is collected** | ✅ **Fixed 13 Aug.** Found by third-party audit, verified against the code. The App Privacy table in `APP_STORE_SUBMISSION.md` §2 and `PrivacyInfo.xcprivacy` do not declare **Name** (the display name, which the partner link actually shows to another person) or **Other User Content** (free-text notes in daily logs). Both are collected and both are linked to identity. Under-declaring is a common 5.1.1 rejection and, unlike the imaginary one in P0-10, this one is real. **All three artefacts now agree:** `PrivacyInfo.xcprivacy` declares Name (`NSPrivacyCollectedDataTypeName`) and Other User Content (`NSPrivacyCollectedDataTypeOtherUserContent`) alongside Email, Health and User ID, `plutil -lint` clean; the App Privacy table in `APP_STORE_SUBMISSION.md` §2 carries the matching two rows; and because the manifest is baked into the bundle, **the archive was rebuilt after the edit** and all five types were verified inside `build/Genesyx_1.2.0_18.xcarchive` itself, 1.2.0 (18), same signing identity, dSYM present. Nothing further to do here — the remaining privacy work is P0-13 (Article 9 consent) and P0-15 (Apple token revocation) |
| P0-16 | **The two clients erase different things from the same database** | ⬜ Found 13 Aug by cross-checking the Android repo, which shares this Supabase project. iOS deletes through the `delete_account` Edge Function; **Android 1.4.0 (`versionCode` 14) calls the `delete_current_user()` SQL RPC** (`SupabaseAuthService.kt:70`). They are not the same contract. **Live state read 13 Aug** via `pg_get_functiondef`, `pg_constraint` and `information_schema.tables`. **Android runs the OLDER RPC body** — the one at `schema.sql:238`, with no `user_supplements` line. That proves only that the function **does not abort**; it is not evidence that deletion is complete. It is not. **Verified cascade coverage: six foreign keys, every one of them `child → auth.users(id) ON DELETE CASCADE`** — `cycle_settings.user_id`, `daily_logs.user_id`, `partner_invites.inviter_id`, `ph_readings.user_id`, `profiles.id`, `quiz_answers.user_id`. So the RPC's final `delete from auth.users` does sweep `quiz_answers` and `partner_invites`-by-`inviter_id` even though the body never names them, and **Android erases six of the seven live tables**. **It is incomplete in exactly three places, and all three are the places with no foreign key:** (a) `partner_invites` addressed TO her by `invitee_email` — `text`, no FK, so nothing cascades it, and `partner_invites_owner` is `inviter_id = auth.uid()`, meaning she could never see or delete those rows even while her account existed; (b) `waitlist_emails` — keyed by `email` text, no FK, survives forever; (c) **the reciprocal partner link, which is the one that surprised me.** `pg_constraint` on `public.profiles` returns exactly two rows, `profiles_pkey` and `profiles_id_fkey (id → auth.users ON DELETE CASCADE)`. **There is no foreign key on `partner_id` at all.** `docs/supabase_schema.sql:21` declares `partner_id uuid references public.profiles (id) on delete set null`; **that constraint was never deployed.** The RPC never touches `partner_id` and no cascade does it either, so her partner's row keeps a pointer to a profile that no longer exists — a stuck "connected" state he cannot clear, because `profiles_update` only lets him write his own row and the pointer is the thing that is wrong. iOS is unaffected: `delete_account` nulls the partner's pointer explicitly as its first step (`index.ts:39-46`) instead of trusting a cascade, and matches invitee emails case-insensitively with an `ilike` narrow plus an exact compare so a stranger's invite cannot be taken with it. **`accepted_by` does not exist** — live `partner_invites` has seven columns (`id`, `inviter_id`, `invitee_email`, `code`, `status`, `created_at`, `expires_at`), so there is nothing for it to cascade or null, and acceptance is recorded only by mutating `status`. **`user_supplements` was NOT a deletion orphan when this was written** — the live table was absent, so there were no rows to strand, and adding it to the iOS list would have aborted `delete_account` on a missing relation and broken deletion for everyone. **That instruction expired the same day.** Migration B created the table hours later, so the relation now exists and the abort risk is gone; the line was added to the iOS list on 14 Aug (`308b8ca`, see P0-15b), which restores parity with the backstop H1 spliced into Android's RPC. Read "leave the iOS list alone" as scoped to 13 Aug, before migration B. The missing table is a different bug entirely — see P0-17A. **Live blast radius of (c) today is zero:** `count(*) filter (where partner_id is not null)` is **0**, nobody is linked yet, which is exactly why it is cheap now and expensive once the feature is used. Preferred fix is the explicit unlink in the RPC rather than adding the FK — it matches iOS and does not depend on a constraint that has already proven it can go missing. **✅ Fixed 13 Aug by migration A, `20260813_delete_current_user_hardening.sql`, applied to production.** The new body unlinks every row pointing at her (`where partner_id = v_uid`, which also survives a one-directional or already-stale link), deletes invites addressed to her and her waitlist row by normalised email, and pins `search_path = ''` with every identifier schema-qualified. Post-apply reads confirm `prosecdef = true`, `proconfig = {search_path=}`, execute revoked from `anon` and `PUBLIC`, and — the pre-apply risk — `relforcerowsecurity = false` on both `profiles` and `waitlist_emails`, so the definer genuinely bypasses RLS and the unlink reaches rows it does not own. At that point it deliberately never named `user_supplements`: plpgsql resolves relations at run time, and the table did not yet exist, so that single line would have aborted every call. **✅ Superseded later the same day by H1.** Once migration B had created the table, `20260813_user_supplements_delete_backstop_and_push_default_false` spliced `delete from public.user_supplements where user_id = v_uid;` into the deployed body **exactly once**, immediately before the profiles/auth deletion. The explicit backstop is therefore **deployed**, and the cascade is no longer the only thing standing between a deleted account and her supplement rows. Post-apply reads preserved owner `postgres`, `SECURITY DEFINER`, `search_path=''` and EXECUTE for postgres/authenticated/service_role only; every hardened cleanup block survived; `profiles` = 18, `user_supplements` = 1, `genesyx_products` = 0 and `ph_readings` = 61 were identical before and after. **The distinction that matters: `delete_current_user()` was REDEFINED, not EXECUTED.** No account was deleted to get this evidence, and none should be. **So end-to-end deletion is still NOT proven** — tests 2, 3 and 5 need two throwaway accounts and a real deletion against a project holding 18 live profiles including Apple's reviewer, which was never authorised. That is remaining behavioural QA, not missing implementation |
| P0-17A | **Android supplement sync writes to a table that does not exist — data is not restorable** | ⬜ Found 13 Aug. `user_supplements` is absent from the live schema and the only migration that would create it has **never been applied**. Production DI binds the real Supabase implementation whenever credentials are configured (`NetworkModule.kt:139,148`), and they are. So she adds a supplement, it lands in Room as `PENDING_UPSERT` (`UserSupplementRepository.kt:76`), the push fails against a missing relation, `pushOrQueue` **logs a warning and reschedules** (`:98-108`), `syncPending()` returns false, and `UserSupplementSyncWorker` returns `Result.retry()` so WorkManager backs off and retries **forever**. The pull path fails the same way, log-only (`:158`). **The severity is data restoration, not just sync:** nothing has ever reached the server, so a new phone, a reinstall or a sign-in elsewhere shows none of it, and there is no copy anywhere but that one device. **I previously called the wording honest. That was wrong, and it is the opposite.** `ProfileScreen.kt:160` renders *"Saved on your device — they'll sync to your account automatically."* — a promise that is **false** while the table does not exist. The code comment directly above it (`:145-146`) states the lingering count is *"reassuring, not an error"* because the change *"syncs on its own"*; for supplements it never does, so the reassurance is false too, and the "Sync now" button re-runs a drain that cannot succeed. The counter is shared with daily logs and pH, whose tables **do** exist, so the stuck remainder is indistinguishable from a transient queue. **Play exposure: NOT VERIFIED — it needs Play Console, which I cannot reach** (no `adb`, no fastlane, no publish workflow, no app release tags). What the repo does bound: the feature arrived `aecac1a` on **29 Jul**, *after* the 27 Jul bump to `versionCode 13`, and `versionCode 14` was bumped **12 Aug** with the message "for the **next** Play release" (`ab0ebc0`) with six feature commits landing after it. **So if Production and Internal are at 13 or below, no Play user has ever run this code and it is a current-source defect only; if 14 was promoted to any track, testers on that track are losing entries now.** Settle it by reading both track version codes before deciding urgency. **✅ Server side fixed 13 Aug by migration B, `20260813_android_supplements_backend.sql`, applied to production.** `user_supplements` now exists with `user_id → auth.users(id) ON DELETE CASCADE` — so account deletion covers it with no change to either delete path, which is why A and B are order-independent — and `product_id → genesyx_products(id) ON DELETE SET NULL`, because retiring a product must never delete her history. `updated_at` is **nullable on purpose**: `UserSupplementDto.updatedAt` is `String?` and `toDto()` emits `updatedAt?.toString()`, so a `NOT NULL` column would have rejected precisely the rows this migration exists to unstick. Owner-only RLS, both indexes present, table empty. **Not yet proven end to end** — verification test 7 needs an Android build with credentials, and until someone watches that "N changes not synced yet" row reach zero on its own, "the queue now drains" is inference, not evidence |
| P1-1 | `genesyx_products` catalogue table is not created | ⬜ Found 13 Aug, and **deliberately not filed with P0-17A — it is not the same class of problem.** The table is absent live, so the catalogue read fails; but `GenesyxProductRepository.kt:28` catches that and renders the **"coming soon"** empty state, which is *also the truthful answer* — the Genesyx range has zero SKUs and has not launched. Nothing queues, nothing is pending, no user data is at risk and there is nothing to restore. It is a readiness gap, not a data defect: a failed fetch and an empty catalogue are indistinguishable to her, and both are correct today. Worth creating empty anyway, because then real SKUs can be seeded with **no app update on either platform** — which is exactly what the client already built for. **✅ Created 13 Aug by migration B, applied to production** — empty, RLS on, a single `select` policy and no write grant by any route, so seeding real SKUs is a data change rather than a release on either platform. Nothing visible changed: the app still renders "coming soon", which remains the truth |
| P1-2 | **Every new table in `public` is born with `authenticated` holding TRUNCATE** | ✅ Found and fixed 13 Aug, **by my own migration B breaking it first.** This project's schema-level default privileges grant the full `arwdDxtm` to `anon`, `authenticated` and `service_role` at `CREATE TABLE` time. Migration B wrote `grant select on genesyx_products to authenticated` and assumed that *described* the result; `GRANT` is additive, so it described only what was added. The post-apply read showed `authenticated` holding `DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE` on **both** new tables. **`TRUNCATE` is the one that bites: it is not subject to RLS**, so the owner policy that correctly scopes every other verb to her own rows cannot refuse it, and one statement would empty every user's supplements. This is the identical hole `2e07f1f` closed on the other six tables three weeks ago — creating a table silently re-opens it, which is exactly why it is worth a row of its own rather than a footnote. Fixed by making the revoke name `authenticated` as well as `anon` and re-applying; grants now read exactly `SELECT` on `genesyx_products` and `DELETE,INSERT,SELECT,UPDATE` on `user_supplements`, with `anon` holding nothing on either. **Standing rule for this project: after any `create table`, read the ACL back — the failure to look for is an extra privilege, not a missing one.** A "can the client still write?" check passes cleanly while this defect is present |
| P0-19 | **Mandatory authentication gate (H22) is not in this archive** | ⚠️ **Not in build 18.** Build 18 was archived **13 Aug**. H22 landed **14 Aug** and is still uncommitted. Testers on 1.2.0 (18) will still reach every private tab after logout, deletion, or a missing session — that is the old `onboardingComplete`-only route, not a regression in the gate. **Do not tell them to look for mandatory Sign In.** The working tree now routes from session first (`RootRouting`), fails closed in Release without a backend, and has unit coverage for a revoked token (`SessionExpiryTests`). Physical logout/relaunch remains **DEFERRED** (no iPhone). Same rule as P0-18: this becomes a tester-facing fact the moment a later build carries the gate. |
| P0-20 | **The gate locked out anyone who forgot her password — no in-app route to recovery at all** | ✅ **Found and fixed 14 Aug, and it is a defect H22 *created* rather than one it exposed.** Before the gate, private tabs mounted from `onboardingComplete` alone, so a forgotten password was an inconvenience: she kept using the app and Profile → Change password was reachable. After it, `RootRouting` sends a signed-out user to `AuthView` and nowhere else, so the only reset control in the app sat behind the very session she could not obtain. **The loop was broken in three independent places.** (a) She could not ask for the email — the sole entry point was `ProfileView.swift:105`, inside the private tabs, and `AuthView` had no forgot-password control at all. (b) The method could not have addressed it to her anyway — `SessionRepository.resetPassword()` took no argument and read `self.email`, which only a live session populates. (c) The link had nowhere to land — `RootView.onOpenURL` handles only the Google OAuth callback and `DeepLink.inviteCode`, `DeepLink` parses invites only, and `.passwordRecovery` hits `default: continue` in `SupabaseBackend.observeAuthState:88`, so a recovery URL is inert end to end. **(a) and (b) are fixed:** `sendPasswordReset(email:)` takes the address the way `resendConfirmation(email:)` already did, and a **Forgot password?** control is on the sign-in gate. The confirmation wording is deliberately neutral — *"If that email has an account, we've sent a reset link"* — because naming whether an address is registered would make this screen an account-enumeration oracle for a health app, and Supabase does not distinguish the two either. Five unit tests (`PasswordResetTests`) plus a UI test asserting the control is actually **on** the mandatory screen, since the repository method is unreachable if nothing calls it. **Falsified twice:** restoring the old session-email read failed exactly the two signed-out tests while the signed-in path correctly still passed; hiding the control from sign-in mode failed the UI test. ⬜ **(c) is still open and needs one fact I cannot read.** Completing in-app recovery needs the emailed link to come back to `genesyx://…` — the scheme is already registered (`project.yml:70`) — but there is **no `supabase/config.toml` in this repo**, so the redirect allowlist and the email template live only in the dashboard. Building the landing screen before that is confirmed risks dead code that never runs. **Needed: what the recovery email currently points at, and whether genesyx.co.uk has a page that handles it.** Until then she can *start* recovery from inside the app and finish it wherever that link leads, which is the difference between locked out and recoverable |
| P0-18 | **The bundled free-guide PDF gates the *next* public submission, not this one** | ⚠️ **Not in build 18.** Build 18 was archived 13 Aug; the free guide (H21) landed 14 Aug and is still uncommitted, so nothing here changes this build and testers should not be told to look for it. It is recorded now because it becomes a submission gate the moment a build carries it, and this is the checklist whoever prepares that build will read. **Client ruling D5, 14 Aug: the PDF is usable internally — TestFlight is fine — but it is NOT App Store-ready.** Four corrections need a person before public submission: the filename and internal PDF metadata must read "7-Day Fertility Nutrition Starter Guide" (it was supplied as a recipe book, so saving or sharing it produces a different title from the one the app showed); the page-20 typo "Download **out** free app" must read "our"; the page-20 QR code / app-download call-to-action must go, because it tells a reader who is already inside the app to download the app — and that QR is precisely the silent exit to Safari the in-app reader deliberately blocks; and the PDF must be accessibility-tagged or carry an accessible text equivalent in the app (the reader sets an `.accessibilityLabel`, which is not a text equivalent). **Plus the medical and content-source review every other piece of shipping content has had — this file came in through a different door.** Engineering is done and proven: the PDF is verified inside the built `.app` rather than just the repo, which matters because if it fell out of Copy Bundle Resources nothing would complain — the button would still open and the reader would simply be blank. Detail in `CHANGE_LIST_PLAN.md` §11.1c, `HANDOFF.md` §0h |
| H22 | **The mandatory authentication gate is NOT in build 18** | ⚠️ **Not in build 18, and build 18's notes above must not be read as though it were.** Build 18 was archived 13 Aug. H22 — the gate that stops every private tab mounting without a validated session — landed 14 Aug and is still uncommitted, so **nothing in this document's build-18 rows changes**, and no tester on build 18 is exercising it. **A new archive and a new build number are required before H22 can reach TestFlight at all;** re-uploading 18, or renumbering it, would ship the pre-gate binary under a name that claims the gate. Engineering state, 14 Aug: **Engineering Done; simulator verified; physical-device QA deferred because no physical iPhone is available.** What that split means, precisely — the simulator suites are green and the decision table (`RootRouting.destination`) and the expired/revoked-token lifecycle (`SessionExpiryTests`) are both covered by domain-level tests that a UI-only rewrite cannot satisfy; but **every UI test runs `AppContainer.uiTestSeeded()` with `backend: nil`**, so they prove the routing table and the view wiring and never Supabase's real session restore. Keychain persistence across a genuine cold boot, a token revoked from another device, and Sign in with Apple on real hardware are therefore **unproven, not passed**. Whoever cuts the next build owes: a physical-device pass on those three, then a TestFlight pass on the same. See `HANDOFF.md` §0-H22 and `CHANGE_LIST_PLAN.md` |
| P0-15 | **`delete_account` does not revoke the Sign in with Apple token** | ⬜ Found 13 Aug, confirmed by reading `supabase/functions/delete_account/index.ts` end to end — there is no call to Apple's `/auth/revoke` anywhere. Apple requires apps offering Sign in with Apple to revoke the refresh token on account deletion; leaving it live means the relationship persists after she deleted everything. Also in that file: the `waitlist_emails` delete is **best-effort** — on error it logs and falls through, and `{ok: true}` is returned regardless (`:84-108`), so a woman can be told her data is gone while her email is still on the waitlist. **Confirmed live 13 Aug: this is not hypothetical.** `auth.identities` grouped by provider returns **apple 2**, email 15, google 2 — Sign in with Apple is offered *and in use*, so the revocation duty is already engaged for real accounts, not just theoretically by having the button on screen. **⚠️ 14 Aug — this row was three defects wearing one number. Two are now closed and one is not; do not read the ⬜ as "nothing happened".** ✅ **(a) The `waitlist_emails` swallow is gone** (`308b8ca`): the delete is checked like every other table and a failure returns 500. It runs *before* the profile and auth-user steps, so a failure leaves her account intact and still deletable — the retry is the same call again. The old best-effort was justified on "the table might not exist live"; that premise died 13 Aug when both `waitlist_emails` and `join_waitlist` were confirmed present. ✅ **(b) `user_supplements` is now deleted explicitly** (`308b8ca`) — Android's RPC got that backstop on 13 Aug via H1 and this path did not; the asymmetry is closed. Severity, stated honestly: the table cascades on `auth.users`, so a *successful* deletion always erased it. The gap only bit when the final auth-user delete failed, and a retry cleared it. Defence in depth, not a live leak. ⚠️ **Neither (a) nor (b) is deployed.** They are in the repo only; the live project `epltxklawpcxxbaleswg` still runs the old function until someone runs `supabase functions deploy delete_account`. The file carries a banner saying exactly that, to be deleted in the same change that deploys it. ⬜ **(c) The Apple `/auth/revoke` server call remains OPEN and is the actual public-release blocker.** It needs the Apple `.p8` in Supabase's secret store — a person's action, not an engineering one, and entangled with the unresolved decision to revoke/regenerate the exposed keys. ✅ **The client-side half is done** (`SessionRepository.handleAppleCredentialRevoked`, wired in `RootView` to `ASAuthorizationAppleIDProvider.credentialRevokedNotification`): when she revokes the app under Settings → Apple ID, the local session ends. Guarded on how the **live** session was obtained, because the notification is app-wide — an Apple revocation must not end an unrelated email session. Three tests in `SessionExpiryTests`, all falsified: neutering the handler fails the revoke tests, removing the guard fails the email-session test |
| P0-21 | **Partner linking is intentionally OUT OF SCOPE for the public release** | ✅ **Decided and implemented 14 Aug 2026, after build 18 was archived — so it is not in build 18 either.** Testers on 1.2.0 (18) still see the Partner section on Profile and can still open an invite link; that is the pre-change binary, not a regression. From the next archive onward, `FeatureFlags.partnerInvites` is `false` and the feature is unreachable: no Profile section, no invite deep link, and `AppContainer` no longer even calls `partner.refresh()`, so the build never reads `partner_invites`. It is a **compile-time constant** — nothing at runtime, on the server or on the device, can turn it back on; that needs a new binary. **Nothing was deleted and nothing backend-side changed:** the five partner Edge Functions stay deployed and `PartnerRepository` / `InviteView` stay compiled, because the same Supabase project serves the Android app, which does ship partner linking. **Metadata was the real risk and it is closed:** the App Store description in `APP_STORE_SUBMISSION.md` carried a whole `PARTNER LINKING` paragraph, which would have described a feature the submitted build does not have (guideline 2.3.1). It is removed, and the App Review notes now explain why partner code is still visible in the binary. Two new UI tests assert the scope and both were falsified by flipping the flag back on. See `HANDOFF.md` §0-P |
| P0-22 | **Health consent, widget and barcode are OUT OF SCOPE for 1.2.0 — and the survey found nothing to remove** | ✅ **Surveyed and guarded 14 Aug 2026. Report this accurately: no feature was withdrawn, because none of the three was ever built.** **Widget:** no target in `project.yml` (the file declares exactly three — `Genesyx`, `GenesyxAppTests`, `GenesyxUITests`), no source directory, no `WidgetKit` link, no user-visible string, and no claim in the App Store description. **Barcode / photo meal logging:** no `AVFoundation`, `VisionKit` or `Vision`, and — the load-bearing fact — **no `NSCameraUsageDescription` and no `NSPhotoLibraryUsageDescription`**, so the build structurally cannot open a capture UI; iOS terminates an app that tries without them. The only two mentions in the whole codebase are code *comments* at `NutritionView.swift:519` and `NutritionContent.swift:37`, both explaining why nutrient counting is **not** offered. **Health is the inverse of what the brief assumed.** There is no half-finished consent flow to disable — the app has **no consent step at all**, only a Privacy Policy link at `ProfileView.swift:416`. The misleading Article 9(2)(a) claim is on the **live published privacy policy**, not in the binary, and is already open and correctly described as a legal decision at P0-13. Nothing was invented to paper over it. **What actually changed: one new test file, `App/GenesyxTests/ReleaseScopeTests.swift` (4 tests), and these docs.** The tests read the built `.app` rather than the source tree, because the bundle is what Apple reviews: no camera/photo-library keys, no Apple Health keys, no embedded `.appex` anywhere in the bundle, and no shipping Learn or quiz copy advertising a widget, a barcode scan or photo logging. All four were falsified in two rounds and in each round exactly the expected two failed while the other two stayed green, which also proves they are independent: round A added the camera and health keys to `project.yml`; round B pointed the bundle walk at `.xctest` and put "scan a barcode" into the `hydration-basics` article. Both rounds reverted, `project.yml` diff-clean. **One incidental finding worth knowing:** a stray `.appex` file placed under `App/Genesyx/Resources/` breaks the Swift build outright with unrelated "cannot find type in scope" errors, and the simulator refuses to install an app containing a malformed extension — so an accidental extension will fail loudly rather than ship quietly. **Suites after: 267 domain / 301 app, 0 failures** (`/tmp/gx_scope_app.log`, 16:54). Do not subtract that against the 296 at P0-21 and conclude five tests landed here — **four** did. The fifth is `LearnContentTests.testTheTwelveWeekPlanListsEveryWeeklyArticleInOrder`, unrelated uncommitted twelve-week-plan work sitting in the same tree; the two runs' test *names* were diffed to establish that, because subtracting totals is exactly how a stray test gets credited to the wrong change. ⬜ **Still needs a person, unchanged by this work:** the UK data-protection decision behind P0-13. Widget and barcode need no decision — they are simply future scope, quoted at §7 of `CHANGE_LIST_PLAN.md` |

### What P0-4 was

**A regression in unreleased work, caught before it shipped.** Build 17 stops the drain on *any*
failure (`catch { break }`), and `SyncError` does not exist in it at all. So no user was ever
affected, and nothing needs saying to anyone.

What happened: this batch introduced stepping over a row the server rejects, so one poisoned write
could not starve every newer one behind it. That is right. But `requireUID` throws
`RemoteError.notAuthenticated` before any request leaves the device — session not restored yet, or
token expired — and that is not a `URLError`, so the new classifier read it as "the server rejected
this one row" and stepped over it, then over the next, and the next. A signed-out foreground would
have walked the entire backlog making one doomed call per owed day, to learn what the first call had
already established. Nothing lost, just N times the work, N being however many days she logged
offline. The old blanket `break` had covered this case for free; stepping over rejections stopped
covering it.

`SyncError.isTransport` is now `SyncError.shouldHaltDrain` and returns true for both cases, and
`RepositoryTests.testAMissingSessionStopsTheDrainInsteadOfWalkingTheWholeQueue` pins it — verified
failing (`2` attempts, expected `1`) against the old predicate before the fix went in.

The other half of that question — telling a *permanent* rejection from a transient one, so a row the
server will never accept can be dropped instead of retried forever — was deliberately left alone.
The repositories are Foundation-only by design so they compile without the Supabase package, which
means a 400 and a 503 are indistinguishable from where the decision is made. The two mistakes are
not symmetric: retrying a dead row costs one background call per foreground, while dropping a live
one silently loses a day she logged. Until a rejection can carry its status code up to that layer,
the queue keeps it.
