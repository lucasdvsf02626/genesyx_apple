# Genesyx iOS: Frontend Structure

This is the technical reference for the Genesyx iOS user interface layer: how the seven tabs are mounted and kept alive, how navigation and deep links route, how state reaches views (including the environment re-injection problem on sheets), what each of the 14 feature folders contains, which files have outgrown themselves and what can be extracted from them, which reusable pieces exist, a concrete walkthrough for adding a feature (with the measured cost of adding one `DailyLog` metric), and the launch-argument system the UI tests use. It is written for a developer who has to change the UI or review a UI change. It describes the code at the commit named below and keeps what was read in code apart from what was inferred. The architecture beneath the UI (layers, sync, persistence, concurrency) is in `docs/TECHNICAL_ARCHITECTURE.md`; scalability and security findings are in `docs/SCALABILITY_REVIEW.md` and `docs/SECURITY_REVIEW.md`, referenced here by filename only.

Last updated 2026-10-07, against commit 353ff26 (1.2.3 build 31)

Corrected 2026-10-07 after live dashboard verification: the auth email-quota finding was retracted.

---

## Contents

1. [Evidence labels and conventions](#1-evidence-labels-and-conventions)
2. [Overview and constraints](#2-overview-and-constraints)
3. [The root surface and the seven tabs](#3-the-root-surface-and-the-seven-tabs)
4. [Navigation](#4-navigation)
5. [State management](#5-state-management)
6. [Screen inventory](#6-screen-inventory)
7. [The god-file problem](#7-the-god-file-problem)
8. [Reusable UI patterns](#8-reusable-ui-patterns)
9. [Where to add a new feature](#9-where-to-add-a-new-feature)
10. [Testing hooks: the launch-argument system](#10-testing-hooks-the-launch-argument-system)
11. [Known frontend debt](#11-known-frontend-debt)
12. [Appendix: reproducing the counts](#12-appendix-reproducing-the-counts)

---

## 1. Evidence labels and conventions

Every substantive claim carries one of these labels. A claim with no label is a definition or follows from the claim beside it.

| Label | Meaning |
|---|---|
| **[Verified in code]** | Read at a cited `path:line` in this repository at commit 353ff26. |
| **[Verified in repo docs only]** | An existing file under `docs/` or a code comment records it; the behaviour was not re-checked. |
| **[Verified live]** | Confirmed against the live Supabase project on 2026-10-07 during this engagement. |
| **[Supplied context]** | Came from the client's brief and cannot be checked from this repository. |
| **[Inferred]** | Reasoned from an implementation pattern. The text says from what. |
| **[Needs dashboard verification]** | Depends on production or hosted-service state nobody has read. |
| **[Verified in code + measured]** | The code path is read at a cited line and the timing or count was measured by the analysis pass on 2026-10-07. Not re-run for this document. |

Citations are `path:line` or `path:start-end`, relative to the repository root `/Users/lucasvalenca_sf/genesxy_apple.V1.02`. Bare filenames are not used. A `:line` that follows a full path in the same sentence or table row refers to that path. Line numbers refer to the working tree at 353ff26. Counts are reproducible with the commands in [section 12](#12-appendix-reproducing-the-counts). Where a fresh count differs from the shared evidence brief, both are given.

---

## 2. Overview and constraints

**[Verified in code]** unless marked.

- **SwiftUI throughout.** The UI layer is 33 files and 11,640 lines in `App/Genesyx/UI`, in 14 feature folders plus three loose files. UIKit appears only as small bridges: one `UIViewRepresentable` for the bundled PDF (`App/Genesyx/UI/Learn/FreeGuideView.swift:22`), `UIApplication` calls for resigning the keyboard (`App/Genesyx/UI/Components/GenesyxControls.swift:23`), finding a root view controller for Google sign-in (`App/Genesyx/UI/Auth/AuthView.swift:281-283`) and opening Settings (`App/Genesyx/UI/Profile/ProfileView.swift:367`), `UIImage(named:)` to test whether a hero image exists (`App/Genesyx/UI/Learn/LearnViews.swift:29`), and `UIColor` for adaptive colours (`App/Genesyx/UI/Theme/GenesyxColors.swift:18-20`).
- **iOS 16.0 floor, Swift 5.9, iPhone only, portrait only.** `project.yml:14-15`, `project.yml:131`, `project.yml:132` (`TARGETED_DEVICE_FAMILY: "1"`), `project.yml:65-66` (`UIInterfaceOrientationPortrait`). The 7-tab bar is sized against the narrowest supported device, 375 pt (`App/Genesyx/UI/MainTabView.swift:3-9`).
- **No view-model layer.** Views bind directly to `ObservableObject` repositories through `@EnvironmentObject` (75 declarations, all concrete classes). Rationale and costs are in `docs/TECHNICAL_ARCHITECTURE.md`, section 3. The iOS 16 floor also rules out `@Observable`, which needs iOS 17 (platform fact); there is no use of it in the app.
- **Mac and Vision Pro run the iPhone build as "Designed for iPad"** (the App Store provides this for iPhone-only apps unless the developer opts out) **[Inferred]** as platform behaviour; the effect on the UI is the environment-injection problem in [section 5.4](#54-the-sheet-re-injection-problem).
- **Dynamic Type is not supported.** The type scale is fixed point sizes. "`Font.system(size:)` takes no part in Dynamic Type, so Larger Text in iOS Settings changes nothing here, nor at the ~150 other places that size their own text" (`App/Genesyx/UI/Theme/Typography.swift:5-10`). Supporting it needs `@ScaledMetric` behind the nine type names and the two flexible-spacer screens (splash and quiz) learning to scroll (`:7-10`).
- **Light mode is the default.** `RootView` applies `preferredColorScheme` from `prefs.themeMode` rather than following the device (`App/Genesyx/Data/App/RootView.swift:63,157-163`); the seeded UI-test container forces `.light` unless told otherwise (`App/Genesyx/Data/App/AppContainer.swift:236-237`). The page-background artwork is drawn in light mode only (`App/Genesyx/UI/Components/GenesyxControls.swift:51-59`).

---

## 3. The root surface and the seven tabs

### 3.1 What mounts when

`RootView` is the top-level surface (`App/Genesyx/Data/App/RootView.swift:10`). It switches over a `RootDestination` computed by the pure function `RootRouting.destination` (`App/Genesyx/Data/App/RootRouting.swift:58-77`; table in `docs/TECHNICAL_ARCHITECTURE.md`, section 4.4). `MainTabView` exists only when the destination is `.mainTabs`, that is, signed in, consent on record for the current wording, no password recovery in progress, no forced update (`App/Genesyx/Data/App/RootView.swift:56-57`). Every other destination replaces the tabs entirely: `SessionResolvingView`, `OnboardingFlowView`, `AuthView(allowsDismissal: false)`, `ConsentView`, `UpdateRequiredView`, `ServiceUnavailableView`, `ResetPasswordView` (`:31-60`). Because `MainTabView` is rebuilt each time the destination returns to `.mainTabs`, its `@StateObject` `TabRouter` is recreated and the selected tab resets to Home (`App/Genesyx/UI/MainTabView.swift:11`). **[Verified in code]**

### 3.2 The seven tabs

`App/Genesyx/UI/MainTabView.swift:3-9` explains why there is a custom bar: a native `TabView` shows five tabs and folds the rest into "More", which would bury Learn and Profile. Seven fit because the narrowest supported device is 375 pt wide, leaving about 53 pt per tab against a widest label of about 48 pt. **[Verified in code]**

| Index | Tab | Root view | Declared at | Own `NavigationStack` | Path-bound |
|---|---|---|---|---|---|
| 0 | Home | `HomeView` | `App/Genesyx/UI/Home/HomeView.swift:8` | `:37` | no |
| 1 | Track | `TrackView` | `App/Genesyx/UI/Track/TrackView.swift:6` | `:40` | no |
| 2 | pH | `PhTabView` | `App/Genesyx/UI/Ph/PhTrackerSection.swift:7` | `:18` | no |
| 3 | Nutrition | `NutritionView` | `App/Genesyx/UI/Nutrition/NutritionView.swift:6` | `:53` | yes, `articlePath: [String]` (`:24`) |
| 4 | Insights | `InsightsView` | `App/Genesyx/UI/Insights/InsightsView.swift:8` | `:142` | no |
| 5 | Learn | `LearnLandingView` | `App/Genesyx/UI/Learn/LearnViews.swift:55` | `:73` | yes, `path: [String]` (`:59`) |
| 6 | Profile | `ProfileView` | `App/Genesyx/UI/Profile/ProfileView.swift:7` | `:54` | no |

The mapping from index to view is the `ZStack` at `App/Genesyx/UI/MainTabView.swift:29-37`; the labels and icons are `MainTabView.items` (`:17-25`). Each tab button carries `accessibilityIdentifier(item.title)` (`:111`), so UI tests tap tabs by their visible title.

### 3.3 How `MainTabView` keeps every tab alive

All seven tab views are built and kept in a `ZStack`. The inactive ones are hidden by opacity, removed from hit testing and from the accessibility tree; nothing is unmounted. **[Verified in code]**

```swift
// App/Genesyx/UI/MainTabView.swift:70-76
private func tabContent<Content: View>(_ index: Int, _ content: Content) -> some View {
    let active = router.selection == index
    return content
        .opacity(active ? 1 : 0)
        .allowsHitTesting(active)
        .accessibilityHidden(!active)
}
```

The stated reason is that "state (scroll position, in-tab nav) survives switching" (`App/Genesyx/UI/MainTabView.swift:68-69`). The consequences, each visible in the code:

1. **All seven view trees exist from the first frame after sign-in.** **[Inferred]** from SwiftUI semantics, since a view that is in the hierarchy is re-evaluated when anything it observes publishes, even at opacity 0: each tab's `body` is evaluated at mount and again on every invalidation, whether or not the tab is visible, so a write to the daily log re-evaluates Home, Track, Nutrition, Insights and any open sheet at once. The measured per-body costs in `docs/SCALABILITY_REVIEW.md` therefore apply to hidden tabs too, because the measurements were taken per body and not per visible tab. The `ZStack` structure itself is **[Verified in code]**.
2. **`onAppear` fires once, at mount, not on each tab switch** **[Inferred]** from SwiftUI semantics for views that are never removed. The code behaves as if it knows this: the cross-tab signals are `@Published` flags consumed with `.onChange`, not with `.onAppear` alone. `TrackView` consumes `pendingHydration` both on appear and on change (`App/Genesyx/UI/Track/TrackView.swift:97-98`), and `LearnLandingView` consumes `pendingLearnSlug` only on change (`App/Genesyx/UI/Learn/LearnViews.swift:121-125`).
3. **A tab switch is instant, a sheet is not.** `App/Genesyx/UI/Ph/PhTrackerSection.swift:46-50` records the consequence: a CTA that selected the Nutrition tab and let Nutrition raise a sheet flashed Nutrition into view while the sheet animated up, and dismissing left the user a tab away from where they started. The fix presents the supplement plan from the pH tab itself. The rule it states is: a sheet that is "an overlay on the task she is already doing" is presented in place; only a genuine move to another section goes through the router.
4. **Overlays belong above the tabs.** The milestone celebration is an `.overlay` on the whole `MainTabView`, not inside a tab, because logging happens on four tabs and a celebration that appeared only on Insights "would mostly be shown to nobody" (`App/Genesyx/UI/MainTabView.swift:42-53`).

The Learn tab badge counts articles that arrived in an update and are unread; it reads 0 on a first install (`App/Genesyx/UI/MainTabView.swift:92-94,118-128`). VoiceOver gets the count in words (`:112-115`).

### 3.4 Tab identity is a bare integer

There is no `Tab` enum. A tab is its index, and the order is encoded in several places that nothing links at compile time. **[Verified in code]**

| Kind | Where |
|---|---|
| Order of labels and icons | `App/Genesyx/UI/MainTabView.swift:17-25` |
| Order of root views | `App/Genesyx/UI/MainTabView.swift:30-36` |
| Learn index constant | `App/Genesyx/UI/MainTabView.swift:15` (`learnTab = 5`) |
| Notification destinations | `App/Genesyx/Notifications/NotificationContent.swift:45-47` (`NotificationTab: Int`, "matches the `MainTabView` order") |
| Literal assignments `router.selection = N` | `App/Genesyx/UI/Home/HomeView.swift:313,358,408`; `App/Genesyx/UI/Track/TrackView.swift:79`; `App/Genesyx/UI/Profile/ProfileView.swift:510`; `App/Genesyx/UI/Ph/PhTrackerSection.swift:26`; `App/Genesyx/UI/Nutrition/NutritionView.swift:205,506`; `App/Genesyx/UI/Learn/LearnViews.swift:481` |
| Test launch argument | `App/Genesyx/UI/MainTabView.swift:131-137` (`-uiTestTab N`); the mapping is repeated in a comment at `App/GenesyxUITests/GenesyxUITests.swift:13` |

Nine literal assignments, three declarations of the order in production code, and one more in the tests. Adding, removing or reordering a tab means editing all of them; see [section 9.4](#94-a-new-tab).

---

## 4. Navigation

### 4.1 One `NavigationStack` per tab, one per sheet

Every tab root owns its own `NavigationStack` (table in 3.2). Every presented sheet that needs a title bar also wraps its content in its own `NavigationStack`: 21 `NavigationStack` declarations exist outside the seven tab roots (for example `App/Genesyx/UI/Log/LogView.swift:60,444,488,589`, `App/Genesyx/UI/Track/TrackView.swift:791,902,953,1245,1410,1465,1534`, `App/Genesyx/UI/Profile/ProfileView.swift:779,848,960`, `App/Genesyx/UI/Nutrition/NutritionView.swift:666,767`, `App/Genesyx/UI/Learn/LearnViews.swift:551`, `App/Genesyx/UI/Learn/FreeGuideView.swift:116`, `App/Genesyx/UI/Ph/PhTrackerSection.swift:510`, `App/Genesyx/UI/Components/CycleSettingsSheet.swift:41`, `App/Genesyx/UI/Components/PlaceholderScreen.swift:9`). There is no `NavigationView` anywhere, and no single app-wide navigation path. **[Verified in code]**

### 4.2 Path-bound stacks and `navigationDestination`

Only two stacks bind a path, both `[String]` of article slugs, and only two `navigationDestination` modifiers exist in the app. **[Verified in code]**

- **Learn**: `NavigationStack(path: $path)` (`App/Genesyx/UI/Learn/LearnViews.swift:73`) with `.navigationDestination(for: String.self)` (`:103`). A slug resolves to one of three destinations: the twelve-week plan (`TwelveWeekPlan.route`), the "How to use" guide (`HowToUseView.route`), or an article (`ArticleDetailView(slug:path:)`) (`:103-111`).
- **Nutrition**: `NavigationStack(path: $articlePath)` (`App/Genesyx/UI/Nutrition/NutritionView.swift:53`) with `.navigationDestination(for: String.self) { ArticleDetailView(slug: $0, path: $articlePath) }` (`:84-86`). The same article view is reached from two tabs.

Everywhere else navigation is `NavigationLink` with an inline destination: `LogHistoryView` from Insights (`App/Genesyx/UI/Insights/InsightsView.swift:167-169`), `PhTrackerScreen` (`:282-284`), a heat-map cell to `LogHistoryView(focusDate:)` (`:730`), and Profile's `navRow` (`App/Genesyx/UI/Profile/ProfileView.swift:575-586`). There is no `Route` enum, no coordinator and no programmatic push other than appending a slug to the two paths. Because a tab keeps its stack alive (3.3), appending a slug from a notification stacks the article on top of whatever the user already had open in that tab **[Inferred]**.

### 4.3 `TabRouter`: cross-tab signals

`TabRouter` is a `@MainActor ObservableObject` created by `MainTabView` and injected into the tab hierarchy (`App/Genesyx/UI/MainTabView.swift:11,41`). It is declared in the Learn views file, not in a navigation file (`App/Genesyx/UI/Learn/LearnViews.swift:7-16`). It has three fields and is read by eight views (`@EnvironmentObject` at `App/Genesyx/UI/Home/HomeView.swift:19`, `App/Genesyx/UI/Track/TrackView.swift:12`, `App/Genesyx/UI/Ph/PhTrackerSection.swift:8`, `App/Genesyx/UI/Nutrition/NutritionView.swift:23`, `App/Genesyx/UI/Learn/LearnViews.swift:56,474,612`, `App/Genesyx/UI/Profile/ProfileView.swift:16`). **[Verified in code]**

| Field | Meaning | Written by | Consumed by |
|---|---|---|---|
| `selection: Int` | Selected tab index | The tab bar (`App/Genesyx/UI/MainTabView.swift:96`); notification taps (`:63`); the literal assignments in 3.4 | `MainTabView.tabContent` (`:71`) and `tabButton` (`:93`) |
| `pendingLearnSlug: String?` | An article to push once Learn is showing | `App/Genesyx/UI/MainTabView.swift:64`; `App/Genesyx/UI/Home/HomeView.swift:407`; `App/Genesyx/UI/Track/TrackView.swift:78`; `App/Genesyx/UI/Profile/ProfileView.swift:509`; `App/Genesyx/UI/Ph/PhTrackerSection.swift:25`; `App/Genesyx/UI/Learn/LearnViews.swift:480` | `LearnLandingView`, which appends to its path and clears the field (`App/Genesyx/UI/Learn/LearnViews.swift:121-125`) |
| `pendingHydration: Bool` | Open the hydration sheet on Track | `App/Genesyx/UI/Home/HomeView.swift:312`; `App/Genesyx/UI/Nutrition/NutritionView.swift:204` | `TrackView` (`App/Genesyx/UI/Track/TrackView.swift:97-98,516-520`) |

The pattern is a one-shot flag: the producer sets it, the consumer acts and clears it. A deep link into an article is two coupled statements, `pendingLearnSlug` and then `selection`. Getting only the first lands the user on the Learn list with no explanation, which is why `HowThisWorksLink` exists as one type that writes both (`App/Genesyx/UI/Learn/LearnViews.swift:466-494`). Anything that deep-links into Learn from a new place should use it or copy its two statements together.

### 4.4 Deep links and notification taps

| Entry | Handler | Result |
|---|---|---|
| Notification tapped, app running or cold | `NotificationService.userNotificationCenter(_:didReceive:)` (`App/Genesyx/Notifications/NotificationService.swift:558-562`) decodes the payload with `NotificationRouter.destination(from:)` (`App/Genesyx/Notifications/NotificationRouter.swift:21-24`) and sets `pendingDestination` | `MainTabView.applyPendingNotification()` (`App/Genesyx/UI/MainTabView.swift:55-56,61-66`) sets `router.selection` and `router.pendingLearnSlug`, then clears the destination |
| Notification tapped while signed out, resolving, or on the consent screen | Same decode; the destination is held on the service | Applied on `MainTabView`'s first appearance, "after authentication, never before" (`App/Genesyx/UI/MainTabView.swift:59-60`). Sign-out drops it (`App/Genesyx/Notifications/NotificationService.swift:66-69`) |
| `genesyx://reset-password` | `RootView.onOpenURL` (`App/Genesyx/Data/App/RootView.swift:64-72`) → `DeepLink.isPasswordRecovery` (`App/Genesyx/Data/App/DeepLink.swift:84-86`) → `receiveRecovery` (`App/Genesyx/Data/App/RootView.swift:122-132`) | Redeems the link; `RootRouting` holds the user on `ResetPasswordView` (`App/Genesyx/Data/App/RootRouting.swift:68`). A failed redemption shows copy rather than silently returning to sign-in (`App/Genesyx/Data/App/RootView.swift:22-26,128-129`) |
| Google OAuth callback | `GIDSignIn.sharedInstance.handle(url)` first in `onOpenURL` (`App/Genesyx/Data/App/RootView.swift:65-67`) | Completes Google sign-in |
| `genesyx://invite/{code}` or `https://genesyx.co.uk/invite/{code}` | `DeepLink.inviteCode(from:)` (`App/Genesyx/Data/App/DeepLink.swift:88-120`), `receiveInvite` (`App/Genesyx/Data/App/RootView.swift:142-149`) | Does nothing in the public release: `guard FeatureFlags.partnerInvites else { return }` (`:143`) |

Notes. **[Verified in code]**

- Only the custom scheme `genesyx` and the reversed Google client ID are registered (`project.yml:69-75`). **Universal Links are off**: `DeepLink.universalLinksLive = false` (`App/Genesyx/Data/App/DeepLink.swift:22`) and `App/Genesyx/Genesyx.entitlements` carries only Sign in with Apple, with a comment explaining the Associated Domains entitlement is deliberately absent because it breaks archiving until the provisioning profile includes it. The `onContinueUserActivity` handler (`App/Genesyx/Data/App/RootView.swift:73-77`) is therefore reachable only after that switch is flipped. The comment at `App/Genesyx/Data/App/DeepLink.swift:66-67` that the entitlement "is present" is out of date.
- URL parsing is host-checked on purpose: any app on the device can open a `genesyx://` URL, so only the shapes the app issues are honoured (`App/Genesyx/Data/App/DeepLink.swift:77-79,89-104`).
- The recovery path raises `passwordRecoveryActive` before the token exchange so `RootRouting` cannot mount the tabs for a frame (`App/Genesyx/Data/SessionRepository.swift:387-400`).
- A DEBUG-only launch argument reproduces a notification tapped while the app was not running (`-uiTestPendingNotification <tab>`, `App/Genesyx/Data/App/GenesyxApp.swift:26-38`). XCUITest cannot deliver a system notification to a cold-launched app (`:27-32`).

### 4.5 What does not exist

No state restoration (no `@SceneStorage`, no `NSUserActivity` for navigation), no route enum, no coordinator, and no per-tab deep-link API beyond `TabRouter`. A search of `App/Genesyx` for `SceneStorage` and `NSUserActivity` finds only the `onContinueUserActivity` handler above. **[Verified in code]**

---

## 5. State management

### 5.1 The mechanisms in use

**[Verified in code]** Counts are over `App/Genesyx/UI` unless stated.

| Mechanism | Count | Used for |
|---|---|---|
| `@EnvironmentObject` | 70 in `UI`, 5 in `App/Genesyx/Data/App/RootView.swift:12-16`; **75 in total**, all concrete classes | Reaching repositories and services from any view |
| `@State` | 127 | View-local state: sheet flags, text input, selections, transient feedback |
| `@StateObject` | 1 in `UI` (`App/Genesyx/UI/MainTabView.swift:11`); 2 at the app root (`App/Genesyx/Data/App/GenesyxApp.swift:6-7`) | Owning a reference type |
| `@Binding` | 4 | Passing a navigation path or a selected set into a child |
| `@FocusState` | 4 | Keyboard focus on numeric fields |
| `@AppStorage` | 14 in `UI`, 1 in `RootView` (`:17`) | Device-local UI preferences and flags |
| `@Environment(\.key)` | 32 across the app: `dismiss` 24, `openURL` 3, `colorScheme` 3, `scenePhase` 1, `accessibilityReduceMotion` 1 | System values |
| `@ObservedObject` | 0 | Not used anywhere in `App/` |
| `@Published` in views | 3, all on `TabRouter` (`App/Genesyx/UI/Learn/LearnViews.swift:10-14`) | Cross-tab signals |

Views hold no business state of their own beyond transient UI state. Anything the user would expect to survive a relaunch lives in a repository (see `docs/TECHNICAL_ARCHITECTURE.md`, sections 4.2 and 8).

### 5.2 `@EnvironmentObject`: thirteen types

**[Verified in code]** The 75 declarations by type:

| Type | Declarations | Provided by |
|---|---|---|
| `DailyLogRepository` | 13 | `withAppEnvironment` |
| `ConsentRepository` | 12 | `withAppEnvironment` |
| `TabRouter` | 8 | `MainTabView` (`App/Genesyx/UI/MainTabView.swift:41`) |
| `SessionRepository` | 7 | `withAppEnvironment` |
| `PhRepository` | 6 | `withAppEnvironment` |
| `AppContainer` | 6 | `withAppEnvironment` |
| `CycleRepository` | 5 | `withAppEnvironment` |
| `PreferencesRepository` | 4 | `withAppEnvironment` |
| `LearnProgress` | 4 | `withAppEnvironment` |
| `Reachability` | 3 | `withAppEnvironment` |
| `NotificationService` | 3 | `GenesyxApp` (`App/Genesyx/Data/App/GenesyxApp.swift:46`) |
| `SupplementsRepository` | 2 | `withAppEnvironment` |
| `PartnerRepository` | 2 | `withAppEnvironment` |

By file, the heaviest are `App/Genesyx/UI/Track/TrackView.swift` (15 declarations across 7 views), `App/Genesyx/UI/Profile/ProfileView.swift` (10), `App/Genesyx/UI/Home/HomeView.swift` (8), `App/Genesyx/UI/Learn/LearnViews.swift` (7) and `App/Genesyx/UI/Nutrition/NutritionView.swift` (6).

Which repositories each tab reads (declarations on the root view and, in brackets, on the sheets and sub-views it presents):

| Tab | Reads |
|---|---|
| Home | cycle, dailyLog, ph, session, learn, consent, container, router |
| Track | cycle, dailyLog, ph, consent, router, container; [reachability in the hydration and sleep sheets; consent in the day sheet] |
| pH | router; [`PhTrackerSection`: ph, consent] |
| Nutrition | cycle, dailyLog, ph, router; [`SupplementPlanSheet`: prefs, supplements] |
| Insights | ph, dailyLog, cycle; [`LogHistoryView`: dailyLog; `WeeklySummaryView`: dailyLog, ph] |
| Learn | router, learn; [`ArticleDetailView`: router, learn, consent, container] |
| Profile | session, prefs, notifications, cycle, router, consent, reachability; [`PartnerSectionView`: session, partner; `TrackingPreferencesSheet`: consent] |
| `MainTabView` | notifications, learn (plus the router it owns) |

`DailyLogRepository` is the most widely read object, so a change to any one day invalidates most of the app (see 5.9).

### 5.3 Where the environment is injected

There are exactly three injection points. **[Verified in code]**

1. `App/Genesyx/Data/App/GenesyxApp.swift:45-46`: `.withAppEnvironment(container)` and `.environmentObject(notifications)` on `RootView`.
2. `App/Genesyx/Data/App/GenesyxApp.swift:79-92`: `View.withAppEnvironment(_:)` puts eleven objects into the environment: the container itself plus `cycle`, `dailyLog`, `ph`, `prefs`, `session`, `partner`, `consent`, `learn`, `reachability` and `supplements`.
3. `App/Genesyx/UI/MainTabView.swift:41`: `.environmentObject(router)`.

`NotificationService` and `TabRouter` are not on the container and are injected by whoever owns them (`App/Genesyx/Data/App/GenesyxApp.swift:77-78`). `withAppEnvironment` takes the container rather than a separate list so the set "cannot drift from the repositories the container actually owns" (`:76-77`). Adding a repository to the container without adding it to this list makes it invisible to views, and the first read traps.

### 5.4 The sheet re-injection problem

**What goes wrong.** A sheet normally inherits the presenter's environment. On the "Designed for iPad" Mac variant, SwiftUI builds the presented `PresentationHostingController` before that inheritance runs, so a sheet's content can start with an empty object container, and the first `@EnvironmentObject` read traps. Build 29 crashed exactly this way: `EXC_BREAKPOINT` in `EnvironmentObject.error()` at `App/Genesyx/UI/Log/LogView.swift:324` at commit `ae70372` (build 29, where the crash was captured; the same `dailyLog.customFoodGroups` read is at `:333` at HEAD `353ff26`), the first line in that view's body to touch the environment. **[Verified in repo docs only]**: the mechanism and the crash are recorded in the code comment at `App/Genesyx/Data/App/GenesyxApp.swift:66-78` and in commit `86260d3`. The crash log itself was not re-read for this document, and the behaviour has not been reproduced on a Mac for this document.

**The fix and the quote.** Commit `86260d3` (8 September 2026, shipped in build 30) added `View.withAppEnvironment(_:)` and applied it at the app root and at the root of the log sheets and the hydration sheet. Re-injecting is a no-op wherever inheritance already works (`App/Genesyx/Data/App/GenesyxApp.swift:66-74`). The commit message is explicit that the fix is partial:

> Not covered: the food groups and supplements sheets presented from NutritionDetailView still rely on inheritance. Both pass on iOS Simulator, so this is left for a later build rather than adding churn to the build 30 cut.

Document this as a known, deliberate partial fix, not as resolved. **[Verified in code]** (`git show 86260d3`).

**The count.** The evidence brief records 10 protected sites against 33 modal presentations. Re-counted at 353ff26:

- **10 call sites of `withAppEnvironment`**, excluding its definition: the app root (`App/Genesyx/Data/App/GenesyxApp.swift:45`), the preview helper (`App/Genesyx/UI/PreviewSupport.swift:40`), and **eight sheet roots** (`App/Genesyx/UI/Home/HomeView.swift:70`, `App/Genesyx/UI/Learn/LearnViews.swift:672`, `App/Genesyx/UI/Track/TrackView.swift:69,70,991`, `App/Genesyx/UI/Log/LogView.swift:103,108,113`). So 8 presented sheets are protected.
- **38 modal presentations** in code (37 `.sheet(` and 1 `.fullScreenCover(`, comments excluded), not 33. The brief's counting method is not recorded, and the difference could not be reproduced. The ratio is 8 protected out of 38.
- Of the 30 unprotected presentations, **18 present content that reads the environment** and 12 do not. One of the 18 is the partner-invite sheet, gated off in the public release, so **17 are reachable in the public iOS release**. That matches the brief's "roughly 17".

The full inventory, in file order. "Wrapped" is **[Verified in code]**. "Reads environment" is **[Inferred]**: it is a static read of the presented view and of the views it directly embeds (for example `PhDetailView` embeds `PhTrackerSection`, and three sheets embed `ConsentWithdrawnBanner`); it does not trace every descendant.

| # | Site | Presents | Wrapped | Reads environment |
|---|---|---|---|---|
| 1 | `App/Genesyx/UI/Home/HomeView.swift:70` | `LogView` | yes | yes (`App/Genesyx/UI/Log/LogView.swift:8-12`) |
| 2 | `App/Genesyx/UI/Home/HomeView.swift:71` | `PregnancyView` (gated off by `FeatureFlags.pregnancyMode`) | no | no |
| 3 | `App/Genesyx/UI/Home/HomeView.swift:72` | `CycleSettingsSheet` | no | **yes** (`App/Genesyx/UI/Components/CycleSettingsSheet.swift:16,46`) |
| 4 | `App/Genesyx/UI/Learn/LearnViews.swift:112` | `LearnSearchView` | no | no |
| 5 | `App/Genesyx/UI/Learn/LearnViews.swift:118` | `FreeGuideScreen` | no | no |
| 6 | `App/Genesyx/UI/Learn/LearnViews.swift:672` | `LogView` | yes | yes |
| 7 | `App/Genesyx/UI/Track/TrackView.swift:63` | `CycleSettingsSheet` | no | **yes** |
| 8 | `App/Genesyx/UI/Track/TrackView.swift:66` | `CycleDetailView` | no | no |
| 9 | `App/Genesyx/UI/Track/TrackView.swift:69` | `LogView` | yes | yes |
| 10 | `App/Genesyx/UI/Track/TrackView.swift:70` | `HydrationDetailSheet` | yes | yes (`:920-924`) |
| 11 | `App/Genesyx/UI/Track/TrackView.swift:74` | `PhDetailView`, embedding `PhTrackerSection` | no | **yes** (`App/Genesyx/UI/Ph/PhTrackerSection.swift:56-57`) |
| 12 | `App/Genesyx/UI/Track/TrackView.swift:82` | `SleepDetailView` | no | **yes** (`:1231-1232`) |
| 13 | `App/Genesyx/UI/Track/TrackView.swift:83` | `SymptomsDetailView` | no | **yes** (`:1401`) |
| 14 | `App/Genesyx/UI/Track/TrackView.swift:84` | `NutritionDetailView` | no | **yes** (`:1437`) |
| 15 | `App/Genesyx/UI/Track/TrackView.swift:87` | `DayDetailSheet` | no | **yes** (`:1748`) |
| 16 | `App/Genesyx/UI/Track/TrackView.swift:991` | `LogView`, from `HydrationDetailSheet` | yes | yes |
| 17 | `App/Genesyx/UI/Track/TrackView.swift:1512` | `SupplementsSheet`, from `NutritionDetailView` | no | **yes** (`App/Genesyx/UI/Log/LogView.swift:570`). Named in the commit message. |
| 18 | `App/Genesyx/UI/Track/TrackView.swift:1515` | `FoodGroupsSheet`, from `NutritionDetailView` | no | **yes** (`:1528`). Named in the commit message. |
| 19 | `App/Genesyx/UI/Log/LogView.swift:101` | `SleepSheet` | yes | no (wrapped regardless) |
| 20 | `App/Genesyx/UI/Log/LogView.swift:106` | `WaterSheet` | yes | yes (`:476`) |
| 21 | `App/Genesyx/UI/Log/LogView.swift:111` | `SupplementsSheet` | yes | yes (`:570`) |
| 22 | `App/Genesyx/UI/Ph/PhTrackerSection.swift:80` | `PhLogSheet` | no | **yes**, through `ConsentWithdrawnBanner` (`:516`) |
| 23 | `App/Genesyx/UI/Ph/PhTrackerSection.swift:94` | `SupplementPlanSheet` | no | **yes** (`App/Genesyx/UI/Nutrition/NutritionView.swift:749-751`) |
| 24 | `App/Genesyx/UI/Nutrition/NutritionView.swift:92` | `SupplementPlanSheet` | no | **yes** |
| 25 | `App/Genesyx/UI/Nutrition/NutritionView.swift:93` | `RecipeSheet` | no | no |
| 26 | `App/Genesyx/UI/Profile/ProfileView.swift:84` | reminder prompt (inline view of `ProfileView`) | no | no (uses the presenter's own objects) |
| 27 | `App/Genesyx/UI/Profile/ProfileView.swift:85` | `AuthView` | no | **yes** (`App/Genesyx/UI/Auth/AuthView.swift:42`) |
| 28 | `App/Genesyx/UI/Profile/ProfileView.swift:86` | `PregnancyView` (gated off) | no | no |
| 29 | `App/Genesyx/UI/Profile/ProfileView.swift:87` | `PersonalDetailsSheet` | no | no |
| 30 | `App/Genesyx/UI/Profile/ProfileView.swift:92` | `CycleSettingsSheet` | no | **yes** |
| 31 | `App/Genesyx/UI/Profile/ProfileView.swift:95` | `TrackingPreferencesSheet` | no | **yes** (`:950,965`) |
| 32 | `App/Genesyx/UI/Profile/ProfileView.swift:103` | `ConsentView` | no | no |
| 33 | `App/Genesyx/UI/Profile/ProfileView.swift:130` | `ChangePasswordSheet` | no | no |
| 34 | `App/Genesyx/UI/Profile/ProfileView.swift:725` | `InviteShareSheet` (partner; gated off) | no | no |
| 35 | `App/Genesyx/UI/Onboarding/OnboardingFlowView.swift:61` | `FreeGuideScreen` | no | no |
| 36 | `App/Genesyx/UI/Onboarding/OnboardingFlowView.swift:68` (`fullScreenCover`) | `AuthView` | no | **yes** |
| 37 | `App/Genesyx/Data/App/RootView.swift:91` | `InviteView` (partner; gated off) | no | **yes** (`App/Genesyx/UI/Invite/InviteView.swift:13-14`); not reachable in the public release |
| 38 | `App/Genesyx/Data/App/RootView.swift:99` | `AuthView` | no | **yes** |

Rows 1, 6, 9, 10, 16, 19, 20 and 21 are the eight wrapped sites. The 18 unwrapped rows that read the environment are rows 3, 7, 11, 12, 13, 14, 15, 17, 18, 22, 23, 24, 27, 30, 31, 36, 37 and 38.

**Status, stated plainly. [Inferred]** The commit message names two uncovered sheets; the static tally finds 18. Whether any of the others traps on the Mac or Vision Pro variant is not known: the commit and its author observed the crash in the log sheet only, and the other sheets passed on the iOS Simulator. A TestFlight crash report from a Mac or Vision Pro run would settle it **[Needs dashboard verification]**; running the sheets in the "Designed for iPad" Mac destination would also settle it.

**The rule for a new sheet.** If the presented content, or anything it embeds, declares an `@EnvironmentObject`, apply `.withAppEnvironment(container)` to the sheet's root and hold `@EnvironmentObject private var container: AppContainer` in the presenter for that purpose. The existing pattern is `.sheet(item: $logTarget) { LogView(date: $0.date).withAppEnvironment(container) }` (`App/Genesyx/UI/Track/TrackView.swift:69`). Five views already hold a `container` only to hand it on: `App/Genesyx/UI/Home/HomeView.swift:17`, `App/Genesyx/UI/Track/TrackView.swift:14,924`, `App/Genesyx/UI/Log/LogView.swift:12` and `App/Genesyx/UI/Learn/LearnViews.swift:616`. They are commented "Held only to hand on to presented sheets". `NotificationService` and `TabRouter` are not re-injected by `withAppEnvironment`, so a sheet that reads either is still exposed.

### 5.5 Sheet state patterns

**[Verified in code]**

- **One piece of state per sheet, as an item.** `.sheet(item:)` with an `Identifiable` value rather than a flag plus a separate "which one" variable, because the pair raced: SwiftUI evaluated the sheet body before the second variable was written (`App/Genesyx/UI/Ph/PhTrackerSection.swift:59-60`). Examples: `LogTarget` (`App/Genesyx/UI/Track/TrackView.swift:1729-1733`), `DayInfo` (`:1721-1727`), `PhSheetMode` (`App/Genesyx/UI/Ph/PhTrackerSection.swift:98-115`), `InvitePresentation` (`App/Genesyx/Data/App/DeepLink.swift:123-127`).
- **Chaining sheets goes through `onDismiss`.** "SwiftUI drops the second sheet if it is raised while the first is still going down", so the day sheet records the day to edit and `onDismiss` opens the log sheet (`App/Genesyx/UI/Track/TrackView.swift:85-96`).
- **Staged inputs versus write-through.** `LogView` stages mood, energy, symptoms, notes, sleep, supplements, intimacy and food groups in `@State`, copied in by `populate()` (`App/Genesyx/UI/Log/LogView.swift:127-140`) and written back together by `save()` (`:154-173`). Water is the exception: it writes through to the repository the moment it is tapped, and `save()` deliberately leaves it out (`:162-164`). `save()` is a read-modify-write on the stored day, so a field the sheet does not show cannot be wiped (`:142-153`).

### 5.6 `@AppStorage` and device-local preferences

Fifteen `@AppStorage` declarations in seven files **[Verified in code]**: `learn_intro_seen` (`App/Genesyx/UI/Learn/LearnViews.swift:58`), the hydration pair, `nutrition_last_seen_phase` (`App/Genesyx/UI/Nutrition/NutritionView.swift:32-33`) and `genesyx.onboardingComplete` (`App/Genesyx/Data/App/RootView.swift:17`).

The hydration pair (unit and glass size, `App/Genesyx/UI/HydrationPrefs.swift:15-16`) is declared as `@AppStorage` in six places: Home (`:29-30`), Track (`:936-937`), Profile (`:34,39`), `LogView` (`:49-50` and `:478-479`) and Nutrition (`:25-26`), each in its own file under `App/Genesyx/UI/`. `@AppStorage` rather than a bare `UserDefaults` read is deliberate: a bare read is not observed, so changing the unit in Profile left Home stale until it was rebuilt (`App/Genesyx/UI/Home/HomeView.swift:27-28`). `HydrationPrefs.current` exists for non-`View` call sites and is not observed (`App/Genesyx/UI/HydrationPrefs.swift:25-30`).

These keys are plain `UserDefaults` keys, outside `LocalStore`, are device-local, and are not wiped on sign-out except `nutrition_last_seen_phase` (`App/Genesyx/Data/App/AppContainer.swift:194`). Moving the hydration settings to the synced profile "is a single coherent change to make with Android" (`App/Genesyx/UI/HydrationPrefs.swift:6-10`).

### 5.7 Consent-aware UI: disable first, explain second

Because the Article 9 gate sits in the repositories, a refused write is silent there. The UI therefore disables the controls that would write, and a banner says why. **[Verified in code]**

- **`ConsentWithdrawnBanner`** (`App/Genesyx/UI/Onboarding/ConsentView.swift:74-91`) renders only after withdrawal. It is placed in eight places: `App/Genesyx/UI/Home/HomeView.swift:41`, `App/Genesyx/UI/Track/TrackView.swift:44`, `App/Genesyx/UI/Components/CycleSettingsSheet.swift:46`, `App/Genesyx/UI/Ph/PhTrackerSection.swift:21,516`, `App/Genesyx/UI/Nutrition/NutritionView.swift:57`, `App/Genesyx/UI/Profile/ProfileView.swift:965` and `App/Genesyx/UI/Log/LogView.swift:77`.
- **Disabling controls** with `.disabled(!consent.isActive)` and reduced opacity: `App/Genesyx/UI/Home/HomeView.swift:58-59`, `App/Genesyx/UI/Track/TrackView.swift:51-52,1766-1767`, `App/Genesyx/UI/Log/LogView.swift:79-80,373-374`, `App/Genesyx/UI/Components/CycleSettingsSheet.swift:88-103`, `App/Genesyx/UI/Ph/PhTrackerSection.swift:77,83,596`, `App/Genesyx/UI/Profile/ProfileView.swift:997`, and the Learn call-to-action `App/Genesyx/UI/Learn/LearnViews.swift:705`.
- **Writers return `Bool`** and the sheets branch on it: `LogView.save()` stays open on a refusal (`App/Genesyx/UI/Log/LogView.swift:167-171`).

Where it is not applied. **[Inferred]** The Track hydration sheet's quick-add and manual-entry controls have no consent check (`App/Genesyx/UI/Track/TrackView.swift:1065-1082,1171-1182`; the sheet declares no `ConsentRepository`, `:920-924`). `applyHydrationChange` shows the "Saved" state for 1.2 s regardless of whether `adjustWater` was accepted. With consent withdrawn, the tap is refused by the repository and the "Saved" label still flashes; the number does not change. The log sheet's water card is disabled for exactly this reason (`App/Genesyx/UI/Log/LogView.swift:366-367`), the Track sheet is not. Nutrition shows the banner (`App/Genesyx/UI/Nutrition/NutritionView.swift:57`) but its food and recipe controls are not disabled: the view itself declares no `ConsentRepository` (`:8-10,23`).

### 5.8 Previews and the environment

`#Preview` blocks are DEBUG-only and live in one file, `App/Genesyx/UI/PreviewSupport.swift:45-57` (13 previews). `withPreviewEnvironment()` routes through `withAppEnvironment` so previews cannot drift from the real environment (`:35-43`), over a seeded container with its own `UserDefaults` suite and no backend (`:12-33`). **[Verified in code]**

It provides the eleven objects only. `TabRouter` and `NotificationService` are not supplied. A preview that reaches a view which reads one of them during body evaluation has no provider. Examples where the read is in the body: `App/Genesyx/UI/Track/TrackView.swift:98` (`router.pendingHydration` in `.onChange`), `App/Genesyx/UI/Learn/LearnViews.swift:121` (`router.pendingLearnSlug`), and `App/Genesyx/UI/MainTabView.swift:46` (`notifications.celebration` in the overlay). **[Inferred]**: the "Track" and "Main Tabs" previews are therefore likely to trap in the Xcode canvas. Not opened in the canvas; check there before relying on them.

### 5.9 Observation granularity

Every repository publishes whole collections: `@Published private(set) var logByDate: [CalendarDate: DailyLog]` (`App/Genesyx/Data/DailyLogRepository.swift:43`), `readings` on `PhRepository` (`App/Genesyx/Data/PhRepository.swift:21`), `settings` on `CycleRepository` (`App/Genesyx/Data/CycleRepository.swift:13`). A view that holds a repository is invalidated by any change to it, not only the part it reads. Combined with the all-tabs-alive structure (3.3), one water tap re-evaluates the bodies of every tab that holds `DailyLogRepository`. **[Inferred]** from `ObservableObject` semantics and the structure above. The measured cost of the heaviest bodies is in `docs/SCALABILITY_REVIEW.md`; the code locations are `App/Genesyx/UI/Track/TrackView.swift:35-37,172`, `App/Genesyx/UI/Insights/InsightsView.swift:30-36,39,71`, `App/Genesyx/UI/Nutrition/NutritionView.swift:44-49,154,158`, `App/Genesyx/UI/Home/HomeView.swift:204` and `App/Genesyx/UI/Insights/InsightsView.swift:833-855` (a history list in a non-lazy `VStack`, filtering and sorting twice per body). **[Verified in code]** for the locations.

---

## 6. Screen inventory

Fourteen feature folders under `App/Genesyx/UI`, plus three loose files. **[Verified in code + measured]** for sizes (line counts by `wc -l`).

| Folder | Files / lines | Main view | Purpose |
|---|---|---|---|
| `App/Genesyx/UI/Auth` | 2 / 698 | `AuthView` (`App/Genesyx/UI/Auth/AuthView.swift:40`, 412 lines) | Email and password sign-in and sign-up, Sign in with Apple, Google, forgot password, resend confirmation, with cooldowns for the project-wide email rate limit, which is 30 per hour on the live project **[Verified live 2026-10-07]**. An earlier version of this row implied the 2-per-hour built-in sender; that was stale repo data (`docs/TESTFLIGHT_B20.md:29`, dated 18 August) and is retracted. Raise the limit before a marketing push or before turning email confirmation on. `ResetPasswordView` (`App/Genesyx/UI/Auth/ResetPasswordView.swift:31`) is the password-recovery screen |
| `App/Genesyx/UI/Components` | 6 / 629 | `App/Genesyx/UI/Components/GenesyxControls.swift` (324 lines) | Shared buttons, eyebrow, page background, brand artwork, milestone celebration, `CycleSettingsSheet`, `CitationLink` and `SourcesFooter`, `FlowLayout`, `ErrorStateView`, `PlaceholderScreen` (see section 8) |
| `App/Genesyx/UI/Home` | 1 / 436 | `HomeView` (`App/Genesyx/UI/Home/HomeView.swift:8`) | Greeting, cycle phase and focus cards (or a setup card), hydration summary, pH nudge, Learn card, "Log today" |
| `App/Genesyx/UI/Insights` | 2 / 1,232 | `InsightsView` (`App/Genesyx/UI/Insights/InsightsView.swift:8`) | Trend cards: consistency, pH, hydration, nutrition consistency, sleep, cycle regularity, symptom patterns, ovulation; "My logs" opens `LogHistoryView` (`:833`). `WeeklySummaryView` (`App/Genesyx/UI/Insights/WeeklySummaryView.swift:8`) |
| `App/Genesyx/UI/Invite` | 2 / 186 | `InviteView` (`App/Genesyx/UI/Invite/InviteView.swift:6`) | Partner invite acceptance and the share sheet. **Gated off** in the public release (`FeatureFlags.partnerInvites`) |
| `App/Genesyx/UI/Learn` | 5 / 2,395 | `LearnLandingView` (`App/Genesyx/UI/Learn/LearnViews.swift:55`) | The article library: landing, search, article detail, twelve-week plan, "How to use" guide, free PDF guide. Also `App/Genesyx/UI/Learn/LearnContent.swift` (32 articles as Swift literals), `App/Genesyx/UI/Learn/LearnModels.swift` (which also holds `FeatureFlags`, `AppGuide`, `LearnLibrary`), `App/Genesyx/UI/Learn/FreeGuideView.swift`, `App/Genesyx/UI/Learn/LearnSourceMap.swift` |
| `App/Genesyx/UI/Log` | 1 / 681 | `LogView` (`App/Genesyx/UI/Log/LogView.swift:6`) | The daily log sheet: mood, energy, symptoms, intimacy, food groups, sleep, water, supplements, notes. Also `SleepSheet` (`:424`), `WaterSheet` (`:473`), `SupplementsSheet` (`:568`) |
| `App/Genesyx/UI/Nutrition` | 1 / 937 | `NutritionView` (`App/Genesyx/UI/Nutrition/NutritionView.swift:6`) | Phase-aware focus foods, recipes, supplement plan, hydration card, water challenge, food log, articles. Also `SupplementAvatar` (`:536`), `RecipeSheet` (`:657`), `SupplementPlanSheet` (`:747`) |
| `App/Genesyx/UI/Onboarding` | 2 / 493 | `OnboardingFlowView` (`App/Genesyx/UI/Onboarding/OnboardingFlowView.swift:7`) | Step machine: splash, intro, Article 9 consent, quiz, readiness summary, then authentication (`:21`). `App/Genesyx/UI/Onboarding/ConsentView.swift` holds the consent screens and `ConsentWithdrawnBanner` |
| `App/Genesyx/UI/Ph` | 1 / 613 | `PhTabView` (`App/Genesyx/UI/Ph/PhTrackerSection.swift:7`) and `PhTrackerSection` (`:44`) | The pH tab, and the tracker card, chart, "product spine" and log sheet, reused as detail views from Track and Insights |
| `App/Genesyx/UI/Pregnancy` | 1 / 61 | `PregnancyView` (`App/Genesyx/UI/Pregnancy/PregnancyView.swift:6`) | A teaser, not a feature. **Gated off** (`FeatureFlags.pregnancyMode`) |
| `App/Genesyx/UI/Profile` | 2 / 1,066 | `ProfileView` (`App/Genesyx/UI/Profile/ProfileView.swift:7`) | Account, consent management, tracking preferences, reminders, hydration unit, theme, about, medical sources (`App/Genesyx/UI/Profile/MedicalSourcesView.swift:5`), sign out, delete account |
| `App/Genesyx/UI/Theme` | 3 / 164 | `GenesyxColor` (`App/Genesyx/UI/Theme/GenesyxColors.swift:29`) | Colour tokens, `Theme` (domain enum to colour mapping, `App/Genesyx/UI/Theme/Theme.swift:6`), the `Font.gx*` type scale |
| `App/Genesyx/UI/Track` | 1 / 1,822 | `TrackView` (`App/Genesyx/UI/Track/TrackView.swift:6`) | Month calendar with phase colours and markers, current-phase card, trackers section opening six detail sheets (cycle, hydration, pH, sleep, symptoms, nutrition), and the day sheet |

Loose files in `App/Genesyx/UI`: `App/Genesyx/UI/MainTabView.swift` (138 lines), `App/Genesyx/UI/PreviewSupport.swift` (58), `App/Genesyx/UI/HydrationPrefs.swift` (31). Folder sums: 698 + 629 + 436 + 1,232 + 186 + 2,395 + 681 + 937 + 493 + 613 + 61 + 1,066 + 164 + 1,822 = 11,413, plus the loose files 227 = 11,640. **[Verified in code + measured]**

Files that are compiled but unreachable in the public release, behind compile-time flags **[Verified in code]**: `InviteView` and `InviteShareSheet` (`FeatureFlags.partnerInvites == false`, `App/Genesyx/UI/Learn/LearnModels.swift:21`), `PregnancyView` (`FeatureFlags.pregnancyMode == false`, `:36`), and the partner section of Profile (`App/Genesyx/UI/Profile/ProfileView.swift:65-67`). They stay compiled because the same Supabase backend serves the Android app, which ships partner linking (`App/Genesyx/UI/Learn/LearnModels.swift:15-17`).

---

## 7. The god-file problem

Five files hold 5,895 of the layer's 11,640 lines, 50.6%. **[Verified in code + measured]**

| File | Lines | Top-level declarations | What is wrong |
|---|---|---|---|
| `App/Genesyx/UI/Track/TrackView.swift` | 1,822 | 17 types and 4 free functions; `TrackView` itself ends at line 521 | Eight private sheets, five non-view types and four shared builders live below the screen they support |
| `App/Genesyx/UI/Learn/LearnContent.swift` | 1,114 | One `let learnArticles: [LearnArticle]` literal (`:14`) holding 32 articles | Content compiled in as code; the first 16 articles came verbatim from the Android repository's `docs/learn/articles.json` (`App/Genesyx/UI/Learn/LearnContent.swift:4-6`; that file is not in this repository) |
| `App/Genesyx/UI/Profile/ProfileView.swift` | 1,031 | 5 types | Four sheets and sections in one file |
| `App/Genesyx/UI/Insights/InsightsView.swift` | 991 | 13 types and one `extension DailyLog` | Nine private cards in one file |
| `App/Genesyx/UI/Nutrition/NutritionView.swift` | 937 | 4 types and a `private extension NutritionView` (`:548`) | `SupplementPlanSheet` is shared with the pH tab but lives here |

Two test files are the same problem: `App/GenesyxTests/RepositoryTests.swift` (2,768 lines) and `App/GenesyxUITests/GenesyxUITests.swift` (1,933 lines) are 4,701 lines, 13.5% of all Swift in the repository (34,899). **[Verified in code + measured]**

The most depended-upon types, which is where a change spreads: `CalendarDate` is referenced in 30 production files, `GenesyxColor` in 30, and `DailyLog` in 19 (fresh word-boundary search over `App/Genesyx` and `Sources/GenesyxCore`; the evidence brief records 29, 29 and 20, within one file and a difference of method). **[Verified in code]**

### 7.1 `App/Genesyx/UI/Track/TrackView.swift`: everything that can be extracted

Line ranges are from the file's own structure (`graft skeleton` of the file, cross-checked against the cited lines). Each type below is used only inside `App/Genesyx/UI/Track/TrackView.swift`, except where the last column says a unit test reaches it. Most are `private struct`; moving one to its own file means relaxing `private` to internal. **[Verified in code]**

| Lines | Type | Kind | Suggested home | Reached by unit tests |
|---|---|---|---|---|
| 6-521 | `TrackView` | the screen | stays; shrinks to about 520 lines | no |
| 523-635 | `TrackSignalSummary` | value type **holding a SwiftUI `Color`** (`:528`) and `GenesyxColor` tints | a new file, `App/Genesyx/UI/Track/TrackSignalSummary.swift`. **Not Core**: it carries a `Color` | `App/GenesyxTests/HydrationInsightTests.swift` |
| 637-665 | `SleepTrackingData` | pure logic over `DailyLog` | Core candidate (`Sources/GenesyxCore/Tracking` or `Insights`) | `App/GenesyxTests/HydrationInsightTests.swift` |
| 667-677 | `SleepHistoryRow` | pure value | Core candidate, with the above | no |
| 679-760 | `CyclePredictionCopy` | pure copy over Core types (`Phase`, `DayType`, `DayMarker`) | Core candidate (`Sources/GenesyxCore/Content` or `Cycle`) | `App/GenesyxTests/RealInsightsTests.swift` |
| 762-781 | `SparkDots` | private view | `App/Genesyx/UI/Track/` components | no |
| 783-895 | `CycleDetailView` | private sheet | its own file | no |
| 897-915 | `PhDetailView` | private sheet, embeds `PhTrackerSection` | its own file | no |
| 919-1206 | `HydrationDetailSheet` | private sheet, 288 lines | its own file | no |
| 1208-1228 | `HydrationHistoryRow` | pure value | Core candidate | `App/GenesyxTests/HydrationInsightTests.swift` |
| 1230-1364 | `SleepDetailView` | private sheet | its own file | no |
| 1400-1434 | `SymptomsDetailView` | private sheet | its own file | no |
| 1436-1521 | `NutritionDetailView` | private sheet | its own file | no |
| 1526-1636 | `FoodGroupsSheet` | private sheet | its own file | no |
| 1723-1727 | `DayInfo` | `Identifiable` wrapper | with `DayDetailSheet` | no |
| 1730-1733 | `LogTarget` | `Identifiable` wrapper, used by `TrackView` and `HydrationDetailSheet` | shared internal file | no |
| 1735-1822 | `DayDetailSheet` | private sheet | its own file | no |
| 1366-1398, 1641-1674, 1676-1708, 1710-1719 | `sleepHistoryCard`, `todayCard`, `detailHistoryCard`, `insightCard` | private free functions shared by the detail sheets | one new file, `App/Genesyx/UI/Track/TrackDetailComponents.swift` | no |

A correction to the evidence brief, from re-reading the file: the brief lists `TrackSignalSummary` among the non-view types that belong in Core. It cannot move as written, because it stores a SwiftUI `Color` (`App/Genesyx/UI/Track/TrackView.swift:528`) and builds it from `GenesyxColor` (`:532-625`), and Core has no SwiftUI. It can move to its own UI file. The other four (`SleepTrackingData`, `SleepHistoryRow`, `CyclePredictionCopy`, `HydrationHistoryRow`) show no SwiftUI types in their ranges and are Core candidates. This is a static read; confirm by compiling the move. **[Verified in code]** for the contents of the ranges; whether Core is the right home is a design judgement.

### 7.2 The others

- **`App/Genesyx/UI/Profile/ProfileView.swift`**: `PartnerSectionView` (`:610-756`, gated off), `PersonalDetailsSheet` (`:760-823`), `ChangePasswordSheet` (`:831-935`), `TrackingPreferencesSheet` (`:942-1031`). The screen itself spans `:7-606`.
- **`App/Genesyx/UI/Insights/InsightsView.swift`**: nine private cards, `ConsistencyCard` (`:203`), `PhInsightsCard` (`:270`), `HydrationInsightsCard` (`:401`), `NutritionConsistencyCard` (`:484`), `SleepCard` (`:558`), `CycleRegularityCard` (`:626`), `SymptomPatternsCard` (`:676`), `OvulationCard` (`:749`), `LogHistoryCard` (`:892`); plus `LogHistoryView` (`:833`) and `PhTrackerScreen` (`:816`), which are navigation destinations rather than cards, and `DailyLog.isBlank` (`:976-991`), which is domain logic in a view file.
- **`App/Genesyx/UI/Nutrition/NutritionView.swift`**: `SupplementPlanSheet` (`:747-937`, 191 lines) is presented from Nutrition (`:92`) and from the pH tab (`App/Genesyx/UI/Ph/PhTrackerSection.swift:94`), so it is a shared component sitting in one feature's file. `SupplementAvatar` (`:536`) is similar.
- **`App/Genesyx/UI/Learn/LearnContent.swift`**: each of the 32 `LearnArticle` literals carries its body as `ArticleBlock` values (`App/Genesyx/UI/Learn/LearnModels.swift:82-87`). Moving them to a bundled resource needs `Codable` for the article and block types and a loader. There is precedent for a JSON source on Android and in this app (`App/Genesyx/Resources/medical_sources.json`, loaded by `App/Genesyx/Services/MedicalSourceStore.swift:5-23`).
- **`App/Genesyx/UI/Learn/LearnModels.swift`** holds three things that are not Learn: `FeatureFlags` (`:6-42`), `AppGuide` (`:166-222`) and `LearnLibrary` (`:226-315`). `FeatureFlags` is read by the data layer (`docs/TECHNICAL_ARCHITECTURE.md`, section 5.3); `TabRouter` sits in `App/Genesyx/UI/Learn/LearnViews.swift:8-16` for the same accidental reason.

A sensible extraction order, lowest risk first **[Inferred]**: the private sheets in `App/Genesyx/UI/Track/TrackView.swift` that no unit test reaches (all eight; `LogTarget` must move first or with them because `HydrationDetailSheet` uses it), then shared builders, then the pure types (move their existing tests with them), then `FeatureFlags` and `TabRouter` to neutral files, then content to a resource.

---

## 8. Reusable UI patterns

### 8.1 What exists

| Piece | Defined at | Used | Notes |
|---|---|---|---|
| `Eyebrow` | `App/Genesyx/UI/Components/GenesyxControls.swift:78-93` | 44 call sites | ALL-CAPS section label, `Font.gxEyebrow`, tracking 1.6 |
| `GxPrimaryButton` | `App/Genesyx/UI/Components/GenesyxControls.swift:96-119` | 20 | Pill, height 56, radius 28; `enabled:` and optional leading and trailing SF Symbol. Consent gating is done by the caller with `.disabled` and `.opacity` |
| `GxGhostButton` | `App/Genesyx/UI/Components/GenesyxControls.swift:122-135` | 11 | Low-emphasis text button |
| `GxBackButton` | `App/Genesyx/UI/Components/GenesyxControls.swift:138-149` | 5 | 44 pt hit area |
| `GxOptionPill` | `App/Genesyx/UI/Components/GenesyxControls.swift:152-187` | 2 | Selectable row with trailing radio; quiz |
| `BrandOrb`, `BrandEgg` | `App/Genesyx/UI/Components/GenesyxControls.swift:190,216` | 1 and 4 | Decorative brand artwork |
| `MilestoneCelebrationView` | `App/Genesyx/UI/Components/GenesyxControls.swift:264` | 1 (`MainTabView` overlay) | |
| `gxPageBackground()` | `App/Genesyx/UI/Components/GenesyxControls.swift:35-66` | 11 | Backdrop for the seven tab screens; sheets keep the flat fill (`:32-34`); art opacity is one constant (`:44`) |
| `gxKeyboardDoneToolbar()` | `App/Genesyx/UI/Components/GenesyxControls.swift:17-30` | 4 | "Done" above numeric keyboards. Apply once per hierarchy, or you get two Dones (`:14-16`) |
| `gxHourLabel(_:)` | `App/Genesyx/UI/Components/GenesyxControls.swift:70-75` | 4 | Locale-aware hour label shared by Profile and the plan |
| `FlowLayout` | `App/Genesyx/UI/Components/FlowLayout.swift:4` | 4 | iOS 16 `Layout`; wrapping chips (symptoms, food groups) |
| `ConsentWithdrawnBanner` | `App/Genesyx/UI/Onboarding/ConsentView.swift:74-91` | 8 | Explains a disabled recording control (5.7) |
| `HowThisWorksLink` | `App/Genesyx/UI/Learn/LearnViews.swift:473-494` | 4 (Home, Track, Nutrition, Insights) | The two-statement deep link into Learn as one type (4.3) |
| `CitationLink`, `SourcesFooter` | `App/Genesyx/UI/Components/CitationLink.swift:4,28` | 2 and 3 | Medical source links, backed by `MedicalSourceStore` (`App/Genesyx/Models/MedicalSource.swift:3`: shown next to a health claim, App Store guideline 1.4.1) |
| `CycleSettingsSheet` | `App/Genesyx/UI/Components/CycleSettingsSheet.swift:7` | 3 (Home, Track, Profile) | The only editor sheet shared between tabs |
| `SupplementPlanSheet`, `SupplementsSheet`, `SupplementAvatar` | `App/Genesyx/UI/Nutrition/NutritionView.swift:747,536`; `App/Genesyx/UI/Log/LogView.swift:568` | 2, 2, 2 | Shared but filed under a single feature (section 7) |
| `GenesyxColor` | `App/Genesyx/UI/Theme/GenesyxColors.swift:29-104` | 30 files | Semantic tokens that adapt to dark mode via `Color.adaptive(light:dark:)` (`:16-24`) and brand tokens that do not; contrast-tuned calendar and marker colours with the measured ratios in their comments (`:67-97`) |
| `Theme` | `App/Genesyx/UI/Theme/Theme.swift:6-38` | | The only place domain enums (`DayType`, `PhStatus`, `FoodAccent`) become colours; `Theme.cardRadius = 28` |
| `Font.gx*` | `App/Genesyx/UI/Theme/Typography.swift:12-22` | | Nine fixed sizes (`gxDisplayLarge` 32 down to `gxEyebrow` 11, `gxPhValue` 48) |
| `HydrationPrefs` | `App/Genesyx/UI/HydrationPrefs.swift:14-31` | 6 views | Keys and accessors for the unit and glass size |

All of the above **[Verified in code]**. Counts are call sites found by search.

### 8.2 What does not exist, and its cost

- **No shared card.** There is no `ViewModifier` and no custom `ButtonStyle` anywhere in `App/Genesyx` (`buttonStyle(.plain)` appears 83 times). The card treatment, `GenesyxColor.card` background plus a rounded clip, is written out inline: `GenesyxColor.card` appears 94 times in `App/Genesyx/UI` and `Theme.cardRadius` 29 times, alongside `RoundedRectangle(cornerRadius: 16)` 44 times. Card builders exist only as private helpers inside single files: `todayCard`, `detailHistoryCard` and `insightCard` in `App/Genesyx/UI/Track/TrackView.swift:1641-1719`, and `cardGroup` in `App/Genesyx/UI/Profile/ProfileView.swift:558`. A visual change to cards is a search-and-edit across the UI. **[Verified in code]**
- **Two unreferenced components.** `ErrorStateView` (`App/Genesyx/UI/Components/ErrorStateView.swift`, 31 lines) and `PlaceholderScreen` (`App/Genesyx/UI/Components/PlaceholderScreen.swift`, 28 lines, "Temporary screen for tabs not yet translated") are not referenced from any file in `App`, `Sources` or `Tests`. They are the intended loading and error surfaces, and nothing uses them: screens handle their own empty and error states. **[Verified in code]**
- **No Dynamic Type** (section 2) and **no shared loading state.**
- **Accessibility identifiers are conventional but unenforced.** 118 `accessibilityIdentifier` calls in `App/Genesyx`, mostly lowercase dotted `area.name` (`log.save`, `consent.agree`, `root.updateRequired.update`); tab buttons use their visible title (`App/Genesyx/UI/MainTabView.swift:111`). The UI tests depend on these strings. **[Verified in code]**

### 8.3 Conventions to follow when adding UI

Observed rather than documented anywhere **[Verified in code]**:

- Tab screens: `.padding(.horizontal, 20)`, `.gxPageBackground()`, `Font.gx*`, colours only from `GenesyxColor`.
- Sheets: flat `GenesyxColor.background`, their own `NavigationStack`, a "Done" or "Close" toolbar button, `.presentationDetents` where a half sheet is wanted (nine uses).
- Anything that records data: disable-first plus `ConsentWithdrawnBanner` (5.7), and branch on the repository's `Bool`.
- Copy: UK English, and the app's user-facing copy avoids dashes (a house rule, [Supplied context]; code comments do not follow it).

---

## 9. Where to add a new feature

### 9.1 A new `DailyLog` metric (the measured case)

This is the commonest change and the most expensive one, because a metric is restated at every layer and nothing links the copies at compile time.

**Measured cost. [Verified in code + measured]** Files that mention each field today, by layer (Swift files; fresh count at 353ff26):

| Field | Core | Data | UI | Notifications | App unit tests | Core tests | UI tests | Swift files | Also |
|---|---|---|---|---|---|---|---|---|---|
| `sexualActivity` | 4 | 2 | 3 | 1 | 3 | 2 | 1 | **16** | migration `supabase/migrations/20260810_daily_logs_sexual_activity.sql` |
| `sleepMinutes` | 4 | 4 | 4 | 0 | 3 | 3 | 0 | **18** | column in `docs/supabase_schema.sql:99` |
| `foodGroups` | 4 | 5 | 4 | 1 | 3 | 3 | 1 | **21** | migration `supabase/migrations/20260812_daily_logs_food_groups.sql` |

So adding one metric touches **16 to 21 Swift files** plus one SQL file, **17 to 22 files** in all, of which 10 to 14 are production and 6 to 7 are tests. The evidence brief quotes 15 to 21 (17, 19 and 21 for the same three fields). The ranges overlap; the difference is whether the SQL or schema document is counted, and the lower bound depends on how many surfaces the metric reaches. The counts include surfaces added after a field first shipped. At introduction, `sexualActivity` touched 12 code, test and SQL files over two commits on the same day: `f082d31` (data layer, tests, migration) and `ca28088` (log sheet, notification and streak changes, UI test). **[Verified in code]** (`git show --stat`).

**The walkthrough.** `X` is the new metric. Paths are in the order to edit them; line numbers point at the place to copy from.

0. **Decide before coding.** `daily_logs` is shared with the Android app, so a new column is a cross-platform schema change. Decide whether `X` counts as "a meaningful log". That predicate is the cross-platform streak contract: if it counts, Android must change in the same release; if it does not, iOS-only surfaces fold it in separately, as `sexualActivity` is (`App/Genesyx/Notifications/NotificationService.swift:218,246` and `App/Genesyx/UI/Insights/InsightsView.swift:976-991`). **[Verified in code]** (`Sources/GenesyxCore/Tracking/TrackingEngine.swift:27-31`).
1. **SQL migration.** New file `supabase/migrations/2026MMDD_daily_logs_<x>.sql`. Copy `supabase/migrations/20260810_daily_logs_sexual_activity.sql:16-17`: `alter table public.daily_logs add column if not exists ... not null default ...`, so every existing row is valid the moment it runs. RLS needs no change (policy `daily_logs_owner` covers the whole row, `docs/supabase_schema.sql:158-161`); run the policy check in the migration's verify section (`:34` onward). Migrations are applied by hand (`:12`), and this one must be live **before** the build that sends the column ships (`docs/TECHNICAL_ARCHITECTURE.md`, section 9.5, item 9).
2. **Core model.** `Sources/GenesyxCore/Models/DailyLog.swift`: stored property (`:35-64`), initialiser parameter with a default (`:66-76`), assignment (`:77-85`). The default keeps every existing call site compiling.
3. **Core rules, only if `X` affects streaks, markers or insights.** The same edit in both predicates: `Sources/GenesyxCore/Tracking/TrackingEngine.swift:43-47` and `Sources/GenesyxCore/Streaks/StreakEngine.swift:53-57`. They were edited in different commits for the same field (`f082d31` and `ca28088`) and a third copy drifted (`App/Genesyx/UI/Insights/InsightsView.swift:976-991`). For a calendar dot, `Sources/GenesyxCore/Tracking/DayMarkers.swift:17-44`. Insight logic goes in `Sources/GenesyxCore/Insights/`.
4. **Persistence DTO.** `App/Genesyx/Data/PersistenceDTOs.swift`: an **optional** property with a default in `DailyLogDTO` (`:7-21`), then the `dto` mapper (`:23-37`) and the `domain` mapper (`:39-53`). Optional, so data written by older builds still decodes; a failed decode reads as "nothing stored" (`docs/TECHNICAL_ARCHITECTURE.md`, section 8.1).
5. **Remote row.** `App/Genesyx/Data/Remote/RemoteModels.swift`, `DailyLogRow`: property (`:135-154`), `CodingKeys` (`:156-165`), `domain` (`:167-179`), `init` (`:181-194`). Optional on decode.
6. **Repository mutator, if the value needs clamping or merging.** `App/Genesyx/Data/DailyLogRepository.swift`: copy `setSleep` (`:178-183`) or `toggleFoodGroup` (`:138-142`). Every mutator is a read-modify-write that ends in `upsert` (`:107-118`), so the consent gate, the owed set, persistence and the push are inherited. Do not touch the sync path.
7. **Input.** `App/Genesyx/UI/Log/LogView.swift`: a `@State` (`:30-38`), `populate()` (`:127-140`), `save()` (`:154-173`), and a section view in the `body` list (`:63-69`; sections at `:182-420`, `intimacySection` at `:293` is the simplest to copy). If the control opens its own sheet, wrap that sheet with `.withAppEnvironment(container)` as at `:101-115` (rule in 5.4).
8. **Display surfaces.** `App/Genesyx/UI/Track/TrackView.swift`: the day summary `DayDetailSheet.loggedSummary` (`:1804-1821`), and if `X` is a marker, the calendar cell and legend (`:166-290`, `:338`); if it deserves a tracker tile, `TrackSignalSummary` (`:523-635`) and a detail sheet. `App/Genesyx/UI/Insights/InsightsView.swift`: `LogHistoryCard` (`:897-945`) and `DailyLog.isBlank` (`:976-991`), so a day with only `X` is not dropped from the history list.
9. **iOS-only nudges, if relevant.** `App/Genesyx/Notifications/NotificationService.swift:208-249` (`snapshot()` and `lastActivityDay`).
10. **Seeds and previews.** `AppContainer.uiTestSeeded()` (`App/Genesyx/Data/App/AppContainer.swift:206-294`) and `AppContainer.previewSeeded` (`App/Genesyx/UI/PreviewSupport.swift:12-32`), if screenshots or tests should show `X`.
11. **Tests.** `Tests/GenesyxCoreTests/Tracking/MeaningfulLogTests.swift` (the predicate; the contract guard is at `:47`) and `Tests/GenesyxCoreTests/Tracking/DayMarkersTests.swift`; `App/GenesyxTests/PersistenceTests.swift` (DTO round trip and legacy decode); `App/GenesyxTests/RepositoryTests.swift` (the fake `FakeDailyLogBackend` is at `:2674`); `App/GenesyxUITests/GenesyxUITests.swift` if there is UI.
12. **Release order.** Migration live, then archive and upload. The reverse breaks every daily-log push until the migration lands.
13. **Check completeness** with `grep -rl <field> App Sources Tests supabase` (and the snake_case column name). Compare the layers present in the output with the table above; a missing layer means a copy was not updated.

**Traps.**

- The `okay` mood is the cautionary tale for enums. The persisted value is the enum's `rawValue` (`App/Genesyx/Data/PersistenceDTOs.swift:26`, `App/Genesyx/Data/Remote/RemoteModels.swift:184`), **[Verified in code]**; the SQL `CHECK` in the schema document lists `'okay'` (`docs/supabase_schema.sql:96`), **[Verified in repo docs only]**, because that document is stale against the live schema. The comment on `Mood.id` says "`okay` persists as `ok`" (`Sources/GenesyxCore/Models/DailyLog.swift:7-15`), but nothing writes `id`, **[Verified in code]**. Persist `rawValue` and make the `CHECK` agree. What Android writes is **[Needs verification against the Android repository]**.
- A `Set<String>` field persists as an array and its order is not stable.
- If `save()` in `LogView` does not set the field, the stored value is preserved (the read-modify-write protects it) but the user's edit is silently dropped. If `populate()` does not load it, the control shows empty and the next save writes the empty value back.
- Never write to `logByDate` directly; go through a repository method so the consent gate and the owed set apply.

### 9.2 A new screen inside an existing tab

1. Put the view in the tab's folder under `App/Genesyx/UI/`. Declare only the environment objects it needs, from the thirteen types in 5.2.
2. Reach it with a `NavigationLink` inside the tab's `NavigationStack` (the pattern at `App/Genesyx/UI/Insights/InsightsView.swift:166-188`), or with a sheet (rule 5.4). For an article-like destination in Learn or Nutrition, append a slug to the tab's path instead.
3. Use `.gxPageBackground()` for a tab-level screen and the flat background for a sheet; `Font.gx*`; `GenesyxColor` only; 20 pt horizontal padding.
4. If it records anything: `.disabled(!consent.isActive)` plus `ConsentWithdrawnBanner()`, and branch on the repository's `Bool` (5.7).
5. Add `accessibilityIdentifier`s in the dotted `area.name` form for anything a test must tap.
6. One screen per file. If a file passes about 400 lines or holds more than one screen, split it before it joins the list in section 7.
7. A `#Preview` in `App/Genesyx/UI/PreviewSupport.swift` works only if the view reads none of `TabRouter` or `NotificationService` in its body (5.8).

### 9.3 A new sheet

Apply `.withAppEnvironment(container)` if the content or anything it embeds declares an `@EnvironmentObject` (5.4); wrap it in its own `NavigationStack`; use `.presentationDetents` for a partial height; present it from the screen that owns the task rather than switching tabs (3.3, item 3); and chain a second sheet through `onDismiss` (5.5).

### 9.4 A new tab

An eighth tab does not fit: the comment records about 53 pt per tab for seven against a widest label of about 48 pt on a 375 pt device (`App/Genesyx/UI/MainTabView.swift:3-9`), and 375 / 8 is about 47 pt **[Inferred]** arithmetic, so this is a design change (a "More" tab, or removing one) before it is a code change. The code places to edit, because tab identity is a bare integer (3.4):

1. `MainTabView.items` (`App/Genesyx/UI/MainTabView.swift:17-25`) and the `ZStack` of `tabContent` calls (`:30-36`).
2. `MainTabView.learnTab` (`:15`) if indices shift.
3. `NotificationTab` (`App/Genesyx/Notifications/NotificationContent.swift:45-47`), if notifications may open it.
4. The nine literal `router.selection = N` assignments (3.4), if any index shifts.
5. The tab's own `NavigationStack`, `.gxPageBackground()` and, if it reads the router, the `TabRouter` environment object.
6. `-uiTestTab` and the mapping comment in `App/GenesyxUITests/GenesyxUITests.swift:13`, and any test that taps a tab by title.

### 9.5 A new synced entity

See `docs/TECHNICAL_ARCHITECTURE.md`, section 13.

---

## 10. Testing hooks: the launch-argument system

The UI tests drive the app through launch arguments read in DEBUG builds. They are the only supported way to put the app in a known state without a network. **[Verified in code]** for every row.

All of it is inside `#if DEBUG` (`App/Genesyx/Data/App/GenesyxApp.swift:12-20,26-38`, `App/Genesyx/UI/MainTabView.swift:131-137`) and `AppContainer.uiTestSeeded()` is "never compiled into Release builds" (`App/Genesyx/Data/App/AppContainer.swift:202-205`).

### 10.1 The flags

| Flag | Read at | Effect |
|---|---|---|
| `-uiTestSeed YES` | `App/Genesyx/Data/App/GenesyxApp.swift:13` | Builds `AppContainer.uiTestSeeded()` instead of `AppContainer()` (`:14`). Wipes the app's defaults, seeds data, signs in, marks onboarding complete. Backend-less: the container is built with `backend: nil` (`App/Genesyx/Data/App/AppContainer.swift:219`) |
| `-uiTestKeepStore YES` | `App/Genesyx/Data/App/AppContainer.swift:213` | Second half of a cold-relaunch test: the same local-only container, reading whatever the previous launch left, with no wipe and no seed (`:207-215`). Still backend-less: "no test may point at the shared production project" (`:211-212`) |
| `-uiTestTheme dark`, `light` or `system` | `App/Genesyx/Data/App/AppContainer.swift:236` | Sets `prefs.themeMode`. Applied on every seeded launch, defaulting to `.light`, because the wipe leaves `theme_mode` readable in-process and one dark run used to leave dark mode latched for every later seeded launch (`:225-237`). No UI test passes it; it exists for manual dark-mode QA |
| `-uiTestNoCycle YES` | `App/Genesyx/Data/App/AppContainer.swift:240` | Skips the seeded cycle, for the user who skipped cycle setup (`:238-242`) |
| `-uiTestOnboarding YES` | `App/Genesyx/Data/App/AppContainer.swift:260` | Does not sign in and leaves onboarding un-run, so the quiz can be driven (`:262-267`) |
| `-uiTestSignedOut YES` | `App/Genesyx/Data/App/AppContainer.swift:261` | Does not sign in; onboarding is marked complete, so the app lands on mandatory auth |
| `-uiTestPhaseChange YES` | `App/Genesyx/Data/App/AppContainer.swift:271` | Backdates `nutrition_last_seen_phase` to the phase before the seeded cycle day, so the phase-change card is due (`:268-273`) |
| `-uiTestMilestone YES` | `App/Genesyx/Data/App/AppContainer.swift:278` | Adds six backdated food-group-only days, giving a 7-day logging streak and a 1-day hydration streak (`:274-283`). Without it every milestone is pre-marked celebrated, so a celebration cannot open over the tab bar and swallow taps in unrelated tests (`:284-292`) |
| `-uiTestPendingNotification <n>` | `App/Genesyx/Data/App/GenesyxApp.swift:33` | Seeds `pendingDestination` for tab `n` (0 to 6) through the same decode the real `didReceive` handler uses (`:26-38`), reproducing a notification tapped while the app was not running |
| `-uiTestTab <n>` | `App/Genesyx/UI/MainTabView.swift:133` | Initial selected tab, 0 to 6; always Home in Release (`:131-137`) |

Usage across the UI tests (count of occurrences of each argument in `App/GenesyxUITests`): `-uiTestSeed` 37, `-uiTestTab` 23, `-uiTestSignedOut` 9, `-uiTestKeepStore` 4, `-uiTestOnboarding` 3, `-uiTestNoCycle` 3, `-uiTestPhaseChange` 2, `-uiTestPendingNotification` 2, `-uiTestMilestone` 2, `-uiTestTheme` 0.

### 10.2 What the seed contains

`AppContainer.uiTestSeeded()` (`App/Genesyx/Data/App/AppContainer.swift:206-294`), in order: wipe the app's `UserDefaults` domain (`:216-218`); build a backend-less container (`:219`); grant consent first, because the seed is health data and the gate would refuse it otherwise (`:220-224`); set the theme (`:236`); a cycle with the last period 8 days ago, length 28 and period length 5 (`:240-242`); 750 ml of water today (`:243`); two past logs, yesterday and three days ago, with mood, energy, symptoms, sleep, supplements, notes and water (`:244-253`); three pH readings (`:254-256`); sign in as a fixed example user unless onboarding or signed-out was asked for (`:258-264`); mark onboarding complete (`:267`); then the optional phase-change and milestone adjustments. The sign-in is the repository's DEBUG-only local sign-in, which verifies nothing (`App/Genesyx/Data/SessionRepository.swift:223-228`). No real credentials are involved. **[Verified in code]**

### 10.3 How the tests launch the app

The standard helper (`App/GenesyxUITests/GenesyxUITests.swift:14-19`):

```swift
app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
app.launch()
```

A second helper leaves onboarding un-run (`:22-27`). **Every flag takes the `-key YES` form.** `uiTestSeeded()` reads them with `UserDefaults.standard.bool(forKey:)`, which sees only the argument domain, so a bare `-uiTestSignedOut` is silently ignored and the app comes up in its previous state, which looks like a seeding bug (`to do list.md:572-576`, **[Verified in repo docs only]**; the reading mechanism is **[Verified in code]**).

Tests locate controls by `accessibilityIdentifier` (118 in the app) and by visible titles, notably the tab titles. The suite has 9 files in `App/GenesyxUITests`: `AuthGateUITests`, `CitationE2ETests`, `CustomerWalkthroughUITests`, `DemoWalkthroughTests`, `GenesyxUITests` (1,933 lines), `LifecycleE2ETests`, `NotificationFlowUITests`, `SleepSmokeUITests` and the untracked `TempPhPlanDemo`. Run results reported by the analysis pass on 2026-10-07 (not re-run for this document): 86 pass, 1 skip, 1 known-benign failure, in about 18 minutes.

### 10.4 Unit-test and preview seams

- `LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)` isolates storage per test (`App/GenesyxTests/BackendSwapTests.swift:17-19`).
- `AppContainer(store:backend:monitorNetwork:)` takes an injected store and backend; `monitorNetwork: false` keeps tests off the host's connectivity (`App/Genesyx/Data/App/AppContainer.swift:27-32`). `Reachability.simulate(online:)` drives the reconnect path without a network (`App/Genesyx/Data/Reachability.swift:49-51`).
- `NotificationService.readAuthorizationStatus` is injectable, so the denied path is testable regardless of the host simulator (`App/Genesyx/Notifications/NotificationService.swift:35-39`).
- `RootRouting.destination` and `VersionGate` are pure so the gate is testable without SwiftUI (`App/Genesyx/Data/App/RootRouting.swift:11-13,80-84`); `NotificationRouter` and `DeepLink` likewise.
- Backends are protocol-typed, so tests use fakes, for example `FakeDailyLogBackend` (`App/GenesyxTests/RepositoryTests.swift:2674`).
- Previews use `AppContainer.previewSeeded` with its own `UserDefaults` suite (`App/Genesyx/UI/PreviewSupport.swift:12-33`).

### 10.5 Hazards

1. **`App/GenesyxUITests/TempPhPlanDemo.swift` is untracked and contains `Thread.sleep(forTimeInterval: 60)` at line 30.** `project.yml` includes the whole `App/GenesyxUITests` folder (`project.yml:169-170`), so the next `xcodegen generate` adds it to the UI target and every UI run gains a silent minute. **[Verified in code]**
2. **`testDemoWalkthrough` fails immediately when `DEMO_PASSWORD` is not set**: the guard and `XCTFail` are at `App/GenesyxUITests/DemoWalkthroughTests.swift:55-57`, before any UI is touched (the analysis pass reported line 49; in the working tree the guard is at lines 56-57). `project.yml` forwards `DEMO_PASSWORD` and `DEMO_EMAIL` from the environment and keeps only the reference, never the value (`project.yml:192-196`). It signs in as a separate QA account. This is the known-benign failure. **[Verified in code]**
3. **A cold-launched app cannot be given a system notification by XCUITest**, which is why `-uiTestPendingNotification` exists (`App/Genesyx/Data/App/GenesyxApp.swift:27-32`).
4. **`removePersistentDomain` does not clear everything in-process.** The seed's wipe leaves some keys readable in the same process (`theme_mode`, `onboardingComplete`), which is why the seed re-sets them explicitly on every launch (`App/Genesyx/Data/App/AppContainer.swift:225-237,265-267`).
5. **The build target for unit tests is `GenesyxAppTests`** though the folder is `App/GenesyxTests` (`project.yml:154-158`).

---

## 11. Known frontend debt

Facts about the code at 353ff26, with where each is analysed.

| # | Debt | Evidence | Analysed in |
|---|---|---|---|
| 1 | Sheet environment injection is partial: 8 of 38 modal presentations wrapped; 17 reachable unprotected presentations read the environment | Section 5.4 | this document; Mac verification needed |
| 2 | God files; TrackView holds 17 top-level types | Section 7 | this document |
| 3 | Tab identity is a bare integer repeated in 13 places | Section 3.4 | this document |
| 4 | Navigation and flag types live in unrelated feature files (`TabRouter`, `FeatureFlags`) | `App/Genesyx/UI/Learn/LearnViews.swift:8-16`, `App/Genesyx/UI/Learn/LearnModels.swift:6-42` | `docs/TECHNICAL_ARCHITECTURE.md` section 5.3 |
| 5 | No shared card or button style; card treatment repeated about 94 times | Section 8.2 | this document |
| 6 | No Dynamic Type | `App/Genesyx/UI/Theme/Typography.swift:5-10` | this document |
| 7 | Render cost: derived values recomputed in `body`, all tabs alive, coarse invalidation | Sections 3.3 and 5.9 | `docs/SCALABILITY_REVIEW.md` |
| 8 | Consent-aware UI is incomplete: the Track hydration sheet flashes "Saved" for a refused write | Section 5.7 | this document |
| 9 | Preview environment lacks `TabRouter` and `NotificationService` | Section 5.8 | this document |
| 10 | Dead or unreachable UI: `ErrorStateView`, `PlaceholderScreen`; partner and pregnancy screens behind compile-time flags | Sections 6 and 8.2 | this document |
| 11 | A metric is restated at every layer (16 to 21 Swift files per field) | Section 9.1 | this document, `docs/TECHNICAL_ARCHITECTURE.md` section 8.4 |
| 12 | Untracked UI test sleeps 60 s | Section 10.5 | this document |

---

## 12. Appendix: reproducing the counts

Run from the repository root; counts are at 353ff26.

```bash
# UI size, per folder and total
find App/Genesyx/UI -name '*.swift' | wc -l                              # 33
find App/Genesyx/UI -name '*.swift' -exec cat {} + | wc -l               # 11640
for d in App/Genesyx/UI/*/; do echo "$d $(find $d -name '*.swift' -exec cat {} + | wc -l)"; done

# Property wrappers in the UI
grep -rn "@EnvironmentObject" App/Genesyx --include='*.swift' | grep -vE ":[0-9]+:\s*//" | wc -l   # 75
grep -rn "@State "           App/Genesyx/UI --include='*.swift' | grep -vE ":[0-9]+:\s*//" | wc -l   # 127
grep -rn "@AppStorage"       App/Genesyx    --include='*.swift' | grep -vE ":[0-9]+:\s*//" | wc -l   # 15

# Modal presentations, and the sites that re-inject the environment
grep -rnE "\.(sheet|fullScreenCover|popover)\(" App/Genesyx --include='*.swift' | grep -vE ":[0-9]+:\s*//" | wc -l   # 38
grep -rn "withAppEnvironment" App/Genesyx --include='*.swift' | grep -v "///"        # 10 call sites + the definition

# NavigationStack declarations outside previews (28; 7 are tab roots)
grep -rn "NavigationStack" App/Genesyx --include='*.swift' | grep -v PreviewSupport | grep -vE ":[0-9]+:\s*//" | wc -l

# Tab index literals
grep -rn "selection = [0-9]" App/Genesyx --include='*.swift'

# Launch arguments read by the app
grep -rnoE "\"uiTest[A-Za-z]*\"" App/Genesyx --include='*.swift'

# Files that mention a DailyLog field, by layer
grep -rl sleepMinutes Sources/GenesyxCore App/Genesyx/Data App/Genesyx/UI App/Genesyx/Notifications \
     App/GenesyxTests Tests App/GenesyxUITests --include='*.swift'

# Unreferenced components
grep -rn "ErrorStateView\|PlaceholderScreen" App Sources Tests --include='*.swift'
```

Two counts differ from the evidence brief, so a reader who repeats the commands is not surprised: modal presentations (38 here against the brief's 33; the brief's method is not recorded) and file fan-in for `CalendarDate`, `DailyLog` and `GenesyxColor` (30, 19, 30 here against 29, 20, 29; within one file, a difference of method). The per-field file counts are Swift files only, and the brief's 15 to 21 includes the SQL file for some fields.
