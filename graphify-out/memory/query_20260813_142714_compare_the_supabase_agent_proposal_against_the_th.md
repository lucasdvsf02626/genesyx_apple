---
type: "query"
date: "2026-08-13T14:27:14.116562+00:00"
question: "Compare the Supabase agent proposal against the three local iOS and Android migration files"
contributor: "graphify"
outcome: "useful"
source_nodes: ["pushEnabled", "NotificationService", "ProfileView", "AuthView"]
---

# Q: Compare the Supabase agent proposal against the three local iOS and Android migration files

## Answer

Expanded from original query via vocab: [delete, current, user, supplements, push, enabled, profile, notification, auth, backend]. The old Android 2026-07-29 draft must not be applied because it lacks user_id FK cascade, overwrites the hardened deletion body, is non-idempotent, and uses additive grants. The canonical 20260813 Android supplements migration supersedes it and production has auth.users ON DELETE CASCADE plus correct ACL/RLS. The iOS push migration exactly changes only profiles.push_enabled default to false. The proposed guarded splice preserves the deployed hardened function and adds an explicit user_supplements deletion backstop before profile/auth deletion. Safe to authorize after pinning the zero-argument function and running postflight; no pH or existing profile rows should change.

## Outcome

- Signal: useful

## Source Nodes

- pushEnabled
- NotificationService
- ProfileView
- AuthView