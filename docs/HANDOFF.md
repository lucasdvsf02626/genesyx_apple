# Genesyx iOS — Session Handoff

> Written 2026-08-11, reconstructed from the 2026-08-10 session (which ended on token exhaustion
> before this could be saved). Companion to `CHANGE_LIST_PLAN.md`, which tracks the client's
> change list task-by-task. This file tracks **what is in flight right now**.

**Branch:** `main` · **HEAD:** `8580dd6` *"Freeze the 1.2.0 release candidate: the auth gate,
the free guide, and supplement sync"* — **this is the release SHA**; the tree is now clean apart
from `graphify-out/`, `.claude/` and the excluded duplicate `docs/assets/` PDF. · **Version:**
1.2.0, build **still 18 in `project.yml` — must be bumped before archiving**
· **Test baseline:** 267 domain + 288 app + 79 UI (1 skip), 0 failures — **one sweep over one
byte-identical tree**, 2026-08-14: `/tmp/genesyx_h22_final_domain.log` (267/0, 14:18),
`/tmp/genesyx_h22_final_app.log` (288/0, 14:20), `/tmp/genesyx_h22i_full_ui.log`
(886.043 s, 79 exec / 1 skip / 0 fail, 14:16). The UI run was deliberately adversarial:
`xcrun simctl keychain <UDID> reset` first, to re-arm iOS's "Save Password?" sheet, on a
simulator with no other `xcodebuild` attached. Historical H21/H11 67/1/0 logs remain valid
for those batches. All of that was measured on the tree that became **`8580dd6`**, which also
compiles clean in the **Release** configuration (0 errors, `/tmp/genesyx_rc_release_build.log`).

```bash
swift test && xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:GenesyxUITests
```
Do **not** pass `-quiet` — it has returned exit 0 with no summary and hidden a real result.

---

## 0. STOP HERE FIRST — state at handoff, 14 Aug 2026

**Nothing is committed. Nothing is pushed. No Supabase change was made in this session.**
H21 engineering gates are closed. H11 / T22 is closed. **H22 (mandatory authentication
gate): Engineering Done; simulator verified; physical-device QA deferred.** No physical
iPhone is available — that absence does not keep H22 In progress. The PDF content
blockers in §0h remain open. Exclude `graphify-out/` from any product commit.

**Sections 1–3 remain 37/44 = 84% and 37/42 = 88%.** No release-scope row closed this
pass. Website science/Shettles stay **BLOCKED**. Profile / name-password / edit-controls
stay **IN REVIEW**. Physical cellular stays **DEFERRED**. D3 and D4 stay **DESCOPED**.

### 0-H22. Mandatory authentication gate (P0, 14 Aug 2026)

`RootView` used to mount `MainTabView` from `genesyx.onboardingComplete` alone. Session
state is now the credential. `onboardingComplete` is only a progress flag.

| File | Change |
|---|---|
| `App/Genesyx/Data/App/RootRouting.swift` | Pure `RootDestination` decision. |
| `App/Genesyx/Data/SessionRepository.swift` | `resolving` / `signedOut` / `signedIn`; validated restore; auth events. |
| `App/Genesyx/Data/App/RootView.swift` | Routes from session first; mandatory `AuthView`; held invites. |
| `App/Genesyx/UI/Auth/AuthView.swift` | `allowsDismissal`; no “Back to app” in mandatory mode. |
| `App/Genesyx/Data/Remote/RemoteBackend.swift` / `SupabaseBackend.swift` | `validatedSession` + `observeAuthState`. |
| `App/Genesyx/Notifications/NotificationService.swift` | `isActive` requires `session.isSignedIn`; cancel on sign-out. |
| `App/Genesyx/Data/App/AppContainer.swift` / `GenesyxApp.swift` | Hydrate/drain only while signed in; Release fail-closed. Plus the DEBUG-only `-uiTestPendingNotification` hook (`GenesyxApp.swift:26-38`). |
| `App/GenesyxTests/SessionExpiryTests.swift` | **New, 4 tests.** The expired/revoked-token lifecycle, driven from an injected `AuthBackend` fake. |
| `App/GenesyxUITests/AuthGateUITests.swift` | 11 → 12. Vacuous notification test replaced by a real pair; the misleading name corrected. |

#### The second audit pass — two tests that were green while claiming more than they proved

Both gaps were found on 14 Aug by re-reading the tests rather than the results. A green suite cannot
report this class of defect on itself.

**(a) The expired/revoked-token path had no coverage at any level.** The UI test that appeared to
cover it launched with `-uiTestSignedOut`, which seeds **no credential** — the *missing*-session
path. A cached credential the server has stopped honouring is a different mechanism, and it was the
untested one. `SessionExpiryTests` now drives it through an injected `AuthBackend` — **no Supabase,
no network, no account**:

| Test | What it proves |
|---|---|
| `testExpiredSessionSignsOutAndFiresTheBecameSignedOutHook` | `.sessionExpired` signs out **and** fires `onBecameSignedOut` — the hook that drops the held notification destination and cancels the schedule. A silent state change here leaves private routing armed. |
| `testAnExpiredSessionCannotComeBackFromARefreshOrAnExpiredInitialSession` | Neither `.tokenRefreshed` nor `.initialSession(userId: nil)` resurrects it. `tokenRefreshed` only ever describes an already-live session; treating it as a credential would re-open the tabs on the strength of the token that just lapsed. |
| `testLaunchWithAnExpiredCachedSessionNeverSignsIn` | Cold launch with `currentUserId` non-nil but `validatedSession()` nil resolves `.resolving` → `.signedOut`, never `.signedIn`. Mounting off the cached id alone is the defect the gate exists to prevent. |
| `testAFreshSignInAfterExpiryReachesSignedIn` | A genuine new session still signs her in — without this the gate could be "correct" by refusing everything. |

The misleading UI test is renamed `testMissingSessionNeverShowsPrivateContent` and now points at
`SessionExpiryTests` for the other path.

**(b) `testNotificationTapWhileSignedOutDoesNotOpenATab` performed no notification action.** It was a
strict subset of the test above it and its name claimed evidence it did not provide. Replaced by a
pair. `-uiTestPendingNotification <tab>` is **DEBUG-only** (`#if DEBUG`, referenced nowhere else in
product code, so Release cannot see it) and injects a destination through the **same** `payload` →
`destination` decode the real `didReceive` handler uses — so the test asserts against a genuinely
held destination, not an app that simply has nothing pending. XCUITest cannot deliver a system
notification to a cold-launched app; the gate's job is what happens to the destination afterwards,
not how it arrived, and the test no longer claims otherwise.

- `testPendingNotificationWhileSignedOutNeverOpensItsTab` — the gate holds it (6.410 s).
- `testPendingNotificationOpensItsTabOnceAuthenticated` — **the control** (5.449 s). The same
  injection on a signed-in launch *does* land on Insights. Without it the first test would also pass
  if the hook did nothing, so the control is what makes it evidence.

**Falsification of the new tests (recorded):** re-inserted `case .sessionExpired: break` into
`SessionRepository.swift` → exit 65, `Executed 4 tests, with 6 failures`, `** TEST FAILED **`
(`/tmp/genesyx_h22_expiry_falsify.log`). 3 of 4 failed on the intended assertions (`("signedIn") is
not equal to ("signedOut")`, `onBecameSignedOut must fire so held private state is dropped`); the 4th
correctly still passed because it exercises the bootstrap path, not the lifecycle event. Production
line restored and re-verified (`case .signedOut, .sessionExpired:`, `SessionRepository.swift:124`).

**Falsification (recorded):** restored the old `if onboardingComplete { MainTabView }` route.
Three new tests failed as required (50.417 s, `** TEST FAILED **`):
- `AuthGateUITests.testCompletedOnboardingWithNoSessionOpensMandatoryLogin` — `AuthGateUITests.swift:40`
- `AuthGateUITests.testLogoutRemovesEveryPrivateTab` — `AuthGateUITests.swift:65`
- `GenesyxUITests.testSignOutClearsHealthDataLocally` — `GenesyxUITests.swift:1462` `logout must land on mandatory authentication`

Restored production routing. Targeted UI after restore: **12/0**, 103.276 s.
Full UI after the H22 evidence cleanup: **79 exec / 1 skip / 0 fail**,
`/tmp/genesyx_h22i_full_ui.log` (886.043 s, 14 Aug 14:16).
No product/test file for the gate is newer than that log.

**Two red UI results were diagnosed on 14 Aug. Neither was product code.** Both are worth
recording because both would otherwise be re-diagnosed as an app bug.

*1 — `LifecycleE2ETests.testSignOutDoesNotBlankMedicalSources`.* After the test submits
credentials, iOS sometimes decides that was a successful sign-in and offers its own
**"Save Password?" sheet**. It belongs to another process, so it never appears in the test log;
what surfaces instead is the app's own controls going unhittable, because the sheet ships a
full-screen touch-blocking backdrop. Proven from the failure-linked attachment
(`xcrun xcresulttool export attachments`, the dump with `isAssociatedWithFailure: true`): the
app was pid 34347, and a second window owned by **pid 34360** carried
`Sheet … label: 'Save Password?'` plus `Other, {{41.0, 315.0}, {402.0, 874.0}}`. Both the
`Medical Sources & Disclaimer` row and the `Profile` tab were present in the tree and simply
unreachable. XCUITest merges layered system windows into the app-under-test's snapshot, so
`app.buttons["Not Now"]` can reach it — that is what `dismissSystemSavePasswordSheet` does,
gated behind `if !profile.isHittable` so it costs nothing when the sheet is absent. **No
assertion was weakened.** `xcrun simctl keychain <UDID> reset` re-arms the prompt on demand;
without it iOS suppresses re-offering once "Not Now" has been answered, which is why the
failure looked random. In the authoritative run the guard is **load-bearing, not decorative**:
at t=15.64 s `profile.isHittable` returned false, the guard found and tapped "Not Now" at
t=16.90 s, and only then did `Tap "Profile"` succeed. Honest caveat: with the guard removed and
the same test run alone 5×, and its whole class 3×, it passed every time — the blocking is
intermittent, so the guard is proven necessary in the armed full-suite configuration and proven
harmless otherwise, not proven necessary on every run.

