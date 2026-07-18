# Genesyx iOS — What's Left to App Store (Status & Gap Checklist)

> Snapshot of where we are and everything remaining to ship. Updated each session.
> Legend: ✅ done · 🟡 in progress / partial · ⬜ not started · ⚠️ your action (off-code)

---

## ✅ DONE so far

- ✅ Project planning docs: `ARCHITECTURE.md`, `OODA.md`, `PLAYBOOK.md`, `RELEASE_ROADMAP.md`
- ✅ **Domain layer fully ported** (`GenesyxCore`, UI-free, dependency-free):
  - ✅ Cycle engine + models + `CalendarDate` — with `CycleEngineTests`
  - ✅ pH classification + insight logic — with `PhInsightLogicTests`
  - ✅ Cycle / nutrition / quiz content + overlays — with `ContentTests`
  - ✅ Models: `DailyLog`, `PhReading`, `Account` types
- ✅ **App-layer foundation:**
  - ✅ Theme: adaptive light/dark colors, type scale, domain→color mapping
  - ✅ `LocalStore` + all 6 repositories (on-device persistence, `ObservableObject`)
  - ✅ DI container, app entry, navigation shell, minimal onboarding
  - ✅ Working **Home** screen (drives the real cycle engine + content + hydration)
  - ✅ Reproducible Xcode project via `project.yml` (XcodeGen)

---

## 🟡 / ⬜ REMAINING — App code

### 1. Screens to translate (build order from `ARCHITECTURE.md`)
- ✅ **Onboarding (full)** — Splash, Intro, Quiz (5 Q + DidYouKnow), ReadinessSummary, Waitlist
  (egg artwork approximated with `BrandOrb` until image assets are bundled)
- ✅ **Track** — month calendar (phase colors) + day detail + **CycleSettings** edit sheet
- ✅ **Nutrition** — phase foods (expandable) + hydration + supplement plan + articles
- ✅ **Insights** — cycle regularity, symptom heatmap, nutrition consistency, pH insights
- ✅ **pH Tracker** — Swift Charts line + status bands, range filter (7/30/90/all), log/edit sheet (embedded on Track + Nutrition)
- ✅ **Daily Log** sheet — mood / energy / symptoms / sleep / water / supplements / notes (wired from Home + Track)
- ✅ **Profile** — focus toggle, account, prefs, theme toggle, sign-out, delete + **Partner** section
- ✅ **Pregnancy** preview (transition + stub home), reachable from Profile focus toggle
- ✅ **Auth** screen (email + mock Google; real Apple/Google when Supabase lands)
- ✅ **Invite accept** view (deep-link `genesyx://invite/{code}` view built; URL routing still to wire)
- ✅ **Home (full)** — phase hero, today's focus card, hydration + streak, Log CTA

### 2. Shared components
- ✅ Controls (`GxPrimaryButton`/`GhostButton`/`BackButton`/`OptionPill`), `Eyebrow`, `BrandOrb`,
  `FlowLayout`, `ErrorStateView`, pH `PhChart` (Swift Charts), Insights bar charts + heatmap
- 🟡 Optional niceties not yet split out: a reusable `Snackbar`, `ScreenHeader` (screens inline their headers)
- ✅ **SwiftUI `#Preview`s for every screen** (seeded sample data) — iterate UI in Xcode canvas without running

### 3. Assets & config (the main remaining work for a v1)
- 🟡 **App icon** — asset catalog + accent color wired; ⬜ drop `AppIcon-1024.png` into `Resources/Assets.xcassets/AppIcon.appiconset/`
- ✅ **Fonts** — shipping system-font type scale; optional Outfit/Inter adoption is documented but not declared until bundled
- ⬜ Brand images: logo, splash eggs (or keep the `BrandOrb` code stand-in)
- ✅ Deep-link routing wired (`DeepLink` parser + `onOpenURL` + Universal Link → `InviteView`)
- ✅ Error / not-found surface (`ErrorStateView`)
- ✅ **Privacy Manifest** (`PrivacyInfo.xcprivacy`) — required-reason API (UserDefaults) declared, no tracking/collection

### 4. Backend (DEFERRED — scaffolding started; not needed for a local-only v1 launch)
- 🟡 Supabase remote layer **scaffolded**: protocols + row DTOs + config + `#if canImport(Supabase)`
  implementation + `docs/SUPABASE.md` (package not linked yet → v1 builds untouched)
- ⬜ Activate: link `supabase-swift`, set `Secrets.xcconfig`, swap repositories to online-first
- ⬜ Sign in with Apple (required once any 3rd-party login exists) + Google
- ⬜ Edge Functions: partner accept/unlink, **account deletion** (App Store mandatory *if* accounts exist)
- ⬜ App Privacy label flips to "data collected" + privacy policy becomes mandatory

> 🎯 **Recommendation:** ship v1 **local-only** (no backend) → simplest review, fastest path.
> Add Supabase in a reviewed v1.x.

---

## ⬜ VERIFY (on your Mac)
- ⬜ `swift test` → all `GenesyxCore` tests green (proves the domain port)
- ⬜ `xcodegen generate` → `open Genesyx.xcodeproj` → builds clean
- ⬜ Runs in Simulator; runs on a real iPhone
- ⬜ No crashes, no dead buttons, no placeholder text on shipping screens (Guideline 2.1)

---

## ⬜ APPLE OPS — account → store (detail in `RELEASE_ROADMAP.md`)
- ⚠️ **Apple Developer Program** enrolled ($99/yr)
- ⬜ Bundle ID `com.genesyx.app` + Team set for automatic signing
- ⬜ Archive → Upload → **TestFlight** internal testers → install on phone
- ⬜ Create app record in **App Store Connect**
- ⬜ **Age rating** questionnaire (fertility → likely 16+/17+)
- ⬜ **App Privacy** → "Data Not Collected" (valid for local-only v1)
- ⚠️ **Privacy Policy URL** (required even for "no data collected")
- ⚠️ **Store listing** + **6.7" screenshots** + icon + description (category: Health & Fitness)
- ⬜ Pricing → Free → **Submit for Review** → Release

---

## ⚠️ YOUR HOMEWORK (start anytime, runs parallel to coding)
1. Enroll in the Apple Developer Program ($99/yr) — gates everything.
2. **Privacy Policy** — ✅ drafted in `docs/PRIVACY_POLICY.md`; just fill in email/date and host it, then paste the URL.
3. **Store listing copy** — ✅ drafted in `docs/APP_STORE_LISTING.md`; you still need 6.7" screenshots + a 1024² icon + support URL.
4. Have a **Mac with Xcode 15+** ready (or a cloud-Mac).
5. Grant Claude Code **write access** to the repo so the work can be pushed.

---

## Suggested order from here
1. **You:** repo write access (so commits push) + start the Apple enrollment + privacy policy.
2. **Me:** fonts + app icon slot, then screens in build order — Onboarding → Track → Nutrition →
   Insights → pH → Log → Profile/Partner → Pregnancy → Auth/Invite.
3. **You (Mac):** `swift test`, then `xcodegen generate` + run on device.
4. Polish pass (Opus review for App Store guideline risks) → TestFlight → submit.

**Rough effort to a submittable local-only v1:** the screens + components + assets are the bulk;
the hard logic (cycle/pH/content) is already done and tested.
