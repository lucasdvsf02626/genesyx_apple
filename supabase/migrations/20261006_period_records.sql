-- Genesyx: cycle history, table `public.period_records`.
--
-- STATUS: NOT APPLIED. Written 5 Oct 2026 as a file only; nothing in this repo has run it.
-- NO AGENT MAY APPLY THIS FILE. It goes through the database review gate (a rolled-back dry run
-- against live, then a GO from the reviewer) and is then applied by the owner, by hand.
--
-- WHY THIS EXISTS
-- Until now the app kept one period date per user, `cycle_settings.last_period_date`, and
-- overwrote it. Cycle history keeps every period she records: one row per user per period START
-- DATE, with an optional last day. Cycles and their lengths are never stored; the clients derive
-- them from consecutive starts. `cycle_settings` is unchanged and is still the only input to
-- predictions.
--
-- THE KEY IS (user_id, start_date), NOT A RANDOM ID
-- Two devices that both record "my period started on 3 March" while offline must end up as one
-- row, exactly as `daily_logs` does with (user_id, date). Consequences the clients rely on:
--   * A CORRECTION of a start date cannot change the key, so it is TWO upserts: a tombstone
--     (`deleted_at` set) on the old date and a row on the new date.
--   * Recording again on a date that holds a tombstone clears `deleted_at` on that row. Clients
--     therefore send `deleted_at` and `end_date` on every upsert, as an explicit null when empty.
--   * There is deliberately NO constraint across rows. Two devices can record different starts
--     for the same period, and a merge can leave one row's `end_date` on or after the next row's
--     `start_date`. Both are tolerated by the clients and corrected by her, never by the database.
--
-- WHAT IS STORED
-- The start date, the optional end date, and whether the row was `recorded` by her or `seeded`
-- (the single row copied from her cycle settings when history first switched on). Nothing else.
--
-- DATE RANGE
-- `start_date` must be on or after 1900-01-01, and neither `start_date` nor `end_date` may be
-- later than tomorrow's date in UTC (the server's clock plus one day, so a user ahead of UTC is
-- never refused). A write outside that range fails with 23514 (check_violation). The start date
-- is the key and drives `cycle_settings.last_period_date` on every device, so a year taken from a
-- wrong device clock or calendar must not become her "latest period". ANDROID_PARITY.md section 7
-- states the same rule for the Android client.
--
-- HOW TO APPLY
-- By hand in the Supabase dashboard, SQL Editor, paste the WHOLE file and Run it ONCE. Never
-- `supabase db push`, and NEVER statement by statement. It is one transaction: any failed
-- assertion at the end rolls everything back.
--
-- Why once, as a whole: any policy DDL run as postgres on this project takes an ACCESS EXCLUSIVE
-- lock on about 23 auth / storage / realtime tables (auth.users, sessions, refresh_tokens,
-- storage.objects and others) until commit. Stopping after the policy statement with the
-- transaction open would block every sign-in until that session ends. For the same reason the
-- policy below is created only if absent, so a re-run issues no policy DDL at all.
--
-- PRE-APPLY CHECK. Run this first and proceed ONLY if it returns 0:
--   select count(*) from pg_stat_activity
--    where pid <> pg_backend_pid() and xact_start is not null
--      and now() - xact_start > interval '2 seconds';
--
-- ORDER, DO NOT VARY IT:
--   1) THIS FILE (20261006_period_records.sql),
--   2) VERIFY THE GRANTS EXACTLY (verification 1 at the foot of this file),
--   3) 20261006b_delete_current_user_period_records.sql,
--   4) ONLY THEN `supabase functions deploy delete_account`.
-- WHY: THE `delete_account` EDGE FUNCTION NOW DELETES FROM THIS TABLE. DEPLOYED BEFORE THE TABLE
-- EXISTS, EVERY iOS ACCOUNT DELETION RETURNS 500 AFTER IT HAS ALREADY DELETED THE USER'S
-- ph_readings, daily_logs, cycle_settings, quiz_answers AND user_supplements ROWS, LEAVING THE
-- PROFILE AND THE AUTH USER IN PLACE.
--
-- RELATIVE TO THE LH FILES (20261005_lh_results.sql, 20261005b_delete_current_user_lh_results.sql)
-- This file does not depend on them and may be applied before or after 20261005_lh_results.sql.
-- BUT the edge function in this repo names BOTH `lh_results` and `period_records`, so it may be
-- deployed only once BOTH tables exist. The two `b` files may be applied in either order (see
-- the header of 20261006b). Recommended: 20261005, 20261005b, 20261006, 20261006b, then deploy.
--
-- ANDROID PARITY
-- The table name, the key, the column names and the `source` values are a contract from the
-- moment the Android app reads this table: do not rename or vary them. Android has no consent
-- gate yet and MUST NOT write this table until it has one. See ANDROID_PARITY.md, section 7.
--
-- Re-running creates nothing while the table's column set is unchanged: the table, every
-- constraint, the policy and the trigger are each created only if absent (`create table if not
-- exists` is a no-op), so no constraint, policy or trigger DDL is issued. It does re-issue
-- `enable row level security`, `revoke` and `grant`, which are idempotent, and it re-runs the
-- assertions. If the column set has changed, the assertion block aborts and rolls back by design,
-- having changed nothing.

