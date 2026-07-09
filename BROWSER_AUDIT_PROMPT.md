# Agentic Browser Prompt — Genesyx App Store Connect Audit

**Paste this into your agentic browser** (Claude Code with browser tool, or any agent that can drive a browser).

---

You are auditing the App Store Connect state for the **Genesyx** iOS app and verifying external URLs. You have access to a logged-in browser session (the user is signed into App Store Connect at appstoreconnect.apple.com). 

**App facts:** Bundle ID `com.genesyx.app`, version 1.0.0 build 1, team `M5L3MM75SG`, category Health & Fitness, expected app name "Genesyx: Cycle & Fertility".

## Rules
- **READ-ONLY audit.** Do NOT create, edit, upload, submit, delete, or publish anything. You are only reporting current state.
- If a page requires login and you're not authenticated, STOP and tell me to sign in — do not attempt to create accounts or reset passwords.
- For EVERY item, report: (a) status PASS/FAIL/UNKNOWN, (b) the EXACT URL or page path you were on, (c) the literal value you saw (paste text, don't paraphrase), (d) a screenshot description of what was visible.
- If something is empty/missing, say "EMPTY" — don't guess.
- Do not navigate away from App Store Connect / genesyx.co.uk domains.

## PART 1 — EXTERNAL URL CHECKS (do these first, no login needed)

### 1.1 Privacy Policy URL
- Navigate to `https://genesyx.co.uk/privacy`
- Report: final URL after any redirects, HTTP status if visible, and the page `<title>` + first 200 chars of visible text.
- PASS = a real privacy policy document loads (has a title like "Privacy Policy" and actual policy text). FAIL = 404, "page not found", domain doesn't resolve, or a generic hosting error. UNKNOWN = behind a Cloudflare/JS challenge that didn't complete.
- If you hit a Cloudflare "Verifying your connection" challenge, wait 10 seconds and retry once.

### 1.2 Support / Marketing URL
- Navigate to `https://genesyx.co.uk`
- Report: does it load? What is the site? (It should be the Genesyx product/marketing site.) PASS if it resolves to a real site, FAIL if dead.

### 1.3 Privacy Policy alternate paths (only if 1.1 failed)
- Try in order until one works: `https://genesyx.co.uk/privacy-policy`, `https://genesyx.co.uk/legal/privacy`, `https://genesyx.co.uk/pages/privacy`
- Report which (if any) returns a real privacy policy. Apple only accepts ONE URL, so note the correct one.

## PART 2 — APP STORE CONNECT AUDIT

### 2.0 Confirm authenticated
- Navigate to `https://appstoreconnect.apple.com/apps`
- If you see a sign-in page, STOP and tell me to log in.
- If authenticated, you'll see a grid/list of "My Apps". Report what apps are listed (names only).

### 2.1 App record exists (C1)
- On the apps list, look for "Genesyx: Cycle & Fertility" (or any "Genesyx" app).
- Report: does the app record exist? If yes, report the App Name, the **Apple ID** (the numeric ID in the URL, e.g. `appstoreconnect.apple.com/apps/1234567890/appstore` → the number is 1234567890), and the Primary Language and Bundle ID shown.
- If NO app record exists, report "NO APP RECORD — one must be created (manual: + button → New App)" and stop Part 2 here (nothing else can be checked).

### 2.2 Version 1.0 page — App Store tab (C2)
- Click into the Genesyx app → "App Store" tab → scroll to the "1.0" version section ("Prepare for Submission" if not yet submitted).
- Report each of these with the exact value or "EMPTY":
  - **Screenshots**: Which device size tabs have images? (e.g. "iPhone 6.9″"). How many screenshots per size? Note: locally there are 5 images at 1320×2868 (6.9″). Are they uploaded here?
  - **Promotional Text** (170 char): paste it (first line).
  - **Description**: paste first line / first 100 chars.
  - **Keywords** (100 char): paste them.
  - **Support URL**: paste value.
  - **Marketing URL**: paste value (or "EMPTY/none").
  - **Build** (the uploaded build attached to this version): report the build string shown, or "NO BUILD ATTACHED" / "processing" / "none".
  - **Copyright**: value.
  - **Primary Category / Secondary Category**: values.
- Report whether each required field is filled or empty — Apple blocks submission if any required field is empty.

### 2.3 App Privacy (C3)
- Left sidebar → "App Privacy" (or "App" tab → "App Privacy").
- Report: is the privacy section published/complete or showing "incomplete"? 
- List the declared data types (expect: Email Address, Health/Health & Fitness, User ID — each Linked to User = Yes, Tracking = No, Purpose = App Functionality).
- Report "EMPTY/incomplete" if nothing is declared.

### 2.4 Age Rating (C4)
- Back on the 1.0 version page → "Age Rating" section.
- Report the age rating shown (expect 12+ or 17+).

### 2.5 App Review Information (C5)
- 1.0 version page → scroll to "App Review Information" at the bottom.
- Report:
  - **Sign-in required?** Yes/No (for an app with account auth, should be Yes).
  - **Demo account username**: value or EMPTY.
  - **Demo account password**: value or EMPTY.
  - **Notes**: paste contents or "EMPTY".
  - **Contact info** (reviewer name, email, phone): present or EMPTY.
- If empty, flag it: these MUST be filled before submission since the app requires login.

### 2.6 Export Compliance / Content Rights (C6)
- On the 1.0 version page, check for "Export Compliance" and "Content Rights" sections.
- Report status of each: "complete", "not started", or "will auto-clear after build upload".
- Note: `ITSAppUsesNonExemptEncryption=false` is set in the app, so encryption should auto-clear once a build is attached. Report if it shows that.

### 2.7 App Review status (bonus)
- Top of the app's page: report the overall state — "Prepare for Submission", "Waiting for Review", "In Review", "Ready for Sale", etc.
- Report if there are any open warnings/messages (yellow/red banners).

## FINAL REPORT FORMAT

Produce this table:

| Item | Status | URL / page | Value seen (or EMPTY) | What's needed |

Then give:
1. **Overall App Store Connect readiness**: % complete + PASS/FAIL/UNKNOWN per section.
2. **The single most blocking item** for App Store Connect (e.g. "no app record", "demo credentials missing", "privacy URL dead", "no build attached").
3. **Exactly what you need from me** (demo credentials, manual app-record creation, build upload, etc.).

Do NOT change anything. Audit only.