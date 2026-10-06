-- ============================================================================
-- Genesyx — Supabase schema + Row Level Security
-- ============================================================================
-- Paste this whole file into the Supabase SQL editor (or run via CLI) once, on a
-- fresh project. It creates every table the iOS app reads/writes and locks each
-- one down so an authenticated user can only touch their own rows.
--
-- Column names, types, and upsert keys are matched EXACTLY to the app's row DTOs
-- in App/Genesyx/Data/Remote/RemoteModels.swift. If you change one, change both.
--
-- Tables:  profiles · cycle_settings · period_records · ph_readings · lh_results · daily_logs · partner_invites
-- Safe to re-run: uses IF NOT EXISTS / DROP POLICY IF EXISTS throughout.
-- ============================================================================

-- ------------------------------------------------------------------
-- profiles — one row per auth user; holds display name + partner link
-- ------------------------------------------------------------------
create table if not exists public.profiles (
    id           uuid primary key references auth.users (id) on delete cascade,
    display_name text,
    partner_id   uuid references public.profiles (id) on delete set null,
    created_at   timestamptz not null default now()
);

-- Auto-create a profile row whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, display_name)
    values (new.id, coalesce(new.raw_user_meta_data->>'display_name',
                             split_part(new.email, '@', 1)))
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- SECURITY DEFINER helper: returns the caller's partner id WITHOUT re-triggering
-- RLS on profiles (a plain sub-select inside the policy would recurse and error).
create or replace function public.current_partner_id()
returns uuid
language sql
stable
security definer set search_path = public
as $$
    select partner_id from public.profiles where id = auth.uid();
$$;

