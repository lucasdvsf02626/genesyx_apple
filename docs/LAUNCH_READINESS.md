# Launch readiness — 17–18 August 2026

**Question:** is the app ready to launch, and what is left for Lucas to finish?

**Short answer: the app itself is in good shape. The submission is not.** Every blocker that remains is either off-code work only you can do, a decision only you or the client can make, or one live check I cannot run from the repo. No feature work is outstanding for the agreed scope.

> **Read §9 first if you have read this document before.** On 18 August three of the hard blockers
> were closed in code — Article 9 consent, Sign in with Apple revocation, and the pregnancy
> placeholder. Their operational halves were then closed the same day: the `consent_events` migration
> is applied to production and visible to PostgREST, and the Apple secrets are set with
> `delete_account` deployed. §9.7 carries the state sync and the probe evidence. What is left before
> upload is legal sign-off on the consent wording, the on-device passes, and the App Store Connect
> metadata — not code.

This document supersedes `WHATS_LEFT.md`, which is stale (11 Aug, written when the plan was still a local-only v1 with no backend).

> **Sending something to the client?** Send [`HOW_THE_APP_WORKS.md`](HOW_THE_APP_WORKS.md), not this
> file. It is the plain-English product report — every tab's purpose, the goal of each feature, how
> the parts connect, and what a real first week looks like — written to be read and signed off
> without an engineer in the room. This file is the engineering and submission view, and it names
> risks that are yours to weigh, not theirs.

---

## 1. Customer walkthrough — I used the app as a customer would

New in `App/GenesyxUITests/CustomerWalkthroughUITests.swift`. Ten tests, all passing, each one
falsified — the behaviour was broken, the test was watched to fail with its intended message, and
the behaviour was restored.

| What a customer does | Result |
|---|---|
| Opens the app and taps every tab, left to right | **All 7 tabs render their own screen** — Home, Track, pH, Nutrition, Insights, Learn, Profile |
| Checks nothing is buried | **All 7 stay on the bar. No "More" overflow.** Every tab is tappable |
| Leaves a tab and comes back | **Her screen is still there** — state survives switching |
| Taps into a screen and backs out | **The tab bar comes back**; she is never stranded |
| Opens the app and logs a glass of water on her first evening | **Works with no setup** |
| Taps near the bottom of the screen | **Only the front tab takes the touch** |
| Opens pH and asks *"what can I actually do?"* | **She can scroll to everyday support guidance** — proved reachable, not merely present |
| Opens pH and asks *"but what **is** this number?"* | **She can now reach the explainer** — the tab had no route into the pH Learn content at all |
| Opens Learn looking for *"how do I use this app?"* | **The how-to index opens, and its rows open the guide** — proved end to end, because an index whose rows go nowhere looks perfectly healthy in a screenshot |
| Is on Insights, does not trust what she is reading, and wants it explained | **The inline link crosses tabs and lands her inside the explainer** — not on the Learn list wondering why she is there |

**Why this needed writing.** The existing `testTabNavigation` tapped each tab and then asserted the *tab button* still existed — which is true whether the tab rendered correctly, rendered blank, or rendered the previous tab's content, because the bar is drawn outside the tab area. Nothing in the suite had ever asserted that tapping Insights puts Insights on screen. It does. Now it is proved.

### One thing I found and could not settle from here

All seven tabs are built at once and stacked, so **343 pieces of text are in the accessibility tree simultaneously** — every tab's content, all the time. Inactive tabs are drawn at `opacity 0` and correctly refuse touches, which is what matters for a sighted user, and that is now asserted.

Whether **VoiceOver** skips the stacked-behind tabs is a different question. It normally does skip fully transparent views, so this is probably fine — but `.accessibilityHidden(true)` demonstrably does *not* propagate past the `NavigationStack` inside each tab (I tested both modifier orderings; the tree was identical at 343 either way), so the app is relying on the opacity behaviour rather than on the explicit guard it thinks it has.

**This needs sixty seconds on a real device with VoiceOver on** — see §4. If VoiceOver reads content from tabs she is not on, the app is effectively unusable with VoiceOver and that is a launch blocker. If it skips them, there is nothing to do. I do not want to guess either way.

### A second thing I found and could not settle from here

**No Profile `rowItem` button can be made to fire under XCUITest.** This is not caused by anything changed today, and it needs a manual check.

What I measured, across roughly eight diagnostic runs:

- `app.buttons["How to use Genesyx"]` on Profile reports `exists = true`, `isHittable = true`, and a real frame of `(36.0, 544.67, 329.0, 17.33)`. So the test can see it and believes it can press it.
- Tapping it does nothing. The router value it should set is never set — confirmed by then switching to Learn and finding no pushed screen.
- **The same is true of rows that have shipped for months.** `rowItem("Privacy & Data")` produces no alert. `rowItem("Health Profile")` produces no sheet.
- **`navRow` NavigationLinks on the same screen work fine** — `navRow("Medical Sources & Disclaimer")` pushes correctly every time.
- `press(forDuration:)`, tapping by normalised coordinate, slow scrolling, and a 1.5-second settle all failed to change it.

**My read:** this is an XCUITest limitation with this particular plain-styled `Button` construction, not a real defect. Three pre-existing rows behave identically, and an app whose Personal Details and Health Profile rows had never opened would not have got this far. But *"I am fairly sure"* is not the same as *"I checked"*.

**What this means practically:** the Profile → "How to use Genesyx" row is the one new route in this feature that is **not** covered by an automated test. The other two routes into the same screen — the Learn tab card, and the four inline tab links — are both proved end to end, so the feature is reachable regardless. **Please tap these four rows once on a real device** (see §4): How to use Genesyx, Personal Details, Health Profile, Privacy & Data. Thirty seconds, and it settles both this and whether an existing defect has been sitting there unnoticed.

---

## 2. What I fixed today

All proved by falsification — the fix was removed, the test was shown to fail with its intended message, the fix was restored.

| | Defect | Was |
|---|---|---|
| **R1** | Tracker's Nutrition row counted supplements only | She ticked six food groups, opened Track, and read *"No entries yet"* |
| **R2** | Supplement plan and tick-list were different lists | **Zinc could never be logged**, so "4 of 4" was unreachable; Iron counted toward a plan it was not in |
| **R4** | pH chart scaled to the full 3.8–7.0 range | **78% of the chart was amber** and every real reading sat in the bottom 19% — a flat line on the floor of a warning-coloured box |
| **R5** | Water target hardcoded in two places | A silent divergence waiting to happen |
| **R6** | Theme migration flag latched per *device* | Second account on a shared phone landed in dark mode, never seeing the palette |
| **R7** | Phase card linked to the same article in all four phases | The one card whose subject is *"this has changed"* pointed at something that had not |
| **R8** | Peak day never named on 21/22/23/24-day cycles | Ovulation falls inside the period on short cycles, and the copy asked the phase instead of the day |
| **1A row 6** | The pH tab could say *when to worry* in five places and *what she might do* in none | The only "support" on the tab was a supplements link |
| **L14** | The pH tab had no route into the pH Learn content | Four guides pointed *into* the tracker; the tracker pointed nowhere back, so its own sections leaned on background she could not reach |

**On 1A row 6.** New copy on the pH spine: warm water only, unscented products, cotton, not douching — mostly about leaving well alone, which is the honest advice — plus *"a pharmacist can help — no appointment needed, and it's a very ordinary thing to ask about."* Shown before she has logged anything, since that is when she is most likely to want it. **This is new health-adjacent copy and should go to your clinician** with the PDF and the website pages.

**On L14, and a near-miss worth knowing about.** The pH tab now links to *"Understanding your vaginal pH"*. The obvious article to link was *"What your vaginal pH is actually telling you"* — and it would have shipped **dead**: it is dated **30 August**, and Learn hides anything dated ahead, so the link would have compiled, switched tab, and left her on an "unavailable" screen. Nothing would have thrown and no existing test would have noticed. Both new tests were falsified against that exact article rather than an invented break, so they are proved to catch the real thing. The same route was added to the pH sheet reached from Track, so the dead end is closed on both surfaces.

While writing the support copy I found the banned-phrase guard had been **scanning less than it appeared to**: it held its own hand-written copy of the string list, so every constant added to `PhCopy` after the guard was written was unguarded, and nothing failed to say so. It now reads the registry. A guard that passes because it is looking at less is worse than no guard, because it reports success.

**Suite:** `swift test` **294 / 0** · `xcodebuild build` **BUILD SUCCEEDED** · app unit tests
**306 / 0** · app + UI **90 / 0** (1 skipped) · **`** TEST SUCCEEDED **`**, in 996s.

That run is the one to quote: it started after the last source edit and **no `.swift` file was
touched while it ran**, so it describes the tree as it stands rather than a tree that has since
moved on.

Earlier green runs were discarded rather than quoted: each started before some of the day's edits,
so each described a tree that no longer existed. A green result for the wrong tree is worse than no
result, because it reads as reassurance.

