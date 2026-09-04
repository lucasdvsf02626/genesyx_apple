# iOS launch checklist — Genesyx `com.genesyx.app`

Target: controlled rollout to ~5,000 users, zero showstoppers.

Loop 1 — 2026-09-02. Status is evidence-based; anything I could not verify from the
repo is marked **UNKNOWN** rather than guessed. External state (App Store Connect,
TestFlight) is never inferred.

Legend: 🟢 green · 🔴 red · 🟡 partial · ⚪ unknown (needs external confirmation)

---

## Headline finding this loop

**The `Genesyx-1.2.0-b25.xcarchive` on disk is not shippable, and the reason is worse
than "ambiguous build identity". It corresponds to no commit, and it does not contain
the build-25 work.**

Evidence:

| Fact | Source |
| --- | --- |
| `HEAD` = `3202ba8` "Let her add a food group of her own" | `git rev-parse` |
| Committed `project.yml` at `3202ba8` has `CURRENT_PROJECT_VERSION: "24"` | `git show HEAD:project.yml:113` |
| Working tree has `CURRENT_PROJECT_VERSION: "25"`, **uncommitted** | `git diff project.yml` |
| Archive `CFBundleVersion` = `25`, created **Fri 28 Aug 2026 16:56:06 BST** | `~/Library/Developer/Xcode/Archives/2026-08-28/Genesyx-1.2.0-b25.xcarchive/Info.plist` |
| All 16 app/domain source files last modified **1 Sep 2026**, 4 days *after* the archive | `stat` on the dirty set |
| Uncommitted RC work = **1,132 insertions / 50 deletions across 23 files** | `git diff --stat HEAD` |

So the archive was produced from a dirty tree whose only difference from `3202ba8` was
(at least) the build-number bump. It therefore contains **none** of the 1 September
release-candidate work: no minimum-version gate, no auth rate-limit handling, no
incremental sync, no account-switch rename fix.

**This kills Option B.** Shipping the existing archive would put a binary labelled
"build 25" in front of testers that contains zero of the work `changes_iOS.md` describes
as build 25. That is the single most dangerous outcome available right now, because the
label would look correct on every dashboard.

**Option A is the only safe path**, with one refinement recorded under item 1 below.

---

## 1. Build identity resolved — 🔴 RED — Apple closed the 1.2.0 upload train

- [ ] 🔴 **Upload attempt rejected by App Store Connect, 2 Sep 2026 14:33 BST.**
      The verified Desktop archive reached Apple's analysis service, then failed with
      `90062`: its `CFBundleShortVersionString` is `1.2.0`, which is not higher than the
      previously approved version `1.2.0`. Apple also returned `90186`: pre-release train
      `1.2.0` is closed for new build submissions. **No build was uploaded.** Build number
      25 being unused does not reopen a closed marketing-version train.
- [x] ✅ **Cause verified against a primary source.** 1.2.0 went **live on the App Store
      2026-08-26T09:14:21Z** (public iTunes lookup API, id `6787682466`, seller
      *SF MEDIA & PR LTD*). A released version's train closes permanently, so **no build of
      any number can ever be uploaded as 1.2.0 again.** This is not a transient error to
      retry.
- [x] ✅ **Rejection evidence is inside the archive itself**, not inferred:
      `Info.plist` → `Distributions[0]` — one attempt, `destination = upload`,
      `uploadedBuildNumber = 25`, `preparationEvent` success 13:32:27Z, `uploadEvent`
      failure 13:33:59Z carrying both error codes.
- [x] **My error, stated plainly.** Under item 3 I verified that build *number* 25 was
      unused and concluded 25 was free. That was the wrong question: build-number
      availability does not imply the **version train** is open, and I never checked the
      train. The commit, tag and archive are sound work aimed at an unusable target.
- [ ] Choose the next marketing version (normally `1.2.1` for this release), update the
      project, commit and tag that exact state, then create and verify a new archive before
      attempting another upload. Do not modify or relabel the existing signed archive.