-- ------------------------------------------------------------------
-- cycle_settings — one row per user (PK = user_id → drives .upsert())
-- ------------------------------------------------------------------
create table if not exists public.cycle_settings (
    user_id          uuid primary key references auth.users (id) on delete cascade,
    last_period_date date    not null,          -- yyyy-MM-dd
    cycle_length     integer not null,
    period_length    integer not null,
    updated_at       timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- period_records: cycle history, one row per (user, period start date). PK (user_id, start_date), drives .upsert()
-- ------------------------------------------------------------------
-- 5 Oct 2026: kept in sync with migration 20261006_period_records.sql, which is the authoritative
-- copy (it also asserts the result). Not applied to the live database yet. Cycles are never
-- stored: clients derive them from consecutive starts. A corrected start is a tombstone on the
-- old date plus a row on the new one. No constraint compares one row with another. The dates are
-- range-checked: start_date on or after 1900-01-01, and neither date later than tomorrow's date
-- in UTC (the server's clock plus one day, so a user ahead of UTC is never refused).
create table if not exists public.period_records (
    user_id    uuid not null references auth.users (id) on delete cascade,
    start_date date not null,                   -- yyyy-MM-dd, first day of the period
    end_date   date,                            -- yyyy-MM-dd, last day inclusive; null = not recorded
    source     text not null check (source in ('recorded', 'seeded')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,                     -- tombstone: null = live
    primary key (user_id, start_date),
    constraint period_records_dates_finite check (
        isfinite(start_date) and (end_date is null or isfinite(end_date))
    ),
    constraint period_records_end_not_before_start check (
        end_date is null or end_date >= start_date
    ),
    constraint period_records_dates_in_range check (
        start_date >= date '1900-01-01'
        and start_date <= (now() at time zone 'utc')::date + 1
        and (end_date is null or end_date <= (now() at time zone 'utc')::date + 1)
    )
);
-- The server's clock owns updated_at, on insert as well as update (see lh_results below).
drop trigger if exists period_records_bump_updated_at on public.period_records;
create trigger period_records_bump_updated_at before insert or update on public.period_records
    for each row execute function public.bump_updated_at();

-- ------------------------------------------------------------------
-- ph_readings — many per user (id is a client-generated UUID string)
-- ------------------------------------------------------------------
create table if not exists public.ph_readings (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users (id) on delete cascade,
    ph_value         double precision not null,
    measurement_type text not null default 'urine'
                       check (measurement_type in ('urine', 'vaginal')),
    recorded_at      timestamptz not null,
    notes            text,
    created_at       timestamptz not null default now(),
    -- Conditional range: vaginal 3.8–7.0, legacy urine 4.5–9.0.
    -- Kept in sync with migration 20260722_ph_conditional_value_range.sql.
    constraint ph_value_range check (
        (measurement_type = 'vaginal' and ph_value >= 3.8 and ph_value <= 7.0)
        or
        (measurement_type = 'urine'   and ph_value >= 4.5 and ph_value <= 9.0)
    )
);
create index if not exists ph_readings_user_recorded_idx
    on public.ph_readings (user_id, recorded_at);
-- 5 Oct 2026: scan provenance columns (all nullable; source null = manual) are added by
-- migration 20261005_ph_readings_scan_source.sql: source, scan_confidence,
-- scan_configuration_id, scan_configuration_version, scanner_version. Not applied to the live
-- database yet; apply it before the Scan Test feature flag is enabled in a shipped build.

-- ------------------------------------------------------------------
-- lh_results — ovulation (LH) test results, many per user (id is a client-generated UUID string)
-- ------------------------------------------------------------------
-- 5 Oct 2026: kept in sync with migration 20261005_lh_results.sql, which is the authoritative
-- copy (it also asserts the result). Not applied to the live database yet. Only the
-- classification and the scan measurements are stored, never an image.
create table if not exists public.lh_results (
    id                         uuid primary key default gen_random_uuid(),
    user_id                    uuid not null references auth.users (id) on delete cascade,
    recorded_at                timestamptz not null,
    cycle_day                  integer check (cycle_day is null or cycle_day >= 1),
    classification             text not null
                                 check (classification in ('low', 'rising', 'positive', 'invalid')),
    source                     text not null check (source in ('manual', 'camera_scan')),
    test_signal                double precision,
    control_signal             double precision,
    test_control_ratio         double precision,
    scan_confidence            double precision,
    scan_configuration_id      text,
    scan_configuration_version text,
    scanner_version            text,
    created_at                 timestamptz not null default now(),
    updated_at                 timestamptz not null default now(),
    deleted_at                 timestamptz,             -- tombstone: null = live
    constraint lh_results_scan_confidence_range check (
        scan_confidence is null or (scan_confidence >= 0 and scan_confidence <= 1)
    ),
    constraint lh_results_signals_nonnegative check (
        (test_signal        is null or (test_signal        >= 0 and test_signal        < 'Infinity'::double precision))
        and (control_signal     is null or (control_signal     >= 0 and control_signal     < 'Infinity'::double precision))
        and (test_control_ratio is null or (test_control_ratio >= 0 and test_control_ratio < 'Infinity'::double precision))
    ),
    -- A camera scan carries all seven scan columns; a manual result carries none.
    constraint lh_results_scan_fields_match_source check (
        (source = 'camera_scan'
           and test_signal is not null and control_signal is not null
           and test_control_ratio is not null and scan_confidence is not null
           and scan_configuration_id is not null and scan_configuration_version is not null
           and scanner_version is not null)
        or
        (source = 'manual'
           and test_signal is null and control_signal is null
           and test_control_ratio is null and scan_confidence is null
           and scan_configuration_id is null and scan_configuration_version is null
           and scanner_version is null)
    )
);
create index if not exists lh_results_user_recorded_idx
    on public.lh_results (user_id, recorded_at);
-- The server's clock owns updated_at, on insert as well as update: the client sends its own, and
-- the sync cursor must only ever hold server time. `bump_updated_at()` is defined in
-- migration 20260712_sync_hardening.sql.
drop trigger if exists lh_results_bump_updated_at on public.lh_results;
create trigger lh_results_bump_updated_at before insert or update on public.lh_results
    for each row execute function public.bump_updated_at();

-- ------------------------------------------------------------------
-- daily_logs — one row per (user, day). PK (user_id, date) → .upsert()
-- ------------------------------------------------------------------
create table if not exists public.daily_logs (
    user_id       uuid not null references auth.users (id) on delete cascade,
    date          date not null,                -- yyyy-MM-dd
    mood          text check (mood   in ('great','good','okay','low')),
    energy        text check (energy in ('low','normal','high')),
    symptoms      text[]  not null default '{}',
    sleep_minutes integer,
    water_ml      integer not null default 0,
    supplements   text[]  not null default '{}',
    notes         text,
    updated_at    timestamptz not null default now(),
    primary key (user_id, date)
);

-- ------------------------------------------------------------------
-- partner_invites — invites the user has sent (id/created_at server-set)
-- ------------------------------------------------------------------
create table if not exists public.partner_invites (
    id            uuid primary key default gen_random_uuid(),
    inviter_id    uuid not null references auth.users (id) on delete cascade,
    invitee_email text not null,
    code          text not null unique,
    status        text not null default 'pending'
                       check (status in ('pending','accepted','revoked')),
    created_at    timestamptz not null default now()
);
create index if not exists partner_invites_inviter_idx
    on public.partner_invites (inviter_id);

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table public.profiles        enable row level security;
alter table public.cycle_settings  enable row level security;
alter table public.ph_readings     enable row level security;
alter table public.lh_results      enable row level security;
alter table public.daily_logs      enable row level security;
alter table public.partner_invites enable row level security;

-- profiles: read own + your linked partner's; write only your own.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
    for select to authenticated
    using (id = auth.uid() or id = public.current_partner_id());

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
    for insert to authenticated
    with check (id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
    for update to authenticated
    using (id = auth.uid()) with check (id = auth.uid());

-- cycle_settings / ph_readings / daily_logs: full CRUD on your own rows only.
drop policy if exists cycle_settings_owner on public.cycle_settings;
create policy cycle_settings_owner on public.cycle_settings
    for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists ph_readings_owner on public.ph_readings;
create policy ph_readings_owner on public.ph_readings
    for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists period_records_owner on public.period_records;
create policy period_records_owner on public.period_records
    for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists lh_results_owner on public.lh_results;
create policy lh_results_owner on public.lh_results
    for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists daily_logs_owner on public.daily_logs;
create policy daily_logs_owner on public.daily_logs
    for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

-- partner_invites: the inviter manages their own invites. (Accepting an invite is
-- done by the accept_partner_invite Edge Function with the service role, which
-- bypasses RLS — so the invitee needs no direct policy here.)
drop policy if exists partner_invites_owner on public.partner_invites;
create policy partner_invites_owner on public.partner_invites
    for all to authenticated
    using (inviter_id = auth.uid()) with check (inviter_id = auth.uid());

-- ============================================================================
-- Grants — RLS decides row visibility; these grant the table-level privilege.
-- ============================================================================
grant usage on schema public to authenticated;
grant select, insert, update, delete on
    public.profiles, public.cycle_settings, public.ph_readings,
    public.daily_logs, public.partner_invites
    to authenticated;
-- lh_results: revoke first, so the TRUNCATE that Supabase default privileges hand out at
-- CREATE TABLE time (and that RLS cannot refuse) is gone.
revoke all on public.lh_results from anon, authenticated;
grant select, insert, update, delete on public.lh_results to authenticated;
grant all on public.lh_results to service_role;
-- period_records: the same revoke-first rule.
revoke all on public.period_records from anon, authenticated;
grant select, insert, update, delete on public.period_records to authenticated;
grant all on public.period_records to service_role;

-- ============================================================================
-- Sanity check (optional) — run after the above; every table should show rls = true.
-- ============================================================================
-- select tablename, rowsecurity as rls
--   from pg_tables where schemaname = 'public'
--   order by tablename;
