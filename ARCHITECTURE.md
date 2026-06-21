# Genesyx — Native iOS (Swift + SwiftUI) Architecture

> **Source of truth** for the native SwiftUI build of Genesyx.
> This is the iOS translation of the proven Android (Kotlin/Compose) architecture.
> Where this doc and the Android doc differ, **this doc wins for iOS**.
> Every Claude session should start by reading this file. Update it as the app evolves.

- **Bundle ID:** `com.genesyx.app` (match Android appId; web/Capacitor id was `com.genesyx.fertilityprep`)
- **UI toolkit:** SwiftUI (+ SF Symbols, Swift Charts)
- **Architecture:** Single-window SwiftUI App + `NavigationStack` + **MVVM** over **Clean Architecture** (`Data` / `Domain` / `UI`)
- **DI:** lightweight `AppContainer` injected via `.environmentObject`
- **Persistence (v1):** **local-only**, mirroring the Android v1 — repositories persist on-device
  (`UserDefaults` / Codable JSON via a `LocalStore`). Auth & partner are in-memory mocks. **Supabase
  is deferred** to a later phase (scaffolded only), exactly as in the current Android build.
- **Pure logic module:** `GenesyxCore` (Swift Package) — UI-free domain layer (models, `CycleEngine`,
  pH + content logic), `swift test`-able without Xcode. The SwiftUI app target depends on it.
- **Deployment target:** **iOS 16.0** · Swift 5.9+ · Xcode 15+
- **Versioning:** `CFBundleShortVersionString = 1.0.0`, `CFBundleVersion = 1`
- **No ads.** No AdMob, no third-party analytics/tracking SDKs.

**App:** *Genesyx — Fertility Prep, Gently Guided.* A premium, mobile-first fertility-prep
& cycle-tracking companion: cycle awareness, nutrition guidance, daily logging, pH tracking,
partner coordination, and personalised insights. Light + dark mode from day one.

---

## Tech mapping (Android → iOS)

| Android (Genesyx Kotlin) | iOS / SwiftUI |
|---|---|
| Jetpack Compose + Material 3 | SwiftUI |
| MVVM + Clean Arch (data/domain/ui) | Same layering (`Data`/`Domain`/`UI`) |
| Hilt | `AppContainer` (manual DI) + `@EnvironmentObject` |
| `supabase-kt` (auth + Postgrest) | **`supabase-swift`** (Auth + PostgREST) |
| Room (offline cache) | Lightweight Codable disk cache (`CacheStore`) |
| DataStore (theme/onboarding flags) | `@AppStorage` (UserDefaults) |
| Encrypted DataStore / Keystore (JWT) | **Keychain** (`KeychainStore`) |
| Compose custom charts / Vico | **Swift Charts** |
| `StateFlow<UiState>` + `collectAsState()` | `@Published` on `ObservableObject` (`@MainActor`) |
| `NavHost` + sealed `Screen` | `NavigationStack` + `enum Route: Hashable` |
| `ModalBottomSheet` (`rounded-t-[28px]`) | `.sheet` + `.presentationDetents` |
| `AlertDialog` / `Dialog` | `.alert` / `.confirmationDialog` / `.sheet` |
| Lucide → Material icons | **SF Symbols** |
| Outfit + Inter (`res/font`) | Bundle `.ttf`, register in `Info.plist` (`UIAppFonts`) |
| `enableEdgeToEdge` + insets | `.ignoresSafeArea` + `safeAreaInset` / `GeometryReader` |
| Google Credential Manager → Supabase | **Sign in with Apple** + Google → `supabase.auth.signInWithIdToken` |
| Sonner toasts | Custom bottom Snackbar overlay (anchored above tab bar) |
| Deep link `genesyx://invite/{code}` | URL scheme + **Universal Link** → `InviteAcceptView` |
| Capacitor config | N/A (native) — keep only app id/name/icons |

---

## Design Tokens (translate oklch → fixed sRGB; never compute at runtime)

Define all colors in `UI/Theme/Color+Genesyx.swift` as an asset catalog color set OR
a `Color(hex:)` palette with light/dark variants. **Pre-compute** every oklch /
`color-mix` value to a fixed hex — do not compute color spaces at runtime.