- [x] 🟢 **Decision: Option A at build number 25.** Build 25 has never been uploaded
      (item 3), so 25 is free. No renumber to 26.
  - ~~Option B: ship the existing 28-Aug archive~~ — **rejected on evidence above.**
- [x] 🟢 **Committed `a3ae1b1`** "Bump to build 25 with the release-candidate work" —
      35 files, 1,852 insertions. Includes the pbxproj, which was carrying
      `CURRENT_PROJECT_VERSION = 22` against a `project.yml` that said 24; both now read 25.
      Committing it is what makes the tag reproducible, so it is not a drive-by.
- [x] 🟢 **Tagged `v1.2.0-b25`** (annotated), carrying the min-version-gate warning.
- [x] 🟢 **Archived from the tagged state, 2 Sep 2026 12:07:59 GMT.**
      `~/Desktop/Genesyx-1.2.0-b25.xcarchive` — `** ARCHIVE SUCCEEDED **`, exit 0.
      Verified from its own `Info.plist`, not from the build log:
      `1.2.0` / `25` / `com.genesyx.app` /
      `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)`. Binary 6,716,144 bytes,
      `Genesyx.app.dSYM` present. ~~**This is the archive to ship.**~~
      **SUPERSEDED** — correctly built, correctly signed, and unshippable: it carries
      `1.2.0`, and that train is closed. The binary is not at fault; the label is.
- [ ] ⚠️ **TWO archives now both claim 1.2.0 (25).** The stale one is
      `~/Library/Developer/Xcode/Archives/2026-08-28/Genesyx-1.2.0-b25.xcarchive`.
      Renaming its folder would not help — Xcode Organizer lists archives by the name and
      version inside `Info.plist`, so both appear identical there. **They are distinguishable
      only by date: 28 Aug = stale, 2 Sep = correct.**
      Recommended: delete the 28-Aug one from Xcode Organizer (right-click → Delete) before
      anyone opens that window with upload in mind. I have not deleted it — that is your
      artefact and the deletion is not mine to make.
- [ ] ⚠️ **Three doc files carry uncommitted edits on top of the tag** — `CHANGES.md`,
      `changes_iOS.md`, `to do list.md`. Documentation only, no code, so the archive is
      unaffected — but the tag does not capture them.
- [ ] Stale comment at `project.yml:108-112` **deliberately left uncorrected** — it is a
      factual error, not a release blocker, and fixing it inside the release commit would
      have been a drive-by change. Offered as a separate one-line commit.
- [ ] Delete or rename the stale `2026-08-28/Genesyx-1.2.0-b25.xcarchive` once the real
      one exists, so two different artefacts never both answer to "b25".
- [x] 🟢 The dirty tree is safe to commit: `.gitignore` additions are `build_sim_qa/`,
      `.codegraph/`, `.claude/`, `/graft/` — **`graphify-out/` is untouched**, as required.
      `.mcp.json` contains no credentials (grep for key/token/secret/password: 0 hits).

**Status: blocked.** Commit `a3ae1b1`, tag `v1.2.0-b25`, and the Desktop archive are
internally consistent, but Apple will not accept another `1.2.0` build. A new marketing
version, commit/tag, and archive are now a hard prerequisite for upload.

## 2. App Store Connect compliance — 🟡 PARTIAL (privacy green, entity question open)

- [x] 🟢 **App Privacy is published and accurate.** Published 15 days ago. Four data types,
      all *Used for App Functionality* and all *Linked to the user's identity*:
      **Sensitive Info · Health (Health & Fitness) · Email Address (Contact Info) ·
      User ID (Identifiers)**. That is the correct shape for an Article 9 app — the
      cycle/pH/intimacy data is covered by Health + Sensitive Info.
      Privacy Policy URL: `https://genesyx.co.uk/policies/privacy-policy`.
      *(Verified in ASC → App Privacy, 2026-09-02.)*
