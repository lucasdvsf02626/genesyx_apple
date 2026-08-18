# Graph Report - genesxy_apple.V1.02  (2026-08-13)

## Corpus Check
- 259 files · ~683,241 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3072 nodes · 7248 edges · 195 communities (171 shown, 24 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 813 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d0b0c9f2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CalendarContrastTests
- CycleSettings
- InsightsView.swift
- Eyebrow
- TrackView
- DailyLogRepository
- GenesyxUITests
- LogView
- .minusDays
- PhInsightLogicTests
- AuthBackend
- HomeView
- PhTrackerCard
- PreferencesRepository
- SupplementPersonalisationTests
- ProfileView
- NotificationPlannerTests
- DailyLog
- Sendable
- RepositoryTests
- GenesyxCore
- .addingDays
- CycleEngineTests
- CalendarDate
- CodingKeys
- NutritionView
- NutritionHydrationTests
- PhReading
- 1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026)
- NotificationService
- CycleContent
- Int
- HydrationInsightTests
- GenesyxColor
- .inviteCode
- AuthView
- Foundation
- SessionRepository
- LearnArticle
- ConsistencyInsightLogicTests
- PartnerRepository
- NotificationSlot
- NotificationTests
- NotificationSnapshot
- NotificationTab
- Genesyx iOS — Repository and App Inventory
- Phase
- TrackView.swift
- String
- STATUS TABLES
- .content
- LearnCandidate
- .record
- Recipe
- String
- String
- SwiftUI
- NutritionConsistencyInsights
- .compute
- TrackSignalSummary
- StreakState
- NotificationKind
- LearnCategory
- Image
- WaterChallengeTests
- YearMonth
- CustomSupplement
- LearnModels.swift
- LearnContentTests
- AuthRepository
- Genesyx — Native iOS (Swift + SwiftUI) Architecture
- Genesyx iOS — Client Change List: Audit & Execution Plan
- .hydrationCard
- PersistenceTests
- TrackingEngineVectorTests
- QuizQuestion
- String
- SupplementReminder
- CycleSettingsSheet
- Genesyx iOS — Session Handoff
- client.ts
- AuthView.swift
- CaseIterable
- View
- SupplementPlanSheet
- .state
- NotificationTarget
- CycleRepository
- supabase_schema.sql
- Genesyx — unattended session report
- ContentTests
- HydrationUnit
- PART 2 — APP STORE CONNECT AUDIT
- OvulationLogicTests
- DayType
- verify_review_account.sh
- Genesyx — "Is it real?" fix pass
- SleepDetailView
- .isValid
- Step
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
- .cyclePhase
- OODA — How We Build genesyx With Claude
- genesyx — iOS Playbook: Zero to App Store
- Genesyx — Product Requirements & Strategy (Consolidated)
- Genesyx — Apple App Store Release Roadmap (Zero → Deployment)
- Genesyx iOS — What's Left to App Store (Status & Gap Checklist)
- Client structural changes (pH spine, Track order, hydration units, supplements, nutrition)
- .from
- Your tasks — do them in order, stop and tell me before any irreversible action
- Genesyx — Feature Overview
- Run Genesyx on your Mac — Checklist
- .uiTestSeeded
- .markers
- TestFlight — Genesyx 1.2.0 (18)
- Parity Audit & Bug-Fix Batch (mirrors Android 28 Jul batch)
- SupplementReminderTests
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
- .userNotificationCenter
- Genesyx (iOS)
- 6. Nutrition tab
- SleepSmokeUITests
- TestFlight — Genesyx 1.1.1 (17)
- 20260712_sync_hardening.sql
- 0. Design system — the vocabulary every screen uses
- Resources
- Genesyx — Backend Live Test Plan (Supabase)
- .previewSeeded
- .handleApple
- 20260811_waitlist_emails.sql
- public.user_supplements
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
- public.quiz_answers
- public.delete_current_user
- public.partner_invites
- Supabase Edge Functions (v1.x)
- ContentTests.swift
- RecipeContentTests.swift
- 7. Insights tab
- 8. Learn tab
- 9. Profile tab
- public.ph_readings
- Fonts/README.md
- public.profiles
- public.profiles
- public.daily_logs
- public.profiles
- public.daily_logs
- public.profiles

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
- `.domain` --calls--> `PhReading`  [INFERRED]
  App/Genesyx/Data/Remote/RemoteModels.swift → Sources/GenesyxCore/Models/PhReading.swift
