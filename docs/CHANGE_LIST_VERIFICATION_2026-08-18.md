# Genesyx iOS — Change-list implementation & verification pass, 18 August 2026

> **Tree:** `main` @ `7a533b4` · **Version:** 1.2.0 (20) · **Scope:** iOS only.
> Supersedes nothing. Companion to [`CHANGE_LIST_AUDIT_2026-08-17.md`](CHANGE_LIST_AUDIT_2026-08-17.md)
> (which it re-checks) and [`LAUNCH_READINESS.md`](LAUNCH_READINESS.md) (which owns the off-code blockers).

## 0. Read this first — what this pass did, and the one decision behind it

**No Swift source was changed.** That was a decision, not an omission, and it is reversible.

`git diff --name-only 8df44db HEAD` returns exactly one non-doc file (`to do list.md`), and
`git status --short -- App Sources project.yml Genesyx.xcodeproj` is **empty**. The iOS source tree is
**byte-identical** to the tree that was archived, signed and exported to
`build/Export/Genesyx.ipa` on 17 Aug 23:18 — a verified 18 MB App Store IPA
(`CFBundleVersion 20`, `get-task-allow` false, privacy manifest present at every level).

That IPA is the only shippable artefact this project has produced since 12 July. **Any edit under
`App/` or `Sources/` destroys it** and forces a re-archive as build 21, with a fresh full-suite run
and a fresh archive verification behind it.

So the test applied to every candidate change was: *does this fix something a customer hits, or
something Apple rejects?* Two items in the change list are still genuinely **Missing**. Neither is
code — both are blocked on a person outside engineering (§3). Ten more are **Partial**. None of the
ten is a P0, and each is itemised below with what it would cost to close. **No P0 bug was found**;
two candidates were investigated and both turned out to be correct behaviour, which is recorded in
§4 because the prior notes on them were wrong in the alarming direction.

If you would rather ship the Partials than protect build 20, say so and this becomes build 21. That
is a product call, and it is yours.

---

## 1. Headline

| | Count |
|---|---:|
| Items verified this pass | **35** |
| **Done** — proved in code at this SHA | **23** |
| **Partial** — works, but short of what was asked | **10** |
| **Missing** — no implementation at all | **2** |
| **P0 bugs found** | **0** |

The two Missing items are both in section 1A (critical, vaginal pH) and both have the **same single
blocker**: two pages on genesyx.co.uk that do not exist. I re-fetched them live today — see §3.

---

## 2. Item by item

Verdicts are against the code at `7a533b4`. Every row carries `file:line`. Where a row contradicts
`CHANGE_LIST_AUDIT_2026-08-17.md`, the change is called out.

### 1A — Vaginal pH (critical)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Wording is vaginal pH, not urine | **Done** | Remaining `urine` hits are an enum case for legacy tolerance (`Sources/GenesyxCore/Models/PhReading.swift:7`, `App/Genesyx/Data/PersistenceDTOs.swift:74`) and a rename map (`Notifications/LearnReadLog.swift:12`). The three user-visible "urine" strings are a hydration colour cue and two study descriptions (`UI/Learn/LearnContent.swift:870,951,1088`) — none is urine *pH* |
| 2 | Removed from Nutrition | **Done** | `UI/Nutrition/NutritionView.swift:10,43,47` reads `PhRepository` only to count consistency days. No tracker, no log button, no pH card |
| 3 | Dedicated pH tab | **Done** | `UI/MainTabView.swift:20,32`; title "Vaginal pH Tracker" (`UI/Ph/PhTrackerSection.swift:32`) |
| 4 | Add reading, history, interpretation | **Done** | Add `PhTrackerSection.swift:131-139` → `PhLogSheet:447-559`; history `:243-295` (expandable, tap to edit/delete); meaning `:209`, `:397-401` |
| 5 | **Explain relevance to fertility** | **MISSING** | `grep -i fertil` over `Sources/GenesyxCore/Ph/` and `App/Genesyx/UI/Ph/` returns **nothing**. Spine copy stops at "signal of intimate wellbeing" (`PhCopy.swift:33`). The ungated pH guide (`LearnContent.swift:684-712`) never says fertility either |
| 6 | Learn expanded — supporting vaginal health | **Done** | `PhCopy.swift:51-56`, rendered unconditionally at `PhTrackerSection.swift:406-412`. Triggers on symptoms with **no reading threshold**, so normal readings + symptoms is no longer a dead end |
| 7 | Disclaimer behind an info icon | **Partial** | Tracker card: collapsed behind "Safety note" (`PhTrackerSection.swift:154-171`). Log/edit sheet: still inline small print (`:479`, `:483-485`), deliberately, per the comment at `:151-153` |
| 8 | **Links to the website + Shettles page** | **MISSING** | No `http` or `genesyx.co.uk` link anywhere under `UI/Ph/` or `GenesyxCore/Ph/`. The only outbound links in the app are privacy policy and support (`ProfileView.swift:9-10`). See §3 |

