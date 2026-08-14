# Genesyx iOS — Final App Store Release Checklist

> **Owner:** Genesyx release team  
> **Created:** 14 August 2026  
> **Scope:** iOS public App Store release after TestFlight  
> **Status at this snapshot:** **NOT READY TO SUBMIT**  
> **Refresh this snapshot before every release session.** Git, tests, Supabase and App Store Connect can change after this document is written.

This is the final operational checklist for turning the current iOS working tree into a public App Store submission. It separates engineering proof, backend proof, App Store Connect work and human approval so a green simulator test is never mistaken for a released app.

## 1. Current evidence snapshot

| Item | Current evidence | Release meaning |
|---|---|---|
| Repository | `main` at `4ff918b`; working tree has concurrent uncommitted work | **Do not archive yet** |
| App version | `MARKETING_VERSION = 1.2.0` | Keep unless product changes the version |
| Build number | `CURRENT_PROJECT_VERSION = 18` | **Must use a new unique build number** before upload |
| Frozen earlier baseline | 267 domain / 288 app / 79 UI, 1 expected skip, 0 failures | Historical evidence only; not proof of the current tree |
| Later partner-scope baseline | 267 domain / 296 app / 82 UI, 1 expected skip, 0 failures; Debug and Release builds succeeded | Strong evidence, but changes occurred afterwards |
| Latest targeted UI attempt | Failed to install because stale `FalsifyWidget.appex` existed inside DerivedData without a bundle ID | **Test environment must be cleaned and re-run**; not a proven product defect |
| Original change-list scope | 37/44 complete (84%); 37/42 release-scope items complete (88%) | Remaining rows must be accepted, completed or explicitly deferred |
| Partner linking | Built but deliberately withheld from iOS 1.2.0; Android remains untouched | Keep `FeatureFlags.partnerInvites = false` for this iOS release |
| Physical iPhone evidence | Not available | Record as **deferred**, never “passed” |

The durable evidence and detailed history remain in:

- [HANDOFF.md](HANDOFF.md)
- [PROGRESS_CHECKLIST.md](PROGRESS_CHECKLIST.md)
- [CHANGE_LIST_PLAN.md](CHANGE_LIST_PLAN.md)
- [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md)
- [APP_STORE_LISTING.md](APP_STORE_LISTING.md)
- [TESTFLIGHT_B18.md](TESTFLIGHT_B18.md)

## 2. One-writer release rule

Only one agent may modify Swift/Xcode files or own the simulator at a time.

| Worker | Safe responsibility |
|---|---|
| **Claude Code or Codex — one at a time** | Swift changes, tests, project generation, build/archive, Supabase function code, release commits |
| **Grok** | Read-only audit, checklist reconciliation, App Store metadata comparison, screenshot inventory, evidence/log review, content gap report |
| **Lucas / authorised person** | Legal and medical decisions, Apple credentials, Supabase secrets/deployment approval, App Store Connect declarations, submission and release approval |

Rules:

- [ ] Do not run two `xcodebuild test` commands against the same simulator.
- [ ] Do not let Grok edit the repository while Claude/Codex is implementing.
- [ ] Stop all build/test processes before the final clean verification run.
- [ ] Never discard another agent's uncommitted work.
- [ ] Never upload, submit for review or release without Lucas's explicit approval.

## 3. Immediate stabilisation gate

Complete this before feature or release work continues:

- [ ] Let the active Claude task finish or stop at a documented safe point.
- [ ] Confirm no other `xcodebuild` owns the selected simulator.
- [ ] Confirm no real widget target exists in `project.yml` or the generated Xcode project.
- [ ] Remove only the stale `FalsifyWidget.appex` build artifact/DerivedData produced by falsification.
- [ ] Re-run the previously blocked targeted Learn UI test on a clean build.
- [ ] Re-run `ReleaseScopeTests` and confirm the built app contains no unexpected extension.
- [ ] Review every non-Graphify `git status` entry and assign it to the correct batch.
- [ ] Commit the verified batch so the release candidate is a reproducible SHA.
- [ ] Record the SHA, exact test totals and log paths in `HANDOFF.md`.