*2 — `GenesyxUITests.testInsightsOpensLogHistory`, `kAXError -25218 / "Error getting main
window"`.* Caused by **two agents driving the same simulator UDID at once**; found with
`pgrep -fl`, which showed a second `GROK_AGENT=1 … xcodebuild test … -destination
'…id=6EFF8D1E-…'`. Concurrent `xcodebuild test` runs on one UDID corrupt each other's
accessibility server. **Rule: one agent owns the simulator for the duration of a UI run.**
The authoritative run above was made with `pgrep` confirming zero other `xcodebuild` processes.

**What the simulator cannot prove.** Every UI test runs `AppContainer.uiTestSeeded()` with
`backend: nil`. They prove the routing table and the view wiring; they never exercise Supabase's real
session restore. **Keychain persistence across a genuine cold boot, a token revoked from another
device, and Sign in with Apple on real hardware are unproven, not passed.** That is the whole content
of "physical-device QA deferred" — it is a real gap, not a formality.

**Engineering Done; simulator verified; physical-device QA deferred.** Physical
logout/relaunch is not available hardware, not unfinished engineering.

**H22 is not in build 18.** Build 18 was archived 13 Aug; the gate landed 14 Aug and is
uncommitted. A **new archive with a new build number** is required before H22 can reach TestFlight,
and build-18 notes must not be rewritten as though it shipped there. See `TESTFLIGHT_B18.md` row H22.

### 0-FROZEN. Five product decisions the client closed on 14 Aug 2026 — DO NOT REOPEN

These are **settled input, not open questions.** They were frozen specifically to stop every
assistant, reviewer and future session re-litigating them. Do not re-analyse, re-propose,
re-estimate or "improve" any of them. If a later request appears to contradict one, **stop and ask**
rather than assuming it was reversed.

| # | Decision | Ruling | What it closes |
|---|---|---|---|
| **D1** | Warm / premium presentation | ✅ **Approved** | The subjective sign-off group 5 / item 2A was blocked on. Group 5 is now 4/4. |
| **D2** | Deleting a whole daily log | ❌ **Not in this release** | The data-retention ruling item 1B was half-blocked on. **Build no delete path on either client.** |
| **D3** | Cycle edits + article reads counting toward the streak | ❌ **Not in this release** | H6 / item 7. |
| **D4** | Occasional streak restore | ❌ **Not in this release** | H7 / item 8. |
| **D5** | The bundled guide PDF | ⚠️ **Usable internally — NOT App Store-ready** | Ships in internal/TestFlight builds only; a public-submission blocker until §0h is done. |

Three consequences a future agent must not get wrong:

1. **D3 + D4 together cancel the new production column and the Android migration** either one would
   have required. **No schema change is now needed for the streak.** Do not add one.
2. **D3, D4 and D2 are descoped, not delivered.** They remain change-list items and are counted as
   unbuilt. Never report them as done. The honest figures are **37 of 44 (84%)** on the original
   scope and **37 of 42 (88%)** against the remaining release scope; quote both.
3. **D1 approves a direction, it does not licence free restyling.** Every visual change still goes
   through the same tests, accessibility expectations and compliance guards as any other change.

**Website, re-fetched 14 Aug:** two new slugs exist and **must not be wired**.
`https://genesyx.co.uk/pages/vaginal-ph-fertility-science` is the same uncited product copy
as `/pages/ph-tracking`. `https://genesyx.co.uk/pages/shettles-method-evidence-limitations`
is an empty slug title — no “unproven”, no Wilcox. App grep of both paths is 0. **Item 1
stays BLOCKED.** Detail in `CHANGE_LIST_PLAN.md` §0.1.

### 0a. Where the repository is

```
git rev-parse --short HEAD   →  8580dd6
git rev-parse --abbrev-ref HEAD → main
```

`git status --short` is large because it carries every earlier uncommitted batch as well as this
one. `git diff --stat` (excluding the `graphify-out/` tooling directory) totals **58 files changed,
4385 insertions, 531 deletions** as of this audit, plus untracked H21/H22 product files
(`RootRouting.swift`, `AuthGateUITests.swift`, `FreeGuideView.swift`, recipe images, the bundled
PDF). Do not reset, stash or discard any of it — batches 1 through 9 plus H22 all live in this tree.

### 0b. The exact task being completed

**H20 audit finding #2 — "Unlock My Free Guide" unlocks nothing.** The client returned a product
decision, and this session implemented it. Tracked as tasks #48–#54; **#48–#54 are complete.**
Falsification and the full UI suite were re-run 14 Aug 2026 against a fresh backup of the
production file. The PDF content blockers in §0h remain open.

### 0c. The decision that was approved — implement exactly this, do not re-litigate it

> **"Open My Free Guide" must open a bundled offline PDF immediately — without login, email,
> waiting list or Supabase — and the same guide must also be available under Learn → Guides.**

Signed-off in eight points: relabel the CTA to **"Open My Free Guide"**; open the bundled *7-Day
Fertility Nutrition Starter Guide* immediately; work **before registration, offline, with no email,
waiting list, authentication or Supabase**; closing it returns to the readiness summary;
**"Register / Login to continue" stays a separate action**; the same guide is reachable under
**Learn → Guides**; the CTA **no longer routes to `WaitlistView`**; and the backend waiting-list API
is **not deleted** — only this CTA is disconnected, because Android shares that backend and no proof
was attempted that it has no other consumer.

Full text and rationale: `CHANGE_LIST_PLAN.md` §11.1.

### 0d. What was implemented

| File | State | What changed |
|---|---|---|
| `App/Genesyx/Resources/Genesyx_7_Day_Fertility_Nutrition_Starter_Guide.pdf` | **new**, untracked | The guide, 6.3 MB. Added under `App/Genesyx`, which `project.yml` sweeps in wholesale, so **XcodeGen** classified it into Copy Bundle Resources automatically — 4 lines of pbxproj, no hand editing. |
| `App/Genesyx/UI/Learn/FreeGuideView.swift` | **new**, untracked | `enum FreeGuide` (title + resource name + `Bundle.main` URL) and `FreeGuideScreen`, a `NavigationStack` around a SwiftUI-wrapped `PDFView`. Presented as a **sheet** from both entry points, so dismissing returns to the caller by construction. Carries `guide.screen`, `guide.pdf`, `guide.done` accessibility identifiers, and an unavailable-state view for the build-misconfiguration case. |
| `App/Genesyx/UI/Onboarding/OnboardingFlowView.swift` | modified | 434 → **342 lines**. CTA relabelled; `onUnlockGuide` → `onOpenGuide`; `@State private var showGuide` plus a `.sheet`; the `.waitlist` step, the `@EnvironmentObject container` it needed, and the 81-line `private struct WaitlistView` are **deleted**. |
| `App/Genesyx/UI/Learn/LearnViews.swift` | modified | `GuideBookRow` shown when the **Guides** category chip is selected, opening the same `FreeGuideScreen`. |
| `App/GenesyxTests/FreeGuideBundleTests.swift` | **new**, untracked | 3 tests: the URL resolves from the **built app bundle**; PDFKit can actually open what shipped and it is multi-page; the title matches what the UI test asserts. |
| `App/GenesyxUITests/GenesyxUITests.swift` | modified | `testWaitlistMakesNoUnsendablePromise` **replaced** by `testTheFreeGuideOpensFromOnboardingWithNoWaitingList` and `testTheFreeGuideAlsoOpensFromLearnGuides`, plus a `guideReader(_:)` helper. |
| `Genesyx.xcodeproj/project.pbxproj` | modified | Regenerated by `xcodegen generate`. Backup at `/tmp/pbxproj.bak`. |
| `docs/CHANGE_LIST_PLAN.md`, `GENESYX_PROGRESS.md`, `docs/HANDOFF.md` | modified | This batch's documentation. |

Three decisions inside the implementation that are load-bearing — **do not "simplify" them away:**

1. **The guide is deliberately not a `LearnArticle`.** `LearnContentTests` asserts
   `articles.count == 32`, and `LearnReadLog.markRead(slug)` fires `.onAppear` in `LearnViews.swift`.
   Modelling the PDF as an article breaks the count *and* makes opening one PDF register as having
   read the ten written guides — which the brief explicitly forbade.
2. **`GuidePdfView.Coordinator` implements `pdfViewWillClick(onLink:)` as a no-op.** That is what
   stops PDFKit handing an embedded link straight to Safari, which would break both the offline and
   the pre-registration guarantee in a single tap.
3. **`RemoteBackend.joinWaitlist`, `SupabaseBackend.joinWaitlist`, the `join_waitlist` RPC and
   `waitlist_emails` are untouched**, and `RemoteError.notAvailable` was left in place — it is a
   shared error enum, not onboarding-only UI. `EmailValidator` also stays; it has two other consumers.

### 0e. Test commands and totals

Everything below was re-run **against the restored production tree**, after the falsification run —
not carried over from before it.

