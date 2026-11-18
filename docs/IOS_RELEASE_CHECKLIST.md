# Genesyx iOS: release checklist

| | |
|---|---|
| **Audit date** | 2026-10-07 |
| **Project root** | `/Users/lucasvalenca_sf/genesxy_apple.V1.02` |
| **App version** | 1.2.3 |
| **Build** | 31 (HEAD `353ff26`, branch `main`) |
| **Scope** | The practical, ordered procedure for getting an iOS build of Genesyx from this checkout into App Store review and watching it afterwards. It is written for this app (XcodeGen project, manual distribution signing, a local `run_archive.sh`, Supabase backend), not as a generic iOS checklist. Android is out of scope. |

Tick each box as you go. A line that begins **STOP** means do not continue until it is resolved. Commands are run from the project root unless stated. Companion document: `docs/QA_TEST_MATRIX.md` (row IDs such as C1 or J6 below refer to it).

## Where things stand today

| Fact | Value | Evidence |
|---|---|---|
| Live on the App Store | **1.2.2** | repo records; Needs dashboard verification |
| Repo and archive | **1.2.3, build 31**, commit `353ff26` (committed 11:47 on 30 September; archived and uploaded within minutes) | `project.yml:84,130`; `git log` |
| Build 31 uploaded | **Yes**: 2026-09-30T10:49:48Z, state `success`, no errors | `Distributions` array in `build/Genesyx-1.2.3-b31.xcarchive/Info.plist` |
| 1.2.3 version record in App Store Connect | **None exists** | 7 October review; Needs dashboard verification, it moves |
| Submitted for review | **No** | same |
| Verdict | **TestFlight ready; App Store review not ready.** The one item that moves it: prove the App Review demo account still signs in (QA matrix **C1**). | `docs/QA_TEST_MATRIX.md` |

So there are two honest paths:

- **Path A, ship build 31 as it is.** Build 31 is already at Apple. Do **not** archive or upload again. Do section 1 (to confirm HEAD is still the archived commit), run the device gate in 2.8, then go straight to section 5.
- **Path B, a code change is needed.** The new build needs a number above every build ever uploaded (read TestFlight; as of 30 September the next free number was 32, but never infer it from the repo). Do every section in order.

> ### Common mistakes on this project
>
> Each of these has cost a build or a false report.
>
> 1. **Version drift.** `project.yml` and `Genesyx.xcodeproj/project.pbxproj` both hold the version and build, and nothing checks that they agree. `run_archive.sh` archives the committed project and **never runs `xcodegen`**, so the pbxproj wins locally, while a later `xcodegen generate` silently imposes the yml value. It has produced bad cuts (yml 24 against pbxproj 22; yml 25 against pbxproj 26). Run check 1.5 before every archive.
> 2. **Looking in the wrong archive directory.** `run_archive.sh` writes `build/Archives/Genesyx.xcarchive` inside the repo (and deletes the previous one), a direct cut lives in `build/`, and Xcode's own Organizer folder `~/Library/Developer/Xcode/Archives/` holds only what Xcode saved (the newest there are b27 and b28, 4 September). More live on `~/Desktop`. Look in all three. Build 30, the live 1.2.2 binary, has an archive in none of them.
> 3. **Concluding "not uploaded" from missing artefacts.** An export with `destination: upload` writes **no** `.ipa`, no `DistributionSummary.plist` and no copy of the options file. The automated check in `to do list.md` looks for exactly those files, so 18 consecutive daily entries since 10 September wrongly reported "no upload trail" for a build that had been uploaded on 30 September. The proof of upload is the archive's own `Info.plist` (step 4.4).
> 4. **`delete-account` against `delete_account`.** One character. The app calls `delete_account` with an underscore (`App/Genesyx/Data/Remote/SupabaseBackend.swift:58`), the live function that performs every GDPR deletion. A hyphenated `delete-account` orphan, which erased a user with no Apple revoke, was deleted from production on 2026-10-07. Never type `supabase functions deploy delete-account` and never restore from `docs/archive/edge-functions-orphans/`.
> 5. **The wrong test target.** The unit tests live in a folder called `GenesyxTests` but the target is `GenesyxAppTests`. `-only-testing:GenesyxTests` fails with exit 70.
> 6. **Exporting with the tracked `ExportOptions.plist`.** It has no `destination` key, so `xcodebuild -exportArchive` defaults to *export*: it writes a signed `.ipa`, uploads nothing and exits 0, which looks exactly like success (`docs/LAUNCH_READINESS.md:170`).
> 7. **Inferring the next build number from the repo.** That has been wrong twice. Read the TestFlight build list.
> 8. **Giving the test runner the review account's password.** `DEMO_PASSWORD` makes `testDemoWalkthrough` sign in to production and edit that account. Use a separate QA account through `DEMO_EMAIL`.
> 9. **Switching on Associated Domains.** It makes `xcodebuild archive` fail, because the "Genesyx App Store" profile lacks the capability. The block in `Genesyx.entitlements` is commented out on purpose.
> 10. **Trusting a green suite to mean the app builds for release.** Build 18 was unarchivable for days while every test passed (an `#if DEBUG` around an import). Step 2.1 compiles Release.

