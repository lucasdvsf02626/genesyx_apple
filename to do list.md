# Genesyx iOS — To Do List

Written 2026-08-12. Source: status audit against the client change list of 2026-08-10.

---

## READ THIS FIRST

**The live TestFlight build is 1.1.1 (17), cut 29 July from commit `6bc452d`. The change list arrived 10 August. No build carrying any of this work has ever been archived or uploaded.**

Evidence:
- `~/Library/Developer/Xcode/Archives/2026-07-29/Genesyx 1.1.1 (17).xcarchive` is the newest archive. The `2026-07-30` folder is empty. No 1.2.0 (18) archive exists anywhere.
- `docs/HANDOFF.md` §4 task 22: "Ship build 18 to TestFlight | blocked by pre-flight 1–5" (it read "1–3" until 13 Aug, when the table had already grown to five — corrected there and in §3 below).
- `docs/TESTFLIGHT_B18.md` release checklist: P0-2 (commit the working tree), P0-6 (full green regression) and P0-7 (verify live theme default) are all still unticked.

**What this means for the statuses below.** The client's rule was: nothing is "Done" unless it is live in the current TestFlight build and verified on a real device. Build 17 predates the entire change list, so under that rule almost nothing on the list can be Done. Where `HANDOFF.md` and `CHANGE_LIST_PLAN.md` say "shipped", they mean **committed** — not shipped. I have marked **Done** only for items genuinely live in build 17.

**Caveat that applies to every Done below:** I have not verified anything on a real device, and there is no device-test evidence anywhere in the repo. Read every Done as "live in 17, device-unverified".

---

## TOMORROW — do these in this order

### 2026-08-17 morning check — what moved

- **No new archive.** Newest is still `Genesyx 1.1.1 (17).xcarchive` (2026-07-29); the `2026-07-30` folder is empty. TestFlight is unchanged from 2026-07-29. **This is the single fact that has not moved and it is the one that must.**
- **P0-2 done — working tree is clean.** `git status --short` returns only `?? docs/assets/` once the `graphify-out/` cache noise is filtered out. All ~40 files from the baseline are committed.
- **Version bumped as planned.** `project.yml` now reads `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "19"`. HEAD is `fb37e2a release: prepare Genesyx 1.2.0 build 19`.
- **26 new commits since baseline `2e07f1f`.** Notable: `c9aa8ba Withhold partner linking from the 1.2.0 build` (release scope narrowed — the lockdown/deploy order for partner_invites is no longer racing this build), `4ff918b` (password reset via the gate), `d554541` (session ended on Sign-in-with-Apple revoke), `308b8ca` (account deletion stops reporting false success), `07bb619` + `d0b3895` (privacy policy declared).
- **Google `-5` fix is in code**, not just claimed. `AuthView.swift:181-185`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Committed. Not in any shipped build.
- **Supabase held items are committed** — `supabase/migrations/20260812_partner_invites_write_lockdown.sql` in `2e07f1f`, `supabase/functions/revoke_partner_invite/` in `6000f2d`. Applied/deployed state on production was not probed today (out of scope per standing rules).

**Next blocking action (updated 18 Aug 00:05):** upload `build/Export/Genesyx.ipa` to TestFlight. HEAD `8df44db` (1.2.0 **build 20**) is **archived and exported** — signed `Apple Distribution: SF MEDIA & PR LTD`, IPA contents verified (version, privacy manifest, 1024 icon, entitlements); facts and the two archive traps are in `docs/TESTFLIGHT_B20.md` under "Build facts". Build 19 (`fb37e2a`) was superseded the same day by the password recovery flow (`eded1c7`) and the build bump; do not upload 19. The full green regression is **done** on the build-20 tree — 294 domain (`swift test`) and 430/431 `xcodebuild test` on iPhone 17, 0 failures, 1 declared skip. The Supabase Google **Authorized Client IDs** question is **settled** — the iOS client is present, see section 1. What remains is the upload itself, the App Store Connect listing (screenshots, privacy labels, age rating — never audited), and the P0-7 theme-default decision. Sign-in per the 30-second console-read table below is still the gating verification the moment a build reaches a device.

### 1. Fix Google sign-in (blocks everything else)
Nothing can be device-verified until someone can sign in. Current state of the diagnosis:

