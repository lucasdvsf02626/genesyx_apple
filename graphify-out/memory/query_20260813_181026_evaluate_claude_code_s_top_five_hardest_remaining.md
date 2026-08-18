---
type: "query"
date: "2026-08-13T18:10:26.505142+00:00"
question: "Evaluate Claude Code's top five hardest remaining Genesyx tasks and decide what should start next"
contributor: "graphify"
outcome: "corrected"
correction: "Do not treat the shared tracking vectors as byte-identical or H4 as closing three checklist rows; reconcile the contract first, then close 1B-1 and 2B-4 while leaving 3A-1 in progress."
source_nodes: ["PRIVACY_POLICY.md", "FoodGroup", ".streak()", "Hydration"]
---

# Q: Evaluate Claude Code's top five hardest remaining Genesyx tasks and decide what should start next

## Answer

Claude's difficulty ranking is mostly sound, but H4 closes two checklist rows and only advances the overall streak row. The iOS and Android tracking vector files exist but currently use divergent schemas and hashes, so H4 must begin by defining and reconciling the canonical cross-platform contract. Public App Store gates are real and separate: explicit-consent/legal-basis resolution and Sign in with Apple token revocation. Recovering and checking in the exact production SQL remains a priority-zero safety prerequisite.

## Outcome

- Signal: corrected
- Correction: Do not treat the shared tracking vectors as byte-identical or H4 as closing three checklist rows; reconcile the contract first, then close 1B-1 and 2B-4 while leaving 3A-1 in progress.

## Source Nodes

- PRIVACY_POLICY.md
- FoodGroup
- .streak()
- Hydration