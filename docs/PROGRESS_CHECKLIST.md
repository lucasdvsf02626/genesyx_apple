# Genesyx iOS — Progress Checklist

> Last verified: **14 Aug 2026**, against the release commit `8580dd6` — batches 1–9 are now
> committed, and the working tree is clean apart from `graphify-out/`, `.claude/` and the
> deliberately excluded duplicate `docs/assets/` copy of the guide PDF.
> The date below is the last verification date, not necessarily the original implementation date.
> Only **Done** rows are ticked. Section 4 is deferred and excluded from the Sections 1–3 total.

## Overall progress

| Scope | Done | Descoped (D3/D4) | Blocked on a person | Total |
|---|---:|---:|---:|---:|
| Sections 1–3 | **37 (84%)** | 2 | 5 | 44 |
| Sections 1–3, release scope only | **37 (88%)** | — | 5 | 42 |
| Section 4 — deferred by the brief | 1 | — | 4 | 5 |

Both percentages are shown on purpose. **84%** is against the client's original 44. **88%** is
against the 42 this release is committed to, once D3 and D4 are removed by decision. Quoting only
the second would flatter the result.

### The client's ten priority groups, at a glance

The sections below are numbered the way this repo files them (1A…3B). The client's change list is
numbered 1–10 by priority. This is the mapping, so the two can be read against each other without
recounting.

| Client group | Section | Done | State |
|---|---|---:|---|
| 1 · Critical — Vaginal pH | 1A | 7/8 | Website science + Shettles pages still not citable — **BLOCKED** |
| 2 · Critical — Tracking, calendar, Profile | 1B | 6/9 | Code complete; 3 rows stay **In review** (live account / live email / device QA) |
| 3 · Critical — Gender-preference question | 1C | 2/2 | ✅ Complete |
| 4 · Critical — Connectivity | 1D | 2/3 | Code complete and audited; physical cellular QA **DEFERRED** (no iPhone) |
| 5 · UX — Restore intended design | 2A | 4/4 | ✅ Complete — warm/premium **approved** by the client, 14 Aug (D1) |
| 6 · UX — Nutrition + hydration | 2B, 2C | 8/8 | ✅ Complete — closed by H19, 14 Aug |
| 7 · UX — Contextual cycle guidance | 2D | 3/3 | ✅ Complete |
| 8 · Engagement — Logging streak | 3A | 2/4 | Closed for this release — the other 2 **descoped** by the client, 14 Aug (D3, D4) |
| 9 · Engagement — Education, 12 weeks | 3B | 3/3 | ✅ Complete |
| 10 · Partner, Health, widget, barcode | 4 | — | Deliberately not started; the brief defers it |

### FROZEN PRODUCT DECISIONS — 14 Aug 2026 · DO NOT REOPEN

The client froze these so no assistant or reviewer re-litigates them. **Settled input, not open
questions.** Canonical copy with rationale: `CHANGE_LIST_PLAN.md` §0.0.

| # | Decision | Ruling |
|---|---|---|
| **D1** | Warm / premium presentation | ✅ **Approved** — closes the 2A sign-off. Not a licence to restyle freely: visual changes still face the same tests, accessibility expectations and compliance guards. |
| **D2** | Deleting a whole daily log | ❌ **No, not this release.** Build no delete path on either client. |
| **D3** | Cycle edits / article reads counting toward the streak | ❌ **No, not this release.** No new production column, no Android migration. |
| **D4** | Occasional streak restore | ❌ **No, not this release.** Same descoped column and migration as D3. |
| **D5** | The bundled guide PDF | ⚠️ **Internal use only — not App Store-ready** until §11.1c's four content corrections and the medical review are done. |

**D2, D3 and D4 are descoped, not delivered.** Never present them as done.

### The five that are not done, and who owns each

Was eight. **D1 closed one, D3 and D4 removed two from scope, and D2 resolved half of #4** — the
product half; its QA half remains. **None of the five is code waiting to be written.** Every one
needs a person, a page or a device.

| # | Item | Row | Status | Owner | What unblocks it |
|---|---|---|---|---|---|
| 1 | pH science + Shettles website links | 1A | **BLOCKED** | **Content owner** | ⚠️ **Re-fetched live 14 Aug 12:50 and still blocked.** Two new slugs now exist but are **not** the required pages and are **not wired**. `https://genesyx.co.uk/pages/vaginal-ph-fertility-science` is the same uncited product/marketing copy as `/pages/ph-tracking` (no citations, no science). `https://genesyx.co.uk/pages/shettles-method-evidence-limitations` is an empty Shopify page whose H1 is the slug only — it does not call the method unproven and does not cite Wilcox. Do not substitute either. |
| 2 | Profile section — every edit works | 1B | **IN REVIEW** | **Client QA** | Disposable-account run of the remote success and failure paths. Never against a live customer account. |
| 3 | Edit name, password, personal details | 1B | **IN REVIEW** | **Client QA** | Code-side name persist/sync is proven. Live reset-email delivery and the deep-link return are **not** verified. There is no in-app recovery-URL handler. |
| 4 | Controls obvious; entries updatable | 1B | **IN REVIEW** | **Client QA** | Product half settled by D2 (no daily-log delete). Simulator evidence: Track “Add to today’s log” is clipped by the tab bar (`docs/day-report-assets/track.png`); Insights pH Safety note sits below the fold. Physical-device pass **DEFERRED** (no iPhone). |
| 5 | Works over mobile data | 1D | **DEFERRED** | **Client QA** | Code audited: no cellular restriction. A simulator cannot prove a radio. Physical cellular / dead-zone QA is **DEFERRED** because no physical iPhone is available — not left In progress. |