| Suite | Command | Result |
|---|---|---|
| Domain | `swift test` (~1 s) | ✅ **267 passed / 0 failed** |
| App | `xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx -destination "platform=iOS Simulator,id=6EFF8D1E-6556-45FA-AB67-1AE6EFF64575" "-only-testing:GenesyxAppTests"` (~25 s) | ✅ **276 passed / 0 failed** after the splash lockup (was 275 after H21; +1 `testBrandLockupArtworkExists`) |
| `FreeGuideBundleTests` | same, `"-only-testing:GenesyxAppTests/FreeGuideBundleTests"` | ✅ **3 executed / 0 failures**, 0.005 s |
| The 2 guide UI tests (after restore) | same, `"-only-testing:GenesyxUITests/GenesyxUITests/testTheFreeGuideOpensFromOnboardingWithNoWaitingList"` and `.../testTheFreeGuideAlsoOpensFromLearnGuides` | ✅ **2 executed / 0 failures**, 32.091 s — onboarding 20.740 s, Learn 11.351 s · `** TEST SUCCEEDED **` |
| Falsification | one-line `onOpenGuide: { }`, then the onboarding guide test | ✅ **failed as required**, exit 65, 28.044 s. `GenesyxUITests.swift:130` `XCTAssertTrue failed - the bundled PDF should render — a blank reader means it is not in the app bundle`. Restored from `/tmp/onb_h21_prod_20260814T104552.swift`; `cmp` byte-identical. |
| Restored tree compiles | `xcodebuild build-for-testing …` | ✅ `** TEST BUILD SUCCEEDED **`, 0 errors |
| Full UI suite | `"-only-testing:GenesyxUITests"` (785.545 s, `/tmp/genesyx_h21_full_ui.log`) | ✅ **67 executed, 1 skipped, 0 failures** · `** TEST SUCCEEDED **` |

**The PDF is confirmed in the built product, not merely in the repository:**
`~/Library/Developer/Xcode/DerivedData/Genesyx-adfpdsulhpkxjwhgqbthjlvpvgrl/Build/Products/Debug-iphonesimulator/Genesyx.app/Genesyx_7_Day_Fertility_Nutrition_Starter_Guide.pdf`
— 6,568,029 bytes, md5 `618149b77247080cc9061f971886d379`, **byte-identical to the repository
copy**. `FreeGuideBundleTests` additionally proves PDFKit can open what shipped and that it is
multi-page, which a filename check alone would not.

### 0f. What is NOT done — read this before claiming the batch is complete

**Both gates are now closed. This section is kept as the evidence trail, not as a to-do list.**

1. ✅ **Falsification completed 14 Aug 2026, 10:46.** Minimal one-line regression: `onOpenGuide: { }`
   (CTA does not open the guide). `WaitlistView` was not reconstructed. Recorded failure:
   `GenesyxUITests.swift:130` `XCTAssertTrue failed - the bundled PDF should render — a blank
   reader means it is not in the app bundle`, exit 65, 28.044 s. Restored from
   `/tmp/onb_h21_prod_20260814T104552.swift`; byte-identical at restore. Both guide UI tests re-run
   green (2/0, 32.091 s).
2. ✅ **The full UI suite was re-run green after the restore** — 67 executed, 1 skipped, 0 failures,
   **785.545 s**, `** TEST SUCCEEDED **` (`/tmp/genesyx_h21_full_ui.log`, 254,321 bytes, verified by
   reading the log rather than trusting a claim). **This is the authoritative run — it is the one
   that post-dates the falsification.** An earlier green run the same day at 10:42
   (`/tmp/ui_full2.log`, 783.312 s, same 67/1/0) pre-dates it and proves less; cite the 785.545 s
   run. Earlier still, one run failed `testSignOutClearsHealthDataLocally` because it looked for the
   old Home empty-state sentence — the cycle wipe was already correct, the test was pointed at the
   current card, and every run since has been green.

**Hash note, so nobody misreads it as a failed restore.** `OnboardingFlowView.swift` no longer
matches the restore hash `b85686926825890766d64990ae2f747e` (342 lines); it is now
`9124dd6ef35afe9cd86bf64bcf0fd4bf` (348 lines). Re-diffed 14 Aug: the **only** delta is line 82,
where the splash `Text("GENESYX")` became `Image("brand_lockup")` — an unrelated later branding
change, asset present with light and dark variants. `grep -ic waitlist` on that file returns **0**.
Re-diff before drawing any conclusion from the hash.

What remains is **not** an engineering gate: the four PDF content corrections and the medical
review in §0h. H21 is Done. The PDF is not App Store-ready (D5).

### 0g. Unfinished code

**None.** There is no half-written code in the tree. `OnboardingFlowView.swift` is the correct
version — 348 lines, compiling, `waitlist` count 0 — and both gates in §0f are closed.

Scratch files that exist and can be deleted once §0f is closed: `/tmp/onb_correct.swift` (the good
342-line file), `/tmp/waitlist_block.swift` (the extracted 81-line `WaitlistView`, kept only to make
re-falsification a copy-paste), `/tmp/pbxproj.bak`.

One tidy-up worth doing but not urgent: `docs/assets/Genesyx-Recipe-Book.pdf` is a 6.3 MB untracked
copy of the same file, rescued during the audit *before* the decision came back. It is now redundant
with the copy in `App/Genesyx/Resources` and should be deleted rather than committed.

### 0h. Blockers — the PDF is not App Store-ready, and that is a person's job

The supplied file is a **temporary integration asset**. It is wired in correctly and it renders. It
must not ship until:

1. **Filename and internal PDF metadata read "7-Day Fertility Nutrition Starter Guide"** — it was
   supplied as a recipe book, so a user who saves or shares it gets a different title from the one
   the app showed her.
2. **Page 20's typo "Download out free app" is corrected to "our".**
3. **Page 20's QR code / app-download call-to-action is removed or rewritten**, because it tells a
   reader who is already inside the app to go and download the app — and the QR route is precisely
   the silent exit to Safari the reader now blocks.
4. **The PDF is accessibility-tagged, or the app carries an accessible text equivalent.** The reader
   sets an `.accessibilityLabel` so VoiceOver does not land on an unnamed view, but a label is not a
   text equivalent.

**And, tracked separately: medical / content-source review of the guide has not been done.** Every
other piece of shipping content carries a citation, a disclaimer and a sign-off — that is the
compliance model the banned-phrase guards enforce. This PDF came in through a different door.

### 0i. The exact next implementation step

H21's two engineering gates are closed. H11 / T22 (splash lockup) is closed — see §0k.
H22 engineering is closed (simulator verified; physical logout/relaunch **DEFERRED**).
Next product work is a **reviewed commit of the working tree excluding `graphify-out/`**,
then the five remaining release-scope rows (website content, disposable Profile QA, live
reset email, edit-control device pass, physical cellular) and the App Store gates outside
the 44. Do not implement those in a documentation pass.

```bash
cd /Users/lucasvalenca_sf/genesxy_apple.V1.02

# Review product files only. Do not stage graphify-out/.
git status --short -- . ':!graphify-out'
git diff --stat -- . ':!graphify-out'

# Optional tidy: the rescued recipe-book copy is redundant with the bundled guide.
# rm docs/assets/Genesyx-Recipe-Book.pdf

# Commit only after a person has reviewed the product set.
```

### 0j. Copy-paste continuation prompt for the next agent

> Continue the Genesyx **iOS** delivery from the release commit `8580dd6` on branch
> `main`. **Preserve every uncommitted change — batches 1–9 all live in this tree. Do not reset,
> stash or discard anything.** Read `docs/HANDOFF.md` §0 first.
>
> H21 (free guide) is **Done** as engineering: falsification recorded
> (`GenesyxUITests.swift:130`, exit 65, 28.044 s), both guide UI tests green after restore
> (2/0, 32.091 s), full UI suite green after the restore (67 executed, 1 skip, 0 failures,
> 785.545 s, `/tmp/genesyx_h21_full_ui.log`). H11 / T22 is also **Done**: splash
> `Text("GENESYX")` is now `Image("brand_lockup")` at 220×54. H22 is **Engineering Done;
> simulator verified; physical-device QA deferred.** Authoritative current baseline:
> **267 domain / 288 app / 79 UI (1 skip)**, `/tmp/genesyx_h22i_full_ui.log` (14 Aug 14:16).
> The four PDF content blockers and the medical review in §0h / §11.1c stay open —
> **do not mark the guide App Store-ready.**
>
> **Five product decisions were frozen on 14 Aug and are settled input, not open questions —
> see §0-FROZEN.** D1 warm/premium **approved** (group 5 now 4/4). D2 daily-log deletion, D3 cycle
> edits + article reads toward the streak, and D4 streak restore are all **not in this release** —
> **descoped, not delivered; never report them as done.** D5: the guide PDF is usable internally
> but not App Store-ready. **D3 + D4 cancel the new production column and the Android migration —
> do not add a schema change for the streak.** Do not re-analyse, re-estimate or "improve" any of
> the five; if a request seems to contradict one, stop and ask. Current figures: **37 of 44 (84%)**
> original scope, **37 of 42 (88%)** release scope — quote both.
>
> **Do not wire the website pH-science or Shettles links.** Live 14 Aug slugs
> `/pages/vaginal-ph-fertility-science` (same marketing copy as `/pages/ph-tracking`, no
> citations) and `/pages/shettles-method-evidence-limitations` (empty slug title) are **not**
> the required pages. Item 1 stays BLOCKED (§0-FROZEN, `CHANGE_LIST_PLAN.md` §0.1).
>
> Next step is a **reviewed product commit excluding `graphify-out/`**. Do not
> include `.claude/scheduled_tasks.lock` or the redundant `docs/assets/Genesyx-Recipe-Book.pdf`.
> Physical cellular and physical H22 logout/relaunch are **DEFERRED** (no iPhone).
>
> **Constraints that are still in force and are not yours to change:** iOS only, do not touch the
> Android app. Do not push, or deploy any Supabase change. Do not delete
> `RemoteBackend.joinWaitlist`, `SupabaseBackend.joinWaitlist`, the `join_waitlist` RPC or
> `waitlist_emails` — Android shares that backend. Do not make the PDF a `LearnArticle`
> (`LearnContentTests` asserts 32 articles, and it would pollute `markRead`). Never pass `-quiet` to
> xcodebuild. Banned-phrase guards are compliance controls — a failing one is a decision for a
> person, never a quiet test edit.

