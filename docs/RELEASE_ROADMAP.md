# Genesyx — Apple App Store Release Roadmap (Zero → Deployment)

> The iOS equivalent of the Android/Play Store checklist. Covers everything from a fresh
> account to a published app, with good practices baked in. Mark items ✅ as you go.
>
> **Key difference from Play Store:** iOS builds/signing/upload happen on a **Mac with Xcode**,
> the testing track is **TestFlight**, and "Data safety" becomes the **App Privacy** label.
>
> **Genesyx v1 is local-only** (no backend, no login, no analytics, no ads). That makes most
> compliance answers the simplest possible — see the ⚠️ notes for what changes when Supabase
> (accounts + cloud health data) is wired later.

---

## Phase 0 — One-time account & project setup

- ⬜ **0.1 Enroll in the Apple Developer Program** — $99/year (vs Play's $25 once). Required to ship. https://developer.apple.com/programs/
- ⬜ **0.2 A Mac with Xcode 15+** — mandatory; iOS cannot be built/signed on Linux/Windows.
- ⬜ **0.3 Decide the Bundle ID** — recommend `com.genesyx.app` (match the Android appId). Permanent once published.
- ⬜ **0.4 Register the Bundle ID** in the Developer portal (or let Xcode auto-create on first archive).
- ⬜ **0.5 Signing** — in Xcode, enable **Automatically manage signing**, select your Team. Xcode handles certificates + provisioning profiles. *(This replaces the manual keystore/AAB signing on Android.)*

---

## Phase 1 — Code readiness (what we control in this repo)

- 🟡 **1.1 Cycle engine ported + tested** — `GenesyxCore`, `CycleEngineTests` (run `swift test`). *Code complete; verify on Mac.*
- 🟡 **1.2 Rest of domain layer ported** — pH logic (`PhStatus`, `PhInsightLogic`), content (cycle/nutrition/quiz), models (`DailyLog`, `PhReading`, `Account`), all with tests (`PhInsightLogicTests`, `ContentTests`). *Code complete; verify on Mac.*
- ✅ **1.3 Theme** — adaptive light/dark colors + shipping system-font type scale complete.
- 🟡 **1.4 Local persistence** (`LocalStore`) + all six repositories done (mirror Android DataStore). *Verify on Mac.*
- 🟡 **1.5 Navigation shell** done (DI container, RootView, MainTabView, minimal onboarding, working Home). ⬜ remaining 13 screens per `ARCHITECTURE.md` build order.
- 🟡 **1.x Reproducible Xcode project** — `project.yml` (XcodeGen) added; `xcodegen generate` builds it.
- ⬜ **1.6 App icon** in `Assets.xcassets` (1024×1024 master, no alpha, no rounded corners — Apple rounds it).
- ⬜ **1.7 `Info.plist` good-practice keys:**
  - `ITSAppUsesNonExemptEncryption = NO` (only standard HTTPS) → skips the export-compliance prompt every upload.
  - `CFBundleDisplayName = Genesyx`, version `1.0.0`, build `1`.
  - URL scheme `genesyx` + (later) Associated Domains for the partner invite deep link.
- ⬜ **1.8 No ads, no tracking SDKs** — verified (keeps the privacy label clean & review fast).

---

## Phase 2 — Build & upload (on your Mac)

- ⬜ **2.1 Archive a signed build** — Xcode → *Product ▸ Archive* (Release config). *(iOS equivalent of "Build signed AAB".)*
- ⬜ **2.2 Validate** the archive in the Organizer (catches signing/asset issues pre-upload).
- ⬜ **2.3 Upload to App Store Connect** — Organizer ▸ *Distribute App ▸ App Store Connect*.

---

## Phase 3 — Create the app record (App Store Connect)

- ⬜ **3.1 Create a fresh "Genesyx" app** in App Store Connect → *Apps ▸ +*. Pick the bundle ID, primary language, SKU. *(= "Create app / fresh Genesyx entry".)*
- ⬜ **3.2 Confirm the uploaded build appears** under the app (processing takes a few minutes). *(= "Upload to Internal testing — key matched".)*

---

## Phase 4 — TestFlight (internal testing)

- ⬜ **4.1 Add internal testers** — App Store Connect users on your team, up to 100, **no review needed**, installs in minutes. *(= "Add tester emails".)*
- ⬜ **4.2 Provide test details** — what to test, and **App Access**: since v1 has **no login**, mark "**Sign-in not required**". *(= "App access → no restrictions".)*
  - ⚠️ When Supabase auth is added: provide a **demo account** here or review will be blocked.
- ⬜ **4.3 Install on your iPhone** via the **TestFlight app** + the invite email. *(= "install on phone".)*
- ⬜ **4.4 (Optional) External testers** — needs a quick **Beta App Review**; only if you want testers outside your team.

---

## Phase 5 — App Store listing & compliance

- ⬜ **5.1 Ads → No.** Genesyx has no ads. Nothing to declare (no AdMob equivalent). *(= "Ads → No".)*
- ⬜ **5.2 Age rating questionnaire** — answer honestly. Fertility/reproductive-health content will likely land **16+/17+** (not 4+). *(= "Content rating questionnaire".)* ⚠️ Don't claim medical/diagnostic capability — Genesyx is informational/wellness.
- ⬜ **5.3 App Privacy ("nutrition label")** — the Data-Safety equivalent.
  - **v1 (local-only):** data stays on device, never sent off → you can select **"Data Not Collected."** ✅ *(matches your "No data collected".)*
  - ⚠️ **When Supabase is wired:** this becomes **Health & Fitness + Contact Info + User Content, linked to identity, used for App Functionality, NOT tracking** — and a real privacy policy + in-app **account deletion** (Guideline 5.1.1(v)) become mandatory.
- ⬜ **5.4 Privacy Policy URL** — ⚠️ **your homework. REQUIRED for every app**, even "no data collected" (App Store Connect won't let you submit without it). Host a simple page (e.g. your domain, or a free generator).
- ⬜ **5.5 Store listing + graphics** — ⚠️ **your homework:**
  - App name, subtitle, promotional text, description, keywords (accurate — must reflect real features).
  - **Screenshots:** required for **iPhone 6.7"** (1290×2796). Use real app screens.
  - Support URL, marketing URL (optional), category (**Health & Fitness**).
  - *(= "Store listing + graphics".)*
- ⬜ **5.6 Export compliance** — answered automatically if `ITSAppUsesNonExemptEncryption=NO` is set (1.7).

---

## Phase 6 — Submit & release

- ⬜ **6.1 Attach the build** to the App Store version.
- ⬜ **6.2 Pricing → Free.**
- ⬜ **6.3 Submit for App Review** — Apple manually reviews (typically 24–48h; stricter than Play).
- ⬜ **6.4 Release** — choose **manual** or **automatic** release on approval. *(= "Roll out → install".)*

---

## Quick reference: Android → Apple mapping

| Your Play Store step | Apple App Store equivalent |
|---|---|
| Build signed AAB | Archive signed build in Xcode |
| Create app entry | Create app in App Store Connect |
| Upload AAB → Internal testing | Upload build → TestFlight |
| Add tester emails | TestFlight internal testers |
| App access (no restrictions) | App Access: "Sign-in not required" (v1) |
| Ads → No | No ads (nothing to declare) |
| Content rating questionnaire | Age rating questionnaire |
| Target audience 18+ | Age rating result (likely 16+/17+) |
| Data safety → No data collected | App Privacy → "Data Not Collected" (v1) |
| Privacy policy URL ⚠️ | Privacy Policy URL ⚠️ (always required) |
| Store listing + graphics ⚠️ | App Store listing + 6.7" screenshots ⚠️ |
| Roll out → install | Submit for review → release |

---

## ⚠️ Your homework (start these in parallel — they gate submission)
1. **Apple Developer Program enrollment** ($99/yr) — nothing ships without it.
2. **Privacy Policy URL** — required even for "no data collected."
3. **Store graphics** — app icon (1024²) + 6.7" screenshots + description.

## 🔑 The two Apple traps that differ from Play (plan for them now)
- **Account deletion + privacy policy + non-"tracking" App Privacy** all become mandatory the
  moment you wire Supabase accounts/cloud health data. Keep v1 local-only to ship fast, add the
  backend in a reviewed v1.x.
- **Health data**: keep all copy **informational/wellness**, never diagnostic/medical claims.
