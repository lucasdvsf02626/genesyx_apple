-- Genesyx: explicit period_records backstop in public.delete_current_user().
--
-- STATUS: NOT APPLIED. Written 5 Oct 2026 as a file only; nothing in this repo has run it.
-- NO AGENT MAY APPLY THIS FILE. It goes through the database review gate and is then applied by
-- the owner, by hand in the Supabase dashboard SQL Editor. Never `supabase db push`.
-- Apply AFTER 20261006_period_records.sql (this file aborts if the table is missing).
--
-- ORDER, DO NOT VARY IT:
--   1) 20261006_period_records.sql,
--   2) VERIFY ITS GRANTS (verification 1 at the foot of that file),
--   3) THIS FILE,
--   4) ONLY THEN `supabase functions deploy delete_account`, and only if public.lh_results
--      exists too: the edge function in this repo deletes from BOTH tables.
-- WHY: THE `delete_account` EDGE FUNCTION NOW DELETES FROM public.period_records. DEPLOYED BEFORE
-- THE TABLE EXISTS, EVERY iOS ACCOUNT DELETION RETURNS 500 AFTER IT HAS ALREADY DELETED THE
-- USER'S ph_readings, daily_logs, cycle_settings, quiz_answers AND user_supplements ROWS, LEAVING
-- THE PROFILE AND THE AUTH USER IN PLACE.
--
-- Scope (exactly one change): add a defence-in-depth delete of public.period_records to the
-- deployed hardened delete_current_user() (the account-deletion path Android uses), immediately
-- before the profiles / auth.users block. `period_records.user_id` already cascades from
-- auth.users, but a cascade only fires if that LAST step succeeds; an explicit delete erases her
-- period records first.
--
-- A copy of 20261005b_delete_current_user_lh_results.sql: the deployed body is spliced in place
-- (pg_get_functiondef -> replace -> execute), never retyped, so every hardened block, the owner,
-- the ACL, SECURITY DEFINER and search_path = '' are preserved byte for byte.
-- delete_current_user() is never executed here.
--
-- The anchor is the live line `  delete from public.profiles where id = v_uid;` (two leading
-- spaces), which occurs exactly once; the backstop line is inserted directly above it.
--
-- COEXISTENCE WITH THE LH SPLICE (20261005b), IN EITHER ORDER
-- Both files insert one line directly above the same anchor and neither removes, moves or
-- matches the other's line, so each works whether or not the other has run:
--   LH first, then this file:  ... user_supplements / lh_results / period_records / profiles ...
--   this file first, then LH:  ... user_supplements / period_records / lh_results / profiles ...
-- The order of those two deletes does not matter (neither table references the other). This file
-- therefore asserts only that its own line is present once and sits before the profiles line,
-- not that it is the line directly above it, and it enforces no md5 of the function body,
-- because the body legitimately differs between the two orders (the md5 for each order is quoted
-- under VERIFY below, as a verification aid only). What it does enforce, independently of the
-- order, is that the splice added exactly one line and changed nothing else: removing that line
-- from the new body must give the deployed body back byte for byte. For the same reason the md5
-- quoted as a verification aid in 20261005b is only right when that file runs before this one,
-- and the md5 check inside 20261005b's ROLLBACK aborts while this file's line is present: roll
-- this file back first.
--
-- Safe to run more than once: if the backstop line is already there exactly once the splice is
-- skipped and only the assertions run. Any other reference to period_records aborts.

begin;

set local lock_timeout = '5s';

-- Splice the period_records backstop into the EXACT deployed body
do $mig$
declare
  v_oid    oid;
  v_def    text;
  v_anchor constant text = '  delete from public.profiles where id = v_uid;';
  v_line   constant text = '  delete from public.period_records where user_id = v_uid;';
begin
  if to_regclass('public.period_records') is null then
    raise exception 'ABORT: apply 20261006_period_records.sql first';
  end if;
  v_oid = 'public.delete_current_user()'::regprocedure::oid;
  v_def = pg_get_functiondef(v_oid);
  if position('period_records' in v_def) > 0 then
    if (length(v_def) - length(replace(v_def, 'period_records', ''))) / length('period_records') = 1
       and position(v_line in v_def) > 0 then
      raise notice 'period_records backstop already present: nothing to splice';
      return;
    end if;
    raise exception 'ABORT: period_records already referenced in deployed function';
  end if;
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception 'ABORT: anchor line not found exactly once';
  end if;
  execute replace(v_def, v_anchor, v_line || E'\n' || v_anchor);
  if replace(pg_get_functiondef(v_oid), v_line || E'\n', '') is distinct from v_def then
    raise exception 'ABORT: the function differs from the deployed body by more than the one line';
  end if;
