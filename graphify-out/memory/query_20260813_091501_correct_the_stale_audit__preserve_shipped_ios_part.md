---
type: "query"
date: "2026-08-13T09:15:01.278844+00:00"
question: "Correct the stale audit: preserve shipped iOS partner linking, defer Section 4 partner sharing scopes, and identify current partner RLS and account deletion gaps"
contributor: "graphify"
outcome: "corrected"
correction: "The earlier recommendation to disable iOS partner linking was wrong because linking already shipped; only the unbuilt sharing-scope model remains deferred."
source_nodes: ["PartnerRepository,SupabasePartner,ProfileRow,SupabaseBackend"]
---

# Q: Correct the stale audit: preserve shipped iOS partner linking, defer Section 4 partner sharing scopes, and identify current partner RLS and account deletion gaps

## Answer

Corrected prior recommendation: keep FeatureFlags.partnerInvites true because linking shipped. Do not implement the deferred cycle-stage, fertile-window, or reminder-sharing permission model. Current privacy defect is separate: profiles_select permits a linked partner to select the entire profiles row while the client only requests display_name. Safe compatibility sequence is add a mutually validated name-only RPC or Edge endpoint, ship the client using it, then make profiles owner-only after old builds retire. delete_account still treats waitlist deletion as best-effort and lacks Sign in with Apple token revocation.

## Outcome

- Signal: corrected
- Correction: The earlier recommendation to disable iOS partner linking was wrong because linking already shipped; only the unbuilt sharing-scope model remains deferred.

## Source Nodes

- PartnerRepository,SupabasePartner,ProfileRow,SupabaseBackend