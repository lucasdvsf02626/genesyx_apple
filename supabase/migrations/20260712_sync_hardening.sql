-- Genesyx v1.0.1 — sync hardening.
--
-- REVISED against the live genesyx project after inspecting it. Most of what the v1.0.1 doc asks
-- for is ALREADY THERE: RLS is enabled with owner-only policies on all four tables, ph_readings
-- already has the validated 4.5–9.0 CHECK and the auth.users FK, and the tables/columns the app
-- reads all exist. So this migration does NOT recreate any of that — in particular it does not
-- touch RLS policies, because `profiles` carries an extra partner-read policy that a
-- drop-and-recreate would destroy.
--
-- Two live columns differ from the doc's schema, and the APP was changed to match the DB rather
-- than the other way round (no duplicate columns, no renaming of a column other clients may read):
--   * ph_readings tombstone is the existing `deleted_at timestamptz` (null = alive) — NOT a
--     `deleted` boolean. PhReadingRow maps it.
--   * profiles theme column is the existing `theme` — NOT `theme_mode`. ProfilePrefsRow maps it.
--
-- What is genuinely missing: two preference columns on `profiles`.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run.

-- 1. profiles: the two preference columns the client now writes -------------------------------
-- (`theme` already exists and is reused; `display_name` and `partner_id` are untouched.)

alter table public.profiles add column if not exists focus_mode   text    not null default 'prep';
alter table public.profiles add column if not exists push_enabled boolean not null default true;

-- 2. ph_readings: the index behind the pH trend query -----------------------------------------

create index if not exists ph_readings_user_recorded_idx
  on public.ph_readings (user_id, recorded_at);

-- 3. updated_at ---------------------------------------------------------------------------------
-- Server-authoritative for profiles / cycle_settings / daily_logs: the client does no cross-device
-- merge on those, so a trigger owns the column.
--
-- ph_readings is deliberately EXCLUDED. It is the one table with conflict resolution, and the
-- CLIENT authors updated_at (last edit wins; an unpushed local edit always wins — see
-- PhSync.merge). A trigger stamping now() on every push would overwrite the client's ordering and
-- the merge would start losing edits.
--
-- ⚠️ CHECK FIRST — if a bump trigger already exists on ph_readings, it must be DROPPED, or pH
-- last-write-wins will misbehave across devices. Run the verification query at the bottom.

create or replace function public.bump_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_bump_updated_at on public.profiles;
create trigger profiles_bump_updated_at before update on public.profiles
  for each row execute function public.bump_updated_at();

drop trigger if exists cycle_settings_bump_updated_at on public.cycle_settings;
create trigger cycle_settings_bump_updated_at before update on public.cycle_settings
  for each row execute function public.bump_updated_at();

drop trigger if exists daily_logs_bump_updated_at on public.daily_logs;
create trigger daily_logs_bump_updated_at before update on public.daily_logs
  for each row execute function public.bump_updated_at();

-- 4. Verify -------------------------------------------------------------------------------------

-- (a) The new columns exist:
--   select column_name from information_schema.columns
--    where table_name = 'profiles' and column_name in ('focus_mode','push_enabled','theme');

-- (b) ⚠️ THE IMPORTANT ONE — no trigger may bump updated_at on ph_readings:
--   select tgname from pg_trigger
--    where tgrelid = 'public.ph_readings'::regclass and not tgisinternal;
--   -- If this returns a bump/updated_at trigger, drop it:
--   --   drop trigger <name> on public.ph_readings;

-- (c) RLS is already enabled with owner policies — confirm, don't recreate:
--   select tablename, policyname from pg_policies
--    where tablename in ('profiles','cycle_settings','daily_logs','ph_readings');