- `.domain` --calls--> `InviteStatus`  [INFERRED]
  App/Genesyx/Data/Remote/RemoteModels.swift → Sources/GenesyxCore/Models/Account.swift
- `.body` --calls--> `CalendarDate`  [INFERRED]
  App/Genesyx/UI/Components/CycleSettingsSheet.swift → Sources/GenesyxCore/Models/CalendarDate.swift
- `.body` --calls--> `CalendarDate`  [INFERRED]
  App/Genesyx/UI/Home/HomeView.swift → Sources/GenesyxCore/Models/CalendarDate.swift
- `.chart` --references--> `OvulationInsights`  [INFERRED]
  App/Genesyx/UI/Insights/InsightsView.swift → Sources/GenesyxCore/Insights/OvulationLogic.swift

## Import Cycles
- None detected.

## Communities (195 total, 24 thin omitted)

### Community 0 - "CalendarContrastTests"
Cohesion: 0.23
Nodes (9): CalendarContrastTests, .tintedFills, PregnancyContrastTests, Color, Double, StaticString, String, UInt (+1 more)

### Community 1 - "CycleSettings"
Cohesion: 0.16
Nodes (10): CycleSettingsRow, .domain, .body, BackendSwapTests, FakeCycleBackend, FakeCycleBackend, MidDrainCycleBackend, Void (+2 more)

### Community 2 - "InsightsView.swift"
Cohesion: 0.06
Nodes (39): ConsistencyCard, .body, .weekDots, DashedLine, HydrationInsightsCard, .body, .chart, .body (+31 more)

### Community 3 - "Eyebrow"
Cohesion: 0.10
Nodes (34): BrandEgg, .body, BrandOrb, .body, Color, Eyebrow, .body, GxBackButton (+26 more)

### Community 4 - "TrackView"
Cohesion: 0.10
Nodes (26): DayDetailSheet, .eyebrow, .loggedSummary, DayInfo, .id, LogTarget, .id, Bool (+18 more)

### Community 5 - "DailyLogRepository"
Cohesion: 0.11
Nodes (19): DailyLogRepository, Set, String, DailyLogBackend, InsightsView, .currentWeek, .currentWeekSleep, .currentWeekSupplements (+11 more)

### Community 6 - "GenesyxUITests"
Cohesion: 0.08
Nodes (5): GenesyxUITests, StaticString, UInt, XCUIApplication, XCUIElement

### Community 7 - "LogView"
Cohesion: 0.08
Nodes (31): FlowLayout, CGFloat, CGRect, Void, LogView, .addSymptomChip, .allSymptoms, .body (+23 more)

### Community 8 - ".minusDays"
Cohesion: 0.14
Nodes (4): RealInsightsTests, String, SymptomPatternInsights, SymptomPatternLogic

### Community 9 - "PhInsightLogicTests"
Cohesion: 0.09
Nodes (18): PhInsightLogic, PhInsights, Bool, Date, Double, TimeInterval, Trend, down (+10 more)

### Community 10 - "AuthBackend"
Cohesion: 0.22
Nodes (9): AuthBackend, requireUID(), SupabaseBackend, SupabaseCycle, SupabaseDailyLog, SupabasePh, SupabaseProfile, Supabase (+1 more)

### Community 11 - "HomeView"
Cohesion: 0.19
Nodes (9): HomeView, .greeting, .greetingHeader, .learnCard, .phNudgeCard, .pregnancyPathwayLink, .setupCard, Double (+1 more)

### Community 12 - "PhTrackerCard"
Cohesion: 0.09
Nodes (30): PhChart, .body, PhLogSheet, .body, PhRange, all, .days, .id (+22 more)

### Community 13 - "PreferencesRepository"
Cohesion: 0.08
Nodes (20): .pendingDates, LocalStore, Bool, String, T, UserDefaults, PreferencesRepository, .celebratedMilestones (+12 more)

### Community 14 - "SupplementPersonalisationTests"
Cohesion: 0.22
Nodes (3): SupplementPersonalisationTests, Calendar, String

### Community 15 - "ProfileView"
Cohesion: 0.13
Nodes (22): PersonalDetailsSheet, .body, .trimmedName, ProfileView, .aboutGroup, .accountGroup, .body, .focusSection (+14 more)

