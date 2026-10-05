-- Genesyx: ovulation (LH) test results, table `public.lh_results`.
--
-- STATUS: NOT APPLIED. Written 5 Oct 2026 as a file only; nothing in this repo has run it.
--
-- WHY THIS EXISTS
-- The Scan Test feature logs the result of an ovulation test strip, either typed in or read with
-- the camera. It is a new synced health record with its own table, shaped like ph_readings and
-- user_supplements: client-minted uuid primary key, a server-stamped `updated_at` for the sync
-- cursor, and a `deleted_at` tombstone so a delete reaches her other devices.
--
-- WHAT IS STORED
-- Only the classification and, for a scanned result, the scan measurements (two line signals,
-- their ratio, the analyser's confidence and the scanner / strip-configuration versions). Never an
-- image: the photo never leaves the phone.
--
-- HOW TO APPLY
-- By hand in the Supabase dashboard, SQL Editor, paste the WHOLE file and Run it ONCE. Never
-- `supabase db push`, and NEVER statement by statement. It is one transaction: any failed
-- assertion at the end rolls everything back.
--
-- Why once, as a whole: any policy DDL run as postgres on this project takes an ACCESS EXCLUSIVE
-- lock on about 23 auth / storage / realtime tables (auth.users, sessions, refresh_tokens,
-- storage.objects and others) until commit. Measured at about 7 ms on the first apply. Stopping
-- after the policy statement with the transaction open would block every sign-in until that
-- session ends. For the same reason the policy below is created only if absent, so a re-run
-- issues no policy DDL at all.
--
-- PRE-APPLY CHECK. Run this first and proceed ONLY if it returns 0:
--   select count(*) from pg_stat_activity
--    where pid <> pg_backend_pid() and xact_start is not null
--      and now() - xact_start > interval '2 seconds';
--
-- ORDER, DO NOT VARY IT:
--   1) THIS FILE (20261005_lh_results.sql),
--   2) VERIFY THE GRANTS EXACTLY (verification 1 at the foot of this file),
--   3) 20261005b_delete_current_user_lh_results.sql,
--   4) ONLY THEN `supabase functions deploy delete_account`.
-- WHY: THE `delete_account` EDGE FUNCTION NOW DELETES FROM THIS TABLE. DEPLOYED BEFORE THE TABLE
-- EXISTS, EVERY iOS ACCOUNT DELETION RETURNS 500 AFTER IT HAS ALREADY DELETED THE USER'S
-- ph_readings, daily_logs, cycle_settings, quiz_answers AND user_supplements ROWS, LEAVING THE
-- PROFILE AND THE AUTH USER IN PLACE.
--
-- ANDROID PARITY
-- The column names and the CHECK values (`classification`, `source`) are a contract from the
-- moment the Android app reads this table: do not rename or vary them. Android has no consent
-- gate yet and MUST NOT write this table until it has one.
--
-- Re-running is a no-op while the table's column set is unchanged (nothing is created, no policy
-- DDL is issued). If the column set has changed, the assertion block aborts and rolls back by
-- design, having changed nothing.

begin;

set local lock_timeout = '5s';

-- 0. Precondition -------------------------------------------------------------------------------
do $$ begin
  if to_regprocedure('public.bump_updated_at()') is null then
    raise exception 'ABORT: public.bump_updated_at() is missing (20260712_sync_hardening.sql)';
  end if;
end $$;

-- 1. Table --------------------------------------------------------------------------------------
create table if not exists public.lh_results (
  id                         uuid        primary key default gen_random_uuid(),   -- client-minted
  user_id                    uuid        not null references auth.users (id) on delete cascade,
  recorded_at                timestamptz not null,
  cycle_day                  integer,
  classification             text        not null,
  source                     text        not null,
  test_signal                double precision,
  control_signal             double precision,
  test_control_ratio         double precision,
  scan_confidence            double precision,
  scan_configuration_id      text,
  scan_configuration_version text,
  scanner_version            text,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now(),
  deleted_at                 timestamptz                                          -- tombstone: null = live
);

