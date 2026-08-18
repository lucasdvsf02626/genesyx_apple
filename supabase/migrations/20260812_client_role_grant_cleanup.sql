-- Genesyx — take away the client-role privileges that no client can exercise anyway.
--
-- WHY THIS IS SEPARATE FROM 20260812_partner_invites_write_lockdown.sql
-- That migration takes UPDATE and DELETE on `partner_invites` away from `authenticated`, which is a
-- real behaviour change: it breaks any client still issuing a direct PATCH, and Android shares this
-- database and is not in this repo. It is therefore gated on an Android grep and an iOS release.
--
-- Everything in THIS file is gated on nothing, because none of it can change any client's
-- behaviour. Two categories only:
--
--   (1) Every privilege `anon` holds on the app tables. All 8 RLS policies name `{authenticated}`
--       and nothing else (verified below), so `anon` is already refused every row of every one of
--       these tables by RLS. The grant it holds is unreachable.
--   (2) TRUNCATE on `authenticated`. PostgREST has no TRUNCATE verb, so no HTTP client on any
--       platform can emit one.
--
-- Folding these into the lockdown migration would have parked two free wins behind an unrelated
-- blocker. Splitting is the whole point: this one can be applied today.
--
-- WHY TRUNCATE IS NOT MERELY UNTIDY
-- TRUNCATE is not subject to RLS. A policy cannot restrict it, scope it to a row, or refuse it. So
-- for `anon`, "RLS already denies it everything" was true of every verb EXCEPT this one, and the
-- only thing standing between a leaked anon key and an empty `daily_logs` was that PostgREST does
-- not expose the verb. That is a property of the API layer, not a control — anything that ever
-- reaches this database with the anon role over a Postgres connection has it. The anon key is
-- published in the app binary by design.
--
-- WHAT THIS FILE DELIBERATELY DOES NOT DO
-- It does not touch UPDATE or DELETE for `authenticated` on any table. Both are reachable verbs
-- that a client may legitimately be using, and only the iOS client can be read from this repo.
-- Deciding those needs the Android sweep. See §4.
--
-- MEASURED BEFORE-STATE (2026-08-12, read-only, this project — pg_class.relacl):
--   cycle_settings, daily_logs, ph_readings, quiz_answers, partner_invites:
--     postgres=arwdDxtm | anon=arwdDxtm | authenticated=arwdDxtm | service_role=arwdDxtm
--   profiles (anon's `w` already removed by 20260810_profiles_partner_id_write_guard.sql):
--     postgres=arwdDxtm | anon=ardDxtm | authenticated=ardDxtm | service_role=arwdDxtm
--   waitlist_emails: postgres and service_role only — no client role holds anything. Nothing to do.
--   RLS enabled on all seven.
--
-- Idempotent: REVOKE is declarative and safe to re-run.
-- Apply: paste this file into the Supabase Dashboard SQL Editor and run it. (This line used to name
-- `supabase db query --linked -f`, a subcommand that no longer exists — checked against CLI 2.109.1
-- on 2026-08-17.)
-- Do NOT use `supabase db push` — this project has no supabase_migrations.schema_migrations table;
-- every migration here has been applied by hand and push would replay all of them.

begin;

-- 1. Preconditions --------------------------------------------------------------------------------
-- The claim this migration rests on is "no policy grants `anon` anything". Assert it rather than
-- trust the reading, so that a policy added between the audit and the apply stops this file instead
-- of silently locking out a role something had started to depend on.
do $$
declare
  missing text;
  anon_policies int;
begin
  select string_agg(t, ', ')
    into missing
    from unnest(array[
      'cycle_settings', 'daily_logs', 'ph_readings', 'quiz_answers',
      'partner_invites', 'profiles'
    ]) as t
   where to_regclass('public.' || t) is null;

  if missing is not null then
    raise exception 'missing table(s): %; wrong database?', missing;
  end if;

  select count(*)
    into anon_policies
    from pg_policies
   where schemaname = 'public'
     and tablename in ('cycle_settings', 'daily_logs', 'ph_readings', 'quiz_answers',
                       'partner_invites', 'profiles')
     and ('anon' = any(roles) or 'public' = any(roles));

  if anon_policies > 0 then
    raise exception
      'a policy on these tables names anon or PUBLIC; revoking anon''s grants would change behaviour';
  end if;
end $$;

-- 2. `anon` keeps nothing on the app tables --------------------------------------------------------
-- Not a behaviour change: `auth.uid()` is null without a session, every policy is `TO authenticated`,
-- and every client path in the app calls `requireUID` and throws before it reaches any of these.
-- What it does change is that TRUNCATE — the one verb RLS never filtered — is now gone too.
revoke all on
  public.cycle_settings,
  public.daily_logs,
  public.ph_readings,
  public.quiz_answers,
  public.partner_invites,
  public.profiles
from anon;

-- 3. `authenticated` keeps no TRUNCATE anywhere ----------------------------------------------------
-- Its other privileges are untouched here. A signed-in user can still read and write her own rows
-- exactly as before; she simply cannot empty a table, which she was never able to ask for over
-- PostgREST and which RLS would not have stopped if she could.
revoke truncate on
  public.cycle_settings,
  public.daily_logs,
  public.ph_readings,
  public.quiz_answers,
  public.partner_invites,
  public.profiles
from authenticated;

-- `service_role` is untouched throughout. It holds its own table-level grant and bypasses RLS —
-- that is how every Edge Function writes, and nothing above narrows it.

commit;

-- 4. HELD — decisions this file will not make for you ----------------------------------------------
--
-- 4A. Does `authenticated` need UPDATE on all four health tables?
--     Audited 2026-08-12: yes, and unlike `partner_invites` this is not a hole waiting to happen.
--     Every column on `cycle_settings`, `daily_logs`, `ph_readings` and `quiz_answers` is the user's
--     own data, written by her own device. There is no server-authoritative column — no analogue of
--     `profiles.partner_id` (whose value grants a read on someone else) or `partner_invites.status`
--     (a state machine a privilege cannot express). And there is no cross-user surface: the sole
--     partner-visibility path in the whole schema is `profiles_select`, the only policy that calls
--     `current_partner_id()`. All four health policies are `user_id = auth.uid()` on both USING and
--     WITH CHECK, so the worst a user can do with this privilege is corrupt her own logs.
--     `updated_at` is the only column with server semantics, and BEFORE UPDATE triggers overwrite
--     whatever the client sends on three of the four.
--
-- 4B. Does `authenticated` need DELETE on them? Unknown from this repo. iOS never deletes —
--     `ph_readings` soft-deletes via the `deleted_at` tombstone and the other three are upsert-only
--     — but Android is not here, and a client that hard-deletes would break silently. Needs the
--     same sweep as the `partner_invites` lockdown before it can be answered.
--
-- 4C. `quiz_answers.updated_at` is never maintained: the table has no trigger and `QuizAnswersRow`
--     (RemoteModels.swift:238) does not send the column, so PostgREST's ON CONFLICT SET never
--     touches it and it keeps its insert-time `now()` forever. Nothing in the app or the schema
--     reads it, so this is inert rather than wrong. Noted, not fixed — out of scope here.
--
-- 4D. The timestamps held open at 20260810_profiles_partner_id_write_guard.sql §5 are still open.
--     That revoke is now mechanically possible (the table-level UPDATE came off in that file's §2),
--     and it is blocked on the same Android question as 4B.

-- 5. Verification ----------------------------------------------------------------------------------
-- Run after the above.
--
-- V1. Table ACLs. Expect NO anon row on any of the six, and `authenticated` with `D` (TRUNCATE)
--     gone and NOTHING ELSE removed:
--       cycle_settings, daily_logs, ph_readings, quiz_answers, partner_invites
--         arwdDxtm -> arwdxtm   (INSERT/SELECT/UPDATE/DELETE/REFERENCES/TRIGGER/MAINTAIN)
--       profiles
--         ardDxtm  -> ardxtm    (same, minus the UPDATE 20260810 already took at table level)
--     `d` (DELETE) is still present on purpose — see 4B. postgres and service_role unchanged at
--     arwdDxtm. If partner_invites reads arDxtm or arxtm here, the lockdown migration has also
--     been applied; that is fine and independent.
--
-- select c.relname as tbl,
--        coalesce(nullif(split_part(s.acl, '=', 1), ''), 'PUBLIC') as grantee,
--        split_part(split_part(s.acl, '=', 2), '/', 1)             as privs
--   from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--   cross join lateral (select unnest(c.relacl)::text as acl) s
--  where n.nspname = 'public'
--    and c.relname in ('cycle_settings', 'daily_logs', 'ph_readings', 'quiz_answers',
--                      'partner_invites', 'profiles')
--  order by 1, 2;
--
-- V2. No anon privilege survives at COLUMN level. Expect ZERO rows.
--     This matters because a table-level REVOKE does not reach into column-level grants: the two
--     are stored separately (pg_class.relacl vs pg_attribute.attacl) and §2 only clears the first.
--     Measured 2026-08-12: zero anon column grants existed on any of the six, so there is nothing
--     for §2 to miss — this query proves that assumption still held at apply time rather than
--     assuming it. (The nine UPDATE grants 20260810 put on profiles are `authenticated`, not anon,
--     so they are correctly excluded here and are meant to survive.)
--
-- select c.relname, a.attname, a.attacl::text
--   from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--   join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
--  where n.nspname = 'public'
--    and c.relname in ('cycle_settings', 'daily_logs', 'ph_readings', 'quiz_answers',
--                      'partner_invites', 'profiles')
--    and a.attacl::text like '%anon=%'
--  order by 1, 2;
--
-- V3. Policies untouched — expect the same 8 rows, all {authenticated}, as before.
--
-- select tablename, policyname, cmd, roles::text from pg_policies
--  where schemaname = 'public' order by 1, 2;
--
-- V4. Then prove it end to end, which the catalog cannot do. Sign in on a device and confirm the
--     ordinary loop still works: log a day, save a pH reading, change a preference, send an invite.
--     Every one of those runs as `authenticated` and none of them is touched by this file — if any
--     breaks, the revoke was wider than intended.
