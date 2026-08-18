---
type: "query"
date: "2026-08-13T09:34:48.904201+00:00"
question: "Live Supabase has neither user_supplements nor genesyx_products. How should the two Android findings be classified?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["NutritionView", "SupabaseBackend"]
---

# Q: Live Supabase has neither user_supplements nor genesyx_products. How should the two Android findings be classified?

## Answer

Expanded using graph vocabulary: nutrition remote repository supabase. The iOS graph has no product catalogue node, so current Android source was verified directly. genesyx_products is a read-only, non-user-owned catalogue. Supabase fetch errors are intentionally converted to an empty list, and the UI truthfully shows 'coming soon' while zero SKUs exist; this is a latent catalogue-readiness/log-noise issue, not user data loss or an account-deletion table. user_supplements is different: the current Nutrition UI accepts local writes, production DI selects the Supabase remote when configured, failures remain PENDING and retry, and Profile tells the user the changes will sync automatically. With the live table absent, that claim cannot become true and a second device cannot restore data. Do not apply the old combined 2026-07-29 migration unchanged because its delete_current_user body and schema assumptions are stale; draft a new reviewed shared-backend migration after confirming the Android build is actually distributed.

## Outcome

- Signal: useful

## Source Nodes

- NutritionView
- SupabaseBackend