Do not call the repository “release frozen” while the working tree is dirty.

## 4. Hard public-release blockers

These are outside the ordinary 44-row feature count but can block a public App Store release.

### 4.1 UK GDPR Article 9 decision — human/legal owner

- [ ] Obtain a written decision on the lawful basis for special-category health data.
- [ ] Reconcile that decision with the live privacy policy, which currently states Article 9(2)(a) explicit consent.
- [ ] If explicit consent is the chosen basis, implement and verify:
  - [ ] approved consent wording;
  - [ ] affirmative action before relevant processing;
  - [ ] stored `consented_at` timestamp and policy version;
  - [ ] withdrawal behaviour and deletion/retention consequences;
  - [ ] tests and backend evidence.
- [ ] If a different lawful basis is approved, update the policy and app copy consistently.
- [ ] Do not invent legal wording in code before the decision is supplied.

### 4.2 Sign in with Apple deletion revocation — Apple/Supabase owner

- [ ] Provide the correct Apple Sign in with Apple private key (`.p8`) through the authorised secret-management route; never paste it into chat or commit it.
- [ ] Configure the required Apple identifiers/secrets in Supabase.
- [ ] Implement the server-side Apple `/auth/revoke` call in `delete_account`.
- [ ] Preserve the existing client-side credential-revoked sign-out handling.
- [ ] Deploy the reviewed Edge Function to the correct Supabase project.
- [ ] Use a disposable Apple test account to verify revocation and account deletion end to end.
- [ ] Record deployment identifier/time and test evidence.

### 4.3 Account-deletion function deployment — Supabase owner

- [ ] Review the repository-only `delete_account` changes for waitlist failure honesty and `user_supplements` cleanup.
- [ ] Confirm the production SQL migration remains checked in exactly as applied.
- [ ] Deploy `delete_account` only after diffing local and deployed function bodies.
- [ ] Run read-only preflight and post-deploy checks for owner, grants, RLS, search path and row counts.
- [ ] Test deletion with a disposable account containing representative logs and supplements.
- [ ] Confirm the account cannot sign in afterwards and owned rows are removed.
- [ ] Confirm shared `genesyx_products` data is not deleted.

### 4.4 Password recovery completion

- [x] Signed-out user can request a reset email from the mandatory authentication gate.
- [x] Response copy does not reveal whether an email is registered.
- [ ] Inspect the real Supabase recovery email redirect and dashboard allowlist.
- [ ] Decide whether recovery finishes on `genesyx.co.uk` or returns through `genesyx://`.
- [ ] If returning to the app, implement the password-recovery auth event and new-password screen.
- [ ] Verify the emailed link end to end with a disposable account.

### 4.5 Free fertility guide

- [x] PDF is bundled and opens from onboarding and Learn → Guides.
- [ ] Correct the four recorded PDF content/accessibility issues in `CHANGE_LIST_PLAN.md` §11.1.
- [ ] Obtain medical/content approval for the final PDF.
- [ ] Verify VoiceOver reading order, links, zoom and document metadata.
- [ ] Re-run bundle and UI tests against the approved final PDF bytes.

## 5. Remaining change-list release scope

The four large “scope separately” features remain excluded: expanded partner sharing, wearables, widget and advanced photo/barcode food logging. Do not count those as missing from this release.

- [ ] Publish or formally defer the website science and Shettles pages needed by in-app links.
- [ ] Complete remote Profile-edit QA against a non-production/disposable account.
- [ ] Verify the full password-reset journey after the redirect decision.
- [ ] Review every Profile edit, prior-entry edit and calendar-date persistence path once more after the final merge.
- [ ] Record physical cellular, logout/relaunch and Apple hardware checks as **deferred — no device available**, unless a remote tester supplies evidence.
- [ ] Reconcile every row in `PROGRESS_CHECKLIST.md` to one of: Done, Accepted deferment, Blocked with owner, or Out of scope.