- [ ] ⚠️ **Wiring Sentry will change this page.** A crash reporter adds
      *Diagnostics → Crash Data* and *Performance Data*. The labels must be updated
      **before** the build 25 submission, not after.
- [ ] 🟡 **Controller/signer mismatch is confirmed and user-visible.**
      The public App Store listing reports `sellerName` and `artistName` =
      **SF MEDIA & PR LTD** (iTunes lookup for id `6787682466`, 2026-09-02), the archive is
      signed `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)`, but the linked privacy
      policy names the data controller as **Genesyx Ltd**.
      Signing identity and data controller are permitted to differ, but UK GDPR Art 13(1)(a)
      requires the controller's identity to be clear to the user. Today a user sees the app
      sold by one company and the policy written by another, with nothing linking them.
      **This is a legal/business decision, not a code fix** — either the policy explains the
      relationship, or the listing entity changes. Flagging, not resolving.
- [x] 🟢 **No pending rejections.** iOS 1.2.0 is *Ready for Distribution*; nothing is in
      review and nothing is in Pending Developer Release.

## 3. Live TestFlight / App Store state — 🟢 GREEN, VERIFIED 2026-09-02

Read directly from App Store Connect, not inferred from any repo file.

**TestFlight → iOS → Version 1.2.0:**

| Build | Status | Uploaded |
| ---: | --- | --- |
| **24** | Complete · Testing, expires in 83 days | 25 Aug 2026 20:39 |
| 23 | Complete · **Expired** | 25 Aug 2026 20:36 |
| 22 | Complete · Testing, expires in 76 days | 19 Aug 2026 00:34 |

Earlier versions: 1.1.1 build 16, 1.1.0 build 13.

**App Store:** iOS 1.2.0 is **Ready for Distribution** with **Build 24** attached.
Public listing confirms version 1.2.0 live, released **2026-08-26 09:14 UTC**,
`minimumOsVersion` 16.0, bundle `com.genesyx.app`.

**Conclusions:**
1. Highest build ever uploaded = **24**. Build **25 is free**. → item 1 unblocked.
2. `changes_iOS.md:11` was right that 24 is live. My earlier session note saying build 22
   was *Pending Developer Release* is **superseded** — that was true a fortnight ago.
3. `project.yml:108-112` is **wrong**: build 23 *was* uploaded. → see item 1.

## 4. Crash reporting — 🟡 RISK ACCEPTED — **none in build 25, deferred to 26**

- [x] 🟢 Confirmed absent today. Grep across `project.yml`, `Package.swift` and
      `Info.plist` for Crashlytics / Sentry / Bugsnag / Firebase returns **zero hits**.
      The only SPM packages are `GenesyxCore` (local) and `Supabase` (2.50.0).
- [x] ⚠️ **Decision (owner, 2026-09-02): DEFERRED. Build 25 ships with no crash reporting.**
      Sentry was chosen, then deferred to keep build 25 moving. **This is an accepted risk,
      recorded here so it is not mistaken for an oversight.**

**What the risk actually is, at 5,000 users.** There is no automatic signal when the app
crashes. Not a reduced signal — none. Apple's own crash reports in ASC → TestFlight →
Crashes are symbolicated but sampled, opt-in per user, and often days late, so a crash
affecting a minority of devices can run for a week unnoticed. The realistic detection path
is a tester choosing to write to you.

**Manual monitoring plan standing in for it — do these, or the risk is unmanaged rather
than accepted:**
- Check **ASC → TestFlight → Crashes** and **Feedback** daily for the first week of rollout,
  then twice weekly. Both are already in the left sidebar of the TestFlight tab.
- Watch **Supabase → Logs** for a rise in 4xx/5xx on `daily_logs`, `ph_records`,
  `supplements` and `consent_events`. A client crash loop usually shows up as a write
  pattern that stops mid-sequence.
- Treat **install-to-session ratio** in TestFlight as a crash proxy: installs climbing while
  sessions stay flat is the signature of a launch crash.
- **Rollback trigger:** any crash reproducible on a supported device at launch or during
  consent capture. Do not ramp past the first cohort until a week passes with none.

