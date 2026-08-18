---
type: "query"
date: "2026-08-13T08:12:45.197368+00:00"
question: "do a list of everything needs to be done, deep dive so nothing is left, so we do today"
contributor: "graphify"
outcome: "useful"
source_nodes: ["OnboardingFlowView", "NutritionView", "ProfileView", "TrackingEngine", "NotificationService", "DailyLogRepository", "PhTrackerCard", "PreferencesRepository", "TrackView", "LearnProgress"]
---

# Q: do a list of everything needs to be done, deep dive so nothing is left, so we do today

## Answer

Expanded from original query via graph vocab: onboarding, nutrition, profile, streak, offline, migration, sync, test, tracking, vaginal, notification, calendar. Remaining completion work is to isolate section 4 changes, make the preference question optional, add selected-date food-group editing in Track, fix the live profiles theme default and account-scoped theme migration, finish pH metadata/history/external-link decisions, validate Google sign-in and cellular reconnect on a real device, settle streak semantics, correct privacy and App Store metadata, run domain app UI release tests, archive build 19, install from TestFlight, and record live backend and release evidence. Live verification on 2026-08-13 confirmed food_groups and sexual_activity columns, waitlist RPC/table, owner-only daily-log RLS, and active Edge Functions; profiles.theme still defaults to dark.

## Outcome

- Signal: useful

## Source Nodes

- OnboardingFlowView
- NutritionView
- ProfileView
- TrackingEngine
- NotificationService
- DailyLogRepository
- PhTrackerCard
- PreferencesRepository
- TrackView
- LearnProgress