---
type: "query"
date: "2026-08-14T10:07:02.757751+00:00"
question: "Audit why the Genesyx iOS app is accessible without login and list every fix"
contributor: "graphify"
outcome: "useful"
source_nodes: ["RootView", "SessionRepository", "AuthView", "MainTabView", "AppContainer"]
---

# Q: Audit why the Genesyx iOS app is accessible without login and list every fix

## Answer

Expanded from original query via graph vocab: auth authentication session root onboarding signed main backend mock invite deep gate. Live source confirms RootView routes solely on genesyx.onboardingComplete and renders MainTabView without checking SessionRepository.isSignedIn. SessionRepository comments and UI tests intentionally keep all tabs usable after sign-out, AuthView always offers Back to app, session restoration uses cached currentUserId rather than Supabase authStateChanges, initial hydrate and foreground drains run without an authenticated guard, and NotificationService does not include session state in isActive. Fix with an explicit resolving/signedOut/signedIn session state, a root-level non-dismissible auth gate, Supabase authStateChanges plus validated session restoration, immediate routing on logout/deletion/revocation, session-gated sync and notifications, safe invite/notification deep-link deferral, fail-closed release config, and rewritten unit/UI/lifecycle tests. No Supabase schema migration is required.

## Outcome

- Signal: useful

## Source Nodes

- RootView
- SessionRepository
- AuthView
- MainTabView
- AppContainer