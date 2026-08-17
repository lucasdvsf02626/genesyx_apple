# Launch readiness — 17 August 2026

**Question:** is the app ready to launch, and what is left for Lucas to finish?

**Short answer: the app itself is in good shape. The submission is not.** Every blocker that remains is either off-code work only you can do, a decision only you or the client can make, or one live check I cannot run from the repo. No feature work is outstanding for the agreed scope.

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

**1. Decide the UK GDPR Article 9 lawful basis.** *Legal decision, then engineering follows.*
The live privacy policy claims **"Article 9(2)(a) explicit consent"** for health data. The app has no consent step and stores no `consented_at`. Either the app must gain a consent step, or the policy must state the basis that is actually relied on. **This is the single largest legal exposure in the release** and it cannot be resolved in code until you decide which way it goes. Everything else is smaller than this.

**2. Sign in with Apple `/auth/revoke`.** *Yours — you said you'd do this.*
Needs the `.p8` key into Supabase secrets and the server-side revoke call in `delete_account`. Apple requires that deleting an account revokes the Apple token. **Do not paste the `.p8` into a chat or commit it** — it goes through your secret manager. Note this is tangled with the unresolved decision about the previously exposed keys; settle that at the same time.

**3. Deploy `delete_account`.** *Yours.*
The waitlist-honesty and `user_supplements` fixes exist **in the repo only**. The live project still runs the old function. Account deletion is an Apple requirement and it is currently deployed broken.

**4. Verify the password-reset email end to end.** *One live check — I cannot do it from the repo.*
`resetPasswordForEmail` is called with **no `redirectTo`**, and the app has no recovery deep-link handler and no set-new-password screen. The email therefore lands on whatever the Supabase project's **Site URL** is — which is outside this repo. Meanwhile the app tells her *"Check your inbox."*
**→ Trigger a real password reset against production and follow the email.** Tell me what you see. If it does not land somewhere that works, every woman who forgets her password is locked out, and I will build the in-app recovery screen.

**5. Bump the build number.** *Engineering, 30 seconds, but it must not be forgotten.*
`project.yml` still says `CURRENT_PROJECT_VERSION: "18"`. Build 18 was archived **before** the auth gate landed, so that archive is void. Bump to 19, `xcodegen generate`, re-archive from a single clean SHA.
**Two things to know before you make that commit:** the working tree currently holds **47 uncommitted product changes** across several sessions and **nothing has been committed yet**, so "a single clean SHA" does not exist until you make one. And `graphify-out/` is **tracked and not in `.gitignore`** — it accounts for the overwhelming majority of changed entries, so a bare `git add -A` would put more generated cache than product into the release commit. `docs/assets/` (a duplicate copy of the guide PDF) is deliberately excluded too.

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

**A reviewer can reach a "Coming soon" screen.** `PregnancyView` is presented from a Profile row and ends with *"Coming soon — we'll let you know the moment it's ready."* It is honestly built — it shows no fake data, no empty "—" fields, and it does not switch her into a mode that does not exist — which is exactly how a teaser *should* be done. But Apple has rejected apps for "coming soon" surfaces before, and a reviewer clicking through Profile will land on it.
**Your call:** leave it (it is honest and it sells the roadmap) or hide the Profile row for v1 and restore it in 1.3. I would leave it, but you should know it is there before review, not after.

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

What stands between here and the App Store is **one legal decision (Article 9), two deployments you own, one live check on the password email, one build-number bump, and a data-entry session in App Store Connect.** None of it is engineering risk. All of it is unavoidable.

The one thing I would not skip is **the VoiceOver check** — it is sixty seconds and it is the only finding where I genuinely do not know the answer. Tap the four Profile rows while the phone is in your hand (§4 item 0); that is the second.