- [ ] Revisit for build 26. When it lands, implement as below and update App Privacy first.
- [ ] Implementation, when the DSN lands — privacy-defensive by default for an Article 9 app:
  - `sendDefaultPii = false` — no IP address, no email, no username.
  - No `setUser` call; crashes stay unattributed to a person.
  - Breadcrumbs suppressed on the screens rendering cycle, pH and intimacy data.
  - DSN carried as a build setting in `project.yml` alongside `SUPABASE_ANON_KEY`, not
    hardcoded in Swift. *(A DSN is not a secret — it ships in every client by design — but
    this keeps it consistent with how the project already handles that class of value.)*
- [ ] Update App Privacy (item 2) to add *Diagnostics → Crash Data / Performance Data*
      **before submitting build 26** — i.e. only once Sentry actually ships.
      **Do not add it for build 25:** build 25 collects no diagnostics, and declaring a
      category the binary does not collect is itself an inaccurate privacy declaration.

**Sequencing note (resolved):** the earlier note here said Sentry must be wired before the
item 1 archive. That was written under the wire-now decision and is now obsolete — the
deferral was taken first, so the archive was correctly cut without it.

## 5. Real-device / TestFlight QA — 🔴 RED (blocked on a new-version archive)

- [ ] 🔴 The owner approved upload of the verified 2 Sep archive, but App Store Connect
      rejected it because the `1.2.0` train is closed. Physical-device QA cannot begin until
      item 1 produces an archive under a higher marketing version and Apple accepts it.
- [ ] Add to the smoke set, from the item 7b finding: edit a supplement on Android, then
      confirm on iOS that it survives the pull intact (it will reorder — that is expected and
      documented, not a bug to chase on the device).
- [ ] Smoke set: sign-up, consent grant/withdraw, daily log, pH, supplements, cycle view,
      password reset, account deletion, Google Sign-In.
- [ ] **Consent round-trip (V5) is still open from the previous workstream**: grant →
      withdraw → re-grant should append exactly three rows at version `2026-08-18.v2`.

## 6. Staged rollout plan — 🟡 DRAFTED, needs owner sign-off

### Sequencing — the order is the safety mechanism

1. Upload build 25 to App Store Connect. **Do not** release to the App Store yet.
2. TestFlight **internal** first (existing SF / SF_media groups, ~11 testers). Sit here
   until the item 5 smoke set passes on a real device.
3. TestFlight **external**, ramped: ~100 → ~1,000 → ~5,000. Do not skip the 100 cohort;
   it is the only stage where you can still read every piece of feedback by hand.
4. App Store **phased release**: 1% → 2% → 5% → 10% → 20% → 50% → 100% (Apple's fixed
   7-day schedule). Only start it once the external cohort has been quiet for a week.
5. **Only after build 25 is live on the App Store**, set
   `app_config.min_supported_build = 25`.

**Step 5 is the one that can hurt everybody at once.** `changes_iOS.md:60` and the tag
message both carry the warning: setting it while 24 is public locks out every current
user. The gate is fail-open by construction — missing table, missing row, malformed value
and network error all proceed (`RootRouting.swift:84-114`,
`AppContainer.checkMinimumVersion()` at `AppContainer.swift:84-98`, pinned by
`RootRoutingTests.testAMissingOrMalformedMinimumFailsOpen`). So leaving the row unset is
safe indefinitely. The danger is exclusively in setting it early.

### Success metrics — thresholds, so the decision is not a judgement call each time

| Metric | Where | Green | Pause |
| --- | --- | --- | --- |
| Crash-free sessions | ASC → TestFlight → Crashes (sampled; see item 4) | ≥ 99.5% | < 99% |
| Installs → first session | TestFlight installs vs sessions | sessions track installs | installs climb, sessions flat = launch crash |
| Sign-up completion | Supabase `auth.users` vs consent rows | ≥ 80% reach consent | < 60% |
| Consent grant rate | `consent_events` action=`granted` per new user | ≥ 90% | < 75% |
| Daily-log submission | `daily_logs` rows per active user per day | ≥ 0.5 | < 0.2 |
| Supabase 5xx | Supabase → Logs | < 0.5% of requests | > 2% sustained 1h |

