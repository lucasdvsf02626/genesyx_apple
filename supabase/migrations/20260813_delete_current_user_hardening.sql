-- ============================================================================
-- A. CANONICAL ACCOUNT-DELETION RPC — public.delete_current_user()
--
-- ✅ APPLIED to production 13 Aug 2026. Idempotent — re-running is safe:
--      supabase db query --linked -f supabase/migrations/20260813_delete_current_user_hardening.sql
--
-- Verified after applying: prosecdef = true, proconfig = {search_path=}; anon and
-- PUBLIC cannot execute, authenticated can; the body contains the unlink, the
-- invitee-email delete, the waitlist delete and quiz_answers, and does NOT name
-- user_supplements. profiles.relforcerowsecurity and waitlist_emails.relforce-
-- rowsecurity are both FALSE, which clears the pre-apply risk flagged below: the
-- function owner does bypass RLS, so the unlink reaches rows it does not own.
--
-- STILL UNVERIFIED — the behavioural half (tests 2, 3 and 5) needs two throwaway
-- accounts and an actual deletion on a project holding real users. Not run.
--
-- WHY THIS EXISTS
-- Android deletes through this RPC; iOS deletes through the `delete_account`
-- Edge Function. Verified live on 13 Aug 2026, the deployed body erases six of
-- the seven tables and misses exactly the three things that have no foreign
-- key. This is not Section 4 partner work — it is shared account-deletion
-- hardening, and it applies to every client that calls this function.
--
-- WHAT WAS MISSING, AND WHY THE CASCADES DID NOT COVER IT
-- Six foreign keys exist, all `child -> auth.users(id) ON DELETE CASCADE`:
-- cycle_settings.user_id, daily_logs.user_id, partner_invites.inviter_id,
-- ph_readings.user_id, profiles.id, quiz_answers.user_id. So `delete from
-- auth.users` already sweeps quiz_answers and inviter-owned invites even though
-- the old body never named them. The gaps are the three columns with NO FK:
--
--   1. profiles.partner_id — `docs/supabase_schema.sql:21` declares
--      `references public.profiles (id) on delete set null`. That constraint
--      WAS NEVER DEPLOYED. `pg_constraint` on public.profiles returns only
--      profiles_pkey and profiles_id_fkey. So nothing nulls her partner's
--      pointer, and his row keeps a reference to a profile that no longer
--      exists — a "connected" state he cannot clear, because profiles_update
--      only lets him write his own row and the pointer is what is wrong.
--   2. partner_invites.invitee_email — free text, deliberately, because you can
--      invite someone who has no account yet. Nothing cascades it. She could
--      never delete these herself either: partner_invites_owner is
--      `inviter_id = auth.uid()`, so rows addressed TO her are invisible to her.
--   3. waitlist_emails.email — text key, no FK, survives forever.
--
-- DESIGN NOTES
-- * ATOMIC. A PostgREST RPC call runs in one transaction, so any exception
--   rolls the whole thing back. Nothing is reported deleted that was not
--   deleted, and a half-finished deletion cannot exist.
-- * RETRYABLE. Every statement is idempotent — deleting absent rows is a no-op
--   and the unlink is already-null-safe — so calling it twice is harmless and a
--   failed call can simply be repeated.
-- * auth.users LAST. It is the handle everything else hangs off, and while it
--   exists she is still deletable. If a later step fails, she can retry; if the
--   auth user went first, nobody could.
-- * search_path is PINNED TO EMPTY and every identifier is schema-qualified.
--   A SECURITY DEFINER function with a mutable search_path can be pointed at
--   attacker-controlled objects. Empty + fully qualified also closes the
--   `pg_temp` shadowing route, which `search_path = public` alone leaves open.
-- * DELIBERATELY DOES NOT NAME user_supplements. plpgsql resolves table names
--   at RUN time, not definition time, so naming a table that does not exist
--   creates the function happily and then aborts every call — which would break
--   account deletion outright. Migration B creates that table WITH
--   `on delete cascade`, so it needs no line here, ever. Apply order between A
--   and B does not matter, and that is on purpose.
--
-- ONE DELIBERATE SIDE EFFECT: deleting invites addressed to her removes another
-- user's pending invitation. That is correct — the row contains her email
-- address, erasure covers it, and the iOS path already makes the same trade.
--
-- ⚠️ PRE-APPLY CHECK: this relies on the function owner bypassing RLS on
-- profiles and waitlist_emails. Confirm `relforcerowsecurity = false` on both
-- (it is already confirmed false for waitlist_emails). If either FORCEs RLS,
-- the unlink silently affects zero rows — verification test 2 below catches it.
-- ============================================================================

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'no authenticated user' using errcode = '28000';
  end if;

  -- Her address, normalised once. `join_waitlist` stores `lower(btrim(...))`,
  -- and accept/decline match invitee_email case-insensitively, so this is the
  -- shape both comparisons below need.
  select lower(btrim(u.email)) into v_email
    from auth.users u
   where u.id = v_uid;

  -- 1. Reciprocal partner link, FIRST.
  -- `where partner_id = v_uid` catches every row pointing at her, which is
  -- strictly safer than reading her own partner_id and nulling that one row:
  -- it still works if the link was one-directional or already stale.
  update public.profiles
     set partner_id = null
   where partner_id = v_uid;

  -- 2. Rows she owns by id. All six are cascade-covered, but explicit deletes
  -- run BEFORE the auth-user step, so erasure still holds if that step fails.
  delete from public.ph_readings    where user_id = v_uid;
  delete from public.daily_logs     where user_id = v_uid;
  delete from public.cycle_settings where user_id = v_uid;
  delete from public.quiz_answers   where user_id = v_uid;
  delete from public.partner_invites where inviter_id = v_uid;

  -- 3. The email-keyed rows. No FK reaches these; without this block they
  -- outlive the account permanently.
  if v_email is not null and v_email <> '' then
    delete from public.partner_invites
     where lower(btrim(invitee_email)) = v_email;

    delete from public.waitlist_emails
     where lower(btrim(email)) = v_email;
  end if;

  -- 4. Profile, then the auth user last.
  delete from public.profiles where id = v_uid;
  delete from auth.users      where id = v_uid;