### Community 16 - "NotificationPlannerTests"
Cohesion: 0.15
Nodes (5): NotificationPlannerTests, .everythingDue, Bool, Set, String

### Community 17 - "DailyLog"
Cohesion: 0.10
Nodes (13): .dto, DailyLogDTO, .domain, Bool, String, .isBlank, DailyLog, Bool (+5 more)

### Community 18 - "Sendable"
Cohesion: 0.13
Nodes (21): Sendable, EnergyTally, MoodTally, Bool, Double, String, WeeklyDeltas, WeeklySummary (+13 more)

### Community 19 - "RepositoryTests"
Cohesion: 0.12
Nodes (6): AppContainer, ProfilePrefs, FakeProfileBackend, RepositoryTests, Set, T

### Community 20 - "GenesyxCore"
Cohesion: 0.13
Nodes (4): Genesyx, GenesyxCore, UIKit, XCTest

### Community 21 - ".addingDays"
Cohesion: 0.12
Nodes (6): .startOfWeek, Double, WeeklySummaryLogicTests, StreakEngineTests, Set, String

### Community 22 - "CycleEngineTests"
Cohesion: 0.19
Nodes (3): .showsPhaseChange, Bool, CycleEngineTests

### Community 23 - "CalendarDate"
Cohesion: 0.10
Nodes (14): .iso, Calendar, Date, String, Comparable, CycleSetup, Bool, CalendarDate (+6 more)

### Community 24 - "CodingKeys"
Cohesion: 0.07
Nodes (30): CodingKeys, code, cycleLength, deletedAt, displayName, energy, focusMode, foodGroups (+22 more)

### Community 25 - "NutritionView"
Cohesion: 0.12
Nodes (16): NutritionView, .articlesSection, .body, .phase, .supplementPlanCard, .supplementsTakenLabel, .waterChallengeCard, .weeklyStreak (+8 more)

### Community 26 - "NutritionHydrationTests"
Cohesion: 0.08
Nodes (16): MedicalSource, String, URL, MedicalSourceStore, String, CitationLink, .body, SourcesFooter (+8 more)

### Community 27 - "PhReading"
Cohesion: 0.08
Nodes (27): PhReadingDTO, .domain, .record, .dto, Date, Double, PhRepository, .records (+19 more)