end
$mig$;

-- Pre-commit assertions: abort + rollback on any mismatch
do $chk$
declare
  v_oid  oid = 'public.delete_current_user()'::regprocedure::oid;
  v_def  text;
  v_line constant text = 'delete from public.period_records where user_id = v_uid;';
  v_next constant text = 'delete from public.profiles where id = v_uid;';
  v_n    int;
  r      record;
begin
  v_def = pg_get_functiondef(v_oid);
  v_n = (length(v_def) - length(replace(v_def, v_line, ''))) / length(v_line);
  if v_n <> 1 then raise exception 'ABORT: backstop present % times', v_n; end if;
  v_n = (length(v_def) - length(replace(v_def, v_next, ''))) / length(v_next);
  if v_n <> 1 then raise exception 'ABORT: profiles delete present % times', v_n; end if;
  if position(v_line in v_def) > position(v_next in v_def) then
    raise exception 'ABORT: backstop is not before the profile / auth user step';
  end if;

  select prosecdef, proconfig, proowner::regrole::text as fowner, proacl::text as facl
    into r from pg_proc where oid = v_oid;
  if not r.prosecdef then raise exception 'ABORT: SECURITY DEFINER lost'; end if;
  if coalesce(array_to_string(r.proconfig, ','), '') <> 'search_path=""' then
    raise exception 'ABORT: search_path changed: %', r.proconfig;
  end if;
  if r.fowner <> 'postgres' then raise exception 'ABORT: owner changed: %', r.fowner; end if;
  if r.facl is distinct from '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
    raise exception 'ABORT: EXECUTE ACL changed: %', r.facl;
  end if;
end
$chk$;

commit;

-- VERIFY (read-only), after applying:
--   select pg_get_functiondef('public.delete_current_user()'::regprocedure);
--   expect exactly one line `delete from public.period_records where user_id = v_uid;` above the
--   line `delete from public.profiles where id = v_uid;`, with at most the lh_results line
--   between them.
--   As a verification aid (NOT enforced by this file: the body depends on which `b` file ran
--   first), the expected md5(pg_get_functiondef('public.delete_current_user()'::regprocedure))
--   is, for the live body of 6 Oct 2026 (length 1240):
--     live today (neither b file applied)            d09c1fe407abbdbe913a8637c6b3543c
--     after 20261005b only                           ba38803259d0ce31bd5032b77ebeea6c
--     after 20261005b, then THIS file (recommended)  24ae356875e50464ed68705f2a43407d
--     after THIS file only                           a9f42f157d5830267b9b7233e1a9f87a
--     after THIS file, then 20261005b                4c495faec47a40dea7fc99eedbce9adb
--   A value that matches none of these means the deployed body is not the one these were
--   computed from; read the definition before going on.
--
-- ROLLBACK (reverse order: redeploy delete_account without its period_records line FIRST, then
-- this file's change, then drop public.period_records; dropping the table while the function
-- still names it makes every Android account deletion fail at run time). Removes exactly the one
-- line and nothing else (aborts on a second run, because the line is then absent):
--
--   begin;
--   set local lock_timeout = '5s';
--   do $rb$
--   declare
--     v_def  text := pg_get_functiondef('public.delete_current_user()'::regprocedure);
--     v_line constant text := E'  delete from public.period_records where user_id = v_uid;\n';
--   begin
--     if (length(v_def) - length(replace(v_def, v_line, ''))) / length(v_line) <> 1 then
--       raise exception 'ABORT: backstop line not found exactly once';
--     end if;
--     execute replace(v_def, v_line, '');
--     if position('period_records' in pg_get_functiondef('public.delete_current_user()'::regprocedure)) > 0 then
--       raise exception 'ABORT: period_records is still referenced';
--     end if;
--   end
--   $rb$;
--   commit;
