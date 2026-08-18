---
type: "query"
date: "2026-08-13T14:37:14.107314+00:00"
question: "Reconcile the successful production Supabase migration report with both Genesyx repositories"
contributor: "graphify"
outcome: "useful"
source_nodes: ["NotificationService", "ProfileView", "AuthView", "pushEnabled"]
---

# Q: Reconcile the successful production Supabase migration report with both Genesyx repositories

## Answer

Expanded from original query via vocab: [migration, backend, push, profile, delete, user, supplement, supplements, auth, notification]. Live production now closes H1 and H2: delete_current_user contains the explicit user_supplements backstop and profiles.push_enabled defaults false without changing existing rows. The exact applied migration is absent from the iOS supabase/migrations directory and Android has no supabase/migrations directory at all, only docs/migrations. Therefore record executable SQL once in the iOS canonical migration directory, update Android's obsolete draft with a do-not-apply superseded banner or an audited docs copy, and refresh CHANGE_LIST_PLAN/TESTFLIGHT/HANDOFF. End-to-end deletion remains unverified until a disposable account is actually deleted.

## Outcome

- Signal: useful

## Source Nodes

- NotificationService
- ProfileView
- AuthView
- pushEnabled