### H22 — mandatory authentication gate · **Engineering Done; simulator verified; physical-device QA deferred** (14 Aug 2026)

P0, **outside the original 44**. The seven main tabs used to be reachable from `genesyx.onboardingComplete` alone.

**Policy (still in source):** splash, quiz and bundled guide may stay pre-auth. Home, Track, pH, Nutrition, Insights, Learn and Profile require a valid session (`RootRouting.swift`). A returning signed-out user goes to non-dismissible `AuthView(allowsDismissal: false)` — no `auth.back`. Mandatory Sign In shows `brand_lockup` (`auth.brandLogo`).

**Simulator evidence belongs to this tree.** `/tmp/genesyx_h22i_full_ui.log` (14 Aug 14:16, 886.043 s): **79 executed, 1 expected notification-permission skip, 0 failures.** Product/test files for the gate are older than that log. App suite `/tmp/genesyx_h22_final_app.log`: **288/0** (14:20). Domain `/tmp/genesyx_h22_final_domain.log`: **267/0** (14:18). All three ran over one byte-identical tree, md5-fingerprinted before and after, on a simulator with no other `xcodebuild` attached.

**Two evidence gaps were found and closed by a second audit pass on 14 Aug.** Both were tests that
were green while claiming more than they proved, which is the failure mode a green suite cannot
report on itself.

1. **The expired/revoked-token path had no coverage at any level.** The UI test that looked like it
   covered it launched with `-uiTestSignedOut`, which seeds *no credential* — that is the *missing*-
   session path, not a cached credential the server has stopped honouring. The two are different
   mechanisms and only one of them was tested. `App/GenesyxTests/SessionExpiryTests.swift` (new, 4
   tests) drives the real one through an injected `AuthBackend` fake — **no Supabase, no network, no
   account**. It proves: expiry signs out *and* fires `onBecameSignedOut` (the hook that drops the
   held notification destination and cancels the schedule, so a silent state change would leave
   private routing armed); neither `.tokenRefreshed` nor `.initialSession(userId: nil)` can bring an
   expired session back; a cold launch whose `currentUserId` is non-nil but whose `validatedSession()`
   is nil resolves `.resolving` → `.signedOut` and never `.signedIn`; and a genuine new sign-in still
   reaches `.signedIn`, so the gate is not "correct" by refusing everything. The misleading UI test
   was renamed `testMissingSessionNeverShowsPrivateContent`.

2. **`testNotificationTapWhileSignedOutDoesNotOpenATab` performed no notification action at all** —
   it was a strict subset of the test above it, and its name claimed evidence it did not provide. It
   is replaced by a pair built on a DEBUG-only launch argument (`-uiTestPendingNotification`,
   `GenesyxApp.swift:26-38`, inside `#if DEBUG` and referenced nowhere else in product code, so it
   cannot affect Release). The argument injects a destination through the **same** `payload` →
   `destination` decode the real `didReceive` handler uses, so the assertion is against a genuinely
   held destination rather than an app that simply has nothing pending.
   `testPendingNotificationWhileSignedOutNeverOpensItsTab` proves the gate holds it;
   **`testPendingNotificationOpensItsTabOnceAuthenticated` is the control** — the same injection on a
   signed-in launch does land on Insights. Without the control the first test would also pass if the
   hook did nothing, so the control is what makes it evidence.

**Falsification.** Re-inserting `case .sessionExpired: break` into `SessionRepository.swift` produced
exit 65, `Executed 4 tests, with 6 failures`, `** TEST FAILED **`
(`/tmp/genesyx_h22_expiry_falsify.log`) — 3 of 4 failing on exactly the intended assertions
(`"signedIn" is not equal to "signedOut"`, `onBecameSignedOut must fire…`). The 4th correctly still
passed: it exercises the bootstrap path, a different mechanism from the lifecycle event. Production
line restored and re-verified.

**What the simulator cannot prove.** Every UI test runs `AppContainer.uiTestSeeded()` with
`backend: nil`. They prove the routing table and the view wiring; they never exercise Supabase's real
session restore. Keychain persistence across a genuine cold boot, a token revoked from another
device, and Sign in with Apple on real hardware are therefore **unproven, not passed**.

**Physical logout/relaunch QA is DEFERRED** — no physical iPhone is available. That absence does not keep H22 In progress.

### H21 — the free guide · **Done** (14 Aug 2026) — PDF still not App Store-ready

Outside the 44, because it is H20 audit finding #2 rather than a client change-list row. The client
returned the product decision and it is implemented: **"Open My Free Guide"** opens a bundled PDF
with no account, no email, no waiting list, no Supabase and no connection, and the same guide sits
under Learn → Guides. Detail in `CHANGE_LIST_PLAN.md` §11.1; state in `HANDOFF.md` §0.

**Both engineering gates are now ticked:**

- [x] The falsification run is executed and recorded. Minimal one-line regression
      (`onOpenGuide: { }` — the CTA no longer opens the guide). Fresh backup
      `/tmp/onb_h21_prod_20260814T104552.swift`. Recorded failure, 14 Aug 2026 10:46:
      `GenesyxUITests.swift:130` `XCTAssertTrue failed - the bundled PDF should render — a blank
      reader means it is not in the app bundle` (28.044 s, exit 65). Restored from that backup, and
      the restore was byte-identical **at the time** (`md5 b85686926825890766d64990ae2f747e`, 342
      lines). `WaitlistView` was not reconstructed.
      **The live file no longer matches that hash. That is expected, not a regression.** It is now
      `md5 9124dd6ef35afe9cd86bf64bcf0fd4bf`, 348 lines. Re-diffed against the backup on 14 Aug:
      the **only** delta is at line 82, where the splash `Text("GENESYX")` was replaced by
      `Image("brand_lockup")` — an unrelated later branding change, asset verified present in
      `Assets.xcassets` with light and dark variants. The guide route is untouched:
      `grep -ic waitlist` on that file returns **0**. Do not read the hash drift as evidence the
      restore failed — re-diff before concluding anything from it.