### Rollback triggers — any one of these pauses the ramp

- Any crash reproducible on a supported device at **launch** or during **consent capture**.
- Consent rows failing to append (an Art 7(1) evidence failure, not just a bug).
- Auth sign-in failure rate above 5%, or any report of one account seeing another's data.
- Supabase 5xx above 2% sustained for an hour.
- Two or more independent reports of the same data-loss symptom.

**How to actually pause:** TestFlight — remove the build from the external group, which
stops new installs but does not uninstall it from testers who already have it. App Store —
Pricing and Availability → **Pause Phased Release**. Neither removes the app from anyone
already running it, so a bad build still needs a fixed build 26, not just a pause.

- [ ] Owner sign-off on the thresholds above.

## 7. Parity & divergence vs Android — 🟡 PARTIAL

Audited against Android **1.4.2 (23)**, commit `652788e`, branch `main`, 2026-09-02.

**First, the framing in the original checklist was wrong.** It asks whether iOS
`StreakEngine` sits "under the shared `tracking_test_vectors.json` contract". **There is no
shared file.** Each repo keeps its own vectors in its own schema — iOS
`Tests/GenesyxCoreTests/Resources/tracking_test_vectors.json` (`"contractVersion": 3`),
Android `app/src/main/kotlin/.../tracking/tracking_test_vectors.json`
(`"spec": "genesyx-tracking-v1"`). Both files' own comments state explicitly that they are
NOT copies of each other and that what the platforms share is the **rules**, not the file.
Neither platform's streak test consumes its vectors.

**The real risk is not "iOS is behind".** It is that the two files use different schemas and
different version markers, so **nothing mechanically detects drift**. A rule can change on
one platform and no test fails on the other. The only guard is a written instruction in both
file comments to move both in the same change — a discipline, not a test.

### 7a. Streak math — 🔴 DIVERGES

- [x] ✅ **VERIFIED — article reads extend the streak on Android only, and it is live.**
      `StreakEngine.kt:81,83` unions `articleReadDates` into `activeDates`. It is a defaulted
      parameter, so I checked the call sites: `StreakRepository.kt:53` passes real
      `articleDates`. iOS has no article-read concept at all — grep for
      `articleRead|readArticle` across `Sources/` and `App/Genesyx/` returns nothing.
      **Consequence:** a day she only reads a Learn article keeps her streak alive on
      Android and breaks it on iOS. Same account, two different numbers.
- [ ] ⚠️ **REPORTED, NOT INDEPENDENTLY VERIFIED** (from the parity agent; treat as leads):
      "best" streak computed differently (iOS scans history for the longest run; Android
      keeps a persisted running max of the *current hydration* streak); milestone
      re-celebration on lapse exists on iOS only; a whitespace-only note counts as
      meaningful on iOS (`!(notes ?? "").isEmpty`) but not on Android (`isNullOrBlank()`).
      **Do not quote these as fact until checked.**

### 7b. Supplement contract — 🟡 NOW VERIFIED; one real gap, not release-blocking

- [x] ✅ The checklist names the wrong Android type. `SupplementToggleSet.kt` is a UI count
      helper, **not** the counterpart to iOS `SupplementRecord`. The real sync layer is
      `UserSupplementEntity.kt` + `UserSupplementRepository.kt`.
- [x] ✅ **VERIFIED — conflict resolution is aligned.** iOS `SupplementSync.merge` /
      `mergeIncremental` (`SupplementSync.swift:52-95`): a `pendingSync` local record wins
      outright, otherwise the later `updatedAt` wins. Android `refresh`
      (`UserSupplementRepository.kt:195-202`): any local row whose `syncStatus != SYNCED` is
      skipped entirely ("keep local edits"), otherwise the incoming row is adopted unless it
      is strictly older. Same rule, same precedence. **No action.**