### 1B — Tracking, calendar, Profile (critical)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 9 | Symptoms + nutrition logging | **Done** | `UI/Log/LogView.swift:54,56,292-317,329`; save writes both `:132,138`. The tracker's Nutrition row now reads `foodGroups` (`TrackView.swift:605-609`) — **R1 confirmed landed**, so this row is Done in fact, not only on paper |
| 10 | Private sexual-activity logging | **Done** | `LogView.swift:261-279`; owner-only RLS with no partner grant (`supabase/migrations/20260810_daily_logs_sexual_activity.sql:19-32`); absent from every notification string (counted internally only, `NotificationService.swift:212,240`) |
| 11 | Saves to the correct date | **Done** | Day sheet reads `dailyLog.log(on: day.date)` (`TrackView.swift:78-86`); editor opens on that date (`:62`); write is `upsert(_:on: date)` (`DailyLogRepository.swift:83-91`) |
| 12 | Six colour markers | **Done — all six** | Period fill `TrackView.swift:250`; fertile fill `:251` + ring `:210-221`; ovulation solid + thickened ring `:252,:218`; then pH / symptoms / intimacy dots `:239-246` from `GenesyxCore/Tracking/DayMarkers.swift:36-44`. Legend `:281-300` |
| 13 | Fertile stage highlighted | **Done** | Home hero switches copy (`CycleContent.swift:76-91` → `HomeView.swift:120-134`); calendar ring/fill; opt-in 08:00 push on the morning the window opens (`NotificationPlanner.swift:235-250`) |
| 14 | Full Profile edit audit | **Partial** | Name persists (`ProfileView.swift:80-82` → `SessionRepository.swift:266-283`); password reset now sends `redirectTo: DeepLink.passwordRecoveryURL` (`SupabaseBackend.swift:54`) with an in-app `ResetPasswordView`; Health Profile persists (`CycleRepository.upsert:34-39`); Tracking Preferences persist (`PreferencesRepository.recordQuizAnswers:123-126`). Shortfalls: "Personal details" is display name only, email is read-only by design (`:700-711`), and the Track cycle-edit pencil still has no accessibility label (`TrackView.swift:100-108`) |

### 1C — Gender-preference question (critical)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 15 | Girl / Boy / No preference / Prefer not to say, optional | **Done** | `GenesyxCore/Content/QuizContent.swift:88-99` with `isOptional: true`; skip at `OnboardingFlowView.swift:250-252` |
| 16 | No guarantee implied | **Done** | The answer is **recorded and never read**. The only quiz key any logic consumes is `quizAnswers["support"]` (`GenesyxCore/Notifications/SupplementPersonalisation.swift:148`). Nothing in the app behaves differently by preference, so nothing can imply an outcome |

