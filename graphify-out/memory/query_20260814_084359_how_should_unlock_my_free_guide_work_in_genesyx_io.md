---
type: "architecture"
date: "2026-08-14T08:43:59.564348+00:00"
question: "How should Unlock My Free Guide work in Genesyx iOS?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["ReadinessSummaryView", "waitlist", "guides", "LearnLandingView"]
---

# Q: How should Unlock My Free Guide work in Genesyx iOS?

## Answer

Make the CTA deliver the bundled 7-Day Fertility Nutrition Starter Guide immediately and offline, without email, waitlist, login, or Supabase. Present it from the readiness summary, keep Register/Login separate, and expose it again in Learn > Guides. The current route in OnboardingFlowView sends the CTA to WaitlistView and must be replaced. Do not mark the feature App Store ready until the supplied PDF is corrected: its metadata says Recipe Book, page 20 says Download out free app and contains an in-app download QR, and it is untagged for accessibility.

## Outcome

- Signal: useful

## Source Nodes

- ReadinessSummaryView
- waitlist
- guides
- LearnLandingView