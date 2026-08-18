---
type: "audit"
date: "2026-08-13T12:30:10.599334+00:00"
question: "Which Sections 1-3 and 5 tracker requirements are complete, partial, missing, or blocked, with Section 4 excluded?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["PersistenceDTOs.swift", "PhRepository.swift", "InsightsView.swift", "TrackingEngine.swift", "CycleRegularityLogic.swift", "OnboardingFlowView.swift", "LearnContent.swift", "NotificationService.swift", "Reachability.swift"]
---

# Q: Which Sections 1-3 and 5 tracker requirements are complete, partial, missing, or blocked, with Section 4 excluded?

## Answer

Strict audit: 25 of 44 complete, 16 partial, 1 missing, 1 physical-device blocked, and 1 subjective design review. Critical defect: PhRecord.dto omits measurementType, so vaginal pH reloads as legacy urine and disappears from the tracker, calendar, Insights, and streak. Hydration, sleep, symptoms, daily notes, supplements and cycle predictions use real stored data. Missing/partial areas include actual cycle history, food-group data in Insights/streaks, optional onboarding answer, arbitrary pH-history editing, in-app streak celebrations/restore, external science links, backend push default semantics, Profile end-to-end checks, recipe imagery, and exact article order.

## Outcome

- Signal: useful

## Source Nodes

- PersistenceDTOs.swift
- PhRepository.swift
- InsightsView.swift
- TrackingEngine.swift
- CycleRegularityLogic.swift
- OnboardingFlowView.swift
- LearnContent.swift
- NotificationService.swift
- Reachability.swift