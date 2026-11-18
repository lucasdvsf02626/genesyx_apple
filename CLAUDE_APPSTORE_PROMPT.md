# Claude Code Prompt — Genesyx iOS App Store Submission

**Copy everything below the line into Claude Code** (running in `/Users/lucasvalenca_sf/genesxy_apple.V1.02`).

---

You are helping me ship the Genesyx iOS app (Swift, SwiftUI, Xcode 26.6) to the App Store. The project is at `/Users/lucasvalenca_sf/genesxy_apple.V1.02`. An iPhone is now connected to this Mac (trusted).

## Context — already verified
- Code compiles clean in Release; Swift packages resolve.
- `project.yml` (XcodeGen) → `Genesyx.xcodeproj`, scheme `Genesyx`, target `Genesyx`.
- Bundle ID `com.genesyx.app`, version 1.0.0 build 1, iOS 16.0+, team `M5L3MM75SG`.
- Automatic signing is on; Apple ID authenticated; only Apple Development identities exist (distribution cert will auto-generate once a device registers the profile).
- Submission copy, privacy labels, and age-rating guidance live in `docs/APP_STORE_SUBMISSION.md` — read it first.
- Screenshots (1320×2868, 5 screens) in `docs/appstore_screenshots/`. App icon 1024 present.
- `PrivacyInfo.xcprivacy` declares Email + Health + User ID. `ITSAppUsesNonExemptEncryption=false`.
- Account deletion + medical disclaimer built. Supabase backend live.
- A `run_archive.sh` script exists in the project root (uses `-allowProvisioningUpdates`, workspace-local DerivedData, logs to `build_archive.log`).

## Your tasks — do them in order, stop and tell me before any irreversible action

### 1. Produce the Release archive
- Confirm the connected iPhone is recognized: `xcrun devicectl list devices` (look for a Connected iPhone).
- Re-run the archive: `./run_archive.sh` (or the equivalent `xcodebuild archive ... -allowProvisioningUpdates`).
- If it still fails on signing, read `build_archive.log` and diagnose: missing distribution cert, device not trusted, team mismatch, or bundle ID taken. Report the exact error and proposed fix — do NOT keep retrying blindly.
- On success, confirm the archive exists at `build/Archives/Genesyx.xcarchive` and show its Info.plist (bundle id, version, team).

### 2. Validate the archive before upload
- Run: `xcrun altool --validate-app -f build/Archives/Genesyx.xcarchive/Apps/Genesyx.ipa -t ios -u <apple-id> -p <app-specific-password>` OR use `xcrun notarytool`/Organizer. If altool asks for an app-specific password, tell me — I'll generate one at appleid.apple.com.
- If validation surfaces missing items (privacy manifest, icon, bitcode, etc.), fix the config and re-archive. Report each issue with the file/setting responsible.

### 3. Real-device test (pre-upload sanity)
- Build & run the app on the connected iPhone (Debug is fine): `xcodebuild -project Genesyx.xcodeproj -scheme Genesyx -destination 'platform=iOS,name=<device>' build` then run via Xcode.
- Test and report results for:
  1. Email sign-in → land on Home
  2. Google sign-in → land on Home
  3. Sign in with Apple → land on Home
  4. Log a pH entry + a cycle entry → appears in Insights/Log history
  5. Profile → Delete account → account actually removed from Supabase (verify via `supabase/functions` or a DB query if accessible)
- Flag any crash, hang, or flow that doesn't complete. Do not upload until these pass.

### 4. Upload to App Store Connect
- Prefer the Xcode Organizer GUI for the actual upload (more reliable than CLI for first-time). Give me exact click steps: Window → Organizer → select archive → Distribute App → App Store Connect → Upload.
- If I want CLI: `xcrun altool --upload-app ...` — only do this if I confirm.
- After upload, watch for Apple's processing email (usually 15–30 min). Report the build number once uploaded.

### 5. App Store Connect record + metadata
- Check whether an app record for "Genesyx: Cycle & Fertility" exists. If not, I'll create it in the web UI (needs my login). Give me the exact field values to paste from `docs/APP_STORE_SUBMISSION.md`:
  - App name, subtitle, promotional text, description, keywords
  - Support URL `https://genesyx.co.uk`, Privacy Policy URL `https://genesyx.co.uk/privacy`
  - Category: Health & Fitness
  - Age rating: Medical/Treatment Information = Infrequent/Mild → 12+
  - App Privacy answers (the 3 data types table from the doc)
- Verify `https://genesyx.co.uk/privacy` resolves with `curl -sI` before telling me to submit.

### 6. TestFlight internal + submit for review
- Once the build processes, add me as an internal tester, install via TestFlight on device, open it once.
- Then Submit for Review. Tell me what to expect (24–48h, possible rejection reasons to watch for: 2.1 app completeness, 5.1.1 data collection/account deletion, 5.1.2 data use, 4.2 minimum functionality).

## Rules
- Never hardcode secrets. Secrets live in `Secrets.xcconfig` (gitignored) — reference it, don't print values.
- Before uploading, distributing, or submitting anything public/irreversible, show me the plan and wait for my "go".
- Keep all evidence: archive path, validation output, upload response, App Store Connect build ID.
- If a step fails, root-cause it from `build_archive.log` or Apple's error text — don't retry the same command more than twice without changing something.
- Update `docs/APP_STORE_SUBMISSION.md` checklist items as you complete them.

Start now with task 1: confirm the device is connected, then run the archive.
