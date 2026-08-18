---
type: "query"
date: "2026-08-14T10:13:54.603326+00:00"
question: "the first home page is ok now is only the page when i click the sigin page in the PROFILE tab the last option"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AuthView", "ProfileView", "BrandAssetTests.swift"]
---

# Q: the first home page is ok now is only the page when i click the sigin page in the PROFILE tab the last option

## Answer

Expanded from original query via vocab: [auth, view, profile, brand, image, sign, account, session]. The remaining logo target is AuthView, presented by ProfileView through showAuth. Replace only the Text GENESYX header in AuthView with the existing brand_lockup image and an auth.brandLogo accessibility identifier. Keep SplashView unchanged and do not duplicate the supplied SVG because the asset catalog already carries light and dark variants. Add a targeted Profile to Sign In UI assertion.

## Outcome

- Signal: useful

## Source Nodes

- AuthView
- ProfileView
- BrandAssetTests.swift