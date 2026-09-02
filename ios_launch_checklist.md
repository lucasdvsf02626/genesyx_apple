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

## 1. Build identity resolved — 🟡 UNBLOCKED, PLAN AGREED, NOT YET EXECUTED

- [x] 🟢 **Decision: Option A at build number 25.** Item 3 is now verified — build 25 has
      never been uploaded, so 25 is free and matches what `changes_iOS.md` already claims.
      No renumber to 26 is needed.
  - ~~Option B: ship the existing 28-Aug archive~~ — **rejected on evidence above.**
- [ ] Commit the working tree, tag `v1.2.0-b25`, re-archive from the tagged state.
      **Must happen after Sentry is wired (item 4), or the archive is immediately stale again.**
- [ ] Correct the stale comment at `project.yml:108-112` in that same commit — it claims
      "Build 23 was archived but never uploaded; nothing but this machine ever saw it."
      **App Store Connect proves otherwise: build 23 was uploaded 25 Aug 2026 20:36 and is
      now Expired.** See "Known stale claims".
- [ ] Delete or rename the stale `2026-08-28/Genesyx-1.2.0-b25.xcarchive` once the real
      one exists, so two different artefacts never both answer to "b25".
- [x] 🟢 The dirty tree is safe to commit: `.gitignore` additions are `build_sim_qa/`,
      `.codegraph/`, `.claude/`, `/graft/` — **`graphify-out/` is untouched**, as required.
      `.mcp.json` contains no credentials (grep for key/token/secret/password: 0 hits).

**Nothing is committed. Awaiting your decision on item 3 before I commit or tag.**

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

## 4. Crash reporting — 🔴 RED — **decision made: wire Sentry**, not yet implemented

- [x] 🟢 Confirmed absent today. Grep across `project.yml`, `Package.swift` and
      `Info.plist` for Crashlytics / Sentry / Bugsnag / Firebase returns **zero hits**.
      The only SPM packages are `GenesyxCore` (local) and `Supabase` (2.50.0).
- [x] 🟢 **Decision (owner, 2026-09-02): wire Sentry.**
- [ ] **Blocked: needs a DSN.** A Sentry project must exist first.
- [ ] Implementation, when the DSN lands — privacy-defensive by default for an Article 9 app:
  - `sendDefaultPii = false` — no IP address, no email, no username.
  - No `setUser` call; crashes stay unattributed to a person.
  - Breadcrumbs suppressed on the screens rendering cycle, pH and intimacy data.
  - DSN carried as a build setting in `project.yml` alongside `SUPABASE_ANON_KEY`, not
    hardcoded in Swift. *(A DSN is not a secret — it ships in every client by design — but
    this keeps it consistent with how the project already handles that class of value.)*
- [ ] Update App Privacy (item 2) to add *Diagnostics → Crash Data / Performance Data*
      **before** submitting build 25.

**Sequencing note:** Sentry must be wired *before* the item 1 archive. Archive first and
the binary ships with no crash reporting, which defeats the purpose of the decision.

## 5. Real-device / TestFlight QA — 🔴 RED (not started)

- [ ] Cannot start until item 1 produces an archive worth testing.
- [ ] Smoke set: sign-up, consent grant/withdraw, daily log, pH, supplements, cycle view,
      password reset, account deletion, Google Sign-In.
- [ ] **Consent round-trip (V5) is still open from the previous workstream**: grant →
      withdraw → re-grant should append exactly three rows at version `2026-08-18.v2`.

## 6. Staged rollout plan — 🔴 RED (not written)

- [ ] Not yet drafted. **One hard sequencing constraint is already known and must not be
      missed:** `changes_iOS.md:60` — do **not** set `app_config.min_supported_build` to 25
      until build 25 is actually live. Activating it while 24 is public locks out every
      current user. The gate is fail-open by design (`RootRouting.swift:84-114`,
      `AppContainer.checkMinimumVersion()` at `AppContainer.swift:84-98`), so an unset row
      is safe — the danger is setting it early, not leaving it unset.

## 7. Parity & divergence vs Android — 🟡 PARTIAL

- [ ] **Streak math** — `StreakEngine` (`Sources/GenesyxCore/Streaks/StreakEngine.swift`)
      is tested by `StreakEngineTests`, which does **not** consume
      `tracking_test_vectors.json`. Only `TrackingEngineVectorTests` and
      `MeaningfulLogTests` read the shared contract file. So iOS streak maths is
      well-tested but **not proven equal to Android's**. Red until a shared vector or an
      accepted divergence exists.
- [ ] **Supplement contract** — iOS has `SupplementRecord` / `SupplementSync`
      (`Sources/GenesyxCore/Models/SupplementSync.swift`). There is **no
      `SupplementToggleSet` in the iOS tree**; that is an Android type. Field-level diff
      not yet done.
- [ ] **Learn article count** — 32 iOS vs 31 Android, unreconciled.
- [ ] **Consent semantics** — iOS refreshes consent *before* health pulls in
      `AppContainer.hydrate()` (`AppContainer.swift:113-141`) and each repository gates its
      own pull; pending queues still drain because those writes were made under live
      consent. Whether Android matches is not verified from this repo.

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

## Next highest-priority red item

**Item 4 — Sentry.** It is now on the critical path: it must be wired *before* the item 1
commit/tag/archive, or the build-25 binary ships without it. **I need a Sentry DSN** from
a project you create; everything else about the integration I can do from here.