**Re-running the suite is what caught the one thing a single run would have shipped.**
`LifecycleE2ETests.testSignOutDoesNotBlankMedicalSources` went from green to reliably failing — not
an app regression, and not the theme fix (reverting that left it failing at a different line). The
cause is the **iOS save-password sheet**: the test dismissed it with a single timing-sensitive
check, so a sheet arriving a moment later covered the next row. It only became reproducible once
the simulator had accumulated saved credentials from repeated runs — **the state a CI machine
reaches and a fresh laptop does not.** Guarded and re-proved; three consecutive passes with that
credential state still present, and failing again with the guard removed.

---

## 3. Your list — what you must finish

Ordered by what unblocks the most. Items 1–3 are the true critical path.

### 🔴 Hard blockers — nothing ships until these are done

**1. ~~Decide the UK GDPR Article 9 lawful basis.~~ BUILT IN CODE, 18 Aug 2026 — copy still needs legal sign-off.**
The live policy claims **"Article 9(2)(a) explicit consent"**, and as of build 21 the app now does what the policy says: an unticked agreement screen before the first health question, a persisted event trail with version and timestamp, a withdrawal control in Profile, and a repository-level gate that stops every health write the moment she withdraws. **The mechanism is closed; the wording is not.** The copy in `ConsentPolicy` was written to be legally defensible but has not been reviewed by a lawyer — see §9.1 for exactly what it says and what remains open.

**2. ~~Sign in with Apple `/auth/revoke`.~~ CLOSED, 18 Aug 2026 — code, secrets and deploy all done.**
The edge function revokes before it destroys anything, and the iOS client now collects a fresh Apple authorization code at the delete confirmation and sends it. **Done, 18 August 2026:** all five secrets (`APPLE_TEAM_ID`, `APPLE_CLIENT_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_REVOKE_REQUIRED=true`) are set with real values and confirmed present via `supabase secrets list`, and `delete_account` is deployed. The `.p8` was handled through Supabase secrets only — it is not in this repo, this doc, or any transcript.

One consequence of `APPLE_REVOKE_REQUIRED=true` being live now rather than after the upload: the function is no longer inert on that path, so **an Apple-signed user deleting from a build older than 21 will fail the deletion** — those clients send no authorization code, and the flag makes a missing code fatal by design. **Reviewed and kept deliberately on 18 Aug 2026**: nothing has ever shipped publicly, so the only pre-21 installs are the client's own TestFlight accounts; the failure is a refusal before any data is touched, not a partial delete; and it self-closes when 21 goes live rather than leaving a flag someone must remember to flip. Full reasoning in §9.2.

**3. ~~Deploy `delete_account`.~~ DONE, 17 Aug 2026.**
Live at **v10 ACTIVE**, bundle byte-identical to the repo, verified by `supabase functions download` and diff. Evidence in §6.1; committed as `b78eee6`. This entry is kept struck through rather than deleted because two other documents still reference it as outstanding.

**3b. ~~Deploy the three invite Edge Function fixes.~~ DONE, 17 Aug 2026.**
`accept_partner_invite` (v8 → **v9**), `decline_partner_invite` (v6 → **v7**) and `unlink_partner` (v7 → **v8**) are deployed to production, all ACTIVE, all `verify_jwt=true`, each deployed on its own with the diff confirmed first and the deployed source downloaded and diffed byte-for-byte against the repo afterwards. Production no longer runs the versions where the invite ownership check failed to fire for an account with no email, or where unlinking could sever a third party's link. Full evidence in §8.6. No other function was redeployed.

**4. Verify the password-reset email end to end.** *One live check — I cannot do it from the repo.*
`resetPasswordForEmail` is called with **no `redirectTo`**, and the app has no recovery deep-link handler and no set-new-password screen. The email therefore lands on whatever the Supabase project's **Site URL** is — which is outside this repo. Meanwhile the app tells her *"Check your inbox."*
**→ Trigger a real password reset against production and follow the email.** Tell me what you see. If it does not land somewhere that works, every woman who forgets her password is locked out, and I will build the in-app recovery screen.

**5. ~~Bump the build number.~~ DONE, 17 Aug 2026.**
`project.yml` reads `CURRENT_PROJECT_VERSION: "19"` and `MARKETING_VERSION: "1.2.0"`. `xcodegen` was run: `Genesyx.xcodeproj/project.pbxproj` carries `CURRENT_PROJECT_VERSION = 19` in both configurations with no `18` remaining, and it is committed and clean. The release commit is `fb37e2a`. The staging advice below is kept because it still applies to every future release commit.

**5b. The release candidate is archived.** *Found 17 Aug 20:00 — `to do list.md` still says "No new archive", and that line is spent.*
`~/Library/Developer/Xcode/Archives/2026-08-17/Genesyx-1.2.0-b19.xcarchive`, created **12:48 GMT**, `CFBundleShortVersionString 1.2.0`, `CFBundleVersion 19`, `com.genesyx.app`, arm64, signed **Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)**.
**It is a faithful build of the release commit.** `fb37e2a` landed at 12:29, the archive was cut at 12:48, and the only two commits since (`b78eee6` at 16:36, `b6907c5` at 16:50) touched one Supabase function file and one document. No `App/` or `Sources/` file has changed since the archive, so it does not need recutting. The three Edge Function fixes deployed later this evening are server-side and reach this build without a new binary.
**What is not established from here:** whether it has been uploaded to TestFlight or App Store Connect. That needs the browser. Note also that the signing identity is *SF MEDIA & PR LTD* while the live privacy policy names *Genesyx Ltd* as data controller — those are allowed to differ, but the App Store listing and the policy should be checked to say the same thing as each other.
**The thing to know before any release commit:** `graphify-out/` is **tracked and not in `.gitignore`** — it accounts for the overwhelming majority of changed entries at any given moment, so a bare `git add -A` would put more generated cache than product into the commit. `docs/assets/` (a duplicate copy of the guide PDF) is deliberately excluded too. Neither is a mistake to correct: `graphify-out/` is committed at the client's explicit instruction, so do not add it to `.gitignore` and do not `git rm --cached` it.

*The 47-uncommitted-changes warning that stood here is spent — those changes were committed as `fb37e2a`. The staging discipline it argued for is not.*

Stage by directory rather than by listing 47 paths — the four product roots are exactly the ones that matter, and this cannot pick up `graphify-out/` or `docs/assets/`:

```
git add App Sources Tests Genesyx.xcodeproj/project.pbxproj docs/*.md docs/website
git status --short          # expect exactly 47 staged, none under graphify-out/ or docs/assets/
```

*Verified by dry run on 17 Aug: 47 paths, 0 under `graphify-out/`.*

`project.pbxproj` is named explicitly because it is generated by `xcodegen` but **must** be committed — it is what Xcode actually builds from. Regenerate it *before* staging, since the build-number bump only reaches the build through `xcodegen generate`.

**6. Real-device pass.** *Yours — needs a physical iPhone.*
Email, Google and Apple sign-in; then delete the account. The simulator cannot prove Sign in with Apple. Your own docs say both must be tested on a real device before submission, and this is currently deferred because there is no device.

**7. App Store Connect data entry.** *Yours, all off-code.*
Privacy labels · age rating questionnaire · regulated-medical-device declaration · DSA trader status · Privacy Policy URL · content rights & encryption · **a demo account in the Review Notes** (the app is behind an auth gate — without one, review will be rejected on Guideline 2.1 without ever seeing the app).

**8. Fresh screenshots from the release candidate.** *Yours.*
The currently uploaded set predates the auth gate and the partner-flag change. Your two docs disagree about whether this is done — `APP_STORE_SUBMISSION.md` ticks it, `FINAL_APP_STORE_RELEASE_CHECKLIST.md` says take new ones. **The checklist is right; treat the tick as void.**

### 🟠 Content — needs your clinician, not an engineer

> **All four of these are now assembled into one document you can forward as-is:
> [`CLINICAL_REVIEW_PACK.md`](CLINICAL_REVIEW_PACK.md).** It contains the new copy verbatim, the
> specific questions to ask about each item, and the one piece of copy (M1) we deliberately did not
> write because only the clinician can say what may be claimed. You should not need to assemble
> anything yourself.

**9. Medical sign-off on the bundled PDF.** Plus four corrections still open: title metadata, the *"Download **out** free app"* typo, remove the page-20 QR, and accessibility tagging.

**10. The two website science pages.** Drafted in `docs/website/WEBSITE_PLAN.md`. **Must not be published until a suitably qualified clinician has reviewed and signed them off.** Two in-app content items are waiting on them:
- **M1** — pH's relevance *to fertility*. The copy currently stops at *"a signal of intimate wellbeing"* and never connects to fertility, which is the section's whole purpose.
- **M2** — the in-app links to the science page and the Shettles page. Do not ship these links until the pages are live, or they 404 in front of a reviewer.

**11. 1A row 6 — vaginal-health support guidance.** **Now written** (see below) — but it is new health-adjacent copy, so send it to the same clinician as items 9 and 10. It needs a read, not a rewrite.

