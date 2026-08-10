-- Genesyx — stop a user declaring themselves someone else's partner.
--
-- THE HOLE
-- `profiles_select` reads ((id = auth.uid()) OR (id = current_partner_id())), and
-- `current_partner_id()` returns `partner_id` from the *caller's own* row. `profiles_update` allows
-- `id = auth.uid()` with no column restriction, and no trigger inspects `partner_id` (audited: both
-- BEFORE UPDATE triggers on `profiles` only bump `updated_at`). So any signed-in user can PATCH
-- their own row, set `partner_id` to any UUID they like, and immediately read that person's whole
-- profile row. The victim's own `partner_id` is never consulted, so she cannot observe or refuse it.
--
-- WHY A GRANT AND NOT A TRIGGER
-- Consent already exists and is already enforced — in the wrong place. `accept_partner_invite`
-- requires a pending invite whose `invitee_email` matches the caller's authenticated email, then
-- writes both rows with the service role. `unlink_partner` clears both the same way. The app never
-- writes `partner_id` itself: `SupabasePartner.accept`/`unlink` invoke those functions, and neither
-- profile upsert path names the column. So the legitimate writer is already service-role-only, and
-- the fix is simply to stop `authenticated` writing the column at all.
--
-- A BEFORE UPDATE trigger that raised on a `partner_id` change would have broken both functions:
-- the service role bypasses RLS, but nothing bypasses a trigger. Column privileges are the right
-- tool here precisely because `service_role` holds its own table-level grant and is unaffected.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. Diagnose before changing -------------------------------------------------------------------
-- Read these first. If `anon` appears with UPDATE, or `service_role` does NOT hold table-level
-- UPDATE, stop — the grant below assumes neither is true.
--
--   select grantee, privilege_type from information_schema.table_privileges
--    where table_schema = 'public' and table_name = 'profiles' order by grantee, privilege_type;
--
--   select grantee, column_name from information_schema.column_privileges
--    where table_schema = 'public' and table_name = 'profiles' and privilege_type = 'UPDATE'
--    order by grantee, column_name;

-- 2. The guard ----------------------------------------------------------------------------------
-- The table-level revoke is not optional: Postgres ignores a column-level REVOKE while the role
-- still holds the privilege table-wide, so it has to come off first and go back on per column.
--
-- Every column except `partner_id` is re-granted, deliberately. This migration closes one hole and
-- changes nothing else; tightening `created_at`/`updated_at` (the triggers own them) is a separate
-- question, not something to smuggle in here.

revoke update on public.profiles from authenticated;

grant update (
  id, display_name, avatar_url, theme, created_at, updated_at,
  focus_mode, push_enabled, quiz_answers
) on public.profiles to authenticated;

-- `quiz_answers` is in that list only because the column still exists. It is dropped by
-- `20260810_quiz_answers_owner_table.sql` step 3 once the client reading the new table has shipped;
-- dropping a column drops its grants, so nothing here needs revisiting afterwards.

-- 3. Verify -------------------------------------------------------------------------------------
--   select column_name from information_schema.column_privileges
--    where table_schema = 'public' and table_name = 'profiles'
--      and grantee = 'authenticated' and privilege_type = 'UPDATE'
--    order by column_name;
--   -- Expect every column EXCEPT partner_id.
--
-- Then prove it end to end, which the catalog cannot do. With a real user's JWT (not the service
-- key), against a UUID that is not hers:
--
--   PATCH /rest/v1/profiles?id=eq.<her-uid>   body: {"partner_id":"<any-other-uid>"}
--   -- Expect 403, SQLSTATE 42501 (permission denied for column partner_id).
--
-- And confirm the legitimate path still works: send an invite from one account, accept it from the
-- other in-app, and check both rows linked. That exercises the service role through
-- `accept_partner_invite`, which this migration must not have touched.

-- 4. Not fixed here -----------------------------------------------------------------------------
-- Existing bad links are not cleaned up by this. Any `partner_id` written before today by the route
-- above is still in place and still granting reads. To find pairs that were never mutual — the
-- signature of a self-declared link — run:
--
--   select a.id as claimer, a.partner_id as target
--     from public.profiles a
--     join public.profiles b on b.id = a.partner_id
--    where a.partner_id is not null and (b.partner_id is distinct from a.id);
--   -- Expect 0 rows. Anything here is a one-directional link that no invite created.