begin;

set local lock_timeout = '5s';
-- lock_timeout is per lock wait and the policy statement takes about 23 locks in turn, so on its
-- own it does not bound the whole run. statement_timeout caps every statement.
set local statement_timeout = '15s';

-- 0. Precondition -------------------------------------------------------------------------------
do $$ begin
  if to_regprocedure('public.bump_updated_at()') is null then
    raise exception 'ABORT: public.bump_updated_at() is missing (20260712_sync_hardening.sql)';
  end if;
end $$;

-- 1. Table --------------------------------------------------------------------------------------
-- The primary key is declared inline, so it exists exactly when this statement created the
-- table; the assertion block checks it either way.
create table if not exists public.period_records (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  start_date date        not null,                 -- first day of the period; the key
  end_date   date,                                 -- last day of the period, inclusive; null = not recorded
  source     text        not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,                          -- tombstone: null = live
  constraint period_records_pkey primary key (user_id, start_date)
);

-- 2. Constraints --------------------------------------------------------------------------------
-- Added separately so re-running this file is safe on a table that already exists. All four
-- CHECKs are NULL-safe (a CHECK passes when it evaluates to NULL): `source` and `start_date` are
-- NOT NULL columns, and the nullable `end_date` is tested with an explicit `is null`.
-- `date` accepts 'infinity' and '-infinity'; a period on either is not a date she recorded, so
-- both are refused on both columns. `date` also accepts year 8 and year 2569 (the year a device
-- on the Buddhist calendar reports as today), so the last CHECK bounds both columns to a
-- plausible range.
do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.period_records'::regclass
                    and conname  = 'period_records_source_check') then
    alter table public.period_records
      add constraint period_records_source_check
      check (source in ('recorded', 'seeded'));
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.period_records'::regclass
                    and conname  = 'period_records_dates_finite') then
    alter table public.period_records
      add constraint period_records_dates_finite
      check (isfinite(start_date) and (end_date is null or isfinite(end_date)));
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.period_records'::regclass
                    and conname  = 'period_records_end_not_before_start') then
    -- Within one row only. Nothing here compares a row with its neighbours (see the header).
    alter table public.period_records
      add constraint period_records_end_not_before_start
      check (end_date is null or end_date >= start_date);
  end if;

  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.period_records'::regclass
                    and conname  = 'period_records_dates_in_range') then
    -- The server's clock, as for updated_at. Upper bound "+ 1": her local date can be one day
    -- ahead of the UTC date (UTC+14 at most), never two. `now() at time zone 'utc'`, not
    -- `current_date`, which follows the session TimeZone. Lower bound: no period of a living
    -- user predates 1900; it stops a year taken from a non-Gregorian device calendar.
    -- end_date needs no lower bound of its own (period_records_end_not_before_start).
    -- NULL-safe: start_date is NOT NULL and end_date has an explicit `is null` arm.
    -- now() is acceptable in a CHECK here because the upper bound only ever moves forward, so a
    -- row that was valid when written stays valid, which also keeps dump and restore safe.
    alter table public.period_records
      add constraint period_records_dates_in_range
      check (start_date >= date '1900-01-01'
         and start_date <= (now() at time zone 'utc')::date + 1
         and (end_date is null or end_date <= (now() at time zone 'utc')::date + 1));
  end if;
end $$;

-- 3. Index --------------------------------------------------------------------------------------
-- None beyond the primary key. The client read filters on user_id and orders by start_date,
-- which is the primary key's own index (user_id, start_date); the incremental pull adds a filter
-- on updated_at over one user's rows, a handful per year.

-- 4. Row level security and grants --------------------------------------------------------------
alter table public.period_records enable row level security;

-- Revoke first: Supabase default privileges hand anon and authenticated everything at CREATE
-- TABLE time, including TRUNCATE, which RLS cannot refuse. A bare grant is only additive.
revoke all on public.period_records from anon, authenticated;
grant  select, insert, update, delete on public.period_records to authenticated;
grant  all on public.period_records to service_role;

