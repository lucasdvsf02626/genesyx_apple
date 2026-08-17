# Supabase Wiring (v1.x — deferred)

The current shipping plan is **local-only v1** (on-device storage, mock auth). This document
describes the remote layer that's already scaffolded and how to turn it on later.

## What's already in the repo
- `Data/Remote/RemoteBackend.swift` — config reader + protocols (`AuthBackend`, `CycleBackend`,
  `PhBackend`, `DailyLogBackend`, aggregate `GenesyxBackend`). **Pure Swift, always compiles.**
- `Data/Remote/RemoteModels.swift` — Codable row DTOs for `cycle_settings`, `ph_readings`,
  `daily_logs` with domain mappers. **Pure Swift, always compiles.**
- `Data/Remote/SupabaseBackend.swift` — the real implementation, wrapped in
  `#if canImport(Supabase)`. Excluded from the build until the package is linked, so it cannot
  break the local-only v1.
- `RemoteConfig` reads `SUPABASE_URL` / `SUPABASE_ANON_KEY` from `Info.plist` (injected from
  `Secrets.xcconfig`). `isConfigured` is false until you set real values.

## How to activate (when ready)
1. **Add the package** to `project.yml`:
   ```yaml
   packages:
     GenesyxCore:
       path: .
     Supabase:
       url: https://github.com/supabase/supabase-swift
       from: "2.0.0"
   targets:
     Genesyx:
       dependencies:
         - package: GenesyxCore
           product: GenesyxCore
         - package: Supabase
           product: Supabase
   ```
2. **Add credentials**: copy `Secrets.xcconfig.example` → `Secrets.xcconfig`, fill in your project
   URL + anon key, and reference it via `configFiles` on the target (see that file's header).
3. `xcodegen generate` — now `canImport(Supabase)` is true, `SupabaseBackend` compiles, and
   `AppBackend.make()` returns it.

That's it — **the repository swap is already wired**. Every repository takes an optional backend
(`CycleRepository(store:backend:)` etc.), defaulting to `nil` for local-only. `AppContainer`
resolves `AppBackend.make()` and passes `backend?.cycle / .ph / .dailyLog` in; on launch it calls
`refresh()` (online-first) and all writes mirror to the remote via fire-and-forget tasks. No UI or
repository call sites change when you flip it on.

## Database
Reuse the existing Supabase project from the Android build. The schema lives in the Android repo
at `docs/schema.sql` (tables: `profiles`, `cycle_settings`, `daily_logs`, `partner_invites`,
`ph_readings`, all with owner-only RLS).

### Edge Functions required (privileged ops)
`SupabasePartner.accept` / `.unlink` call Edge Functions (`accept_partner_invite`,
`unlink_partner`) because bidirectional linking needs the service role. Account deletion
(`deleteAccount`) is likewise an Edge Function and is **mandatory** before App Store submission
once accounts exist (Guideline 5.1.1(v)). Auth, cycle, pH, daily-log, and invite list/send/revoke
go straight through PostgREST under RLS.

## Auth redirect URLs — DASHBOARD SETTING, required for password reset

**Authentication → URL Configuration → Redirect URLs must contain exactly:**

```
genesyx://reset-password
```

Without it the password-reset flow is broken end to end, and it fails *silently*. Supabase drops
any `redirect_to` that is not on the allow-list and substitutes the project **Site URL**, so the
link in her inbox opens a web page instead of the app, the app never sees the callback, and she is
left looking at "check your inbox" for a link that cannot come home. That was the state of the app
before 17 Aug 2026: `resetPasswordForEmail` was called with no `redirectTo` at all.

The string is pinned in code at `DeepLink.passwordRecoveryURL` and asserted by
`DeepLinkTests.testTheRecoveryRedirectIsTheExactStringAllowListedInSupabase`. **If that test ever
fails, this dashboard entry has to change in the same breath** — the two are one setting split
across two systems.

Custom scheme rather than the https Universal Link on purpose. The `associated-domains` entitlement
is present, but `DeepLink.universalLinksLive` is still `false` because the AASA file is not served
from `genesyx.co.uk` yet, and an https recovery link with nothing behind it opens Safari to a 404 —
a woman locked out of her account. The custom scheme has no such dependency.

**One consequence worth knowing before testing.** supabase-swift defaults to the **PKCE** flow, so
`resetPasswordForEmail` stores a code verifier on the requesting device. The reset link therefore
only works on the same iPhone that asked for it. Opening it on a desktop or a second phone fails,
and the app reports it as an expired link. This is correct, and safer than implicit flow, but it
means the manual test must be done on one device throughout.

## Apple review implications (important)
Turning on accounts + cloud health data **changes the App Store story**:
- App Privacy label flips from "Data Not Collected" to **Health & Fitness + Contact Info + User
  Content, linked to identity, not used for tracking**.
- A **privacy policy URL becomes mandatory**, and **in-app account deletion** is required
  (Guideline 5.1.1(v)) — implement `deleteAccount` (Supabase Edge Function) before submitting.
- Offering Google sign-in requires **Sign in with Apple** too.

See `ARCHITECTURE.md` → Open Decisions and `WHATS_LEFT.md` → backend.
