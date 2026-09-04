# Genesyx iOS — To Do List

Written 2026-08-12. Source: status audit against the client change list of 2026-08-10.

---

## READ THIS FIRST

**The live TestFlight build is 1.1.1 (17), cut 29 July from commit `6bc452d`. The change list arrived 10 August. No build carrying any of this work has ever been archived or uploaded.**

Evidence:
- `~/Library/Developer/Xcode/Archives/2026-07-29/Genesyx 1.1.1 (17).xcarchive` is the newest archive. The `2026-07-30` folder is empty. No 1.2.0 (18) archive exists anywhere.
- `docs/HANDOFF.md` §4 task 22: "Ship build 18 to TestFlight | blocked by pre-flight 1–5" (it read "1–3" until 13 Aug, when the table had already grown to five — corrected there and in §3 below).
- `docs/TESTFLIGHT_B18.md` release checklist: P0-2 (commit the working tree), P0-6 (full green regression) and P0-7 (verify live theme default) are all still unticked **in that file**, but P0-6 and P0-7 are both now done — see §3.

**What this means for the statuses below.** The client's rule was: nothing is "Done" unless it is live in the current TestFlight build and verified on a real device. Build 17 predates the entire change list, so under that rule almost nothing on the list can be Done. Where `HANDOFF.md` and `CHANGE_LIST_PLAN.md` say "shipped", they mean **committed** — not shipped. I have marked **Done** only for items genuinely live in build 17.

**Caveat that applies to every Done below:** I have not verified anything on a real device, and there is no device-test evidence anywhere in the repo. Read every Done as "live in 17, device-unverified".

---

## TOMORROW — do these in this order

### 2026-09-04 automated check — no new archive, no new commits, but the working tree has re-diverged from HEAD on five source-related paths

> **CORRECTION, later on 2026-09-04.** The "no new archive" bullet below is **wrong**, and so is
> every "still unshipped" claim that follows from it. `run_archive.sh` writes into the repo's own
> `build/` directory, not `~/Library/Developer/Xcode/Archives/`, so the daily check has been looking
> at a path nothing writes to. `build/Genesyx-1.2.1-b26.xcarchive` has existed since **3 Sep 16:50**
> (`CFBundleShortVersionString 1.2.1`, `CFBundleVersion 26`, `CreationDate Thu Sep 03 16:50:38 GMT
> 2026`), and the owner uploaded it to App Store Connect on 4 Sep. **Build 26 is burned; 27 is the
> next free number.** Any future archive check must inspect `build/` as well, or it will report a
> shipped build as never cut. The Organizer path is stale, not empty-because-idle.

