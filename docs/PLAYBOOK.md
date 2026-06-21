# genesyx — iOS Playbook: Zero to App Store

> The SwiftUI-native, free, **no-ads** equivalent of the "Vibe Coding Android
> Guide." Build genesyx with Claude, from first line to a published App Store app.
>
> Pair this with `OODA.md` (the working loop) and `ARCHITECTURE.md` (created in
> Phase 2, once your Kotlin app is translated).

---

## ⚠️ Hard requirement: you need a Mac

Apple only allows iOS apps to be **built, signed, and submitted from macOS with
Xcode.** This repo holds all the Swift source code, but the build → archive →
upload steps happen on your Mac. (Cloud-Mac services exist if you don't own one,
but a Mac is non-negotiable somewhere in the chain.)

| Kotlin / Android (your old guide) | SwiftUI / Apple (this guide) |
|---|---|
| Kotlin + XML layouts | Swift + SwiftUI |
| Android Studio | **Xcode** |
| Google Play Console — $25 once | **Apple Developer Program — $99 / year** |
| `build.gradle` | Xcode project / `Package.swift` |
| `AndroidManifest.xml` | `Info.plist` + target settings |
| `targetSdk 34` | iOS Deployment Target (e.g. 16.0) |
| AdMob | **Removed entirely — free, no ads** |
| Signed `.aab` upload | Signed `.ipa` archive via Xcode → App Store Connect |
| Internal/Beta tracks | **TestFlight** |

Because there are **no ads and (planned) no data collection**, large parts of the
Android guide simply vanish: no AdMob rules, no ad-placement policy, no advertising
-ID privacy declarations. This makes Apple review *simpler*, not harder.

---

## Phase 0 — Foundations (do before writing code)

- [ ] **Enroll in the Apple Developer Program** ($99/yr) — required to ship.
- [ ] **Choose the Bundle ID:** `com.<yourorg>.genesyx` (reverse-DNS, permanent).
- [ ] **Decide the deployment target** (recommend iOS 16+ for modern SwiftUI).
- [ ] **Read the relevant App Store Review Guidelines.** For a free, no-ads app the
      ones that bite are:
  - **2.1 App Completeness** — no crashes, no placeholder content, no broken links.
  - **4.2 Minimum Functionality** — must do something real, not be a glorified
    website/wrapper.
  - **5.1.1 Privacy** — if you collect *nothing*, your App Privacy label is
    "Data Not Collected" (clean and simple). Only add a privacy policy URL if you
    later collect data or add accounts.
  - **3.x Payments** — N/A while the app is free with no in-app purchases.
- [ ] **App Privacy plan:** target "Data Not Collected." Avoid SDKs that phone home.

> 💡 The single biggest review-rejection risk for a simple free app is **4.2
> minimum functionality**. Make sure genesyx clearly *does a useful thing.*

---

## Phase 1 — Design preview (the "HTML preview" step, SwiftUI version)

In the Android guide you mocked the app in a single HTML file first. The SwiftUI
equivalent is even better: **Xcode Previews**. Build static SwiftUI views with
`#Preview` blocks and hardcoded sample data — see every screen instantly, no build,
no backend, no signing.

- Mock each screen as a SwiftUI `View` with sample data.
- Use `#Preview { ... }` to render it live in Xcode's canvas.
- Lock the design here — colors, spacing, navigation — *before* wiring logic.
- One design change per request (same discipline as the Kotlin guide).

If you want a browser-shareable mockup to show people before touching Xcode, a
single-file HTML mock still works as a quick throwaway — but Previews are the real
design contract for SwiftUI.

---

## Phase 2 — Architecture (Opus plans it)

Once you send the **Kotlin app code**, I will translate its structure into a
SwiftUI **MVVM** layout and save it as `ARCHITECTURE.md`. Expected shape:

