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

## Apple review implications (important)
Turning on accounts + cloud health data **changes the App Store story**:
- App Privacy label flips from "Data Not Collected" to **Health & Fitness + Contact Info + User
  Content, linked to identity, not used for tracking**.
- A **privacy policy URL becomes mandatory**, and **in-app account deletion** is required
  (Guideline 5.1.1(v)) — implement `deleteAccount` (Supabase Edge Function) before submitting.
- Offering Google sign-in requires **Sign in with Apple** too.

See `ARCHITECTURE.md` → Open Decisions and `WHATS_LEFT.md` → backend.