### Light mode
| Token | ~Hex | Use |
|---|---|---|
| `background` (zenith) | `#F2F2F2` | Page background |
| `card` | `#FFFFFF` | Cards, dialogs, tab bar |
| `foreground` | `#1A1A1A` | Primary text |
| `mutedForeground` | `#6E6B78` | Secondary/helper text |
| **`primary`** (electric-lavender) | `#4D4DAA` | Buttons, active tab, links, focus ring |
| `primaryForeground` | `#FCFCFC` | Text on primary |
| `border` / `input` | `#E6E5EA` | Dividers, input borders |
| `destructive` | `#C8412E` | Delete, errors, sign-out |
| `accentBlue` (electric-blue) | `#57A1CE` | Hydration / chart accent |
| `powderBlue` | `#8DD2E2` | Fertile-window tint |
| `powderPink` | `#DDA4D3` | Period tint |
| `babyLavender` | `#8888D3` | Luteal tint / avatar gradient start |
| `electricPink` | `#C782D8` | Avatar gradient end |

### Dark mode (must ship in v1)
| Token | ~Hex |
|---|---|
| `background` | `#000000` |
| `card` | `#242424` |
| `foreground` | `#FFFFFF` |
| `primary` (brighter) | `#8A7DE0` |
| `border` | white @ 10% |
| `input` | white @ 14% |

> Use an **asset catalog color set with Any/Dark appearances** for each token so
> SwiftUI switches automatically with `@Environment(\.colorScheme)`. Theme override
> (light/dark/system) is applied via `.preferredColorScheme(_:)` at the app root,
> driven by an `@AppStorage("themeMode")` value.

### Shadows / effects
- `gxCardShadow`: iOS-style hairline + lift — approximate with layered `.shadow`
  (`color: .black.opacity(0.05), radius: 18, y: 6` + a hairline `.overlay(stroke 0.5)`).
- `gxOrb` (BrandOrb): `RadialGradient` (electric-lavender → babyLavender → powderPink),
  soft blur — or ship a pre-rendered PNG.
- Animations: `gxFadeUp` (offset y 8→0, opacity, ~320ms `easeOut`); `gxFloat`
  (looping vertical float for splash eggs) via `.repeatForever(autoreverses:)`.

### Typography
- **Display:** **Outfit** (tracking ~ -0.025em) → all headings/titles/brand.
- **Body:** **Inter** (tracking ~ -0.005em) → body, paragraphs, metadata.
- Bundle `Outfit-*.ttf` + `Inter-*.ttf` in `Resources/Fonts/`, list in `Info.plist`
  under `UIAppFonts`. Expose via a `Font` extension (`.gxTitle`, `.gxBody`, etc.).

| Role | Size | Weight |
|---|---|---|
| Splash CTA / Nutrition title | 32 | semibold |
| Screen title (Home greeting, Quiz Q) | 26 | semibold |
| Card heading | 17–18 | semibold |
| Section label (ALL CAPS, tracked) | 11 | medium |
| Body | 13.5–15 | regular |
| pH value display | 48 | semibold |

### Spacing & shape
- Corner radius scale: sm 12 · md 14 · lg 16 · xl 20 · 2xl 24 · 3xl 28 · 4xl 32.
- Applied: **cards/sheets 28**, buttons/inputs 16–24, pills `.capsule`.
- 4pt spacing base; cards usually 20–24 padding. Honor **safe-area insets**.

---

## Project Structure (Xcode)

