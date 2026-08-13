# TestFlight — Genesyx 1.2.0 (18)

The client change list, end to end. 1.2.0 rather than 1.1.2 because this is a feature batch, not a
fix pass — a weekly article series, intimacy logging, a fertile-window notification, and
per-supplement reminder times are all new surface.

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
- **Logging food groups on Android** — meals now count toward your streak, so a day where meals are
  the only thing you logged keeps it alive, and both platforms compute that identically from the
  same rule. What Android still lacks is the *editor*: it reads, syncs and counts your food groups,
  but iOS remains the only place you can tick them.
- **The girl/boy quiz framing** — still held pending written client and medical-reviewer approval to
  remove `"boy or girl"` from `QuizContentTests`. Calendar time, not engineering time.
  *(The Shettles article is no longer on this list: it shipped 12 Aug as week 12 of the series,
  revealed 2026-11-08, and needed no guard relaxed. See G1 in `docs/CHANGE_LIST_PLAN.md`.)*

## Build facts

- Version **1.2.0 (18)**.
- Contains build 17 plus the client change list: T1–T6, T8, T10–T18, T20, T21, T23–T27, T28,
  T29a/T29c, T30, the waitlist wiring, and the privacy/security batch (quiz answers moved off the
  partner-readable `profiles` row; a user can no longer declare themselves someone else's partner).
- **Green baseline:** 239 domain · 238 app · 57 UI, 0 failures. Verified 13 Aug 2026. Do not pass
  `-quiet` — it has returned exit 0 with no summary and hidden a real result.
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
| P0-16 | **The two clients erase different things from the same database** | ⬜ Found 13 Aug by cross-checking the Android repo, which shares this Supabase project. iOS deletes through the `delete_account` Edge Function; **Android 1.4.0 (`versionCode` 14) calls the `delete_current_user()` SQL RPC** (`SupabaseAuthService.kt:70`). They are not the same contract. **Live state read 13 Aug** via `pg_get_functiondef`, `pg_constraint` and `information_schema.tables`. **Android runs the OLDER RPC body** — the one at `schema.sql:238`, with no `user_supplements` line. That proves only that the function **does not abort**; it is not evidence that deletion is complete. It is not. **Verified cascade coverage: six foreign keys, every one of them `child → auth.users(id) ON DELETE CASCADE`** — `cycle_settings.user_id`, `daily_logs.user_id`, `partner_invites.inviter_id`, `ph_readings.user_id`, `profiles.id`, `quiz_answers.user_id`. So the RPC's final `delete from auth.users` does sweep `quiz_answers` and `partner_invites`-by-`inviter_id` even though the body never names them, and **Android erases six of the seven live tables**. **It is incomplete in exactly three places, and all three are the places with no foreign key:** (a) `partner_invites` addressed TO her by `invitee_email` — `text`, no FK, so nothing cascades it, and `partner_invites_owner` is `inviter_id = auth.uid()`, meaning she could never see or delete those rows even while her account existed; (b) `waitlist_emails` — keyed by `email` text, no FK, survives forever; (c) **the reciprocal partner link, which is the one that surprised me.** `pg_constraint` on `public.profiles` returns exactly two rows, `profiles_pkey` and `profiles_id_fkey (id → auth.users ON DELETE CASCADE)`. **There is no foreign key on `partner_id` at all.** `docs/supabase_schema.sql:21` declares `partner_id uuid references public.profiles (id) on delete set null`; **that constraint was never deployed.** The RPC never touches `partner_id` and no cascade does it either, so her partner's row keeps a pointer to a profile that no longer exists — a stuck "connected" state he cannot clear, because `profiles_update` only lets him write his own row and the pointer is the thing that is wrong. iOS is unaffected: `delete_account` nulls the partner's pointer explicitly as its first step (`index.ts:39-46`) instead of trusting a cascade, and matches invitee emails case-insensitively with an `ilike` narrow plus an exact compare so a stranger's invite cannot be taken with it. **`accepted_by` does not exist** — live `partner_invites` has seven columns (`id`, `inviter_id`, `invitee_email`, `code`, `status`, `created_at`, `expires_at`), so there is nothing for it to cascade or null, and acceptance is recorded only by mutating `status`. **`user_supplements` is NOT a deletion orphan** — the live table is absent, so there are no rows to strand, and adding it to the iOS list would abort `delete_account` on a missing relation and break deletion for everyone. Leave the iOS list alone. The missing table is a different bug entirely — see P0-17A. **Live blast radius of (c) today is zero:** `count(*) filter (where partner_id is not null)` is **0**, nobody is linked yet, which is exactly why it is cheap now and expensive once the feature is used. Preferred fix is the explicit unlink in the RPC rather than adding the FK — it matches iOS and does not depend on a constraint that has already proven it can go missing. **✅ Fixed 13 Aug by migration A, `20260813_delete_current_user_hardening.sql`, applied to production.** The new body unlinks every row pointing at her (`where partner_id = v_uid`, which also survives a one-directional or already-stale link), deletes invites addressed to her and her waitlist row by normalised email, and pins `search_path = ''` with every identifier schema-qualified. Post-apply reads confirm `prosecdef = true`, `proconfig = {search_path=}`, execute revoked from `anon` and `PUBLIC`, and — the pre-apply risk — `relforcerowsecurity = false` on both `profiles` and `waitlist_emails`, so the definer genuinely bypasses RLS and the unlink reaches rows it does not own. At that point it deliberately never named `user_supplements`: plpgsql resolves relations at run time, and the table did not yet exist, so that single line would have aborted every call. **✅ Superseded later the same day by H1.** Once migration B had created the table, `20260813_user_supplements_delete_backstop_and_push_default_false` spliced `delete from public.user_supplements where user_id = v_uid;` into the deployed body **exactly once**, immediately before the profiles/auth deletion. The explicit backstop is therefore **deployed**, and the cascade is no longer the only thing standing between a deleted account and her supplement rows. Post-apply reads preserved owner `postgres`, `SECURITY DEFINER`, `search_path=''` and EXECUTE for postgres/authenticated/service_role only; every hardened cleanup block survived; `profiles` = 18, `user_supplements` = 1, `genesyx_products` = 0 and `ph_readings` = 61 were identical before and after. **The distinction that matters: `delete_current_user()` was REDEFINED, not EXECUTED.** No account was deleted to get this evidence, and none should be. **So end-to-end deletion is still NOT proven** — tests 2, 3 and 5 need two throwaway accounts and a real deletion against a project holding 18 live profiles including Apple's reviewer, which was never authorised. That is remaining behavioural QA, not missing implementation |
| P0-17A | **Android supplement sync writes to a table that does not exist — data is not restorable** | ⬜ Found 13 Aug. `user_supplements` is absent from the live schema and the only migration that would create it has **never been applied**. Production DI binds the real Supabase implementation whenever credentials are configured (`NetworkModule.kt:139,148`), and they are. So she adds a supplement, it lands in Room as `PENDING_UPSERT` (`UserSupplementRepository.kt:76`), the push fails against a missing relation, `pushOrQueue` **logs a warning and reschedules** (`:98-108`), `syncPending()` returns false, and `UserSupplementSyncWorker` returns `Result.retry()` so WorkManager backs off and retries **forever**. The pull path fails the same way, log-only (`:158`). **The severity is data restoration, not just sync:** nothing has ever reached the server, so a new phone, a reinstall or a sign-in elsewhere shows none of it, and there is no copy anywhere but that one device. **I previously called the wording honest. That was wrong, and it is the opposite.** `ProfileScreen.kt:160` renders *"Saved on your device — they'll sync to your account automatically."* — a promise that is **false** while the table does not exist. The code comment directly above it (`:145-146`) states the lingering count is *"reassuring, not an error"* because the change *"syncs on its own"*; for supplements it never does, so the reassurance is false too, and the "Sync now" button re-runs a drain that cannot succeed. The counter is shared with daily logs and pH, whose tables **do** exist, so the stuck remainder is indistinguishable from a transient queue. **Play exposure: NOT VERIFIED — it needs Play Console, which I cannot reach** (no `adb`, no fastlane, no publish workflow, no app release tags). What the repo does bound: the feature arrived `aecac1a` on **29 Jul**, *after* the 27 Jul bump to `versionCode 13`, and `versionCode 14` was bumped **12 Aug** with the message "for the **next** Play release" (`ab0ebc0`) with six feature commits landing after it. **So if Production and Internal are at 13 or below, no Play user has ever run this code and it is a current-source defect only; if 14 was promoted to any track, testers on that track are losing entries now.** Settle it by reading both track version codes before deciding urgency. **✅ Server side fixed 13 Aug by migration B, `20260813_android_supplements_backend.sql`, applied to production.** `user_supplements` now exists with `user_id → auth.users(id) ON DELETE CASCADE` — so account deletion covers it with no change to either delete path, which is why A and B are order-independent — and `product_id → genesyx_products(id) ON DELETE SET NULL`, because retiring a product must never delete her history. `updated_at` is **nullable on purpose**: `UserSupplementDto.updatedAt` is `String?` and `toDto()` emits `updatedAt?.toString()`, so a `NOT NULL` column would have rejected precisely the rows this migration exists to unstick. Owner-only RLS, both indexes present, table empty. **Not yet proven end to end** — verification test 7 needs an Android build with credentials, and until someone watches that "N changes not synced yet" row reach zero on its own, "the queue now drains" is inference, not evidence |
| P1-1 | `genesyx_products` catalogue table is not created | ⬜ Found 13 Aug, and **deliberately not filed with P0-17A — it is not the same class of problem.** The table is absent live, so the catalogue read fails; but `GenesyxProductRepository.kt:28` catches that and renders the **"coming soon"** empty state, which is *also the truthful answer* — the Genesyx range has zero SKUs and has not launched. Nothing queues, nothing is pending, no user data is at risk and there is nothing to restore. It is a readiness gap, not a data defect: a failed fetch and an empty catalogue are indistinguishable to her, and both are correct today. Worth creating empty anyway, because then real SKUs can be seeded with **no app update on either platform** — which is exactly what the client already built for. **✅ Created 13 Aug by migration B, applied to production** — empty, RLS on, a single `select` policy and no write grant by any route, so seeding real SKUs is a data change rather than a release on either platform. Nothing visible changed: the app still renders "coming soon", which remains the truth |
| P1-2 | **Every new table in `public` is born with `authenticated` holding TRUNCATE** | ✅ Found and fixed 13 Aug, **by my own migration B breaking it first.** This project's schema-level default privileges grant the full `arwdDxtm` to `anon`, `authenticated` and `service_role` at `CREATE TABLE` time. Migration B wrote `grant select on genesyx_products to authenticated` and assumed that *described* the result; `GRANT` is additive, so it described only what was added. The post-apply read showed `authenticated` holding `DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE` on **both** new tables. **`TRUNCATE` is the one that bites: it is not subject to RLS**, so the owner policy that correctly scopes every other verb to her own rows cannot refuse it, and one statement would empty every user's supplements. This is the identical hole `2e07f1f` closed on the other six tables three weeks ago — creating a table silently re-opens it, which is exactly why it is worth a row of its own rather than a footnote. Fixed by making the revoke name `authenticated` as well as `anon` and re-applying; grants now read exactly `SELECT` on `genesyx_products` and `DELETE,INSERT,SELECT,UPDATE` on `user_supplements`, with `anon` holding nothing on either. **Standing rule for this project: after any `create table`, read the ACL back — the failure to look for is an extra privilege, not a missing one.** A "can the client still write?" check passes cleanly while this defect is present |
| P0-15 | **`delete_account` does not revoke the Sign in with Apple token** | ⬜ Found 13 Aug, confirmed by reading `supabase/functions/delete_account/index.ts` end to end — there is no call to Apple's `/auth/revoke` anywhere. Apple requires apps offering Sign in with Apple to revoke the refresh token on account deletion; leaving it live means the relationship persists after she deleted everything. Also in that file: the `waitlist_emails` delete is **best-effort** — on error it logs and falls through, and `{ok: true}` is returned regardless (`:84-108`), so a woman can be told her data is gone while her email is still on the waitlist. **Confirmed live 13 Aug: this is not hypothetical.** `auth.identities` grouped by provider returns **apple 2**, email 15, google 2 — Sign in with Apple is offered *and in use*, so the revocation duty is already engaged for real accounts, not just theoretically by having the button on screen |

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
