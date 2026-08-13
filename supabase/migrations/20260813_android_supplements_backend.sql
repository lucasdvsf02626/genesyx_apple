-- ============================================================================
-- B. ANDROID SUPPLEMENT BACKEND — genesyx_products + user_supplements
--
-- ✅ APPLIED to production 13 Aug 2026. Idempotent — re-running is safe:
--      supabase db query --linked -f supabase/migrations/20260813_android_supplements_backend.sql
--
-- Applied TWICE. The first run created both tables correctly but left the grants
-- wrong, and verification test 2 below caught it: `grant select` is additive, so
-- authenticated kept the full arwdDxtm the schema default privileges hand out at
-- CREATE TABLE time — including TRUNCATE, which RLS cannot refuse. The revoke
-- lines now name authenticated as well as anon. See the note above the grants.
--
-- Verified after the second run: both FKs correct (user_id CASCADE, product_id
-- SET NULL); both check constraints present; RLS enabled with exactly one policy
-- each; both indexes created; both tables empty; grants now exactly SELECT for
-- authenticated on genesyx_products and SELECT/INSERT/UPDATE/DELETE on
-- user_supplements, with anon holding nothing on either.
--
-- STILL UNVERIFIED — tests 5, 6 and 7 are behavioural: they need throwaway
-- accounts, a real account deletion, and an Android device. Not run.
--
-- Supersedes genesyx-android/docs/migrations/2026-07-29_user_supplements.sql,
-- which must NOT be applied. That file is wrong in two ways that matter:
--   * it declares `user_id uuid NOT NULL` with NO `references` clause, which
--     would create precisely the orphan the audit feared — rows with no cascade,
--     missed by both delete paths;
--   * its comment claims "this DB has no FK cascades". Six exist, verified live
--     13 Aug 2026. That false premise is why it compensated with an explicit
--     delete line inside delete_current_user() instead of just using a cascade.
--
-- WHY THIS IS URGENT: Android already ships the client for these tables.
-- Production DI binds the real Supabase implementations whenever credentials
-- are configured (NetworkModule.kt:139,148), so today every supplement she adds
-- lands in Room as PENDING_UPSERT, fails against a missing relation, and
-- WorkManager retries it forever. Profile shows "N changes not synced yet —
-- Saved on your device, they'll sync to your account automatically." That
-- sentence is false while these tables do not exist, and "Sync now" can never
-- make it true.
--
-- SCOPE: server-side only. This does NOT touch iOS custom-supplement storage,
-- which is local (UserDefaults, CustomSupplement.storageKey) and reads none of
-- these tables. If iOS ever syncs supplements, the column names below become a
-- cross-platform contract and renaming one is a breaking change.
--
-- ORDERING: independent of migration A. A deliberately never names these
-- tables, and user_id below carries ON DELETE CASCADE, so account deletion
-- covers user_supplements automatically with no change to the RPC. Either
-- order, or one without the other, is safe.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. genesyx_products — shared read-only catalogue, intentionally EMPTY.
--
-- No SKUs are seeded. The Android UI already renders "coming soon" for an empty
-- catalogue (UserSupplementsSection.kt:316), which is also the correct offline
-- and guest rendering, so creating this table empty changes nothing visible and
-- lets rows be seeded later with no app update on either platform.
--
-- NOT user-owned. It must never appear in any account-deletion path: deleting
-- an account must not delete the product catalogue.
-- ----------------------------------------------------------------------------