**Ruled out:**
- The applied grant-cleanup migration. `handle_new_user` is `security definer`, owned by `postgres` (still `arwdDxtm` on `profiles`), so the revokes cannot break signup. GoTrue connects as `supabase_auth_admin` and `/token` never touches the `public` schema.
- Credentials / config. The built Info.plist carries `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `GIDClientID`. My earlier hypothesis that `Secrets.xcconfig` was unwired is dead — the values live in `project.yml` `settings.base`.
- Server-side provider state. `GET /auth/v1/settings` returns HTTP 200 with `"google": true`.

**Leading hypothesis — ❌ DISPROVED 2026-08-18.** The theory was that the Google provider's "Authorized Client IDs" list omitted the iOS OAuth client, so a token whose `aud` is the iOS ID would be rejected. Read directly off the dashboard (Authentication → Sign In / Providers → Google), `EXTERNAL_GOOGLE_CLIENT_ID` holds three comma-separated entries and the iOS client is the **third**: `…-ad6b9oe6lsbt3hvhfng6h45vht4eq2ge` (web), `…-foh3v0ssm46stsc5d2klato8ivif96k5` (android), `…-tfah1knspa8ip82p51c3i3veuh3ljul4` (**iOS**, matches `project.yml:67`). The field renders truncated to the first entry, which is why every earlier glance at it looked wrong. "Skip nonce checks" is also **on**, which native iOS Google Sign-In requires because the client cannot supply the nonce Supabase would otherwise verify.

So the server config is correct and this is no longer a candidate cause. If Google sign-in still fails on a device, the fault is client-side or in the Google SDK — read the console table below rather than re-checking this list.

**Google Cloud half of the hypothesis — verified 2026-08-17.** The iOS OAuth client "Genesyx iOS" (created 8 Jul 2026, `413702980668-tfah…`) exists and matches `project.yml:67`. Exactly one web client ("Web client 1", `413702980668-ad6b…`) exists — this is what `genesyx.googleWebClientId` should point to. No OAuth errors in the Google Cloud logs, but traffic is TestFlight-level (≤2 requests/day) so absence of errors proves nothing about end-to-end sign-in. **The check that remains is the Supabase side only:** Authentication → Providers → Google → *Authorized Client IDs* must contain the iOS client ID above. Redirect URIs on Web client 1 are not load-bearing while the client uses `signInWithIdToken` — they only matter for a hosted / webview OAuth flow, which iOS does not use.

**30-second way to settle it.** Reproduce the failure with the Xcode console open and read the line:

| Console line | Cause |
| --- | --- |
| `[GoogleSignIn] SDK sign-in FAILED: …` | Failure is in the Google SDK, before Supabase is ever called |
| `[GoogleSignIn] supabase signInWithIdToken FAILED: …` | Token exchange rejected — this is the Authorized Client IDs case |
| No `[GoogleSignIn]` line at all after tapping | Silent no-op — see the `-5` defect below |

**Separate real defect found while looking — ✅ FIXED 2026-08-13.** `AuthView.swift:137` was:
```swift
if (error as NSError).code == -5 { return }   // GIDSignInError.canceled — she backed out
```
This matched code `-5` in **any** NSError domain, not just `GIDSignInError`. Any unrelated error that happened to be `-5` was swallowed as "user cancelled" and produced a silent no-op with no error shown. Now domain-checked the way the Apple path at `AuthView.swift:105` already did it:
```swift
if (error as? GIDSignInError)?.code == .canceled { return }
```
Build verified (`BUILD SUCCEEDED`, `AuthView.swift` recompiled, so the typed cast is real and not a stale object file).

**Do the console read anyway, and do it after this fix.** The table above assumes the failure prints a line. It may not have: the third row — "no `[GoogleSignIn]` line at all" — was exactly what the `-5` swallow produced, so the defect above could have been *hiding* the diagnosis rather than sitting beside it. Row 3 now means something different from what it meant when this was written.

### 2. Commit the working tree (~40 files) + full green regression
`TESTFLIGHT_B18.md` P0-2 and P0-6. Nothing ships from a dirty tree.
```
swift test && xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17'
```
Reminders: **do not use `-quiet`** (exit 0 with no summary, hides real results). **Never run two `xcodebuild test` processes at once** — the loser dies with `Test crashed with signal kill`, which reads exactly like a real crash. Check first; never `pkill -9 -f xcodebuild`. Simulator is **iPhone 17** — `iPhone 16` does not exist on this machine.

### 3. Supabase pre-flight 1–5
From `TESTFLIGHT_B18.md`. **This list said "1–3" and the table now has five rows** — two were added
after it was written, and both are load-bearing, so do not stop at three:
1. `daily_logs.sexual_activity` column — ✅ verified present 12 Aug
2. `join_waitlist` RPC + `waitlist_emails` table — migration written, confirm applied
3. `daily_logs.food_groups` column — ✅ **APPLIED 13 Aug**. Was missing; meal logging was failing
   silently (she ticks groups all week, sees them persist locally, syncs none of it). Now
   `ARRAY / NO / '{}'::text[]`, matching `symptoms` and `supplements`. RLS re-checked: unchanged
4. Deploy all six Edge Functions — ✅ **DEPLOYED 13 Aug**. Note this **turned `verify_jwt` ON**:
   there is no `config.toml`, so the CLI default of `true` applied. Confirmed by probe — all six now
   answer an anonymous POST from the gateway, not from their own catch block
5. `profiles.theme` live default — ⬜ **still outstanding**, P0-7 (this is what the old "3" meant).
   Needs `select theme, count(*) from public.profiles group by theme;` and then a decision

Apply with `supabase db query --linked -f <file>`. **Never `supabase db push`** — this project has no `supabase_migrations.schema_migrations` table and push would replay every migration.

### 4. Finish the 1A leftovers
See the 1A table below for exactly what is In progress.

### 5. Bump to 1.2.0 (19), archive, upload
`project.yml` currently reads `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "18"`. Build 18 was never uploaded, so go to 19 to avoid any ambiguity in App Store Connect.

### 6. Device verification pass
The first real-device pass since 29 July. Everything marked Done below is unverified until this happens.

### Also queued (not blocking the build)
- Real Nutrition text pass (2B).
- Partner clarification + sharing scope (1B / 4).
- Streak decisions, agreed with Android (3A).

---

## STATUS TABLES

Status vocabulary: To do / In progress / In review / Done / Blocked. Apple Health, Apple Watch and Oura skipped as instructed — out of scope, no work started.

### 1A — Vaginal pH

| Item | Status | Evidence |
| --- | --- | --- |
| pH tracker as a primary feature | **Done** | `MainTabView.swift:19` — own tab, live in 17 |
| Log a pH reading with date/time | **Done** | `PhTrackerSection.swift:94` |
| Guidance on what the number means | **Done** | `PhCopy.swift:7`, `:28`, `:35` |
| Educational content on vaginal pH | **Done** | `LearnContent.swift:711-717` |
| "Why vaginal pH matters for fertility" | **Blocked** | Reverses a medical-review decision. `LearnContent.swift:767` currently states "It is not a fertility score". Needs the client + medical reviewer to sign off, not an engineering call |
| pH history list | **Done** | `PhTrackerSection.swift:243-271` — collapsible "Reading history (N)" on the pH tab, newest first, every row opens that reading for edit or delete. Covered by `GenesyxUITests.swift:1181` (an older reading opens for editing) and `:1207` (Cancel keeps it, Delete asks first). Cold-start persistence: `RepositoryTests.swift:433`, `GenesyxUITests.swift:1322` |
| pH reminders | **Done** | `NotificationPlanner.swift:293-315` — weekly `.ph` slot with its own copy, scheduled only when a reading is actually due (`phDueAfterDays`), silent when she logged recently. Covered by `NotificationPlannerTests.swift:47`, `:158`, `:197`, `:257`, `:264`, `:449` |

Content guard note: `PhContentGuardTests.swift:9` bans "infection", "thrush", "candida", "vaginosis" and "bv" in pH articles. **"obvious" contains "bv"** — this has bitten before.

### 1B — Tracking / calendar / Profile

| Item | Status | Evidence |
| --- | --- | --- |
| Calendar day markers | **Done** | `DayMarkers.swift`, `TrackView.swift:189-198` |
| Daily log entry | **Done** | `LogView.swift:186` |
| Sexual activity logging | **Done** | `DailyLogRepository.swift:42` — column ⚠️ unconfirmed in prod, see pre-flight 1 |
| Symptoms / notes | **Done** | `LogView.swift:239-259` |
| Partner linking | **Built, WITHHELD from 1.2.0** | Code is complete and was live in 17 (`PartnerRepository.swift:41-47`), but `FeatureFlags.partnerInvites = false` (`LearnModels.swift:21`, commit `c9aa8ba`) gates off the Profile section (`ProfileView.swift:59`), the invite deep link (`RootView.swift:123`) and the refresh (`AppContainer.swift:91,107`). It is a compile-time constant, so **no shipped build can turn it on** — restoring it means editing that line and submitting a new binary. Do not describe this to the client as delivered in 1.2.0 |
| Partner sees name only | **Built, WITHHELD from 1.2.0** | Moot while the flag above is off. When it is restored: true in-app (`ProfileView.swift:173`), but RLS exposes the **whole `profiles` row**. `CHANGE_LIST_PLAN.md:17` overstates the guarantee — needs a decision, see §4 |
| Password change | **Done** | `SupabaseBackend.swift:49` `resetPasswordForEmail`, wired and live in 17. `CHANGE_LIST_PLAN.md:206` says this is unbuilt — **that is wrong** |
| Account deletion | **Done** | `Account.swift:39-42` → `delete_account` edge function |

### 1C — Onboarding

| Item | Status | Evidence |
| --- | --- | --- |
| Quiz flow | **Done** | `OnboardingFlowView.swift:224` |
| Quiz answers persisted | **Done** | `quiz_answers` table ✅ applied (`HANDOFF.md` §2) |
| Girl/Boy option | **Done, iOS only** | `QuizContent.swift:82`. Now Girl / Boy / No preference / Prefer not to say. No compliance guard was relaxed — "Girl" and "Boy" as separate labels never contained the banned string "boy or girl"; the only real blocker was the parity assertion, now `options.count == 4`. **ANDROID MUST MATCH before release** |
| Waitlist capture | **Not reachable** | Backend half only. `joinWaitlist` is declared at `RemoteBackend.swift:220` and implemented at `SupabaseBackend.swift:29`, and `grep -rn joinWaitlist` finds **no call site anywhere in the app** — there is no screen, field or button that collects the email. The missing piece is UI, not the migration |

**Do not rename quiz question ids, or option ids.** Both are storage keys; renaming orphans every stored answer on both clients. The Girl/Boy change kept `either` and `private` for exactly that reason and retired `hope` rather than remapping it — `hope` never recorded *which* sex, which is the distinction the change introduces. A stored `hope` stays readable and renders unselected until she picks again.

### 1D — Connectivity

| Item | Status | Evidence |
| --- | --- | --- |
| Offline logging | **Done** | Local-first repositories, live in 17 |
| Sync on reconnect | **Done** | Upsert path in `SupabaseBackend.swift` |
| Sign-in | **Blocked** | Google sign-in currently failing — see tomorrow's item 1 |

### 2A — Design

| Item | Status | Evidence |
| --- | --- | --- |
| Warm / premium visual pass | **Blocked** | No design spec supplied. Cannot start without one |
| Theme (light/dark/system) | **In review** | `PreferencesRepository.swift:102`. The client-side override bug is fixed and tested (see the two-week plan, item 7). What is still in review is P0-7: the **live** `profiles.theme` default on production, which is a data decision, not a code one |
| Dynamic Type | **To do** | `HANDOFF.md` §4f: the app has **no Dynamic Type support at all** |
| Component consistency | **In progress** | `GenesyxControls.swift:53`, `:215` |

### 2B — Nutrition

| Item | Status | Evidence |
| --- | --- | --- |
| Nutrition screen | **Done** | `NutritionView.swift:133`, live in 17 |
| Greyed-out text behind disclosures | **In progress** | `CHANGE_LIST_PLAN.md:25` claims this is already done — **overstated**. Only one disclosure exists (`NutritionView.swift:148`) and the line reference is wrong |
| Recipes / meal content | **Done** | Eight recipes in `Sources/GenesyxCore/Content/RecipeContent.swift`, selected per cycle phase and rendered at `NutritionView.swift:388-398` with a detail sheet at `:645`. "Blocked — no content supplied" was stale; client content would replace these, not unblock them |
| Banned-phrase compliance | **Done** | `LearnContentTests.swift:217` green |

### 2C — Hydration

| Item | Status | Evidence |
| --- | --- | --- |
| Hydration tracking | **Done** | `HydrationPrefs.swift:16`, live in 17 |
| Unit switching | **Done** | `HydrationUnit.swift:20-28` |
| Custom glass size | **Done** | Implemented. `CHANGE_LIST_PLAN.md:22` says it's missing — **stale** |
| Hydration insight | **Done** | `HomeView.swift:74` |

### 2D — Cycle guidance

| Item | Status | Evidence |
| --- | --- | --- |
| Cycle phase display | **Done** | `TrackView.swift:250-255` |
| Phase-specific guidance | **In progress** | `InsightsView.swift:35` — partial coverage |
| Fertile window | **Done** | `TrackView.swift:1490` |

### 3A — Streak

| Item | Status | Evidence |
| --- | --- | --- |
| Streak counter | **Done** | `StreakEngine.swift:61-69`, live in 17 |
| What counts as an entry | **In review** | `sexualActivity` is deliberately **excluded** from `TrackingEngine.isMeaningfulLog` (`:32-35`) and `StreakEngine.hasAnyEntry`. Flip it in both clients **and** `tracking_test_vectors.json`, or not at all |
| Streak restore after a missed day | **Blocked** | No policy decision from the client |

### 3B — Education

| Item | Status | Evidence |
| --- | --- | --- |
| Weekly article series | **Done** | **Twelve** articles, `w1`–`w12` at `LearnContent.swift:727-1078`; the header saying "the twelve-week run" is correct and the earlier "eleven" count in this file was wrong. Gated by `LearnModels.swift:229`; first article drops 2026-08-23 |
| Article model / rendering | **Done** | `LearnModels.swift:129`, `LearnContent.swift:1040-1068` |
| Science links to the website | **Blocked** | No URLs supplied |
| Medical compliance guards | **Done** | `LearnContentTests.swift:217`, `PhContentGuardTests.swift:9` green |

### 4 — Clarify / scope

| Item | Status | Evidence |
| --- | --- | --- |
| G1 compliance sign-off | **Blocked** | `CHANGE_LIST_PLAN.md` gate list — G1 open, G2/G3/G4 resolved |
| Partner data-sharing scope | **Blocked** | RLS exposes the full `profiles` row; needs a product decision before it can be narrowed |
| Deep links | **Done** | `DeepLink.swift`, live in 17 |

---

## BUILT BUT DORMANT — what flipping each flag actually does

### `FeatureFlags.personalisedSupplementTiming` — currently `false`

Personalises the supplement reminders she already set: **when they fire and how they read, never which supplements she takes.** That boundary is the whole design. Recommending a supplement to a named individual is personalised health advice and needs medical-review sign-off; nudging the hour of an alarm she set herself, and appending a sentence that makes no health claim, needs none. `SupplementPersonalisation.apply` maps her list to itself preserving `id`, `name` and `dose`, so it is structurally incapable of adding or removing one.

With the flag **on**:
- A reminder she is ignoring (≤ 3 days logged in the trailing week) moves toward the hour she is demonstrably awake, **capped at ±2 hours**. Above the threshold it is left where she put it.
- One sentence may be appended: an affirming line at ≥ 5 days, or a pointer to Nutrition for the woman whose `support` answer was `supplements`. A missed week appends **nothing** — there is no sentence about a week of blanks that reads as encouragement, and the reminder still arrives.

Two things it reads that are worth knowing before anyone widens it:
- **Adherence is day-level, not per-supplement.** `DailyLog.supplements` stores display names from a hardcoded list in `LogView.swift:21` (Folic acid, Vitamin D, Iron, Omega-3) while a reminder is keyed `essential.<initial>` or a custom UUID. The two vocabularies don't even describe the same set. Fix the vocabularies before trying to narrow this.
- **The observed hour comes from pH readings**, because `PhReading.recordedAt` is the only wall-clock time this app records — `DailyLog` is keyed by `CalendarDate` and carries no clock at all. A woman who never uses the pH tracker gets no shift, which is correct rather than a gap.

`phase` is plumbed into `SupplementSignals` and **deliberately unread**. Any wording tying a supplement to a phase asserts the supplement does something phase-specific — the same unsupported claim the gender question already had stripped out of it. `SupplementPersonalisationTests.testCyclePhaseChangesNothingUntilAReviewerSaysItMay` fails the moment someone wires it in, on purpose.

Covered by 22 tests in `Tests/GenesyxCoreTests/Notifications/SupplementPersonalisationTests.swift`, including one proving the flag-off path is byte-identical to today's. The dormant copy is already inside `NotificationContent.allCopyStrings`, so the banned-phrase and guilt scans reach it today rather than the day the flag flips.

---

## SHARED SUPABASE — what changed, and whether Android needs anything

| Change | State | Android impact |
| --- | --- | --- |
| `20260812_client_role_grant_cleanup.sql` | **APPLIED to production** | **None.** Revokes everything `anon` held on six tables (RLS already refused it every row — all 8 policies name `{authenticated}`) plus TRUNCATE from `authenticated` (PostgREST has no TRUNCATE verb). Neither is reachable from any HTTP client |
| `20260812_partner_invites_write_lockdown.sql` | Committed, **NOT applied** | **BLOCKING.** Revokes UPDATE + DELETE on `partner_invites` from `authenticated`. Someone must grep the Android client for direct UPDATE/DELETE on `partner_invites` first — a direct PATCH there breaks silently the moment this is applied |
| `revoke_partner_invite` edge function | **DEPLOYED** (v1, ACTIVE, `verify_jwt`) 2026-08-12 | Step 2 of the order below is now done. It had been skipped: `SupabaseBackend.swift:199` already called a function that did not exist, and only the un-applied lockdown was keeping the old direct UPDATE alive |
| `decline_partner_invite` edge function | **DEPLOYED** (v4, ACTIVE, `verify_jwt`) | Writes `status: "declined"`; 409 if not pending, 403 if `invitee_email` ≠ caller |
| `20260812_partner_invite_hardening.sql` | **APPLIED to production**, untracked in git | Verified live: status constraint includes `declined`, `expires_at` exists. Was applied and recorded nowhere — Android should assume both are present |
| `daily_logs.sexual_activity` | ⚠️ unconfirmed | Additive column — backwards-compatible |
| `join_waitlist` / `waitlist_emails` | ⚠️ unconfirmed | New RPC + table — additive, no Android change needed |

**Order of operations for the lockdown, per the migration header:** (1) grep Android → (2) deploy `revoke_partner_invite` ✅ → (3) ship the `SupabaseBackend.swift:199` change → (4) apply the migration. Steps 1, 3 and 4 remain. Step 3 is written but unreleased, so the lockdown must not be applied until a build carrying it is live.

No schema, RLS policy, table/column name, enum or function signature has been changed without flagging. Everything above is either additive or a privilege revoke.

---

## BLOCKED ON YOU

1. **G1 compliance sign-off** — gates the medical/claims-adjacent work
2. **The pH-fertility decision** — item 1A reverses an existing medical-review decision; needs the reviewer, not engineering
3. **Website science URLs** — 3B cannot link out without them
4. **A design spec for "warm / premium"** — 2A cannot start
5. **Recipe / meal content** — 2B
6. **Streak-restore policy** — 3A
7. **The Android grep on `partner_invites`** — gates the lockdown migration
8. **Supabase pre-flight 1–5** — needs a production apply, which I will not do unasked
9. **The Google sign-in failure** — gates *all* device verification. Send me the console line from the table above

---

## TWO-WEEK PLAN

**Week 1 — get a build out.** The single highest-value action is **shipping a build**. Nothing on the change list has ever reached a tester.
1. Fix sign-in
2. Commit the tree + full green regression
3. Supabase pre-flight 1–5
4. ~~Finish the 1A leftovers (history list, reminders)~~ — **already in code.** Both landed before build 19; evidence in the 1A table. Device verification still owed
5. Bump to 1.2.0 (19), archive, upload
6. Device verification pass

**Week 2 — the amendment list proper.**
7. ~~Theme-override bug~~ — **fixed in code.** `clearThemeMigrationFlag()` (`PreferencesRepository.swift:169-171`) is called on sign-out (`AppContainer.swift:131`), and `migrateLegacySystemTheme()` runs after `apply(remote:)` (`:200-201`, `:213-218`) so the pulled `.system` is corrected rather than left standing. Tests: `RepositoryTests.swift:1185`, `:1200`, `:1212`, `:1231`. The separate P0-7 decision on the **live** `profiles.theme` default is still open
8. Nutrition text pass (2B)
9. Partner clarification + sharing scope (1B / 4)
10. Streak decisions agreed with Android (3A)
11. Phase-specific guidance completion (2D)
12. Dynamic Type, if the design spec lands (2A)

---

## WHERE iOS AND ANDROID NOW DIFFER

| # | Area | Divergence |
| --- | --- | --- |
| 1 | `partner_invites` writes | iOS moved revoke to an edge function; Android presumably still does a direct UPDATE |
| 2 | Quiz options | **iOS has shipped 4** — `girl` / `boy` / `either` / `private`. Android is still on 3. Android must add `girl` and `boy`, relabel `either` → "No preference" and `private` → "Prefer not to say", retire `hope` without remapping, and drop the "Did you know?" fact. Reusing the two existing ids is what carries stored answers across |
| 2b | Supplement reminder copy | iOS carries a dormant personalisation layer (`FeatureFlags.personalisedSupplementTiming = false`). No behaviour difference while off; Android needs nothing until it is turned on |
| 3 | `sexualActivity` in streaks | Excluded on iOS by design; must match Android + `tracking_test_vectors.json` |
| 4 | Theme default | iOS corrects a legacy stored `.system` to `.light` once per account and clears the device flag on sign-out, so the next account on the same phone is corrected too (`PreferencesRepository.swift:169-171`, `:213-218`, `AppContainer.swift:131`). Unknown on Android |
| 5 | Waitlist | iOS calls `join_waitlist`; unknown whether Android has the path |
| 6 | Anon-role grants | Cleanup applied DB-wide — affects both, but neither can reach it |
| 7 | Article series | Eleven articles on iOS; Android content set unverified |
| 8 | Deep links | iOS `DeepLink.swift`; Android scheme unverified |
| 9 | Publishable key format | iOS ships `sb_publishable_…`; Android may still be on the legacy JWT anon key (both work) |

---

## TWO CORRECTIONS TO THE TRACKER

1. **`CHANGE_LIST_PLAN.md:206` is wrong.** T19 password change is already built, wired and live in build 17 (`SupabaseBackend.swift:49`).
2. **`CHANGE_LIST_PLAN.md:42,:384` is wrong.** The Girl/Boy blocker is the Android parity assertion at `QuizContentTests.swift:30`, not the "boy or girl" banned phrase.

Also minor: `CHANGE_LIST_PLAN.md:22` (custom glass size) and `:25` (Nutrition disclosures) are stale/overstated, and `LearnContent.swift:5` says twelve weeks where there are eleven.

---

## STANDING RULES — do not break these

- **Do not quietly edit the guard tests.** `LearnContentTests`, `QuizContentTests`, `NotificationTests`, `RealInsightsTests`, `HydrationInsightTests`, `NutritionHydrationTests`, `PhContentGuardTests`. Relaxing them is a client + medical-reviewer decision.
- Banned phrases: "sex selection", "boy or girl", "gender sway", "sway the sex", "choose the sex", "alkaline diet", "balance your ph", "detox", "flush toxins". pH articles additionally ban "infection", "thrush", "candida", "vaginosis", "bv".
- **Never `supabase db push`.** Every migration here is applied by hand with `supabase db query --linked -f <file>`.
- **Never run two `xcodebuild test` processes at once.** Never `pkill -9 -f xcodebuild`. Never `-quiet`.
- Simulator is **iPhone 17**.
- **`Application failed preflight checks` / `Busy` is not a test failure.** `xcodebuild` exits 65 and prints `** TEST FAILED **` with zero `error:` lines — that is a stuck simulator, usually after a back-to-back run. Fix: `xcrun simctl boot <udid>` → `bootstatus -b` → `simctl uninstall <udid> com.genesyx.app`, then re-run. Read the `Testing failed:` block before believing a red result.
- **Never mask the exit code.** `xcodebuild … | tail -60` reports 0 on a failed build because the pipe's status wins. Redirect to a file and check `$?` on its own.
- Correct repo path is **`genesxy_apple.V1.02`** (x before y). `~/genesxy_apple` is a stale June checkout — never work or deploy from it.
- Do not guess. If it cannot be confirmed from the repo or Supabase config, mark it **Not verified**.
