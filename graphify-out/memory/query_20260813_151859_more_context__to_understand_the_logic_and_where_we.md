---
type: "query"
date: "2026-08-13T15:18:59.095142+00:00"
question: "more context, to understand the logic and where we are at"
contributor: "graphify"
outcome: "useful"
source_nodes: ["CycleRegularityInsights", "CycleRegularityCard", "CycleSettings", "InsightsView.swift", "GenesyxUITests"]
---

# Q: more context, to understand the logic and where we are at

## Answer

Expanded from original query via vocab: [cycle, regularity, insights, test, claim, history, current, length]. H3 is an honesty correction, not the real cycle-history feature: the backend stores one cycle_settings row with lastPeriodDate, cycleLength, and periodLength, so Insights may show current configured length and its 21-35 day comparison but cannot infer longitudinal regularity. Claude renamed the visible card and empty state, kept shared type names for Android parity, and added a UI guard that first proves the configured length is visible and then asserts no visible Insights label contains regularity. Targeted UI passed in 7.676 seconds and 236 domain tests passed; mutation proof and final post-H3 app/UI run do not yet have a completed output, so H3 remains interim implemented/testing while the cycle_period event model, sync/conflicts, Android parity, and Supabase work remain open.

## Outcome

- Signal: useful

## Source Nodes

- CycleRegularityInsights
- CycleRegularityCard
- CycleSettings
- InsightsView.swift
- GenesyxUITests