-- Owner-only, single ALL policy, the convention on every other table in this project, including
-- the `(select auth.uid())` form. Created only if absent: any policy DDL (even a bare create)
-- locks about 23 auth / storage / realtime tables until commit, so a re-run must issue none.
do $$ begin
  if not exists (select 1 from pg_policy
                  where polrelid = 'public.period_records'::regclass and polname = 'period_records_owner') then
    create policy period_records_owner on public.period_records
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
-- Created only if absent, so a re-run does not drop and re-create it (which would lock the table
-- for no reason). A same-named trigger of the wrong shape is not replaced: the assertion block
-- checks its type, state and function, and aborts.
do $$ begin
  if not exists (select 1 from pg_trigger
                  where tgrelid = 'public.period_records'::regclass and not tgisinternal
                    and tgname = 'period_records_bump_updated_at') then
    create trigger period_records_bump_updated_at before insert or update on public.period_records
      for each row execute function public.bump_updated_at();
  end if;
end $$;

-- 6. Pre-commit assertions: abort and roll back on any mismatch --------------------------------
do $chk$
declare
  v_rel  constant oid = 'public.period_records'::regclass::oid;
  v_n    int;
  v_text text;
  r      record;
begin
  -- Columns: exactly the seven named above, no more and no fewer.
  select string_agg(attname::text, ',' order by attname) into v_text
    from pg_attribute where attrelid = v_rel and attnum > 0 and not attisdropped;
  if v_text is distinct from 'created_at,deleted_at,end_date,source,start_date,updated_at,user_id' then
    raise exception 'ABORT: period_records columns are %', v_text;
  end if;

  -- NOT NULL exactly where declared.
  select string_agg(attname::text, ',' order by attname) into v_text
    from pg_attribute where attrelid = v_rel and attnum > 0 and not attisdropped and attnotnull;
  if v_text is distinct from 'created_at,source,start_date,updated_at,user_id' then
    raise exception 'ABORT: period_records NOT NULL columns are %', v_text;
  end if;

  -- Column types: the two dates are `date`, never a timestamp.
  select string_agg(a.attname::text || ':' || format_type(a.atttypid, a.atttypmod), ',' order by a.attname) into v_text
    from pg_attribute a where a.attrelid = v_rel and a.attnum > 0 and not a.attisdropped
     and a.attname in ('start_date', 'end_date', 'user_id', 'source');
  if v_text is distinct from 'end_date:date,source:text,start_date:date,user_id:uuid' then
    raise exception 'ABORT: period_records column types are %', v_text;
  end if;

  -- Primary key: exactly (user_id, start_date), in that order.
  select string_agg(a.attname::text, ',' order by k.ord) into v_text
    from pg_constraint c
    cross join lateral unnest(c.conkey) with ordinality as k(attnum, ord)
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
   where c.conrelid = v_rel and c.contype = 'p';
  if v_text is distinct from 'user_id,start_date' then
    raise exception 'ABORT: period_records primary key is (%)', v_text;
  end if;

  -- The four CHECK constraints, all validated, and no others.
  select count(*) into v_n from pg_constraint
   where conrelid = v_rel and contype = 'c' and convalidated
     and conname in ('period_records_source_check', 'period_records_dates_finite',
                     'period_records_end_not_before_start', 'period_records_dates_in_range');
  if v_n <> 4 then raise exception 'ABORT: % of 4 CHECK constraints present', v_n; end if;
  select count(*) into v_n from pg_constraint where conrelid = v_rel and contype = 'c';
  if v_n <> 4 then raise exception 'ABORT: % CHECK constraints on period_records, expected 4', v_n; end if;

  -- No exclusion or unique constraint: nothing may compare one row with another.
  select count(*) into v_n from pg_constraint where conrelid = v_rel and contype in ('x', 'u');
  if v_n <> 0 then raise exception 'ABORT: % cross-row constraint(s) on period_records', v_n; end if;

  -- user_id -> auth.users (id) ON DELETE CASCADE.
  select count(*) into v_n from pg_constraint
   where conrelid = v_rel and contype = 'f'
     and confrelid = 'auth.users'::regclass and confdeltype = 'c';
  if v_n <> 1 then raise exception 'ABORT: user_id cascade foreign key count is %', v_n; end if;

  -- RLS on, and exactly one policy: period_records_owner, FOR ALL, TO authenticated only.
  if not (select relrowsecurity from pg_class where oid = v_rel) then
    raise exception 'ABORT: row level security is not enabled';
  end if;
  select count(*) into v_n from pg_policy where polrelid = v_rel;
  if v_n <> 1 then raise exception 'ABORT: % policies on period_records, expected 1', v_n; end if;
  select polname, polcmd, polpermissive, polroles::regrole[]::text as roles,
         pg_get_expr(polqual, polrelid) as qual, pg_get_expr(polwithcheck, polrelid) as wcheck
    into r from pg_policy where polrelid = v_rel;
  if r.polname <> 'period_records_owner' or r.polcmd <> '*' or not r.polpermissive
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

  -- The delete_account edge function deletes from this table as service_role. Without DELETE it
  -- would return 500 after having erased the user's rows in other tables.
  if not has_table_privilege('service_role', v_rel, 'DELETE') then
    raise exception 'ABORT: service_role cannot delete from period_records';
  end if;

  -- The trigger: enabled, row-level, BEFORE INSERT OR UPDATE (tgtype 1 + 2 + 4 + 16 = 23).
  select count(*) into v_n from pg_trigger
   where tgrelid = v_rel and not tgisinternal and tgname = 'period_records_bump_updated_at'
     and tgtype = 23 and tgenabled = 'O'
     and tgfoid = 'public.bump_updated_at()'::regprocedure::oid;
  if v_n <> 1 then raise exception 'ABORT: period_records_bump_updated_at is missing or not BEFORE INSERT OR UPDATE'; end if;