## 6. Final engineering verification

Run these only after the tree is clean and all intended changes are committed.

- [ ] Confirm `git status --short` is clean except explicitly excluded local tooling.
- [ ] Confirm the final commit SHA and branch.
- [ ] Run `swift test` and save the full log.
- [ ] Run the app unit-test target and save the full log.
- [ ] Reset the simulator keychain to re-arm the system Save Password sheet.
- [ ] Run the complete UI suite with one simulator owner and save the full log.
- [ ] Confirm the expected notification-permission test is the only skip.
- [ ] Run the Release configuration build.
- [ ] Confirm no falsification/debug artifacts or unexpected `.appex` bundles are in the built app.
- [ ] Confirm the privacy manifest, entitlements, icons, logo, recipe images and PDF are present in the built product.
- [ ] Confirm partner linking is absent from the iOS UI, deep-link path and release copy.
- [ ] Confirm no health insight uses fabricated/sample data.
- [ ] Record exact totals, duration, log paths and SHA in the handoff.

Physical-device limitations must be stated separately:

- [ ] Cellular/mobile-data behaviour — deferred or remotely verified.
- [ ] Cold relaunch with real Keychain credentials — deferred or remotely verified.
- [ ] Real Sign in with Apple and revocation — deferred until hardware/account evidence exists.
- [ ] Push-notification permission and delivery — deferred or remotely verified.

## 7. Version, archive and upload gate

- [ ] Check App Store Connect for the latest used build number.
- [ ] Set `CURRENT_PROJECT_VERSION` in `project.yml` to a new unique value (expected next candidate: 19, but verify first).
- [ ] Regenerate the Xcode project with XcodeGen; do not hand-edit `project.pbxproj`.
- [ ] Re-run the required smoke/build checks after regeneration.
- [ ] Archive Release from the final clean SHA.
- [ ] Validate the archive in Xcode Organizer.
- [ ] Confirm bundle ID, version, build, signing team and distribution profile.
- [ ] Inspect the archive for unexpected extensions, duplicate resources or debug files.
- [ ] Upload only after Lucas explicitly approves the exact archive.
- [ ] Confirm processing succeeds in App Store Connect.
- [ ] Distribute to TestFlight before public submission.

## 8. TestFlight acceptance gate

- [ ] Install the new build from TestFlight, not Xcode.
- [ ] Authentication gate blocks private tabs while signed out.
- [ ] Email and Apple sign-in routes behave correctly.
- [ ] Forgot-password request is reachable.
- [ ] Onboarding and the free guide open correctly.
- [ ] Cycle, symptoms, nutrition, hydration, pH and notes persist on the correct date.
- [ ] Insights reflect the same real tracker data.
- [ ] Profile edits and account deletion behave honestly.
- [ ] Partner linking is not exposed in this iOS build.
- [ ] No false offline indicator appears during normal connectivity changes.
- [ ] Light mode, logo, egg artwork and recipe imagery render correctly.
- [ ] Record tester, device/OS, build and result for every failed or deferred row.

If no physical iPhone is available, TestFlight hardware verification remains an explicit release risk. Simulator evidence does not close it.

## 9. App Store Connect checklist

- [ ] Use the final product name, subtitle, description, keywords and support URL from the reviewed submission documents.
- [ ] Remove any partner-linking claim from the 1.2.0 listing.
- [ ] Upload fresh screenshots from the actual release candidate; do not reuse obsolete July screenshots without comparison.
- [ ] Verify screenshot sizes and required device sets in App Store Connect.
- [ ] Complete App Privacy using the app's real data flows, not marketing assumptions.
- [ ] Confirm health, identifiers, contact information, usage data and diagnostics declarations as applicable.
- [ ] Confirm privacy-policy URL and support/contact links work publicly.
- [ ] Complete age rating and medical/health-content questions honestly.
- [ ] Complete content-rights, encryption/export-compliance and DSA trader-status declarations.
- [ ] Provide a stable App Review demo account if review needs authenticated access.
- [ ] Put exact sign-in steps, health-feature scope, partner withholding and deletion behaviour in Review Notes.
- [ ] Attach the processed release-candidate build.
- [ ] Select **manual release** unless Lucas chooses otherwise.
- [ ] Lucas explicitly approves **Submit for Review**.
- [ ] After approval, Lucas explicitly approves public release.