- [x] The full UI suite is re-run green: **67 executed, 1 skipped, 0 failures**, 785.545 s,
      `** TEST SUCCEEDED **` (`/tmp/genesyx_h21_full_ui.log`).

Verified against the restored production tree, 14 Aug 2026: `FreeGuideBundleTests` 3/0 in 0.003 s;
the two guide UI tests 2/0 in 32.091 s after restore (onboarding 20.740 s, Learn 11.351 s);
`** TEST BUILD SUCCEEDED **`; the PDF present inside the built `.app` and byte-identical to the
repository copy.

**It must still not be called App Store-ready** until four content corrections are made to the PDF
by a person — filename/metadata, the page-20 typo "Download **out** free app", the page-20
QR/app-download call-to-action, and accessibility tagging — plus the medical and content-source
review every other piece of shipping content has had. Those are `CHANGE_LIST_PLAN.md` §11.1c and
stay open.

Latest clean automated evidence: **267 domain, 288 app and 79 UI tests** — 0 failures and 1
pre-existing permission-dependent skip
(`NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission`).
Authoritative UI run for the current tree: `/tmp/genesyx_h22i_full_ui.log`
(886.043 s, 79 exec / 1 skip / 0 fail, 14 Aug 14:16) — AuthGate 12, Citation 7, Genesyx 55,
LifecycleE2E 3, NotificationFlow 1 (skipped), SleepSmoke 1. App suite
`/tmp/genesyx_h22_final_app.log` (288/0, 14:20). Domain `/tmp/genesyx_h22_final_domain.log`
(267/0, 14:18). The app count rose from 276 after H11 by H22's `RootRoutingTests`,
`SessionExpiryTests` and session/auth restore waits. The UI count rose from 67 by the ten
AuthGate tests, `testMandatorySignInShowsTheBrandLockup` and the notification-injection pair.
Historical H21/H11 UI logs (67/1/0) remain valid for those batches and are superseded as the
overall baseline.
which check the PDF against the **built `.app`** rather than the repository: if it fell out of Copy
Bundle Resources nothing would complain, because the button still opens and the reader is simply
blank. The app count rose by 9 with H13's display-name sync, by a
further 1 with H16's cancellation test, by 2 with H17's refresh-race tests, by 3 with H18's
calendar and history tests, by 12 with H19's supplement sync and by 4 with H20's account-handover
batch; H16 also added 4 domain tests and replaced 1, H18 added 3 domain tests and **rewrote 1 that
had been asserting a wrong answer** (see 2B), H19 added 18 domain tests and **corrected 1 whose
premise described a state the sync cannot reach** (see 2B), and H20 added 1 domain test for the
ovulation-day copy (see 2D). The 66th UI test is H19's
`testASupplementIsAddedWithOneOfTheFourSharedTimes`, which drives the four-option picker through
the assembled screen — deliberately placed here and not in the app target, for the reason the
paragraph below gives.

**H19 is also the batch that proves a green fast suite is not a releasable app, so read the UI
number as load-bearing rather than ceremonial.** All 30 of its new tests passed while the app
terminated on tapping "Review Plan" — a missing `@EnvironmentObject` injection, which the domain
tests cannot see (no SwiftUI) and the app tests cannot see (they construct the repository
themselves, supplying the exact dependency the app was failing to supply). The existing UI test
`testEachSupplementCanBeGivenItsOwnReminderTime` caught it on the first run. **Run the ~12-minute UI
suite before calling a batch done, not after** — and treat any new `@EnvironmentObject` as an edit
to both `GenesyxApp.swift` and `PreviewSupport.swift`.

## 1A — Vaginal pH feature (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Replace all “urine pH” references with “vaginal pH” | **Done** | 13 Aug 2026 | User-facing Home, pH and guidance copy is vaginal-pH specific. Internal legacy urine typing remains deliberately for safe decoding; it is not shown as the feature. |
| ☑ | Remove pH tracker from Nutrition | **Done** | 13 Aug 2026 | Nutrition opens on its own focus content; pH routes to the dedicated tab. |
| ☑ | Add dedicated pH icon and bottom-navigation link | **Done** | 13 Aug 2026 | Dedicated seventh tab is wired and tested. |
| ☑ | Add result, view history and explain readings | **Done** | 14 Aug 2026 | Logging, trend ranges, interpretation, full dated history, and edit/delete work. Cold-relaunch test proves vaginal type persists. **H15 fixed a destructive fault here:** the delete button sat in the toolbar's top-left slot — where every other iOS screen puts Cancel — and fired on the first tap, so opening a reading to change it and then thinking better of it destroyed the reading. It is now in the body of the sheet, away from Save, behind a confirmation, and the toolbar slot is a plain Cancel that only dismisses. The trend range selector also gained a readable selected state; which of 7d/30d/90d/all was showing had been expressed in colour alone, so VoiceOver read four identical labels. |
| ☑ | Explain pH/vaginal-health relevance to fertility | **Done** | 13 Aug 2026 | Short contextual explanation is present without diagnosis or unsupported causation claims. |
| ☑ | Expand Learn content, including when to seek help | **Done** | 13 Aug 2026 | Cited vaginal-health guidance and professional-help wording are present. |
| ☑ | Move disclaimer into an info/expandable panel | **Done** | 14 Aug 2026 | Main-card disclaimer is collapsible; the logging sheet retains visible safety copy. **H15 found one pH surface with no disclaimer at all** — the Insights pH card, which is the most clinical-looking thing in the app: a pH value, an `ELEVATED` badge and a "speak to a GP" signpost. A woman who reads her result there and never opens the pH tab saw all of that with no small print. It now carries the same collapsible "Safety note". Separately, two pH cards told her to "log your cycle day alongside each reading" when the log sheet has no cycle-day control — an instruction she could not follow. Reworded to name the note field, which exists, and moved into `PhCopy` so the two cards cannot drift apart. |
| ☐ | Link to Genesyx website science and Shettles content | **Blocked** | 14 Aug 2026 | Re-fetched live 14 Aug. Two slugs appeared today and **must not be wired**: `https://genesyx.co.uk/pages/vaginal-ph-fertility-science` is the same product/marketing copy as `/pages/ph-tracking` (H1 “Track your vaginal pH at home”, Google Play CTAs, **no citations**). `https://genesyx.co.uk/pages/shettles-method-evidence-limitations` is an empty page whose H1 is the slug — it does not call the method unproven and does not mention Wilcox. App grep of both paths: **0**. Unblocking still needs a **cited science page** and a **Shettles page framed as unproven**, then a small wiring change. |

