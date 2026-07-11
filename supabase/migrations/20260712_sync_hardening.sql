-- Genesyx v1.0.1 — sync hardening.
--
-- Idempotent, and written against the schema that is ALREADY live in the genesyx project
-- (profiles, cycle_settings, daily_logs and ph_readings all exist; profiles is keyed on `id`,
-- daily_logs on (user_id, date)). Safe to re-run.
--
-- It adds: the columns the client now writes (profile prefs, pH tombstones), the pH range
-- constraint, the index behind the pH trend query, updated_at triggers — and row-level security,
-- which is the one thing here that is security-critical rather than cosmetic.
--
-- Apply: Supabase dashboard → SQL Editor → paste → Run.  (Or `supabase db push`.)

-- 1. updated_at -------------------------------------------------------------------------------

create or replace function public.bump_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 2. profiles ---------------------------------------------------------------------------------
-- Keyed on `id` (= auth.users.id) — NOT user_id. The three prefs mirror PreferencesRepository.

alter table public.profiles add column if not exists focus_mode   text    not null default 'prep';
alter table public.profiles add column if not exists theme_mode   text    not null default 'system';
alter table public.profiles add column if not exists push_enabled boolean not null default true;

drop trigger if exists profiles_bump_updated_at on public.profiles;
create trigger profiles_bump_updated_at before update on public.profiles
  for each row execute function public.bump_updated_at();

-- 3. cycle_settings + daily_logs --------------------------------------------------------------
-- The server is authoritative for these two (the client does no cross-device merge on them), so
-- a trigger owns updated_at.

drop trigger if exists cycle_settings_bump_updated_at on public.cycle_settings;
create trigger cycle_settings_bump_updated_at before update on public.cycle_settings
  for each row execute function public.bump_updated_at();

drop trigger if exists daily_logs_bump_updated_at on public.daily_logs;
create trigger daily_logs_bump_updated_at before update on public.daily_logs
  for each row execute function public.bump_updated_at();

-- 4. ph_readings ------------------------------------------------------------------------------

-- The tombstone. A deleted reading has to SYNC as deleted; if the row simply vanished, other
-- devices could not tell "deleted" from "never pushed" and would resurrect it.
alter table public.ph_readings add column if not exists deleted boolean not null default false;

-- Deliberately NO updated_at trigger on this table. pH is the one table with cross-device
-- conflict resolution, and the CLIENT authors updated_at (last edit wins, and an unpushed local
-- edit always wins — see PhSync.merge). A trigger stamping now() on every push would overwrite
-- the client's ordering and the merge would start losing edits.
--
-- `pending_sync` is deliberately NOT a column either: it means "does THIS device still owe the
-- server a push", which is local bookkeeping. Every client would write it as false. It lives in
-- the on-device store only.

-- pH is a physical measurement, not a free number. NOT VALID so the migration cannot fail on any
-- pre-existing row; it is enforced for every insert and update from here on. Once you're happy the
-- existing rows are in range, you can run:
--     alter table public.ph_readings validate constraint ph_readings_ph_range;
alter table public.ph_readings drop constraint if exists ph_readings_ph_range;
alter table public.ph_readings add constraint ph_readings_ph_range
  check (ph_value between 4.5 and 9.0) not valid;

create index if not exists ph_readings_user_recorded_idx
  on public.ph_readings (user_id, recorded_at);

-- 5. Row-level security -----------------------------------------------------------------------
-- THE IMPORTANT ONE. The anon key ships inside the app binary, so without RLS anybody holding it
-- can read every user's rows. Owner-only, every operation. Re-running this is harmless.

alter table public.profiles       enable row level security;
alter table public.cycle_settings enable row level security;
alter table public.daily_logs     enable row level security;
alter table public.ph_readings    enable row level security;

drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own cycle_settings" on public.cycle_settings;
create policy "own cycle_settings" on public.cycle_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own daily_logs" on public.daily_logs;
create policy "own daily_logs" on public.daily_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own ph_readings" on public.ph_readings;
create policy "own ph_readings" on public.ph_readings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Partner tables (partner_invites / partner_links) are left alone: the feature is flagged off and
-- the flow is not device-scoped in the same way. Do not enable it without its own RLS review.

-- Verify (run as the anon role in the SQL editor's "impersonate" mode, or from a second account):
--   select * from public.ph_readings;   -- must return 0 rows for a user who owns none