-- 2. Constraints --------------------------------------------------------------------------------
-- Added separately so re-running this file is safe on a table that already exists. Every CHECK
-- is NULL-safe (a CHECK passes when it evaluates to NULL): `classification` and `source` are NOT
-- NULL columns, and every nullable column is tested with an explicit `is null` / `is not null`.
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.lh_results'::regclass
                    and conname  = 'lh_results_classification_check') then
    -- 'unreadable' is never stored: an unreadable scan is not a result.
    alter table public.lh_results
      add constraint lh_results_classification_check
      check (classification in ('low', 'rising', 'positive', 'invalid'));
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.lh_results'::regclass
                    and conname  = 'lh_results_source_check') then
    alter table public.lh_results
      add constraint lh_results_source_check
      check (source in ('manual', 'camera_scan'));
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.lh_results'::regclass
                    and conname  = 'lh_results_cycle_day_check') then
    alter table public.lh_results
      add constraint lh_results_cycle_day_check
      check (cycle_day is null or cycle_day >= 1);
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.lh_results'::regclass
                    and conname  = 'lh_results_scan_confidence_range') then
    alter table public.lh_results
      add constraint lh_results_scan_confidence_range
      check (scan_confidence is null or (scan_confidence >= 0 and scan_confidence <= 1));
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.lh_results'::regclass
                    and conname  = 'lh_results_signals_nonnegative') then
    -- `x >= 0` alone accepts NaN and +Infinity on this server; `< 'Infinity'` rejects both.
    alter table public.lh_results
      add constraint lh_results_signals_nonnegative
      check ((test_signal        is null or (test_signal        >= 0 and test_signal        < 'Infinity'::double precision))
         and (control_signal     is null or (control_signal     >= 0 and control_signal     < 'Infinity'::double precision))
         and (test_control_ratio is null or (test_control_ratio >= 0 and test_control_ratio < 'Infinity'::double precision)));
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.lh_results'::regclass
                    and conname  = 'lh_results_scan_fields_match_source') then
    -- Holds in both directions: a camera scan carries all seven scan columns, a manual result
    -- carries none. `source` is NOT NULL, so neither arm can evaluate to NULL.
    alter table public.lh_results
      add constraint lh_results_scan_fields_match_source
      check (
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
      );
  end if;
end $$;

-- 3. Index (matches the client read: filter user_id, order by recorded_at) ----------------------
create index if not exists lh_results_user_recorded_idx
  on public.lh_results (user_id, recorded_at);

-- 4. Row level security and grants --------------------------------------------------------------
alter table public.lh_results enable row level security;

-- Revoke first: Supabase default privileges hand anon and authenticated everything at CREATE
-- TABLE time, including TRUNCATE, which RLS cannot refuse. A bare grant is only additive.
revoke all on public.lh_results from anon, authenticated;
grant  select, insert, update, delete on public.lh_results to authenticated;
grant  all on public.lh_results to service_role;

-- Owner-only, single ALL policy, the convention on every other table in this project, including
-- the `(select auth.uid())` form. Created only if absent: any policy DDL (even a bare create)
-- locks about 23 auth / storage / realtime tables until commit, so a re-run must issue none.
do $$ begin
  if not exists (select 1 from pg_policy
                  where polrelid = 'public.lh_results'::regclass and polname = 'lh_results_owner') then
    create policy lh_results_owner on public.lh_results
      for all to authenticated
      using ((select auth.uid()) = user_id)
      with check ((select auth.uid()) = user_id);
  end if;
end $$;

-- 5. updated_at is the server's -----------------------------------------------------------------
-- INSERT is included on purpose. The client sends its own clock in `updated_at`, and the sync
-- cursor must only ever hold server time: with a before-update trigger alone a first insert from
-- a phone whose clock runs fast would store a future stamp, and the cursor taken from it would
-- step over another device's rows for good.
drop trigger if exists lh_results_bump_updated_at on public.lh_results;
create trigger lh_results_bump_updated_at before insert or update on public.lh_results
  for each row execute function public.bump_updated_at();

-- 6. Pre-commit assertions: abort and roll back on any mismatch --------------------------------
do $chk$
declare
  v_rel  constant oid = 'public.lh_results'::regclass::oid;
  v_n    int;
  v_text text;
  r      record;