## 1B — Tracking, calendar and Profile (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Log symptoms and nutrition from the tracker | **Done** | 13 Aug 2026 | Symptoms work. H4 dated food groups into the Track day sheet, My Logs, Insights and the streak identically on both clients. The daily log sheet now carries its own food-group control, so “Edit this day” can change the meals that same sheet reports, and a meal can be entered from the tracker rather than Nutrition only. Both directions are UI-tested and falsification-proven: ticking/un-ticking round-trips, and saving the sheet no longer wipes a meal logged in Nutrition. **iOS only** — Android reads and syncs meals but still has no control to record one. |
| ☑ | Private sexual-activity logging for TTC users | **Done** | 13 Aug 2026 | Private daily-log field and UI are owner-only; no partner or lock-screen detail exposure. |
| ☑ | Entries persist on the correct calendar date | **Done** | 14 Aug 2026 | Daily logs and pH use dated persistence; pH now survives a real second-process relaunch. **H18 found they persisted correctly and were then hidden on the way back out** (14 Aug): "Your logs" filtered on a hand-written `isBlank` in `InsightsView` that had drifted from the shared predicate, so a day whose only entry was food groups — or intimacy — was dropped from the read-back. The calendar drew its dot, the day sheet named the entry and the streak counted it; only the screen whose whole job is showing her logs back disagreed, in the same file that already knew how to render food groups. It now delegates to the shared `hasAnyEntry`, so it cannot silently fall behind it again, and the history card gained an Intimacy row. |
| ☑ | Colour markers: period, fertile, ovulation, activity, pH, symptoms/notes | **Done** | 14 Aug 2026 | Calendar markers, phase/fertile styling and legend are implemented and tested. **H18 found one of the six was unreachable on a short cycle** (14 Aug): `CycleEngine.dayType` gives period precedence, so wherever ovulation falls inside the period — 21/7, 22/8, 23/9 and 24/10 are all selectable — the ovulation marker was never drawn at all, while Home, Insights and the cycle sheet each still printed "Predicted ovulation: Day 7". Fixed in the view rather than the engine, because `dayType`'s precedence is deliberate and shared with Android; the fertile ring already used exactly this workaround for the *window*, and nobody had carried it to the *day*. **Also corrected here: every period countdown was one day short** (`cycleLength - dayOfCycle`, missing the `+ 1` that accounts for the next period starting on day 1 of the next cycle). On the last day of the cycle it reached 0, which Home renders as "Next period: Today" — a full day early, every cycle. The domain test had asserted the wrong numbers, so a green suite proved nothing. Android and web still carry the old expression; flagged for parity, not touched. |
| ☑ | Notification or highlight for the most fertile stage | **Done** | 14 Aug 2026 | Fertile-window notification and visual fertile-stage highlighting are implemented. **H16 found two ways the nudge was being lost after it had been scheduled** (14 Aug). Cancelling did not forget: `cancelAll()` removed the pending request but left its remembered fire time behind, so at the next foreground a nudge that never fired was recorded as delivered — and a slot believed to have spoken then serves out its full repeat guard in silence, which for the fertile nudge is fourteen days (`fertileRepeatGuardDays = 14`). Turning reminders off and back on in the same evening cost her a fortnight of it. Separately, a fertile nudge a full week out was standing the evening check-in down, because the rest-day rule uses the weekday as a proxy and seven days on is today's own weekday. Both fixed and falsified. A third report — that the nudge is lost if the app is opened after 08:00 on the day itself — was checked against the source and rejected: at that point the app is already open, and the behaviour is deliberate and documented. **H18 closed the visual half of this row for short cycles** (14 Aug): the notification fired, but on a 21/7-type cycle the calendar drew her peak day as an ordinary bleeding day, so the "clear highlight when entering the most fertile stage" this row promises was the one thing missing on the one day it matters. The fertile ring now thickens on the ovulation day wherever the fill cannot say it, and the cell names the day aloud for VoiceOver. |
| ☐ | Audit full Profile section — every edit works | **In review** | 13 Aug 2026 | The audit is done, and **all five defects it found are now fixed** rather than catalogued. The display name (H13) is the row below. The other four (H14): a custom glass size outside 50–1000 ml was dropped in silence and left on screen looking saved — now clamped to the nearest allowed size when she leaves the field; the master reminder switch was labelled "Weekly reminders" while it gates all eight categories, so declining a "digest" silently declined the daily supplement reminders, the evening check-in and the fertile-window nudge — now "All reminders"; the Pregnancy segment stored *and synced* `focusMode = .pregnancy` while its own sheet said "Coming soon" and "Keep tracking", leaving the segment permanently claiming a mode no screen implements — it now opens the teaser and stores nothing; and the dead `switchRow` helper and unused `@EnvironmentObject partner` are gone. Each is covered by a UI test that was falsified. **H20 audited what one account leaves behind for the next and found three leaks, all on the teardown paths this row's own QA will exercise** (14 Aug). *Focus mode survived sign-out.* `focusMode` — Fertility Prep vs Pregnancy — was being cleared by nothing, because it sat in `PreferencesRepository` alongside genuine device preferences like theme and push, and `clearNotificationState()`'s doc comment even asserted it "belongs to the device". It is a health answer about her body. The next person to sign in on that handset opened Profile to find Pregnancy already selected; worse for a new sign-up, whose `profiles` row does not exist yet, so `refresh()` seeds one from whatever the device still holds and writes the previous user's pregnancy status permanently into hers. New `clearFocusMode()`, called from `AppContainer.clearLocalState()`, and it deliberately brackets the write in `isApplyingRemote` — a naive `focusMode = .prep` fires `didSet` → `pushPrefs()` and would reset the *departing* user's server row, destroying the answer she actually gave. Her value stays on the server and returns on her next profile pull. *Account deletion had both halves of the handover backwards*, and it is the one path that did — `signOut()` was already correct. The owed rename was left set, so the next sign-in resolved a name from the only thing it still had, the email prefix, and drained *that* onto the incoming user's row over the real name she registered under. And `store.remove(forKey: identityKey)` threw away the marker that makes `applySignIn` recognise an owner change: `previous == nil` is indistinguishable from a device that has never held a session, so the wipe was skipped and anything logged between the deletion and the next sign-in was filed as the new user's and pushed to her rows. The identity key now outlives the account deliberately, with the reasoning written at the call site. Three tests, each falsified. What still needs a person: disposable-account testing of the remote success and failure paths, because account creation and password entry are not actions the delivery agent may take — and these three fixes are precisely what that QA should now be looking for. |
| ☐ | Edit name, password and personal details | **In review** | 13 Aug 2026 | Name editing and password-reset email are wired. **H13 found the name was not merely unverified but broken**, and fixed it: it had never been part of the sync contract. Three faults, one cause. A rename was pushed fire-and-forget with no owed flag and appeared in no drain, so a correction made offline was lost silently. Sign-up never pushed at all, so the name she registered under never left the device — her partner's app read `display_name` as null and showed the literal word "Partner". And nothing ever read the column back, so a reinstall or a second phone greeted her as the part of her address before the @. It now follows the same owed-write contract as her theme and focus mode: push then pull, the local write wins, the flag is persisted across relaunch, and it is dropped on sign-out and on an identity change so it cannot land in the next account's row. 9 tests, 7 falsifications. Password-reset delivery, the deep-link return and replacement-password sign-in still need live QA — **code verification is not live email-delivery verification.** `RootView.onOpenURL` handles Google OAuth and partner-invite codes only; there is **no recovery-URL / new-password handler**. Email change is intentionally unsupported. |
| ☑ | Amend Health Profile and Tracking Preferences | **Done** | 13 Aug 2026 | Both editors are implemented through the existing persistence/sync paths. |
| ☐ | Controls obvious; previous entries genuinely updatable | **In review** | 13 Aug 2026 | Every editable type was walked rather than assumed. Daily logs: editable, not deletable. pH: editable and deletable, already tested. Cycle settings: editable, not deletable. Hydration: **now complete** — the sheet's seven-day strip was inert, so seeing a wrong total on a past day offered nothing to do about it and the only route was Track → that day → Edit this day, which is not where she is looking. H15 made each tile open that day's log (14 Aug); the sheet itself stays a today editor by design, so this adds the missing route rather than redesigning it. The untested gap was the one that mattered: the existing test back-filled an *empty* past day, and nothing covered correcting a day that already held symptoms and a note. That failure would have been silent — a fresh entry saved over the old one takes her symptoms and note with it. Now proven to **merge**, and falsified by breaking the prefill (exactly one failure, the back-fill test still green). One thing stays open: **no daily log can be deleted at all** — `DailyLogRepository` has no `delete()`, which is a data-retention decision, not an oversight to patch quietly. **H18 found the cycle editor's entry control quietly answering for her** (14 Aug): `CycleSetup` exists solely to stop a new user's last-period date being invented as "today", and `canSave` enforced it — but the empty-state "Choose a date" button assigned `Date()`, because SwiftUI's `DatePicker` has to be handed a date to bind to. Opening the picker and choosing a date were therefore the same event, and the second one silently meant today, with Save enabled on the way past. The two are now separate states, and "today" is reachable as an explicit button rather than as the default — deliberately, because SwiftUI may not fire the binding when the day already on screen is tapped. **H20 found H18's fix was being routed around from the other door** (14 Aug): `HomeView` opens the same `CycleSettingsSheet`, and it held its own `@State private var lastPeriod = Date()` and passed `CycleSettings(lastPeriodDate: lastPeriod, …)` in. So `CycleSetup.initialLastPeriod` resolved to today, `canSave` was satisfied on open, and the "My period started today" confirmation was hidden — the exact fabrication `CycleSetup` exists to forbid, reintroduced by the caller. Home now passes `cycle.settings` unchanged, which is `nil` for a new user and is what keeps the sheet's empty state reachable; the inline `DatePicker` on the setup card is gone, so there is one way in and it is the guarded one. `TrackView` and `ProfileView` were checked at the same time and were already passing `cycle.settings` correctly — Home was the sole offender. Simulator evidence from the existing day-report shots: Track’s “Add to today’s log” is clipped by the tab bar (`docs/day-report-assets/track.png`); the Insights pH Safety note sits below the fold. Physical-device pass, including SE3, is **DEFERRED** (no iPhone). Daily-log deletion remains out of scope (D2). |