### 0k. H11 / T22 — splash lockup, 14 Aug 2026

**Approved the same day:** the bounded warm/premium presentation; all eight recipe photographs;
the full Genesyx lockup on the initial splash. Group 5 is 4/4. T22 and H11 are Done.

**Production file first.** `OnboardingFlowView.swift` is the restored H21 production route
(342 lines, `onOpenGuide: { showGuide = true }`, `grep -ic waitlist` = 0) plus the splash
edit only. It is now 348 lines, md5 `9124dd6ef35afe9cd86bf64bcf0fd4bf`. The H21 backup
`/tmp/onb_h21_prod_20260814T104552.swift` (`b85686926825890766d64990ae2f747e`) still
matches the pre-lockup file; the only delta is `Text("GENESYX")` → `Image("brand_lockup")`.

**What changed (product, this batch):**

| File | Change |
|---|---|
| `App/Genesyx/UI/Onboarding/OnboardingFlowView.swift` | In private `SplashView` only: `Image("brand_lockup").resizable().renderingMode(.original).scaledToFit().frame(width: 220, height: 54)` with `accessibilityLabel("Genesyx")` and `accessibilityIdentifier("onboarding.brandLogo")`. Four eggs, copy, quiz/sign-in, disclaimer, quiz route and guide sheet are unchanged. |
| `App/GenesyxTests/BrandAssetTests.swift` | `testBrandLockupArtworkExists` — `UIImage(named: "brand_lockup")` must load. |
| `App/GenesyxUITests/GenesyxUITests.swift` | `testTheOnboardingQuizRunsEndToEnd` now asserts `onboarding.brandLogo` **before** tapping the quiz. |
| `brand_lockup.imageset` | **Not imported.** Existing light (`brand_lockup.png`) and dark (`brand_lockup_dark.png`) variants used as-is. The supplied `~/Downloads/genesyx-logo.svg` was not copied. |

**Measured results (iPhone 17 sim `6EFF8D1E-6556-45FA-AB67-1AE6EFF64575` unless noted):**

| Check | Result |
|---|---|
| Asset falsify (`UIImage(named: "brand_lockup_missing")`) | ✅ failed as required, `BrandAssetTests.swift:47` `XCTAssertNotNil failed - Missing brand asset "brand_lockup"`, **0.066 s**, exit 65 |
| Restore + `BrandAssetTests` | ✅ **5 executed / 0 failures**, 0.003 s |
| `testTheOnboardingQuizRunsEndToEnd` | ✅ **passed 15.552 s** — logo exists before the quiz tap |
| `GenesyxAppTests` | ✅ **276 passed / 0 failed**, 0.547 s |
| Full UI #1 (`/tmp/genesyx_h11_full_ui.log`) | 67 exec, 1 skip, **1 fail** — `CitationE2ETests.testCitationTapOpensBrowser` (button at y=658, hit `{-1,-1}`, under the tab bar). **Not a splash regression.** |
| Isolated citation rerun | ✅ **passed 5.633 s** |
| Full UI #2 (`/tmp/genesyx_h11_full_ui2.log`) | ✅ **67 executed, 1 skipped, 0 failures**, **785.772 s**, `** TEST SUCCEEDED **` |

**Smallest supported iPhone.** SE3-375pt sim `E22639B5-9ACA-4F23-BF89-F9F18658FC84`. Light
screenshot `docs/day-report-assets/splash_se3_light.png`: lockup visible, 220×54 fits, four
eggs / copy / quiz / sign-in / disclaimer intact. Dark screenshot file
`splash_se3_dark.png` is **byte-identical** to the light shot (md5
`582ec22d2463c3714b02a2d3907d3796`) because the seeded theme is `.light` via `LocalStore`
and system appearance does not apply. The dark catalog asset
(`brand_lockup_dark.png`, 25,208 bytes) was inspected separately; a live dark splash was
not captured.

**Nothing committed. Nothing pushed.**

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

**Photography now ships — all eight recipes.** It did not until 14 Aug; the original position was to
render on the phase accent rather than ship stock photos of somebody else's food, the Guideline 2.1
risk documented in `docs/FIX_REPORT_2026-07-12_data_honesty.md`, with `Recipe.imageName` left as a nil
seam. That seam has now been filled and **the guard was swapped, not dropped** —
`testNoRecipeClaimsAnImageTheAppDoesNotHave` no longer exists; `testEveryRecipeHasAUniqueImageMapping`
(domain) proves no recipe is imageless and no two share a plate, and `testEveryRecipeImageAssetExists`
(app target) loads each name through `UIImage(named:)`.

**Why that second test has to live in the app target, and why it is not ceremony.** SwiftUI's
string-based `Image(_:)` lookup **fails silently** — a misspelled asset name yields a blank card, and
crucially *not* the phase-gradient fallback, because the fallback is keyed on `imageName == nil`
rather than on the lookup failing. A domain test cannot catch this: it has no bundle to load from and
can only compare strings to strings. So the two tests are checking genuinely different things, and
deleting the app-target one would leave a category of defect with no coverage at all while the domain
suite stayed green. If photography is ever extended, both must be.

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

**Closed 14 Aug 2026.** The exact applied SQL is now checked in at
`supabase/migrations/20260813_user_supplements_delete_backstop_and_push_default_false.sql` — md5
`55c387ecc1fc940b892bd8bdc3e1cfb5`, 3424 bytes, mtime 13 Aug 15:35, `cmp`-identical to the dashboard
SQL-editor copy that was saved to `~/Downloads/` on the day it ran. It had never existed in git on
any branch and appears in no session transcript, so refusing to reconstruct it was the right call:
the real file splices the backstop in with `pg_get_functiondef -> replace -> execute` and asserts the
owner, the ACL, `prosecdef` and `search_path=""` before committing. A prose reconstruction would have
retyped the body and silently dropped whichever hardened block the summary omitted.

**Still owed:** the disposable-account deletion test. Production DDL is not proof of runtime
behaviour, and this file is DDL.

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

## 4s. The Profile audit, actually performed (2026-08-13)

`H8` had been recorded as "needs live QA" and left there. Reading the section instead found **five**
defects, one of them serious, and none of them requiring an account to find. Full detail lives in
`CHANGE_LIST_PLAN.md` §6A rows H13 and H14; what belongs here is the part that generalises.

**The owed-write contract now has a third member.** `display_name` had never been in it: the rename
was fire-and-forget, sign-up never pushed at all, and nothing ever read the column back. It now
follows `PreferencesRepository` exactly — persisted flag, drained on launch/foreground/reconnect,
push before pull, cleared on sign-out and on identity change. Two traps were designed out rather
than discovered in production: only a name she actually **typed** is ever owed (pushing the resolved
name would send the email prefix and overwrite "Ada Lovelace" with "ada" on every sign-in), and a
row whose `display_name` is null **leaves hers alone** (every account predating the fix has one, so
letting null win would blank the name for all 18 at their next hydrate).

**A label can disable a feature.** The reminders master switch said "Weekly reminders". It gates all
eight categories through `NotificationService.isActive`, so the woman who declined what read as a
weekly digest also declined the daily supplement reminder, the evening check-in and the
fertile-window nudge the brief calls critical. Nothing was broken in code; the copy was the bug.
Worth carrying: **a control's blast radius is part of its correctness**, and `grep` for a toggle's
label is not the same as reading what it sets.

**A "coming soon" teaser was persisting and syncing state.** Tapping Pregnancy wrote
`focusMode = .pregnancy` to the device *and the server* — so to Android too — while its own sheet
said "Coming soon" and its button said "Keep tracking". No screen implements pregnancy mode, so the
segment sat there claiming a state nothing honoured, permanently. A teaser must store nothing.

**Silent input rejection reads as success.** A glass size outside 50–1000 ml was dropped by the
per-keystroke rule and left in the field, so "3000" looked exactly like a setting that had taken
while the glass was still 250 ml. Clamped on blur, not reverted — the keystroke rule stores the
in-range prefix on the way, so reverting would have answered her with "300", a number she neither
typed nor had.

### The XCUITest mechanics that made two assertions pass for the wrong reason

This is the §4r lesson again in a different disguise, and both halves are now written into the
`enterGlassSize` helper so the next person does not rediscover them:

- **`coordinate(withNormalizedOffset:).tap()` does not scroll an element into view.** Only
  `element.tap()` does. A raw coordinate tap fires at those screen coordinates whatever is there —
  after a few `swipeUp()`s, that was the tab bar.
- **`XCUIKeyboardKey.delete` is a no-op when the caret is at position 0**, and a centre tap in a
  trailing-aligned 56 pt field puts it there. The deletes did nothing and the new digits were
  **prepended**: "10" became "101000", which clamped back to 1000 — the value under test — so the
  assertion passed. `field.doubleTap()` selects the whole number (one word, no spaces) and typing
  replaces it. The helper now also asserts the field reads what she typed *while she is still in
  it*, so it can no longer mis-enter a value in silence.

A related one, found in the same pass: **`XCUIElement.isSelected` needs
`.accessibilityAddTraits(.isSelected)`.** The focus segments expressed selection in colour and
background alone — invisible to VoiceOver and to every test.

### Falsification choice worth copying

