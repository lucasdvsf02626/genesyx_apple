---
type: "query"
date: "2026-08-14T08:47:45.247681+00:00"
question: "the customer can download this online can have in my own machine tell me how to impement this thing"
contributor: "graphify"
outcome: "useful"
source_nodes: ["OnboardingFlowView", "LearnLandingView", "guides", "Supabase", "LocalStore"]
---

# Q: the customer can download this online can have in my own machine tell me how to impement this thing

## Answer

Expanded from original query via graph vocab: [guide, offline, local, share, url, website, learn, waitlist, supabase, open]. Use a dual-copy architecture: keep the permanent master PDF on the Mac, upload a corrected versioned copy to a public read-only Supabase Storage bucket for website downloads, and bundle the same PDF in the iOS app for immediate offline reading. The onboarding CTA opens the bundled file without login or network; a ShareLink using the local file URL lets customers save it to Files, AirDrop, Mail, or Messages. Learn > Guides opens the same viewer. Do not serve the Outlook Temp path or the Mac itself, do not use the waitlist, and do not allow anonymous uploads or deletes.

## Outcome

- Signal: useful

## Source Nodes

- OnboardingFlowView
- LearnLandingView
- guides
- Supabase
- LocalStore