```
Genesyx/
├── Genesyx.xcodeproj
├── Genesyx/
│   ├── GenesyxApp.swift                 ← @main App; injects AppContainer; theme override
│   ├── RootView.swift                   ← switches: Onboarding / Auth / MainTabView
│   │
│   ├── App/
│   │   ├── AppContainer.swift           ← DI: holds repositories + services (ObservableObject)
│   │   └── AppState.swift               ← session, theme, onboarding-complete flags
│   │
│   ├── Data/
│   │   ├── Remote/
│   │   │   ├── SupabaseService.swift     ← supabase-swift client (Auth + PostgREST)
│   │   │   └── DTO/                       ← Codable DTOs matching tables
│   │   ├── Cache/
│   │   │   └── CacheStore.swift          ← Codable disk cache (light, online-first)
│   │   ├── Keychain/
│   │   │   └── KeychainStore.swift       ← session/JWT storage
│   │   └── Repository/
│   │       ├── AuthRepository.swift
│   │       ├── CycleRepository.swift
│   │       ├── DailyLogRepository.swift
│   │       ├── PhRepository.swift
│   │       ├── PartnerRepository.swift
│   │       ├── NutritionRepository.swift
│   │       └── ProfileRepository.swift
│   │
│   ├── Domain/
│   │   ├── Model/   { User, Profile, CycleSettings, CyclePhase, DailyLog,
│   │   │              PhReading, PartnerInvite, NutritionFocus, Supplement }
│   │   └── UseCase/ { GetCycleInsights, GetNutritionFocus, LogDailyEntry,
│   │                  ComputeCyclePhase, ComputeStreak, ClassifyPh }
│   │
│   ├── UI/
│   │   ├── Theme/        { Color+Genesyx.swift, Font+Genesyx.swift, Theme.swift }
│   │   ├── Navigation/   { Route.swift, Router.swift }
│   │   ├── Components/    ← Shared views
│   │   │   { GenesyxTabBar, BrandLogo, BrandOrb, PurpleCard, ScreenHeader,
│   │   │     BarChartView, LineChartView, DidYouKnowSheet, SupplementBadge,
│   │   │     CycleSettingsSheet, PhLogSheet, Snackbar }
│   │   ├── Home/        { HomeView, HomeViewModel }
│   │   ├── Track/       { TrackView, TrackViewModel }       ← month calendar
│   │   ├── Nutrition/   { NutritionView, NutritionViewModel }
│   │   ├── Insights/    { InsightsView, InsightsViewModel } ← charts + pH insights
│   │   ├── Profile/     { ProfileView, ProfileViewModel, PartnerSection }
│   │   ├── Log/         { LogView, LogViewModel }           ← daily log sheet
│   │   ├── Ph/          { PhTrackerView, PhViewModel }      ← pH chart + history
│   │   ├── Pregnancy/   { PregnancyView }                   ← preview/stub
│   │   ├── Auth/        { AuthView, AuthViewModel }         ← email + Apple/Google
│   │   ├── Invite/      { InviteAcceptView, InviteViewModel } ← deep link /invite/{code}
│   │   └── Onboarding/  { SplashView, OnboardingIntroView, QuizView,
│   │                      OnboardingViewModel, ReadinessSummaryView, WaitlistView }
│   │
│   ├── Util/ { DateUtils.swift, Extensions.swift, Color+Hex.swift }
│   └── Resources/
│       ├── Assets.xcassets   ← color sets (light/dark), egg images, logo, app icon
│       ├── Fonts/            ← Outfit-*.ttf, Inter-*.ttf
│       └── Info.plist        ← UIAppFonts, URL types, associated domains
└── GenesyxTests/
    └── CycleEngineTests.swift ← port the Android CycleEngineTest verbatim
```

---

## Dependencies (Swift Package Manager)

- **`supabase-swift`** (`supabase/supabase-swift`) — Auth + PostgREST (+ Realtime later).
- **Swift Charts** — system framework (cycle regularity, nutrition, symptom heatmap, pH chart).
- **Sign in with Apple** — `AuthenticationServices` (system).
- **Google Sign-In** (`GoogleSignIn-iOS`) — only if Google OAuth is required at launch
  (else start with Apple + email, add Google later).
- No analytics, no ads, no tracking SDKs. Keep the dependency graph minimal for App Review.

---

## Navigation

Root decides the surface based on `AppState`:

```
RootView
 ├─ not onboarded            → Onboarding flow (Splash → Intro → Quiz → Summary → [Waitlist])
 ├─ onboarded, not signed in → AuthView
 └─ signed in                → MainTabView (5 tabs) + sheets
```

