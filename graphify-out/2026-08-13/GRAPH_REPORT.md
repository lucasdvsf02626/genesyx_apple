# Graph Report - genesxy_apple.V1.02  (2026-08-13)

## Corpus Check
- 260 files · ~688,871 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3093 nodes · 7283 edges · 180 communities (170 shown, 10 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 813 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d0b0c9f2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CalendarContrastTests
- HydrationUnit
- View
- GxPrimaryButton
- TrackView
- .today
- GenesyxUITests
- LogView
- CycleSettings
- PhInsightLogicTests
- AuthBackend
- HomeView
- PhTrackerCard
- LocalStore
- SupplementPersonalisationTests
- ProfileView
- NotificationPlannerTests
- DailyLog
- Sendable
- DailyLogRepository
- GenesyxCore
- .addingDays
- PreferencesRepository
- CalendarDate
- CodingKeys
- Image
- NutritionHydrationTests
- PhReading
- 1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026)
- NotificationService
- Hashable
- Int
- HydrationInsightTests
- WeeklySummaryView
- AuthView
- PartnerInvite
- Foundation
- SessionRepository
- NotificationTests
- ConsistencyInsightLogicTests
- FakePartnerBackend
- NotificationSlot
- .schedule
- NotificationSnapshot
- NotificationTab
- Genesyx iOS — Repository and App Inventory
- ProbePhBackend
- String
- String
- STATUS TABLES
- .content
- LearnCandidate
- .record
- Phase
- String
- String
- SwiftUI
- NutritionConsistencyInsights
- .compute
- TrackSignalSummary
- .compute
- NotificationKind
- Identifiable
- PartnerSectionView
- WaterChallengeTests
- YearMonth
- .remove
- LearnModels.swift
- LearnArticle
- StreakState
- Genesyx — Native iOS (Swift + SwiftUI) Architecture
- Genesyx iOS — Client Change List: Audit & Execution Plan
- HydrationStatus
- PersistenceTests
- TrackingEngineVectorTests
- QuizQuestion
- PartnerRepository
- MedicalSource
- CycleSettingsSheet
- Genesyx iOS — Session Handoff
- client.ts
- AuthView.swift
- CaseIterable
- MainTabView
- SupplementPlanSheet
- .initialLastPeriod
- NotificationTarget
- AppContainer
- PhRecord
- Genesyx — unattended session report
- ContentTests
- .progress
- PART 2 — APP STORE CONNECT AUDIT
- InviteView
- PhReadingDTO
- verify_review_account.sh
- Genesyx — "Is it real?" fix pass
- SleepDetailView
- .isValid
- .body
- Package.swift
- prepare_store_screenshots.sh
- XCTestCase
- Genesyx — Project Status & Inventory
- CitationE2ETests
- Partner invite email — what's built, and the 15 minutes you need to finish it
- Genesyx — Privacy Policy
- HydrationDetailSheet
- Reachability
- Genesyx — App Store Submission Pack
- Genesyx_Intelligent_Partner_Implementation_Blueprint_844a9d42.md
- OODA — How We Build genesyx With Claude
- genesyx — iOS Playbook: Zero to App Store
- Genesyx — Product Requirements & Strategy (Consolidated)
- Genesyx — Apple App Store Release Roadmap (Zero → Deployment)
- Genesyx iOS — What's Left to App Store (Status & Gap Checklist)
- Client structural changes (pH spine, Track order, hydration units, supplements, nutrition)
- FlowLayout
- Your tasks — do them in order, stop and tell me before any irreversible action
- Genesyx — Feature Overview
- Run Genesyx on your Mac — Checklist
- FoodGroup
- QuizView
- TestFlight — Genesyx 1.2.0 (18)
- Parity Audit & Bug-Fix Batch (mirrors Android 28 Jul batch)
- 6. The 7-to-30-day customer programme
- Genesyx iOS — All Screen Content (hidden reference)
- 2. Home tab
- DayPart
- QuizContentTests
- LifecycleE2ETests
- Genesyx iOS — Deployment Status Report
- 1. Onboarding (pre-auth flow)
- 3. Track tab
- Genesyx iOS — Session State Checkpoint
- Supabase Wiring (v1.x — deferred)
- 7. Domain guidance specifications
- Genesyx (iOS)
- 6. Nutrition tab
- Partner
- TestFlight — Genesyx 1.1.1 (17)
- 2. Current repository and technical architecture
- 0. Design system — the vocabulary every screen uses
- Resources
- Genesyx — Backend Live Test Plan (Supabase)
- 11. Implementation contracts and algorithms
- 13. Testing and verification
- 8. Track and Insights experience
- 9. Notification programme
- Q: do a list of everything needs to be done, deep dive so nothing is left, so we do today
- Q: what can claude do and what can you do please, from this list?
- Q: Claude code said it made some audit
- Q: what i need to check in supbase, remember this is for the IOS and I have the andriod as well in 1 supbase, need to do anything?
- Q: Correct the stale audit: preserve shipped iOS partner linking, defer Section 4 partner sharing scopes, and identify current partner RLS and account deletion gaps
- Q: So far Claude's shared-backend audit found the older live delete_current_user body, policies, no waitlist policies, and no user_supplements table. Is the conclusion correct and what remains?
- Q: Live audit found seven tables, six cascades, no profiles.partner_id FK, zero linked profiles, zero legacy quiz rows, and two Apple identities. What is the correct conclusion?
- Q: Live Supabase has neither user_supplements nor genesyx_products. How should the two Android findings be classified?
- Q: Review Claude's full shared-backend diagnostic matrix committed as 8d82e54 and identify remaining corrections before implementation
- Q: Review the newest Claude handoff claiming a Home no-cycle fix, T24 never existed, and 180/202/46 tests
- Q: What is next and what prompt should Claude use to do the tasks after discovering the Home fix was made in a stale worktree?
- Q: Copy the dedicated Android Learn article hero photos into the iOS project and wire every previously reused or missing hero
- Q: the understanding your Vaginal pH is not there
- Q: Which Sections 1-3 and 5 tracker requirements are complete, partial, missing, or blocked, with Section 4 excluded?
- Q: Plan the difficult remaining Genesyx work, update docs/CHANGE_LIST_PLAN.md, and provide a safe prompt for the one shared iOS and Android Supabase backend
- Q: Review Claude's pH history list and SwiftUI sheet-state race fix
- Q: Compare the Supabase agent proposal against the three local iOS and Android migration files
- Q: Reconcile the successful production Supabase migration report with both Genesyx repositories
- Q: Assess Claude's final pH cold-relaunch verification while the full suite runs
- 14. Safety, privacy and approval gates
- 15. Definition of done and implementation backlog
- 1. Executive summary
- Supabase Edge Functions (v1.x)
- ContentTests.swift
- RecipeContentTests.swift
- 7. Insights tab
- 8. Learn tab
- 9. Profile tab
- .path
- 10. Proposed technical architecture
- Fonts/README.md