### Community 28 - "1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026)"
Cohesion: 0.05
Nodes (43): 1.1.1 (16) — external TestFlight, 1.2.0 (18) — in flight (main, `9d08d82` … working tree, 10–11 Aug 2026), 2026-07-18 — build 1.1.0 (13), Accessibility — a claim that was not true, App Store Connect — resubmission (manual, performed in browser by account holder), App Store Guideline 1.4.1 — medical citations (release-critical), build 17 — in flight (`fix/privacy-links-b17`, PR #2, not merged), Changelog (+35 more)

### Community 29 - "NotificationService"
Cohesion: 0.12
Nodes (11): AnyCancellable, NotificationService, .isActive, .isOn, .isSystemDenied, Bool, String, .reminderPromptSheet (+3 more)

### Community 30 - "CycleContent"
Cohesion: 0.28
Nodes (6): CycleContent, FocusCopy, FocusFood, PhaseHeroCopy, Bool, String

### Community 31 - "Int"
Cohesion: 0.11
Nodes (17): HydrationHistoryRow, .displayTotal, sleepHistoryCard(), SleepHistoryRow, Equatable, CycleRegularityInsights, Bool, String (+9 more)

### Community 32 - "HydrationInsightTests"
Cohesion: 0.13
Nodes (7): .hydrationInsightsCard, HydrationInsightTests, HydrationInsightLogic, HydrationInsights, Bool, Double, String

### Community 33 - "GenesyxColor"
Cohesion: 0.11
Nodes (18): Bool, CGFloat, Double, String, WeeklySummaryView, .body, .emptyState, .isCurrentWeek (+10 more)

### Community 34 - ".inviteCode"
Cohesion: 0.13
Nodes (12): DeepLink, InvitePresentation, .id, String, URL, RootView, .body, .colorScheme (+4 more)

### Community 35 - "AuthView"
Cohesion: 0.16
Nodes (10): AuthView, .body, .divider, Binding, Bool, String, Void, ASAuthorizationAppleIDRequest (+2 more)

### Community 36 - "Foundation"
Cohesion: 0.11
Nodes (5): Combine, Foundation, CycleRegularityLogic, PhCopy, UserNotifications

### Community 37 - "SessionRepository"
Cohesion: 0.20
Nodes (5): SessionRepository, Bool, String, Void, FakeAuthBackend

### Community 38 - "LearnArticle"
Cohesion: 0.14
Nodes (11): LearnLibraryLog, LearnProgress, .nextRead, .unreadNewCount, LearnReadLog, Set, String, UserDefaults (+3 more)

### Community 39 - "ConsistencyInsightLogicTests"
Cohesion: 0.16
Nodes (9): .consistencyCard, ConsistencyCardModel, ConsistencyInsightLogic, HydrationDeltaLogic, PhContextLogic, Bool, String, ConsistencyInsightLogicTests (+1 more)

### Community 40 - "PartnerRepository"
Cohesion: 0.06
Nodes (24): PartnerRepository, String, PartnerBackend, InviteView, .body, .busy, .valid, Bool (+16 more)

### Community 41 - "NotificationSlot"
Cohesion: 0.11
Nodes (18): NotificationCategory, checkIn, cycle, insights, learn, logging, milestones, ph (+10 more)

### Community 42 - "NotificationTests"
Cohesion: 0.15
Nodes (6): Calendar, Date, Set, NotificationTests, .shipped, Date

### Community 43 - "NotificationSnapshot"
Cohesion: 0.26
Nodes (8): NotificationPlan, .hydration, .hydrationRestDays, .weekly, NotificationPlanner, NotificationSnapshot, PlannedNotification, Set

### Community 44 - "NotificationTab"
Cohesion: 0.14
Nodes (13): Any, AnyHashable, NotificationTab, home, insights, learn, nutrition, ph (+5 more)

### Community 45 - "Genesyx iOS — Repository and App Inventory"
Cohesion: 0.06
Nodes (34): 10. Repository map, 11. Verification and release boundary, 12. Capability status, 13. Maintenance rules, 1. Product and truth model, 2. Runtime architecture, 3. App shell, onboarding, authentication and routing, 4. User-visible surfaces (+26 more)

### Community 46 - "Phase"
Cohesion: 0.17
Nodes (13): Hashable, String, CalendarCell, day, empty, CyclePhaseInfo, FertileWindow, Phase (+5 more)

### Community 47 - "TrackView.swift"
Cohesion: 0.18
Nodes (14): CycleDetailView, .body, .emptyCycleContent, CyclePredictionCopy, detailHistoryCard(), insightCard(), NutritionDetailView, .body (+6 more)

### Community 48 - "String"
Cohesion: 0.15
Nodes (15): date, .domain, EmailInviteResponse, parseISO(), PartnerInviteRow, .domain, PhReadingRow, .domain (+7 more)

### Community 49 - "STATUS TABLES"
Cohesion: 0.06
Nodes (30): 1. Fix Google sign-in (blocks everything else), 1A — Vaginal pH, 1B — Tracking / calendar / Profile, 1C — Onboarding, 1D — Connectivity, 2. Commit the working tree (~40 files) + full green regression, 2A — Design, 2B — Nutrition (+22 more)

### Community 50 - ".content"
Cohesion: 0.10
Nodes (25): ArticleDetailView, .body, .unavailable, ArticleRow, .body, FeaturedCard, .body, LearnHero (+17 more)

### Community 51 - "LearnCandidate"
Cohesion: 0.17
Nodes (3): LearnCandidate, Bool, String

### Community 52 - ".record"
Cohesion: 0.19
Nodes (5): PhSync, PhSyncTests, Bool, Double, String

### Community 53 - "Recipe"
Cohesion: 0.14
Nodes (9): .body, Color, Recipe, .id, RecipeContent, RecipeCopy, .allStrings, String (+1 more)

### Community 54 - "String"
Cohesion: 0.11
Nodes (25): .foodLogCard, .header, Article, .id, FoodAccent, follicular, luteal, ovulatory (+17 more)

### Community 55 - "String"
Cohesion: 0.14
Nodes (5): SupabaseAuth, .currentUserId, SupabasePartner, Bool, String

### Community 56 - "SwiftUI"
Cohesion: 0.08
Nodes (17): ErrorStateView, .body, String, Void, PlaceholderScreen, .body, String, CGRect (+9 more)

### Community 57 - "NutritionConsistencyInsights"
Cohesion: 0.27
Nodes (5): NutritionConsistencyInsights, NutritionConsistencyLogic, Bool, String, NutritionConsistencyLogicTests

### Community 58 - ".compute"
Cohesion: 0.25
Nodes (5): .body, SleepInsightLogic, SleepInsights, String, SleepInsightLogicTests

### Community 59 - "TrackSignalSummary"
Cohesion: 0.16
Nodes (7): SleepTrackingData, SparkDots, .body, .normalized, Double, TrackSignalSummary, .trackersSection

### Community 60 - "StreakState"
Cohesion: 0.21
Nodes (9): StreakEngine, StreakLoggable, StreakState, Bool, Log, Set, Log, Set (+1 more)

### Community 61 - "NotificationKind"
Cohesion: 0.10
Nodes (21): NotificationContent, .allCopyStrings, NotificationKind, cycleFertile, dailyHydration, milestone14, milestone7, milestoneWeek1 (+13 more)

### Community 62 - "LearnCategory"
Cohesion: 0.18
Nodes (11): LearnCategory, gettingStarted, guides, .id, insights, .label, nutrition, .tint (+3 more)

### Community 63 - "Image"
Cohesion: 0.09
Nodes (21): .logHistoryLink, LogHistoryView, .emptyState, .entries, InviteShareSheet, .body, Bool, String (+13 more)

### Community 64 - "WaterChallengeTests"
Cohesion: 0.30
Nodes (4): FakeDay, .isMeaningfulLog, Bool, WaterChallengeTests

### Community 65 - "YearMonth"
Cohesion: 0.20
Nodes (6): String, .current, .shortTitle, .title, YearMonth, .lengthOfMonth

### Community 66 - "CustomSupplement"
Cohesion: 0.20
Nodes (6): .custom, CustomSupplement, .isValid, Bool, String, CustomSupplementTests

### Community 67 - "LearnModels.swift"
Cohesion: 0.13
Nodes (14): ArticleBlock, bulletList, callout, heading, paragraph, ArticleCta, CtaType, openArticle (+6 more)

### Community 68 - "LearnContentTests"
Cohesion: 0.08
Nodes (10): LearnLibrary, .articles, .featured, LearnSourceMap, String, .results, LearnContentTests, StaticString (+2 more)

### Community 69 - "AuthRepository"
Cohesion: 0.22
Nodes (3): AuthRepository, Bool, String

### Community 70 - "Genesyx — Native iOS (Swift + SwiftUI) Architecture"
Cohesion: 0.08
Nodes (23): Auth, Backend / Data Layer, Conventions, Cycle Engine (port from `src/lib/cycle.ts` / `cycleEngine.ts`), Dark mode (must ship in v1), Dependencies (Swift Package Manager), Design Tokens (translate oklch → fixed sRGB; never compute at runtime), Feature Parity Matrix (+15 more)

### Community 71 - "Genesyx iOS — Client Change List: Audit & Execution Plan"
Cohesion: 0.09
Nodes (22): 0. Read this first, 10. Verification gate, 1. Gate 0 — decisions before any code, 2. Phase 1 — corrections (8–10d), 3. Phase 2 — the real gaps (15–18d), 4. Phase 3 — design (10–20d, design-gated), 5. Phase 4 — nutrition (15–20d), 6. Phase 5 — education (6–8d + medical review) (+14 more)

### Community 72 - ".hydrationCard"
Cohesion: 0.21
Nodes (8): .hydrationCard, HydrationStatus, HydrationStatusEvaluator, Double, String, Tone, neutral, positive

### Community 74 - "TrackingEngineVectorTests"
Cohesion: 0.29
Nodes (10): Decodable, TrackingLoggable, Expect, Bool, String, TrackingEngineVectorTests, VectorCase, VectorDay (+2 more)

### Community 75 - "QuizQuestion"
Cohesion: 0.50
Nodes (5): DidYouKnow, QuizOption, QuizQuestion, Bool, String

### Community 76 - "String"
Cohesion: 0.17
Nodes (8): RemoteConfig, .anonKey, .isConfigured, .url, SocialProvider, apple, google, String

### Community 77 - "SupplementReminder"
Cohesion: 0.23
Nodes (5): SupplementReminder, .allPossibleCopy, .body, .title, String

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
Cohesion: 0.33
Nodes (4): AuthenticationServices, CryptoKit, GoogleSignIn, Security

### Community 82 - "CaseIterable"
Cohesion: 0.14
Nodes (13): CaseIterable, FocusMode, pregnancy, prep, InviteStatus, accepted, declined, pending (+5 more)

### Community 83 - "View"
Cohesion: 0.10
Nodes (28): answers, CycleRegularityCard, .body, .cycleRegularityCard, MainTabView, .body, .initialSelection, .tabBar (+20 more)

### Community 84 - "SupplementPlanSheet"
Cohesion: 0.26
Nodes (8): .supplementReminders, SupplementPlanSheet, .addForm, .body, .yourSupplements, Binding, Content, String

### Community 85 - ".state"
Cohesion: 0.27
Nodes (5): Bool, Log, String, WaterChallenge, WaterChallengeState

### Community 86 - "NotificationTarget"
Cohesion: 0.22
Nodes (8): NotificationTarget, home, insights, learn, nutrition, ph, profile, track

### Community 87 - "CycleRepository"
Cohesion: 0.09
Nodes (18): AppBackend, Bool, CycleRepository, .pendingPush, Bool, CycleBackend, GenesyxBackend, RemoteError (+10 more)

### Community 88 - "supabase_schema.sql"
Cohesion: 0.29
Nodes (9): on_auth_user_created, public.current_partner_id(), public.cycle_settings, public.daily_logs, public.partner_invites, public.ph_readings, public.profiles, auth.users (+1 more)

### Community 89 - "Genesyx — unattended session report"
Cohesion: 0.11
Nodes (18): 10. What's left for you, 🔴 #1 — Sign-out leaked the previous user's notification state to the next one, 1. TestFlight, 2. Test suite, 🔴 #2 — The partner invite never reached the partner, 3. End-to-end sync — THE FLAGSHIP RESULT, 🟠 #3 — The shared invite code was the wrong code, 🟠 #4 — A refused invite still showed a linked partner (+10 more)

### Community 91 - "HydrationUnit"
Cohesion: 0.11
Nodes (15): .hydration, HydrationPrefs, .current, .hydrationGlassMl, .hydrationUnit, HydrationFormat, HydrationUnit, cups (+7 more)

### Community 92 - "PART 2 — APP STORE CONNECT AUDIT"
Cohesion: 0.12
Nodes (16): 1.1 Privacy Policy URL, 1.2 Support / Marketing URL, 1.3 Privacy Policy alternate paths (only if 1.1 failed), 2.0 Confirm authenticated, 2.1 App record exists (C1), 2.2 Version 1.0 page — App Store tab (C2), 2.3 App Privacy (C3), 2.4 Age Rating (C4) (+8 more)

### Community 94 - "DayType"
Cohesion: 0.22
Nodes (7): Color, DayType, fertile, follicular, luteal, ovulation, period

### Community 95 - "verify_review_account.sh"
Cohesion: 0.29
Nodes (5): api_header, auth_header, verify_review_account.sh script, SUPABASE_ANON_KEY, SUPABASE_URL

### Community 96 - "Genesyx — "Is it real?" fix pass"
Cohesion: 0.12
Nodes (16): 1. A note on how this session ran, 2. Fixes in this session, 3. What I reverted (and why), 4. Files changed, 5. What is NOT fixed — because it needs your decision, 6. Still only provable on a real device, 7. Recommended next steps, A. No invite email is ever sent (+8 more)

### Community 97 - "SleepDetailView"
Cohesion: 0.20
Nodes (8): DailyLogSyncState, pendingSync, saved, synced, Bool, .body, SleepDetailView, .body

### Community 98 - ".isValid"
Cohesion: 0.33
Nodes (3): EmailValidator, Bool, String

### Community 99 - "Step"
Cohesion: 0.33
Nodes (6): Step, intro, quiz, splash, summary, waitlist

### Community 102 - "XCTestCase"
Cohesion: 0.13
Nodes (6): BrandAssetTests, PhContentGuardTests, Set, String, NotificationFlowUITests, XCTestCase

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
Cohesion: 0.22
Nodes (5): HydrationDetailSheet, .glassMl, .manualEntry, .manualValue, .unit

### Community 108 - "Reachability"
Cohesion: 0.23
Nodes (6): Reachability, Bool, Void, MainActor, Network, NWPathMonitor

### Community 109 - "Genesyx — App Store Submission Pack"
Cohesion: 0.15
Nodes (11): Current release facts, Genesyx — App Store Connect Listing, Submission rule, 1. Listing metadata (copy/paste into App Store Connect), 2. App Privacy answers (App Store Connect → App Privacy), 3. Age rating questionnaire guidance, 4. Sign in with Apple note, 5. App Review access and notes (+3 more)

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

### Community 117 - ".from"
Cohesion: 0.33
Nodes (3): Calendar, Date, Date

### Community 118 - "Your tasks — do them in order, stop and tell me before any irreversible action"
Cohesion: 0.18
Nodes (10): 1. Produce the Release archive, 2. Validate the archive before upload, 3. Real-device test (pre-upload sanity), 4. Upload to App Store Connect, 5. App Store Connect record + metadata, 6. TestFlight internal + submit for review, Claude Code Prompt — Genesyx iOS App Store Submission, Context — already verified (+2 more)

### Community 119 - "Genesyx — Feature Overview"
Cohesion: 0.18
Nodes (10): Authentication & onboarding, Cross-cutting, Genesyx — Feature Overview, Home, Insights (all from real logged data), Learn, Notes, Nutrition (+2 more)

### Community 120 - "Run Genesyx on your Mac — Checklist"
Cohesion: 0.18
Nodes (10): 0. Prerequisites (one-time), 1. Get the code, 2. Verify the domain layer (no Xcode UI needed), 3. Generate & open the app, 4. Signing (first build only), 5. Run, 6. If the build fails, 7. Drop in assets (anytime) (+2 more)

### Community 121 - ".uiTestSeeded"
Cohesion: 0.25
Nodes (4): App, GenesyxApp, .body, Scene

### Community 123 - "TestFlight — Genesyx 1.2.0 (18)"
Cohesion: 0.22
Nodes (8): Beta App Review Information (for the External test submission), Build facts, Pre-flight — do these before uploading, Release checklist, TestFlight — Genesyx 1.2.0 (18), What P0-4 was, What's NOT in this build (say so if asked), "What to Test" (paste into TestFlight → Build 18 → Test Details)

### Community 124 - "Parity Audit & Bug-Fix Batch (mirrors Android 28 Jul batch)"
Cohesion: 0.22
Nodes (8): Contract vectors, Decision, Next actions (queued, blocked externally), Non-reproducing edge notes (flagged, not fixed — surgical discipline), Parity Audit & Bug-Fix Batch (mirrors Android 28 Jul batch), Phase 1 — Audit results, Tests, Worklog — 2026-07-28

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

### Community 136 - ".userNotificationCenter"
Cohesion: 0.33
Nodes (4): UNNotification, UNNotificationPresentationOptions, UNNotificationResponse, UNUserNotificationCenter

### Community 137 - "Genesyx (iOS)"
Cohesion: 0.29
Nodes (6): Architecture, Docs, Genesyx (iOS), Notes, Quick start (Mac), Status — local-only v1 is code-complete

### Community 138 - "6. Nutrition tab"
Cohesion: 0.33
Nodes (6): 6.1 Header, 6.2 Hydration coach card, 6.3 Focus foods card, 6.4 Supplement plan card, 6.5 Articles section, 6. Nutrition tab

### Community 140 - "TestFlight — Genesyx 1.1.1 (17)"
Cohesion: 0.33
Nodes (5): Beta App Review Information (for the External test submission), Build facts, TestFlight — Genesyx 1.1.1 (17), What's NOT in this build (say so if asked), "What to Test" (paste into TestFlight → Build 17 → Test Details)

### Community 141 - "20260712_sync_hardening.sql"
Cohesion: 0.47
Nodes (4): public.bump_updated_at, cycle_settings_bump_updated_at, daily_logs_bump_updated_at, profiles_bump_updated_at

### Community 142 - "0. Design system — the vocabulary every screen uses"
Cohesion: 0.40
Nodes (5): 0.1 Colour palette (`GenesyxColors.swift`), 0.2 Type scale (`Typography.swift`, Apple system font), 0.3 Reusable controls (`GenesyxControls.swift`) — button colours, 0.4 Navigation shell, 0. Design system — the vocabulary every screen uses

### Community 143 - "Resources"
Cohesion: 0.40
Nodes (4): Accent color, App icon, Fonts, Resources

### Community 144 - "Genesyx — Backend Live Test Plan (Supabase)"
Cohesion: 0.40
Nodes (4): Genesyx — Backend Live Test Plan (Supabase), Notes, Preconditions, Test matrix

### Community 146 - ".handleApple"
Cohesion: 0.50
Nodes (3): Error, ASAuthorization, Result

### Community 148 - "public.user_supplements"
Cohesion: 0.67
Nodes (3): public.genesyx_products, public.user_supplements, auth.users

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

## Knowledge Gaps
- **726 isolated node(s):** `.id`, `.colorScheme`, `saved`, `synced`, `pendingSync` (+721 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

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

- **Why does `Int` connect `Int` to `DayPart`, `CycleSettings`, `InsightsView.swift`, `Eyebrow`, `TrackView`, `DailyLogRepository`, `GenesyxUITests`, `LogView`, `LifecycleE2ETests`, `.minusDays`, `AuthBackend`, `HomeView`, `SleepSmokeUITests`, `PreferencesRepository`, `SupplementPersonalisationTests`, `NotificationPlannerTests`, `DailyLog`, `Sendable`, `.addingDays`, `CycleEngineTests`, `CalendarDate`, `NutritionView`, `NutritionHydrationTests`, `PhReading`, `NotificationService`, `HydrationInsightTests`, `GenesyxColor`, `AuthView`, `LearnArticle`, `ConsistencyInsightLogicTests`, `NotificationTests`, `NotificationSnapshot`, `NotificationTab`, `Phase`, `TrackView.swift`, `.content`, `LearnCandidate`, `Recipe`, `String`, `NutritionConsistencyInsights`, `.compute`, `TrackSignalSummary`, `StreakState`, `WaterChallengeTests`, `YearMonth`, `.hydrationCard`, `PersistenceTests`, `TrackingEngineVectorTests`, `SupplementReminder`, `CycleSettingsSheet`, `View`, `.state`, `NotificationTarget`, `HydrationUnit`, `OvulationLogicTests`, `SleepDetailView`, `CitationE2ETests`, `HydrationDetailSheet`, `.cyclePhase`, `.from`?**
  _High betweenness centrality (0.157) - this node is a cross-community bridge._
- **Why does `CalendarDate` connect `CalendarDate` to `DayPart`, `CycleSettings`, `InsightsView.swift`, `TrackView`, `DailyLogRepository`, `LogView`, `.minusDays`, `AuthBackend`, `PreferencesRepository`, `SupplementPersonalisationTests`, `DailyLog`, `Sendable`, `RepositoryTests`, `.addingDays`, `CycleEngineTests`, `NotificationService`, `Int`, `HydrationInsightTests`, `GenesyxColor`, `Foundation`, `LearnArticle`, `Phase`, `.content`, `TrackSignalSummary`, `StreakState`, `Image`, `WaterChallengeTests`, `YearMonth`, `LearnContentTests`, `PersistenceTests`, `TrackingEngineVectorTests`, `CycleSettingsSheet`, `.state`, `OvulationLogicTests`, `HydrationDetailSheet`, `.cyclePhase`, `.from`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `PreferencesRepository` connect `PreferencesRepository` to `.inviteCode`, `Foundation`, `.userNotificationCenter`, `NotificationSlot`, `ProfileView`, `CaseIterable`, `RepositoryTests`, `SupplementPlanSheet`, `View`, `CycleRepository`, `NotificationService`, `Int`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 47 inferred relationships involving `CalendarDate` (e.g. with `.snapshot()` and `.body`) actually correct?**
  _`CalendarDate` has 47 INFERRED edges - model-reasoned connections that need verification._
- **Are the 27 inferred relationships involving `DailyLog` (e.g. with `.uiTestSeeded()` and `.previewSeeded()`) actually correct?**
  _`DailyLog` has 27 INFERRED edges - model-reasoned connections that need verification._
- **Are the 72 inferred relationships involving `Image` (e.g. with `.stepButton()` and `.body`) actually correct?**
  _`Image` has 72 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.id`, `.colorScheme`, `saved` to the rest of the system?**
  _726 weakly-connected nodes found - possible documentation gaps or missing edges._