### 🟡 Decisions only you or the client can make

**12. Article 7 ships as week 12** — get the reordering confirmed in writing, or reorder it.
**13. The 12-week plan is anchored to absolute dates** (23 Aug – 8 Nov 2026), not to install date. Decide what a woman who installs in October sees, and what happens to the plan after 8 Nov. **This has a live consequence today:** because the articles are date-gated, most phase-specific reading is not yet resolvable, and the Nutrition phase card falls back to a general article until each date arrives.
**14. Two different numbers are both labelled "streak."**
**15. The compliance guard bans "vaginosis" in prose, but the pH tab displays it as a link label.** Raise with the medical reviewer.
**16. Add Resend to the live privacy policy, or move it to the EU region.**

### 🟢 Not blocking — my list, not yours

The Profile `rowItem` device check (§1 — thirty seconds, and it may turn out to be nothing),
R5's full fix (a hydration goal field in Profile), the remaining low-severity findings in the audit
(**L12 and L13 are now closed**, L15 is partly closed — the new pH support signpost triggers on
symptoms with no reading threshold, so a woman with symptoms and normal readings is no longer told
nothing), the `daily_logs.date` column-type check, an accessibility label on the cycle pencil.

---

## 3b. Two things I found scanning for review risks

Apple **Guideline 2.1 (App Completeness)** rejects placeholder content. I scanned every shipping screen for it. Two results, neither fatal:

**~~A reviewer can reach a "Coming soon" screen.~~ CLOSED, 18 Aug 2026.** `PregnancyView` was reachable from the "Pregnancy" segment in Profile's *Current focus* control, and ended with *"Coming soon — we'll let you know the moment it's ready."* The teaser was honestly built, but the segment beside it read as a mode she could switch into, and there was nothing to switch into: no screen in the app behaves differently in pregnancy mode.
**Now gated behind `FeatureFlags.pregnancyMode = false`,** a compile-time constant on the same pattern as `partnerInvites`. With it off, the focus control is not rendered at all (with pregnancy gone there was exactly one option left, so the control had nothing to choose between) and the Home pathway link — already commented out — is now a real flag gate rather than dead text. The view and `FocusMode.pregnancy` stay compiled, because `profiles.focus_mode` is shared with Android. Asserted by `testThePregnancyPlaceholderIsUnreachableInAShippingBuild`.

**`PlaceholderScreen.swift` is dead code.** *"Temporary screen for tabs not yet translated"*, rendering *"{title} coming soon"*. Nothing references it anywhere in `App/` or `Sources/` — every tab it was written for now exists. It is compiled into the binary but unreachable, so it is **not** a review risk. Flagging rather than deleting, since it is not part of what you asked me to change.

---

## 4. Manual checks I cannot run from here

Five minutes on a real device, and they close real risk:

0. **Tap four Profile rows** — How to use Genesyx, Personal Details, Health Profile, Privacy & Data. XCUITest cannot fire any of them, including three that have shipped for months (see §1). Thirty seconds, and it settles whether that is a test-harness limitation or a real defect nobody has noticed.
1. **VoiceOver on, swipe through Home.** Does it ever read content from Track, Nutrition or pH? (See §1 — this is the open question.)
2. **Password reset**, all the way through the email. (Blocker 4.)
3. **Sign in with Apple**, then delete the account, then try to sign in again.
4. **Dynamic Type at the largest accessibility size** — the seven-tab bar has ~53pt per tab against a ~48pt widest label, which is tight by design.
5. **Airplane mode**: log a reading, restore the network, confirm it syncs rather than silently disappearing.

---

## 5. Honest verdict

**The app is ready. The submission is not.**

The code is in the best state it has been in: **Core 294 / 0, app 315 / 0, UI 93 / 0 — a full sweep over one tree, no flakes and no retries** (17 Aug, 10:26–10:44). Seven working tabs proved by an actual customer walkthrough, seven real defects closed — two of which (Zinc unloggable, the tracker blind to food groups) would have been noticed by any attentive user in her first week — and the app's own how-to guides are now findable instead of being buried behind a category chip.

What stands between here and the App Store is **one legal decision (Article 9), the Apple `/auth/revoke` work, one live check on the password email, a real-device pass, and a data-entry session in App Store Connect.** None of it is engineering risk. All of it is unavoidable.

*Updated 17 Aug, three times. The build-number bump and the `delete_account` deployment came off this list first. The C1 migration and the invite-function deployment were added to it after it was written, and both are now off it too: C1 and C2 are applied and verified live (§6.3), and the three invite fixes are deployed and source-verified (§8.6). **Every server-side item this document ever raised is closed.** What is left is one legal decision and a set of human actions on a device and in a browser.*

*Also verified 17 Aug, 20:05: `xcodebuild -configuration Release` on the current tree returns **BUILD SUCCEEDED**. This is worth stating separately from the test numbers above, because a green suite does not prove the app compiles for release — the suites and the release build are different configurations, and it is possible to pass every test in a tree that will not archive.*

*And re-run end to end on the evening tree, 20:06–20:24, after the Edge Function deploys: **Core 294 / 0** (`swift test`), **app + UI 407 passed, 0 failed, 1 skipped of 408** on iPhone 17 (`xcodebuild test`, 17 minutes, `TEST SUCCEEDED`). **702 tests, zero failures.** The single skip is `NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission`, which needs a real notification-permission prompt the simulator will not raise. It is a known structural skip rather than a regression, and it is the one notification behaviour still resting on the real-device pass (§3 item 6). The full UI suite was run rather than the two fast suites, deliberately — those run in about a second and 25 seconds respectively and are blind to SwiftUI assembly faults.*

The one thing I would not skip is **the VoiceOver check** — it is sixty seconds and it is the only finding where I genuinely do not know the answer. Tap the four Profile rows while the phone is in your hand (§4 item 0); that is the second.

---

## 6. Production verification — account deletion, 17 August 2026

Run against the live project `epltxklawpcxxbaleswg` over the REST API using the public anon key. No
service-role credential was used, retrieved or searched for at any point.

### 6.1 Deployment

| Item | Evidence |
|---|---|
| `delete_account` version | **10, ACTIVE** (was 8 at the start of the day) |
| `verify_jwt` | **true** |
| Bundle SHA | `2202278b4216a57832ad26b439c23ddafb7ca8e030b2eafc63d2d578415af6af` |
| Deployed at | 17 Aug 2026, 15:30:24 UTC |
| Deployed source vs local | **Byte-identical**, including `_shared/client.ts`. Verified by `supabase functions download` into a scratch directory, then diff. |
| Stale banner | **Gone.** 0 occurrences of "NOT YET DEPLOYED" in the deployed source. |
| Apple revocation logic | **None present.** Greps for `revoke`, `apple`, `p8`, `client_secret`, `audience` return nothing across all 136 lines. No secret was added or modified. |

The banner was accurate right up until this deployment, which is why v9 still carried it: the first
deploy went out at 15:13:15 UTC and the comment was removed afterwards. The v10 deploy is the one
that made the file and the live function agree.

### 6.2 End-to-end deletion, with a bystander control

Two fresh accounts were created and seeded identically with six rows each across `profiles`,
`cycle_settings`, `daily_logs`, `ph_readings`, `user_supplements` and `partner_invites`. One was
deleted. The other was touched by nothing.

| Check | Result |
|---|---|
| Deletion response | `{"ok":true}`, HTTP 200 |
| Deleted account can re-authenticate | **No.** `invalid_credentials`. |
| Bystander kept all six rows | **Yes**, contents intact (`QA-d-supp` present, its invite still `pending`) |
| Bystander can still authenticate | **Yes** |
| Test-account cleanup | **Complete.** All five accounts used across the day are deleted. Local tokens and downloaded source wiped. |

Deleted (subject): `6ef14b59-e89f-4134-935c-ecc3be144cb5`
Bystander (control): `8f2d333b-5241-4b37-a0de-60811c47c90e`

**Limitation, stated plainly.** The zero row counts read back on the deleted account's own token are
not proof the tables are empty, because that token no longer resolves. What supports the claim is
the function's fail-closed structure (every delete is checked, and `{ok:true}` is unreachable unless
all of them succeeded) plus the `on delete cascade` foreign keys in `supabase_schema.sql`. A direct
service-role row audit would settle it outright and has not been run. The uids are listed in §6.5.

Separately proved live: deleting an account also removed the pending invite addressed **to** its
email address, so invitee-side cleanup works. That path has no foreign key and would otherwise be
unreachable forever.

### 6.3 CLOSED — invite write lockdown applied and verified in production

**Status: applied and verified, 17 August 2026.** Reported by Lucas after running
`supabase/migrations/20260812_partner_invites_write_lockdown.sql` by hand in the Dashboard SQL
Editor. Effective privileges for `authenticated` on `public.partner_invites`:

| Privilege | Before | After |
|---|---|---|
| UPDATE | true | **false** |
| DELETE | true | **false** |
| INSERT | true | true |
| SELECT | true | true |

