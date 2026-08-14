-- Migration: 20260813_user_supplements_delete_backstop_and_push_default_false
-- Project:   epltxklawpcxxbaleswg (Genesyx production)
-- Applied:   2026-08-13 via dashboard SQL editor (single statement batch, one transaction)
--
-- Scope (exactly two changes, both reviewed and pre-authorized):
--   A. Add an explicit defence-in-depth delete of public.user_supplements to the
--      deployed hardened delete_current_user(), immediately before the
--      profiles/auth.users deletion block. The deployed body is spliced in place
--      (pg_get_functiondef -> replace -> execute), never retyped, so every
--      existing hardened block, the owner, the ACL, SECURITY DEFINER and
--      search_path='' are preserved byte-for-byte.
--   B. Change ONLY the DEFAULT of public.profiles.push_enabled to false.
--      Catalog-only; no existing row is updated.
--
-- The old Android draft (genesyx-android/docs/migrations/2026-07-29_user_supplements.sql)
-- is obsolete and was NOT applied. Nothing touches genesyx_products, pH data,
-- RLS, grants or foreign keys. delete_current_user() is never executed here.

begin;

-- Change A: splice user_supplements backstop into the EXACT deployed body
do $mig$
declare
  v_oid    oid = 'public.delete_current_user()'::regprocedure::oid;
  v_def    text;
  v_anchor constant text = '  -- 4. Profile, then the auth user last.';
  v_line   constant text = '  delete from public.user_supplements where user_id = v_uid;';
begin
  v_def = pg_get_functiondef(v_oid);
  if position('user_supplements' in v_def) > 0 then
    raise exception 'ABORT: user_supplements already referenced in deployed function';
  end if;
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception 'ABORT: anchor comment not found exactly once';
  end if;
  execute replace(v_def, v_anchor, v_line || E'\n\n' || v_anchor);
end
$mig$;

-- Change B: default only; no row updates
alter table public.profiles alter column push_enabled set default false;

-- Pre-commit assertions: abort + rollback on any mismatch
do $chk$
declare
  v_oid  oid = 'public.delete_current_user()'::regprocedure::oid;
  v_def  text;
  v_line constant text = 'delete from public.user_supplements where user_id = v_uid;';
  v_n    int;
  r      record;
  v_default text;
begin
  v_def = pg_get_functiondef(v_oid);
  v_n = (length(v_def) - length(replace(v_def, v_line, ''))) / length(v_line);
  if v_n <> 1 then raise exception 'ABORT: backstop present % times', v_n; end if;

  select prosecdef, proconfig, proowner::regrole::text as fowner, proacl::text as facl
    into r from pg_proc where oid = v_oid;
  if not r.prosecdef then raise exception 'ABORT: SECURITY DEFINER lost'; end if;
  if coalesce(array_to_string(r.proconfig, ','), '') <> 'search_path=""' then
    raise exception 'ABORT: search_path changed: %', r.proconfig;
  end if;
  if r.fowner <> 'postgres' then raise exception 'ABORT: owner changed: %', r.fowner; end if;
  if r.facl <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' then
    raise exception 'ABORT: EXECUTE ACL changed: %', r.facl;
  end if;

  select column_default into v_default from information_schema.columns
   where table_schema = 'public' and table_name = 'profiles' and column_name = 'push_enabled';
  if v_default <> 'false' then raise exception 'ABORT: push_enabled default is %', v_default; end if;
end
$chk$;

commit;
