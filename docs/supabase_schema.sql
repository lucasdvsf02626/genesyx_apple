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
-- Tables:  profiles · cycle_settings · ph_readings · daily_logs · partner_invites
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
-- ph_readings — many per user (id is a client-generated UUID string)
-- ------------------------------------------------------------------
create table if not exists public.ph_readings (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    ph_value    double precision not null,
    recorded_at timestamptz not null,
    notes       text,
    created_at  timestamptz not null default now()
);
create index if not exists ph_readings_user_recorded_idx
    on public.ph_readings (user_id, recorded_at);

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

-- ============================================================================
-- Sanity check (optional) — run after the above; every table should show rls = true.
-- ============================================================================
-- select tablename, rowsecurity as rls
--   from pg_tables where schemaname = 'public'
--   order by tablename;