## 1C — Onboarding question (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Girl / Boy / No preference / Prefer not to say | **Done** | 13 Aug 2026 | Four stable options are stored in the owner-only quiz-answer record. **H20 found the answers were being destroyed by the back button** (14 Aug): the private `QuizView` held `@State private var answers: [String: String] = [:]` and `@State private var step = 0`, and SwiftUI destroys `@State` when a view leaves the hierarchy. Backing out of the readiness summary to change one answer therefore returned her to question 1 of 5 with all five cleared, including this one, and made her enter them all again — the likeliest moment for a woman to abandon onboarding. It now takes `initialAnswers` from `prefs.quizAnswers` and seeds both `@State` values through an explicit `init`, opening on the first question she has *not* answered rather than on question one. |
| ☑ | Optional, with no sex-guarantee suggestion | **Done** | 13 Aug 2026 | Only this question may be skipped; skipping stores no key. Copy guards prohibit efficacy claims. |

## 1D — Connectivity (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☐ | App works over mobile data as well as Wi-Fi | **Deferred** | 14 Aug 2026 | Re-audited this pass: `NWPathMonitor()` is unconstrained, nothing reads `isExpensive` / `isConstrained`, no `allowsCellularAccess` customisation exists, and Info.plist has no ATS keys. `isOnline` only drives Track wording/icons and the reconnect drain. **Not marked Done** — a simulator has no cellular radio. Physical cellular / dead-zone QA is **DEFERRED** because no physical iPhone is available. |
| ☑ | Investigate false offline symbol | **Done** | 13 Aug 2026 | Root cause was a non-published owed-days update, not real reachability; fixed and tested. |
| ☑ | Prevent log loss during temporary connection drops | **Done** | 14 Aug 2026 | Local-first queues, owed writes, foreground/reconnect drains and relaunch tests cover temporary drops. **H17 audited the contract across all five repositories rather than assuming it was applied uniformly, and found two that could lose an edit made while a pull was in flight** (14 Aug). `refresh()` checked what was owed *before* awaiting the fetch and never re-checked, so a change made during the round trip was overwritten by the copy coming back. On profile preferences that lost the change outright rather than reverting it pending a retry: `apply` runs under `isApplyingRemote`, which exists to stop a pull bouncing back as a push, so the overwrite was silently un-owed too. Both now re-read after the suspension, matching the idiom the daily-log and pH repositories already used — those two were immune, which is why the divergence was findable. Reachable at launch and sign-in only; the foreground path drains without pulling. Physical-device confirmation remains part of H10. |

