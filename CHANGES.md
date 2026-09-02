# Post-launch-audit patch — CHANGES

Running log of every file touched, per task.

## Task 1 — Incremental sync (egress vs Free-tier 5 GB cap)

Per-table `updated_at` cursors for the three growing history tables so a launch pulls
only rows changed since the last successful sync, instead of full history every time.

**`consent_events` is deliberately EXCLUDED** and keeps its current full fetch. It has no
column that can safely drive an incremental cursor: verified schema
(`supabase/migrations/20260818_consent_events.sql`) has no `updated_at`/`created_at`, only
`occurred_at`, which is **client-set and backdated** (onboarding runs before sign-up, so the
row is inserted minutes-to-hours after the timestamp it carries — see
`RemoteModels.swift` `ConsentEventRow` and `ConsentRepository.swift`). A cursor on
`occurred_at` could silently miss a backdated consent row inserted by another device after a
sync — an unacceptable gap in a legal Article 9 audit trail. It is also a tiny, non-growing
table, so it contributes nothing to the egress problem. The spec's "safe by construction"
note assumed a server-monotonic timestamp this table does not have.

### Design
- Cursor = the **request start time** of the last *successful* pull, persisted per repository
  via the existing `LocalStore` pattern (same mechanism as `pendingDates`). Never advanced on
  a failed fetch.
- The query filters `updated_at >= (cursor − 60s)` (60s overlap margin for clock skew). The
  margin is applied in the repository so it is unit-testable; the backend just formats the date.
- First run after this update (no stored cursor) fetches full history once — identical to
  current behaviour — then stores the cursor. This is the migration path for existing users.
- Merge: `DailyLog`'s existing overwrite loop is already subset-safe (touches only returned
  keys). `PhSync.merge`/`SupplementSync.merge` assume a *complete* snapshot (they re-flag any
  local record absent from `remote` as pending), so a subset-safe `mergeIncremental` was added
  next to each; the full first sync still uses `merge`.
- Sign-out / account-switch: each repository's `clearLocalState()` (already called by
  `AppContainer.clearLocalState`) now also clears its cursor.

### Files touched
- `Sources/GenesyxCore/Ph/PhSync.swift` — added `mergeIncremental(local:remote:)`.
- `Sources/GenesyxCore/Models/SupplementSync.swift` — added `mergeIncremental(local:remote:)`.
- `App/Genesyx/Data/Remote/RemoteBackend.swift` — `DailyLogBackend.list`, `PhBackend.list`,
  `SupplementBackend.list` now take `updatedSince: Date?`.
- `App/Genesyx/Data/Remote/RemoteModels.swift` — `DailyLogRow` now decodes `updated_at`
  (decode-only; omitted on write so the server trigger stamps it).
- `App/Genesyx/Data/Remote/SupabaseBackend.swift` — the three `list` implementations apply the
  `updated_at >= since` filter when a cursor is supplied.
- `App/Genesyx/Data/DailyLogRepository.swift` — cursor + `#if DEBUG` row-count log.
- `App/Genesyx/Data/PhRepository.swift` — cursor + full/incremental branch + row-count log.
- `App/Genesyx/Data/SupplementsRepository.swift` — cursor + full/incremental branch + row-count log.
- `App/GenesyxTests/RepositoryTests.swift` — updated mock `list` signatures; added cursor and
  `mergeIncremental` tests.

Note on `user_supplements.updated_at`: nullable in schema but defaulted `now()` on insert and
always sent by the client on upsert, so a changed row always carries a non-null `updated_at`;
the incremental filter cannot miss a real change. First full sync covers the baseline.