- [x] ✅ **VERIFIED, but severity downgraded — the nullable `updatedAt` is not a live bug.**
      It is genuinely nullable on all three layers (`UserSupplementEntity.kt:28`,
      `UserSupplementDto.kt:20`, and the server column itself —
      `20260813_android_supplements_backend.sql:129` is `updated_at timestamptz default
      now()` with **no `not null`**, unlike the neighbouring table at `:69-70`). Android
      `:198` does treat a null on either side as "adopt incoming". **But** `:195` has already
      skipped every non-`SYNCED` row, so a locally-pending edit can never be clobbered by it.
      The only row that can reach the null branch is one already marked `SYNCED` — i.e. one
      that already agrees with the server. A latent schema weakness worth tightening
      (`set not null`), **not** a data-loss path. Not a blocker.
- [x] 🔴 **VERIFIED — the ordering claim is true, and the cause is bigger than the ordering.**
      The fact the report missed: **Android has a supplement edit path and iOS does not.**
      Android exposes `update()` (`UserSupplementRepository.kt:66`) wired to tap-to-edit
      (`UserSupplementsSection.kt:63, 87`). iOS has only `add` (`NutritionView.swift:922-926`)
      and `remove` (`:933-934`) — there is no update anywhere in the iOS repository or UI.
      iOS's own comment predicted this exactly (`SupplementSync.swift:110-112`): *"nothing
      edits an existing entry … Should an edit path ever be added, this becomes 'most
      recently touched last' and will want a `createdAt` of its own."* That edit path was
      added — on the other platform.
      **Consequence:** she edits a supplement on her Android phone, `updatedAt` bumps, the
      iOS pull adopts the row, and because iOS sorts by `(updatedAt, id)` while Android
      orders by `createdAt ASC`, the supplement **jumps to the bottom of the list on her
      iPhone** and stays put on Android. Cosmetic reordering, **no data loss**. Separately,
      she cannot edit a supplement on iOS at all — she must delete and re-add.
- [x] **Judgement: not release-blocking for build 25.** Both effects are pre-existing feature
      gaps, not regressions introduced by the RC work, and neither loses data. An iOS edit
      path (plus a real `createdAt` for ordering) is a **build 26** item.

### 7c. Learn article count — 🟢 SAME (the premise was wrong)

- [x] ✅ **VERIFIED INDEPENDENTLY.** Both platforms ship **32** articles. Id sets are
      identical (`a1-a10`, `g1-g10`, `w1-w12`); the set difference is empty in both
      directions. The "32 iOS vs 31 Android" belief is **stale — delete it.**

### 7d. Consent semantics — 🔴 DIVERGES, and iOS is the weaker side

- [x] ✅ **VERIFIED IN IOS SOURCE.** Granting consent does **not** re-run the pulls that were
      skipped while consent was absent. `ConsentRepository.grant()` →
      `record()` (`ConsentRepository.swift:74, 83-90`) appends the event, persists, and drains
      only the **consent event** queue. `AppContainer.hydrate()` — the method that refreshes
      profile, cycle, daily logs, pH and supplements — has exactly **one** caller:
      `session.onHydrate` (`AppContainer.swift:59`), fired only from
      `SessionRepository.applySignIn` (`:276`) and `restoreSignedIn` (`:165`).
- [x] ✅ **Severity corrected.** `restoreSignedIn` is called by `bootstrapAuth` (app launch)
      and `handleAuthEvent`. So the recovery is an **app relaunch**, not a sign-out/sign-in.
      The parity agent said "until her next sign-in", which overstates it.
      **Real consequence:** after granting consent from Profile, she sees an empty or stale
      view until she next relaunches the app. Confusing, not data loss.
- [ ] ⚠️ Reported (unverified): Android calls `resyncAfterConsentGranted()` on grant, so it
      recovers immediately; but Android *refuses* to drain its outbound queue while consent
      is absent, whereas iOS drains regardless. The agent explicitly could not confirm that
      Android's resync actually drains the stalled supplement queue.