The `information_schema.column_privileges` UPDATE-residue query returned **zero rows**, so the nine
column-level grants measured in the baseline are gone as well as the table-level one. INSERT and
SELECT surviving is the intended outcome, not residue: creating an invite and listing your own stay
direct client operations, still row-scoped by `partner_invites_owner`.

Both halves were checked, and by the right instrument each time — `has_table_privilege` for the
table level, because it is the only one of the two that can report DELETE at all.

**Independently re-verified against `epltxklawpcxxbaleswg` in a second pass**, which reproduced all
four results above and added one more: **`anon` SELECT = false**. That last one is not about this
migration — C2 never touched `anon` — it is further confirmation of C1 (§8.1), whose §2 revokes
every `anon` privilege on this table among five others. Two independent passes agreeing, using the
privilege-level instrument rather than the catalogue view, is what moves this from "reported" to
settled.

**H1 in the dashboard audit (§8) is the same finding as C2 and is CLOSED by this.** That audit read
the pre-apply state; see §8.1 for why the two are consistent rather than contradictory.

**Do not rerun the revoke.** REVOKE is idempotent, so a rerun is harmless, but there is nothing left
for it to remove and running it invites confusion about whether the state was ever settled. It was.

The rest of this section is the record of what was found and reproduced before the fix. It is kept
because it is the evidence the change was needed, not a description of the current state.

---

All three holes documented in that migration reproduced against production before it was applied:

- PATCH `status` to `accepted` succeeded
- DELETE of the row succeeded
- on a re-created invite, `declined` → `pending` succeeded, which is hole (a) verbatim

**Bounded, not a leak.** Row-level scoping still holds, so one account cannot touch another's
invites. Partner linking is withheld from builds 19 and 20, so nothing shipping today runs against
this.

All four gates in that migration's order of operations were clear before it was applied: Android
emits no UPDATE or DELETE on `partner_invites`, `revoke_partner_invite` is deployed (v4 ACTIVE), and
`SupabaseBackend.swift:274-296` routes every invite write through `functions.invoke`.

The connected project reports no recorded migrations, which is why `supabase db push` must not be
used: there is no `supabase_migrations.schema_migrations` table, so a push would replay the entire
repository history against a database whose migrations were all applied by hand.

**Measured baseline before applying (17 Aug 2026, read-only, live project):**

```
has_table_privilege('authenticated', 'public.partner_invites', 'UPDATE') = true
has_table_privilege('authenticated', 'public.partner_invites', 'DELETE') = true
information_schema.column_privileges: UPDATE present on all seven columns
```

**Verification after applying.** Use `has_table_privilege` as the primary check, not
`information_schema.column_privileges`. That view only reports column-grantable privileges
(SELECT, INSERT, UPDATE, REFERENCES), so DELETE can never appear in it and filtering for DELETE
there proves nothing. An earlier version of this plan made exactly that mistake.

```sql
select
  has_table_privilege('authenticated', 'public.partner_invites', 'UPDATE') as can_update,
  has_table_privilege('authenticated', 'public.partner_invites', 'DELETE') as can_delete;
-- expect: can_update = false, can_delete = false
```

Then, separately, confirm no column-level UPDATE residue survives. A table-level revoke does not
remove column-level grants, so this is a genuinely independent check rather than a restatement.

```sql
select privilege_type, column_name
  from information_schema.column_privileges
 where table_name = 'partner_invites' and grantee = 'authenticated'
   and privilege_type = 'UPDATE'
 order by 2;
-- expect: zero rows
```

The migration's own header records `pg_attribute.attacl` as NULL on every column as at 12 Aug, so
zero column-level grants existed then and no column-level cleanup is expected to be needed.

### 6.4 Open production finding — two orphan Edge Functions

`delete-account` and `change-password` (hyphens, v5, both ACTIVE, both `verify_jwt=true`) were
deployed on 12 Aug 2026 at 15:41:52 UTC from a flat `source/index.ts` layout this repository has
never produced. Every maintained function deploys to `source/supabase/functions/<slug>/index.ts`.

Confirmed unused by: iOS source, Android source, the live website and all 12 custom theme scripts,
and the documentation and deployment scripts in both repositories. Every apparent hit was a false
positive, either the website URL `genesyx.co.uk/pages/delete-account` or a log string. Auth hooks are
structurally ruled out, since both functions require a user bearer token rather than a signed GoTrue
payload. Not yet confirmed: invocation logs and any external or scheduled caller, both of which need
the dashboard.

**Sweep re-run and strengthened, 17 Aug 2026.** The Android result is better than "no references".
Grepping the Android sources for any Edge Function call at all — `functions.` and `invoke(` across
`app/src/main/kotlin` — returns **nothing**. Android does not invoke a single Edge Function on any
slug. It deletes accounts through the `delete_current_user()` SECURITY DEFINER RPC
(`SupabaseAuthService.kt:69`) and changes passwords through native supabase-kt calls
(`SupabaseAuthService.kt:83-101`). So these two orphans cannot be reached from Android by any path,
not merely by these two names. On the iOS side the only surviving hits are this document's own text.
Auth hooks are now settled as well: the dashboard audit found none configured, which closes the last
structural doubt.

**Source archived, 17 Aug 2026** — the precondition for removing them. Both were downloaded from
production with `supabase functions download <slug> --use-api --workdir <scratch>` and committed
verbatim, with provenance headers, to `docs/archive/edge-functions-orphans/`. The scratch workdir
matters: `functions download` has no output-path flag and writes into `supabase/functions/<slug>/`,
so run from the repo it would have overwritten the fixed sources sitting there undeployed. They are
filed under `docs/` rather than `supabase/functions/` for the same class of reason — a bare
`supabase functions deploy` with no slug deploys every directory under `supabase/functions/`, which
would have resurrected them.

```
docs/archive/edge-functions-orphans/delete-account.index.ts    sha256 5b47a71015d548030202bc4ca1281e99570a0cbfb9294842ee8399793d8e58ad
docs/archive/edge-functions-orphans/change-password.index.ts   sha256 296725f4848a9f2b6ad280dd641e19d4bd7e60c1292402b8cd6ee69ee8a50b28
```

Those are the hashes of the archived files including their headers, not of the bundles. The bundle
`ezbr_sha256` values below are the production identifiers and are the ones to compare against a
future `functions list`.

Reading `change-password` before archiving it turned up one thing worth keeping. Line 35 of the
original refuses outright when the account has no email on file. That is exactly the fail-safe shape
the H1 bug in `accept_partner_invite` was missing (§7.2), written into a function that predates it
and that nothing calls. The unused code got it right and the live code did not.

**Status: cleared for removal, not removed.** Every criterion set for this has now been met — no
caller in either client, no website or script reference, no auth hook, versions and source recorded.
What is deliberately still outstanding is the removal itself, which stays a separate explicit change
rather than something folded into this pass.

`delete-account` matters more than "unused" suggests. It deletes only the auth user and returns
`{ok:true}`. Cascades sweep most tables, but `partner_invites.invitee_email` and `waitlist_emails`
have no foreign key, so both survive and become permanently unreachable once the auth user is gone.
That is the precise failure the maintained function's header comment was written to prevent, live
under a slug one hyphen away from the one iOS calls.

Recorded before any removal:

```
delete-account   v5 ACTIVE verify_jwt=true sha 463ecca44125405c6fa74e8f7b6dccab464acdda73059ece6ae751c5867f9a0c
change-password  v5 ACTIVE verify_jwt=true sha ae292161316979f1a5b8ed846d6247413954c9dfce1a227156d1c7aee35ae69e
```

### 6.5 Optional service-role row audit

Should you want the outright proof described in §6.2, these are every account used today. All are
deleted; all should return zero rows in every table.

```
c6e969bb-aa4f-4112-9f2c-40756a0a063e
df6db5c6-c754-4ace-92c6-84e3d1bfa305
a1f1e0dd-44da-471c-8e1c-b9763e6a4ae3
6ef14b59-e89f-4134-935c-ecc3be144cb5
8f2d333b-5241-4b37-a0de-60811c47c90e
```

## 7. Security audit, 17 August 2026 — repo evidence only

Scope: this repository. No production writes, no live probes, no dashboard reads. Anything that
could not be settled from the repo is marked NOT VERIFIED rather than assumed either way.

### 7.1 The two blockers — both closed

| | File | What it does | Status |
|---|---|---|---|
| C1 | `supabase/migrations/20260812_client_role_grant_cleanup.sql` | Takes every privilege off `anon`, and TRUNCATE off `authenticated`, on six tables | **APPLIED** — see §8.1 |
| C2 | `supabase/migrations/20260812_partner_invites_write_lockdown.sql` | Takes UPDATE and DELETE off `authenticated` on `partner_invites` | **APPLIED AND VERIFIED** — see §6.3 |