create table if not exists public.genesyx_products (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null,
  dose       text,                               -- label as printed on the product
  sort_order integer     not null default 0,     -- display order; ties break on name
  active     boolean     not null default true,  -- false = retired, row kept for history
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Matches the client read: filter on active, then sort by (sort_order, name).
create index if not exists genesyx_products_active_idx
  on public.genesyx_products (active, sort_order, name);

alter table public.genesyx_products enable row level security;

-- REVOKE BEFORE GRANT, and the revoke must name `authenticated` too.
-- Supabase's schema-level default privileges hand the full arwdDxtm to anon,
-- authenticated AND service_role at CREATE TABLE time, so a bare `grant select`
-- is purely additive and leaves everything else standing. This is the same
-- defect 20260812_client_role_grant_cleanup.sql cleaned off the other six
-- tables; creating a table re-introduces it every time.
--
-- TRUNCATE is the privilege that actually matters here: it is NOT subject to
-- RLS, so no policy can scope or refuse it. A client holding it empties the
-- whole table in one statement. The only thing otherwise standing in the way is
-- that PostgREST emits no TRUNCATE verb — an API-layer property, not a control.
revoke all    on public.genesyx_products from anon, authenticated;
grant  select on public.genesyx_products to   authenticated;
grant  all    on public.genesyx_products to   service_role;

-- Read-only for signed-in users. No INSERT/UPDATE/DELETE policy exists, and no
-- write grant either, so a client cannot write the catalogue by any route.
drop policy if exists genesyx_products_read on public.genesyx_products;
create policy genesyx_products_read on public.genesyx_products
  for select to authenticated using (true);

-- ----------------------------------------------------------------------------
-- 2. user_supplements — her own entries.
--
-- Shape follows public.ph_readings: client-minted uuid PK, updated_at for
-- last-write-wins merge, deleted_at tombstone so a delete syncs instead of
-- reappearing on the next pull (the client's list() returns tombstones too).
-- ----------------------------------------------------------------------------

create table if not exists public.user_supplements (
  id          uuid        primary key default gen_random_uuid(),

  -- THE LINE THE 29 JUL DRAFT WAS MISSING. With this, account deletion needs no
  -- change on either client: the cascade fires when auth.users goes.
  user_id     uuid        not null references auth.users (id) on delete cascade,

  name        text        not null,
  dose        text,                     -- free text ("400 mcg"); nullable, never parsed
  time_of_day text,                     -- constrained below; null = unspecified

  -- SET NULL, not CASCADE: retiring a product must never delete her history.
  product_id  uuid        references public.genesyx_products (id) on delete set null,

  created_at  timestamptz not null default now(),

  -- NULLABLE ON PURPOSE. UserSupplementDto.updatedAt is String? and toDto()
  -- emits `updatedAt?.toString()`, so the client can serialise an explicit
  -- null. A NOT NULL column would reject that row and strand it PENDING
  -- forever — the exact failure mode this migration exists to end. The client's
  -- merge already handles a null updatedAt (UserSupplementRepository.refresh).
  updated_at  timestamptz default now(),

  deleted_at  timestamptz               -- soft-delete tombstone: null = live
);

-- Constraints added separately so re-running this file is safe on a table that
-- already exists. Both mirror limits the client already enforces, so neither
-- can reject a row a current build would send.
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.user_supplements'::regclass
                    and conname  = 'user_supplements_name_check') then
    -- Client contract is 1..60 chars, trimmed (UserSupplementRepository.kt:36).
    alter table public.user_supplements
      add constraint user_supplements_name_check
      check (char_length(btrim(name)) between 1 and 60);
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.user_supplements'::regclass
                    and conname  = 'user_supplements_time_of_day_check') then
    -- Exactly the four SupplementTime.wire values, plus null.
    alter table public.user_supplements
      add constraint user_supplements_time_of_day_check
      check (time_of_day is null
             or time_of_day in ('morning', 'afternoon', 'evening', 'anytime'));
  end if;
end $$;

-- Matches the client read: filter user_id, newest first.
create index if not exists user_supplements_user_idx
  on public.user_supplements (user_id, created_at desc);

alter table public.user_supplements enable row level security;

-- Revoke from `authenticated` first, for the reason spelled out above
-- genesyx_products. It matters more on this table: the default privileges
-- include TRUNCATE, RLS cannot refuse it, and one call would erase every user's
-- supplements — not merely the caller's own rows, which is all the owner policy
-- below ever governs.
revoke all on public.user_supplements from anon, authenticated;
grant  select, insert, update, delete on public.user_supplements to authenticated;
grant  all on public.user_supplements to service_role;