- [ ] **Decision needed:** fix iOS (call `hydrate()` after a successful grant) or accept and
      document. It is a small, well-isolated change — but it is a **code change after the
      tag**, so it belongs in build 26 unless you judge it release-blocking.

## 8. Final go/no-go — 🔴 RED

Blocked on 1, 2, 3, 4, 5, 6.

---

## Build & run status (verified today, 2026-09-02)

| Suite | Executed | Result |
| --- | ---: | --- |
| `GenesyxCoreTests` (`swift test`) | 314 | 🟢 314 pass |
| `GenesyxAppTests` (iPhone 17 Pro sim) | 393 | 🟢 393 pass |
| `GenesyxUITests` | 102 | 🟡 100 pass, 1 skip, **1 fail** |

The single UI failure is `DemoWalkthroughTests.testDemoWalkthrough()`:
`DemoWalkthroughTests.swift:49 — DEMO_PASSWORD is not set in the runner environment`.
Environmental, not a product defect — but it is an `XCTFail`, not an `XCTSkip`, so
`xcodebuild test` now returns `** TEST FAILED **` on any machine without that secret
exported. See "Known stale claims" below.

## Known stale claims (do not repeat as fact)

- `changes_iOS.md:~118` records `GenesyxAppTests` at **383** and `GenesyxUITests` at
  **99 executed / 4 failed**. Today's run gives **393** and **102 / 1 failed**. The doc's
  test table is stale; the tree moved after it was written.
- `changes_iOS.md:17` — "No commit, archive, upload… was performed." Accurate as to
  commit and upload; an archive *does* exist from 28 Aug, but it predates this work.
- **`project.yml:108-112` is factually wrong.** It states "Build 23 was archived but never
  uploaded; nothing but this machine ever saw it, so 24 is what testers receive after 22
  and its notes should read against 22, not 23." App Store Connect shows build 23 uploaded
  **25 Aug 2026 20:36**, three minutes before build 24, now Expired. Testers in two groups
  had it. Release notes written "against 22" may therefore be wrong for anyone who took 23.
  To be corrected in the build-25 commit.
- My own earlier session note — "1.2.0 build 22 approved, Pending Developer Release" — is
  **superseded**. Build 24 has been live since 26 Aug.

## Verified-vs-assumed ledger for this loop

Everything in items 1, 2 and 3 above was read from a primary source today: `git`, the
archive `Info.plist`, `stat`, the App Store Connect UI, and the public iTunes lookup API.
No status was inferred from `changes_iOS.md`, `CHANGELOG.md` or `to do list.md`.

**Item 7b is now verified too** — read from both trees and the migration SQL, not from the
parity agent's report. Two of its three claims survived contact with the source but with the
severity changed; the third was true for a reason the report had not found (Android has an
edit path, iOS does not). What remains unverified is explicitly marked: 7a's three streak
claims and 7d's Android-side resync claim.

## Next highest-priority red item

**Item 1 — select and cut the next marketing version.** Upload approval was given and the
verified archive was submitted, but Apple rejected it because version `1.2.0` is already
approved and its pre-release train is closed. No build reached TestFlight. The likely next
version is `1.2.1`; once the owner confirms that version, update the project, commit/tag,
archive, verify, and upload the new artifact.

**Export trap, recorded because it has cost a build here before:**
`xcodebuild -exportArchive` defaults to `destination=export`. `method: app-store` governs
signing and packaging, not delivery — without an explicit `destination: upload` key in the
export plist you get a local .ipa and no upload, silently, with a success message.

The smoke set for item 5, once it is on a device: sign-up, consent grant, daily log, pH,
supplements, cycle view, password reset, account deletion, Google Sign-In. Plus the still-open
**V5 consent round trip** — grant → withdraw → re-grant, expecting three append-only rows at
version `2026-08-18.v2` in the order `granted, withdrawn, granted`.