**C1 — closed.** The dashboard audit in §8 read `anon` as holding **zero** table grants in `public`,
and read TRUNCATE as absent from `authenticated` on `partner_invites`. Both are C1's two halves.
The finding as originally written follows, because it is the evidence the change was needed.

**C1 (historic) — `anon` holds TRUNCATE on six tables.** RLS never filters TRUNCATE; no policy can restrict it.
This is not inferred from Supabase's default grants: lines 33-39 of that migration record a measured
`pg_class.relacl` reading of `anon=arwdDxtm` on `cycle_settings`, `daily_logs`, `ph_readings`,
`quiz_answers` and `partner_invites`, taken 12 Aug. The publishable key `sb_publishable_eR7…` ships
inside the app binary by design (`project.yml:97`) and resolves to `anon`. PostgREST exposes no
TRUNCATE verb, which is why nothing has happened; that is a property of the API layer in front of
the database, not a control on the database. Whether the ACLs still read that way today is
**NOT VERIFIED** — no read was taken against production for this audit.

**C2 — closed.** `authenticated` no longer holds UPDATE or DELETE on `partner_invites`, verified in
production 17 Aug. Result and method in §6.3.

### 7.2 Fixed in code today — DEPLOYED AND VERIFIED, see §8.6

**Optional chaining nullified the invite ownership check.** `accept_partner_invite/index.ts` and
`decline_partner_invite/index.ts` both compared `invite.invitee_email?.toLowerCase()` against
`user.email?.toLowerCase()`. For an account with no email — phone or anonymous auth — that is
`undefined !== undefined`, which is false, so the guard did not run. The one check standing between
a stranger holding a code and a partner link was skipped. Both now require each side to be present
as well as equal. `deno check` passes on all four edited functions.

Severity is capped by the code being unguessable. `SupabaseBackend.swift:251` builds it from
`UUID()`, taking 16 hex characters of a v4 UUID: 60 bits of entropy, drawn from the system CSPRNG.
Whether phone or anonymous auth is even enabled on this project is **NOT VERIFIED** — dashboard only.

**`unlink_partner` could sever a third party's link.** Line 30 cleared `partner_id` on whoever the
caller's row pointed at, whether or not he pointed back. Where the link was asymmetric — she points
at him, he points at someone else — her unlink cut his link to a person who was not a party to the
request, while that person kept pointing at him and kept reading his row under `profiles_select`.
The update is now narrowed with `.eq("partner_id", user.id)`, so it clears only a genuinely
reciprocal pointer. Matching zero rows is the right outcome for the asymmetric case; her own row is
still cleared, which is what removes the read she holds on him.

**Three stale `verify_jwt` comments corrected.** `_shared/client.ts`, `revoke_partner_invite` and
`send_partner_invite` all asserted `verify_jwt` was OFF, from a 12 Aug probe. It is ON, verified
live 13 Aug. Comments only; the 401 mapping they justify was correct either way, and remains correct
because a token minted for a since-deleted account clears the gateway and still fails `requireUser`.

**Two migration headers corrected.** Both named `supabase db query --linked -f` as the apply route.
That subcommand does not exist in CLI 2.109.1, so following the instruction produced an error rather
than an applied migration. C2's V2 verification block also repeated the
`information_schema.column_privileges` mistake recorded in §6.3 — filtering for DELETE in a view
that cannot report DELETE. Both now lead with `has_table_privilege`.

### 7.3 Open, not blocking

- **`search_path` inconsistency.** `current_partner_id()` and `handle_new_user()`
  (`docs/supabase_schema.sql:29,47`) use `set search_path = public`; the hardened migrations use
  `''`. Deliberately not fixed here: under `''` a function body must schema-qualify every reference,
  so an `alter function` applied blind would break these rather than harden them. Needs the bodies
  rewritten and tested together.
- **No CORS or OPTIONS handling on any function** (`_shared/client.ts`). Only browsers need CORS and
  no browser client calls these, so this is a gap in reach rather than in safety. Noted, not fixed —
  adding it would widen the surface for no current caller.
- **`genesyx_products`** policy is `USING (true)`.
- **`send_partner_invite/index.ts:86`** returns Resend's raw error body to the caller. Line 44
  refuses anyone but the invite's owner, so this reaches only the person who typed the address —
  not the cross-user leak it first looked like.
- ~~**`decline_partner_invite` writes `status = 'declined'`**, which the baseline check constraint
  does not allow.~~ **RESOLVED, 17 Aug 2026.** `docs/supabase_schema.sql:115` does restrict status to
  `('pending','accepted','revoked')`, but `20260812_partner_invite_hardening.sql` widens it to four
  values, and that file's own header records it as applied to `epltxklawpcxxbaleswg` on 12 Aug 2026
  and verified with its §3 queries. It also records the pre-state — constraint at three values, no
  `expires_at`, one row holding status `revoked` — which is the detail that makes the note credible
  rather than aspirational, since it describes what was found rather than what was intended. Decline
  is not failing in production. Worth noting how this was nearly missed: the schema file looks
  authoritative and is out of date, because this project has no
  `supabase_migrations.schema_migrations` table and every migration has been applied by hand. The
  apply notes written into the migration headers are the only record of what has landed.

### 7.4 Checked and found sound

`requireUser` validates against the Auth server via `getUser(token)` rather than decoding locally,
and every function calls it before anything else. No SQL injection: all database access goes through
PostgREST's parameter binding. No SSRF: the only outbound host is a hardcoded constant. Secrets are
read only via `Deno.env.get`, and `service_role` appears nowhere in `App/` or `Sources/`. ~~Supabase
Storage is unused entirely, so there are no bucket policies to get wrong.~~ **Corrected by §8.3 M1:**
no *client code* touches Storage, which is all the repository could show, but production has two
buckets and one of them (`learn`) is PUBLIC with zero policies, no size limit and no MIME
restriction. This is the clearest example in this document of the limit of a repo-only audit — the
absence of a caller was read as the absence of the resource. Deep links are already
hardened — `DeepLink.swift:75-92` checks scheme and host and returns nil rather than falling
through. Mock sign-in cannot ship: `SessionRepository.swift:199` throws in Release builds. The
`uiTestSeed` hook is inside `#if DEBUG`. No ATS exemption in `Info.plist`. Every `user_id` and
`inviter_id` the client sends is refused by a matching RLS `WITH CHECK`, so insert spoofing fails at
the database.

### 7.5 Verdict

**Superseded by §8.4.** Both database blockers this section raised are now closed and confirmed
against production. The remaining item this section owns is that the Edge Function fixes in §7.2 are
**not deployed** — they are inert in the repo until they are, so `accept_partner_invite`,
`decline_partner_invite` and `unlink_partner` still run in production with the flaws described.

## 8. Production dashboard audit, 17 August 2026

Read-only inspection of project `epltxklawpcxxbaleswg` — dashboard panels plus `SELECT`-only queries
in the SQL Editor as `postgres`. This is the evidence §7 could not reach from the repo, and it
settles most of what §7 marked NOT VERIFIED.

### 8.1 Reconciling this audit with §6.3 — they do not conflict

This audit reports the `partner_invites` lockdown as **unapplied**. §6.3 records it as **applied and
verified**. Both are correct, at different moments, and the audit's own evidence is what dates it.

Its H1 line reads `partner_invites | authenticated | DELETE, INSERT, REFERENCES, SELECT, TRIGGER,
UPDATE`. **TRUNCATE is absent.** The measured baseline for that table was `arwdDxtm`, in which `D`
is TRUNCATE, so something removed it. The only change in this repository that removes TRUNCATE from
`authenticated` is C1, `20260812_client_role_grant_cleanup.sql` — whose other half revokes
everything from `anon`, which is precisely what this audit reports as "zero `anon` grants".

So the order was: **C1 applied → this audit ran → C2 applied → verified.** Recorded because the two
documents otherwise read as a straight contradiction, and the temptation would be to assume one of
them was simply wrong.

**C1 is therefore closed**, on live catalogue evidence rather than inference. Both database blockers
are done.

### 8.2 One recommendation in that audit should NOT be followed

The audit observes that `profiles` has no `UPDATE` grant for `authenticated` while a
`profiles_update` policy exists, and proposes "either restore the grant or delete the dead policy".

**Do neither.** The policy is not dead and the grant is not missing — it is column-level.
`20260810_profiles_partner_id_write_guard.sql:47-52` deliberately revokes the table-level UPDATE and
grants it back on nine named columns, so that `partner_id` is the one column a client cannot write.
That is what stops a user pointing her own row at someone else's profile and gaining a read on it
through `profiles_select`.

The finding is a false positive with a specific cause: `information_schema.role_table_grants`
reports **table-level** grants only. Column grants live in `column_privileges`. This is the mirror
image of the `column_privileges`/DELETE error recorded in §6.3 — the same class of mistake, in the
opposite direction, and worth naming twice for that reason.

Restoring the table-level grant would silently reopen the hole that migration closed. Confirmed the
app still works as-is: `SupabaseBackend.swift:215` and `:222` upsert only `id`, `display_name` and
the preference columns, all inside the granted set.