begin
  -- Columns: exactly the sixteen named above, no more and no fewer.
  select string_agg(attname::text, ',' order by attname) into v_text
    from pg_attribute where attrelid = v_rel and attnum > 0 and not attisdropped;
  if v_text is distinct from 'classification,control_signal,created_at,cycle_day,deleted_at,id,recorded_at,scan_confidence,scan_configuration_id,scan_configuration_version,scanner_version,source,test_control_ratio,test_signal,updated_at,user_id' then
    raise exception 'ABORT: lh_results columns are %', v_text;
  end if;

  -- NOT NULL exactly where declared.
  select string_agg(attname::text, ',' order by attname) into v_text
    from pg_attribute where attrelid = v_rel and attnum > 0 and not attisdropped and attnotnull;
  if v_text is distinct from 'classification,created_at,id,recorded_at,source,updated_at,user_id' then
    raise exception 'ABORT: lh_results NOT NULL columns are %', v_text;
  end if;

  -- The six CHECK constraints, all validated.
  select count(*) into v_n from pg_constraint
   where conrelid = v_rel and contype = 'c' and convalidated
     and conname in ('lh_results_classification_check', 'lh_results_source_check',
                     'lh_results_cycle_day_check', 'lh_results_scan_confidence_range',
                     'lh_results_signals_nonnegative', 'lh_results_scan_fields_match_source');
  if v_n <> 6 then raise exception 'ABORT: % of 6 CHECK constraints present', v_n; end if;

  -- user_id -> auth.users (id) ON DELETE CASCADE.
  select count(*) into v_n from pg_constraint
   where conrelid = v_rel and contype = 'f'
     and confrelid = 'auth.users'::regclass and confdeltype = 'c';
  if v_n <> 1 then raise exception 'ABORT: user_id cascade foreign key count is %', v_n; end if;

  -- RLS on, and exactly one policy: lh_results_owner, FOR ALL, TO authenticated only.
  if not (select relrowsecurity from pg_class where oid = v_rel) then
    raise exception 'ABORT: row level security is not enabled';
  end if;
  select count(*) into v_n from pg_policy where polrelid = v_rel;
  if v_n <> 1 then raise exception 'ABORT: % policies on lh_results, expected 1', v_n; end if;
  select polname, polcmd, polpermissive, polroles::regrole[]::text as roles,
         pg_get_expr(polqual, polrelid) as qual, pg_get_expr(polwithcheck, polrelid) as wcheck
    into r from pg_policy where polrelid = v_rel;
  if r.polname <> 'lh_results_owner' or r.polcmd <> '*' or not r.polpermissive
     or r.roles <> '{authenticated}'
     or r.qual   is distinct from '(( SELECT auth.uid() AS uid) = user_id)'
     or r.wcheck is distinct from '(( SELECT auth.uid() AS uid) = user_id)' then
    raise exception 'ABORT: policy is % cmd % roles % using % check %', r.polname, r.polcmd, r.roles, r.qual, r.wcheck;
  end if;

  -- Grants are EXACT. The failure to look for is an EXTRA privilege (TRUNCATE above all).
  select coalesce(string_agg(a.privilege_type, ',' order by a.privilege_type), '') into v_text
    from pg_class c, aclexplode(c.relacl) a
   where c.oid = v_rel and a.grantee = 'authenticated'::regrole::oid;
  if v_text <> 'DELETE,INSERT,SELECT,UPDATE' then
    raise exception 'ABORT: authenticated holds [%]', v_text;
  end if;
  select count(*) into v_n
    from pg_class c, aclexplode(c.relacl) a
   where c.oid = v_rel and a.grantee in ('anon'::regrole::oid, 0);   -- 0 = PUBLIC
  if v_n <> 0 then raise exception 'ABORT: anon or PUBLIC holds % privilege(s)', v_n; end if;

  -- The trigger: enabled, row-level, BEFORE INSERT OR UPDATE (tgtype 1 + 2 + 4 + 16 = 23).
  select count(*) into v_n from pg_trigger
   where tgrelid = v_rel and not tgisinternal and tgname = 'lh_results_bump_updated_at'
     and tgtype = 23 and tgenabled = 'O'
     and tgfoid = 'public.bump_updated_at()'::regprocedure::oid;
  if v_n <> 1 then raise exception 'ABORT: lh_results_bump_updated_at is missing or not BEFORE INSERT OR UPDATE'; end if;
end
$chk$;

commit;

-- ============================================================================
-- VERIFICATION: run after applying, with two throwaway accounts A and B.
--
--  1. Grants are EXACT, not merely sufficient:
--       select grantee, string_agg(privilege_type, ',' order by privilege_type) as privs
--         from information_schema.role_table_grants
--        where table_schema = 'public' and table_name = 'lh_results'
--        group by grantee order by grantee;
--     expect exactly:
--       authenticated  DELETE,INSERT,SELECT,UPDATE   and nothing else
--       service_role   full (arwdDxtm)
--       anon           absent entirely
--     and the table ACL (select relacl from pg_class where oid = 'public.lh_results'::regclass)
--     reads exactly:
--       {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=arwd/postgres}
--     THE FAILURE TO LOOK FOR IS AN EXTRA PRIVILEGE, NOT A MISSING ONE. If TRUNCATE appears
--     against authenticated the revoke did not run: RLS cannot refuse TRUNCATE, so that one verb
--     empties the table for every user at once.
--
--  2. RLS isolation: as A insert a manual row; as B select it -> 0 rows; as B update it by id
--     -> 0 rows affected; as B delete it by id -> 0 rows affected; as B insert a row carrying
--     A's user_id -> refused.
--
--  3. FK cascade: as service_role delete throwaway account A from auth.users, then
--       select count(*) from public.lh_results where user_id = <A>;
--     expect 0.
--
--  4. Server time on INSERT: as A insert a row carrying updated_at = now() + interval '1 day',
--     read it back, and expect updated_at within a second of now(), not tomorrow. Update the
--     row with another future updated_at and expect the same.
--
--  5. CHECKs refuse what they should (each must fail): classification 'unreadable';
--     source 'manual' with test_signal set; source 'camera_scan' with scanner_version null;
--     scan_confidence 1.5; cycle_day 0; test_signal, control_signal or test_control_ratio set to
--     'NaN', 'Infinity' or '-Infinity' (all nine must fail with lh_results_signals_nonnegative).
-- ============================================================================

-- ============================================================================
-- ROLLBACK (destroys every stored result; splice lh_results back out of
-- delete_current_user() and redeploy delete_account without its lh_results line FIRST):
--
--   drop table public.lh_results;
-- ============================================================================
