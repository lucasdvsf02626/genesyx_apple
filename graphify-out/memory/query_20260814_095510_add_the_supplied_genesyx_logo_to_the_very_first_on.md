---
type: "query"
date: "2026-08-14T09:55:10.193540+00:00"
question: "Add the supplied Genesyx logo to the very first onboarding page before the quiz"
contributor: "graphify"
outcome: "useful"
source_nodes: ["BrandAssetTests.swift", "splash", "BrandEgg", "OnboardingFlowView.swift"]
---

# Q: Add the supplied Genesyx logo to the very first onboarding page before the quiz

## Answer

Expanded from original query via vocab: onboarding splash brand asset image egg quiz view swift tests. Live source shows SplashView in App/Genesyx/UI/Onboarding/OnboardingFlowView.swift renders Text GENESYX before the quiz CTA. The repository already contains the same full logo as the adaptive brand_lockup asset with light and dark variants, so use Image brand_lockup instead of adding a duplicate SVG, keep the egg background, add accessibility identifier onboarding.brandLogo, extend BrandAssetTests and the onboarding UI test, then update H11 and progress counts after verification.

## Outcome

- Signal: useful

## Source Nodes

- BrandAssetTests.swift
- splash
- BrandEgg
- OnboardingFlowView.swift