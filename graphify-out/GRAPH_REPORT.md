# Graph Report - .  (2026-08-12)

## Corpus Check
- Large corpus: 269 files · ~591,398 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 2121 nodes · 6002 edges · 102 communities (89 shown, 13 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 715 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101

## God Nodes (most connected - your core abstractions)
1. `CalendarDate` - 168 edges
2. `DailyLog` - 109 edges
3. `GenesyxColor` - 72 edges
4. `CycleSettings` - 69 edges
5. `DailyLogRepository` - 66 edges
6. `RepositoryTests` - 63 edges
7. `GenesyxCore` - 62 edges
8. `PreferencesRepository` - 57 edges
9. `NotificationService` - 48 edges
10. `PhReading` - 46 edges

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

## Communities (102 total, 13 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (22): BrandAssetTests, CalendarContrastTests, .tintedFills, PregnancyContrastTests, Color, Double, StaticString, UInt (+14 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (28): DailyLogSyncState, .label, saved, synced, willSyncWhenOnline, .hydration, HydrationPrefs, .current (+20 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (47): ConsistencyCard, .body, .weekDots, CycleRegularityCard, .body, DashedLine, HydrationInsightsCard, .body (+39 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (50): answers, BrandEgg, .body, BrandOrb, .body, GxBackButton, .body, GxGhostButton (+42 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (35): DayDetailSheet, .eyebrow, .loggedSummary, DayInfo, .id, LogTarget, .id, NutritionDetailView (+27 more)

### Community 5 - "Community 5"
Cohesion: 0.12
Nodes (19): DailyLogRepository, Set, InsightsView, .currentWeek, .currentWeekSleep, .currentWeekSupplements, .header, .hydrationDeltaLine (+11 more)

### Community 6 - "Community 6"
Cohesion: 0.09
Nodes (5): GenesyxUITests, StaticString, UInt, XCUIApplication, XCUIElement

### Community 7 - "Community 7"
Cohesion: 0.08
Nodes (28): FlowLayout, CGFloat, CGRect, Void, LogView, .addSymptomChip, .allSymptoms, .body (+20 more)

### Community 8 - "Community 8"
Cohesion: 0.14
Nodes (7): RealInsightsTests, FakeCycleBackend, MidDrainCycleBackend, Void, SymptomPatternInsights, SymptomPatternLogic, CycleSettings

### Community 9 - "Community 9"
Cohesion: 0.09
Nodes (18): PhInsightLogic, PhInsights, Bool, Date, Double, TimeInterval, Trend, down (+10 more)

### Community 10 - "Community 10"
Cohesion: 0.11
Nodes (14): AuthBackend, CycleBackend, DailyLogBackend, PhBackend, requireUID(), SupabaseBackend, SupabaseCycle, SupabaseDailyLog (+6 more)

### Community 11 - "Community 11"
Cohesion: 0.08
Nodes (22): HomeView, .body, .greeting, .greetingHeader, .hydrationCard, .learnCard, .phNudgeCard, .pregnancyPathwayLink (+14 more)

### Community 12 - "Community 12"
Cohesion: 0.08
Nodes (27): .body, PhChart, .body, PhLogSheet, .body, PhRange, all, .days (+19 more)

### Community 13 - "Community 13"
Cohesion: 0.10
Nodes (15): CycleRepository, .pendingPush, Bool, .pendingDates, LocalStore, Bool, T, UserDefaults (+7 more)

### Community 14 - "Community 14"
Cohesion: 0.09
Nodes (14): .supplementReminders, gxHourLabel(), SupplementPlanSheet, .addForm, .body, .custom, .genesyxEssentials, .yourSupplements (+6 more)

### Community 15 - "Community 15"
Cohesion: 0.11
Nodes (23): PersonalDetailsSheet, .body, .trimmedName, ProfileView, .aboutGroup, .accountGroup, .body, .deleteButton (+15 more)

### Community 16 - "Community 16"
Cohesion: 0.16
Nodes (4): NotificationPlannerTests, .everythingDue, Bool, Set

### Community 17 - "Community 17"
Cohesion: 0.10
Nodes (13): .dto, DailyLogDTO, .domain, Bool, .isBlank, DrainProbeDailyLogBackend, DailyLog, .hasAnyEntry (+5 more)

### Community 18 - "Community 18"
Cohesion: 0.12
Nodes (23): Equatable, Sendable, EnergyTally, MoodTally, Bool, Double, WeeklyDeltas, WeeklySummary (+15 more)

### Community 19 - "Community 19"
Cohesion: 0.15
Nodes (4): AppContainer, RepositoryTests, Set, T

### Community 20 - "Community 20"
Cohesion: 0.13
Nodes (3): Genesyx, GenesyxCore, XCTest

### Community 21 - "Community 21"
Cohesion: 0.15
Nodes (5): .startOfWeek, Double, WeeklySummaryLogicTests, StreakEngineTests, Set

### Community 22 - "Community 22"
Cohesion: 0.15
Nodes (10): PreferencesRepository, .focusMode, .prefs, .pushEnabled, .themeMode, Bool, Set, ProfileBackend (+2 more)

### Community 23 - "Community 23"
Cohesion: 0.11
Nodes (15): .domain, HydrationHistoryRow, .displayTotal, sleepHistoryCard(), SleepHistoryRow, .iso, Calendar, Date (+7 more)

### Community 24 - "Community 24"
Cohesion: 0.07
Nodes (29): CodingKeys, code, cycleLength, deletedAt, displayName, energy, focusMode, id (+21 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (18): CitationLink, SourcesFooter, Color, Eyebrow, .body, NutritionView, .articlesSection, .body (+10 more)

### Community 26 - "Community 26"
Cohesion: 0.11
Nodes (10): NutritionHydrationTests, DayPart, afternoon, evening, midday, morning, night, HydrationCoach (+2 more)

### Community 27 - "Community 27"
Cohesion: 0.13
Nodes (8): Double, .body, ProbePhBackend, PhRecord, .id, PhSync, Bool, Date

### Community 28 - "Community 28"
Cohesion: 0.15
Nodes (5): .showsPhaseChange, .subtitle, CycleEngine, Bool, CycleEngineTests

### Community 29 - "Community 29"
Cohesion: 0.13
Nodes (10): AnyCancellable, NotificationService, .isActive, .isOn, .isSystemDenied, Bool, .reminderPromptSheet, NSObject (+2 more)

### Community 30 - "Community 30"
Cohesion: 0.12
Nodes (10): CycleContent, FocusFood, PhaseHeroCopy, Bool, Phase, follicular, luteal, ovulatory (+2 more)

### Community 31 - "Community 31"
Cohesion: 0.12
Nodes (14): CycleRegularityInsights, Bool, .weekdaySundayZero, Int, CalendarCell, day, empty, CyclePhaseInfo (+6 more)

### Community 32 - "Community 32"
Cohesion: 0.13
Nodes (6): .hydrationInsightsCard, HydrationInsightTests, HydrationInsightLogic, HydrationInsights, Bool, Double

### Community 33 - "Community 33"
Cohesion: 0.12
Nodes (14): Bool, CGFloat, CGRect, Double, Path, WeeklyDashedLine, WeeklySummaryView, .body (+6 more)

### Community 34 - "Community 34"
Cohesion: 0.16
Nodes (7): DeepLink, URL, InviteShareSheet, .body, .shareText, Bool, DeepLinkTests

### Community 35 - "Community 35"
Cohesion: 0.13
Nodes (8): .domain, FakePartner, InviteStatus, accepted, pending, revoked, Partner, PartnerInvite

### Community 36 - "Community 36"
Cohesion: 0.10
Nodes (7): AppBackend, LearnSourceMap, Combine, Foundation, CycleRegularityLogic, PhCopy, UserNotifications

### Community 37 - "Community 37"
Cohesion: 0.10
Nodes (8): AuthRepository, Bool, SocialProvider, apple, google, Error, ASAuthorization, Result

### Community 38 - "Community 38"
Cohesion: 0.19
Nodes (5): LearnProgress, .unreadNewCount, NotificationTests, .shipped, UserDefaults

### Community 39 - "Community 39"
Cohesion: 0.17
Nodes (8): .consistencyCard, ConsistencyCardModel, ConsistencyInsightLogic, HydrationDeltaLogic, PhContextLogic, Bool, ConsistencyInsightLogicTests, Bool

### Community 40 - "Community 40"
Cohesion: 0.25
Nodes (4): PartnerRepository, FakePartnerBackend, PartnerTests, Bool

### Community 41 - "Community 41"
Cohesion: 0.11
Nodes (18): NotificationCategory, checkIn, cycle, insights, learn, logging, milestones, ph (+10 more)

### Community 42 - "Community 42"
Cohesion: 0.18
Nodes (4): Calendar, Date, Set, Date

### Community 43 - "Community 43"
Cohesion: 0.26
Nodes (8): NotificationPlan, .hydration, .hydrationRestDays, .weekly, NotificationPlanner, NotificationSnapshot, PlannedNotification, Set

### Community 44 - "Community 44"
Cohesion: 0.14
Nodes (12): Any, AnyHashable, NotificationTab, home, insights, learn, nutrition, ph (+4 more)

### Community 45 - "Community 45"
Cohesion: 0.19
Nodes (9): .domain, PhRepository, FakePhBackend, PhMeasurementType, urine, vaginal, PhReading, Date (+1 more)

### Community 46 - "Community 46"
Cohesion: 0.19
Nodes (4): SessionRepository, Bool, Void, FakeAuthBackend

### Community 47 - "Community 47"
Cohesion: 0.18
Nodes (14): CycleDetailView, .body, .emptyCycleContent, CyclePredictionCopy, detailHistoryCard(), insightCard(), .body, SparkDots (+6 more)

### Community 48 - "Community 48"
Cohesion: 0.17
Nodes (10): CycleSettingsRow, DailyLogRow, .domain, EmailInviteResponse, PartnerInviteRow, ProfilePrefsRow, ProfileRow, QuizAnswersRow (+2 more)

### Community 49 - "Community 49"
Cohesion: 0.19
Nodes (5): LearnLibraryLog, .nextRead, LearnReadLog, Set, UserDefaults

### Community 50 - "Community 50"
Cohesion: 0.15
Nodes (16): ArticleRow, .body, FeaturedCard, .body, LearnHero, .assetExists, .body, LearnLandingView (+8 more)

### Community 52 - "Community 52"
Cohesion: 0.24
Nodes (4): .records, PhSyncTests, Bool, Double

### Community 53 - "Community 53"
Cohesion: 0.15
Nodes (9): AuthView, .body, .divider, Binding, Bool, Void, ASAuthorizationAppleIDRequest, UIKeyboardType (+1 more)

### Community 54 - "Community 54"
Cohesion: 0.17
Nodes (11): .header, Article, .id, FoodAccent, follicular, luteal, ovulatory, period (+3 more)

### Community 55 - "Community 55"
Cohesion: 0.21
Nodes (5): SupabaseAuth, .currentUserId, String, .isBlank, Bool

### Community 56 - "Community 56"
Cohesion: 0.13
Nodes (9): ErrorStateView, .body, Void, PlaceholderScreen, .body, MedicalSourcesView, .body, Font (+1 more)

### Community 57 - "Community 57"
Cohesion: 0.25
Nodes (5): .nutritionConsistencyCard, NutritionConsistencyInsights, NutritionConsistencyLogic, Bool, NutritionConsistencyLogicTests

### Community 58 - "Community 58"
Cohesion: 0.25
Nodes (4): .sleepCard, SleepInsightLogic, SleepInsights, SleepInsightLogicTests

### Community 60 - "Community 60"
Cohesion: 0.30
Nodes (5): Log, Log, Set, TrackingEngine, TrackingMetrics

### Community 61 - "Community 61"
Cohesion: 0.14
Nodes (13): NotificationKind, cycleFertile, dailyHydration, milestone14, milestone7, milestoneWeek1, milestoneWeek4, weeklyInsights (+5 more)

### Community 62 - "Community 62"
Cohesion: 0.14
Nodes (14): LearnCategory, gettingStarted, guides, .id, insights, .label, nutrition, .tint (+6 more)

### Community 63 - "Community 63"
Cohesion: 0.21
Nodes (6): PartnerSectionView, .body, .divider, .inviteForm, .notSignedIn, .pending

### Community 64 - "Community 64"
Cohesion: 0.23
Nodes (8): NotificationContent, .allCopyStrings, Milestone, day14, day7, .flagKey, week1, week4

### Community 65 - "Community 65"
Cohesion: 0.23
Nodes (5): .current, .shortTitle, .title, YearMonth, .lengthOfMonth

### Community 67 - "Community 67"
Cohesion: 0.20
Nodes (9): ArticleCta, CtaType, openArticle, openInsights, openLog, openNutrition, openPh, openTrack (+1 more)

### Community 68 - "Community 68"
Cohesion: 0.29
Nodes (5): LearnArticle, LearnLibrary, .articles, .featured, Bool

### Community 69 - "Community 69"
Cohesion: 0.20
Nodes (7): StreakEngine, StreakLoggable, StreakState, Bool, Set, FakeLog, Bool

### Community 72 - "Community 72"
Cohesion: 0.24
Nodes (6): HydrationStatus, HydrationStatusEvaluator, Double, Tone, neutral, positive

### Community 74 - "Community 74"
Cohesion: 0.35
Nodes (9): Decodable, TrackingLoggable, Expect, Bool, TrackingEngineVectorTests, VectorCase, VectorDay, VectorFile (+1 more)

### Community 75 - "Community 75"
Cohesion: 0.31
Nodes (6): Hashable, FocusCopy, DidYouKnow, QuizContent, QuizOption, QuizQuestion

### Community 76 - "Community 76"
Cohesion: 0.20
Nodes (7): PartnerBackend, RemoteConfig, .anonKey, .isConfigured, .url, Bool, SyncError

### Community 77 - "Community 77"
Cohesion: 0.22
Nodes (5): MedicalSource, URL, MedicalSourceStore, .body, .body

### Community 78 - "Community 78"
Cohesion: 0.33
Nodes (7): CycleSettingsSheet, .body, .lastPeriodBinding, Binding, Date, Void, ClosedRange

### Community 80 - "Community 80"
Cohesion: 0.47
Nodes (3): json(), requireUser(), serviceClient()

### Community 81 - "Community 81"
Cohesion: 0.22
Nodes (5): AuthenticationServices, CryptoKit, GoogleSignIn, Security, UIKit

### Community 82 - "Community 82"
Cohesion: 0.25
Nodes (8): CaseIterable, FocusMode, pregnancy, prep, ThemeMode, dark, light, system

### Community 83 - "Community 83"
Cohesion: 0.31
Nodes (5): MainTabView, .body, .initialSelection, .tabBar, Content

### Community 84 - "Community 84"
Cohesion: 0.33
Nodes (3): AuthPartnerBackendTests, FakeAuth, .currentUserId

### Community 85 - "Community 85"
Cohesion: 0.28
Nodes (3): CycleSetup, Bool, CycleSetupTests

### Community 86 - "Community 86"
Cohesion: 0.22
Nodes (8): NotificationTarget, home, insights, learn, nutrition, ph, profile, track

### Community 87 - "Community 87"
Cohesion: 0.25
Nodes (8): RemoteError, emailConfirmationRequired, notAuthenticated, notAvailable, notConfigured, DrainProbeError, serverRejected, Error

### Community 88 - "Community 88"
Cohesion: 0.25
Nodes (6): date, parseISO(), PhReadingRow, .domain, Date, Double

### Community 89 - "Community 89"
Cohesion: 0.29
Nodes (5): LearnSearchView, .body, .isSearching, .results, .searchField

### Community 92 - "Community 92"
Cohesion: 0.33
Nodes (6): InvitePresentation, .id, RootView, .body, .colorScheme, ColorScheme

### Community 93 - "Community 93"
Cohesion: 0.29
Nodes (4): InviteView, .valid, Bool, Void

### Community 94 - "Community 94"
Cohesion: 0.29
Nodes (6): .dto, PhReadingDTO, .record, .dto, Date, Double

### Community 95 - "Community 95"
Cohesion: 0.29
Nodes (5): api_header, auth_header, verify_review_account.sh script, SUPABASE_ANON_KEY, SUPABASE_URL

### Community 96 - "Community 96"
Cohesion: 0.33
Nodes (4): App, GenesyxApp, .body, Scene

### Community 97 - "Community 97"
Cohesion: 0.33
Nodes (5): ArticleBlock, bulletList, callout, heading, paragraph

## Knowledge Gaps
- **255 isolated node(s):** `.id`, `.colorScheme`, `saved`, `synced`, `willSyncWhenOnline` (+250 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `Community 55` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 18`, `Community 19`, `Community 20`, `Community 21`, `Community 22`, `Community 23`, `Community 24`, `Community 25`, `Community 26`, `Community 27`, `Community 29`, `Community 30`, `Community 31`, `Community 32`, `Community 33`, `Community 34`, `Community 35`, `Community 36`, `Community 37`, `Community 38`, `Community 39`, `Community 40`, `Community 41`, `Community 42`, `Community 43`, `Community 44`, `Community 45`, `Community 46`, `Community 47`, `Community 48`, `Community 49`, `Community 50`, `Community 51`, `Community 52`, `Community 53`, `Community 54`, `Community 56`, `Community 57`, `Community 58`, `Community 59`, `Community 60`, `Community 61`, `Community 62`, `Community 63`, `Community 64`, `Community 65`, `Community 66`, `Community 67`, `Community 68`, `Community 69`, `Community 70`, `Community 71`, `Community 72`, `Community 74`, `Community 75`, `Community 76`, `Community 77`, `Community 78`, `Community 82`, `Community 83`, `Community 84`, `Community 86`, `Community 88`, `Community 89`, `Community 90`, `Community 92`, `Community 93`, `Community 94`, `Community 97`, `Community 98`?**
  _High betweenness centrality (0.532) - this node is a cross-community bridge._
- **Why does `Int` connect `Community 31` to `Community 0`, `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 8`, `Community 10`, `Community 11`, `Community 13`, `Community 14`, `Community 16`, `Community 17`, `Community 18`, `Community 21`, `Community 22`, `Community 23`, `Community 25`, `Community 26`, `Community 27`, `Community 28`, `Community 29`, `Community 30`, `Community 32`, `Community 38`, `Community 39`, `Community 42`, `Community 43`, `Community 44`, `Community 47`, `Community 48`, `Community 50`, `Community 51`, `Community 53`, `Community 55`, `Community 57`, `Community 58`, `Community 59`, `Community 60`, `Community 65`, `Community 69`, `Community 70`, `Community 72`, `Community 74`, `Community 78`, `Community 79`, `Community 83`, `Community 86`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Why does `CalendarDate` connect `Community 23` to `Community 2`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 10`, `Community 11`, `Community 13`, `Community 17`, `Community 18`, `Community 19`, `Community 21`, `Community 25`, `Community 26`, `Community 28`, `Community 29`, `Community 31`, `Community 32`, `Community 33`, `Community 36`, `Community 48`, `Community 55`, `Community 59`, `Community 60`, `Community 65`, `Community 68`, `Community 69`, `Community 70`, `Community 71`, `Community 74`, `Community 75`, `Community 78`, `Community 79`, `Community 85`, `Community 91`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Are the 43 inferred relationships involving `CalendarDate` (e.g. with `.snapshot()` and `.body`) actually correct?**
  _`CalendarDate` has 43 INFERRED edges - model-reasoned connections that need verification._
- **Are the 24 inferred relationships involving `DailyLog` (e.g. with `.uiTestSeeded()` and `.save()`) actually correct?**
  _`DailyLog` has 24 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.id`, `.colorScheme`, `saved` to the rest of the system?**
  _255 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.051360842844600525 - nodes in this community are weakly interconnected._