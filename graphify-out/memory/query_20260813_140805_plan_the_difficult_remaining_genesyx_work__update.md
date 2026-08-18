---
type: "query"
date: "2026-08-13T14:08:05.011161+00:00"
question: "Plan the difficult remaining Genesyx work, update docs/CHANGE_LIST_PLAN.md, and provide a safe prompt for the one shared iOS and Android Supabase backend"
contributor: "graphify"
outcome: "useful"
source_nodes: ["Supabase", "CycleRegularityInsights", "DailyLog", "NotificationService", "PreferencesRepository", "DailyLogRepository", "PhRepository", "ProfileView", "TrackingEngine", "InsightsView.swift"]
---

# Q: Plan the difficult remaining Genesyx work, update docs/CHANGE_LIST_PLAN.md, and provide a safe prompt for the one shared iOS and Android Supabase backend

## Answer

Expanded from original query via graph vocabulary: [supabase, profile, preferences, notification, tracking, cycle, regularity, daily, food, nutrition, hydration, insights]. Verified source and live backend, then updated docs/CHANGE_LIST_PLAN.md with H0-H11. P0 is the iOS pH measurementType cold-relaunch fix. The safe backend patch is limited to preserving the deployed hardened delete_current_user body while adding an explicit user_supplements delete, plus changing only profiles.push_enabled default to false. No pH data conversion, existing push-row rewrite, broad db push, or unreviewed cycle/article/hydration schema. Larger cross-platform work is cycle history, food groups in Insights/shared streak vectors, dated article-read events, restore semantics, synced hydration display preferences, and physical-iPhone QA.

## Outcome

- Signal: useful

## Source Nodes

- Supabase
- CycleRegularityInsights
- DailyLog
- NotificationService
- PreferencesRepository
- DailyLogRepository
- PhRepository
- ProfileView
- TrackingEngine
- InsightsView.swift