---

## 1. Pre-flight (repo state)

- [ ] **1.1 Right folder.** `pwd` prints `/Users/lucasvalenca_sf/genesxy_apple.V1.02`. This is the active release checkout. The clone under `Genesxy Apps/genesyx-ios` and the other copies are stale and blind to unpushed commits; never cut from them. `run_archive.sh` hard-codes this path on its second line.
- [ ] **1.2 Branch and commit.**
  ```bash
  git branch --show-current         # main
  git rev-parse --short HEAD        # 353ff26 for path A
  git log origin/main..HEAD --oneline | wc -l   # 5 unpushed on 7 October
  ```
  Path A: HEAD must still be `353ff26`. Path B: HEAD is the commit that carries your version bump. Push the commit and the tag (3.5) before you submit, so the binary at Apple maps to a commit on the remote.
- [ ] **1.3 Tracked tree is clean.** An archive builds the **working tree**, not HEAD, so an uncommitted edit ships.
  ```bash
  git status --short -- App Sources Package.swift project.yml Genesyx.xcodeproj
  ```
  Expected: nothing, apart from the untracked file in 1.4. Known noise you can ignore: `graphify-out/cache/last_query_stamp` (changes on every query) and `to do list.md` (the owner's notes). **STOP** on any modified file under `App`, `Sources`, `project.yml` or `Genesyx.xcodeproj`: commit it deliberately (stage by explicit path, never `git add -A`) or revert it.
- [ ] **1.4 Untracked-file sweep.** `git status --short | grep '^??'`. Decide each; do not delete anything you did not create without asking its owner.

  | File | What to do |
  |---|---|
  | `App/GenesyxUITests/TempPhPlanDemo.swift` | **Delete it, or commit it on purpose, before any `xcodegen generate`.** It is a manual demo test whose last statement is `Thread.sleep(forTimeInterval: 60)` (line 30), and its own header says "Delete after use". The UI target's sources are the whole folder `App/GenesyxUITests` (`project.yml:166-170`), so the next `xcodegen generate` pulls it in: a silent extra minute and an extra test in every UI run, and a regenerated project that makes it permanent if committed. |
  | `AGENTS.md` (project root) | Untracked, so the project's own agent instructions are not in version control. It does not ship (the app target compiles only `App/Genesyx`, `project.yml:19-38`), but commit it deliberately or leave it out deliberately. |
  | `.cursor/`, `.ignore` | Tooling. Ignore. |
  | `docs/*.md` new review documents | Commit separately from the release commit, never inside it. |
  | `docs/appstore_screenshots_build30/` and `docs/Genesyx-AppStore-Screenshots-Build30.zip` | Labelled build 30 while the release is 31. See 5.5. |

  Confirm nothing untracked sits under the app target: `git status --short App/Genesyx` prints nothing.
- [ ] **1.5 Version agreement.** Both files must say the same thing.
  ```bash
  grep -nE '^\s+(MARKETING_VERSION|CURRENT_PROJECT_VERSION):' project.yml
  # 84:        MARKETING_VERSION: "1.2.3"
  # 130:        CURRENT_PROJECT_VERSION: "31"
  grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION' Genesyx.xcodeproj/project.pbxproj | sed 's/^[[:space:]]*//' | sort | uniq -c
  #    2 CURRENT_PROJECT_VERSION = 31;
  #    2 MARKETING_VERSION = 1.2.3;
  ```
  (The pbxproj holds each value twice, Debug and Release of the `Genesyx` target.) Output above is what it printed on 7 October. **STOP** if they disagree. Change both in one commit.
- [ ] **1.6 The build number is new.** It must exceed every build ever uploaded to App Store Connect, including ones uploaded by hand; the comment block at `project.yml:79-130` is a ledger of burned numbers. Read App Store Connect, TestFlight, the build list. A marketing version whose train is closed accepts no new builds (the 1.2.0 and 1.2.1 trains closed, errors 90186 and 90062); 1.2.3 is the first open train.
- [ ] **1.7 `xcodegen generate` only if you need it** (you edited `project.yml`, or added or removed files outside Xcode). It is not run by `run_archive.sh`.
  ```bash
  xcodegen generate
  git diff --stat Genesyx.xcodeproj
  git diff Genesyx.xcodeproj | grep -c TempPhPlanDemo     # must print 0
  ```
  Then repeat 1.5. A regeneration reproduces the committed project except for the temp test (until it is dealt with) and, if the folder name differs, three object-ID lines.
- [ ] **1.8 Static hygiene checks.** Each should print what is shown.
  ```bash
  git log --all --oneline -- Secrets.xcconfig | wc -l          # 0: never committed on any branch
  git check-ignore -v Secrets.xcconfig                         # .gitignore:21
  grep -rnE 'eyJ[A-Za-z0-9_-]{20,}' App Sources | wc -l        # 0: no JWT-shaped literal
  grep -rn 'http://' App Sources --include='*.swift'           # nothing
  grep -rniE 'localhost|staging|127\.0\.0\.1' App/Genesyx Sources --include='*.swift'   # nothing
  grep -rn 'print(' App/Genesyx Sources --include='*.swift' | wc -l   # 10, every one inside #if DEBUG
  ```
  The ten `print(` sites are `AuthView.swift:207,214,245,258,266`, `SupplementsRepository.swift:128`, `DailyLogRepository.swift:219`, `PhRepository.swift:118` and `AppContainer.swift:91,95`. A new one outside `#if DEBUG` is a leak into Release. Never print or paste a Supabase key, a demo credential or an Apple key anywhere.
- [ ] **1.9 Entitlements, manifest, export compliance.** `App/Genesyx/Genesyx.entitlements` holds only Sign in with Apple, and the Associated Domains block is still commented out. `App/Genesyx/Resources/PrivacyInfo.xcprivacy` exists. `ITSAppUsesNonExemptEncryption: false` is set (`project.yml:64`), so App Store Connect will not ask the export-compliance question.

## 2. Build and test gate

Run from the project root, on a quiet machine. For a result you can defend, run from a clean export so your working tree cannot colour it:
```bash
D=$(mktemp -d) && git archive HEAD | tar -x -C "$D" && cd "$D"
# add -derivedDataPath "$D/dd" to the xcodebuild commands below
```

- [ ] **2.1 Compile Release without signing.** This is the check a green test suite cannot give you.
  ```bash
  xcodebuild build -project Genesyx.xcodeproj -scheme Genesyx -configuration Release \
    -destination 'generic/platform=iOS' -onlyUsePackageVersionsFromResolvedFile \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
  ```
  Expected: `** BUILD SUCCEEDED **` with exactly one warning, `appintentsmetadataprocessor ... No AppIntents.framework dependency found` (benign), and zero Swift compiler warnings. On 7 October a Release build for `generic/platform=iOS` succeeded; the exact signing flags that run used were not recorded, so the flags above are the standard unsigned compile check, not a copy of that run.
- [ ] **2.2 Core suite.** `swift test` runs on macOS, no simulator. Expected: `Executed 314 tests, with 0 failures`.
- [ ] **2.3 App unit suite.** The target is `GenesyxAppTests`.
  ```bash
  xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:GenesyxAppTests
  ```
  Expected: `Executed 405 tests, with 0 failures` (about 45 seconds once built; the earlier figure of 395 is out of date). The banned-phrase and content-guard tests are in this suite. If one fails, **do not relax it**: they enforce the Guideline 1.4.1 position and loosening them is a compliance decision.
- [ ] **2.4 UI suite on iPhone 17.** About 23 minutes. `env -u` guarantees the production walkthrough cannot sign in.
  ```bash
  env -u DEMO_PASSWORD -u DEMO_EMAIL xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:GenesyxUITests
  ```
  Reds you should expect (see the QA matrix, "Run record and known failures"):

  | Test | Why | Action |
  |---|---|---|
  | `DemoWalkthroughTests.testDemoWalkthrough` | `DEMO_PASSWORD` is not set; fails at `DemoWalkthroughTests.swift:57` | Expected red. Leave it. |
  | `LifecycleE2ETests.testSignOutDoesNotBlankMedicalSources` | iOS "Save Password?" sheet covers the re-asked consent screen; reproduced 3 of 3 on 7 October | Expected red until the test gets an interruption monitor. |
  | `AuthGateUITests.testMandatorySignInOffersPasswordRecovery` | Occasional order or load flake | If red in the full run, re-run it alone; it passes alone. |
  | `GenesyxUITests.testAnAlreadyLoggedPastDayCanBeCorrectedWithoutLosingWhatWasThere` | Date dependent: fails on the **1st to 3rd** of a month | Not a regression on those dates. |
  | `NotificationFlowUITests.testTurningOnRemindersExplainsFirstThenAsksPermission` | Skips if the install already answered the permission prompt | Run `xcrun simctl uninstall booted com.genesyx.app`, then run it alone. |

  **STOP on any other red.** A different red is yours until proved otherwise.
- [ ] **2.5 UI suite on iPhone 17e.** Same command with `name=iPhone 17e`. The small screen has exposed a real defect the larger device hid (a hydration tap target, fixed in `d3e7724`), so a failure that appears only here is a candidate defect, not a quirk.
- [ ] **2.6 Leave the simulators as you found them.** If you installed a falsification build, reinstall the real one, so the next person does not read it as a regression.
- [ ] **2.7 No test was weakened to get green.** Path B: `git diff ios-v1.2.3-b31..HEAD --stat -- Tests App/GenesyxTests App/GenesyxUITests`. Read any deletion or loosened assertion before you accept it.
- [ ] **2.8 Device gate.** Needs a TestFlight build on a **physical iPhone** (build 31 qualifies for path A; for path B run this after section 4 and before section 5). These are the rows the simulator cannot settle. Use throwaway accounts for anything destructive; never the App Review account for J-rows.
  - [ ] **C1** the App Review demo account signs in (`[REVIEW DEMO EMAIL]` / `[REVIEW DEMO PASSWORD]`, exactly as written in the review notes). **This is the item that decides review readiness.**
  - [ ] **E2, E4, E9** Sign in with Apple: first sign-in, returning sign-in, revocation while the app is not running.
  - [ ] **B4, C2, C10** create an account, sign in with email, continue with Google, on production.
  - [ ] **D6, D7** password reset round trip: the email arrives from the Resend domain, the link opens the app on the same phone, the new password works; and the recovery redirect is on the Supabase allow-list.
  - [ ] **B13** after agreeing to consent, a `granted` row exists in `consent_events`.
  - [ ] **J6, J7** account deletion erases a throwaway email account end to end, and an Apple-created account revokes its Apple token.
  - [ ] **H11, H12** two-device sync, and a reinstall restoring history.
  - [ ] **I6, I7** reminders: explanation before the system prompt, delivery at the chosen time, tap opens the right tab.
  - [ ] **A2** first launch on the oldest iOS you hold (minimum is 16.0).

## 3. Archive

*(Path A: skip sections 3 and 4. Build 31 exists. Do not re-archive it: you would create a second, different "31" that Apple would refuse.)*

- [ ] **3.1 Know what `run_archive.sh` is and is not.** It is not in git (ignored at `.gitignore:29`; a fresh clone does not have it) and works at one path only. It archives to **`build/Archives/Genesyx.xcarchive` inside the repo, not the Xcode Organizer path**, after deleting the previous archive at that path, writes `build_archive.log`, and runs `xcodebuild archive` with no signing flags, **without `-onlyUsePackageVersionsFromResolvedFile` and without `xcodegen`**. It does not export, upload, tag or bump. It did **not** produce build 31, whose archive is `build/Genesyx-1.2.3-b31.xcarchive`, a name the script cannot generate.
- [ ] **3.2 Cut the archive with the lockfile flag and a name that cannot overwrite anything.** `build/` is ignored by git (`.gitignore:33`).
  ```bash
  xcodebuild archive \
    -project Genesyx.xcodeproj -scheme Genesyx -configuration Release \
    -archivePath "$PWD/build/Genesyx-<version>-b<build>.xcarchive" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$PWD/build/DerivedData" \
    -onlyUsePackageVersionsFromResolvedFile \
    -skipPackagePluginValidation -skipMacroValidation \
    > "build/archive-<version>-b<build>.log" 2>&1; echo "exit=$?"
  ```
  Expected: `exit=0`. Pass **no** signing settings: Release signs manually with the "Genesyx App Store" profile (`project.yml:149-152`), and a command-line `CODE_SIGN_STYLE` leaks into every package target (GoogleSignIn, AppAuth) which cannot take a profile. Do not use `-allowProvisioningUpdates`; it mints profiles against the developer account and broke the build 9 archive.
- [ ] **3.3 Read the "Resolved source packages" block before trusting the cut.** The lockfile is `Genesyx.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`; it is tracked on purpose, because without it a fresh checkout resolves to whatever is newest (build 28 silently took supabase-swift 2.50.0 to 2.55.1 plus seven other upgrades, none tested).
  ```bash
  grep -n -A 18 'Resolved source packages' "build/archive-<version>-b<build>.log"
  ```
  Expected pins: **Supabase 2.50.0**, **GoogleSignIn 9.2.0**, AppAuth 2.1.0, GTMAppAuth 5.0.0, GTMSessionFetcher 3.5.0, GoogleUtilities 8.1.2, AppCheck 11.3.0, Promises 2.4.1, InteropForGoogle 101.0.0, swift-crypto 4.5.0, swift-asn1 1.7.1, swift-http-types 1.6.0, swift-clocks 1.1.0, swift-concurrency-extras 1.4.0, xctest-dynamic-overlay 1.10.1. **STOP** if any differs, and check `git status` shows `Package.resolved` unmodified.
- [ ] **3.4 Prove the archive is what you meant.**
  ```bash
  A="build/Genesyx-<version>-b<build>.xcarchive"
  /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" \
    -c "Print :ApplicationProperties:CFBundleVersion" \
    -c "Print :ApplicationProperties:SigningIdentity" "$A/Info.plist"
  ls "$A/Products/Applications/Genesyx.app/PrivacyInfo.xcprivacy" "$A/dSYMs"
  plutil -p "$A/Products/Applications/Genesyx.app/Info.plist" | grep -c UsageDescription   # 0
  /usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$A/Products/Applications/Genesyx.app/Info.plist"   # 16.0
  ```
  Version and build match 1.5; the identity is the Apple Distribution one (build 31 shows "Apple Distribution: SF MEDIA & PR LTD"); the privacy manifest and dSYMs are present; there is no `*UsageDescription` key (the app asks for no camera, microphone, photos, location, contacts, Bluetooth or HealthKit permission). A fresh archive has no `Distributions` key yet; it appears after step 4.
- [ ] **3.5 Tag the commit you archived and push both.** Convention: `ios-v<version>-b<build>`, for example `ios-v1.2.3-b31`.
  ```bash
  git tag ios-v<version>-b<build> && git push origin main ios-v<version>-b<build>
  ```
- [ ] **3.6 Back up the archive.** `build/` is gitignored and exists on one Mac. The archive's `Info.plist` is the only local record of the upload and the dSYMs are needed to symbolicate crashes. Copy the `.xcarchive` somewhere durable.

## 4. Upload

- [ ] **4.1 Make an upload-specific export-options file.** Not the tracked `ExportOptions.plist` (see mistake 6). Model it on `build/ExportOptionsUpload-b29.plist`; there is none for b31. Keep it out of git unless you intend to track it.

  | Key | Value |
  |---|---|
  | `method` | `app-store-connect` |
  | `destination` | **`upload`** |
  | `teamID` | the team id (M5L3MM75SG appears in the build 31 archive record) |
  | `signingStyle` | `manual` |
  | `signingCertificate` | `Apple Distribution` |
  | `provisioningProfiles` | `com.genesyx.app` mapped to `Genesyx App Store` |
  | `uploadSymbols`, `stripSwiftSymbols` | `true` |
  | `manageAppVersionAndBuildNumber` | `false` |

- [ ] **4.2 Upload.** Needs the Apple Distribution certificate and the "Genesyx App Store" profile in the keychain, and a network. Run it **once** per build number.
  ```bash
  xcodebuild -exportArchive \
    -archivePath "build/Genesyx-<version>-b<build>.xcarchive" \
    -exportOptionsPlist "build/ExportOptionsUpload-b<build>.plist" \
    -exportPath "$(mktemp -d)"
  ```
- [ ] **4.3 An empty export folder is success.** `destination: upload` writes no local IPA, no `DistributionSummary.plist` and no options copy. Do not go looking for them, and do not re-run because they are missing.
- [ ] **4.4 Read the proof.** The archive's own `Info.plist` records every upload in the `Distributions` array. This is the authoritative local evidence.
  ```bash
  /usr/libexec/PlistBuddy \
    -c "Print :Distributions:0:uploadEvent:state" \
    -c "Print :Distributions:0:uploadEvent:date" \
    -c "Print :Distributions:0:uploadedBuildNumber" \
    -c "Print :Distributions:0:destination" \
    "build/Genesyx-<version>-b<build>.xcarchive/Info.plist"
  # success
  # 2026-09-30T10:49:48Z      (build 31's real record)
  # 31
  # upload
  ```
  Expect `success`, a date within minutes of now, your build number, and `upload`. The record also names `adamId` 6787682466 and shows the preparation step with empty `errors` and `warnings`. `plutil -p "<archive>/Info.plist"` prints the lot. **STOP** if `errors` is not empty.
- [ ] **4.5 Wait for processing.** The build must reach "Complete" in TestFlight before it can be attached (usually minutes; Needs dashboard verification). Nothing is submitted by uploading.
- [ ] **4.6 Make the daily check honest.** The automated check in `to do list.md` should read the `Distributions` array, not look for `*.ipa` (`docs/RECOMMENDED_ACTION_PLAN.md`, item 2.13).

## 5. App Store Connect

Everything here needs a person signed in to App Store Connect; the audit's session expired (`authResult=FAILED`), so **none of this was re-read on 7 October**. Repo records say the listing is fully populated; treat that as a starting point, not a fact.

- [ ] **5.1 Build is processed.** App Store Connect, Genesyx, TestFlight: the build shows as processed with no "Missing Compliance" (the Info.plist key answers it).
- [ ] **5.2 Create the version record.** There is no 1.2.3 record. App Store tab, add an iOS version, type `1.2.3` (or your version). iPhone only.
- [ ] **5.3 Attach the build.** In the version page's Build section choose build 31 (or the new build).
- [ ] **5.4 What's New.** UK English, no dashes (house style), no health or medical claims and nothing about partner linking or pregnancy (neither ships). The app was **rejected before under Guideline 1.4.1** (health and medical information), so health-claim accuracy is the axis Review is demonstrably sensitive to. Draw the content from what changed since the live 1.2.2 (build 30, source commit `7b19d04`): `git log 7b19d04..HEAD --oneline` shows six commits.
- [ ] **5.5 Screenshots.** The listing carries **iPhone 6.5 inch only, from a July build**, and the app icon changed at build 27. `docs/appstore_screenshots_build30/` is labelled build 30 while you ship 31. Decide deliberately whether to retake them from the shipping build; read the screenshot panel for the sizes App Store Connect currently asks for rather than assuming. Nothing shown may be a feature that is not in the build.
- [ ] **5.6 App Privacy answers.** Compare the published answers with `PrivacyInfo.xcprivacy`: five collected types (email address, health, user id, name, other user content), every one linked to the user, none used for tracking, purpose App Functionality; tracking: no. **UNVERIFIED** until a person reads them (QA **F12**).
- [ ] **5.7 Age rating.** Apple is showing a "Review New Social Media Questions on Age Ratings" banner on the Apps list. Answer the questionnaire (App Information, Age Rating). Unanswered questions can refuse the submission form. The answers are the owner's to give.
- [ ] **5.8 App Review Information.** Sign-in is required, so the demo account must work.
  - [ ] Prove it first (QA **C1**) on the TestFlight build, on a physical device, signed out. The credentials in the notes date from **build 13** and Supabase auth has changed since (`verify_jwt` on since 13 August). A dead demo login is one of the commonest rejection causes.
  - [ ] Enter them as `[REVIEW DEMO EMAIL]` and `[REVIEW DEMO PASSWORD]` in the Sign-in required fields only. Never in the repo, a ticket, chat or shell history.
  - [ ] Rewrite the notes for this build: Sign in with Apple and Continue with Google are offered; account deletion is Profile, Delete account; the first-run consent screen; reminders are local notifications only; no partner or pregnancy features; the app is educational and not medical advice, with sources under Profile, Medical Sources & Disclaimer.
- [ ] **5.9 URLs.** Privacy Policy URL `https://genesyx.co.uk/policies/privacy-policy` and the Support URL match what the app opens (Profile). Both returned HTTP 200 on 2026-10-07 (QA **K1, K2**); the App Store Connect fields themselves are unread (**K8**).
- [ ] **5.10 Release option.** Choose manual or automatic release, and whether to use a phased release, on purpose. There is no staging environment, so manual release gives you the moment of going live.
- [ ] **5.11 Last look before you press the button.**
  - [ ] Section 2.8's device gate is ticked, above all **C1**.
  - [ ] `main` and the tag are pushed (3.5).
  - [ ] Supabase project is Active, not paused (6.2).
  - [ ] Add for Review, then Submit to App Review. The status should read **Waiting for Review**; note the date and time.

## 6. Post-submission

- [ ] **6.1 Record it.** Write the submission date, version, build and status in the project's change list, and keep the archive backup (3.6).
- [ ] **6.2 Freeze the things Review depends on.** While the build is in review, do not change: Supabase Authentication (providers, redirect URLs, SMTP, `verify_jwt`), the six live edge functions, the demo account or its data, or the Supabase plan. Do not run `testDemoWalkthrough` with the review credentials (it edits the account). Look at the Supabase dashboard each morning and confirm the project is Active; Free projects pause after a period of inactivity [Inferred from Supabase Free plan behaviour; Needs dashboard verification], and a paused project is a failed demo login.
- [ ] **6.3 If it is rejected.** Read the Resolution Center message before doing anything. The likely axes for this app are a failed demo login (2.1), health claims (1.4.1), account deletion (5.1.1(v), including the Apple token revoke) and Sign in with Apple (4.8). Reply factually and briefly, or fix, take the next free build number (read TestFlight), and repeat from section 1.
- [ ] **6.4 If it is approved.** Release it (if manual). Then, the same day, install the **App Store** build on a clean phone and walk first launch, account creation, sign-in, a log, and Profile; do not delete an account to test it.
- [ ] **6.5 What to watch, and where.**

  | Watch | Where | Why it matters here |
  |---|---|---|
  | Crashes and hangs | Xcode Organizer, Crashes (needs the dSYMs from 3.6) | A Mac or Vision Pro "Designed for iPad" crash hit build 29; the fix covers 10 of 33 modal presentations, so roughly 17 environment-reading ones remain unprotected (QA **L5**). |
  | Sign-in and sign-up failures, 429s | Supabase, Authentication logs | The live email limit is 30 per hour project-wide on the custom Resend SMTP (verified 2026-10-07). That is a soft ceiling: raise it on Authentication, Rate Limits before any marketing push or before turning email confirmation on. |
  | Account deletions | Supabase, Edge Functions, `delete_account` logs | `APPLE_REVOKE_REQUIRED` and Apple revoke failures show up here first. |
  | Database size and egress | Supabase, Reports | Free plan: 500 MB and then the **whole project goes read-only**, 5 GB egress, no downloadable backups for health data. No server-side length limits on notes or names. |
  | Rows not syncing | support reports, not telemetry | A row that fails with a 5xx or 429 stays queued with no backoff (QA **H8**); nothing reports it. The unbounded list queries will begin to truncate silently at about 1,000 rows, roughly 2.7 years of daily logs (QA **H9**); iOS sync began 2026-07-12. |
  | Forced-update gate | n/a | The live `app_config` table does not exist, so the gate cannot fire until it is created (QA **L2**). |
  | Reviews and ratings | App Store Connect | Health-claim wording and the consent screen are what users and Review notice. |

- [ ] **6.6 Close the loop.** Update the version and build recorded in the handoff documents, fix the stale upload-trail check (4.6), and push anything outstanding. Do not leave the temp test, the build-30 screenshots or the unpushed commits for the next release to trip over.

---

## References

- `docs/QA_TEST_MATRIX.md`: the journey-by-journey evidence this checklist gates on.
- `docs/DEVELOPER_HANDOFF.md`: sections 4 and 5 (test suites and known-benign failures), 6 (pitfalls), 7.3 (cutting a build, as it is actually done).
- `docs/LAUNCH_READINESS.md`: the export-options trap (`:170`), why `project.pbxproj` is committed (`:194`), and the history behind each burned build number.
- `docs/BACKEND_AND_SUPABASE.md`, `docs/RECOMMENDED_ACTION_PLAN.md`: backend state and the fixes for the WARNING rows.
- `project.yml:79-130`: the ledger of build numbers and why each was burned.