- **No new archive.** `ls -t ~/Library/Developer/Xcode/Archives/` newest folder is still `2026-08-28`, sole entry still `Genesyx-1.2.0-b25.xcarchive`. No `2026-08-29`, `2026-08-30`, `2026-08-31`, `2026-09-01`, `2026-09-02`, `2026-09-03` or `2026-09-04` folders exist. Seven days now since b25 was cut, still unshipped from this workstation. That archive remains both version-stale (`Info.plist` reads `1.2.0`, tree is at `1.2.1`) and commit-stale (predates `a3ae1b1` and `e97e6b4`), for the reasons the 9/03 entry set out.
- **HEAD unchanged.** `git log --oneline -1` returns `e97e6b4 Prepare 1.2.1 build 25 for TestFlight`. No new commits in 48 hours; last two commits (`a3ae1b1`, `e97e6b4`) are both from 9/02.
- **Build config still 1.2.1 (25).** `project.yml` `settings.base` reads `MARKETING_VERSION: "1.2.1"` / `CURRENT_PROJECT_VERSION: "25"`. Unchanged from the 9/03 entry. *(Superseded later the same day: both `project.yml` and `project.pbxproj` now read build **27**, verified from the built product's `CFBundleVersion`, not just the config.)*
- **Working tree has re-diverged from HEAD on five source-related paths — first source-code movement since 9/02.** `git status --short` returns 13 entries — 10 tracked, 3 untracked. Composition has shifted since 9/03: the source tree is no longer clean.
  - Tracked, source-related (5, newly dirty since 9/03): ` M App/Genesyx/Data/App/RootView.swift` (+7/-, 4 line delta), ` M App/Genesyx/UI/Auth/AuthView.swift` (+10 additions, no deletions), ` M App/Genesyx/UI/Onboarding/ConsentView.swift` (+9/-), `A  App/GenesyxUITests/TempPhPlanDemo.swift` (staged, 32 lines, new file), ` M Genesyx.xcodeproj/project.pbxproj` (+8/-, 4 line delta).
  - Tracked, non-source (5, carried over): ` M CHANGES.md` (+100), ` M changes_iOS.md` (+305), ` M graphify-out/cache/last_query_stamp`, ` M ios_launch_checklist.md` (+312), ` M "to do list.md"` (+146).
  - Untracked (3, shorter than 9/03's 8): `.cursor/`, `.ignore`, `.mcp.json`. The five agent-config entries the 9/03 entry listed (`.gemini/`, `.grok/`, `.github/copilot-instructions.md`, `AGENTS.md`, `GEMINI.md`) are no longer in status and are also not in `git status --ignored`, so they have been deleted from disk rather than gitignored.
  - **`TempPhPlanDemo.swift` is flagged by its own name.** The `Temp` prefix reads as a work-in-progress scratch file. It sits under `App/GenesyxUITests/` alongside the two real UI-test bundles (`GenesyxUITests.swift`, `DemoWalkthroughTests.swift`), so a `swift test` or `xcodebuild test` would pick it up. Contents not read — a UI-test scratch file is not itself a launch blocker, but a file named `Temp*` being committed and shipping is the kind of thing that never should. Decide before commit: rename, delete or keep with intent.
    - **Decided 2026-09-04: kept on disk, out of the commit.** Its own docstring reads "TEMPORARY manual-demo test (not committed) … Delete after use", its body ends in `Thread.sleep(forTimeInterval: 60)` — a minute of dead wall clock on a suite already running ~20 minutes — and it asserts a strict subset of `GenesyxUITests.swift:1386`, which additionally proves no Nutrition flash and a correct return to the pH detail. Its four `project.pbxproj` references were removed so the committed project file does not point at an untracked source file, which would break a clean checkout of the UI-test target.
- **Google `-5` fix still in code and still domain-checked, at a different line number again.** `AuthView.swift:271` (not `:261`): `if (error as? GIDSignInError)?.code == .canceled { return }`. The line moved because AuthView.swift is currently dirty with +10 additions above this block. The domain check itself and the comment on `:267` explaining the change are both intact — the uncommitted edit added code near it, not to it. Intent unchanged since 8/22.
- **Supabase held items still committed and clean.** `git status --short supabase/` returns nothing. `supabase/migrations/20260812_partner_invites_write_lockdown.sql` and `supabase/functions/revoke_partner_invite/index.ts` both present and tracked (`ls` confirms both paths exist). Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action — unchanged in essence, but with a new pre-cut condition: the tree must be re-cleaned before a fresh 1.2.1 (25) archive can be cut.** The 9/03 entry named "cut a fresh 1.2.1 (25) archive from HEAD `e97e6b4`, then upload it" as the next action, with the tree at that point clean of source. Today the tree is no longer at HEAD on source paths — three UI source files, the pbxproj and a staged new UI-test file have been changed since HEAD landed. Cutting an archive now would either (a) build from HEAD `e97e6b4` and omit the in-progress edits, or (b) build from the dirty tree and ship uncommitted work under build 25. Both are worse than resolving the divergence first. Three carried-over pre-cut / pre-upload checks:
1. **Decide the fate of the uncommitted source edits before cutting.** Either commit them (in which case build 25 becomes wrong — those edits belong under a fresh build number, since 25 was already pinned by `e97e6b4`), or revert/stash them and cut from `e97e6b4` as the 9/03 plan intended. This is the primary open decision today, and it did not exist on 9/03.
2. **Decide the fate of `App/GenesyxUITests/TempPhPlanDemo.swift`** — rename, delete, or keep with intent. The `Temp` name will get noticed by whoever reads the PR / archive log next; deciding before commit avoids a rename churn commit later.
3. **Re-audit the Profile sub-tabs against the tree that will actually be archived** (the 8/20 afternoon feedback item 4 — Personal Details / Change Password / Health profile / Tracking preferences all reported un-amendable in a submitted build). Carried over from 9/03; still not evidenced closed anywhere in the tree.

Standing rules apply: this task cannot run `xcodebuild` — the archive is a human-initiated step.

Everything below this entry still applies unchanged.

### 2026-09-03 automated check — the tree has moved; the archive on disk is now version-stale as well as commit-stale

- **Two new commits since 8/31.** `git log --oneline 3202ba8..HEAD` returns `a3ae1b1 Bump to build 25 with the release-candidate work` (Wed Sep 2 12:05:02 +0100) and `e97e6b4 Prepare 1.2.1 build 25 for TestFlight` (Wed Sep 2 20:04:42 +0100). HEAD is now `e97e6b4`. First code movement in six days.
- **Version bumped to 1.2.1 (25).** `project.yml` `settings.base` now reads `MARKETING_VERSION: "1.2.1"` / `CURRENT_PROJECT_VERSION: "25"`. The 8/28 archive on disk still reads `1.2.0` / `25` in its own `Info.plist` (`CFBundleShortVersionString=1.2.0`, `CFBundleVersion=25`, `CreationDate=Fri Aug 28 15:56:06 GMT 2026`, signed `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)`). So the pending archive is now **both** version-stale (marketing string bumped) and commit-stale (six days of release-candidate work since it was cut). It cannot be uploaded as 1.2.1 (25); if uploaded, it would be a 1.2.0 (25) that omits everything on `a3ae1b1`.
- **No new archive.** `ls -t ~/Library/Developer/Xcode/Archives/` newest folder is still `2026-08-28`, sole entry still `Genesyx-1.2.0-b25.xcarchive`. No `2026-08-29`, `2026-08-30`, `2026-08-31`, `2026-09-01`, `2026-09-02` or `2026-09-03` folders exist. Six days now since the b25 archive was cut, still unshipped.
- **Release-candidate work in `a3ae1b1` — from the commit message, not fresh inspection.** Per-table incremental sync for daily logs, pH and supplements; rate-limit-aware auth email handling; a fail-open minimum-version gate; and the account-safety fix that stops a rename owed by a replaced account landing on the one that replaced her. Also, quoted verbatim: *"The build number now agrees in both places. project.yml said 24 and the generated pbxproj still said 22, so nothing on disk described build 25 except an archive that matched no commit. Both now read 25."* **This closes the 8/28 carry-over "commit `project.pbxproj` once the client has looked at it"** — the pbxproj is now committed with the 22→25 bump baked in, and the staged UI-test rename that had lived in the working tree since 8/26 landed with it (*"DemoWalkthroughTests.swift moves out of the .xcodeproj bundle and into the App/GenesyxUITests glob, which is what makes it compile and run at all"*).
- **`e97e6b4` — 8 files, +172/-16.** `git show --stat` reports changes to `App/Genesyx/Info.plist` (+4/-0), `App/Genesyx/UI/Auth/AuthView.swift` (+1/-0), `App/Genesyx/UI/Onboarding/OnboardingFlowView.swift` (+1/-0), `App/GenesyxUITests/DemoWalkthroughTests.swift` (+27/-9 test refinement), `Genesyx.xcodeproj/project.pbxproj` (+3/-3), a scheme file (+8/-1), `project.yml` (+5/-5, the 1.2.0→1.2.1 bump plus other config), and a new planning file `bugfix.md` (+121/-0). Contents of `bugfix.md` not read as it is a planning artefact and standing rules limit writes to this file only.
- **Working tree: no source-code files dirty; agent-tool scratch appearing as untracked.** `git status --short` returns 13 entries — 5 tracked (`M CHANGES.md`, `M changes_iOS.md`, `M graphify-out/cache/last_query_stamp`, `M ios_launch_checklist.md`, `M "to do list.md"`) and 8 untracked (`.cursor/`, `.gemini/`, `.grok/`, `.mcp.json`, `.ignore`, `.github/copilot-instructions.md`, `AGENTS.md`, `GEMINI.md`). All 8 untracked are agent-tool config, not code. This is a shorter list than 8/31's 10 tracked entries because `a3ae1b1` folded in the staged UI-test rename + its `project.pbxproj` half, and extended `.gitignore` by 10 lines — the earlier `graphify-out/` noise entries are now presumably ignored rather than cleaned up.
- **Google `-5` fix still in code and still domain-checked, at a different line number.** `AuthView.swift:261` (not `:191`): `if (error as? GIDSignInError)?.code == .canceled { return }`. The line moved because `a3ae1b1` added ~93 lines to `AuthView.swift` (rate-limit-aware auth email handling). Intent unchanged since 8/22 — still `GIDSignInError` domain-scoped, not raw `NSError.code == -5`.
- **Supabase held items still committed and clean.** `git status --short supabase/` returns nothing. `git ls-files supabase/migrations/20260812_partner_invites_write_lockdown.sql supabase/functions/revoke_partner_invite/` returns both paths, tracked. Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action — cut a fresh 1.2.1 (25) archive from HEAD `e97e6b4`, then upload it.** The blocker has shifted, not lifted. Before today it was "upload the 8/28 b25 archive." That archive is now unusable as 1.2.1 (25) — it reads 1.2.0 (25) in its `Info.plist` and predates the release-candidate work in `a3ae1b1`. Uploading it would ship a stale binary under the old marketing string, and would burn build number 25 without the RC work reaching a tester. A new archive must be cut from the current tree. Standing rules apply: this task cannot run `xcodebuild` — the archive is a human-initiated step. Two carried-over pre-cut / pre-upload checks:
1. **`project.pbxproj` commit-cleanliness — DONE.** `a3ae1b1` folded it in (*"Both now read 25"*). No follow-up needed; the tree is clean of the deliberately-uncommitted pair the 8/28–9/01 entries flagged.
2. **Re-audit the Profile sub-tabs against the new tree** (the 8/20 afternoon feedback item 4 — Personal Details / Change Password / Health profile / Tracking preferences all reported un-amendable in a submitted build). `ProfileView.swift` appears in `a3ae1b1`'s stat with +16/-0, but the commit's subject is release-candidate work and there is no evidence in the log that the 8/20 Profile audit was closed. Still open — audit before cutting the next archive, or immediately after against the resulting build.

Everything below this entry still applies unchanged.

### 2026-09-01 automated check — nothing moved in four days

- **No new archive.** `ls -t ~/Library/Developer/Xcode/Archives/` newest folder is still `2026-08-28`, and its sole entry is still `Genesyx-1.2.0-b25.xcarchive` (`Info.plist CreationDate = Fri Aug 28 15:56:06 GMT 2026`). No `2026-08-29`, `2026-08-30`, `2026-08-31` or `2026-09-01` folder exists. Four days now since the b25 archive was cut, still unshipped from this workstation.
- **HEAD unchanged.** `git log --oneline -1` returns `3202ba8 Let her add a food group of her own`, identical to the tip named in the 8/28, 8/31 top entries. No new commits in 96 hours.
- **Working tree identical to 8/31.** `git status --short` returns the same 10 entries the 8/31 entry listed — ` M .gitignore`, the staged UI-test rename + its `MM Genesyx.xcodeproj/project.pbxproj` half, ` M App_Inventory.md`, ` M docs/LAUNCH_READINESS.md`, four `graphify-out/` noise entries, and `MM "to do list.md"`. No source-code files dirty. The client's staged `project.pbxproj` pair remains deliberately uncommitted — do not sweep it without the client's look.
- **Build config still 1.2.0 (24) in `project.yml`,** while the archive on disk is (25). Reconciled in the 8/28 entry (build 25 cut through the local project without committing the 24→25 bump). Nothing new to reconcile today.
- **Google `-5` fix still in code and still domain-checked.** `AuthView.swift:191`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Unchanged since 8/22.
- **Supabase held items still committed and clean.** `git status --short supabase/` returns nothing. `supabase/migrations/20260812_partner_invites_write_lockdown.sql` and `supabase/functions/revoke_partner_invite/index.ts` both present and tracked. Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action — unchanged from 8/31: upload the 8/28 b25 archive to TestFlight.** The blocker has not moved in four days: no upload, no successor archive, no new commits — the b25 binary is still sitting in `~/Library/Developer/Xcode/Archives/2026-08-28/Genesyx-1.2.0-b25.xcarchive` and no tester has seen a post-change-list build cut from *this* workstation. Two carried-over pre-upload checks, both still open, neither answered by anything on this workstation:
1. **Commit `project.pbxproj` once the client has looked at it** — flagged open since 8/28. Not a blocker for uploading the archive already cut, but a blocker for cutting the next one from a clean tree.
2. **Re-audit the Profile sub-tabs against build 25** (the 8/20 afternoon feedback item 4 — Personal Details / Change Password / Health profile / Tracking preferences all reported un-amendable in a submitted build). Nothing since 8/26 touches Profile, so if the defect was in build 24 it is in the b25 archive currently pending upload.

Everything below this entry still applies unchanged.

### 2026-08-31 automated check — nothing moved in three days

- **No new archive.** `ls -t ~/Library/Developer/Xcode/Archives/` newest folder is still `2026-08-28`, and its sole entry is still `Genesyx-1.2.0-b25.xcarchive` — the same archive the 8/28 top entry recorded (`Info.plist` reads `1.2.0` / `25`, `CreationDate = Fri Aug 28 16:56:06 GMT 2026`). No `2026-08-29`, `2026-08-30` or `2026-08-31` folder exists. The b25 archive still sits on disk unshipped — three days now, since 8/28.
- **HEAD unchanged.** `git log --oneline -1` returns `3202ba8 Let her add a food group of her own`, identical to the tip named in the 8/28 top entry. No new commits in 72 hours.
- **Working tree effectively unchanged, one addition.** `git status --short` returns 10 entries — the 9 the 8/27 entry listed, plus ` M .gitignore`. Diff on `.gitignore`: two comment-headed blocks appended, `.codegraph/` and `.claude/` — local agent scratch, not a code signal. Still no source-code files dirty. The staged UI-test rename + its `project.pbxproj` half + this file + the four `graphify-out/` noise entries + `App_Inventory.md` + `docs/LAUNCH_READINESS.md` are all as previously reported. `MM Genesyx.xcodeproj/project.pbxproj` remains the deliberately-uncommitted pair the 8/28 top entry named — do not sweep it without the client's look.
- **Build config still 1.2.0 (24) in `project.yml`,** while the archive on disk is (25). The 8/28 entry already reconciled this: build 25 was cut through the local project without committing the 24→25 bump because doing so would either split or sweep the client's staged 22→24 pair in `project.pbxproj`. Nothing new to reconcile today.
- **Google `-5` fix still in code and still domain-checked.** `AuthView.swift:191`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Unchanged since 8/22.
- **Supabase held items still committed and clean.** `git status --short supabase/` returns nothing. `supabase/migrations/20260812_partner_invites_write_lockdown.sql` and `supabase/functions/revoke_partner_invite/index.ts` both present and tracked (`git ls-files` confirms). Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action — upload the 8/28 b25 archive to TestFlight.** The 8/28 entry recorded "Nothing has been uploaded. The archive stops here by instruction." That instruction is what has not moved in three days: no upload, no successor archive, no new commits — the b25 binary is still sitting in `~/Library/Developer/Xcode/Archives/2026-08-28/Genesyx-1.2.0-b25.xcarchive` and no tester has seen a post-change-list build cut from *this* workstation. Two carried-over pre-upload checks, both still open, neither answered by anything on this workstation:
1. **Commit `project.pbxproj` once the client has looked at it** — flagged open on 8/28. Not a blocker for uploading the archive already cut, but a blocker for cutting the next one from a clean tree.
2. **Re-audit the Profile sub-tabs against build 25** (the 8/20 afternoon feedback item 4 — Personal Details / Change Password / Health profile / Tracking preferences all reported un-amendable in a submitted build). Nothing since 8/26 touches Profile, so if the defect was in build 24 it is in the b25 archive currently pending upload.

Everything below this entry still applies unchanged.

### 2026-08-28 — today's four client items are committed, and build 25 is archived

- **Four commits on `main`, one per client item**, in the order they were reported: `30bbe1e` water Done, `8521dde` custom supplement, `2cd6d95` tappable Nutrition cards, `3202ba8` custom food group. Three files carry changes for more than one item (`LogView.swift`, `TrackView.swift`, `DailyLogRepository.swift`, plus the UI test file), so they were split by hunk rather than committed whole. The split was verified rather than trusted: replaying the four patches from `8518c03` reproduces byte-identical files against the tree the regression ran on.
- **Every commit builds on its own,** checked in a throwaway worktree, so none of them is a bisect trap. The last one needs no separate check: it is the tree the 99-test regression ran on.
- **The client's own staged work was never swept in.** `App_Inventory.md`, `docs/LAUNCH_READINESS.md`, the `graphify-out/` noise, the walkthrough-test rename and this file were all staged before today's work began; the four commits were built through a separate index so none of it could be picked up.
- **Archived: `~/Library/Developer/Xcode/Archives/2026-08-28/Genesyx-1.2.0-b25.xcarchive`.** `** ARCHIVE SUCCEEDED **`, and the archive's own `Info.plist` reads 1.2.0 (25), `com.genesyx.app`, signed `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)`, `get-task-allow = false`. No `aps-environment`, which is correct rather than missing: nothing in the app calls `registerForRemoteNotifications`, so notifications are local only. **This is the first archive of any post-change-list build on this workstation** — the gap that every automated check since 18 Aug has flagged.
- **Nothing has been uploaded.** The archive stops here by instruction.
- **Build 25, not 24, and `project.pbxproj` is deliberately left uncommitted.** That file already carried a staged pair — the moved walkthrough test's registration *and* a 22→24 bump — so committing the bump would have meant either splitting the client's staged change or sweeping it. 25 rather than reusing 24 because there is no way to verify from this machine whether 24 was ever uploaded elsewhere, and a build-number collision costs a whole upload cycle to discover. **Open: commit `project.pbxproj` once the client has looked at it.**

### 2026-08-28 — client request: add your own food group

Client, on the Food groups sheet: "add a section, add your own / custom."

- **What was wrong.** The six chips are the NHS food groups. They describe a British plate and nothing else — there is no chip for fermented food, and no chip for a cuisine the list was not written around. A meal that fitted none of the six could not be recorded at all, so the honest thing to do was leave the day blank, which is exactly the outcome a food log exists to avoid.
- **Fix.** An "Add your own" field on the Food groups sheet, same shape as the supplements one added earlier today. Adding ticks it for the day, and the day is also what keeps it.
- **No new store, and no new sync.** Supplements needed a repository; food groups did not. `DailyLogRepository.customFoodGroups` derives the list from her own history — every group in `logByDate` that this build has no `FoodGroup` case for. Daily logs already sync, so a group named on the phone is offered on the iPad with nothing to keep in step, and one she un-ticks everywhere stops being offered rather than lingering as an entry with no delete button. Storage and sync needed no change at all: `DailyLog.foodGroups` was already `Set<String>` and both `PersistenceDTOs` and `RemoteModels` round-trip arbitrary strings.
- **Custom groups now render everywhere the six do — this is the part that makes the feature true rather than decorative.** Every surface filtered `FoodGroup.allCases`, so a naive "add" would have written the day and then been invisible on every screen including the card directly above the sheet. Four renderers changed: the Nutrition detail Today card (`TrackView.swift`), the Nutrition tab's food log card (`NutritionView.swift`), the Log Today chips (`LogView.swift`) and the day card in log history (`InsightsView.swift`). Each now draws the six, then hers.
- **History was the fourth, and worth naming separately.** `LogHistoryCard` filtered the known cases on the reasoning that an unrecognised token was a newer build's identifier, better hidden than shown raw. Custom groups invert that trade: the tokens are now overwhelmingly names she typed, and hiding one drops her own words from the single screen whose whole job is to give her back what she recorded. It now appends the unknown ones verbatim, sorted, exactly as the supplements row directly above it has always rendered hers.
- **Counts still run against the known six only,** which was already the case and is why "4/6" cannot become "7/6". A custom group counts as *a day she logged food* — it feeds the streak and the "days with food logged" line, because `TrackingEngine` and `StreakEngine` test `!foodGroups.isEmpty` — but it is not scored against the six. The sheet says so in a caption rather than leaving her to infer it.
- **A name that matches one of the six ticks that one instead,** compared against the label she reads as well as the raw value she never sees. Typing "Fruit" would otherwise plant a second permanent chip beside the real one, indistinguishable to her and separate in every count. Existing custom names are matched case-insensitively for the same reason. Capped at 40 characters.
- **Detent changed from `.height(320)` to `[.medium, .large]`.** The list gains a row every few groups she names; a height picked around the original six would crop her own.
- **The caption lives in `FoodLogCopy`, not in the view.** It was written inline first, which is exactly the mistake `NutritionContent.swift:71` warns about — "copy written inline in a SwiftUI body is copy no test scans". Moved to Core and added to `FoodLogCopy.allStrings`, so `testFoodLogCopyMakesNoHealthClaim` now reads it. Proved it does rather than assumed it: putting "boost your fertility and improve egg quality" in that constant fails the guard on four separate terms. Restored, 314 Core tests green. The wording also dropped its em dash on the way, per house style.
- **Covered and falsified.** `testFoodGroupsSheetLogsAndKeepsOneSheNamesHerself` adds "Fermented foods", asserts the chip appears **and reads as logged** (so a build that drew the chip without writing the day fails), asserts the card behind the sheet shows it, crosses to the Nutrition tab and asserts it is offered and ticked there, then opens Insights → My logs and asserts the day's food-groups row carries it. Falsified in all three halves: reverting the card to `FoodGroup.allCases` fails with "the card should show the group she named: TODAY, No entries yet…", dropping the custom chips from the Nutrition tab fails with "a group she named once should be offered on the Nutrition tab too", and reverting the history filter fails with "the day should list its food groups". All restored and green.
- **One assertion was unfalsifiable and had to be rewritten — the lesson, not the bug.** The history check first read `app.staticTexts.containing(label CONTAINS "Fermented foods")`, and it passed *with the fix reverted*. Two causes compounded: `.containing()` filters on an element's **descendants**, and a static text has none; and the Nutrition tab stays alive in the accessibility hierarchy behind a pushed screen, so its own chip satisfied an app-wide query. A green assertion that cannot fail is worse than no assertion, because it is counted as cover. Fixed by giving the row `.accessibilityElement(children: .combine)` and `logHistory.foodGroups`, then asserting on that element's own label. Note for next time: `app.otherElements["logHistory.foodGroups"]` did **not** find a combined `metricRow`; `app.descendants(matching: .any).matching(identifier:)` did.
- **Verified, not assumed.** Screenshot from the running app shows "Fermented foods" ticked, sitting after the six, with the field beneath it.
- **Android parity applies** — same sheet, same fixed six, and the same four renderers to change.

**Full UI regression on the final tree, covering all four of today's fixes.** `-only-testing:GenesyxUITests` on iPhone 17 Pro / iOS 26.5: **99 executed, 1 skipped, 1 failure** in 19m28s. The count is 98 + the new food-groups test, and the one failure is the same environmental one the earlier run hit, not a regression — `DemoWalkthroughTests.testDemoWalkthrough` fails at `DemoWalkthroughTests.swift:49` before the app launches, because `DEMO_PASSWORD` is not exported in the runner environment; it signs into the real demo account and is the only test in the bundle needing a credential. Everything else green, including the four surfaces today's changes share with other features: `todayCard` (Sleep and Symptoms detail sheets), `SupplementsSheet` (now used from two screens), `DailyLogRepository` and `LogHistoryCard`. Core suite re-run on the same tree: **314 tests, 0 failures.** This is the clean run — two earlier attempts were killed rather than reported, because source changed underneath them.

### 2026-08-28 — client request: make the Track → Nutrition cards open what they show

Client, on the Nutrition detail sheet: "would be great if those sections in the Nutrition are clickable and people can see their data, and if they are able to set the goal."

- **Scope, asked and answered.** Two readings were possible and goals are cross-cutting, so I put it to the client rather than picking. Answers: **the Today cards open the editor**, and **tappable only for now — goals deferred**. Settable goals are therefore *not* in this change and remain open work; `TrackingEngine.defaultWaterGoalMl` (2400) is still hard-coded and read in ~16 places including notifications, streaks and the weekly summary, so it is its own piece of work, not a follow-on.
- **What was wrong.** `NutritionDetailView` (`App/Genesyx/UI/Track/TrackView.swift:1423`) reported the day and offered no way to correct it. Noticing a supplement missing there meant leaving for the log sheet and finding the way back. The Sleep detail sheet has carried its editor since it was built, so this was an inconsistency, not a missing feature by design.
- **Fix.** Both "TODAY" cards are now buttons. Supplements opens the same `SupplementsSheet` the log uses (dropped `private` for this); food groups opens a new `FoodGroupsSheet` with the same chips Nutrition shows, writing through the same `toggleFoodGroup`. **Food groups had no card here at all** before — they are half of what the Daily Log records under nutrition and the sheet showed none of it.
- **Presented from this sheet, not by hopping to the Nutrition tab.** Same rule the pH supplement-plan flash was fixed under: a modal that belongs to the task in hand is presented by the screen in hand; a tab change is reserved for the user deliberately going elsewhere.
- **The card reads and writes the stored day, not a local copy.** `todaySupplements` is a `Binding` over `dailyLog`, so the card behind the picker updates as she ticks, and a write the consent gate refuses shows up as the tick reverting rather than as a change that looks saved and is not. New `DailyLogRepository.setSupplements` follows the existing `setWater`/`setSleep` read-modify-write shape, with a no-op guard so re-opening the picker and changing nothing queues no push.
- **`todayCard` gained an optional `action`** and draws a chevron only when it has one — a card that opens something and a card that only reports were otherwise identical. Sleep and Symptoms call sites are unchanged; the parameter defaults to `nil`.
- **Covered and falsified.** `testNutritionDetailTodayCardsEditWhatTheyShow` opens the sheet, asserts each card is a control, ticks Zinc through the supplements picker and Fruit through the chips, and asserts **the card text** changes — the card re-reads the stored day, so it can only say Zinc if the tick was written rather than held in the picker's own copy. Falsified by making the Binding setter a no-op: fails with "the card should show what she just ticked: TODAY, No entries yet…". Restored and green. `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **` on iPhone 17 Pro / iOS 26.5.
- **Verified, not assumed.** Screenshot from the running app shows both Today cards carrying chevrons.
- **Android parity applies** — same sheet, same read-only cards.
- **Still open, deliberately: settable goals.** Client asked; client deferred. Raise it as its own item.

**Full UI regression for all three of today's fixes.** `-only-testing:GenesyxUITests` on iPhone 17 Pro / iOS 26.5: **98 executed, 1 skipped, 1 failure**, and the one failure is environmental rather than a regression — `DemoWalkthroughTests.testDemoWalkthrough` fails at `DemoWalkthroughTests.swift:49` in 0.1s, before the app is launched, because `DEMO_PASSWORD` is not exported in the runner environment; that test signs into the real demo account and is the only test in the bundle that needs a credential. Everything else is green, including the two shared surfaces today's Track change touched: `todayCard` (also used by the Sleep and Symptoms detail sheets, both still passing with the parameter defaulted to `nil`) and `DailyLogRepository`. Run took 19 minutes.

### 2026-08-28 — client report on build 24: two Done buttons on Log Today → Water

Client, editing the water figure: "I got two buttons, one up and another under it — take off the under Done button."

- **Cause.** `WaterSheet` (`App/Genesyx/UI/Log/LogView.swift:424`) carried `.gxKeyboardDoneToolbar()` on the millilitre field *as well as* the confirmation-action Done in its own nav bar. The keyboard toolbar renders directly above the keyboard, so the two Dones stacked one under the other. The screenshot shows exactly that.
- **Fix.** Dropped `.gxKeyboardDoneToolbar()` from the water field only. Nothing else changed. The keyboard Done was redundant here in a way it is not elsewhere: this sheet's toolbar Done both commits the value and dismisses the sheet (keyboard with it), and the sheet rises above the keyboard so that Done is always reachable. The other four users of the modifier are untouched — Log's own notes/symptom fields (`LogView.swift:88`), Track hydration (`TrackView.swift:1000`), Profile (`ProfileView.swift:418`) and pH notes (`PhTrackerSection.swift:583`) all still need it, because their keyboards have no return key out and their save controls sit *under* the keyboard.
- **Covered.** `testLogWaterFieldOffersAKeyboardDismiss` asserted the now-removed behaviour, so it was rewritten rather than deleted: `testLogWaterFieldShowsOnlyTheToolbarDone` raises the keyboard, asserts `keyboardDone` does **not** exist, then taps the nav-bar Done and asserts the sheet closes — so a re-added keyboard toolbar fails, and so does a nav-bar Done that stops committing. Passes on iPhone 17 Pro / iOS 26.5. `** BUILD SUCCEEDED **` on the same destination.
- **Verified, not assumed.** Screenshot taken from the running app with the keyboard up shows a single Done, in the sheet's nav bar.
- **Android parity applies** — same sheet, same duplicated affordance if it was ported.

### 2026-08-28 — client request: log a supplement that is not on the list

Client, on Log Today → Supplements: "I need an option to put any elements — a field where the user puts the supplement as well."

- **What was wrong.** `SupplementsSheet` (`App/Genesyx/UI/Log/LogView.swift:460`) only ever listed the plan's four plus whatever had been added through Nutrition → Review Plan. Anything else she takes could not be logged from the log at all: she had to leave the sheet, cross to Nutrition, add it there, and come back.
- **Fix.** An "Add your own" free-text field and Add button at the foot of the list. Adding does two things: ticks it for today, and keeps it in `SupplementsRepository`, so every later day offers it without her typing it again. Return adds as well as the button. Name capped at `CustomSupplement.nameMaxLength` (60) in the field, matching the server's `char_length(btrim(name)) between 1 and 60` — a longer name would be refused by the database and then retry forever in the pending queue.
- **A name that already exists ticks the existing row** rather than adding a second one. Days store supplements by name, so "magnesium" beside "Magnesium" would be two rows in her list and one indistinguishable pair in every day logged afterwards.
- **The tick does not depend on the keep.** `SupplementsRepository.add` refuses while consent is withdrawn; in that state the log's Save is already disabled and bannered, but if it ever refuses for another reason the day still holds what she typed, because `options` already lists anything selected that the known lists do not carry.
- **No keyboard Done toolbar on this field** — single-line, so it has a return key. See the water fix above for what adding one anyway looks like.
- **Covered and falsified.** `testLogSupplementsSheetLogsAndKeepsOneSheAddsHerself` adds "Magnesium", asserts the Supplements mini-card count goes up by one (the card counts what is ticked; the row merely appearing would prove only that it was written somewhere), then crosses to Track, opens **another** day's log and asserts it is offered there. That second half is checked on a different day deliberately: today's entry carries the name in its own selection, so a same-day re-check could not fail. Falsified both ways — dropping the tick fails the count assertion ("0 is not equal to 1"), dropping the `supplements.add` fails the other-day assertion. Both pass on the fix. `** BUILD SUCCEEDED **`, and screenshotted from the running app with the keyboard up.
- **Also added `log.supplementsCard`** as an accessibility identifier on the mini-card, for the same reason `log.waterCard` has one.
- **Android parity applies** — same sheet, same missing affordance.

### 2026-08-28 automated check — nothing moved

- **No new archive.** `ls -t ~/Library/Developer/Xcode/Archives/` newest folders are unchanged from yesterday: `2026-08-18` (build 22, `Genesyx.xcarchive` + byte-identical `Genesyx 2.xcarchive`), `2026-08-17` (build 19, `Genesyx-1.2.0-b19.xcarchive`). No build 23, 24 or 25 archive on this workstation — same absence yesterday's entry flagged as an open pre-cut question.
- **HEAD unchanged.** `git log --oneline -1` returns `8518c03 Fix pH supplement plan navigation flash`, identical to yesterday. No new commits in 24 hours.
- **Working tree effectively unchanged.** `git status --short` returns 9 entries, same files yesterday's entry listed: the staged UI-test rename (`R  Genesyx.xcodeproj/GenesyxUITests/DemoWalkthroughTests.swift -> App/GenesyxUITests/DemoWalkthroughTests.swift`) + its project-side (`M  Genesyx.xcodeproj/project.pbxproj`), `M  App_Inventory.md`, `M  docs/LAUNCH_READINESS.md`, four `graphify-out/` noise entries, and this file (`MM "to do list.md"` — status flipped from `M` to `MM` because yesterday's edit is now staged and the day-old contents are the unstaged half; not a code signal). Still no source-code files dirty.
- **Build config still 1.2.0 (24).** `project.yml` unchanged: `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "24"`. Next cut still has to be build 25 for the same never-re-use rule yesterday named.
- **Google `-5` fix still in code and still domain-checked.** `AuthView.swift:191`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Unchanged since 8/22.
- **Supabase held items still committed and clean.** `git status --short supabase/` returns nothing. `supabase/migrations/20260812_partner_invites_write_lockdown.sql` and `supabase/functions/revoke_partner_invite/` both present and tracked. Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action — unchanged from yesterday: bump to build 25, cut and upload an archive.** The blocker has not moved in 24 hours: no commits, no archive, no version bump. The two pre-cut checks carried forward from 8/26 and 8/27 are both still open, neither is answered by anything on this workstation today:
1. **Confirm the build 23/24 archive location before cutting build 25.** No local `.xcarchive` for either; check Xcode Organizer / App Store Connect.
2. **Re-audit the Profile sub-tabs against whatever build 25 will carry** (the 8/20 afternoon feedback item 4 — Personal Details / Change Password / Health profile / Tracking preferences all reported un-amendable in a submitted build). Nothing since 8/26 touches Profile, so if the defect was in build 24 it is still in the tree that will become build 25.

Everything below this entry still applies unchanged.

### 2026-08-27 automated check — what moved

- **The pH-flash fix from yesterday is committed.** HEAD is `8518c03 Fix pH supplement plan navigation flash` (Wed Aug 26 09:32:33 2026 +0100), one commit ahead of yesterday's `2cd61d7`. `git show --stat` confirms the commit spans **both** routes flagged yesterday as an open sub-decision — `App/Genesyx/UI/Ph/PhTrackerSection.swift` (+22/-…), `App/Genesyx/UI/Track/TrackView.swift` (+11/…), `App/Genesyx/UI/Nutrition/NutritionView.swift` (+11/…), plus the two UI tests in `App/GenesyxUITests/GenesyxUITests.swift` (+93). A fifth file, `App/Genesyx/UI/Learn/LearnViews.swift` (-4), was not on yesterday's dirty-file list — likely the knock-on from dropping `private` on `SupplementPlanSheet` so `PhTrackerSection` can present it directly. Sub-decision "bundle the Track fix or defer" is settled: **bundled**.
- **No source-code files remain in the working tree.** `git status --short` returns 9 entries, all planning / tooling / staged rename — none source. Staged: `R  Genesyx.xcodeproj/GenesyxUITests/DemoWalkthroughTests.swift -> App/GenesyxUITests/DemoWalkthroughTests.swift` (the test-file relocation carried over from yesterday), `M  Genesyx.xcodeproj/project.pbxproj` (the same rename, project-side), `M  App_Inventory.md`, `M  docs/LAUNCH_READINESS.md`. Noise: `M  graphify-out/.graphify_learning.json`, `M  graphify-out/cache/last_query_stamp`, `A  graphify-out/memory/query_20260826_083047_…md`, `M  graphify-out/reflections/LESSONS.md`, `M  to do list.md`. P0-2 is not fully clean, but the source-code portion is done — the outstanding staged commit is a test-file move + docs, not code work.
- **Build config still 1.2.0 (24).** `project.yml` reads `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "24"`. Unchanged since `cd649f3 Bump to build 24 for the TestFlight cut`. HEAD `8518c03` sits *after* that bump, so the tree is now "post-24 plus one fix" — the next cut has to be **build 25** for the same reason yesterday said so (never re-use a build number that has already been consumed by ASC).
- **Still no local archive for build 23, 24, or 25.** `ls -t ~/Library/Developer/Xcode/Archives/` newest folders: `2026-08-18` (build 22, `Genesyx.xcarchive` and its byte-identical `Genesyx 2.xcarchive`), then `2026-08-17` (build 19, `Genesyx-1.2.0-b19.xcarchive`). Same "archived elsewhere" pattern the 8/20 afternoon and 8/26 entries flagged — do not read absence of a build-24 archive as "build 24 was never cut"; the client tested one. The build 23/24 archive-location question the 8/26 entry raised is **not answered** by anything on this workstation; it remains an open pre-cut check.
- **Google `-5` fix still in code and still domain-checked.** `AuthView.swift:191`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Unchanged from yesterday. Live in every build from 22 onwards.
- **Supabase held items still committed and clean.** `git status --short supabase/` returns nothing. `supabase/migrations/20260812_partner_invites_write_lockdown.sql` and `supabase/functions/revoke_partner_invite/index.ts` both present and tracked. Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action:** bump to build 25, cut and upload an archive. Yesterday's blocker (commit the pH-flash fix) is done. The remaining staged rename + doc churn is not a source-code blocker for a cut, but it should either be folded into the same "prepare build 25" commit or committed on its own before archiving so the archive is cut from a clean tree. Two pre-cut checks carried forward unchanged from 8/26 — both are still valid, neither has been answered locally today:
1. **Confirm the build 23/24 archive location before cutting build 25.** No local `.xcarchive` for either; check Xcode Organizer / App Store Connect before assuming the tester's build 24 exists as a binary reachable from here.
2. **Re-audit the Profile sub-tabs against whatever build 25 will carry** (the 8/20 afternoon feedback item 4 — Personal Details / Change Password / Health profile / Tracking preferences all reported un-amendable in a submitted build). Nothing in the 8/26 or today's commit touches Profile, so if the defect was in build 24 it is still in the tree that will become build 25.

Everything below this entry still applies unchanged.

### 2026-08-26 automated check — what moved

- **Build config still 1.2.0 (24).** `project.yml` reads `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "24"`. Unchanged since `cd649f3 Bump to build 24 for the TestFlight cut`. Build 23 and 24 were both cut in the tree (`8d13921` for 23, `cd649f3` for 24), but **no local archive exists for either** — newest `.xcarchive` on disk is still build 22 from 8/18 (`~/Library/Developer/Xcode/Archives/2026-08-18/Genesyx.xcarchive`, and its byte-identical sibling `Genesyx 2.xcarchive`). Same "archived elsewhere" pattern the 8/20 afternoon entry flagged for build 21 — do not read absence of a build-24 archive as "build 24 was never cut"; the client tested one.
- **One new commit since the 8/26 top entry (below).** HEAD is `2cd61d7 Write the Android parity hand-off for the iOS fixes` — a planning artefact for the same pH-flash + build 23/24 bug run. No code change, no version bump; the pH-flash fix itself is still **uncommitted** in the working tree.
- **Working tree carries the pH-flash fix and nothing else code-substantive.** 10 dirty entries: the fix (`App/Genesyx/UI/Ph/PhTrackerSection.swift`, `App/Genesyx/UI/Nutrition/NutritionView.swift`, `App/Genesyx/UI/Track/TrackView.swift`, `App/GenesyxUITests/GenesyxUITests.swift`), a test-file relocation (`D Genesyx.xcodeproj/GenesyxUITests/DemoWalkthroughTests.swift`, `?? App/GenesyxUITests/DemoWalkthroughTests.swift`, `M Genesyx.xcodeproj/project.pbxproj`), and three noise entries (`App_Inventory.md`, `graphify-out/cache/last_query_stamp`, `to do list.md`). P0-2 is on the edge of un-done — one commit closes it again.
- **Google `-5` fix still in code and still domain-checked.** `AuthView.swift:191`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Committed. Live in every build from 22 onwards.
- **Supabase held items still committed.** `supabase/migrations/20260812_partner_invites_write_lockdown.sql` and `supabase/functions/revoke_partner_invite/index.ts` are both tracked and clean; last touched by `5fd5b18 Capture Article 9 consent and revoke Apple tokens on delete, at build 21`. Production apply/deploy state not probed today (out of scope per standing rules).

**Next blocking action:** commit the pH-flash fix + test-file relocation, bump to build 25, cut and upload an archive. The 8/26 entry below has already reproduced, fixed, covered by test and hand-verified the pH-flash bug in Simulator; the only step between that work and a tester seeing it is the archive. Two open sub-decisions that block *what* to cut, not *whether* to cut:
1. **The Track → pH detail → supplement plan route** (`TrackView.swift:71-75`) still has the same flash. Client did not report it. Bundle the fix or defer — decide before committing the current tree.
2. **Confirm the build 23/24 archive location before cutting build 25.** No local archive for either; either they were cut from another machine or they weren't. Check the Xcode Organizer / ASC before assuming the tester's build 24 exists as a binary anywhere reachable from here — otherwise the pattern the 8/20 afternoon entry warned about (submitting a build no one on this workstation can identify) repeats.

Everything below this entry still applies unchanged.

### 2026-08-26 — client report on build 24: pH → supplement plan flashed Nutrition

Client, having re-tested build 24: everything else runs well; on the pH page, "See your supplement plan" opened the Nutrition page for a second and then opened the plan on top of it.

- **Reproduced and fixed.** The CTA set `router.pendingSupplementPlan = true` then `router.selection = 3`, and `NutritionView` raised the sheet from *its* tab. `MainTabView` keeps every tab alive in a ZStack, so the switch swapped the screen instantly while the sheet took its normal presentation time to animate up — Nutrition was on screen in between. Dismissing then left her on Nutrition, a tab away from the reading she tapped it from. `PhTrackerSection` now owns the presentation: a `showsSupplementPlan` flag decides whether the CTA appears at all, and where it does the section raises `SupplementPlanSheet` from its own `@State`. `SupplementPlanSheet` dropped `private` so it can be reused. Insights (`InsightsView.swift:816`) and the preview still embed the section without the CTA, unchanged.
- **The router flag is gone.** `TabRouter.pendingSupplementPlan` and Nutrition's `.onChange` consumer are both deleted — no route needs them now. Nutrition's own supplement-plan card keeps `planOpen` and its sheet.
- **The Track route is fixed the same way, not relayed.** Track → pH detail sheet → CTA: the section presents the plan *over* the pH sheet, so `TrackView` holds no hand-off state for it and "Got it" hands her back the reading she opened. Learn still leaves through the router, because that one really is a move to another tab.
- **Design rule this sets.** A modal that belongs to the task in hand is presented by the screen in hand; a tab change is reserved for the user deliberately going to another section. Combining the two for one tap is what produced both the flash and the wrong return.
- **Covered and falsified, both routes.** `testPhSupplementPlanOpensWithoutSwitchingToNutrition` (pH tab) and `testTheTrackPhSheetOpensTheSupplementPlanAndReturnsToTheReading` (Track) both assert *hittability*, not presence — inactive tabs and covered sheets stay in the tree, so presence alone would pass on the broken behaviour. Both pass on the fix. Falsified individually: reintroducing the tab hop fails the first ("dismissing the plan should leave her on the pH tab, not on Nutrition"); making the plan's dismissal tear the pH sheet down with it fails the second ("dismissing the plan should leave her back on the pH detail, not on another tab"). Hand-verified in Simulator (iPhone 17 Pro Max, iOS 26.5) on both routes: tap → plan, no Nutrition frame; "Got it" → back where she started, at the same scroll position.
- **Android parity applies** — same CTA, same routing decision.

### 2026-08-20 morning check — what moved

- **Build has moved twice since the 18 Aug entry: 20 → 21 → 22.** `project.yml` now reads `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "22"`. HEAD is `0381449 Correct the documented pH floor to 3.8, matching the signed-off code`, 12 commits ahead of `8df44db` (build 20). The build-20 archive/export the 18 Aug entry was about to upload is now two revisions stale — do not upload it. Build-21 work is captured (`93f5a13 Close the consent_events grant gap and pin the whole tree at build 21`, `5fd5b18 Capture Article 9 consent and revoke Apple tokens on delete, at build 21`, `16fcbaa Replace the July screenshots with seven from the build 21 tree`), build-22 work is `fff30dc Build 22 — make the Article 9 consent gate honest at the surface, plus the Profile fixes`.
- **A build-22 archive exists.** `~/Library/Developer/Xcode/Archives/2026-08-18/Genesyx.xcarchive` — `CFBundleShortVersionString=1.2.0`, `CFBundleVersion=22`, `CreationDate=Tue Aug 18 23:41:01 GMT 2026`. A sibling `Genesyx 2.xcarchive` in the same folder is a byte-identical duplicate (same `CreationDate`) — Xcode appended " 2" because a file named `Genesyx.xcarchive` was already there. Do not upload both; pick one. The build-19 archive from 17 Aug is still on disk (`Genesyx-1.2.0-b19.xcarchive`) and is now two builds stale — same rule as build 20, do not upload it.
- **Working tree still clean.** `git status --short` returns only ` M App_Inventory.md` and ` M graphify-out/cache/last_query_stamp` — both noise, neither is source, and P0-2 remains done.
- **Google `-5` fix still in code and still domain-checked.** `AuthView.swift:191`: `if (error as? GIDSignInError)?.code == .canceled { return }`, matching the Apple path at `:141`. Committed; live for the first time in the archived build-22 tree the moment it reaches a tester.
- **Supabase held items:** neither `supabase/migrations/20260812_partner_invites_write_lockdown.sql` nor `supabase/functions/revoke_partner_invite/` appears in `git status`, so both remain committed. Applied/deployed state on production not probed today (out of scope per standing rules; the 18 Aug entry already recorded `revoke_partner_invite` v1 as DEPLOYED).

**Next blocking action (as written this morning):** upload the build-22 archive to TestFlight. The single fact that has not moved since 29 July is that no build carrying any of this work has ever reached a real tester — an archive on disk is not shipped. Path: `~/Library/Developer/Xcode/Archives/2026-08-18/Genesyx.xcarchive` (build 22), not the `Genesyx-1.2.0-b19.xcarchive` from 17 Aug and not the build-20 IPA the 18 Aug entry named. IPA facts (icon, privacy manifest, entitlements, signing identity) are not re-verified here — the build-22 archive is newer than the last audit and the audit was written for build 20; re-audit before uploading. Everything below this entry still applies unchanged, most importantly the sign-in console-read table at §1: the first thing to do the moment a tester has the binary is reproduce the sign-in flow with the Xcode console attached and read which of the three lines appears.

**Superseded within the same day — see the afternoon block immediately below. A build did reach a tester, feedback landed, and item 4 of that feedback is more urgent than the upload.**

### 2026-08-20 afternoon — TestFlight feedback landed on the submitted build

- **A build DID reach a tester.** User reports the app was **submitted 2026-08-18 at 11:14 PM** (App Store Connect timestamp) and a tester has now run it and returned notes. This is the first tester eyes on any post-17 build since 29 July, and it invalidates the standing claim in this file that "no build carrying any of this work has ever reached a real tester" — replace that framing with "the submitted build has one tester's feedback; it is still not on the wider tester group".
- **Which build was submitted is not verified locally.** No `TESTFLIGHT_B21.md` or `TESTFLIGHT_B22.md` exists, `docs/TESTFLIGHT_B20.md` records no upload for build 20 either, and the build-20 IPA is still sitting in `build/Export/Genesyx.ipa` dated 17 Aug 23:18. The build-22 archive on disk was cut at 23:41 8/18 — 27 minutes *after* the 23:14 submission — so it is almost certainly **not** the submitted binary. Most likely candidate is **build 21** (the commit run `93f5a13` / `5fd5b18` / `9440534` pins the tree at build 21 the same evening, but no build-21 archive is on disk here). Confirm from App Store Connect before writing App Review notes or a `TESTFLIGHT_B21.md` against it.

Client feedback verbatim, mapped to code:

1. **Quiz has no age question, and there is a case for adding one.** Client: "This could surely have an impact on fertility support. Potential to add this question. Especially for knowledge at a later stage for innovation." Add-only change to `Sources/GenesyxCore/Content/QuizContent.swift`; does not touch the "do not rename quiz question ids or option ids" rule at §1C (§1C only bans renames, not additions). Treat as a future personalisation input, not just a demographic field. Android parity applies before release.

2. **Greeting used the wrong name.** The greeting string at `HomeView.swift:98-104` is just "Good morning / afternoon / evening" — no name in it — so the wrong name is coming from `session.displayName`, which the greeting renders at `HomeView.swift:86`: `Text(session.displayName ?? "there")`. `displayName` is populated at sign-up (email + optional typed name) and by the provider on Apple / Google (`AuthView.swift:129-131` for Apple, `:175-177` for Google). Two things to check on the affected account: (a) whether Apple's `fullName` was empty at first sign-in and the fallback wrote the email localpart into `displayName`; (b) whether the account had been signed in with a different provider first and a stale name is stuck. Not a shipped-code bug per se, but a mangled name on the Home screen is a bad first impression.

3. **No mg / dose tracking on supplements.** Confirms the note already in "BUILT BUT DORMANT — Adherence is day-level, not per-supplement": `LogView.swift:21` holds a hardcoded name-only list (Folic acid, Vitamin D, Iron, Omega-3) and `DailyLog.supplements` carries no dose column. Doing this properly is a **data-model change**: add a `dose_mg` (or free-text amount) field to the row, migrate the schema, expose an editor, and only then feed the tracked value into the "recommended daily amount" comparison the client wants. Adding a text field on top of a name-keyed record without changing the model collects mg values that no other part of the app can read — do not scope this as "add a text field".

4. **Profile tab — none of the sub-tabs let her amend anything.** Client: "Personal details tab, change password, health profile, and tracking preference on profile — You cannot amend any details on this tab." This **provably contradicts §1B row "Password change | Done | `SupabaseBackend.swift:49`"**. The row wiring exists — `ProfileView.swift:197` opens Personal Details, `:199` opens the Change Password sheet at `:808-839`, the backend call `resetPasswordForEmail` at `SupabaseBackend.swift:49` exists — and yet the tester cannot change the password on the shipped build. Root-cause candidates in decreasing order of likelihood: (a) the sheet fields are read-only or not bound to state, (b) the Save / Submit button no-ops, (c) the backend call errors and the sheet swallows it silently. Same class of miss as §1C "Waitlist capture" (`joinWaitlist` implemented, no call site): the tracker has been marking backend readiness as feature completeness, and this feedback proves the cost. **Re-audit all four Profile sub-tabs** (Personal Details, Change password, Health profile, Tracking preferences) against the submitted build before the next upload — do not assume the fault is only in Change password.

**Revised next blocking action:** the morning block said "upload build-22 to TestFlight." That is still true eventually, but item 4 above is more urgent: a Profile that does not save is a shipped regression against what the tracker calls Done, and one tester has already seen it. Do not ship build 22 with the same defect. Priorities, in order:
1. Confirm from App Store Connect which build was submitted 8/18 23:14 (no local evidence exists — check the Xcode Organizer or ASC directly)
2. Reproduce item 4 on that same commit in Simulator, identify which of the three candidates above is the actual break
3. Fix item 4 — fold into build 22 if the archive has the same defect, or cut build 23 if 22 is already uploaded and shares it
4. Only then queue the next upload
Items 1, 2 and 3 from the feedback list are the amendment queue *after* the fix build ships; they are not blockers for it.

**Do not edit the §1B "Password change | Done" row until item 4 is reproduced.** It is provably wrong to the tester, but the exact defect is not yet known from the code, and rewriting the row before the audit would replace one wrong statement with another. Same rule applies to any other §1B row the Profile audit touches — mark stale in place once reproduced, then correct with evidence.

### 2026-08-17 morning check — what moved

- **No new archive.** Newest is still `Genesyx 1.1.1 (17).xcarchive` (2026-07-29); the `2026-07-30` folder is empty. TestFlight is unchanged from 2026-07-29. **This is the single fact that has not moved and it is the one that must.**
- **P0-2 done — working tree is clean.** `git status --short` returns only `?? docs/assets/` once the `graphify-out/` cache noise is filtered out. All ~40 files from the baseline are committed.
- **Version bumped as planned.** `project.yml` now reads `MARKETING_VERSION: "1.2.0"` / `CURRENT_PROJECT_VERSION: "19"`. HEAD is `fb37e2a release: prepare Genesyx 1.2.0 build 19`.
- **26 new commits since baseline `2e07f1f`.** Notable: `c9aa8ba Withhold partner linking from the 1.2.0 build` (release scope narrowed — the lockdown/deploy order for partner_invites is no longer racing this build), `4ff918b` (password reset via the gate), `d554541` (session ended on Sign-in-with-Apple revoke), `308b8ca` (account deletion stops reporting false success), `07bb619` + `d0b3895` (privacy policy declared).
- **Google `-5` fix is in code**, not just claimed. `AuthView.swift:181-185`: `if (error as? GIDSignInError)?.code == .canceled { return }`. Committed. Not in any shipped build.
- **Supabase held items are committed** — `supabase/migrations/20260812_partner_invites_write_lockdown.sql` in `2e07f1f`, `supabase/functions/revoke_partner_invite/` in `6000f2d`. Applied/deployed state on production was not probed today (out of scope per standing rules).

**Next blocking action (updated 18 Aug 00:05):** upload `build/Export/Genesyx.ipa` to TestFlight. HEAD `8df44db` (1.2.0 **build 20**) is **archived and exported** — signed `Apple Distribution: SF MEDIA & PR LTD`, IPA contents verified (version, privacy manifest, 1024 icon, entitlements); facts and the two archive traps are in `docs/TESTFLIGHT_B20.md` under "Build facts". Build 19 (`fb37e2a`) was superseded the same day by the password recovery flow (`eded1c7`) and the build bump; do not upload 19. The full green regression is **done** on the build-20 tree — 294 domain (`swift test`) and 430/431 `xcodebuild test` on iPhone 17, 0 failures, 1 declared skip. The Supabase Google **Authorized Client IDs** question is **settled** — the iOS client is present, see section 1. P0-7 is **closed** — the live `profiles.theme` default is `'light'::text`, matching the client, verified by direct SQL (§3). What remains is the upload itself and the App Store Connect listing (screenshots, privacy labels, age rating — never audited). Sign-in per the 30-second console-read table below is still the gating verification the moment a build reaches a device.

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

**Do NOT gate the `[GoogleSignIn]` / `[AppleSignIn]` `print`s behind `#if DEBUG`.** A pre-submission
review flagged them as un-gated in Release, and `AuthView.swift:169` does print her email address.
Leave them. TestFlight builds *are* Release, so gating them would delete the console-read table
above — the only diagnostic that exists for the sign-in question, on the only build type that
reaches a real phone. The exposure is small and bounded: Swift `print` writes to stdout, which is
not routed into the unified log for a store build, so nothing is persisted on device or collected
by a sysdiagnose; it is visible only to someone with the phone attached to Xcode or Console.app.
The right fix, **once sign-in is confirmed working on hardware and the table is spent**, is to drop
the `email=` interpolation from `:169` and gate the remaining four stage markers. Doing it before
then trades a real diagnostic for a theoretical leak, and would invalidate the verified build-20
archive for a change no reviewer will ever see.

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
2. `join_waitlist` RPC + `waitlist_emails` table — table ✅ **exists in production** (18 Aug probe).
   The RPC itself was not called, because calling it would insert a row into the live table; that
   one is still unconfirmed. Moot for 1.2.0 either way — nothing in the app calls `joinWaitlist`,
   so there is no path to the RPC from a shipped build (see the 1C row in the checklist)
3. `daily_logs.food_groups` column — ✅ **APPLIED 13 Aug**. Was missing; meal logging was failing
   silently (she ticks groups all week, sees them persist locally, syncs none of it). Now
   `ARRAY / NO / '{}'::text[]`, matching `symptoms` and `supplements`. RLS re-checked: unchanged
4. Deploy all six Edge Functions — ✅ **DEPLOYED 13 Aug**. Note this **turned `verify_jwt` ON**:
   there is no `config.toml`, so the CLI default of `true` applied. Confirmed by probe — all six now
   answer an anonymous POST from the gateway, not from their own catch block
5. `profiles.theme` live default — ✅ **RESOLVED 18 Aug**, P0-7 (this is what the old "3" meant). The
   live column default is `'light'::text`, which is the same product default the client falls back to
   (`RepositoryTests.swift:451`, `:1367`). No decision left to take; see the direct-SQL audit below.

**Whole-schema probe against production, 18 Aug — no drift.** Every table and column the iOS client
reads or writes exists live. Method: an unauthenticated `GET /rest/v1/<table>?select=<column>&limit=0`
with the publishable anon key returns no rows and distinguishes the two cases cleanly —
`400 / 42703` means the column does not exist, `401 / 42501` means it exists and the grant correctly
denies `anon`. Every probe returned `42501`:
- `daily_logs` — all eleven: `user_id date mood energy symptoms sleep_minutes water_ml supplements notes sexual_activity food_groups`
- `ph_readings` — all eight: `id user_id ph_value recorded_at notes updated_at deleted_at measurement_type`
- `profiles` (`id theme display_name`), plus `cycle_settings`, `user_supplements`, `quiz_answers`,
  `partner_invites`, `waitlist_emails` all present
That also confirms **no table is readable by `anon`**, which is the property that matters for a build
carrying vaginal-pH and sexual-activity rows. Re-run the probe after any migration; it is read-only,
returns no user data, and takes seconds.

**Password-recovery redirect — ✅ confirmed 18 Aug.** `DeepLink.swift:72` warns that
`genesyx://reset-password` must be on the Supabase Auth *Redirect URLs* allow-list or `redirect_to`
is discarded server-side and the email silently falls back to the Site URL, which is the entire bug
build 20 exists to fix. The allow-list holds three entries and it is there:
`https://genesyx.co.uk/**`, `genesyx://`, `genesyx://reset-password`. The server half of password
recovery is therefore correct; what is still unproven is the nine-step walk on hardware.

**Pre-submission security review, 18 Aug — no blockers.** All 16 migrations, all 6 edge functions
and 125 Swift files read. Clean: no analytics or tracking SDK of any kind (only supabase-swift and
GoogleSignIn); no health data in any log call, URL or shared container; no committed secrets; all
nine user tables RLS-on with owner-only `auth.uid()` policies on both `using` and `with check`;
every edge function resolves the caller from the JWT and none trusts a user id from the request
body; no `try!`, `fatalError` or force casts, and the `Phase` force-unwraps are total over all four
cases. `delete_account` removes all nine tables then the auth user last, checking each result, so a
partial failure leaves the account retryable rather than returning a false success.

One NOTE carried forward, **not blocking and not reachable from this binary**:
`supabase/functions/delete_account/index.ts:44` unlinks the partner unconditionally, where
`unlink_partner/index.ts:39-41` deliberately adds `.eq("partner_id", user.id)`. On an asymmetric
link that severs the wrong row. Unreachable while `FeatureFlags.partnerInvites` is `false`, and
`accept_partner_invite:69-74` now prevents asymmetric links, but **Android shares this database**,
so fix it there before Android ships partner linking again.

**Direct-SQL audit against production, 18 Aug — the RLS gap is now closed.** The anon-key probe above
proves a column exists and that `anon` cannot read it, but it can say nothing about the *policies*,
because those were created by hand in the dashboard and appear in no migration file. Run as `postgres`
in the dashboard SQL Editor, read-only, no writes:
- **RLS is on for all 9 public tables**, none off: `cycle_settings daily_logs genesyx_products
  partner_invites ph_readings profiles quiz_answers user_supplements waitlist_emails`.
- **Every policy is owner-scoped and none is granted to `anon` or `public`.** Counting policies whose
  `qual` + `with_check` does not mention `auth.uid()` returns 0 for all eight user tables
  (`profiles` has 3 policies, the rest 1 each). The single exception is deliberate:
  `genesyx_products` has one `SELECT` policy, roles `{authenticated}`, `qual = true` — a read-only
  catalogue for signed-in users, still closed to `anon`.
- **`waitlist_emails` has RLS on and zero policies**, so no client role can touch it directly at all.
  Writes only reach it through `join_waitlist`, which is `SECURITY DEFINER` with `search_path=public`
  explicitly pinned (not the unset variant Supabase's linter flags).
- **`partner_invites` grants:** `anon` = none; `authenticated` = `INSERT, SELECT, REFERENCES,
  TRIGGER` — no `UPDATE`, no `DELETE`. Belt and braces on top of `FeatureFlags.partnerInvites=false`.
- **`profiles.theme` default is `'light'::text`.** Live distribution over 18 rows: `light=8 dark=8
  system=2`. The two `system` rows are exactly the case the one-time migration handles
  (`migrateLegacySystemTheme()`, tests `RepositoryTests.swift:1191`, `:1245`) — a user who never
  chose `.system` is corrected to `.light` on next launch, and one who chooses it herself keeps it.
  That closes P0-7 with data rather than a guess.
- **The migration ledger is empty.** `supabase_migrations.schema_migrations` does not exist (`42P01`),
  and `supabase migration list --linked` reports a blank `remote` for all 16 local files. Production
  was built by hand in the dashboard, so **the migrations directory is not the source of truth for
  what is live** — treat the database as authoritative and the files as history. Not a launch
  blocker: the schema itself was verified column-by-column above.

Apply through the dashboard **SQL Editor**. There is no `supabase db query` subcommand — CLI 2.109.1 offers only `diff dump push pull reset lint` under `db`, and `dump` needs Docker, which is not installed here. **Never `supabase db push`** — confirmed 18 Aug that this project has no `supabase_migrations.schema_migrations` table, so push would replay all 16 migrations against a schema that already has them.

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
| Theme (light/dark/system) | **Done** | `PreferencesRepository.swift:102`. The client-side override bug is fixed and tested (see the two-week plan, item 7). P0-7 closed 18 Aug: the live `profiles.theme` default is `'light'::text`, matching the client's own fallback |
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
7. ~~Theme-override bug~~ — **fixed in code.** `clearThemeMigrationFlag()` (`PreferencesRepository.swift:169-171`) is called on sign-out (`AppContainer.swift:131`), and `migrateLegacySystemTheme()` runs after `apply(remote:)` (`:200-201`, `:213-218`) so the pulled `.system` is corrected rather than left standing. Tests: `RepositoryTests.swift:1185`, `:1200`, `:1212`, `:1231`. The separate P0-7 question on the **live** `profiles.theme` default is now answered too — the column default is `'light'::text` and the two production rows still holding `system` are precisely what `migrateLegacySystemTheme()` corrects
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