For the past-day edit test I broke `populate()`'s prefill rather than `upsert(entry, on:)`. Breaking
the upsert also fails the pre-existing back-fill test, which proves nothing about the new one;
breaking the prefill fails **exactly one** test with the back-fill test still green — which is what
demonstrates the new test covers a guarantee nothing else did. When falsifying, break the narrowest
thing only the new test depends on.

### Left open deliberately

`HydrationDetailSheet` (`TrackView.swift:866`) is hardcoded to `today` (line 871), so a past day's
water is correctable only through `LogView` — a missing route, not lost data. And
`DailyLogRepository` has **no `delete()` at all**: a logged day cannot be removed on either client.
Both are shared surface and the second is a data-retention decision, so neither was patched quietly.
*(The hydration half was closed in §4t on 14 Aug; the deletion half stands.)*

## 4t. H15 — the pH surfaces, walked the way she reaches them (2026-08-14)

Six defects, found by opening the pH surfaces in the order a user hits them rather than reading the
files in the order they are organised. One destroyed data on a single tap, one printed an
unfollowable safety instruction, and one had a green test certifying a sentence that is false about
the app's own behaviour.

**The destructive one.** `PhLogSheet` put its delete action in `ToolbarItem(placement:
.cancellationAction)` — the top-left slot every other screen in iOS gives to Cancel — and called
`onDelete` immediately, with no confirmation. Opening a reading to adjust it and then deciding
against the adjustment destroyed the reading. The button moved into the body of the sheet, away from
Save, behind a confirmation; the toolbar slot is now an unconditional `Cancel` that only dismisses.

**Use `.alert`, not `.confirmationDialog`, when the decline button's wording matters.** The first
implementation used `.confirmationDialog` with `Button("Keep it", role: .cancel)`. The test could
never find "Keep it" and I initially misread that as the dialog not presenting. It was presenting —
a probe showed `sheets=1` and the dialog title present, while the full app-wide button list read
`Cancel | Save | Delete`. **SwiftUI's `.confirmationDialog` silently discards a custom `.cancel`
label** and substitutes the system "Cancel". So the decline button rendered as the same word as the
toolbar button she had just learned does not delete anything — the exact confusion the fix existed to
remove. `.alert` honours both labels and is queryable unambiguously as
`app.alerts["title"].buttons["label"]`.

**The Insights pH card had no disclaimer at all.** It is the most clinical-looking surface in the
app — a pH value, an `ELEVATED` badge and a "speak to a GP" signpost — and `PhCopy.disclaimer`
appeared in exactly two places in the codebase, both in `PhTrackerSection`. A woman who reads her
result on Insights and never opens the pH tab got the badge and the signpost with no small print.
Given the same collapsible "Safety note", under `insights.*` identifiers so it cannot collide with
the tracker card's.

**An instruction pointing at a control that does not exist.** Two pH cards read "log your cycle day
alongside each reading". The log sheet has a pH value, a date and a note — there is no cycle-day
field anywhere. Reworded to name the note field and lifted into `PhCopy.cycleContextCaveat`; that
file exists precisely so a string shown on two surfaces cannot drift. **The grep found seven
occurrences, not the four I expected**, and the three in `LearnContent.swift` were left alone on
purpose: line 335 there ("add a note if you want") immediately precedes the instruction, so the Learn
prose is truthful in its own context and editing it would have risked the banned-phrase guards for
nothing.

**A test that certified a false statement as shipped copy.** `PhCopy.oneTimeNotice` said "Your
earlier readings are kept and marked 'urine (legacy)'", and `testCopyStringsAreVerbatim` asserted it
character-for-character. But `PhRepository.displayReadings` filters `measurementType != .urine`: iOS
**hides** legacy readings and marks nothing. Neither that constant nor `legacyMarker` rendered
anywhere. The test was the trap — a future engineer wiring the notice up would have shipped a
sentence that is untrue about the app, with a green suite vouching for it. Both constants and their
three test references are gone. Hiding rather than marking is a deliberate, documented decision and
was not reversed.

**Hydration history is now actionable**, closing the first of the two items §4s left open. The
seven-day strip on `HydrationDetailSheet` was inert, so a wrong past total was visible and
uncorrectable from where she was looking at it; the only route was Track → that day → Edit this day.
Each tile now opens that day's `LogView`. The sheet stays a today editor by design — this is the
missing route, not a redesign.

**The range selector gained a state VoiceOver can read.** Which of 7d/30d/90d/all was showing was
expressed in foreground colour and background fill alone; `.isSelected`/`.isButton` traits and stable
identifiers make it both audible and assertable.

### The regression the compliance guard caught, and why it was reverted rather than accommodated

An earlier edit in this batch had improved the Home pH card's VoiceOver label to include her last
reading, because `.accessibilityElement(children: .ignore)` discards the subtitle where that number
otherwise appears. The full UI suite failed on
`CitationE2ETests.testHomePhCardHasNoUncitedClaim`, which pins that label to **exactly**
`"Check your Vaginal pH"` so the card stays a navigational nudge carrying no health claim.

That guard is deliberately an exact-equality assertion so that *any* addition forces a human to look,
and it worked. The change was **reverted, not accommodated.** The argument for keeping it is real —
the subtitle already shows "Last reading 6.9 — tap to log again" to sighted users, so the label
change was parity with shipped visible content rather than new exposure — but putting a pH value into
that label is a compliance call, and the carried constraint below is unambiguous that relaxing a
test-enforced guard is a decision, never a quiet test edit. The VoiceOver parity gap is left standing
and recorded here; the code now carries a comment naming the test so the next person does not
rediscover this the same way.

### Falsification

Four new UI tests, four breaks, each applied on its own and each failing **exactly one** test with
the other three green: restoring the one-tap delete failed only the delete test; dropping
`.isSelected` failed only the range test; suppressing the disclaimer body failed only the Insights
test; making the hydration tile inert failed only the hydration test.

The hydration test taps the **oldest** tile deliberately. `lastSevenDays` runs today−6 → today, so
index 0 is six days back — and a tile that opened *today's* log would satisfy a naive "the log
opened" assertion while leaving the past day exactly as uncorrectable as it was.

### Left open deliberately

**The two clients now disagree about the same pH history.** Android displays legacy urine readings
labelled "urine (legacy)" (`HomeScreen.kt:659,669`, `TrackerSummaryLogic.kt:99`,
`LogDaySummary.kt:61`, `PhTrackerCard.kt:141`) and still shows a live migration notice
(`PhCopy.kt` `NOTICE_TITLE`/`NOTICE_BODY`/`NOTICE_DISMISS`), while iOS hides those readings entirely.
One account therefore shows a different pH history on an iPhone than on an Android phone. Nothing is
lost on either side — the rows are stored and synced both ways — but one of the two is wrong. Not
resolved here: the fix is either an Android change (excluded from this delivery by instruction) or
reversing a deliberate iOS product decision, and it needs a ruling on which client is right.

**Cycle edits still cannot count toward the streak, and now the reason is precise.** `CycleSettings`
is three fields and `CycleSettingsRow` mirrors them; there is **no `updated_at` locally or remotely
and no dated history**, so nothing distinguishes an edit made today from one made in March. Two
proxies were checked and both break: counting *projected* period days awards a streak to someone who
never opened the app, because those days are arithmetic from `lastPeriodDate` + `cycleLength` rather
than logged events; counting the recorded period window is retroactive and hands out a week's streak
for a range typed in one sitting. Same unblock as dated article reads — a dated table, or at minimum
an `updated_at` column, plus an Android migration.

## 4u. H16 — the notification queue, and the woman it stopped speaking to (2026-08-14)

Four defects in the notification engine. Three of them are invisible from inside a single session:
they only appear across a cancel, a foreground and a night, which is exactly why eight categories of
green tests never caught them. The suite tested what each nudge *says*. Nothing tested what was still
in the queue tomorrow.

**Read this first, because all four fixes depend on it.** iOS notifications here are
`UNCalendarNotificationTrigger(repeats: false)` — one-shot. There is no `BGTaskScheduler` and no
background refresh. **The queue is rebuilt only when the app is foregrounded or a repository
publisher fires.** So an empty plan is not "nothing to say tonight"; it is "nothing, ever again,
until she happens to open the app". Every planner branch that returns `nil` is a decision to go
silent indefinitely, and it has to be read that way.

**The worst one punished the most engaged user.** `NotificationPlanner.hydration()` returned `nil`
once she had both logged her day and met her water goal. As a sentence about tonight that is
correct. As a queue it is catastrophic: she completes her day, has no reason to open the app again,
and never hears from it again. The women who used the app properly were the ones it abandoned. It
now returns tomorrow's invitation at `dayOffset: 1`, which is still true on the morning it lands,
because she cannot log tomorrow without opening the app and opening it re-plans.

**The weekly nudges do not save her, and the reason generalises.** The obvious objection to the
paragraph above is that `plan()` still returns up to four weekly nudges, so the queue is not empty.
Check what those four actually are for a consistent user: `track()` requires
`daysSinceLastLog >= trackNudgeAfterDays` and returns nil for someone who never has a gap; `ph()`
goes quiet once she has logged recently; `insights()` and `learn()` are each rationed to one in seven
days. Two of the four are written *for a lapse* and have nothing to say to her by design, and the
other two are weekly at best. Her queue can therefore empty completely — and the emptier it is, the
less likely anything arrives to refill it. **The general lesson: when the queue is only refilled by
the user showing up, every rationing rule is also a rule about who gets abandoned, and rules
conditioned on inactivity abandon the active.**

**Scope the fix honestly when reporting it:** it restores the daily rhythm. It does not make the
schedule self-sustaining, and a woman who stops opening the app still runs out.