### 8.3 What this audit newly establishes

Settling §7's NOT VERIFIED items:

- **RLS is genuinely enabled on all 9 tables** (`relrowsecurity = true`), not merely policied.
- **`anon` holds zero table grants in `public`.** Signed-out access fails at the privilege layer
  before RLS is consulted.
- **Security Advisor: 0 errors**, 12 warnings, 1 info.
- **No auth hooks configured**, which retires the last structural question about the orphan
  functions in §6.4.
- **`waitlist_emails` is unreachable by clients** — RLS on, zero policies, zero grants. The only
  path in is `join_waitlist`.
- **Rate limits at defaults**; sign-in/sign-up 360/h per IP.

Genuinely new findings, none of them CRITICAL:

- **Two Storage buckets exist.** `learn` is **public** with zero policies, no size limit and any
  MIME type; `avatars` is private, 5 MB, image types only, with four correctly owner-scoped
  policies. This does not overturn §7.4's "Storage is unused" — that finding was about repo code and
  remains true. The two together are the actual problem: buckets no code manages are unowned
  surface. `learn`'s contents need listing object by object before the public flag is accepted.
- **Email confirmation is OFF.** Email+password users get a working session on an unverified
  address.
- **Leaked-password protection and captcha are OFF.**
- **`handle_new_user()` and `rls_auto_enable()` are client-callable.** Both are trigger functions
  with no reason to be. `REVOKE EXECUTE ... FROM anon, authenticated` on both. All definer functions
  do pin `search_path`, so the classic escalation route is already closed.
- **Legacy `anon`/`service_role` JWT keys are still enabled** alongside the `sb_publishable_` key
  the app ships. Confirm nothing depends on them, then disable.
- **`genesyx://` is in the auth redirect allow-list.** Any iOS app can claim a custom scheme.
  Prefer the Universal Link once `apple-app-site-association` is served — which is the same
  prerequisite `send_partner_invite` waits on for `INVITE_WEB_BASE`.
- **"Automatically expose new tables" is ON** in the Data API settings, so future tables start
  exposed rather than dark.

### 8.4 Where this leaves the launch

Both database blockers are closed. Nothing found here is architectural: the RLS and grant model is
sound and now verified live rather than read off migrations.

What remains before submission, in order:

1. ~~**Deploy the three invite Edge Function fixes** (§7.2, blocker 3b).~~ **DONE** — deployed and
   verified against both conditions of §8.5, a version bump *and* a source diff. Evidence in §8.6.
2. **Delete the two orphan Edge Functions** (§6.4). Now **cleared for removal**: the usage sweep is
   complete on every criterion, and both sources are archived under
   `docs/archive/edge-functions-orphans/` with their versions and bundle hashes. Only the removal
   itself is left, and it stays a separate explicit change.
3. **Audit the `learn` bucket's contents**, then adopt or delete both buckets.
4. **Enable email confirmation and leaked-password protection.**
5. **Apple token revocation** in the delete flow — still the standing App Store compliance gap.

Then the hygiene items: revoke EXECUTE on the two trigger functions, disable the legacy keys, turn
off automatic table exposure.

### 8.5 Edge Function production version baseline, 17 August 2026

Recorded so that a later claim of "deployed" can be checked rather than believed. Read from the
Edge Functions dashboard.

| Function | Version | State | Note |
|---|---|---|---|
| `delete_account` | **v10** | ACTIVE | Matches §6.1. Deployed source verified byte-identical to repo. |
| `accept_partner_invite` | **v8** | ACTIVE | Carries the §7.2 ownership-check flaw. |
| `decline_partner_invite` | **v6** | ACTIVE | Carries the §7.2 ownership-check flaw. |
| `unlink_partner` | **v7** | ACTIVE | Carries the §7.2 third-party unlink flaw. |
| `revoke_partner_invite` | **v4** | ACTIVE | Comment-only change pending. |
| `send_partner_invite` | **v5** | ACTIVE | Comment-only change pending. |
| `delete-account` (orphan, hyphen) | **v5** | ACTIVE | To be deleted — §6.4. |
| `change-password` (orphan) | **v5** | ACTIVE | To be deleted — §6.4. |

**The bar for calling the §7.2 fixes deployed.** Both conditions, not either:

1. The production version number **actually changes** — `accept_partner_invite` v8 → v9,
   `decline_partner_invite` v6 → v7, `unlink_partner` v7 → v8.
2. The **deployed source is verified**, by `supabase functions download <slug>` into a scratch
   directory followed by a diff against the repo, the same method used for `delete_account` in §6.1.

A successful-looking deploy command is not evidence of either. `delete_account` is the precedent:
its first deploy that day went out at 15:13:15 UTC and still carried the stale banner, and only the
15:30:24 deploy made the live function and the file agree. The version number is what caught it.

Until both conditions are met and recorded here, these three functions are **NOT DEPLOYED** and
production is running the flawed versions.

**Baseline independently re-read from the API, 17 Aug 2026**, with
`supabase functions list --project-ref epltxklawpcxxbaleswg`. All eight versions above are confirmed
unchanged. The API returns one field the dashboard does not surface, and it is a better instrument
than the version number: `ezbr_sha256`, the hash of the deployed bundle. A version number only
increments; a bundle hash changes if and only if the shipped code changes. Pre-deploy values for the
three functions under §7.2:

```
accept_partner_invite   v8  e87d523c97bb82617ea9925d0e3472a1b8e10a76eb820e1e1e8edbb06e76419e
decline_partner_invite  v6  563f6a1ca9372172dd8ab4e1074b0ba14c213ccca2e4eb525c783bb45c4c1b1e
unlink_partner          v7  4343eb63dccd329c26f93942eb1aaaf52e5c8e5b0985451c9c8b87bc64dc67b0
```

If a deploy reports success and the hash is unchanged, nothing shipped, whatever the version says.
That is the `delete_account` failure mode caught earlier, detectable now without a download.

Also confirmed at baseline: all eight functions are `verify_jwt=true`, and this repository has **no**
`supabase/config.toml`. That absence is worth stating because it means per-function settings are not
declared anywhere in the repo. Any deploy therefore falls back to the CLI default rather than to a
recorded intent, so `verify_jwt` has to be re-read after each deploy rather than assumed to have
survived it.

**Deploy attempted and deliberately not completed, first pass, 17 Aug 2026.** All three functions
passed `deno check` and the tooling was authenticated and linked, but the deploy was stopped short of
production because "do not deploy again blindly" is a standing instruction and the acceptance
criteria had been set without a deploy being asked for. Superseded by the authorised deploy below.

### 8.6 DEPLOYED AND VERIFIED — the three invite fixes, 17 August 2026

Authorised explicitly, deployed one slug at a time, each verified before the next was started. Both
conditions of §8.5 are met for all three, so §7.2 and blocker 3b are **CLOSED**.

| Slug | Version | State | verify_jwt | Bundle `ezbr_sha256` (first 16) | Source diff vs repo |
|---|---|---|---|---|---|
| `accept_partner_invite` | v8 → **v9** | ACTIVE | true | `e87d523c…` → `4487fe149fb7a981` | byte-identical |
| `decline_partner_invite` | v6 → **v7** | ACTIVE | true | `563f6a1c…` → `a82966004a491184` | byte-identical |
| `unlink_partner` | v7 → **v8** | ACTIVE | true | `4343eb63…` → `2d2df14a46ed58e5` | byte-identical |

Source verification used `supabase functions download <slug> --use-api --workdir /tmp/gx-verify`,
then `diff -u` against the working tree. Every deploy uploaded two assets, the function's own
`index.ts` and `_shared/client.ts`, and both were compared. `diff` reported no differences, and the
local and downloaded `index.ts` hash identically:

```
accept_partner_invite   0e6e32400ef708957b88c8505b5644262e39d9e01234793b7d395f7f38786102
decline_partner_invite  be24bb874cdc8bbb5f1d3e3ad83b7e254c1bb036ef487a65627a074df47b17f4
unlink_partner          0a215d01ca35b0caffdc0585523f6722ece7340f4808017f0b8ba1161c27f908
```

`verify_jwt` was re-read after each deploy rather than assumed. It is still true on all three, which
was the open risk noted above given that this repo carries no `supabase/config.toml`.

**Nothing else was deployed.** The other five functions sit at their baseline versions untouched:
`delete_account` v10, `send_partner_invite` v5, `revoke_partner_invite` v4, and the two orphans
`delete-account` v5 and `change-password` v5. The version number is the load-bearing check there,
because a deploy always increments it. The orphans remain deployed on purpose; their removal is still
a separate change (§6.4).