### 1D — Connectivity (critical)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 17 | Works on mobile data · no false offline symbol | **Done in code** | Real `NWPathMonitor` (`Data/Reachability.swift:41`). `icloud.slash` is reserved for genuinely offline; a pending row on a live connection gets the hollow upload cloud instead (`TrackView.swift:1165-1173`, `:1332-1340`). Reachability never gates a write (`Reachability.swift:10-13`). **Physical cellular QA remains deferred — no iPhone** |
| 18 | No log loss on a drop | **Done** | Local-first write, then a per-repository outbox; `AppContainer.swift:96-102` fans out across six repositories on foreground (`GenesyxApp.swift:58-65`) and on reconnect (`AppContainer.swift:57-59`) |

### 2A — Design (UX)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 19 | Light mode default | **Done** | `PreferencesRepository.swift:103`; mapping `RootView.swift:137-142`; picker `ProfileView.swift:389-395`. Live `profiles.theme` default is `'light'::text`, verified by direct SQL 18 Aug — client and server agree |
| 20 | Egg graphics | **Done** | `egg_female.png` 108 KB, `egg_male.png` 114 KB, `page_background@{1,2,3}x.jpg` (pale ovum crescents), applied app-wide via `gxPageBackground()`. The `BrandEgg` motif itself appears only on the onboarding splash (`OnboardingFlowView.swift:76-79`) |
| 21 | Warm / premium | **Done** | Client-approved 14 Aug (D1) |
| 22 | Less text | **Partial** | Everywhere else is fine. The **pH tab is the one screen still text-dominated**: five always-on prose sections (`PhTrackerSection.swift:369-431`, bodies 150–390 chars via `PhCopy.swift:33,52,56`) plus two permanent caveats (`:143-150`) — eight wrapping blocks on one screen, of which only the safety note collapses |

### 2B / 2C — Nutrition and hydration (UX)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 23 | Simplify the wall of text | **Done** | Three disclosure groups (`NutritionView.swift:172-186`, `:615-637`, `:351-369`). One always-on grey caption survives at `:596-598` |
| 24 | Meal / supplement logging works | **Done** | Chips write straight through (`NutritionView.swift:592-593`); Review Plan `:493`; recipe "log this" `:88-92`. **R2 confirmed landed** — plan and tick-list are one list, so Zinc is loggable and "4 of 4" is reachable |
| 25 | Expanded nutrition | **Partial** | Six food-group chips, recipes with photos (`:378-457`), supplement reminders. Nutrient counting is **absent by deliberate decision** (`:543-548`: "counting nutrients needs claims this app has no substantiation for"), and logging is group-level, not per-dish |
| 26 | Recipes | **Partial — G4 unchanged** | `NutritionView.swift:61-63` still renders `focusFoodsCard` first and `recipesSection` below it. The client asked for recipes to **replace** the text list; they were **added beneath** it. Pure ordering — a two-line change, but a product decision, not a bug |
| 27 | Glasses or ml | **Done** | Unit picker `ProfileView.swift:318-324`; unit-sized quick add `TrackView.swift:1085-1090` |
| 28 | Custom glass size | **Partial** | The setting itself is Done and clamped (`ProfileView.swift:338-365,:382`). But a glasses user correcting **Tuesday** is asked for millilitres (`LogView.swift:409-440`, literal "millilitres" at `:428`), and today's manual-entry field is ml under a glasses readout (`TrackView.swift:946` vs `:992`) |
| 29 | Corrections + progress | **Partial** | Progress and ring render (`TrackView.swift:946-948`, `HomeView.swift:217`). The **target is still a constant** (`GenesyxCore/Tracking/TrackingEngine.swift:82`) with no settings field anywhere, so it is never *her* goal. See §4.3 for the two surviving `2400` literals |