## 2A — Restore intended design

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Light mode default; dark mode optional | **Done** | 13 Aug 2026 | Local and production defaults are light; dark remains selectable. Existing server choices were not overwritten. |
| ☑ | Restore egg graphics, including subtle backgrounds | **Done** | 13 Aug 2026 | Egg assets are restored and guarded by tests. |
| ☑ | Review overall presentation for a warm, premium feel | **Done** | 14 Aug 2026 | **Approved 14 Aug 2026.** The bounded warm/premium presentation is signed off; all eight recipe photographs are approved; the full Genesyx lockup (`brand_lockup`) is on the initial splash. SE3-375pt light screenshot confirms 220×54 fits without clipping eggs, copy or buttons. Dark variant lives in the same imageset. |
| ☑ | Reduce text blocks; use cards, visuals, icons and expandables | **Done** | 13 Aug 2026 | Key pH, Nutrition and guidance surfaces use cards/disclosures; light/dark and small-screen work is covered. |

## 2B — Simplify Nutrition

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Hide greyed-out explanatory text | **Done** | 13 Aug 2026 | Placeholder-heavy/secondary copy no longer dominates the screen. |
| ☑ | Put secondary information in Learn more/Why dropdowns | **Done** | 13 Aug 2026 | Disclosure controls are present for supporting explanations. |
| ☑ | Keep the main Nutrition screen action-focused | **Done** | 13 Aug 2026 | Meal logging, supplement and hydration actions are prioritised over placeholders. |
| ☑ | Meal logging, food groups/nutrients, suggestions, recipes and reminders | **Done** | 14 Aug 2026 | All five exist on the Nutrition screen: meal/food-group logging, focus-food suggestions, eight recipe cards and per-supplement reminder times (stored, scheduled and cleared on sign-out). H4 closed the last objection by dating those meals into Track, My Logs, Insights and the streak. **H19 closed the last unsynced surface in the app** (14 Aug): her own supplements were `@AppStorage` JSON and nothing more, so a reinstall lost them and the same account showed two different lists on two phones with neither device aware of the other. They now follow the same owed-write contract as pH — local write wins, a failed push stays queued, a pull merges rather than replaces, and a delete is a tombstone so it reaches her other devices instead of being resurrected. The time field was also free text while Android offers four fixed options and the server accepts only those four or null, so anything she typed was either rejected or meaningless to her other phone; it is now the same four, with typed values recovered where they match rather than discarded. Three data-loss traps were caught before shipping and each is now a test: reading the old list through `LocalStore` would have found nothing (it namespaces keys; `@AppStorage` did not) and silently wiped every device; a typed enum with synthesized `Codable` would have lost the **whole list** rather than the time, because array decoding is all-or-nothing; and a remote row with a null `updated_at` would have been dated *now* and overwritten what is on this phone. **A fourth fault was introduced by the batch itself and caught by the UI suite:** the sheet now needs `SupplementsRepository` from the environment and nothing injected it, so tapping "Review Plan" crashed the app while all 30 new tests stayed green. Fixed in `GenesyxApp.swift` and `PreviewSupport.swift`; see the note under the test counts at the top of this file. |
| ☑ | Replace text-only suggestions with meal/recipe cards | **Done** | 14 Aug 2026 | Eight actionable recipe cards replace plain food-name suggestions, and **each now carries its own photograph** (14 Aug) rather than the phase gradient the cards originally shipped on. Two tests hold it, and they are not redundant: the domain test proves no recipe is imageless and no two share a plate, while an app-target test loads every name through `UIImage(named:)` — SwiftUI's string lookup fails silently, and the gradient fallback keys on `imageName == nil` rather than on a failed load, so a typo yields a blank card that no domain test could see. **The eight photographs were approved 14 Aug 2026 (D1 / H11).** |