**One false alarm, and it was mine.** The post-deploy comparison initially reported the bundle hash
of `send_partner_invite` as changed while its version stayed at v5, which should be impossible
without a deploy. The cause was a hand-copied baseline: the value I had transcribed was 66 characters
long, with an extra `b9` inserted, so no sha256 could ever have matched it. The live value is 64
characters and identical to the baseline, and the function was never redeployed. The lesson is worth
keeping, because the whole point of §8.5 is to make "deployed" checkable rather than believable: a
hash retyped by hand is not an instrument. Capture the baseline to a file with `functions list
--output json` and diff machine-to-machine. The impossible combination is what exposed it, so the
version and hash together caught an error that either alone would have hidden.

---

## 9. Build 21 — Article 9 consent, Apple revoke, pregnancy gate (18 August 2026)

Three of the release blockers above were closed in code today. This section says what was built, what
was proved, and — the part that matters most — what is still **not** done, because two of the three
have an operational half that no amount of Swift closes.

### 9.1 UK GDPR Article 9 explicit consent

**What the app now does.** Before the onboarding quiz — which is the first thing that asks her
anything about her body — she is shown `ConsentView`: what is collected, what it is used for, and
how to withdraw. The agreement control starts **off** and cannot be pre-set (Article 4(11): a
pre-ticked box is not a clear affirmative action), and Continue stays disabled until she operates it.
Declining is a real destination with a real exit (`ConsentDeclinedView` → "Continue anyway"), because
consent obtained by making the app unusable without it is not freely given (Article 7(4)).

**How it is stored.** `consent_events` is an append-only log — never updated, never deleted. A
withdrawal is a new row, and a re-grant is another new row. Two columns on `profiles` could not have
held this: current state alone cannot answer what she was told and when, which is the question that
gets asked in a complaint, and Article 7(1) puts the burden of proving consent on the controller. It
could not have lived on `profiles` in any case, because `profiles_select` is readable by a linked
partner and RLS filters rows, never columns. Each row carries the **copy version** she was shown
(`2026-08-18.v1`), so if the wording changes materially the app asks again rather than inheriting a
grant against superseded text. `occurred_at` is stamped on the device and sent, not defaulted
server-side, because onboarding runs before sign-up — a default would record when the phone next had
a session rather than when she agreed.

**What withdrawal does.** Profile → *Health data permission* → Withdraw consent, one tap from a
screen she already visits and the same distance from her thumb as the tick that granted it (Article
7(3)). The confirmation states plainly that withdrawal stops collection and is **not** erasure, and
points at the Delete account control further down the same screen, which is Article 17. Turning it
back on re-presents the full consent screen rather than calling `grant()` from the row, because
consent has to be informed every time it is given.

**Where the gate actually is.** At the repository, in five places — `CycleRepository.upsert`,
`DailyLogRepository.upsert`, `PhRepository.upsert`, `SupplementsRepository.add`, and
`PreferencesRepository.recordQuizAnswers`. Not on the entry screens: there are ten UI call sites that
reach a health write across seven files, and a new one is always a screen away. "She cannot get to a
control that writes" has to be re-proved every time the UI changes; "the write itself refuses" does
not. Deletes are deliberately **outside** the gate — Article 17 erasure must survive withdrawal, and
the withdrawal copy promises exactly that.

Because the gate is at the repository, a withdrawn user sees controls that are still on screen and
simply do nothing, which reads as a broken app rather than as her decision. `ConsentWithdrawnBanner`
sits at the top of Home, Track, Nutrition and the pH tab, and only when she has withdrawn, saying so
and naming where to change her mind.

**✅ APPLIED TO PRODUCTION, 18 August 2026 ~11:00.** `20260818_consent_events.sql` was run in the
dashboard SQL Editor and verified there: 5 columns, RLS enabled, exactly the two owner-only policies
(read and append — no ALL, UPDATE or DELETE policy, which would defeat an append-only trail).

This was a blocker until it landed, because the controller could not demonstrate consent from a trail
held only on the data subject's phone (Article 7(1)), and because `clearLocalState()` wipes the local
copy on sign-out and depends on the server copy returning. Both are now satisfied.

Re-probed after the apply and a `NOTIFY pgrst, 'reload schema'`, public anon key, status codes only,
no rows read:

| Table | HTTP | Reading |
| --- | --- | --- |
| `consent_events` | **200** | exists, exposed, RLS filters anon to an empty set |
| `profiles` | 401 | exists, anon holds no table grant (revoked 20260812) |
| `partner_invites` | 401 | same |
| `nonexistent_control` | 404 | what a missing or unexposed relation looks like |

The earlier 404 was the schema cache, as suspected. The control row is the part that makes the 200
mean something: 404 is still reachable, so a 200 is not a blanket response.

**One discrepancy, not exploitable but worth closing.** `consent_events` answers 200 where the six
older tables answer 401. The reason is dates, not policy: `20260812_client_role_grant_cleanup.sql`
revoked `anon`'s table grant on `cycle_settings`, `daily_logs`, `ph_readings`, `quiz_answers`,
`partner_invites` and `profiles`. `consent_events` was created six days later and inherits Supabase's
default grant to `anon`, so it never came under that revoke. Its two policies are `TO authenticated`
and owner-scoped, so `auth.uid()` is null without a session and anon reads nothing — the 200 is an
empty set, which is why it is not a live exposure. But it leaves RLS as the only thing between `anon`
and the table, which is exactly the single-point-of-failure posture the August 12 migration was
written to remove.

**Closed as a migration file, not a one-off statement:**
`supabase/migrations/20260818b_consent_events_grant_cleanup.sql` — the two revokes, in the same
documented and idempotent form as the August 12 cleanup, with preconditions that refuse to run if a
policy has started naming `anon` or if RLS has been disabled. **Not yet applied**; apply via the
dashboard SQL Editor. Writing it as a file rather than pasting the SQL is the point: today's 404 was
repo-and-production drift in the other direction, and a statement that only ever existed in a chat
is the same drift waiting to happen again. V4 in that file re-runs the probe — `consent_events`
should read 401 afterwards, matching `profiles`.

Not a launch blocker and not needed before the build 21 upload.

**🟠 The copy has not had legal review.** `ConsentPolicy` was written to be defensible and the
mechanism around it implements the Articles named above, but every sentence she is shown is a legal
artifact and none of it has been read by a lawyer. It is a sentence-level review, not a rebuild —
the structure does not change if the words do, only `currentVersion`.

### 9.2 Sign in with Apple token revocation

**Both halves are now code complete.** The `delete_account` edge function revokes against Apple's
`/auth/revoke` **before** it destroys anything, so a revoke failure cannot leave an account
half-deleted. The iOS client now collects a fresh Apple authorization code at the moment she confirms
the deletion and sends it along.

**Why the code is collected at deletion and not kept from sign-in.** There is nothing to keep:
`signInWithIdToken` exchanges the identity token with Supabase directly and never performs the code
exchange, so no Apple refresh token is ever stored on the device or in the project. Apple's
authorization code lives about five minutes — long enough to be collected during the delete
confirmation and spent by the function, and short enough that nothing durable is held. Dismissing
Apple's sheet stops the deletion silently, because that is an answer; any other reauthorisation
failure proceeds with no code and lets the server decide, so a misbehaving Apple sheet cannot strand
her with an account she is unable to delete.

Whether an account owes a revoke is read from the live session rather than remembered from the
sign-in that created it — `identities` first, then `app_metadata.providers`, then
`app_metadata.provider` — because she may have signed in with Apple on another device or linked it
later, and the last of those three names only whichever provider came first.

**Deploy order, and where we actually are (18 August 2026).**

1. ✅ Put `APPLE_TEAM_ID`, `APPLE_CLIENT_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` into **Supabase
   secrets**. The `.p8` goes through the secret manager and nowhere else — not into a commit, not
   into a chat. Done; all four confirmed present, `delete_account` deployed.
2. ⚠️ Leave `APPLE_REVOKE_REQUIRED` **off**. The function is inert on this path while it is off.
   **This step was skipped — the flag was set to true on 18 Aug, before step 3.**
3. ⏳ Ship build 21, so clients in the field are sending the code. Archived, not yet uploaded.
4. Only then set `APPLE_REVOKE_REQUIRED=true`. Flipping it before step 3 makes every deletion from an
   older build fail, because those builds send no code.

Steps 2 and 4 were taken out of order, so between now and build 21 reaching users, **an Apple-signed
user deleting from an older build gets a refused deletion** (`index.ts` returns `failed("apple
revoke", "apple identity with no authorizationCode in body")`).

**Decision, 18 August 2026: the flag stays true.** The reasoning, recorded so it is not re-litigated
or mistaken for an oversight:

* **There is no public user to harm.** Nothing has ever shipped to the App Store. The only accounts
  that could be holding a pre-21 build are the client's own TestFlight installs.
* **The failure mode is a refusal, not damage.** The check runs before anything is touched, so a
  refused deletion leaves the account exactly as it was. The alternative ordering trades this for
  the opposite risk — data destroyed while Apple's grant survives, which is the 5.1.1(v) violation
  this function exists to prevent.
* **It self-closes.** Once build 21 is live, every client sends the code and the window is gone
  without anyone remembering to flip anything. A flag left off is a flag someone has to come back
  for; §9.2 step 4 becomes a no-op instead of a follow-up.