## God Nodes (most connected - your core abstractions)
1. `CalendarDate` - 180 edges
2. `DailyLog` - 115 edges
3. `GenesyxColor` - 79 edges
4. `DailyLogRepository` - 78 edges
5. `RepositoryTests` - 78 edges
6. `CycleSettings` - 69 edges
7. `GenesyxCore` - 65 edges
8. `PreferencesRepository` - 59 edges
9. `NotificationService` - 49 edges
10. `Eyebrow` - 47 edges

## Surprising Connections (you probably didn't know these)
- `.record` --calls--> `PhRecord`  [EXTRACTED]
  App/Genesyx/Data/PersistenceDTOs.swift → Sources/GenesyxCore/Ph/PhSync.swift
- `.domain` --calls--> `PhReading`  [INFERRED]
  App/Genesyx/Data/Remote/RemoteModels.swift → Sources/GenesyxCore/Models/PhReading.swift
- `.body` --calls--> `CalendarDate`  [INFERRED]
  App/Genesyx/UI/Components/CycleSettingsSheet.swift → Sources/GenesyxCore/Models/CalendarDate.swift
- `.body` --calls--> `CalendarDate`  [INFERRED]
  App/Genesyx/UI/Home/HomeView.swift → Sources/GenesyxCore/Models/CalendarDate.swift
- `.hydrationCard` --references--> `HydrationStatus`  [INFERRED]
  App/Genesyx/UI/Home/HomeView.swift → Sources/GenesyxCore/Insights/HydrationStatusEvaluator.swift

## Import Cycles
- None detected.

## Communities (180 total, 10 thin omitted)

### Community 0 - "CalendarContrastTests"
Cohesion: 0.23
Nodes (9): CalendarContrastTests, .tintedFills, PregnancyContrastTests, Color, Double, StaticString, String, UInt (+1 more)

### Community 1 - "HydrationUnit"
Cohesion: 0.14
Nodes (13): .hydration, HydrationPrefs, .current, .hydrationGlassMl, .hydrationUnit, .unit, HydrationUnit, cups (+5 more)

### Community 2 - "View"
Cohesion: 0.09
Nodes (41): ConsistencyCard, .body, .weekDots, CycleRegularityCard, .body, DashedLine, HydrationInsightsCard, .body (+33 more)

### Community 3 - "GxPrimaryButton"
Cohesion: 0.09
Nodes (33): BrandEgg, .body, BrandOrb, .body, GxBackButton, .body, GxGhostButton, .body (+25 more)

### Community 4 - "TrackView"
Cohesion: 0.09
Nodes (23): Bool, CGFloat, Color, Set, TrackView, .divider, .header, .legend (+15 more)

### Community 5 - ".today"
Cohesion: 0.10
Nodes (17): Set, String, InsightsView, .currentWeek, .currentWeekSleep, .currentWeekSupplements, .header, .hydrationDeltaLine (+9 more)

### Community 6 - "GenesyxUITests"
Cohesion: 0.08
Nodes (5): GenesyxUITests, StaticString, UInt, XCUIApplication, XCUIElement

### Community 7 - "LogView"
Cohesion: 0.12
Nodes (23): LogView, .addSymptomChip, .allSymptoms, .body, .energySection, .intimacySection, .miniCards, .moodSection (+15 more)

### Community 8 - "CycleSettings"
Cohesion: 0.05
Nodes (21): CycleRepository, Bool, CycleBackend, .ovulationCard, .phase, .showsPhaseChange, BackendSwapTests, FakeCycleBackend (+13 more)

### Community 9 - "PhInsightLogicTests"
Cohesion: 0.09
Nodes (19): .body, PhInsightLogic, PhInsights, Bool, Date, Double, TimeInterval, Trend (+11 more)

### Community 10 - "AuthBackend"
Cohesion: 0.19
Nodes (10): AuthBackend, requireUID(), SupabaseBackend, SupabaseCycle, SupabaseDailyLog, SupabasePartner, SupabasePh, SupabaseProfile (+2 more)

### Community 11 - "HomeView"
Cohesion: 0.16
Nodes (11): HomeView, .body, .greeting, .greetingHeader, .hydrationCard, .learnCard, .phNudgeCard, .pregnancyPathwayLink (+3 more)

### Community 12 - "PhTrackerCard"
Cohesion: 0.07
Nodes (37): PhChart, .body, PhLogSheet, .body, PhRange, all, .days, .id (+29 more)

### Community 13 - "LocalStore"
Cohesion: 0.12
Nodes (12): .pendingPush, .pendingDates, LocalStore, Bool, String, T, UserDefaults, .celebratedMilestones (+4 more)

### Community 14 - "SupplementPersonalisationTests"
Cohesion: 0.05
Nodes (19): .supplementReminders, .custom, CustomSupplement, .isValid, Bool, String, Calendar, Date (+11 more)

### Community 15 - "ProfileView"
Cohesion: 0.18
Nodes (16): ProfileView, .aboutGroup, .accountGroup, .divider, .focusSection, .hydrationSection, .name, .remindersSection (+8 more)

### Community 16 - "NotificationPlannerTests"
Cohesion: 0.14
Nodes (5): NotificationPlannerTests, .everythingDue, Bool, Set, String

### Community 17 - "DailyLog"
Cohesion: 0.07
Nodes (18): .dto, DailyLogDTO, .domain, .isBlank, DailyLog, Bool, Set, .hasAnyEntry (+10 more)

### Community 18 - "Sendable"
Cohesion: 0.14
Nodes (22): Equatable, Sendable, EnergyTally, MoodTally, Bool, Double, String, WeeklyDeltas (+14 more)

### Community 19 - "DailyLogRepository"
Cohesion: 0.15
Nodes (6): DailyLogRepository, DailyLogBackend, DrainProbeDailyLogBackend, FakeDailyLogBackend, FakePhBackend, RepositoryTests

### Community 20 - "GenesyxCore"
Cohesion: 0.14
Nodes (3): Genesyx, GenesyxCore, XCTest

### Community 21 - ".addingDays"
Cohesion: 0.18
Nodes (4): .startOfWeek, StreakEngineTests, Set, String

### Community 22 - "PreferencesRepository"
Cohesion: 0.16
Nodes (11): PreferencesRepository, .focusMode, .prefs, .pushEnabled, .themeMode, Bool, Set, String (+3 more)

### Community 23 - "CalendarDate"
Cohesion: 0.09
Nodes (17): HydrationHistoryRow, .displayTotal, sleepHistoryCard(), SleepHistoryRow, .subtitle, .iso, Calendar, Date (+9 more)

### Community 24 - "CodingKeys"
Cohesion: 0.07
Nodes (30): CodingKeys, code, cycleLength, deletedAt, displayName, energy, focusMode, foodGroups (+22 more)

