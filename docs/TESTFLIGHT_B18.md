# TestFlight — Genesyx 1.2.0 (18)

The client change list, end to end. 1.2.0 rather than 1.1.2 because this is a feature batch, not a
fix pass — a weekly article series, intimacy logging, a fertile-window notification, and
per-supplement reminder times are all new surface.

---

## Pre-flight — do these before uploading

All four are Supabase, and Supabase leaves no trace in this repo, so nothing here can check them for
you. Three of them fail **silently** — the app keeps working, the data just never lands. The other
is a decision rather than a check.

| # | Check | Why it matters | Where |
|---|---|---|---|
| 1 | ✅ **Verified present 12 Aug 2026** — `daily_logs.sexual_activity` column exists | Intimacy logging (T10–T13) is a headline feature of this build. The decoders tolerate the column being absent, so if it was never applied she can log intimacy all week, see the calendar dots, and sync nothing. No error, no warning. | SQL Editor: `select column_name from information_schema.columns where table_name = 'daily_logs' and column_name = 'sexual_activity';` — expect one row |
| 2 | `join_waitlist` RPC + `waitlist_emails` table exist | The onboarding waitlist screen calls this RPC under the anon key. Neither object was ever in this repo's migrations — the schema existed only in whatever was typed into the dashboard, if it was typed at all. | Apply `supabase/migrations/20260811_waitlist_emails.sql` (idempotent — a no-op if they already exist), then run its step-5 verify block |
| 3 | ✅ **APPLIED 13 Aug 2026.** Was verified missing on 12 Aug. `food_groups` now reads `ARRAY / NO / '{}'::text[]` — identical to `symptoms` and `supplements`, which is what the migration's own verify block demanded. `daily_logs` RLS re-checked after: still the single `daily_logs_owner` policy, `ALL`, `(user_id = auth.uid())`. `daily_logs.food_groups` column | Meal logging (T26) is new in this build and fails in exactly the same silent way as row 1: `DailyLogRow.foodGroups` is optional on decode, so without the column she ticks off six groups a day, sees them persist locally, and syncs none of it. A new phone shows an empty history and nothing anywhere says why. | Apply `supabase/migrations/20260812_daily_logs_food_groups.sql` (idempotent; one `add column if not exists`, no policy changes). The type caveat in its verify block is already cleared — `symptoms` and `supplements` were confirmed `text[] NOT NULL DEFAULT '{}'::text[]` on the live project, which is exactly what the migration writes |
| 4 | ✅ **DEPLOYED 13 Aug 2026** — all six, each carrying the updated `_shared/client.ts`. **The deploy turned `verify_jwt` ON** (no `config.toml`, so the CLI default of `true` applies); re-probed straight after and all six now answer an anonymous POST with the gateway's `{"code":"UNAUTHORIZED_NO_AUTH_HEADER"}` instead of their own `{"error":"Not authenticated"}`. See `HANDOFF.md` §4i. **All six Edge Functions** | Until this ran, the 13 Aug backend batch was in this repo and in none of production: account deletion reported success over data it had failed to delete, invites addressed to a deleted user kept her email address, and an expired token came back as a 500. All three are now live. Nothing here changes the client, so the order against the app upload did not matter. | `supabase functions deploy accept_partner_invite decline_partner_invite revoke_partner_invite send_partner_invite unlink_partner delete_account` — or one at a time; the list is in `supabase/functions/README.md`. `decline_partner_invite` additionally needs `20260812_partner_invite_hardening.sql` applied first, which it is |
| 5 | What `profiles.theme` says for existing users | T20 made light the *local* default (`PreferencesRepository.swift:101`), but `apply(remote)` at `:170` overwrites it from the server on sign-in. Anyone whose row already says `system` gets `system` back, and T20 looks like it never shipped for exactly the people who have been here longest. | SQL Editor: `select theme, count(*) from public.profiles group by theme;` |

**Do NOT run** `alter table public.profiles drop column quiz_answers` as part of this release. It is
task 23, and it is gated on task 18 (whether a live web client reads that column) — not on this
build. See `HANDOFF.md` for why the old "blocked by build 18" note was wrong.

Pre-flight 5 is a decision, not just a check. The server cannot tell "she chose system" from "she
was defaulted to system before T20", so there is no safe automatic answer — only a count, and a call
to make once you can see it.

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
   Turn one off and confirm the others still arrive.
7. **A time per supplement** — Nutrition → Review Plan. Each supplement now carries its own reminder
   time rather than sharing one. Set two to different times and confirm both fire.
8. **Your own glass size** — Profile → Hydration. With the unit set to glasses you can now set what
   a glass means to you (50–1000 ml, default 250). Change it and check Home, Track and Nutrition all
   agree on the new count. Your totals should not move — only how they are described.
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
    text, and the old urine-test wording is gone throughout.
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
16. **General** — sign in, complete cycle setup, and sanity-check Home, Insights and Learn.

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

- **Custom-supplement cloud sync** — still local-only, as in 17.
- **Hydration display preferences** (unit and glass size) — device-local, not synced to the account.
  A new phone starts at millilitres with a 250 ml glass. Tracked as task 25; it is one coordinated
  change with Android, because storage is always `waterMl` and only the description differs.
- **Food photography** — the recipe cards ship, but on a coloured gradient rather than a photograph.
  The asset catalogue holds no food imagery at all and stock placeholder art is an App Store
  rejection risk, so the cards were built with a seam for real photography to drop into later.
- **Nutrient counting** — meal logging records food *groups*, not calories, macros or micronutrients.
  Counting needs a food database, which is the deferred barcode/photo work.
- **Food groups on Android, and in your streak** — the column is iOS-only for now, and a day where
  meals are the only thing you log will not extend the daily streak. Both platforms compute streaks
  from one shared rule, and it moves when Android ships the same field.
- **The girl/boy quiz framing** — still held pending written client and medical-reviewer approval to
  remove `"boy or girl"` from `QuizContentTests`. Calendar time, not engineering time.
  *(The Shettles article is no longer on this list: it shipped 12 Aug as week 12 of the series,
  revealed 2026-11-08, and needed no guard relaxed. See G1 in `docs/CHANGE_LIST_PLAN.md`.)*

## Build facts

- Version **1.2.0 (18)**.
- Contains build 17 plus the client change list: T1–T6, T8, T10–T18, T20, T21, T23–T27, T28,
  T29a/T29c, T30, the waitlist wiring, and the privacy/security batch (quiz answers moved off the
  partner-readable `profiles` row; a user can no longer declare themselves someone else's partner).
- **Green baseline:** 236 domain · 233 app · 46 UI (45 + 1 skipped on a simulator that has already
  answered the notification prompt). Verified 12–13 Aug 2026. Do not pass `-quiet` — it has returned
  exit 0 with no summary and hidden a real result.
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
| P0-7 | Verify the live `theme` default | ⬜ Needs the dashboard — pre-flight 5 |
| P0-8 | Backend batch: `delete_account` retention gaps, `unlink_partner` half-clear, auth status codes | ✅ Written and typechecked (`deno check`, all six clean). **Still needs deploying** — pre-flight 4. See `HANDOFF.md` §4i |
| P0-9 | Google sign-in: the `-5` swallow that could hide the failure entirely | ✅ `AuthView.swift` domain-checks `GIDSignInError` now. Do the console read *after* this, not before — see `to do list.md` §1 |

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