end
$chk$;

commit;

-- ============================================================================
-- VERIFICATION: run after applying, with two throwaway accounts A and B.
--
--  1. Grants are EXACT, not merely sufficient:
--       select grantee, string_agg(privilege_type, ',' order by privilege_type) as privs
--         from information_schema.role_table_grants
--        where table_schema = 'public' and table_name = 'period_records'
--        group by grantee order by grantee;
--     expect exactly:
--       authenticated  DELETE,INSERT,SELECT,UPDATE   and nothing else
--       service_role   full (arwdDxtm)
--       anon           absent entirely
--     and the table ACL (select relacl from pg_class where oid = 'public.period_records'::regclass)
--     reads exactly:
--       {postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=arwd/postgres}
--     THE FAILURE TO LOOK FOR IS AN EXTRA PRIVILEGE, NOT A MISSING ONE. If TRUNCATE appears
--     against authenticated the revoke did not run: RLS cannot refuse TRUNCATE, so that one verb
--     empties the table for every user at once.
--
--  2. RLS isolation: as A insert a row; as B select it -> 0 rows; as B update it by key -> 0
--     rows affected; as B delete it by key -> 0 rows affected; as B insert a row carrying A's
--     user_id -> refused. A and B may each hold a row with the SAME start_date.
--
--  3. FK cascade: as service_role delete throwaway account A from auth.users, then
--       select count(*) from public.period_records where user_id = <A>;
--     expect 0.
--
--  4. Server time on INSERT: as A insert a row carrying updated_at = now() + interval '1 day',
--     read it back, and expect updated_at within a second of now(), not tomorrow. Update the
--     row with another future updated_at and expect the same.
--
--  5. CHECKs refuse what they should (each must fail): source 'manual'; source null;
--     end_date one day before start_date; start_date 'infinity'; start_date '-infinity';
--     end_date 'infinity'; start_date = UTC today + 2; start_date 1899-12-31; end_date = UTC
--     today + 2 (with a start_date of today). The bound is the UTC date, so compute "UTC today"
--     as (now() at time zone 'utc')::date, never current_date. And start_date = UTC today + 1
--     must SUCCEED (a user ahead of UTC), as must start_date 1900-01-01.
--
--  6. What the clients rely on (each must SUCCEED):
--       a. the same (user_id, start_date) inserted twice with ON CONFLICT (user_id, start_date)
--          DO UPDATE ends as one row;
--       b. an upsert that sets deleted_at, then one that sends deleted_at = null, leaves the row
--          live again;
--       c. an upsert that sends end_date = null clears a stored end_date;
--       d. two rows two days apart for one user (3 March and 5 March) are both accepted;
--       e. a row whose end_date is on or after the next row's start_date is accepted;
--       f. end_date equal to start_date (a one-day period) is accepted.
-- ============================================================================

-- ============================================================================
-- ROLLBACK (destroys every stored period record; `cycle_settings` is untouched, so predictions
-- are unaffected. Splice period_records back out of delete_current_user() and redeploy
-- delete_account without its period_records line FIRST):
--
--   drop table public.period_records;
-- ============================================================================