```
genesyx/
├─ genesyxApp.swift            // @main App entry (SwiftUI lifecycle)
├─ Models/                     // data structs (translated from Kotlin data classes)
├─ ViewModels/                 // ObservableObject view models (business logic)
├─ Views/                      // SwiftUI screens + components
├─ Services/                   // persistence, etc. (UserDefaults ⇄ SharedPreferences)
├─ Resources/                  // Assets.xcassets, colors, sample data
└─ Supporting/                 // Info.plist, entitlements
```

Kotlin → Swift translation cheatsheet (filled in fully once I see your code):

| Kotlin / Android | SwiftUI / iOS |
|---|---|
| `data class Tip(...)` | `struct Tip: Identifiable, Codable` |
| `SharedPreferences` | `UserDefaults` (or `@AppStorage`) |
| `Fragment` / `Activity` | SwiftUI `View` + `NavigationStack` |
| `RecyclerView` + adapter | `List` / `ForEach` |
| `ViewBinding` | direct view state + `@State` / `@Binding` |
| `ViewModel` (AAC) | `ObservableObject` + `@Published` |
| Share `Intent` | `ShareLink` |
| Bottom navigation | `TabView` |

---

## Phase 3 — Build (Sonnet, one file at a time)

Follow the build order from `ARCHITECTURE.md`. Suggested default order:

1. **Models** (data structs) — everything else depends on them.
2. **Services** (persistence / repository) — `UserDefaults`-backed store.
3. **ViewModels** — one per screen, `@Published` state.
4. **Views** — components first (cards, rows), then screens, then the `TabView`.
5. **App entry** (`genesyxApp.swift`) — wires it together.

### Prompt pattern (Sonnet) — generate one SwiftUI view

```
[Paste Context Block from OODA.md]

Generate Views/HomeView.swift.

Requirements:
- SwiftUI View backed by HomeViewModel (ObservableObject)
- Shows a card: category badge, title (bold), body text
- Save button (heart) toggles favorite via the view model
- Share button uses ShareLink with the tip's text
- "New" button loads another item with a fade animation
- NO ads, NO analytics, NO network calls
- Complete file, all imports, no partial snippets.
```

---

## Phase 4 — Test

- [ ] **Simulator** — run every screen, every button.
- [ ] **Real device** — connect your iPhone, trust the Mac, run from Xcode.
      (This is the iOS version of "Developer Options + USB.")
- [ ] **TestFlight** — upload a build, invite testers (yourself first). Catches
      device-only issues and is the staging step before public release.
- [ ] Verify: no crashes on launch, no dead buttons, no placeholder text (Guideline 2.1).

---

## Phase 5 — Ship (App Store Connect)

- [ ] Create the app record in **App Store Connect** (name, bundle ID, category).
- [ ] **App icon** — 1024×1024 PNG, no alpha, no rounded corners (Xcode generates
      the rest from the asset catalog).
- [ ] **Screenshots** — required sizes for 6.7" (and as needed) iPhone. Use real
      app screens; free tools like Canva work for framing.
- [ ] **Metadata** — accurate name, subtitle, description, keywords. Must reflect
      what the app actually does (no "best app ever" without features).
- [ ] **App Privacy** — declare "Data Not Collected" (assuming no tracking/accounts).
- [ ] **Age rating** questionnaire — answer honestly (likely 4+).
- [ ] **Archive in Xcode** → Validate → **Upload to App Store Connect**.
- [ ] Attach the build, **Submit for Review**.

---

## Quick checklist before you ever hit "Submit"

- [ ] Builds clean, runs on a real device, no crashes
- [ ] Every button/navigation works (no dead ends)
- [ ] No placeholder / lorem-ipsum content
- [ ] Does something genuinely useful (Guideline 4.2)
- [ ] No ads, no third-party tracking SDKs
- [ ] App Privacy label matches reality
- [ ] Icon + screenshots + accurate description ready
- [ ] Opus pre-submission review done (see `OODA.md` model table)

---

### What I still need from you
1. **The Kotlin app code** → so I translate features + structure into `ARCHITECTURE.md`.
2. **Confirm the deployment target** (iOS 16 recommended).
3. Anything special about genesyx's purpose not obvious from the code.
