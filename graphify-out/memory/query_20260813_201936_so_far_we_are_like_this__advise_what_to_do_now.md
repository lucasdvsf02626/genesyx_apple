---
type: "query"
date: "2026-08-13T20:19:36.519143+00:00"
question: "so far we are like this: advise what to do now"
contributor: "graphify"
outcome: "useful"
source_nodes: ["Milestone", "NotificationService", "StreakEngine.swift", "ProfileView", "Commit stack (newest first)"]
---

# Q: so far we are like this: advise what to do now

## Answer

Expanded from original query via vocab: [milestone, streak, logging, notification, checklist, progress, test, cycle, article, profile, website, release, commit, migration]. Finish H7 before starting anything else, but correct two issues first: iOS in-app celebration is currently trapped behind NotificationService.replan's push-authorization guard, and changing day7/day14 to logging creates a semantic mismatch with Android, whose existing MilestoneDialog still keys them to dailyHydration. Add iOS service/UI/cold-relaunch tests, align Android thresholds and copy to dailyActivity, run both suites, and only then mark the row Done. Then checkpoint the large dirty worktrees and recover the exact production migration artifact before H3/H6.

## Outcome

- Signal: useful

## Source Nodes

- Milestone
- NotificationService
- StreakEngine.swift
- ProfileView
- Commit stack (newest first)