## 2C — Hydration logging

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Add water by glasses or millilitres | **Done** | 13 Aug 2026 | Both display/input modes use canonical ml storage. |
| ☑ | Custom glass size and correction of wrong entries | **Done** | 13 Aug 2026 | Custom size and dated edit/correction paths are implemented. **A size outside 50–1000 ml used to be dropped without a word** — "3000" stayed in the field reading exactly like a setting that had taken, while the glass it described was still 250 ml. Now corrected to the nearest allowed size when she leaves the field, so what is on screen and what is stored can no longer disagree. Clamped rather than reverted, because reverting would show her "300" — the in-range prefix stored on the way to 3000 — a number she neither typed nor had. **Correcting an earlier day is now reachable from where she notices it (H15, 14 Aug):** the hydration sheet's seven-day strip was inert, so a wrong past total was visible but not actionable, and the only route was Track → that day → Edit this day. Each tile now opens that day's log. Cross-device preference sync remains H9. |
| ☑ | Show progress towards the daily target | **Done** | 13 Aug 2026 | Home, Track, Nutrition and Insights use real logged water/target data. |

## 2D — Contextual cycle guidance

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Visual card when entering a new cycle phase | **Done** | 13 Aug 2026 | Phase-change card is implemented with once-per-phase presentation logic. **H20 corrected the ovulatory hero copy, which contradicted three other surfaces** (14 Aug): `CycleEngine` enters `.ovulatory` only on `dayOfCycle == ovulationDay` and leaves it the next day, so the phase is exactly one day and is always today. The sub-line had been written for an approaching window and read "Ovulation expected in 1–2 days", directly under its own hero "High chance of conception today", above Home's "Predicted ovulation: Day 14", and while Track said "Day 14 · Predicted ovulation day". On the single day the app exists to identify, it told her it had not arrived. Now "This is your predicted ovulation day." A domain test pins it by constructing the day-14 case through `CycleEngine` and asserting the copy carries no forecast wording, so a future rewrite cannot silently reintroduce it. |
| ☑ | Link the phase card to a relevant article | **Done** | 13 Aug 2026 | Card routes to the relevant cycle-eating guidance. |
| ☑ | Personalise Home greeting with the user’s name | **Done** | 13 Aug 2026 | Home uses the signed-in display name with a safe fallback. |

## 3A — Daily logging streak

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☐ | Count meaningful symptoms, hydration, nutrition, cycle, pH and article actions | **Descoped** | 14 Aug 2026 | **D3 — not in this release. Never Done.** Symptoms, hydration, meals and pH already count under the shared predicate. Cycle edits and article reads do **not** count and will not in this release. Both extras would have needed a dated event column and an Android migration; that schema change is cancelled with D3. |
| ☑ | Show current streak and milestone celebrations | **Done** | 13 Aug 2026 | Current streak is shown on Home and the Consistency card. Milestones now celebrate **in the app** as well as by notification, above the tab bar so the moment reaches her wherever she logged. The in-app half deliberately does not require notification permission — it was behind that gate, which meant the woman who declined notifications was congratulated for nothing. The cross-platform rule is agreed and matched: the 7- and 14-day milestones follow the *logging* streak — the number she is actually shown — on both clients, changed in the same sitting. Restore is still a product decision, tracked in its own row. The celebration is reachable to VoiceOver as a named container (`.accessibilityElement(children: .contain)`) rather than swallowing its own button, and muting is now defined rather than merely implemented: muted means none — the modal goes with the banner — and the flag is still spent, so switching milestones back on later delivers silence instead of a backlog. |
| ☑ | Encouraging, no-guilt language | **Done** | 13 Aug 2026 | Notification and streak-copy guards enforce neutral encouragement. |
| ☐ | Consider occasional streak restore | **Descoped** | 14 Aug 2026 | **D4 — not in this release. Never Done.** A restore is a day with no entry that the streak must count anyway, so it needs its own saved-and-synced state — the same cancelled column and Android migration as D3. |

