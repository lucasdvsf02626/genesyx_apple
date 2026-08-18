---
type: "query"
date: "2026-08-13T09:30:17.123017+00:00"
question: "Live audit found seven tables, six cascades, no profiles.partner_id FK, zero linked profiles, zero legacy quiz rows, and two Apple identities. What is the correct conclusion?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["SupabaseBackend", "PartnerRepository", "ProfileView", "AuthView"]
---

# Q: Live audit found seven tables, six cascades, no profiles.partner_id FK, zero linked profiles, zero legacy quiz rows, and two Apple identities. What is the correct conclusion?

## Answer

Expanded via graph vocabulary: delete account partner profile auth quiz supabase. Current live evidence proves Android delete_current_user does not abort and deletes core auth and FK-owned health data, but it is incomplete: it does not explicitly clear the reciprocal profiles.partner_id, remove partner_invites addressed by invitee_email, or remove waitlist_emails. The missing partner_id FK means no cascade performs the unlink. Zero linked profiles and zero legacy quiz rows mean no current data repair is needed, but cross-platform accounts can still link via shipped iOS then delete through Android, so explicit RPC unlinking is deletion hardening, not deferred Section 4 sharing-scope work. Two Apple identities make iOS token revocation a current requirement. Prefer an explicit unlink in the Android RPC and eventually one canonical deletion contract; do not call Android deletion complete.

## Outcome

- Signal: useful

## Source Nodes

- SupabaseBackend
- PartnerRepository
- ProfileView
- AuthView