### 2D — Contextual guidance (UX)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 30 | Guidance changes with the cycle stage | **Partial — and this one is visible today** | Per-phase card and slug map exist (`NutritionView.swift:255-305`, `:309-314`), which is R7's fix. But all three non-fallback slugs are date-gated — `fertile-window` 23 Aug, `cervical-mucus` 13 Sep, `sleep-stress-and-your-cycle` 4 Oct — so **on 18 Aug every phase falls back to the same article**, `eating-with-your-cycle`. It self-corrects on 23 Aug |
| 31 | Personalised greeting | **Done** | `HomeView.swift:76-80` (`session.displayName ?? "there"`) |

### 3A — Daily logging streak (engagement)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 32 | Streak counts real logging | **Partial vs the client's list** | Counts water, mood, energy, symptoms, sleep, supplements, food groups, notes and pH (`TrackingEngine.swift:44-47`, `StreakEngine.swift:55-59`). Cycle edits and article reads do **not** count — **descoped by the client on 14 Aug (D3)**, so this is a decision, not a gap. Sexual activity is excluded for Android parity |
| 33 | Milestone celebration, no guilt | **Done** | Overlay above the tab bar so it fires wherever she logged (`MainTabView.swift:46-50`); copy at `NotificationContent.swift:54-72` — "One week strong", "That's all consistency asks" |
| — | Streak restore | **Descoped (D4)** | Not built, correctly. Do not present as done |

### 3B — Weekly education programme (engagement)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 34 | Twelve weekly articles | **Done — but 0 of 12 are readable today** | `LearnContent.swift:727-1112`, w1–w12 on Sundays 2026-08-23 → 2026-11-08. `LearnModels.swift:225` filters on `published(asOf: .today())`. The plan screen lists all twelve with "Arrives …" (`LearnViews.swift:249-263`), so it reads as a schedule rather than an empty screen. First article unlocks in **5 days** |
| 35 | Surfaced without a pop-up | **Done** | Dashboard card (`HomeView.swift:357-395`) + tab badge (`MainTabView.swift:118`); push is opt-in and only requested from the Profile toggle (`NotificationService.swift:110,118-120,153-156`) |

### 4 — Deliberately out of scope

Partner sharing, wearables, home-screen widget, barcode/photo food logging. **All four confirmed out
of 1.2.0 on 14 Aug.** Partner is built but withheld behind a compile-time flag
(`UI/Learn/LearnModels.swift:21`, `FeatureFlags.partnerInvites = false`, honoured at
`ProfileView.swift:59`, `RootView.swift:123`, `AppContainer.swift:91,107`). Widget and barcode were
never built and are guarded by `ReleaseScopeTests`. Do not count these against release completion.

---

## 3. The blocked items — one cause, verified live today

Change-list **1A-5** (fertility relevance) and **1A-8** (website links) are the only two Missing
items, and both wait on the same thing.

I fetched both pages live on **18 Aug 2026**:

| URL | State today |
|---|---|
| `genesyx.co.uk/pages/vaginal-ph-fertility-science` | **Product marketing, not science.** Headings are "Track your vaginal pH at home", "Why pH", "Balance, made visible", "Your reading, decoded in one tap". Gives a range (3.8–5.0) and **zero citations**. The word *fertility* appears in the slug and nowhere in the body |
| `genesyx.co.uk/pages/shettles-method-evidence-limitations` | **Empty placeholder.** One heading, "Medical Evidence", and one line: "Coming soon: detailed information about the medical evidence, current research, and its limitations." No description of the method, no statement that it is unproven, no Wilcox |

This is unchanged in substance from the 14 Aug finding, and it is why **1A-8 must not be closed by
wiring the links anyway**: shipping a "Read the science" button that opens uncited marketing copy is
worse than shipping no button, and a "Medical evidence" button that opens *"Coming soon"* is an
App Store review risk in its own right (Guideline 2.1).