**Cancelling remembered what it had just cancelled.** Delivery cannot be observed while the app is
closed, so `recordWhatHasFired()` infers it: a scheduled fire time now in the past is counted as
sent. `cancelAll()` removed the pending requests but left `notification_scheduled_fire` intact — so
every cancelled-but-not-yet-due nudge was promoted to "sent" at the next foreground, and a slot
believed to have spoken then serves out its full repeat guard in silence — seven days for the
evergreen nudges, and fourteen for the fertile one (`fertileRepeatGuardDays = 14`). Turning reminders
off and back on in the same evening therefore cost her a fortnight of the one nudge the change list
calls critical. `cancelAll()` now clears the map. **The ordering is
load-bearing and must not be rearranged:** `replan()` calls `recordWhatHasFired()` *before*
`cancelAll()`, so fires that genuinely happened are banked before anything is cleared.

**A weekday is a fair proxy for a recurring nudge and a wrong one for a dated nudge.**
`hydrationRestDays` stood the evening check-in down on any weekday a weekly nudge lands. Sound for
the four evergreen nudges, which really do recur — but the fertile nudge is a single date, and seven
days from today is *today's own weekday*, so a fertile nudge at the far edge of its horizon silenced
tonight for something firing next week. Now excludes `dayOffset == 7`.

**A safety scan pointed at fixtures fails nobody.** `SupplementReminder.allPossibleCopy` is the
surface the banned-phrase and no-guilt scans walk, and it was built from three invented supplements —
so the scans cleared a "Magnesium" the app does not ship and **never once read "Time for Folate
(400–800 mcg)"**, which is what actually reaches her lock screen. An essential carries its dose
inside its name, which is precisely the shape the fixtures missed. Now built from
`NutritionContent.supplementPlan` exactly as `all()` builds it. The test added for it pins the
*coupling*, not the copy: every essential in the shipping plan must appear in the scanned set. This
generalises — **if a compliance scan reads a hand-written list, the list is the thing to test, not
the scan.**

### When to rewrite a failing test, and when to obey it

Fixing the hydration `nil` broke `testEveningCheckInSaysNothingWhenTheDayIsComplete`, which asserted
the plan was empty — the defect, written down as a specification. It was rewritten into two tests
stating the new contract, with the reasoning kept in the doc comment so the next reader sees the
argument rather than a silent edit.

**This is the opposite call to §4t's citation pin, and the distinction is the point.** There,
`CitationE2ETests` caught a regression I had introduced and I reverted the code and left the test
alone. The rule that separates them: a test that exists so a human must review a change — a
compliance guard, an exact-equality copy pin — is obeyed, always. A test that merely records how the
code behaved when it was written can be rewritten when the behaviour was wrong. Ask which kind it is
*before* touching it, and write the answer down.

**Verify audit findings before fixing them.** A fifth finding was reported — that a fertile nudge is
lost if the app is opened after 08:00 on the day itself. It is not a defect: `fireDate` returns nil
for a moment that has already passed, and the reason is written down at
`NotificationService.swift:293-302` — the plan is only ever rebuilt *because* the app was opened, so
a nudge about a window that opened this morning would be telling her what the screen in front of her
is already showing. Read against the source and rejected rather than patched. The finding was right
about the behaviour and wrong about it being a fault, which is the usual shape: **an audit reports
what the code does; whether that is a defect is a judgement the audit cannot make for you.**

### Left open deliberately

**The queue still runs out for a woman who stops opening the app.** With no `BGTaskScheduler` and no
background refresh, the 14-day dormant hand-back can never fire — the one nudge aimed at someone who
has gone quiet is the one nudge that structurally cannot reach her. Closing it is a
background-execution change with its own capability, battery and review implications, not a planner
change, and it was catalogued rather than attempted inside a batch of defect fixes.

## 4v. H17 — the sync contract, checked in all five places rather than three (2026-08-14)

The owed-write contract is the load-bearing promise of this app when the network is bad: **the local
write always wins**. Every prior batch has cited `PreferencesRepository` as the reference
implementation of it. This batch checked whether the other four repositories actually implement the
same thing, instead of assuming a documented pattern had been applied uniformly — and the reference
implementation turned out to be one of the two that got it wrong.

**The shape of the fault is a TOCTOU, and it is easy to write by accident.** `refresh()` drains what
is owed, checks `!pendingPush`, then pulls:

```swift
await drainPending()
guard !pendingPush else { return }                       // ← read here
do { fetched = try await backend.fetch() } catch { return }   // ← suspension
apply(remote)                                            // ← applied here, flag never re-read
```

The check is correct and it is in the wrong place. Between the guard and the apply there is a real
network round trip, and anything she changes during it is being measured against an answer given
before she touched the screen.

**On `PreferencesRepository` this erases the change rather than reverting the display.** `apply` runs
inside `isApplyingRemote = true`, which exists so that writing pulled values does not bounce them
straight back up as a fresh push. That is right for a genuine pull. Here it means the overwrite was
also *un-owed*: her theme, focus mode or push toggle reverted, and nothing anywhere still knew she
had asked for it. There is no retry, because the retry flag was suppressed by the same code that did
the damage.

**On `CycleRepository` it is milder, and the difference is worth stating** so the fix is not
over-sold. `upsert` fires its own `Task` that carries the edit to the server immediately, so in the
common case the server already has it and only the device reverts — self-healing at the next
refresh. Same fix, lower stakes.

```swift
guard !pendingPush, let remote = try? await backend.fetch() else { return }
guard !pendingPush else { return }   // re-read after the suspension
settings = remote
```

**The two that were immune are what made this findable.** `DailyLogRepository.refresh()` re-reads
inside the loop — `for (date, log) in remote where !pendingDates.contains(date)` — and `PhSync.merge`
does the equivalent. Three implementations of one contract, two of them re-reading after the await
and two not, is the kind of divergence that only shows up if you read all of them side by side; each
one on its own reads as correct.

**Window: launch and sign-in, not foreground — and the narrowness is real.** `refresh()` is reached
only from `AppContainer.hydrate()` (`AppContainer.swift:70-74`). The foreground path
(`GenesyxApp.swift:42-51` → `AppContainer.drainPending`, `AppContainer.swift:79-89`) pushes without
pulling, so it cannot hit this. She had to change a setting in the seconds after a cold start or a
sign-in — which is exactly the window a slow connection stretches out.

### Falsification

Reverting both guards fails **three** assertions across exactly the two new tests, with the other 82
tests in `RepositoryTests` green. The third is the one worth reading:
`testAPreferenceChangedDuringAPullIsNotOverwrittenByWhatComesBack` also asserts that her choice
reaches the server *afterwards*, and without the fix it never does — the `isApplyingRemote`
consequence reproduced as evidence rather than asserted in prose.

Two new fakes rather than extending `MidDrainCycleBackend`: that class's name describes the *drain*
window and these fire during the *fetch* window, so a `duringFetch` hook bolted onto it would have
made the existing test harder to read for no gain. `MidFetchProfileBackend` flips `online` from
inside the hook, so the edit's own push fails and the flag stays genuinely owed — otherwise the test
would be racing the `Task { await drainPending() }` that `pushPrefs()` spawns, and a test that passes
because a task happened not to run yet is not a test.

### Also audited, and sound

All eight `drainPending` definitions are reachable from a live call site. H13's defined-but-never-
called pattern has not recurred.

### Left open deliberately

**Custom supplements are outside this contract altogether, and that is the bigger finding.**
`@AppStorage` JSON, no pending flag, no drain, no read-back — so unlike a write that is merely still
owed, there is no path to the server at all and a reinstall loses everything she typed. Since 13 Aug
`user_supplements` exists in production with owner-only RLS and **Android reads and writes it**, so
the same account now genuinely diverges between her two phones with neither client aware of the
other.

**I first wrote here that nothing blocks it and it is a day's work. That was wrong, and it is worth
recording why rather than quietly editing it out** — it is the same failure mode as the P0-15 call
earlier in this delivery. Both times I costed a piece of work from the shape of the *server* side
without reading what the *client* would have to send. The server side genuinely is ready. Reading
the deployed DDL against `NutritionView.swift` is what showed the problem:

`user_supplements.time_of_day` carries
`check (time_of_day is null or time_of_day in ('morning','afternoon','evening','anytime'))`, and
Android models it as `enum class SupplementTime` whose `wire` values its own doc comment calls a
cross-platform contract that must never be renamed after a client ships. **iOS's time field is a
free-text `TextField`** (`NutritionView.swift:714`, `843-848`). Every value it can produce that is
not one of those four lowercase words will be rejected by the constraint. `name` is likewise bounded
1–60 characters server-side and unbounded on iOS, and deletion server-side is a `deleted_at`
tombstone, which iOS has no concept of — `remove()` drops the item from a local array, so with no
tombstone the next pull would resurrect it.

So the honest sequence is: **decide the time field first, then build.** Matching Android means a
four-option picker, which is parity rather than redesign — but it discards whatever an existing iOS
user typed there, and because these have never synced there is no way to count them or read them
back first. That is a product call, and it is recorded in `TESTFLIGHT_B18.md` under "What's NOT in
this build" with the alternatives and why both are worse. Building the repository before it is
answered means building it twice.

## 4w. H18 — four things the calendar and the countdown were saying wrong (2026-08-14)

Four defects, all in surfaces the client's list calls critical, none of which had a failing test
because in three of the four cases the test suite had encoded the wrong answer as the expected one.

