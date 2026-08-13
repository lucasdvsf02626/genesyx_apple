# Graph Report - .  (2026-08-13)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1963 nodes · 5051 edges · 120 communities (97 shown, 23 thin omitted)
- Extraction: 87% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 623 edges (avg confidence: 0.8)
- Token cost: 185,290 input · 10,083 output

## Graph Freshness
- Built from commit: `547d2d4f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Insights View UI
- Notification Planning
- Learn Article Models
- Daily Log Repository
- Hydration & Sleep History
- Learn Hero Art Assets
- Session Repository
- Supabase Auth
- Log View & Layout
- Supabase Backend
- Brand Assets & Docs
- Hydration Coach Tests
- Cycle Repository
- Partner Invite Model
- Shared UI Controls
- pH Tracker UI
- Notification Service
- Tracking Engine Vector Tests
- Profile View
- Cycle Domain Models
- Remote Data Models
- Cycle Phase Content
- Partner Repository Tests
- pH Repository
- Weekly Summary View
- Core Test Suite
- Auth View & Social Sign-In
- Cycle Regularity Insights
- App Container Bootstrap
- Onboarding Flow
- Persistence DTOs
- Nutrition View
- Cycle Engine Tests
- Medical Source Citations
- Weekly Summary Logic Tests
- Core Repositories & Backend
- Deep Link Handling
- Consistency Insight Logic
- Backend Swap Tests
- Hydration Insight Tests
- Auth Repository
- Cycle Settings Sheet
- Insights View Logic
- pH Reading Model
- Daily Log Sync & Sleep Detail
- pH Sync
- Home Screen View
- Track Calendar View
- Weekly Summary Logic
- Nutrition Content
- Hydration Notification Timing
- Top-Level App Views
- Learn Categories
- Citation E2E Tests
- App UI Tests
- Milestone Notifications
- Track Signal Summary
- Calendar Month Grid
- Nutrition Consistency Logic
- Sleep Insight Logic
- Notification Kinds
- Partner Section UI
- Track Detail Views
- Content Guard & Quiz Tests
- Hydration Detail Sheet
- Sign-Out State Cleanup
- Supabase Schema
- Fake Partner Backend
- Notification Router
- Tracking Engine Streaks
- App Store Screenshots
- Root View & Invite Presentation
- Supabase Edge Functions
- Notification Tab Targets
- Hydration & Nutrition Coaching
- Persistence Round-Trip Tests
- Account Data Lifecycle
- pH Insight Logic
- Medical Citation Bug & Tests
- Cycle Detail View
- App Lifecycle E2E Tests
- Partner Invite Backend
- Invite View
- Review Account Verification Script
- Cycle Engine Calendar Math
- Notification Scheduling State
- Sleep Smoke UI Tests
- Sync Hardening Migration
- Partner Backend Config
- Remote Error Types
- Cycle Phase Computation
- Cross-Feature Navigation State
- pH Data Sync
- Medical Sources Screenshots
- Partner Invite Bugs
- App Routing
- Project Status Reports
- pH Content Health Citations
- Partner Invite Feature
- Streak Tracking Engine
- Graphify Configuration
- Learn Content Handoff
- Cycle Setup Flow
- Deep Link & Invite Email
- Learn Content & Inventory
- Local Storage
- Swift Package Config
- App Store Screenshots
- Cache Storage
- Genesyx Changelog
- Sleep Tracking UI Tests
- Urinalysis Citation
- Unattended Session Report
- Push Notification Migration
- User Profiles Table
- User Profiles Table
- Day Part / Timezone Logic
- History Sparkline UI
- Invite Share Sheet

## God Nodes (most connected - your core abstractions)
1. `CalendarDate` - 148 edges
2. `DailyLog` - 81 edges
3. `GenesyxColor` - 65 edges
4. `CycleSettings` - 62 edges
5. `DailyLogRepository` - 54 edges
6. `GenesyxCore` - 51 edges
7. `PhReading` - 44 edges
8. `NotificationService` - 43 edges
9. `Eyebrow` - 40 edges
10. `PhRepository` - 36 edges

## Surprising Connections (you probably didn't know these)
- `Mismatched 'Urine Tracker' App Screenshot` --conceptually_related_to--> `Feature Overview`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urine45.imageset/urine45.png → docs/FEATURES.md
- `Mismatched 'Urine Tracker' Log Screenshot` --conceptually_related_to--> `Feature Overview`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urinetrack34.imageset/urinetrack34.png → docs/FEATURES.md
- `Mismatched 'Urine Tracker' Chart Screenshot` --conceptually_related_to--> `Feature Overview`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urinetrack67.imageset/urinetrack67.png → docs/FEATURES.md
- `Home Hero Background` --conceptually_related_to--> `Genesyx iOS Architecture`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/home_hero_bg.imageset/home_hero_bg.jpg → ARCHITECTURE.md
- `Genesyx Brand Lockup (light)` --conceptually_related_to--> `Genesyx iOS README`  [INFERRED]
  App/Genesyx/Resources/Assets.xcassets/brand_lockup.imageset/brand_lockup.png → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Mismatched Legacy 'Urine Tracker' Placeholder Images** — app_genesyx_resources_assets_xcassets_urine45_imageset_urine45, app_genesyx_resources_assets_xcassets_urinetrack34_imageset_urinetrack34, app_genesyx_resources_assets_xcassets_urinetrack67_imageset_urinetrack67, docs_features [AMBIGUOUS 0.40]
- **App Store Six-Tab Screenshot Set** — docs_app_store_submission, docs_appstore_screenshots_1_home, docs_appstore_screenshots_2_track, docs_appstore_screenshots_3_nutrition, docs_appstore_screenshots_4_insights, docs_appstore_screenshots_5_learn, docs_appstore_screenshots_6_profile [EXTRACTED 0.85]
- **Privileged Ops via Supabase Edge Functions** — supabase_functions_readme, supabase_functions_accept_partner_invite, supabase_functions_unlink_partner, supabase_functions_delete_account, ios_supabasebackend [EXTRACTED 0.85]
- **Guideline 1.4.1 Medical Citation System** — changelog_medicalsource, changelog_citationlink, changelog_sourcesfooter, changelog_medicalsourcesview, changelog_citatione2etests [EXTRACTED 0.90]
- **Vaginal pH Migration** — changelog_phstatus, changelog_phreading, changelog_phinsightlogic, changelog_phcopy, changelog_vaginal_ph_citation [EXTRACTED 0.90]
- **Learn Hub Article Hero Images** — app_genesyx_resources_assets_xcassets_learn_hero_habits_imageset_learn_hero_habits, app_genesyx_resources_assets_xcassets_learn_hero_hydration_imageset_learn_hero_hydration, app_genesyx_resources_assets_xcassets_learn_hero_insights_imageset_learn_hero_insights, app_genesyx_resources_assets_xcassets_learn_hero_logging_imageset_learn_hero_logging, app_genesyx_resources_assets_xcassets_learn_hero_supplements_imageset_learn_hero_supplements, app_genesyx_resources_assets_xcassets_learn_hero_trends_imageset_learn_hero_trends, app_genesyx_resources_assets_xcassets_learn_hero_using_imageset_learn_hero_using, app_genesyx_resources_assets_xcassets_learn_hero_what_to_log_imageset_learn_hero_what_to_log, docs_features [INFERRED 0.60]
- **App Store Screenshot Tour (Home -> Track -> Nutrition -> Insights -> Profile)** — docs_screenshots_1, docs_screenshots_2_home, docs_screenshots_3_nutrition, docs_screenshots_4_insights, docs_screenshots_5_profile [INFERRED 0.70]
- **Medical Disclaimer & Citation List Views** — docs_review_evidence_simulator_screenshot_iphone_17_pro_2026_07_20_at_10_51_18, docs_review_evidence_simulator_screenshot_iphone_17_pro_2026_07_20_at_10_51_38, docs_review_evidence_simulator_screenshot_iphone_17_pro_2026_07_20_at_10_51_46, docs_review_evidence_simulator_screenshot_iphone_17_pro_2026_07_20_at_10_51_54, concept_medical_disclaimer_sources [INFERRED 0.75]
- **Partner Invite Flow** — report_2026_07_12_unattended_partnerrepository, report_2026_07_12_unattended_inviteview, report_2026_07_12_unattended_inviteshare_sheet, app_inventory_accept_partner_invite_fn, architecture_partner_invites_table [INFERRED 0.80]

## Communities (120 total, 23 thin omitted)

### Community 0 - "Insights View UI"
Cohesion: 0.05
Nodes (49): ConsistencyCard, .body, .weekDots, DashedLine, HydrationInsightsCard, .body, .chart, .body (+41 more)

### Community 1 - "Notification Planning"
Cohesion: 0.07
Nodes (28): LearnCandidate, NotificationPlan, .hydration, .hydrationRestDays, .weekly, NotificationPlanner, NotificationSlot, hydration (+20 more)

### Community 2 - "Learn Article Models"
Cohesion: 0.06
Nodes (42): ArticleBlock, bulletList, callout, heading, paragraph, ArticleCta, CtaType, openArticle (+34 more)

### Community 3 - "Daily Log Repository"
Cohesion: 0.14
Nodes (7): DailyLogRepository, Set, .hydrationCard, FakeDailyLogBackend, FakePhBackend, FakeProfileBackend, RepositoryTests

### Community 4 - "Hydration & Sleep History"
Cohesion: 0.12
Nodes (14): HydrationHistoryRow, .displayTotal, sleepHistoryCard(), SleepHistoryRow, .iso, Calendar, Date, Comparable (+6 more)

### Community 5 - "Learn Hero Art Assets"
Cohesion: 0.05
Nodes (44): Learn Hero: Foggy Path (Habits), Learn Hero: Pouring Water Glass (Hydration), Learn Hero: Trend-line Illustration (Insights), Learn Hero: Open Journal & Pen (Logging), Learn Hero: Open Palm (Supplements), Learn Hero: Scatter Plot with Trend Line (Trends), Learn Hero: Hand Opening Door (Using the App), Learn Hero: Water, Pencil & Pear (What to Log) (+36 more)

### Community 6 - "Session Repository"
Cohesion: 0.09
Nodes (9): SessionRepository, Bool, Void, .body, .signOutButton, AuthPartnerBackendTests, FakeAuth, .currentUserId (+1 more)

### Community 7 - "Supabase Auth"
Cohesion: 0.12
Nodes (15): SupabaseAuth, .currentUserId, Bool, LearnSourceMap, Hashable, FocusCopy, FocusFood, PhaseHeroCopy (+7 more)

### Community 8 - "Log View & Layout"
Cohesion: 0.08
Nodes (28): FlowLayout, CGFloat, CGRect, Void, LogView, .addSymptomChip, .allSymptoms, .body (+20 more)

### Community 9 - "Supabase Backend"
Cohesion: 0.14
Nodes (10): AuthBackend, requireUID(), SupabaseBackend, SupabaseCycle, SupabaseDailyLog, SupabasePartner, SupabasePh, SupabaseProfile (+2 more)

### Community 10 - "Brand Assets & Docs"
Cohesion: 0.06
Nodes (35): App Icon (1024px G logo), Genesyx Brand Lockup (dark), Genesyx Brand Lockup (light), Egg Female splash asset, Egg Male splash asset, Home Hero Background, Launcher Icon Foreground, Launcher Icon Monochrome (+27 more)

### Community 11 - "Hydration Coach Tests"
Cohesion: 0.11
Nodes (11): .hydrationCard, NutritionHydrationTests, HydrationCoach, .allStrings, Double, HydrationStatus, HydrationStatusEvaluator, Double (+3 more)

### Community 12 - "Cycle Repository"
Cohesion: 0.07
Nodes (22): CycleRepository, .pendingPush, Bool, .pendingDates, LocalStore, Bool, PreferencesRepository, .celebratedMilestones (+14 more)

### Community 13 - "Partner Invite Model"
Cohesion: 0.25
Nodes (7): PartnerInviteRow, .domain, InviteStatus, accepted, pending, revoked, PartnerInvite

### Community 14 - "Shared UI Controls"
Cohesion: 0.11
Nodes (28): BrandOrb, .body, Color, Eyebrow, .body, GxBackButton, .body, GxGhostButton (+20 more)

### Community 15 - "pH Tracker UI"
Cohesion: 0.05
Nodes (39): PhChart, .body, PhLogSheet, .body, PhRange, all, .days, .id (+31 more)

### Community 16 - "Notification Service"
Cohesion: 0.12
Nodes (14): AnyCancellable, NotificationService, .isActive, .isOn, .isSystemDenied, Bool, .reminderPromptSheet, NSObject (+6 more)

### Community 17 - "Tracking Engine Vector Tests"
Cohesion: 0.30
Nodes (9): Decodable, TrackingLoggable, Expect, Bool, TrackingEngineVectorTests, VectorCase, VectorDay, VectorFile (+1 more)

### Community 18 - "Profile View"
Cohesion: 0.14
Nodes (16): EditNameSheet, .body, ProfileView, .aboutGroup, .accountGroup, .focusSection, .name, .remindersSection (+8 more)

### Community 19 - "Cycle Domain Models"
Cohesion: 0.12
Nodes (21): CaseIterable, Sendable, OvulationInsights, FocusMode, pregnancy, prep, ThemeMode, dark (+13 more)

### Community 20 - "Remote Data Models"
Cohesion: 0.05
Nodes (40): CodingKeys, code, cycleLength, date, deletedAt, displayName, energy, focusMode (+32 more)

### Community 21 - "Cycle Phase Content"
Cohesion: 0.21
Nodes (3): CycleContent, Bool, ContentTests

### Community 22 - "Partner Repository Tests"
Cohesion: 0.27
Nodes (4): PartnerRepository, FakePartnerBackend, PartnerTests, Bool

### Community 23 - "pH Repository"
Cohesion: 0.28
Nodes (5): PhRepository, Double, PhBackend, PhTrackerSection, .body

### Community 24 - "Weekly Summary View"
Cohesion: 0.11
Nodes (14): Bool, CGFloat, CGRect, Double, Path, WeeklyDashedLine, WeeklySummaryView, .body (+6 more)

### Community 25 - "Core Test Suite"
Cohesion: 0.16
Nodes (3): Genesyx, GenesyxCore, XCTest

### Community 26 - "Auth View & Social Sign-In"
Cohesion: 0.12
Nodes (12): AuthView, .body, .divider, Binding, Bool, Error, Void, ASAuthorization (+4 more)

### Community 27 - "Cycle Regularity Insights"
Cohesion: 0.16
Nodes (6): .body, RealInsightsTests, FakeCycleBackend, SymptomPatternInsights, SymptomPatternLogic, CycleSettings

### Community 28 - "App Container Bootstrap"
Cohesion: 0.11
Nodes (10): App, AppContainer, GenesyxApp, .body, GenesyxBackend, LearnReadLog, .readSlugs, Set (+2 more)

### Community 29 - "Onboarding Flow"
Cohesion: 0.13
Nodes (19): .body, OnboardingFlowView, .body, OnboardingIntroView, QuizView, .isLast, .question, .selected (+11 more)

### Community 30 - "Persistence DTOs"
Cohesion: 0.10
Nodes (15): .dto, DailyLogDTO, .domain, CycleSettingsRow, .domain, DailyLogRow, .isBlank, SleepTrackingData (+7 more)

### Community 31 - "Nutrition View"
Cohesion: 0.21
Nodes (10): NutritionView, .articlesSection, .body, .phase, .supplementPlanCard, .supplementsTakenLabel, SupplementAvatar, .body (+2 more)

### Community 33 - "Medical Source Citations"
Cohesion: 0.18
Nodes (7): MedicalSource, URL, MedicalSourceStore, CitationLink, .body, SourcesFooter, .body

### Community 34 - "Weekly Summary Logic Tests"
Cohesion: 0.14
Nodes (5): .startOfWeek, Double, WeeklySummaryLogicTests, StreakEngineTests, Set

### Community 35 - "Core Repositories & Backend"
Cohesion: 0.10
Nodes (7): AppBackend, Combine, Foundation, CycleRegularityLogic, OvulationLogic, PhCopy, UserNotifications

### Community 36 - "Deep Link Handling"
Cohesion: 0.25
Nodes (3): DeepLink, URL, DeepLinkTests

### Community 37 - "Consistency Insight Logic"
Cohesion: 0.17
Nodes (8): .phCountLine, ConsistencyCardModel, ConsistencyInsightLogic, HydrationDeltaLogic, PhContextLogic, Bool, ConsistencyInsightLogicTests, Bool

### Community 39 - "Hydration Insight Tests"
Cohesion: 0.16
Nodes (5): .hydrationInsightsCard, HydrationInsightTests, HydrationInsightLogic, HydrationInsights, Bool

### Community 40 - "Auth Repository"
Cohesion: 0.14
Nodes (5): AuthRepository, Bool, SocialProvider, apple, google

### Community 41 - "Cycle Settings Sheet"
Cohesion: 0.29
Nodes (7): CycleSettingsSheet, .body, .lastPeriodBinding, Binding, Date, Void, ClosedRange

### Community 42 - "Insights View Logic"
Cohesion: 0.19
Nodes (14): InsightsView, .currentWeek, .currentWeekSleep, .currentWeekSupplements, .header, .hydrationDeltaLine, .streakState, .symptomDates (+6 more)

### Community 43 - "pH Reading Model"
Cohesion: 0.16
Nodes (15): .dto, PhReadingDTO, .domain, .record, .dto, Bool, Date, Double (+7 more)

### Community 44 - "Daily Log Sync & Sleep Detail"
Cohesion: 0.24
Nodes (6): DailyLogSyncState, .label, saved, synced, willSyncWhenOnline, SleepDetailView

### Community 45 - "pH Sync"
Cohesion: 0.14
Nodes (9): .records, PhRecord, .id, PhSync, Bool, Date, PhSyncTests, Bool (+1 more)

### Community 46 - "Home Screen View"
Cohesion: 0.10
Nodes (17): HomeView, .greeting, .greetingHeader, .hydrationCard, .phNudgeCard, .setupCard, Double, CycleRegularityCard (+9 more)

### Community 47 - "Track Calendar View"
Cohesion: 0.12
Nodes (16): Bool, Void, TrackView, .calendarCard, .currentPhaseCard, .divider, .emptyCalendar, .header (+8 more)

### Community 48 - "Weekly Summary Logic"
Cohesion: 0.12
Nodes (21): Equatable, EnergyTally, MoodTally, Bool, Double, WeeklyDeltas, WeeklySummary, WeeklySummaryLogic (+13 more)

### Community 49 - "Nutrition Content"
Cohesion: 0.17
Nodes (11): .header, Article, .id, FoodAccent, follicular, luteal, ovulatory, period (+3 more)

### Community 50 - "Hydration Notification Timing"
Cohesion: 0.23
Nodes (3): Calendar, NotificationTests, Date

### Community 51 - "Top-Level App Views"
Cohesion: 0.08
Nodes (16): ErrorStateView, .body, Void, PlaceholderScreen, .body, MedicalSourcesView, .body, CGFloat (+8 more)

### Community 52 - "Learn Categories"
Cohesion: 0.18
Nodes (11): LearnCategory, gettingStarted, guides, .id, insights, .label, nutrition, .tint (+3 more)

### Community 53 - "Citation E2E Tests"
Cohesion: 0.24
Nodes (4): CitationE2ETests, XCUIApplication, StaticString, UInt

### Community 55 - "Milestone Notifications"
Cohesion: 0.21
Nodes (8): NotificationContent, .allCopyStrings, Milestone, day14, day7, .flagKey, week1, week4

### Community 57 - "Calendar Month Grid"
Cohesion: 0.24
Nodes (4): .shortTitle, .title, YearMonth, .lengthOfMonth

### Community 58 - "Nutrition Consistency Logic"
Cohesion: 0.27
Nodes (4): NutritionConsistencyInsights, NutritionConsistencyLogic, Bool, NutritionConsistencyLogicTests

### Community 59 - "Sleep Insight Logic"
Cohesion: 0.27
Nodes (3): SleepInsightLogic, SleepInsights, SleepInsightLogicTests

### Community 60 - "Notification Kinds"
Cohesion: 0.15
Nodes (12): NotificationKind, dailyHydration, milestone14, milestone7, milestoneWeek1, milestoneWeek4, weeklyInsights, weeklyLearn (+4 more)

### Community 61 - "Partner Section UI"
Cohesion: 0.18
Nodes (8): PartnerSectionView, .body, .divider, .inviteForm, .notSignedIn, .pending, EmailValidator, Bool

### Community 62 - "Track Detail Views"
Cohesion: 0.20
Nodes (11): .emptyCycleContent, insightCard(), NutritionDetailView, .body, PhDetailView, .body, .body, SymptomsDetailView (+3 more)

### Community 63 - "Content Guard & Quiz Tests"
Cohesion: 0.15
Nodes (5): PhContentGuardTests, Set, QuizContentTests, NotificationFlowUITests, XCTestCase

### Community 64 - "Hydration Detail Sheet"
Cohesion: 0.33
Nodes (4): HydrationDetailSheet, .body, .manualEntry, .manualValue

### Community 65 - "Sign-Out State Cleanup"
Cohesion: 0.18
Nodes (11): AppContainer, AuthRepository, KeychainStore, NutritionRepository, ProfileRepository, profiles table, SupabaseService, AppContainer.clearLocalState (+3 more)

### Community 66 - "Supabase Schema"
Cohesion: 0.27
Nodes (9): auth.users, on_auth_user_created, public.current_partner_id(), public.cycle_settings, public.daily_logs, public.partner_invites, public.ph_readings, public.profiles (+1 more)

### Community 68 - "Notification Router"
Cohesion: 0.29
Nodes (4): Any, AnyHashable, Destination, NotificationRouter

### Community 69 - "Tracking Engine Streaks"
Cohesion: 0.51
Nodes (3): Log, Set, TrackingEngine

### Community 70 - "App Store Screenshots"
Cohesion: 0.29
Nodes (10): Fertility & Cycle Tracking, Hydration Tracking, Phase-Based Nutrition Focus, Urine pH Tracking, Home/Today Screen — fertile window & hydration (size A), Track/Cycle Calendar Screen — urine tracker (size A), Nutrition Focus Screen — hydration & pH chart (cropped), Nutrition Focus Screen — hydration & pH chart (with tab bar) (+2 more)

### Community 71 - "Root View & Invite Presentation"
Cohesion: 0.22
Nodes (8): InvitePresentation, .id, RootView, .colorScheme, Benefit, Color, ColorScheme, Identifiable

### Community 72 - "Supabase Edge Functions"
Cohesion: 0.47
Nodes (3): json(), requireUser(), serviceClient()

### Community 73 - "Notification Tab Targets"
Cohesion: 0.22
Nodes (7): NotificationTab, home, insights, learn, nutrition, profile, track

### Community 74 - "Hydration & Nutrition Coaching"
Cohesion: 0.22
Nodes (9): Learn Hero: Eating Across the Cycle, daily_logs table, DailyLogRepository, HydrationCoach, HydrationInsightLogic, HydrationStatusEvaluator, NutritionContent, daily_logs table (+1 more)

### Community 76 - "Account Data Lifecycle"
Cohesion: 0.22
Nodes (9): AppContainer, cycle_settings table, CycleRepository, delete_account Edge Function, PreferencesRepository, profiles table, SessionRepository, cycle_settings table (+1 more)

### Community 77 - "pH Insight Logic"
Cohesion: 0.22
Nodes (9): PhInsightLogic, PhStatus, PhInsightLogic, PhInsightLogicTests, PhReading, PhReadingDTO (local DTO), PhReadingRow (remote DTO), PhRepository (+1 more)

### Community 78 - "Medical Citation Bug & Tests"
Cohesion: 0.25
Nodes (9): BUG-1: hydration card tap conflict, CitationE2ETests, CitationLink, LearnSourceMap, LifecycleE2ETests, MedicalSource, MedicalSourceStore, MedicalSourcesView (+1 more)

### Community 79 - "Cycle Detail View"
Cohesion: 0.26
Nodes (6): CycleDetailView, .body, CyclePredictionCopy, DayDetailSheet, .body, .loggedSummary

### Community 81 - "Partner Invite Backend"
Cohesion: 0.25
Nodes (8): accept_partner_invite Edge Function, partner_invites table, PartnerRepository, send_partner_invite Edge Function, unlink_partner Edge Function, InviteAcceptView, partner_invites table, PartnerRepository

### Community 82 - "Invite View"
Cohesion: 0.29
Nodes (5): InviteView, .body, .valid, Bool, Void

### Community 83 - "Review Account Verification Script"
Cohesion: 0.29
Nodes (5): api_header, auth_header, verify_review_account.sh script, SUPABASE_ANON_KEY, SUPABASE_URL

### Community 84 - "Cycle Engine Calendar Math"
Cohesion: 0.14
Nodes (10): DayInfo, .id, CycleEngine, CycleRegularityInsights, Bool, .weekdaySundayZero, Int, TrackingMetrics (+2 more)

### Community 87 - "Sync Hardening Migration"
Cohesion: 0.47
Nodes (4): public.bump_updated_at, cycle_settings_bump_updated_at, daily_logs_bump_updated_at, profiles_bump_updated_at

### Community 88 - "Partner Backend Config"
Cohesion: 0.18
Nodes (6): PartnerBackend, RemoteConfig, .anonKey, .isConfigured, .url, Bool

### Community 89 - "Remote Error Types"
Cohesion: 0.40
Nodes (5): RemoteError, emailConfirmationRequired, notAuthenticated, notConfigured, Error

### Community 90 - "Cycle Phase Computation"
Cohesion: 0.40
Nodes (5): CycleEngine, ComputeCyclePhase, CycleEngine, CycleEngineTests, GenesyxCore

### Community 91 - "Cross-Feature Navigation State"
Cohesion: 0.40
Nodes (5): LearnReadLog, NotificationPlanner, NotificationRouter, TabRouter, TabRouter (pendingPh)

### Community 92 - "pH Data Sync"
Cohesion: 0.40
Nodes (5): ph_readings table, PhRepository, PhSync, ph_readings table, PhRepository

### Community 93 - "Medical Sources Screenshots"
Cohesion: 0.50
Nodes (5): Medical Disclaimer & Sources, Medical Sources Screen (Disclaimer + References, top), Medical Sources Screen (References, scrolled), Medical Sources Screen (References, scrolled further), Medical Sources Screen (References, same scroll position)

### Community 94 - "Partner Invite Bugs"
Cohesion: 0.40
Nodes (5): Bug #3: wrong invite code shared, Bug #4: optimistic partner link on refusal, InviteView, PartnerBackend.sendInvite, PartnerRepository

### Community 95 - "App Routing"
Cohesion: 0.50
Nodes (4): RootView, MainTabView, RootView, Router / Route enum

### Community 97 - "pH Content Health Citations"
Cohesion: 0.50
Nodes (4): PhContentGuardTests, PhCopy, statpearls-vaginitis citation, vaginal-ph citation (NHS Bacterial vaginosis)

### Community 98 - "Partner Invite Feature"
Cohesion: 0.50
Nodes (4): Bug #2: invite never sent, FeatureFlags.partnerInvites, InviteShareSheet, ProfileView invite form

### Community 99 - "Streak Tracking Engine"
Cohesion: 0.67
Nodes (3): CalendarDate, StreakEngine, TrackingEngine

### Community 100 - "Graphify Configuration"
Cohesion: 0.67
Nodes (3): .claude/CLAUDE.md (graphify trigger), Root CLAUDE.md (graphify rules), graphify SKILL.md

### Community 101 - "Learn Content Handoff"
Cohesion: 0.67
Nodes (3): Learn Articles JSON (missing), iOS Learn Parity Handoff (missing), Session State Checkpoint

### Community 102 - "Cycle Setup Flow"
Cohesion: 0.28
Nodes (3): CycleSetup, Bool, CycleSetupTests

### Community 117 - "Day Part / Timezone Logic"
Cohesion: 0.25
Nodes (6): DayPart, afternoon, evening, midday, morning, night

### Community 118 - "History Sparkline UI"
Cohesion: 0.33
Nodes (6): detailHistoryCard(), SparkDots, .body, .normalized, Color, Double

### Community 119 - "Invite Share Sheet"
Cohesion: 0.40
Nodes (4): InviteShareSheet, .body, .shareText, Bool

## Ambiguous Edges - Review These
- `Genesyx iOS Architecture` → `Home Hero Background`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/home_hero_bg.imageset/home_hero_bg.jpg · relation: conceptually_related_to
- `Learn Articles JSON (missing)` → `Session State Checkpoint`  [AMBIGUOUS]
  docs/SESSION_STATE.md · relation: references
- `iOS Learn Parity Handoff (missing)` → `Session State Checkpoint`  [AMBIGUOUS]
  docs/SESSION_STATE.md · relation: references
- `Genesyx iOS Repository and App Inventory` → `Learn Hero: First Week`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/learn_hero_first_week.imageset/learn_hero_first_week.jpg · relation: conceptually_related_to
- `accept_partner_invite Edge Function` → `Profile Screen — partner invite & account (cropped)`  [AMBIGUOUS]
  docs/screenshots/5-Insights.png · relation: conceptually_related_to
- `accept_partner_invite Edge Function` → `Profile Screen — partner invite & account (with tab bar)`  [AMBIGUOUS]
  docs/screenshots/5-Profile.png · relation: conceptually_related_to
- `Feature Overview` → `Mismatched 'Urine Tracker' App Screenshot`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urine45.imageset/urine45.png · relation: conceptually_related_to
- `Feature Overview` → `Mismatched 'Urine Tracker' Log Screenshot`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urinetrack34.imageset/urinetrack34.png · relation: conceptually_related_to
- `Feature Overview` → `Mismatched 'Urine Tracker' Chart Screenshot`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urinetrack67.imageset/urinetrack67.png · relation: conceptually_related_to
- `Mismatched 'Urine Tracker' App Screenshot` → `App Store Screenshot: Nutrition`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/urine45.imageset/urine45.png · relation: semantically_similar_to
- `NutritionContent` → `Learn Hero: Eating Across the Cycle`  [AMBIGUOUS]
  App/Genesyx/Resources/Assets.xcassets/learn_hero_eating_cycle.imageset/learn_hero_eating_cycle.jpg · relation: conceptually_related_to
- `Medical Sources Screen (References, scrolled further)` → `Medical Sources Screen (References, same scroll position)`  [AMBIGUOUS]
  docs/review_evidence/Simulator Screenshot - iPhone 17 Pro - 2026-07-20 at 10.51.54.png · relation: semantically_similar_to

## Knowledge Gaps
- **323 isolated node(s):** `FeatureFlags`, `PhCopy`, `Font`, `.body`, `.header` (+318 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **23 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Genesyx iOS Architecture` and `Home Hero Background`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Learn Articles JSON (missing)` and `Session State Checkpoint`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `iOS Learn Parity Handoff (missing)` and `Session State Checkpoint`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Genesyx iOS Repository and App Inventory` and `Learn Hero: First Week`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `accept_partner_invite Edge Function` and `Profile Screen — partner invite & account (cropped)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `accept_partner_invite Edge Function` and `Profile Screen — partner invite & account (with tab bar)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Feature Overview` and `Mismatched 'Urine Tracker' App Screenshot`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._