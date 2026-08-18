---
type: "query"
date: "2026-08-13T09:26:58.618023+00:00"
question: "So far Claude's shared-backend audit found the older live delete_current_user body, policies, no waitlist policies, and no user_supplements table. Is the conclusion correct and what remains?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["SupabaseBackend", "PartnerRepository", "ProfileView", "AuthView"]
---

# Q: So far Claude's shared-backend audit found the older live delete_current_user body, policies, no waitlist policies, and no user_supplements table. Is the conclusion correct and what remains?

## Answer

Expanded query via graph vocabulary: delete account auth partner profile quiz invite waitlist supplement supabase. The live older RPC means Android deletion does not abort on a missing user_supplements relation, but that clears only one failure mode. Completeness still requires live FK/on-delete checks, reciprocal profiles.partner_id behavior, addressed partner_invites and waitlist email cleanup, quiz_answers cascade confirmation, RLS-enabled and grant checks for waitlist_emails, and join_waitlist SECURITY DEFINER/search_path/grants. Zero waitlist policies is expected only if RLS is enabled. The absent user_supplements table is a separate current Android sync defect because the visible Nutrition card binds the Supabase remote source in configured production builds. Preserve shipped iOS partner linking and do not tighten profiles RLS before a name-only endpoint and client migration.

## Outcome

- Signal: useful

## Source Nodes

- SupabaseBackend
- PartnerRepository
- ProfileView
- AuthView