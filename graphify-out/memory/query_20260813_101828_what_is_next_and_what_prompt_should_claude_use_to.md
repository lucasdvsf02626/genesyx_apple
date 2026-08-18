---
type: "query"
date: "2026-08-13T10:18:28.089077+00:00"
question: "What is next and what prompt should Claude use to do the tasks after discovering the Home fix was made in a stale worktree?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["HomeView", "NutritionView", "GenesyxUITests", "CycleRepository"]
---

# Q: What is next and what prompt should Claude use to do the tasks after discovering the Home fix was made in a stale worktree?

## Answer

Expanded using graph vocabulary: home cycle hydration learn log phase focus nutrition test view. Immediate task: port only the valid HomeView layout/accessibility change and new Home UI test from peaceful-moore-f43811 at b1ab67b onto current main d0b0c9f; do not merge/rebase the stale branch or copy its docs. T24/Nutrition already exists on main via 6000f2d. Prove the current-main Home test red against old gating, apply fix, run targeted test plus full domain/app/UI suites, update current docs with exact baseline, and commit without graphify files. Then report separately gated follow-ups: production two-account deletion behavior test requires explicit authorization, Android device supplement sync and Play track verification require live platform evidence, Apple token revocation needs a server-side design/secrets, and Article 9 consent needs a legal/product decision.

## Outcome

- Signal: useful

## Source Nodes

- HomeView
- NutritionView
- GenesyxUITests
- CycleRepository