**1. The countdown was a day short, everywhere.**
`CycleEngine.cyclePhase` computed `cycleLength - dayOfCycle`. The next period starts on day 1 of the
*next* cycle — day `cycleLength + 1` counted from this one — so from day `d` it is
`cycleLength - d + 1` days away. On a 28-day cycle, day 8 reported 20 days when the answer is 21.
The visible failure is at the end: on the last day of the cycle the old expression returned **0**,
and 0 is the value Home renders as "Next period: Today" and Track as "Your next period is due
today". A full day early, on the number a woman tracking her cycle checks first.

`CycleEngineTests` asserted `20`. That is how a countdown that was wrong for every user on every
cycle passed its own suite for months: the test recorded what the code did, not what was true. It
was rewritten with the arithmetic spelled out in the comment, and a second test added for the
last-day case specifically.

**Ported from web and Android, both of which still have the old expression.** The header of
`CycleEngine.swift` points at `docs/CYCLE_ENGINE.md` for the parity contract — **that file does not
exist**, so the parity was only ever a code comment. Fixed iOS, flagged the other two, touched
neither. See the H18 row in `CHANGE_LIST_PLAN.md` §6A.

**2. On a short cycle the calendar refused to name her ovulation day.**
`ovulationDay = cycleLength - 14`, so a 21/7 cycle ovulates on day 7 — inside the period.
`CycleEngine.dayType` resolves period before ovulation (deliberate, and shared with Android), so the
cell drew as a period day: no ovulation fill, no heavier ring, and a screen reader said "7, Period".
Meanwhile Home, Insights and the cycle sheet all still printed "Predicted ovulation: Day 7". Four of
the settings sheet's selectable combinations do this — 21/7, 22/8, 23/9, 24/10.

Fixed in the view, not in `dayType`: the cell now asks the *day* whether it is the ovulation day
(`info.dayOfCycle == info.ovulationDay`) rather than asking the fill, which is the same idiom the
adjacent `isFertile` line already used. The shared precedence contract is untouched.

**3. The one screen whose job is reading her logs back was dropping days.**
`InsightsView`'s private `DailyLog.isBlank` was a hand-written copy of `hasAnyEntry` that had
drifted. It never gained the `foodGroups` term when H4 added one to both streak predicates, and it
never had `sexualActivity`. So a day she only ticked her meals on drew a calendar dot, was named in
the day sheet and counted toward her streak — then vanished from history. `LogHistoryCard`, in the
same file, already knew how to render food groups.

`isBlank` now delegates: `!hasAnyEntry && !sexualActivity`. `sexualActivity` is added **on top**
rather than folded into `hasAnyEntry`, because that predicate is a cross-platform contract and
widening it would change her streak numbers against Android's with no error anywhere. Same shape
`NotificationService.swift:222` already uses, for the same reason. The card also gained an
"Intimacy" row, since a day whose only entry was that one still reached history as a bare date.

**4. The cycle editor fabricated a date for new users.**
`CycleSetup.swift`'s header forbids inventing a last-period date in as many words. The editor did it
anyway — not through the rule, but around it: showing the picker required binding it to a
non-optional date, so the empty-state button assigned `Date()` purely to have something to bind, and
that assignment enabled Save on the way past. Asking for the picker and choosing a date were one
event.

Split by a new pure rule, `CycleSetup.showsDatePicker(lastPeriod:isPicking:)`, with the view holding
an `isPickingDate` flag that shows the control without writing anything.

### The SwiftUI trap this one hides, and why there is an extra button

A graphical `DatePicker` must still be handed a non-optional date, so it opens on today whether or
not she means today — and **tapping the day it is already displaying may not move the binding**.
That would strand the exact woman whose period genuinely did start today: picker on screen, correct
day highlighted, Save greyed out, nothing explaining why.

Rather than ship an unverifiable change to the control that gates every prediction in the app, the
empty state now also offers an explicit **"My period started today"** button
(`cycle.lastPeriodIsToday`). It is one line of UI that makes the ambiguous case unambiguous.

### Falsification

Reverted in two pairs, both exact:

- `+ 1` and `|| isPicking` together → **4 failures across 3 tests of 248** domain. `20 ≠ 21`,
  `1 ≠ 2`, `0 ≠ 1`, and the picker/Save split. `testPickerIsHiddenUntilAskedForAndAlwaysShownOnce
  ADateExists` correctly did **not** fail — it guards the other two states.
- The `isOvulationDay` label branch and `isBlank` together → **6 failures across 2 tests of 22** in
  `RealInsightsTests`, the messages reproducing the bug verbatim: `7, Period, also in your fertile
  window` for all four short-cycle combinations, plus both `isBlank` assertions.
  `testTheOvulationNoteIsAddedOnlyWhereTheFillHasNotAlreadySaidIt` correctly did **not** fail.

All four restored and re-verified afterwards.

### Where the new tests live, and why there

The calendar cell's spoken label moved out of the view into `CyclePredictionCopy` — the file's
existing internal, testable seam — as `calendarDayLabel(day:type:isFertile:isOvulationDay:isToday:
markers:)`. The private `cellLabel`/`markerLabel` helpers were deleted and the two `legendLabel`
overloads now delegate. That is what gives the short-cycle case a seam a test can reach, which
matters because it is precisely the case no one notices by eye.

### Left open deliberately

**The legend still shows ovulation as a solid swatch**, which on a short cycle points at a fill that
appears nowhere in that month's grid. Cosmetic, and cycle-aware legend copy is a design decision,
not a correction.

**Android and web still carry the off-by-one.** Fixing them is a separate, non-iOS change and the
standing instruction is iOS only.

**`docs/CYCLE_ENGINE.md` still does not exist.** Until it does, "matches web/Android" claims in
`CycleEngine.swift` are unverifiable assertions in a comment. Worth writing before the next person
uses one as a reason not to fix something.

## 4x. H19 — the last thing in the app that never left the phone (2026-08-14)

Every other thing she records is written locally and then **owed** to the server until it lands —
her cycle, her daily logs, her pH readings, her preferences, her name. Custom supplements were
`@AppStorage` JSON and nothing more. A reinstall lost them. The same account on two phones showed
two different lists, with neither device aware the other existed.

The table was not the blocker: `user_supplements` has been live since 13 Aug with owner-only RLS, a
`user_id → auth.users ON DELETE CASCADE`, a `time_of_day` CHECK and H1's deletion backstop, and
Android has read and written it the whole time. **No schema change and no SQL were needed here.**
iOS simply never connected to it.

### The two halves

**The sync** follows `PhRepository` exactly, because it is the closest shape and the contract is
already proven: the device is the source of truth, a failed push stays queued and is retried on
launch/foreground/reconnect, `refresh` MERGES rather than replaces so an empty cloud cannot wipe
her, and a delete is a **tombstone** rather than an array removal. That last one is the part that
was missing conceptually, not just in code — dropping an item from a local array is invisible to
the server, so the next pull finds a row this device does not have, reads it as new, and puts the
supplement back. She deletes it and it returns.

**The time field** was free text on iOS. Android offers four fixed options, and the server accepts
`morning`/`afternoon`/`evening`/`anytime` or null and nothing else. So whatever she typed was
either refused by the database or arrived at her other phone as a string it had no idea what to do
with. It is now the same four. The client chose this over widening the server.

`SupplementTime.parse` lowercases and trims, which recovers a typed "Evening" or " morning "
instead of dropping it. The decision that authorised this batch accepted discarding the old values;
this keeps the ones that can be kept and discards only what is genuinely unrecognisable.

### Three ways this could have quietly destroyed data, all caught before shipping

**`LocalStore` namespaces every key it writes under `genesyx.`. `@AppStorage` does not.** The
existing list is under the bare key in `UserDefaults.standard`. The first draft read it back through
the store — which would have found nothing, decided there was nothing to migrate, and silently
discarded every supplement on every device that had one. The unprefixed defaults are now injected
explicitly (`legacyDefaults:`) with the reason written at the property, and
`testTheListFromBeforeTheSyncIsAdoptedAndCarriedUp` fails with `[]` if that read is ever routed back
through the store.

**A typed enum with synthesized `Codable` would have lost the list, not the time.** Array decoding
is all-or-nothing: one device holding `"time":"with breakfast"` and `decodeList` returns `[]`. So
the natural, tidy change — `String` becomes `SupplementTime`, let the compiler write the decoder —
converts an unrecognised *time* into the loss of *every supplement she ever added*.
`CustomSupplement` decodes by hand for this reason alone. The falsification prints it plainly:
`("[]") is not equal to ("["Magnesium", "Vitamin C"]")`.

**`updated_at` is nullable on purpose, and the fallback is not cosmetic.** The server stamps it only
on an update, so a row added on Android and never edited arrives with none. `parseISO` answers an
unparseable string with `Date()` — *now* — so without `?? createdAt` that row would be dated now,
**win every merge it takes part in**, and overwrite what is on this phone. Note the direction: the
obvious guess is that a missing timestamp makes a row look old and lose. It makes it look newest and
win. The falsification measured the gap at 20 hours, and the test now asserts the actual timestamp
rather than merely that one exists — the first version asserted `> epoch`, which `Date()` satisfies,
so it could not have failed.

### The migration gets exactly one chance

Everyone with a pre-existing list has it under the old key and an empty `user_supplements`. It is
adopted as `pendingSync: true` with spaced synthetic timestamps from the epoch, so the order she
added them in survives the sort and the whole list is pushed up on her next sign-in. The
alternative — treating an empty server as authoritative — would have made the feature launch by
deleting her list.

The old key is **left in place rather than deleted**: it costs nothing and is the only copy if a
downgrade ever happens. But it is not re-read once the store holds records, or deleting her last
supplement would be undone at the next launch by the copy the old key still holds.

`product_id` and `created_at` are **omitted** from the upsert rather than sent as null, which is
what preserves a catalogue link Android set. Swift leaves nil optionals out of the encoded body —
`encodeIfPresent` — so this works by mechanism rather than by intention, which is exactly why
`testTheSupplementRowLeavesOutTheColumnsItCannotKnow` pins it.