## 10. Definition of ready

### Engineering ready

All intended code is committed, the tree is clean, domain/app/UI/Release verification is green over the same SHA, the Supabase changes are deployed and verified, and all deferred hardware checks are stated honestly.

### Ready to submit

Engineering ready **plus** Article 9/legal resolution, medical/PDF approval, Apple deletion revocation, working password recovery, completed App Store metadata/privacy declarations, fresh screenshots and a processed build.

### Published

Apple has approved the chosen build and Lucas has explicitly released it. An archive, upload, TestFlight build or “Waiting for Review” state is not publication.

## 11. Evidence record

Fill this table during the release. Never tick a gate without a durable reference.

| Gate | Status | Evidence / log / URL | Owner | Date |
|---|---|---|---|---|
| Clean release SHA | ☐ |  | Engineering |  |
| Domain tests | ☐ |  | Engineering |  |
| App tests | ☐ |  | Engineering |  |
| UI tests | ☐ |  | Engineering |  |
| Release build/archive | ☐ |  | Engineering |  |
| Supabase deployment | ☐ |  | Backend |  |
| Disposable deletion test | ☐ |  | Backend/QA |  |
| Article 9 decision | ☐ |  | Legal |  |
| PDF medical approval | ☐ |  | Medical/content |  |
| TestFlight acceptance | ☐ |  | QA |  |
| App Store metadata/privacy | ☐ |  | Product |  |
| Submit approval | ☐ |  | Lucas |  |
| Public release | ☐ |  | Lucas |  |

## 12. Copy-paste prompt for Grok

Use this only while Grok is **not** editing code and does **not** own the simulator:

```text
Act as the read-only release auditor for the Genesyx iOS repository.

Start by reading:
- docs/FINAL_APP_STORE_RELEASE_CHECKLIST.md
- docs/HANDOFF.md
- docs/PROGRESS_CHECKLIST.md
- docs/APP_STORE_SUBMISSION.md
- docs/APP_STORE_LISTING.md
- docs/TESTFLIGHT_B18.md
- BROWSER_AUDIT_PROMPT.md

Rules:
1. Do not edit Swift, project.yml, project.pbxproj, tests, Supabase files or documentation.
2. Do not run xcodebuild, boot/erase a simulator, clear DerivedData or use the simulator. Claude/Codex owns that lane.
3. Do not upload, submit, release, deploy Supabase functions or change App Store Connect.
4. Treat repository notes as leads, not proof. Report the exact file/line or current App Store Connect field supporting each conclusion.
5. Separate: Confirmed done / Partial / Missing / Human decision / Deferred because no physical iPhone.
6. Do not count the separately scoped partner-sharing, wearables, widget or advanced food-logging features against release completion.
7. Do not claim legal, medical, backend, TestFlight or public-release completion without direct evidence.

Tasks:
A. Reconcile every unchecked row in FINAL_APP_STORE_RELEASE_CHECKLIST.md with the latest repo evidence.
B. Audit the App Store listing copy for claims the submitted build does not provide, especially partner linking.
C. Inventory the screenshots currently in App Store Connect and identify which are stale or missing.
D. Compare App Privacy declarations with the documented app/backend data flows.
E. Verify all public URLs, privacy/support links and website science/Shettles destinations.
F. Review the bundled fertility-guide PDF blockers and accessibility checklist, but do not approve medical claims.
G. Return an ordered release blocker table with: severity, exact evidence, owner, next action and whether it blocks upload, submission or public release.

Output only a diagnosis and evidence report. Make no changes.
```

Grok's best contribution is independent evidence reconciliation and App Store Connect inspection. It should not be used as a second concurrent implementer in the same uncommitted working tree.