1A-5 is gated on the same page, for a different reason: the in-app copy explaining vaginal pH's
relevance to fertility is a **clinical claim**. It has to be written once, signed off once, and then
appear identically on the page and in the app. Writing it in Swift first means writing it twice and
having the two drift. `docs/CLINICAL_REVIEW_PACK.md` is the forwardable brief for that sign-off.

The in-app Shettles article exists and is honest, but it is **dated 8 Nov 2026**
(`LearnContent.swift:1112`), so it is invisible for the whole of the launch window.

**Owner: content owner + clinician. Not engineering.**

---

## 4. What this pass found that the prior notes had wrong

Recorded because in all three cases the earlier note was wrong in the direction that would have
caused an unnecessary code change.

### 4.1 The "false offline symbol" is already handled — no P0

A prior note read as though a stalled sync repaints `icloud.slash` on a working connection. It does
not. `TrackView.swift:1165-1167` carries the rule explicitly — *"`icloud.slash` is reserved for
actually being offline"* — and a pending row while online renders `icloud.and.arrow.up` instead.
What survives is narrower and honest: a write the **server** rejected stays in `pendingDates`
forever (`DailyLogRepository.swift:158-172`, deliberately, so one poisoned day does not starve every
newer day behind it), so a permanently-rejected day would show a permanent *"waiting to sync"*. That
is true, not false. **Not a P0. No change made.**

### 4.2 `.requiresConnection` reading as offline is correct, not a bug

`Reachability.swift:41` treats only `.satisfied` as online, so an on-demand VPN that has not raised
yet reads offline. That is the right answer — there is no route yet — and it cannot cost a save,
because reachability chooses **wording and retry timing only** and never gates a write
(`Reachability.swift:10-13`). **No change made.**

### 4.3 The two surviving `2400` literals are latent, not live

`InsightsView.swift:14` and `WeeklySummaryView.swift:15` each hardcode `2400` rather than reading
`TrackingEngine.defaultWaterGoalMl`. R5 was recorded as fixed; it was half-fixed. **But there is no
user-configurable water goal anywhere in the app**, so all three values are 2400 today and cannot
diverge in behaviour. It is a maintenance hazard that becomes a real defect the moment item 29 ships
a settings field — which is the same change that would have to touch these lines anyway.
**Deliberately not fixed in isolation**, because a two-line edit that changes nothing a user sees is
not worth invalidating build 20.

---

## 5. Test evidence

| Suite | Result | When |
|---|---|---|
| `swift test` — `GenesyxCore` domain | **294 executed, 0 failures** | 18 Aug 06:12, this tree |
| `xcodebuild test` — app + UI, clean `-derivedDataPath /tmp/dd-b20v` | **431 passed · 0 failed · 0 skipped**, `** TEST SUCCEEDED **`, 1,100 s | 18 Aug 06:14–06:32, this tree |
| Prior full run on the **identical** source tree | 294 domain · 431 total, 430 passed, 0 failed, **1 skipped**, 1,093 s | 17 Aug 22:57–23:15 |
| Release archive + export | Signed 18 MB App Store IPA, `CFBundleVersion 20`, verified by opening it | 17 Aug 23:18 |

Counts are read out of the result bundle
(`/tmp/dd-b20v/Logs/Test/Test-Genesyx-2026.08.18_06-14-03-+0100.xcresult`) with
`xcresulttool get test-results summary`, not scraped from the log tail. Destination iPhone 17 /
iOS 26.5.

**This run closed a standing evidence gap.** Yesterday's run skipped
`NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission`, which throws
`XCTSkip` when iOS notification permission is already determined for the install — and XCUITest
cannot reset that state, because it is not an `XCUIProtectedResource`. Today's clean derived-data
path installed the app fresh, so permission was undetermined and the test **ran and passed**
(confirmed by name in the result bundle, `result: Passed`, not merely by the zero-skip count). The
notification opt-in pre-prompt path is therefore covered by an actual execution for the first time.
Delivery of a reminder on hardware remains unproven and stays on the §7 list.