### One coupling that had to be cut

`NotificationService` was reading the supplement list straight out of raw `UserDefaults`. Left
alone, the repository and the notification schedule would have drifted the first time the list
changed from the server. It now takes the repository and re-plans when the list changes — the
reminder hour is device-local and keyed by supplement id, so a supplement she deleted on her Android
phone would otherwise have kept its alarm on this one, waking her for something the app no longer
shows her.

Sign-out clears both copies, for the same reason it clears milestones and read articles: the next
user on the device must not inherit them.

### Falsification

Five breaks, each rebuilt and re-run, each failing exactly its own test and nothing else:

| Break | Fails |
|---|---|
| Strict `decodeIfPresent(SupplementTime.self)` | `testAnUnrecognisableStoredTimeCostsTheTimeAndNothingElse` — `[]` for the whole list |
| `merge` drops local-only rows instead of queuing them | `testAnEmptyCloudKeepsHerListAndQueuesItForUpload` |
| Legacy read routed through `store.string(forKey:)` | `testTheListFromBeforeTheSyncIsAdoptedAndCarriedUp` |
| `delete` as an array removal | `testADeletedSupplementDoesNotComeBackOnTheNextPull` |
| `updatedAt ?? ""` | `testARemoteRowWithNoUpdatedAtIsDatedWhenItWasCreatedNotNow` |

**One test premise was wrong and was corrected rather than made to pass.** The first draft of
`testADeletionMadeOnAnotherDeviceRemovesItHere` seeded an unpushed local record and expected a
remote tombstone to beat it. It does not, deliberately: an unpushed local change is one the server
has never seen, so it outranks anything the server says — the same rule `PhSync` uses. The state was
also unreachable, since she cannot delete on Android something that was never pushed. The test now
syncs first, then applies the tombstone, which is the scenario that actually occurs.

### The crash this batch introduced, which 30 green tests could not see

Worth writing down in full, because the next repository migration will hit it identically.

Moving supplements off `@AppStorage` and onto a repository changed how `SupplementPlanSheet` gets
its data: from a property wrapper that needs nothing, to `@EnvironmentObject private var supplements:
SupplementsRepository`, which needs the object to have been injected somewhere above it.
`GenesyxApp.swift` injects nine repositories and `container.supplements` was not among them. SwiftUI
answers a missing `@EnvironmentObject` with a `fatalError` at body-evaluation time, so **tapping
"Review Plan" in Nutrition crashed the app outright** — not a blank sheet, a termination.

Both fast suites were green while this was true, and would have stayed green forever:

- The 18 domain tests never touch SwiftUI.
- The 12 app tests construct `SupplementsRepository` directly and assert on it. That is what makes
  them fast and what makes them blind here — they supply the dependency the app was failing to
  supply, so the defect is definitionally outside their reach.

`testEachSupplementCanBeGivenItsOwnReminderTime` caught it on the first run, and its own doc comment
had predicted the mechanism months earlier: *"a sheet that doesn't inherit them crashes on open
rather than failing a unit test."* That comment is the reason the diagnosis took one grep instead of
a bisect. **Leave it there.**

Fixed by adding `.environmentObject(container.supplements)` in `GenesyxApp.swift:39` and
`PreviewSupport.swift:50` — the previews file matters too, or every `#Preview` touching Nutrition
crashes in Xcode.

Two rules follow, and they are about ordering rather than coverage:

1. **A new `@EnvironmentObject` in any view is an edit to two files, not one.** Grep
   `\.environmentObject(` and confirm the new one appears in both `GenesyxApp.swift` and
   `PreviewSupport.swift` before considering the change done.
2. **The UI suite runs before a batch is called finished, not after.** It is ~12 minutes against
   ~1 second, so the temptation is to treat it as a formality once the fast suites are green. This
   batch is the counter-example: green fast suites, shipping-blocking crash. Budget the 12 minutes.

### Left open deliberately

**Cross-device QA on real hardware is still owed**, and it needs the disposable account (H8). The
merge rules are proven against fakes; two physical phones on one account are not something a test
suite can stand in for.

**There is still no edit path** — a supplement can be added and deleted, not renamed. `SupplementSync`
notes what would need to change if one is added: `updatedAt` currently doubles as insertion order,
and an edit would break that, so the list would want a `createdAt` of its own.

## 4y. H20 — what one account leaves behind for the next (2026-08-14)

Four areas already marked **Done** were re-audited on the rule this project keeps re-learning: "Done"
has repeatedly meant *the feature exists*, not *it is safe to use*. Twenty-one findings. Six fixed,
two rejected on inspection, thirteen recorded in `CHANGE_LIST_PLAN.md` §11 as needing a decision or a
rebuild rather than a patch.

**The three that matter most all live on the same seam: the moment one person stops using the phone
and another starts.**

1. **`focusMode` survived sign-out.** It sat in `PreferencesRepository` next to theme and push, and
   `clearNotificationState()`'s doc comment asserted it "belongs to the device". It does not — Prep
   vs Pregnancy is a health answer. Nothing cleared it, so the next account opened Profile to find
   Pregnancy pre-selected. **The severe case is a new sign-up**, whose `profiles` row does not exist
   yet: `refresh()` seeds one from whatever the device holds and writes a stranger's pregnancy status
   permanently into her record. Fixed with `clearFocusMode()` called from
   `AppContainer.clearLocalState()`.
   **The non-obvious part is why it brackets the write in `isApplyingRemote`.** A plain
   `focusMode = .prep` fires `didSet` → `pushPrefs()`, which would reset the **departing** user's
   server row and destroy the answer she gave. Her value stays server-side and returns on her next
   pull. Any future "clear this on sign-out" on a `@Published` property with a pushing `didSet` has
   the same trap.
2. **`deleteAccount()` had both halves of the handover backwards**, and it is the only teardown path
   that did — `signOut()` was already right, which is exactly what made it findable. Two symmetrical
   errors:
   - the owed rename was left set, so the next sign-in resolved a name from the only thing it still
     had (the email prefix) and drained *that* onto the incoming user's row, over the real name she
     registered under;
   - `store.remove(forKey: identityKey)` discarded the marker `applySignIn` uses to detect an owner
     change. **`previous == nil` is indistinguishable from a device that has never held a session**,
     so the wipe was skipped and anything logged between the deletion and the next sign-in was filed
     as the new user's and pushed to her rows.

   The identity key now outlives the account deliberately, and the reasoning is written at the call
   site so it does not get "tidied up" a second time.
3. **Home was routing around H18's fix from the other door.** `CycleSetup` exists solely to forbid
   fabricating a new user's last-period date as today. H18 fixed the sheet; `HomeView` opened the
   same sheet holding `@State private var lastPeriod = Date()` and passed a fabricated
   `CycleSettings` in, so `initialLastPeriod` resolved to today, `canSave` was satisfied on open, and
   the "My period started today" confirmation was hidden. **Carry this forward: a fix to a guarded
   screen is not done until every caller of that screen has been read.** `TrackView:55` and
   `ProfileView:79` were checked in the same pass and were already correct — Home was the sole
   offender, and it offended by pre-answering the question the guard exists to ask.

The other three: the Sunday nudge read raw `learnArticles` instead of `LearnLibrary.articles`, whose
own doc comment names it as a caller that must go through the gate — and because the "new" pool is
*exclusive*, it drew **only** from the twelve date-withheld pieces, then spent the slug via
`markAnnounced` so the real drop was silent. The `.ovulatory` sub-line forecast an event that is
always today, contradicting its own hero, Home and Track. And `QuizView`'s `@State` was destroyed on
navigating away, so backing out of the readiness summary cleared all five answers.

**The test-seam lesson is the transferable one.** Every existing Learn test rebuilt the candidate
list from `LearnLibrary.articles` itself, so the suite was *structurally incapable* of catching the
single production caller that used something else. `learnCandidates()` was widened from `private` to
internal specifically to let a test drive the real composition. **When every test constructs the
input the production code is supposed to derive, the suite proves the helper and not the wiring.**

4 app tests + 1 domain test, all falsified. The app falsification broke all three source fixes
simultaneously and produced **18 assertion failures across exactly the 4 new tests and nothing else**
in the 272-test target — the precision is the evidence. Restored and re-run green: 267 / 272 / 66.

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
- **The Home pH card's accessibility label is pinned to exactly `"Check your Vaginal pH"`** by
  `CitationE2ETests.testHomePhCardHasNoUncitedClaim`, so the card stays a navigational nudge with no
  health claim and therefore no citation requirement. The exact-equality assertion is the point: any
  addition trips it and forces a human to look. Note the guard covers the **label**, not the card —
  the visible subtitle already shows "Last reading 6.9 — tap to log again", which
  `.accessibilityElement(children: .ignore)` keeps out of the accessibility tree. Putting that number
  into the label is a compliance decision; it was attempted and reverted on 14 Aug (§4t).
- **Use `.alert`, not `.confirmationDialog`, wherever the decline button's wording carries meaning.**
  SwiftUI's `.confirmationDialog` silently discards a custom `.cancel` label and substitutes the
  system "Cancel" — so `Button("Keep it", role: .cancel)` renders as "Cancel". This is invisible in
  code review and looks like a presentation failure in tests. `.alert` honours both labels and is
  queryable as `app.alerts["title"].buttons["label"]`. See §4t.
- **Present the pH log sheet with `.sheet(item:)`.** The `isPresented` + separate-`editing` pair
  races: the body is evaluated before the sibling state lands, which silently turns every edit into
  a duplicate new reading. `testPhHistoryListOpensAnOlderReadingForEditing` is the guard.