end;
$$;

revoke execute on function public.delete_current_user() from public, anon;
grant  execute on function public.delete_current_user() to authenticated;

-- ============================================================================
-- VERIFICATION — run after applying. Tests 2 and 3 are the ones that matter;
-- they are the two gaps this migration exists to close.
--
-- Use two throwaway accounts, A and B. Do NOT run against a real user.
--
--  0. Definition landed and is pinned:
--       select prosecdef, proconfig
--         from pg_proc where oid = 'public.delete_current_user()'::regprocedure;
--     expect prosecdef = true, proconfig = {search_path=}
--
--  1. Grants: anon and PUBLIC cannot execute, authenticated can:
--       select has_function_privilege('anon','public.delete_current_user()','EXECUTE'),
--              has_function_privilege('authenticated','public.delete_current_user()','EXECUTE'),
--              has_function_privilege('public','public.delete_current_user()','EXECUTE');
--     expect false, true, false
--
--  2. RECIPROCAL UNLINK. Link A and B, then delete A. As B:
--       select partner_id from public.profiles where id = <B>;
--     expect NULL. Before this migration it held A's now-dangling id.
--     If it still holds the old id, profiles is FORCEing RLS — see pre-apply.
--
--  3. EMAIL-KEYED ROWS. Before deleting A: have B send an invite TO A's
--     address, and put A's address on the waitlist. After deleting A:
--       select count(*) from public.partner_invites
--        where lower(btrim(invitee_email)) = lower('<A email>');
--       select count(*) from public.waitlist_emails
--        where lower(btrim(email)) = lower('<A email>');
--     expect 0 and 0. Both were non-zero before this migration.
--
--  4. Cascades still do their half — after deleting A, every one of these is 0:
--       ph_readings, daily_logs, cycle_settings, quiz_answers for A's user_id;
--       partner_invites for inviter_id = A; profiles for id = A;
--       auth.users for id = A.
--
--  5. RETRYABLE / IDEMPOTENT. Call it twice for the same session (the second
--     call happens after the auth user is gone, so auth.uid() is null and it
--     must raise 'no authenticated user' rather than corrupt anything). Then,
--     as a service-role query, re-run the deletes from step 4 — still 0.
--
--  6. BLAST-RADIUS GUARD. Confirm an unrelated user C is untouched:
--     C's profile, logs, readings and pending invites all still present, and
--     C.partner_id unchanged.
-- ============================================================================

-- ============================================================================
-- ROLLBACK
--
-- Safe and complete: this migration changes ONE function and no data or schema.
-- Restoring the previous body is the whole rollback. Note the old body leaves
-- the three gaps above, so roll back only to unblock, not as a resting state.
-- ============================================================================
--
-- create or replace function public.delete_current_user()
-- returns void language plpgsql security definer as $$
-- declare uid uuid := auth.uid();
-- begin
--   if uid is null then raise exception 'no authenticated user'; end if;
--   delete from public.ph_readings    where user_id = uid;
--   delete from public.daily_logs     where user_id = uid;
--   delete from public.cycle_settings where user_id = uid;
--   delete from public.profiles       where id      = uid;
--   delete from auth.users where id = uid;
-- end; $$;
-- revoke execute on function public.delete_current_user() from public, anon;
-- grant  execute on function public.delete_current_user() to authenticated;