## 3B — Education

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | One new article weekly plus dashboard/in-app discovery | **Done** | 13 Aug 2026 | Weekly reveal schedule, Home card, Learn badge and Sunday notification are implemented. **H20 found the Sunday notification was the one Learn surface not going through the publication gate** (14 Aug): `NotificationService.learnCandidates()` read the raw `learnArticles` array instead of `LearnLibrary.articles`, whose own doc comment names this nudge as a caller that must. Because the "new" pool is *exclusive* — arrived-and-unread — the raw array meant the nudge picked only from the twelve date-withheld pieces, so "New this week" named an article that resolves to "That article isn't available", and `markAnnounced` then spent the slug, so the genuine release day arrived with no notification and no badge. Every existing test in this area rebuilt the candidate list from `LearnLibrary.articles` itself and was therefore structurally incapable of catching the single production caller that differed, so `learnCandidates()` was widened from `private` to internal to open a seam and the new test drives the real composition. |
| ☑ | Push notifications only after opt-in | **Done** | 14 Aug 2026 | App requires user preference plus system permission; production `push_enabled` now defaults false. **H16 fixed the reverse failure — opted in and still hearing nothing** (14 Aug). Notification requests are one-shot and the queue is only rebuilt when the app is foregrounded, so a planner branch returning "nothing to say tonight" queued nothing at all. The evening check-in did exactly that once she had both logged her day and met her water goal. The weekly nudges do not cover for it: `track()` and `ph()` are conditioned on a *gap* in her logging and return nil for a consistent user by design, and `insights()` and `learn()` are rationed to one in seven days — so her queue can empty completely, and the better she was at using the app the quieter it got. It now queues tomorrow's invitation instead. The supplement-reminder copy that the banned-phrase and no-guilt scans read was also fixture data rather than what ships, so the scans had cleared a supplement the app never sends and had never once read "Time for Folate (400–800 mcg)" — now built from the real plan, with a test pinning the coupling. **Still owed:** with no background refresh, a woman who stops opening the app still runs out of queue, so the 14-day dormant hand-back structurally cannot fire. That needs background execution, not a planner change. |
| ☑ | Twelve-week content plan scheduled | **Done** | 13 Aug 2026 | All twelve cited topics, including evidence-framed Shettles content, are present and scheduled. |

## 4 — Clarify/scope separately (excluded from completion percentage)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Confirm current Add Partner behaviour | **Done** | 13 Aug 2026 | Invite, account acceptance, linking and unlinking exist. Partner currently receives the user’s display name only; health logs are owner-only and no partner reminder feed exists. |
| ☐ | Define partner sharing controls with privacy by default | **To do — deferred** | 13 Aug 2026 | No per-category permission model exists. Current private health/log tables remain owner-only. |
| ☐ | Confirm/scope Apple Health, Watch and Oura | **To do — deferred** | 13 Aug 2026 | No HealthKit entitlement, usage keys or wearable integration exists; separate estimated scope remains required. |
| ☐ | Scope a privacy-controlled iPhone widget | **To do — deferred** | 13 Aug 2026 | No WidgetKit target exists. Requires a separate privacy and data-refresh design. |
| ☐ | Scope barcode scanning/meal photos | **To do — deferred** | 13 Aug 2026 | No AVFoundation/VisionKit pipeline exists; treat as a future technical/product scope. |

## Remaining work in practical order

**Release-scope rows still open (5 of 42):** website science/Shettles (**BLOCKED** on content);
Profile remote QA, live password-reset email, and edit-control device QA (**IN REVIEW**);
physical cellular (**DEFERRED**). D3 and D4 stay descoped.

**Outside the 44 (do not implement in a checklist pass):**

1. ✅ **Done 14 Aug** — the exact applied Supabase file `20260813_user_supplements_delete_backstop_and_push_default_false.sql` is now in `supabase/migrations/`, verbatim and `cmp`-identical to the recovered original (md5 `55c387ecc1fc940b892bd8bdc3e1cfb5`). **Still owed:** disposable-account deletion QA — never against a live account.
2. Article 9 explicit-consent / legal-basis decision (TESTFLIGHT P0-13).
3. Sign in with Apple `/auth/revoke` during deletion — **still open, and it is the only part of P0-15 that is.** It needs the Apple `.p8` in Supabase's secret store, which is a person's action, not engineering. ✅ **Client-side revocation handling done 14 Aug** — `SessionRepository.handleAppleCredentialRevoked` + `RootView`'s `credentialRevokedNotification` subscription end the local session when she revokes the app under Settings → Apple ID, guarded on how the live session was obtained so the app-wide notification cannot end an unrelated email session; 3 tests, falsified. ✅ **Also 14 Aug, in the same P0-15 row:** `waitlist_emails` failure now returns 500 instead of `{ok: true}`, and the explicit `user_supplements` delete iOS lacked is in. ⚠️ **Both Edge Function fixes are repo-only — `supabase functions deploy delete_account` has NOT been run**, and the file carries a banner to be deleted in that same change.
4. Bundled guide PDF §11.1c content, accessibility and medical review (D5).
5. Android food-group editor — iOS-only warning, not this delivery.
6. ✅ **Password recovery from the gate — done 14 Aug (TESTFLIGHT P0-20).** H22 turned a forgotten password into a permanent lockout: the only reset control lived in Profile, behind the session she could not obtain. `AuthView` now carries **Forgot password?** and `SessionRepository.sendPasswordReset(email:)` takes the address rather than reading it off a live session. 5 unit tests + 1 UI test, both halves falsified. ⬜ **Still owed:** the in-app landing for the emailed link. It needs the Supabase redirect allowlist and email template to point at `genesyx://` — dashboard-only, there is no `config.toml` in this repo — so **do not build the new-password screen until someone confirms where that link currently goes.**

**H11 / H21 / H22 engineering are closed.** Physical H22 logout/relaunch and H10 cellular stay **DEFERRED**. Do not wire the two new website slugs.