- **Onboarding** is a `NavigationStack` with `enum OnboardingRoute`. Completion is
  persisted (`@AppStorage("onboardingComplete")`) so it **survives relaunch** (an
  improvement over the web's in-memory `flow` state).
- **MainTabView** = `TabView` with 5 tabs; each tab owns its own `NavigationStack`.
- **Tab bar hidden** on splash/onboarding/auth/invite and full-screen sheets (these
  live outside `MainTabView`, so it's automatic).
- **Deep link:** `genesyx://invite/{code}` (URL scheme) **and** a Universal Link
  (`...lovable.app/invite/:code`) → `InviteAcceptView` (sign-in required; email must match).

| Tab | SF Symbol |
|---|---|
| Home | `house` |
| Track | `calendar` |
| Nutrition | `leaf` |
| Insights | `chart.bar` |
| Profile | `person` |

Sheets (not tabs): **LogView** (Home "Log today"), **PhLogSheet**, **CycleSettingsSheet**,
**PregnancyView** (preview).

---

## Backend / Data Layer

> **v1 reality (matches Android):** the app is **local-only**. `CycleRepository`,
> `DailyLogRepository`, and `PhRepository` persist on-device (Android uses DataStore →
> iOS uses `UserDefaults`/Codable JSON via a `LocalStore`). `SessionRepository` and
> `PartnerRepository` are **in-memory mocks**. The Supabase client is scaffolded but **not
> wired** yet. The tables/operations below are the **target** remote layer for a later phase.

**Target backend = Supabase (Postgres + RLS + Auth).** When wired, native calls Supabase
directly via `supabase-swift`; RLS enforces per-user isolation. A light Codable cache holds the
last-loaded data for instant render; writes go to Supabase, then refresh state.

### Tables (RLS = owner-only unless noted)
| Table | Key columns |
|---|---|
| `profiles` | id (FK auth.users), display_name, avatar_url, **partner_id**, theme. *SELECT for self or linked partner.* |
| `cycle_settings` | user_id (unique), cycle_length (21–35), period_length (1–10), last_period_date |
| `daily_logs` | user_id, date, mood, energy, symptoms[], sleep_minutes, water_ml, supplements[], notes — **UNIQUE(user_id, date)** |
| `partner_invites` | inviter_id, invitee_email, code (unique), status, expires_at (+14d), accepted_by/at |
| `ph_readings` | user_id, ph_value (4.5–9.0), recorded_at, notes |

### Operations (port from `src/lib/*.functions.ts`; re-implement Zod checks in Swift)
- **cycle:** `getCycleSettings`, `upsertCycleSettings`
- **dailyLog:** `getDailyLog(date)`, `upsertDailyLog(partial)`, `getStreak`
- **ph:** `listPhReadings(sinceDays?)`, `create/update/deletePhReading` (validate 4.5–9.0)
- **partner:** `sendPartnerInvite(email)`, `revokePartnerInvite(id)`, `acceptPartnerInvite(code)`, `unlinkPartner`
- **account:** `getProfilePrefs`, `updateDisplayName`, `updateTheme`, `deleteAccount`

> `acceptPartnerInvite`, `unlinkPartner`, `deleteAccount` use the **service role** on web.
> Native can't hold a service-role key → these become **Supabase Edge Functions** the app
> calls with the user's JWT. (See Open Decisions.)

### Auth
- Email + password (`signUp` / `signIn`, 8–72 chars).
- **Sign in with Apple** (required by App Review when offering third-party login) →
  `supabase.auth.signInWithIdToken`.
- Google (optional v1) → GoogleSignIn → `signInWithIdToken`.
- Session JWT stored in **Keychain** (`KeychainStore`), never UserDefaults.
- Bootstrap order: attach the Supabase auth-state listener **before** restoring the
  session (mirror the web's listener-first pattern to avoid a race).
- `email_verified` claim gates partner-invite acceptance.

### Reactive refresh
Web used a pub/sub `Set<Listener>` (`emitLogChange`, pH `emit`). iOS equivalent: a shared
repository exposing `@Published` state (or an `AsyncStream`); views observing it update
automatically after a mutation — no manual emit.

---

## Cycle Engine (port from `src/lib/cycle.ts` / `cycleEngine.ts`)

Pure functions, no backend. Given `lastPeriodDate`, `cycleLength`, `periodLength`, compute
day-of-cycle, **phase** (`period`/`follicular`/`fertile`/`ovulation`/`luteal`), and the
fertile window. Phase colors (Track calendar):
- period → powderPink · follicular → card/border · fertile → powderBlue ·
  ovulation → primary (ring) · luteal → babyLavender · today → ring on foreground.

Port verbatim into `Domain/UseCase/ComputeCyclePhase.swift` + `Util/DateUtils.swift` and
**unit-test against the TS/Kotlin logic** (`CycleEngineTests`).

---

## Screen Build Order

| # | Screen | Notes |
|---|---|---|
| — | Theme (Color/Font/Theme + **dark mode**) | Asset catalog color sets + bundled fonts |
| — | Navigation (Route, Router, RootView) | onboarding/auth/invite + 5 tabs |
| — | GenesyxApp + MainTabView + tab bar | |
| 1 | Splash + OnboardingIntro | floating eggs (`gxFloat`) |
| 2 | OnboardingQuiz (5 Q + DidYouKnow sheets) | persist answers to `@AppStorage` |
| 3 | ReadinessSummary + Waitlist | |
| 4 | Home (cycle hero, hydration, streak, focus, log CTA) | wire real repositories |
| 5 | Track (month calendar + phase colors) + CycleSettings sheet | |
| 6 | Nutrition (phase foods + hydration) | port `PHASE_FOODS` map |
| 7 | Insights (cycle regularity, symptom heatmap, nutrition, pH insights) | Swift Charts |
| 8 | pH Tracker (line chart 7/30/90/all, history, edit/delete) | reference bands 4.5–9.0 |
| 9 | Daily Log sheet (mood/energy/symptoms/sleep/water/supplements/notes) | |
| 10 | Profile (focus toggle, account, prefs, theme, sign-out) | |
| 11 | Partner (invite form, pending list, linked) + invite-accept | Edge Fn for accept |
| 12 | Auth (email + Apple + Google) | |
| 13 | Pregnancy preview (stub) | |
| — | Theme toggle (light/dark/system) → `@AppStorage` | |

### Per-screen prompt template (SwiftUI)
```
Build UI/[Feature]/[ScreenName]View.swift in SwiftUI for the Genesyx app (iOS 16+).
Match this screenshot exactly.
Design tokens: primary electric-lavender #4D4DAA, background #F2F2F2, card #FFFFFF,
text #1A1A1A, muted #6E6B78; cards 28pt radius; Outfit (display) + Inter (body); dark mode.
Use MVVM with [ScreenName]ViewModel (ObservableObject, @MainActor) and our shared
GenesyxTheme + GenesyxTabBar. SF Symbols for icons. Complete file, all imports, no ads.
```

---

## Feature Parity Matrix

| Feature | Backend | Native plan |
|---|---|---|
| Onboarding quiz (5 Q + facts) | client-only | Persist answers to `@AppStorage` |
| Cycle tracking + phase math | Supabase + pure math | Port engine; `cycle_settings` |
| Cycle settings editor | Supabase | Edit sheet |
| Daily logging | Supabase | Log sheet + `daily_logs` |
| Hydration tracker (± water) | Supabase (`water_ml`) | On Home + Nutrition |
| Streak counter | computed | From logs (`ComputeStreak`) |
| Nutrition guidance (phase foods) | hardcoded | Port `PHASE_FOODS` map |
| pH tracking + chart + insights | Supabase | Swift Charts, reference bands |
| Partner invite/link | Supabase (+ service role) | Edge Fn for accept/unlink |
| Insights dashboard (charts) | mocked → real | Build; wire real data where available |
| Theme light/dark | Supabase + local | `@AppStorage` + asset color sets |
| Account mgmt (name/password/delete) | Supabase (+ service role) | delete via Edge Fn |
| Pregnancy mode | stub | Preview screen only (defer full) |
| Apple/Google OAuth | web wrapper | Apple (required) + Google (optional v1) |

---

## Known Gaps / Decisions when scaffolding

1. **404 / error surfaces** — provide a nav fallback + an error view ("Something went
   wrong", Try again / Go home), mirroring the web router's defaults.
2. **HomeViewModel** ships stubbed on Android — inject real repositories on iOS from day one.
3. **Charts** — build reusable `LineChartView` / `BarChartView` on Swift Charts; pH chart
   needs colored reference bands (acidic/optimal/alkaline) and a fixed y-domain 4.5–9.0.
4. **BrandOrb** — `RadialGradient` + blur, or ship a pre-rendered PNG.
5. **Toasts** — custom bottom Snackbar overlay anchored above the tab bar.

---

## Open Decisions (carried from Android + iOS-specific)

1. **Privileged ops** (partner accept/unlink, account delete) → implement as **Supabase
   Edge Functions** called with the user JWT. *Recommended; confirm.*
2. **Google OAuth at launch?** Apple login is required by App Review when any third-party
   login is offered. Recommend shipping **Apple + email** first, add **Google** soon after.
   *Confirm v1 scope.*
3. **Account deletion** — App Store **requires** in-app account deletion for apps with
   accounts (Guideline 5.1.1(v)). The `deleteAccount` Edge Function covers this — **must be
   in v1**.
4. **Onboarding persistence** — keep client-only (`@AppStorage`) unless you want a table.
5. **App Privacy label** — the app *does* collect health/cycle data tied to an account, so
   the label is **not** "no data collected." Declare: Health & Fitness data, Contact Info
   (email), User Content — linked to identity, used for app functionality, **not** for
   tracking. A **privacy policy URL is required** (HealthKit-adjacent + accounts). *Action item.*

> ⚠️ Correction vs the simpler playbook: because Genesyx has accounts + health data,
> "Data Not Collected" does **not** apply. Budget for a real privacy policy and an
> accurate App Privacy questionnaire. This is the #1 review risk for this app.

---

## Conventions

- Complete files only — no partial snippets; all imports at the top. Swift/SwiftUI only.
- One screen per build step, matched to its screenshot.
- `@MainActor` `ObservableObject` view model per screen, exposing a `UiState` + intent methods.
- Repositories are `async`/`await`; expose `@Published` state for reactive refresh.
- Light + dark parity from day one.
- Pre-compute all colors to fixed sRGB; never compute oklch/color-mix at runtime.
- Never store the session JWT outside the Keychain.