### Community 25 - "Image"
Cohesion: 0.12
Nodes (20): Color, Eyebrow, .body, .body, NutritionView, .articlesSection, .body, .foodLogCard (+12 more)

### Community 26 - "NutritionHydrationTests"
Cohesion: 0.15
Nodes (5): NutritionHydrationTests, HydrationCoach, .allStrings, Double, String

### Community 27 - "PhReading"
Cohesion: 0.13
Nodes (14): .domain, PhRepository, .records, Double, String, PhBackend, .body, PhMeasurementType (+6 more)

### Community 28 - "1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026)"
Cohesion: 0.05
Nodes (43): 1.1.1 (16) — external TestFlight, 1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026), 2026-07-18 — build 1.1.0 (13), Accessibility — a claim that was not true, App Store Connect — resubmission (manual, performed in browser by account holder), App Store Guideline 1.4.1 — medical citations (release-critical), build 17 — in flight (`fix/privacy-links-b17`, PR #2, not merged), Changelog (+35 more)

### Community 29 - "NotificationService"
Cohesion: 0.10
Nodes (15): AnyCancellable, App, GenesyxApp, .body, NotificationService, .isActive, .isOn, .isSystemDenied (+7 more)

### Community 30 - "Hashable"
Cohesion: 0.27
Nodes (7): Hashable, CycleContent, FocusCopy, FocusFood, PhaseHeroCopy, Bool, String

### Community 31 - "Int"
Cohesion: 0.09
Nodes (22): .chart, .chart, CycleRegularityInsights, Bool, String, OvulationInsights, String, .weekdaySundayZero (+14 more)

### Community 32 - "HydrationInsightTests"
Cohesion: 0.14
Nodes (7): .hydrationInsightsCard, HydrationInsightTests, HydrationInsightLogic, HydrationInsights, Bool, Double, String

### Community 33 - "WeeklySummaryView"
Cohesion: 0.12
Nodes (15): Bool, CGFloat, CGRect, Double, Path, String, WeeklyDashedLine, WeeklySummaryView (+7 more)

### Community 34 - "AuthView"
Cohesion: 0.06
Nodes (29): DeepLink, InvitePresentation, .id, String, URL, RootView, .body, .colorScheme (+21 more)

### Community 35 - "PartnerInvite"
Cohesion: 0.13
Nodes (6): AuthPartnerBackendTests, FakeAuth, .currentUserId, FakePartner, String, PartnerInvite

### Community 36 - "Foundation"
Cohesion: 0.13
Nodes (5): AppBackend, Combine, Foundation, PhCopy, UserNotifications

### Community 37 - "SessionRepository"
Cohesion: 0.10
Nodes (12): AuthRepository, Bool, String, SocialProvider, apple, google, SessionRepository, Bool (+4 more)

### Community 38 - "NotificationTests"
Cohesion: 0.12
Nodes (10): LearnLibraryLog, LearnProgress, .unreadNewCount, LearnReadLog, Set, String, UserDefaults, NotificationTests (+2 more)

### Community 39 - "ConsistencyInsightLogicTests"
Cohesion: 0.16
Nodes (9): .consistencyCard, ConsistencyCardModel, ConsistencyInsightLogic, HydrationDeltaLogic, PhContextLogic, Bool, String, ConsistencyInsightLogicTests (+1 more)

### Community 40 - "FakePartnerBackend"
Cohesion: 0.12
Nodes (6): FakePartnerBackend, LegacyPartnerBackend, PartnerTests, Bool, Set, String

### Community 41 - "NotificationSlot"
Cohesion: 0.11
Nodes (18): NotificationCategory, checkIn, cycle, insights, learn, logging, milestones, ph (+10 more)

### Community 42 - ".schedule"
Cohesion: 0.18
Nodes (4): Calendar, Date, Set, Date

### Community 43 - "NotificationSnapshot"
Cohesion: 0.21
Nodes (9): NotificationPlan, .hydration, .hydrationRestDays, .weekly, NotificationPlanner, NotificationSnapshot, PlannedNotification, Set (+1 more)

### Community 44 - "NotificationTab"
Cohesion: 0.14
Nodes (13): Any, AnyHashable, NotificationTab, home, insights, learn, nutrition, ph (+5 more)

### Community 45 - "Genesyx iOS — Repository and App Inventory"
Cohesion: 0.06
Nodes (34): 10. Repository map, 11. Verification and release boundary, 12. Capability status, 13. Maintenance rules, 1. Product and truth model, 2. Runtime architecture, 3. App shell, onboarding, authentication and routing, 4. User-visible surfaces (+26 more)

### Community 46 - "ProbePhBackend"
Cohesion: 0.22
Nodes (4): ProbePhBackend, Set, String, T

### Community 47 - "String"
Cohesion: 0.11
Nodes (27): CycleDetailView, .body, .emptyCycleContent, CyclePredictionCopy, DayDetailSheet, .eyebrow, .loggedSummary, DayInfo (+19 more)

### Community 48 - "String"
Cohesion: 0.15
Nodes (16): date, CycleSettingsRow, .domain, DailyLogRow, .domain, EmailInviteResponse, parseISO(), PartnerInviteRow (+8 more)

### Community 49 - "STATUS TABLES"
Cohesion: 0.06
Nodes (30): 1. Fix Google sign-in (blocks everything else), 1A — Vaginal pH, 1B — Tracking / calendar / Profile, 1C — Onboarding, 1D — Connectivity, 2. Commit the working tree (~40 files) + full green regression, 2A — Design, 2B — Nutrition (+22 more)

### Community 50 - ".content"
Cohesion: 0.11
Nodes (24): ArticleDetailView, .body, ArticleRow, .body, FeaturedCard, .body, LearnHero, .assetExists (+16 more)

### Community 52 - ".record"
Cohesion: 0.19
Nodes (5): PhSync, PhSyncTests, Bool, Double, String

### Community 53 - "Phase"
Cohesion: 0.12
Nodes (12): Recipe, .id, RecipeContent, RecipeCopy, .allStrings, String, Phase, follicular (+4 more)

### Community 54 - "String"
Cohesion: 0.25
Nodes (11): Article, .id, FoodAccent, follicular, luteal, ovulatory, period, NutritionContent (+3 more)

### Community 55 - "String"
Cohesion: 0.19
Nodes (4): SupabaseAuth, .currentUserId, Bool, String

### Community 56 - "SwiftUI"
Cohesion: 0.08
Nodes (17): CitationLink, SourcesFooter, String, ErrorStateView, .body, String, Void, PlaceholderScreen (+9 more)

### Community 57 - "NutritionConsistencyInsights"
Cohesion: 0.24
Nodes (6): .nutritionConsistencyCard, NutritionConsistencyInsights, NutritionConsistencyLogic, Bool, String, NutritionConsistencyLogicTests

### Community 58 - ".compute"
Cohesion: 0.25
Nodes (5): .sleepCard, SleepInsightLogic, SleepInsights, String, SleepInsightLogicTests

### Community 59 - "TrackSignalSummary"
Cohesion: 0.18
Nodes (4): .body, SleepTrackingData, TrackSignalSummary, .trackersSection

### Community 60 - ".compute"
Cohesion: 0.36
Nodes (5): .weeklyStreak, Log, Log, Set, TrackingEngine

### Community 61 - "NotificationKind"
Cohesion: 0.10
Nodes (21): NotificationContent, .allCopyStrings, NotificationKind, cycleFertile, dailyHydration, milestone14, milestone7, milestoneWeek1 (+13 more)

### Community 62 - "Identifiable"
Cohesion: 0.14
Nodes (14): LearnCategory, gettingStarted, guides, .id, insights, .label, nutrition, .tint (+6 more)

### Community 63 - "PartnerSectionView"
Cohesion: 0.27
Nodes (8): PartnerSectionView, .divider, .pending, PersonalDetailsSheet, .trimmedName, .body, Void, TrackingPreferencesSheet

### Community 64 - "WaterChallengeTests"
Cohesion: 0.15
Nodes (9): Bool, Log, String, WaterChallenge, WaterChallengeState, FakeDay, .isMeaningfulLog, Bool (+1 more)

### Community 65 - "YearMonth"
Cohesion: 0.22
Nodes (7): .calendarCard, String, .current, .shortTitle, .title, YearMonth, .lengthOfMonth

### Community 67 - "LearnModels.swift"
Cohesion: 0.13
Nodes (14): ArticleBlock, bulletList, callout, heading, paragraph, ArticleCta, CtaType, openArticle (+6 more)

### Community 68 - "LearnArticle"
Cohesion: 0.08
Nodes (13): .nextRead, LearnArticle, LearnLibrary, .articles, .featured, Bool, LearnSourceMap, String (+5 more)

### Community 69 - "StreakState"
Cohesion: 0.60
Nodes (3): StreakState, Bool, Set

### Community 70 - "Genesyx — Native iOS (Swift + SwiftUI) Architecture"
Cohesion: 0.08
Nodes (23): Auth, Backend / Data Layer, Conventions, Cycle Engine (port from `src/lib/cycle.ts` / `cycleEngine.ts`), Dark mode (must ship in v1), Dependencies (Swift Package Manager), Design Tokens (translate oklch → fixed sRGB; never compute at runtime), Feature Parity Matrix (+15 more)

### Community 71 - "Genesyx iOS — Client Change List: Audit & Execution Plan"
Cohesion: 0.09
Nodes (22): 0. Read this first, 10. Verification gate, 1. Gate 0 — decisions before any code, 2. Phase 1 — corrections (8–10d), 3. Phase 2 — the real gaps (15–18d), 4. Phase 3 — design (10–20d, design-gated), 5. Phase 4 — nutrition (15–20d), 6. Phase 5 — education (6–8d + medical review) (+14 more)

### Community 72 - "HydrationStatus"
Cohesion: 0.23
Nodes (7): HydrationStatus, HydrationStatusEvaluator, Double, String, Tone, neutral, positive

### Community 74 - "TrackingEngineVectorTests"
Cohesion: 0.38
Nodes (9): Decodable, Expect, Bool, String, TrackingEngineVectorTests, VectorCase, VectorDay, VectorFile (+1 more)

### Community 75 - "QuizQuestion"
Cohesion: 0.40
Nodes (6): .body, DidYouKnow, QuizOption, QuizQuestion, Bool, String

### Community 76 - "PartnerRepository"
Cohesion: 0.15
Nodes (9): PartnerRepository, String, PartnerBackend, RemoteConfig, .anonKey, .isConfigured, .url, Bool (+1 more)

### Community 77 - "MedicalSource"
Cohesion: 0.17
Nodes (7): MedicalSource, String, URL, MedicalSourceStore, String, .body, .body

### Community 78 - "CycleSettingsSheet"
Cohesion: 0.27
Nodes (8): CycleSettingsSheet, .body, .lastPeriodBinding, Binding, Date, String, Void, ClosedRange

### Community 79 - "Genesyx iOS — Session Handoff"
Cohesion: 0.10
Nodes (20): 1. Shipped 2026-08-10 (committed), 2. Supabase state (dashboard — leaves no trace in this repo), 3. Client audits — who writes `profiles`, 4. Open tasks, 4b. Shipped 2026-08-11 — committed as `185b99e`, 4c. Shipped 2026-08-11, later session — committed as `5b507a3` · `b08a9d9`, 4d. Phase 3 — the calendar in both schemes (2026-08-12), 4e. T24 — the Nutrition text pass (2026-08-12) (+12 more)

### Community 80 - "client.ts"
Cohesion: 0.41
Nodes (4): json(), NotAuthenticated, requireUser(), serviceClient()

### Community 81 - "AuthView.swift"
Cohesion: 0.14
Nodes (6): BrandAssetTests, AuthenticationServices, CryptoKit, GoogleSignIn, Security, UIKit

### Community 82 - "CaseIterable"
Cohesion: 0.13
Nodes (14): .domain, CaseIterable, FocusMode, pregnancy, prep, InviteStatus, accepted, declined (+6 more)

### Community 83 - "MainTabView"
Cohesion: 0.33
Nodes (6): MainTabView, .body, .initialSelection, .tabBar, Content, String

### Community 84 - "SupplementPlanSheet"
Cohesion: 0.15
Nodes (16): gxHourLabel(), .supplementPlanCard, RecipeSheet, .body, .logButton, SupplementAvatar, .body, SupplementPlanSheet (+8 more)

### Community 85 - ".initialLastPeriod"
Cohesion: 0.24
Nodes (3): CycleSetup, Bool, CycleSetupTests

### Community 86 - "NotificationTarget"
Cohesion: 0.25
Nodes (8): NotificationTarget, home, insights, learn, nutrition, ph, profile, track

### Community 87 - "AppContainer"
Cohesion: 0.09
Nodes (14): AppContainer, Bool, GenesyxBackend, RemoteError, emailConfirmationRequired, notAuthenticated, notAvailable, notConfigured (+6 more)

### Community 88 - "PhRecord"
Cohesion: 0.22
Nodes (7): PhReadingRow, Double, PhRecord, .id, Bool, Date, String

### Community 89 - "Genesyx — unattended session report"
Cohesion: 0.11
Nodes (18): 10. What's left for you, 🔴 #1 — Sign-out leaked the previous user's notification state to the next one, 1. TestFlight, 2. Test suite, 🔴 #2 — The partner invite never reached the partner, 3. End-to-end sync — THE FLAGSHIP RESULT, 🟠 #3 — The shared invite code was the wrong code, 🟠 #4 — A refused invite still showed a linked partner (+10 more)

### Community 90 - "ContentTests"
Cohesion: 0.13
Nodes (3): FoodLogCopy, .allStrings, ContentTests

### Community 91 - ".progress"
Cohesion: 0.26
Nodes (3): HydrationFormat, Double, HydrationUnitTests

### Community 92 - "PART 2 — APP STORE CONNECT AUDIT"
Cohesion: 0.12
Nodes (16): 1.1 Privacy Policy URL, 1.2 Support / Marketing URL, 1.3 Privacy Policy alternate paths (only if 1.1 failed), 2.0 Confirm authenticated, 2.1 App record exists (C1), 2.2 Version 1.0 page — App Store tab (C2), 2.3 App Privacy (C3), 2.4 Age Rating (C4) (+8 more)

### Community 93 - "InviteView"
Cohesion: 0.24
Nodes (7): InviteView, .body, .busy, .valid, Bool, String, Void

### Community 94 - "PhReadingDTO"
Cohesion: 0.25
Nodes (7): PhReadingDTO, .record, .dto, Bool, Date, Double, String

### Community 95 - "verify_review_account.sh"
Cohesion: 0.29
Nodes (5): api_header, auth_header, verify_review_account.sh script, SUPABASE_ANON_KEY, SUPABASE_URL

### Community 96 - "Genesyx — "Is it real?" fix pass"
Cohesion: 0.12
Nodes (16): 1. A note on how this session ran, 2. Fixes in this session, 3. What I reverted (and why), 4. Files changed, 5. What is NOT fixed — because it needs your decision, 6. Still only provable on a real device, 7. Recommended next steps, A. No invite email is ever sent (+8 more)

### Community 97 - "SleepDetailView"
Cohesion: 0.21
Nodes (6): DailyLogSyncState, pendingSync, saved, synced, Bool, SleepDetailView

### Community 98 - ".isValid"
Cohesion: 0.33
Nodes (3): EmailValidator, Bool, String

### Community 99 - ".body"
Cohesion: 0.20
Nodes (14): OnboardingFlowView, .body, OnboardingIntroView, ReadinessSummaryView, SplashView, Step, intro, quiz (+6 more)

### Community 102 - "XCTestCase"
Cohesion: 0.13
Nodes (7): PhContentGuardTests, Set, String, NotificationFlowUITests, SleepSmokeUITests, XCUIApplication, XCTestCase

### Community 103 - "Genesyx — Project Status & Inventory"
Cohesion: 0.12
Nodes (15): 1. At a glance, 2. What was built (three workstreams), 3. Source inventory, 4. Backend state (Supabase project `epltxklawpcxxbaleswg`), 5. The bug build 11 exists to fix, 6. Git state, 7. Outstanding, 8. Guardrails (keep these true) (+7 more)

### Community 104 - "CitationE2ETests"
Cohesion: 0.25
Nodes (4): CitationE2ETests, StaticString, UInt, XCUIApplication

### Community 105 - "Partner invite email — what's built, and the 15 minutes you need to finish it"
Cohesion: 0.13
Nodes (14): 1. What was wrong, and what now happens, 2. What YOU need to do (≈15 min), 3. Files added / changed, 4. Universal Links — built, tested, and waiting on TWO things only you can do, 5. And the deeper one: "linked" still shares nothing, Abuse guard, Partner invite email — what's built, and the 15 minutes you need to finish it, Step 1 — Get a sending domain + key (+6 more)

### Community 106 - "Genesyx — Privacy Policy"
Cohesion: 0.13
Nodes (14): Changes to this policy, Children, Contact, Genesyx — Privacy Policy, How long we keep it, Medical disclaimer, Security, Sharing with your partner (+6 more)

### Community 107 - "HydrationDetailSheet"
Cohesion: 0.23
Nodes (6): HydrationDetailSheet, .body, .glassMl, .manualEntry, .manualValue, .hydrationCard

### Community 108 - "Reachability"
Cohesion: 0.23
Nodes (6): Reachability, Bool, Void, MainActor, Network, NWPathMonitor

### Community 109 - "Genesyx — App Store Submission Pack"
Cohesion: 0.15
Nodes (11): Current release facts, Genesyx — App Store Connect Listing, Submission rule, 1. Listing metadata (copy/paste into App Store Connect), 2. App Privacy answers (App Store Connect → App Privacy), 3. Age rating questionnaire guidance, 4. Sign in with Apple note, 5. App Review access and notes (+3 more)

### Community 110 - "Genesyx_Intelligent_Partner_Implementation_Blueprint_844a9d42.md"
Cohesion: 0.15
Nodes (12): 12.1 Suggested code sequence, 12. Delivery roadmap, 3. Existing product capabilities, 4.1 The customer loop, 4.2 The standard insight card, 4. Target intelligent-partner experience, 5.1 Internal evidence states, 5.2 Per-signal coverage (+4 more)

### Community 111 - "OODA — How We Build genesyx With Claude"
Cohesion: 0.17
Nodes (11): 1. OBSERVE — *What is true right now?*, 2. ORIENT — *What does this mean, and what are my options?*, 3. DECIDE — *What is the single next action?*, 4. ACT — *Do it, then verify.*, Context Block — paste at the start of every session, Model Selection (the Swift equivalent of the Kotlin guide), One full loop, worked example, OODA — How We Build genesyx With Claude (+3 more)

### Community 112 - "genesyx — iOS Playbook: Zero to App Store"
Cohesion: 0.17
Nodes (11): genesyx — iOS Playbook: Zero to App Store, ⚠️ Hard requirement: you need a Mac, Phase 0 — Foundations (do before writing code), Phase 1 — Design preview (the "HTML preview" step, SwiftUI version), Phase 2 — Architecture (Opus plans it), Phase 3 — Build (Sonnet, one file at a time), Phase 4 — Test, Phase 5 — Ship (App Store Connect) (+3 more)

### Community 113 - "Genesyx — Product Requirements & Strategy (Consolidated)"
Cohesion: 0.17
Nodes (11): 1. Product strategy, 2. The pH user journey (most important section), 3. App structure & information architecture, 4. Phased roadmap, 5. Ecosystem map, 6. Website requirements, 7. Scientific & regulatory compliance, 8. Success metrics (+3 more)

### Community 114 - "Genesyx — Apple App Store Release Roadmap (Zero → Deployment)"
Cohesion: 0.17
Nodes (11): Genesyx — Apple App Store Release Roadmap (Zero → Deployment), Phase 0 — One-time account & project setup, Phase 1 — Code readiness (what we control in this repo), Phase 2 — Build & upload (on your Mac), Phase 3 — Create the app record (App Store Connect), Phase 4 — TestFlight (internal testing), Phase 5 — App Store listing & compliance, Phase 6 — Submit & release (+3 more)

### Community 115 - "Genesyx iOS — What's Left to App Store (Status & Gap Checklist)"
Cohesion: 0.17
Nodes (11): 1. Screens to translate (build order from `ARCHITECTURE.md`), 2. Shared components, 3. Assets & config (the main remaining work for a v1), 4. Backend (DEFERRED — scaffolding started; not needed for a local-only v1 launch), ⬜ APPLE OPS — account → store (detail in `RELEASE_ROADMAP.md`), ✅ DONE so far, Genesyx iOS — What's Left to App Store (Status & Gap Checklist), 🟡 / ⬜ REMAINING — App code (+3 more)

### Community 116 - "Client structural changes (pH spine, Track order, hydration units, supplements, nutrition)"
Cohesion: 0.17
Nodes (11): Client structural changes (pH spine, Track order, hydration units, supplements, nutrition), Missing content (not built — no fake data added), Next, Phase 0 / 1 (prior verification, carried forward), Phase 1 — Track order  ✅ `c96f253`, Phase 2 — pH product spine  ✅ `3da373f`, Phase 3 — Hydration units  ✅ `1bb379c`, Phase 4 — Manual supplements  ✅ `f570bd4`  (⚠️ DB flagged) (+3 more)

### Community 117 - "FlowLayout"
Cohesion: 0.25
Nodes (8): FlowLayout, CGFloat, CGRect, Void, CGSize, Layout, ProposedViewSize, Subviews

### Community 118 - "Your tasks — do them in order, stop and tell me before any irreversible action"
Cohesion: 0.18
Nodes (10): 1. Produce the Release archive, 2. Validate the archive before upload, 3. Real-device test (pre-upload sanity), 4. Upload to App Store Connect, 5. App Store Connect record + metadata, 6. TestFlight internal + submit for review, Claude Code Prompt — Genesyx iOS App Store Submission, Context — already verified (+2 more)

### Community 119 - "Genesyx — Feature Overview"
Cohesion: 0.18
Nodes (10): Authentication & onboarding, Cross-cutting, Genesyx — Feature Overview, Home, Insights (all from real logged data), Learn, Notes, Nutrition (+2 more)

### Community 120 - "Run Genesyx on your Mac — Checklist"
Cohesion: 0.18
Nodes (10): 0. Prerequisites (one-time), 1. Get the code, 2. Verify the domain layer (no Xcode UI needed), 3. Generate & open the app, 4. Signing (first build only), 5. Run, 6. If the build fails, 7. Drop in assets (anytime) (+2 more)

### Community 121 - "FoodGroup"
Cohesion: 0.20
Nodes (10): FoodGroup, dairy, .examples, fruit, .id, .label, oilsAndFats, protein (+2 more)

### Community 122 - "QuizView"
Cohesion: 0.28
Nodes (6): answers, QuizView, .isLast, .question, .selected, Bool

### Community 123 - "TestFlight — Genesyx 1.2.0 (18)"
Cohesion: 0.22
Nodes (8): Beta App Review Information (for the External test submission), Build facts, Pre-flight — do these before uploading, Release checklist, TestFlight — Genesyx 1.2.0 (18), What P0-4 was, What's NOT in this build (say so if asked), "What to Test" (paste into TestFlight → Build 18 → Test Details)

### Community 124 - "Parity Audit & Bug-Fix Batch (mirrors Android 28 Jul batch)"
Cohesion: 0.22
Nodes (8): Contract vectors, Decision, Next actions (queued, blocked externally), Non-reproducing edge notes (flagged, not fixed — surgical discipline), Parity Audit & Bug-Fix Batch (mirrors Android 28 Jul batch), Phase 1 — Audit results, Tests, Worklog — 2026-07-28

### Community 125 - "6. The 7-to-30-day customer programme"
Cohesion: 0.22
Nodes (9): 6.1 Day 0: start the picture, 6.2 Days 1-3: the picture is beginning, 6.3 Day 7: first weekly picture, 6.4 Day 14: two-week comparison, 6.5 Day 21: emerging routines, 6.6 Day 30: personal monthly picture, 6.7 Beyond 30 days: cycle-aware intelligence, 6. The 7-to-30-day customer programme (+1 more)

### Community 126 - "Genesyx iOS — All Screen Content (hidden reference)"
Cohesion: 0.25
Nodes (7): 10. Partner linking (`PartnerSectionView`, `InviteView`, `InviteShareSheet`), 11. Pregnancy preview (`PregnancyView`), 12. Notifications (local; `NotificationPlanner`/`Content`/`Service`), 13. Shared components, 4. Vaginal pH tracker (`PhTrackerSection`, shown on Track & Nutrition), 5. Log Today (sheet), Genesyx iOS — All Screen Content (hidden reference)

### Community 127 - "2. Home tab"
Cohesion: 0.25
Nodes (8): 2.1 Greeting header, 2.2 Phase hero card, 2.3 Today's focus card, 2.4 Hydration card, 2.5 pH nudge card — a11y `home.phCard`, 2.6 Log today button, 2.7 First-run setup card (no cycle yet), 2. Home tab

### Community 128 - "DayPart"
Cohesion: 0.25
Nodes (6): DayPart, afternoon, evening, midday, morning, night

### Community 131 - "Genesyx iOS — Deployment Status Report"
Cohesion: 0.25
Nodes (7): Bottom line, Critical path to the App Store (in order), Executive summary, Genesyx iOS — Deployment Status Report, Readiness by area, Top risks / watch-items, What's verified vs not

### Community 132 - "1. Onboarding (pre-auth flow)"
Cohesion: 0.29
Nodes (7): 1.1 Splash, 1.2 Intro, 1.3 Quiz (5 questions), 1.4 Readiness Summary, 1.5 Waitlist, 1.6 Auth, 1. Onboarding (pre-auth flow)

### Community 133 - "3. Track tab"
Cohesion: 0.29
Nodes (7): 3.1 Header, 3.2 Calendar card — phase colour legend, 3.3 Current phase card, 3.4 "Add to today's log" — `GxPrimaryButton` **primary** (`plus`) → Log sheet., 3.5 Trackers list ("YOUR TRACKERS"), 3.6 Detail sheets (each "Done" toolbar), 3. Track tab

### Community 134 - "Genesyx iOS — Session State Checkpoint"
Cohesion: 0.29
Nodes (6): Backend (verified read-only, project `epltxklawpcxxbaleswg`), Commit stack (newest first), Done (verified: clean Release build + 29/29 tests green), Genesyx iOS — Session State Checkpoint, Next-session entry point, Open items (3)

### Community 135 - "Supabase Wiring (v1.x — deferred)"
Cohesion: 0.29
Nodes (6): Apple review implications (important), Database, Edge Functions required (privileged ops), How to activate (when ready), Supabase Wiring (v1.x — deferred), What's already in the repo

### Community 136 - "7. Domain guidance specifications"
Cohesion: 0.29
Nodes (7): 7.1 Cycle, 7.2 Vaginal pH, 7.3 Supplements and nutrition, 7.4 Symptoms, 7.5 Sleep, 7.6 Hydration, 7. Domain guidance specifications

### Community 137 - "Genesyx (iOS)"
Cohesion: 0.29
Nodes (6): Architecture, Docs, Genesyx (iOS), Notes, Quick start (Mac), Status — local-only v1 is code-complete

### Community 138 - "6. Nutrition tab"
Cohesion: 0.33
Nodes (6): 6.1 Header, 6.2 Hydration coach card, 6.3 Focus foods card, 6.4 Supplement plan card, 6.5 Articles section, 6. Nutrition tab

### Community 140 - "TestFlight — Genesyx 1.1.1 (17)"
Cohesion: 0.33
Nodes (5): Beta App Review Information (for the External test submission), Build facts, TestFlight — Genesyx 1.1.1 (17), What's NOT in this build (say so if asked), "What to Test" (paste into TestFlight → Build 17 → Test Details)

### Community 141 - "2. Current repository and technical architecture"
Cohesion: 0.33
Nodes (6): 2.1 Verified current state, 2.2 Runtime flow, 2.3 Responsibilities, 2.4 Architectural strengths, 2.5 Current constraints, 2. Current repository and technical architecture

### Community 142 - "0. Design system — the vocabulary every screen uses"
Cohesion: 0.40
Nodes (5): 0.1 Colour palette (`GenesyxColors.swift`), 0.2 Type scale (`Typography.swift`, Apple system font), 0.3 Reusable controls (`GenesyxControls.swift`) — button colours, 0.4 Navigation shell, 0. Design system — the vocabulary every screen uses

### Community 143 - "Resources"
Cohesion: 0.40
Nodes (4): Accent color, App icon, Fonts, Resources

### Community 144 - "Genesyx — Backend Live Test Plan (Supabase)"
Cohesion: 0.40
Nodes (4): Genesyx — Backend Live Test Plan (Supabase), Notes, Preconditions, Test matrix

### Community 145 - "11. Implementation contracts and algorithms"
Cohesion: 0.40
Nodes (5): 11.1 GuidanceResult contract, 11.2 Comparable-date algorithm, 11.3 Period comparison algorithm, 11.4 Prioritization model, 11. Implementation contracts and algorithms

### Community 146 - "13. Testing and verification"
Cohesion: 0.40
Nodes (5): 13.1 Pure logic tests, 13.2 Notification tests, 13.3 Repository and data tests, 13.4 UI and device verification, 13. Testing and verification

### Community 147 - "8. Track and Insights experience"
Cohesion: 0.40
Nodes (5): 8.1 Track answers: What did I record and what next?, 8.2 Insights answers: What is the data beginning to show?, 8.3 Recommended top-level card, 8.4 Navigation requirements, 8. Track and Insights experience

### Community 148 - "9. Notification programme"
Cohesion: 0.40
Nodes (5): 9.1 Priority order, 9.2 Notification matrix, 9.3 Global scheduling rules, 9.4 Required preference controls, 9. Notification programme

### Community 149 - "Q: do a list of everything needs to be done, deep dive so nothing is left, so we do today"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: do a list of everything needs to be done, deep dive so nothing is left, so we do today, Source Nodes

### Community 150 - "Q: what can claude do and what can you do please, from this list?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: what can claude do and what can you do please, from this list?, Source Nodes

### Community 151 - "Q: Claude code said it made some audit"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Claude code said it made some audit, Source Nodes

### Community 152 - "Q: what i need to check in supbase, remember this is for the IOS and I have the andriod as well in 1 supbase, need to do anything?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: what i need to check in supbase, remember this is for the IOS and I have the andriod as well in 1 supbase, need to do anything?, Source Nodes

### Community 153 - "Q: Correct the stale audit: preserve shipped iOS partner linking, defer Section 4 partner sharing scopes, and identify current partner RLS and account deletion gaps"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Correct the stale audit: preserve shipped iOS partner linking, defer Section 4 partner sharing scopes, and identify current partner RLS and account deletion gaps, Source Nodes

### Community 154 - "Q: So far Claude's shared-backend audit found the older live delete_current_user body, policies, no waitlist policies, and no user_supplements table. Is the conclusion correct and what remains?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: So far Claude's shared-backend audit found the older live delete_current_user body, policies, no waitlist policies, and no user_supplements table. Is the conclusion correct and what remains?, Source Nodes

### Community 155 - "Q: Live audit found seven tables, six cascades, no profiles.partner_id FK, zero linked profiles, zero legacy quiz rows, and two Apple identities. What is the correct conclusion?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Live audit found seven tables, six cascades, no profiles.partner_id FK, zero linked profiles, zero legacy quiz rows, and two Apple identities. What is the correct conclusion?, Source Nodes

### Community 156 - "Q: Live Supabase has neither user_supplements nor genesyx_products. How should the two Android findings be classified?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Live Supabase has neither user_supplements nor genesyx_products. How should the two Android findings be classified?, Source Nodes

### Community 157 - "Q: Review Claude's full shared-backend diagnostic matrix committed as 8d82e54 and identify remaining corrections before implementation"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Review Claude's full shared-backend diagnostic matrix committed as 8d82e54 and identify remaining corrections before implementation, Source Nodes

### Community 158 - "Q: Review the newest Claude handoff claiming a Home no-cycle fix, T24 never existed, and 180/202/46 tests"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Review the newest Claude handoff claiming a Home no-cycle fix, T24 never existed, and 180/202/46 tests, Source Nodes

### Community 159 - "Q: What is next and what prompt should Claude use to do the tasks after discovering the Home fix was made in a stale worktree?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: What is next and what prompt should Claude use to do the tasks after discovering the Home fix was made in a stale worktree?, Source Nodes

### Community 160 - "Q: Copy the dedicated Android Learn article hero photos into the iOS project and wire every previously reused or missing hero"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Copy the dedicated Android Learn article hero photos into the iOS project and wire every previously reused or missing hero, Source Nodes

### Community 161 - "Q: the understanding your Vaginal pH is not there"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: the understanding your Vaginal pH is not there, Source Nodes

### Community 162 - "Q: Which Sections 1-3 and 5 tracker requirements are complete, partial, missing, or blocked, with Section 4 excluded?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Which Sections 1-3 and 5 tracker requirements are complete, partial, missing, or blocked, with Section 4 excluded?, Source Nodes

### Community 163 - "Q: Plan the difficult remaining Genesyx work, update docs/CHANGE_LIST_PLAN.md, and provide a safe prompt for the one shared iOS and Android Supabase backend"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Plan the difficult remaining Genesyx work, update docs/CHANGE_LIST_PLAN.md, and provide a safe prompt for the one shared iOS and Android Supabase backend, Source Nodes

### Community 164 - "Q: Review Claude's pH history list and SwiftUI sheet-state race fix"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Review Claude's pH history list and SwiftUI sheet-state race fix, Source Nodes

### Community 165 - "Q: Compare the Supabase agent proposal against the three local iOS and Android migration files"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Compare the Supabase agent proposal against the three local iOS and Android migration files, Source Nodes

### Community 166 - "Q: Reconcile the successful production Supabase migration report with both Genesyx repositories"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Reconcile the successful production Supabase migration report with both Genesyx repositories, Source Nodes

### Community 167 - "Q: Assess Claude's final pH cold-relaunch verification while the full suite runs"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Assess Claude's final pH cold-relaunch verification while the full suite runs, Source Nodes

### Community 168 - "14. Safety, privacy and approval gates"
Cohesion: 0.50
Nodes (4): 14.1 Engineering must not decide, 14.2 Prohibited behaviours, 14.3 Required limitation patterns, 14. Safety, privacy and approval gates

### Community 169 - "15. Definition of done and implementation backlog"
Cohesion: 0.50
Nodes (4): 15.1 Programme definition of done, 15.2 Build backlog, 15.3 Final positioning, 15. Definition of done and implementation backlog

### Community 170 - "1. Executive summary"
Cohesion: 0.50
Nodes (4): 1. Executive summary, Recommended implementation order, Target outcome, What success looks like

### Community 171 - "Supabase Edge Functions (v1.x)"
Cohesion: 0.50
Nodes (3): Supabase Edge Functions (v1.x), `verify_jwt` is ON as of 2026-08-13 — but never write a function that relies on it, Why the `NotAuthenticated` split still matters

### Community 172 - "ContentTests.swift"
Cohesion: 0.50
Nodes (3): String, .isBlank, Bool

### Community 173 - "RecipeContentTests.swift"
Cohesion: 0.50
Nodes (3): String, .isBlank, Bool

### Community 174 - "7. Insights tab"
Cohesion: 0.67
Nodes (3): 7.1 Weekly summary (top of My Logs), 7.2 My Logs (`LogHistoryView`), 7. Insights tab

### Community 175 - "8. Learn tab"
Cohesion: 0.67
Nodes (3): 8.1 Library (10 items), 8.2 Citations mapping (`LearnSourceMap`), 8. Learn tab

### Community 176 - "9. Profile tab"
Cohesion: 0.67
Nodes (3): 9.1 Medical Sources & Disclaimer (`MedicalSourcesView`), 9.2 Medical sources list (`medical_sources.json`, 13), 9. Profile tab

### Community 178 - "10. Proposed technical architecture"
Cohesion: 0.67
Nodes (3): 10.1 New core module, 10.2 App integration, 10. Proposed technical architecture

## Knowledge Gaps
- **778 isolated node(s):** `.id`, `.colorScheme`, `saved`, `synced`, `pendingSync` (+773 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Work-memory lessons

**Preferred sources** — corroborated by past sessions; start here.
- `ProfileView` (9× useful, score=8.965129488)
- `NotificationService` (5× useful, score=4.986311759)
- `SupabaseBackend` (5× useful, score=4.974068403)
- `PartnerRepository` (5× useful, score=4.973332602)
- `AuthView` (4× useful, score=3.989041112)
- `DailyLogRepository` (4× useful, score=3.981127399)
- `PreferencesRepository` (4× useful, score=3.981127399)
- `PhTrackerCard` (3× useful, score=2.987203584)
- `TrackingEngine` (3× useful, score=2.986933207)
- `OnboardingFlowView` (3× useful, score=2.981825446)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Int` connect `Int` to `DayPart`, `HydrationUnit`, `View`, `LifecycleE2ETests`, `.today`, `GenesyxUITests`, `LogView`, `CycleSettings`, `AuthBackend`, `HomeView`, `LocalStore`, `SupplementPersonalisationTests`, `NotificationPlannerTests`, `DailyLog`, `Sendable`, `.addingDays`, `PreferencesRepository`, `CalendarDate`, `Image`, `NutritionHydrationTests`, `NotificationService`, `HydrationInsightTests`, `WeeklySummaryView`, `AuthView`, `NotificationTests`, `ConsistencyInsightLogicTests`, `.schedule`, `NotificationSnapshot`, `NotificationTab`, `ProbePhBackend`, `String`, `String`, `.content`, `LearnCandidate`, `Phase`, `NutritionConsistencyInsights`, `.compute`, `TrackSignalSummary`, `.compute`, `WaterChallengeTests`, `YearMonth`, `StreakState`, `HydrationStatus`, `TrackingEngineVectorTests`, `CycleSettingsSheet`, `MainTabView`, `SupplementPlanSheet`, `NotificationTarget`, `PhRecord`, `ContentTests`, `.progress`, `SleepDetailView`, `XCTestCase`, `CitationE2ETests`, `HydrationDetailSheet`?**
  _High betweenness centrality (0.156) - this node is a cross-community bridge._
- **Why does `CalendarDate` connect `CalendarDate` to `DayPart`, `View`, `TrackView`, `.today`, `LogView`, `CycleSettings`, `AuthBackend`, `HomeView`, `LocalStore`, `SupplementPersonalisationTests`, `DailyLog`, `Sendable`, `DailyLogRepository`, `.addingDays`, `NotificationService`, `Hashable`, `Int`, `HydrationInsightTests`, `WeeklySummaryView`, `Foundation`, `String`, `String`, `TrackSignalSummary`, `.compute`, `WaterChallengeTests`, `YearMonth`, `LearnArticle`, `StreakState`, `PersistenceTests`, `TrackingEngineVectorTests`, `CycleSettingsSheet`, `.initialLastPeriod`, `HydrationDetailSheet`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `PreferencesRepository` connect `PreferencesRepository` to `AuthView`, `.remove`, `Foundation`, `SessionRepository`, `.body`, `NotificationSlot`, `LocalStore`, `SupplementPersonalisationTests`, `ProfileView`, `CaseIterable`, `DailyLogRepository`, `SupplementPlanSheet`, `AppContainer`, `PhReading`, `NotificationService`, `Int`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 47 inferred relationships involving `CalendarDate` (e.g. with `.snapshot()` and `.body`) actually correct?**
  _`CalendarDate` has 47 INFERRED edges - model-reasoned connections that need verification._
- **Are the 27 inferred relationships involving `DailyLog` (e.g. with `.uiTestSeeded()` and `.previewSeeded()`) actually correct?**
  _`DailyLog` has 27 INFERRED edges - model-reasoned connections that need verification._
- **Are the 72 inferred relationships involving `Image` (e.g. with `.stepButton()` and `.body`) actually correct?**
  _`Image` has 72 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.id`, `.colorScheme`, `saved` to the rest of the system?**
  _778 weakly-connected nodes found - possible documentation gaps or missing edges._