-- Owner-only, single ALL policy — matching the convention every other table on
-- this project already uses (ph_readings_owner, daily_logs_owner, ...) rather
-- than the four-policy split in the 29 Jul draft. Same effect, one thing to read.
drop policy if exists user_supplements_owner on public.user_supplements;
create policy user_supplements_owner on public.user_supplements
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================================
-- VERIFICATION — run after applying, with two throwaway accounts A and B.
--
--  1. Shape and the FK that matters:
--       select conname, pg_get_constraintdef(oid)
--         from pg_constraint
--        where conrelid = 'public.user_supplements'::regclass and contype = 'f';
--     expect user_id -> auth.users(id) ON DELETE CASCADE
--        and product_id -> public.genesyx_products(id) ON DELETE SET NULL
--
--  2. Grants are EXACT, not merely sufficient. Run this and read every row —
--     the first version of this migration passed a "can she write?" check while
--     silently leaving authenticated with TRUNCATE on both tables:
--       select grantee, table_name,
--              string_agg(privilege_type, ',' order by privilege_type) as privs
--         from information_schema.role_table_grants
--        where table_schema='public'
--          and table_name in ('user_supplements','genesyx_products')
--        group by grantee, table_name order by table_name, grantee;
--     expect exactly:
--       genesyx_products  authenticated  SELECT
--       user_supplements  authenticated  DELETE,INSERT,SELECT,UPDATE
--       both              service_role   full arwdDxtm
--       anon              absent from both rows entirely
--     THE FAILURE TO LOOK FOR IS AN EXTRA PRIVILEGE, NOT A MISSING ONE. If
--     TRUNCATE appears against authenticated, the revoke above did not run:
--     RLS cannot refuse TRUNCATE, so that one verb empties the table for every
--     user at once.
--
--  3. RLS isolation: as A insert a row; as B select it -> 0 rows; as B update
--     it by id -> 0 rows affected; as B delete it by id -> 0 rows affected.
--
--  4. Catalogue is read-only: as an authenticated user attempt INSERT, UPDATE
--     and DELETE on genesyx_products — all three must fail. SELECT must succeed
--     and return zero rows (the table ships empty, and the app renders that as
--     "coming soon").
--
--  5. THE CASCADE, which is the whole point. As A, insert two supplements, then
--     call public.delete_current_user(). Then as service_role:
--       select count(*) from public.user_supplements where user_id = <A>;
--     expect 0 — with NO user_supplements line anywhere in the RPC.
--     Then: select count(*) from public.genesyx_products;
--     expect UNCHANGED. Deleting an account must never touch the catalogue.
--
--  6. product_id SET NULL: seed one product, point a supplement at it, delete
--     the product as service_role, then re-read the supplement — the row must
--     still exist with product_id null. Remove the seeded product afterwards.
--
--  7. END TO END ON DEVICE, and this is the one that proves the bug is dead.
--     On an Android build with credentials configured: add a supplement, then
--     watch Profile. The "N changes not synced yet" row must reach zero on its
--     own. Then sign in on a second device and confirm the entry is there.
--     Before this migration it never cleared and never arrived.
-- ============================================================================

-- ============================================================================
-- ROLLBACK
--
-- Safe ONLY while no client has successfully written real data — which is the
-- situation today, because nothing has ever synced. After the first successful
-- sync, dropping these destroys user-entered supplement data: export
-- user_supplements first, and prefer leaving the tables in place. An unused
-- table costs nothing; a dropped one costs her history.
--
-- Order matters: user_supplements holds the FK, so it goes first.
--
-- Note what is NOT needed here, unlike the 29 Jul draft: because no delete path
-- ever names these tables, there is no function body to restore, and no risk of
-- leaving a dangling reference that breaks account deletion. That is the
-- payoff of relying on the cascade instead of an explicit delete line.
-- ============================================================================
--
-- drop table if exists public.user_supplements;
-- drop table if exists public.genesyx_products;