* **Only Apple-signed users are in scope at all.** Email and Google deletions never enter this
  branch — `hasAppleIdentity(user)` gates the whole block.

Reverting to false would remove the window, and was considered. It was rejected because the only
population it protects is the client's own test accounts, and it reintroduces a manual step whose
whole cost is that it can be forgotten.

**Not verifiable from here.** Sign in with Apple does not work on the Simulator, so the end-to-end
path — sign in with Apple, delete, confirm the Apple ID no longer lists Genesyx — is a real-device
check. It is already item 3 of §4.

### 9.3 The pregnancy placeholder

Closed — see the revised §3b. `FeatureFlags.pregnancyMode = false`.

### 9.4 Android gender-option ID parity defect

**Confirmed, documented, not fixed** — fixing it needs a decision, and it is in the other repo.

The onboarding quiz question `gender` writes to `profiles.quiz_answers`, which both apps share. Two
of its four option ids do not match:

| Option shown | iOS id | Android id | Same? |
|---|---|---|---|
| Girl | `girl` | `girl` | yes |
| Boy | `boy` | `boy` | yes |
| No preference | `either` | `no_preference` | **no** |
| Prefer not to say | `private` | `prefer_not_to_say` | **no** |

*(iOS: `Sources/GenesyxCore/Content/QuizContent.swift`. Android:
`app/src/main/kotlin/com/genesyx/app/domain/content/QuizContent.kt`, where the fourth is the constant
`PREFER_NOT_TO_SAY`.)*

**Effect.** A woman who answers "No preference" on Android and then opens iOS has a stored value
matching none of the options iOS offers, so the question presents as unanswered — and vice versa. It
is confined to that: nothing on either platform branches on these values, they are storage keys only,
so no guidance, content or calculation changes. There is no crash and no data loss.

**Severity: low, but it is silent**, which is the part worth weighing. She is not told her answer was
not understood; it simply looks like she never gave one.

**Why it is not fixed here.** Aligning Android to iOS means rewriting ids that are already stored in
production rows, so it needs a migration that maps `no_preference` → `either` and
`prefer_not_to_say` → `private`, or it trades one silent mismatch for another. Doing it the other way
(iOS to Android) is worse: the iOS ids are the ones the existing comment in `QuizContent.swift`
records as deliberately preserved across a copy change, so they carry history the Android ids do not.
**Recommendation: align Android to iOS, with a one-shot remap of stored answers.** Needs your
approval and an Android release; it does not block this submission.

### 9.5 What was actually run, 18 August 2026

Every number below is from a run on this machine on 18 August 2026, after all of §9's changes were
in the tree. Commands are given verbatim so they can be repeated.

| Suite | Command | Result |
|---|---|---|
| Core package | `swift test` | **314 passed, 0 failed** |
| App build | `xcodegen generate && xcodebuild -project Genesyx.xcodeproj -scheme Genesyx -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | **BUILD SUCCEEDED** |
| iOS unit | `xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GenesyxAppTests` | **353 passed, 0 failed** |
| iOS UI | `xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GenesyxUITests` | **93 executed, 1 skipped, 0 failed** (1,056s) |
| Android unit | `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest --rerun-tasks --no-build-cache` | **467 passed, 0 failed, 0 skipped** |

The iOS unit count went 349 → 353: the four added tests are the denied-notification path (§9.6).
Android was re-run because the consent work touches shared storage; nothing in the Android tree was
edited, and the count is unchanged from the pre-change run, which is the point of running it.

**`xcodegen generate` is not optional.** Three of the new files live under `App/Genesyx`, and the
project file is generated — building without regenerating first compiles a tree that does not
contain them, and the failure looks like a missing symbol rather than a missing step.

### 9.6 Priority 3 items

**The save-password UI flake is fixed** (`App/GenesyxUITests/LifecycleE2ETests.swift`). iOS
sometimes offers a system "Save Password?" sheet after a sign-in. It belongs to another process, so
it is invisible in the test log, and its backdrop swallows touches — which reads as the app's own
controls going dead. The old code checked `isHittable` once and tapped, which lost the race two
ways: the sheet can arrive between the check and the tap, and while it animates in the element
underneath still reports `isHittable == true`, so the tap is swallowed silently and the test fails
several assertions later, somewhere that reads like a product defect. The wait is now on the sheet
being absent *and staying absent* for a beat, and on nothing else — notably not on `isHittable`,
because `tap()` scrolls an off-screen element into view by itself and gating on hittability forbids
every target below the fold.

**The denied-notification path now has coverage** — four tests, previously impossible to write.
`UNUserNotificationCenter`'s authorisation status is host state, so a test of the denied path passed
or failed according to which simulator it landed on. `NotificationService` now reads it through one
injectable closure (`readAuthorizationStatus`), defaulted to the real call; production behaviour is
unchanged. The tests assert that a system denial is not allowed to look like working reminders, that
it does not rewrite what she asked for, that allowing it later in Settings turns reminders on
without asking her twice, and that a denial still leaves her the in-app milestone.

**One UI test remains skipped**, as it was before:
`NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission` skips itself when
notification permission is already determined for the install, which is correct — the pre-prompt is
genuinely not shown then. Exercising it needs a fresh install.

### 9.7 Consent copy v2 and the build 21 archive (18 August 2026)

The consent copy was revised to name what is collected: vaginal pH, daily symptoms and mood, and
sexual activity, in place of the earlier summary phrase "health data". `currentVersion` moved to
`2026-08-18.v2`, which is the file's own invariant doing its job — **everyone who agreed to v1 will
be asked again on first launch of build 21.** That is correct for a change this material, and it is
a visible event for existing users, so it should not arrive as a surprise.

Two guards had to change with it, and the difference between them matters:

- `testVersionIsPinnedSoCopyChangesCannotShipSilently` failed **by design** — that is the whole
  reason it exists. The pin moved to v2 and now also covers `agreeLabel`, which was unpinned before.
- `testConsentCopyNamesTheControllerTheDataAndTheWithdrawalRoute` required the body to contain the
  literal words "health data". v2 lists the categories instead, so the assertion was replaced with
  one that pins each category by name plus the phrase "especially sensitive". Stronger than what it
  replaced — "specific and informed" under Article 9(2)(a) means she is told what is collected, not
  handed a label — but it is still a guard edited to accommodate new copy, and should be read as
  such rather than as an untouched pass.

The banned-phrase guard `testConsentCopyCarriesNoBannedPhrases` and the registration guard
`testEverySurfaceIsRegisteredForScanning` both **passed untouched** on the v2 strings.

Re-run after the copy change and the build bump: `swift test` **314/0**, `GenesyxAppTests` **353/0**,
`GenesyxUITests` **93 executed, 1 skipped, 0 failed**.

**Archive.** Build 21 is archived at `~/Desktop/Genesyx-b21.xcarchive` — 1.2.0 (21), signed Apple
Distribution: SF MEDIA & PR LTD (M5L3MM75SG), profile "Genesyx App Store", `UIDeviceFamily = [1]`
(iPhone only), minimum iOS 16.0, signature valid and satisfying its Designated Requirement. Not
uploaded. iPhone-only needed no project change: `TARGETED_DEVICE_FAMILY` was already `1` on the
shipping target and there is no watchOS target in the project.

**Backend state as of 18 August 2026, ~11:00.** Both items that were blockers in §6 and §9.2 are
done, performed in the client's own terminal and dashboard rather than from this session:

| Item | State | Evidence |
| --- | --- | --- |
| `20260818_consent_events.sql` applied | ✅ Done | Dashboard-verified: 5 columns, RLS on, exactly the two owner-only policies |
| PostgREST sees the table | ✅ Done | Anon probe **HTTP 200** after `NOTIFY pgrst, 'reload schema'`; was 404 (schema cache) |
| Five Apple secrets set | ✅ Done | `supabase secrets list`; `.p8` never left the secret manager |
| `delete_account` deployed | ✅ Done | Client-confirmed |
| `APPLE_REVOKE_REQUIRED=true` | ✅ Done, kept on deliberately | Early by the documented order; reviewed and accepted — §9.2 |
| `anon` grant on `consent_events` | 🟠 Migration written, not applied | `20260818b_consent_events_grant_cleanup.sql`; RLS covers it meanwhile |

Probe shape, so a future re-run matches: `GET {SUPABASE_URL}/rest/v1/{table}?select=id&limit=0` with
`apikey` and `Authorization: Bearer` both set to the public publishable key, status code read and the
body discarded. No service-role credential was used at any point, and no row contents were read from
any production table.

**A consent-driven test change, not a test weakening.** `testSignOutDoesNotBlankMedicalSources` now
agrees to consent again after signing back in. That is real behaviour: sign-out calls
`consent.clearLocalState()`, and the DEBUG local-only build used by the UI suite has no server to
restore the trail from, so she is asked again. Asking twice is the safe direction to fail in — the
alternative is writing to her body data on a permission the app cannot evidence.