**The 17 Aug run was already evidence for today's tree**, since `git status --short -- App Sources
project.yml Genesyx.xcodeproj` is empty and `git diff 8df44db HEAD` touches no source file. Re-running
it was not strictly necessary; it was worth doing anyway, because it is what turned a declared skip
into a pass rather than carrying the skip forward on the assumption that it would still skip.

### 5.1 What the tests do and do not prove

They prove the domain logic, the repositories, the routing gate, the content guards and that all
seven tabs render their own screen. They **cannot** prove: cellular behaviour, a Keychain-restored
session across a cold boot, real Sign in with Apple, notification delivery, or the password-reset
email round trip. Every one of those is on the deferred list and none of them may be written up as
passed.

### 5.2 Which "Done" rows are test-proved, and which are code-read-only

The brief's rule was *do not mark an item Done unless code **and tests** prove it*. Being strict
about that splits the 23 Dones in two. Both halves are Done; the second half is Done on a weaker
instrument, and that is worth saying rather than smoothing over.

**Test-proved — a named test would fail if the behaviour regressed:**

| Item | Test |
|---|---|
| 12 · six calendar markers | `DayMarkersTests` — 5 tests, incl. `testEachMarkerStandsOnItsOwn`, `testANoteAloneEarnsTheSymptomsMarker`, `testOrderIsStableRegardlessOfWhichAreAbsent` |
| 10 · private intimacy logging | `DayMarkersTests:20,42` · `MeaningfulLogTests:48-63` (intimacy alone is *not* a meaningful log) · `PersistenceTests:52,66` · `GenesyxUITests:304,357` ("the sheet must not contradict the dot") |
| 15, 16 · gender question | `QuizContentTests.testGenderQuestionCarriesNoUnsupportedClaim`, `testGenderOptionIdsPreserveStoredAnswers`, `testOnlyTheSexPreferenceQuestionIsOptional` |
| Section 4 out-of-scope | `ReleaseScopeTests` — `testTheBuiltAppHasNoCameraOrPhotoLibraryCapability`, `testTheBuiltAppEmbedsNoAppExtensions`, `testTheBuiltAppReadsNoAppleHealthData`, `testNoShippingCopyAdvertisesWidgetOrBarcodeLogging`. These assert against the **built product**, not the source |
| 27, 29 · hydration | `NutritionHydrationTests` (14) + `HydrationInsightTests` |
| 13, 30 · cycle-stage guidance | `RealInsightsTests` (22), incl. the short-cycle ovulation boundaries that R8 fixed |
| 32 · streak | `StreakEngineTests`, `MeaningfulLogTests` |
| 3 · tabs render their own screen | `CustomerWalkthroughUITests` — 10 tests, one distinctive on-screen string per tab |
| Copy compliance across 1A/2B/2D | `PhContentGuardTests.testLearnPhGuidesHaveNoBannedTerms`, `QuizContentTests.testNoBannedPhrasesInQuizContent`, `RealInsightsTests.testNoBannedPhrasesAcrossInsightCopy`, plus the `PhCopy.allSurfaces` scan that replaced a hand-written term list (so copy added later is guarded automatically, which it previously was not) |

**Code-read-only — verified by reading the source at this SHA, with no test that would catch a
regression:** items 1 (pH wording), 2 (pH removed from Nutrition), 6 (the new support copy renders
unconditionally), 17 and 18 (connectivity — the reachability seam is testable but the *badge
selection* is not asserted), 19–21 (theme default, egg assets, warm/premium), 23–24 (Nutrition
disclosures), 31 (personalised greeting), 33 (milestone copy), 35 (Learn surfacing without a
pop-up).

None of these is a candidate for a new test *in this pass*, because adding tests means editing the
project and re-archiving. They are listed so that "Done" is not read as "guarded".

---

## 6. Why this app is not ready for App Store submission

Engineering is not the constraint. Ranked by what actually stops a submission:

### 🔴 Blocking — legal, and the largest exposure in the release

1. **UK GDPR Article 9 lawful basis.** Re-read live on 18 Aug: the published policy is **v2.2, last
   updated 24 July 2026**, controller **Genesyx Ltd (company 16913651)**, and it says in terms —
   *"this is special category data. We process it only with your explicit consent (Article 9(2)(a))"*.
   The app has **no consent step and stores no `consented_at`**, so the basis it publicly claims is
   not evidenced anywhere. Either implement consent (wording, affirmative action, stored timestamp +
   policy version, withdrawal behaviour) or change the policy to the basis actually relied on.
   **Do not invent the wording in code before the decision is supplied.** Owner: legal.

   Two smaller things fell out of the same read, both cheap to fix and neither blocking on its own:
   - The sub-processor list names Supabase, Apple, Google, Shopify and Klaviyo, but the
     transactional email provider is unnamed — **Resend is not disclosed by name**. That is the open
     decision already recorded as "add Resend to the live policy, or move it to the EU region".
   - The policy's controller is **Genesyx Ltd**, while the App Store record will be signed and sold
     by **SF MEDIA & PR LTD** (team `M5L3MM75SG`). A customer comparing the listing to the policy
     sees two company names. Worth reconciling before submission, in the listing copy if not in the
     entity.

### 🔴 Blocking — Apple policy

2. **Sign in with Apple token revocation.** Apple requires apps offering Sign in with Apple to call
   `/auth/revoke` on account deletion. The client half works (revoking under iOS Settings ends the
   local session); the **server call in `delete_account` does not exist**, and `auth.identities`
   shows real Apple accounts in use. Needs the `.p8` into Supabase secrets — **never into a chat or a
   commit** — plus the Edge Function change, a deploy, and an end-to-end test on a disposable Apple
   account. Owner: Apple/Supabase.

3. **"Coming soon" is reachable in the shipping build.** Profile → Current focus → **Pregnancy**
   opens `PregnancyView`, which ends on *"Coming soon — we'll let you know the moment it's ready."*
   (`UI/Pregnancy/PregnancyView.swift:35`, routed from `ProfileView.swift:157`). Guideline 2.1
   rejects placeholder content. **Confirmed in the shipping artefact, not just the source** —
   `strings` over `Payload/Genesyx.app/Genesyx` inside `build/Export/Genesyx.ipa` returns
   `"Coming soon "` and `" we'll let you know the moment it's ready."` (the literal is split around
   its em dash). It is exactly one occurrence, so this is the only such copy in the binary. It is defensible as a roadmap teaser rather than a broken feature, so
   this is a **risk, not a certainty** — but it is the single cheapest thing to remove if you would
   rather not argue it with a reviewer. Removing the segment is a small, contained change. **Not made
   in this pass**, because it invalidates build 20 and is a product call.

### 🔴 Blocking — content and medical

4. **The two website pages** (§3), which block 1A-5 and 1A-8.
5. **The bundled guide PDF is marked internal-use-only (D5)** and has not had its medical review.
   Corrections 1 and 4 closed 17 Aug; **2 and 3 are page-20 artwork sitting with the designer**
   (`docs/FREE_GUIDE_DESIGNER_BRIEF.md`).

### 🔴 Blocking — App Store Connect data entry, none of it started

6. Age rating questionnaire, App Privacy declarations against the app's **real** data flows,
   content-rights / encryption / DSA trader status, and a working privacy-policy and support URL.
7. **Fresh 6.7" screenshots from the release candidate.** The tick in `APP_STORE_SUBMISSION.md` is
   void; `FINAL_APP_STORE_RELEASE_CHECKLIST.md` is the accurate one.
8. **A stable demo account in Review Notes.** The app now gates every private tab behind
   authentication. Without credentials a reviewer sees a sign-in wall and rejects under Guideline
   2.1. `demo@genesyx.co.uk` is nominated in `TESTFLIGHT_B20.md`; the password lives in the password
   manager and must not be written into any file.

### 🟠 Not blocking submission, but unresolved

9. **Custom SMTP is not configured.** Reset and invite emails ride Supabase's built-in sender, which
   is rate-limited and documented as not for production. Survivable for an internal TestFlight group;
   **a blocker before external testers or public release**, and its failure mode looks identical to
   the bug build 20 was cut to fix.
10. **No physical-device pass has ever been run** (§7).
11. **VoiceOver across the stacked tabs is unverified.** All seven tabs are built at once, putting
    343 static texts in the accessibility tree simultaneously. `.accessibilityHidden(true)`
    demonstrably does **not** propagate past each tab's `NavigationStack`, so the app relies on
    `opacity(0)` rather than the explicit guard it appears to have. Sixty seconds on a device settles
    it. Touch routing is correct and asserted.
12. Three orphan/hygiene items in Supabase: delete the two orphan Edge Functions, audit the public
    `learn` storage bucket, enable email confirmation and leaked-password protection.

### ⚪ Decisions the client owes, none blocking

G1 Shettles ships as week 12 · G2 the 12-week plan is anchored to absolute dates (so item 30 above
resolves itself on 23 Aug) · G3 two different numbers are both labelled "streak" · G4 recipes were
added beneath the food list rather than replacing it · plus: add Resend to the live privacy policy,
or move it to the EU region.

**G3 deserves a sentence, because it is customer-visible today.** Home renders
`dailyLog.streak()`, which is **hydration only** (`HomeView.swift:234` → `DailyLogRepository.swift:140-142`).
Insights labels `dailyLogging` as **"Daily streak"** (`InsightsView.swift:220` →
`ConsistencyInsightLogic.swift:60`). Two different numbers, one word, on two screens. Nothing is
wrong with either calculation; the labels are wrong. It is a copy fix, and it is the Partial I would
close first if build 21 is authorised.

---

## 7. Deferred — no physical iPhone, and never to be written up as passed

1. The nine-step password-reset walk, including the second tap on a used link.
2. Staying signed in across a genuine cold boot from a Keychain-restored session.
3. A token revoked on another device ending this session.
4. Sign in with Apple on real hardware.
5. Account deletion end to end with two throwaway accounts.
6. A reminder actually **arriving**. The opt-in pre-prompt and the iOS permission dialog are now
   covered by an automated run (§5); delivery is not, and cannot be from the build machine.
7. Cellular / dead-zone behaviour (item 17).

---

## 8. Verdict

**The 1.2.0 change list is substantially delivered: 23 of 35 verified items Done, 10 Partial, 2
Missing, 0 P0 bugs.** The binary is built, signed, exported and green over the exact tree described
here.

**The app is not ready to submit, and not one of the reasons is Swift.** They are: an unresolved
legal basis for processing health data, a missing Apple revocation call, two website pages that do
not exist, an unapproved PDF, and an App Store Connect record that has never been filled in.

The honest one-line summary is the one already in `LAUNCH_READINESS.md`, and today's work does not
change it: **the app is ready; the submission is not.**

### What I would do next, in order

1. Get the Article 9 decision in writing. Everything else can proceed in parallel; this cannot.
2. Put the `.p8` into Supabase secrets through the authorised route and implement `/auth/revoke`.
3. Commission the two website pages, then close 1A-5 and 1A-8 together in one authored change.
4. Decide the four Partials that are copy or ordering rather than engineering: G3 (streak labels),
   G4 (recipe placement), the Pregnancy "Coming soon" segment, and the pH tab's text density.
5. Only then cut build 21 — one archive carrying all of the above, rather than four archives.

Until step 5, **do not touch `App/` or `Sources/`**. Build 20 is the fallback, and it is currently
uploadable the moment the App Store Connect record is filled in.
