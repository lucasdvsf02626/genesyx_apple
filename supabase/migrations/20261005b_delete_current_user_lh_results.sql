-- Genesyx: explicit lh_results backstop in public.delete_current_user().
--
-- STATUS: NOT APPLIED. Written 5 Oct 2026 as a file only; nothing in this repo has run it.
-- Apply AFTER 20261005_lh_results.sql (this file aborts if the table is missing), by hand in the
-- Supabase dashboard SQL Editor. Never `supabase db push`.
--
-- ORDER, DO NOT VARY IT:
--   1) CORRECTED 20261005_lh_results.sql,
--   2) VERIFY ITS GRANTS (verification 1 at the foot of that file),
--   3) THIS FILE,
--   4) ONLY THEN `supabase functions deploy delete_account`, AND ONLY WHEN BOTH public.lh_results
--      AND public.period_records EXIST (the latter is created by 20261006_period_records.sql):
--      the edge function in this repo deletes from BOTH tables.
-- WHY: THE `delete_account` EDGE FUNCTION NOW DELETES FROM public.lh_results. DEPLOYED BEFORE THE
-- TABLE EXISTS, EVERY iOS ACCOUNT DELETION RETURNS 500 AFTER IT HAS ALREADY DELETED THE USER'S
-- ph_readings, daily_logs, cycle_settings, quiz_answers AND user_supplements ROWS, LEAVING THE
-- PROFILE AND THE AUTH USER IN PLACE.
--
-- Scope (exactly one change): add a defence-in-depth delete of public.lh_results to the deployed
-- hardened delete_current_user() (the account-deletion path Android uses), immediately before
-- the profiles / auth.users block. `lh_results.user_id` already cascades from auth.users, but a
-- cascade only fires if that LAST step succeeds; an explicit delete erases her results first.
--
-- A copy of Change A of 20260813_user_supplements_delete_backstop_and_push_default_false.sql:
-- the deployed body is spliced in place (pg_get_functiondef -> replace -> execute), never
-- retyped, so every hardened block, the owner, the ACL, SECURITY DEFINER and search_path = ''
-- are preserved byte for byte. delete_current_user() is never executed here.
--
-- The anchor is a statement, not a comment: the deployed function body has no comments at all
-- (the comments in 20260813_delete_current_user_hardening.sql were not kept). The anchor is the
-- live line `  delete from public.profiles where id = v_uid;` (two leading spaces), which occurs
-- exactly once; the backstop line is inserted directly above it.
--
-- Safe to run more than once: if the backstop line is already there exactly once the splice is
-- skipped and only the assertions run. Any other reference to lh_results aborts.

begin;

set local lock_timeout = '5s';

-- Splice the lh_results backstop into the EXACT deployed body
do $mig$
declare
  v_oid    oid;
  v_def    text;
  v_anchor constant text = '  delete from public.profiles where id = v_uid;';
  v_line   constant text = '  delete from public.lh_results where user_id = v_uid;';
begin
  if to_regclass('public.lh_results') is null then
    raise exception 'ABORT: apply 20261005_lh_results.sql first';
  end if;
  v_oid = 'public.delete_current_user()'::regprocedure::oid;
  v_def = pg_get_functiondef(v_oid);
  if position('lh_results' in v_def) > 0 then
    if (length(v_def) - length(replace(v_def, 'lh_results', ''))) / length('lh_results') = 1
       and position(v_line in v_def) > 0 then
      raise notice 'lh_results backstop already present: nothing to splice';
      return;
    end if;
    raise exception 'ABORT: lh_results already referenced in deployed function';
  end if;
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception 'ABORT: anchor line not found exactly once';
  end if;
  execute replace(v_def, v_anchor, v_line || E'\n' || v_anchor);
end
$mig$;

-- Pre-commit assertions: abort + rollback on any mismatch
do $chk$
declare
  v_oid  oid = 'public.delete_current_user()'::regprocedure::oid;
  v_def  text;
  v_line constant text = 'delete from public.lh_results where user_id = v_uid;';
  v_next constant text = 'delete from public.profiles where id = v_uid;';
  v_n    int;
  r      record;
begin
  v_def = pg_get_functiondef(v_oid);
  v_n = (length(v_def) - length(replace(v_def, v_line, ''))) / length(v_line);
  if v_n <> 1 then raise exception 'ABORT: backstop present % times', v_n; end if;
  if position(v_next in v_def) = 0 or position(v_line in v_def) > position(v_next in v_def) then
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
--   expect one line `delete from public.lh_results where user_id = v_uid;` directly above the
--   line `delete from public.profiles where id = v_uid;`, beside the user_supplements line.
--   As a verification aid (not enforced by this file), the expected
--   md5(pg_get_functiondef('public.delete_current_user()'::regprocedure)) is
--     BEFORE  d09c1fe407abbdbe913a8637c6b3543c
--     AFTER   ba38803259d0ce31bd5032b77ebeea6c
--
-- ROLLBACK (reverse order: redeploy delete_account without its lh_results line FIRST, then this
-- file's change, then drop public.lh_results; dropping the table while the function still names
-- it makes every Android account deletion fail at run time). Restores the exact BEFORE bytes
-- (aborts on a second run, because the line is then absent):
--
--   begin;
--   set local lock_timeout = '5s';
--   do $rb$
--   declare
--     v_def  text := pg_get_functiondef('public.delete_current_user()'::regprocedure);
--     v_line constant text := E'  delete from public.lh_results where user_id = v_uid;\n';
--   begin
--     if (length(v_def) - length(replace(v_def, v_line, ''))) / length(v_line) <> 1 then
--       raise exception 'ABORT: backstop line not found exactly once';
--     end if;
--     execute replace(v_def, v_line, '');
--     if md5(pg_get_functiondef('public.delete_current_user()'::regprocedure)) <> 'd09c1fe407abbdbe913a8637c6b3543c' then
--       raise exception 'ABORT: function is not byte-identical to the pre-apply definition';
--     end if;
--   end
--   $rb$;
--   commit;
