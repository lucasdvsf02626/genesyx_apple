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

-- 1. Prior diagnosis ----------------------------------------------------------------------------
-- Audited 2026-08-10. All four roles (anon, authenticated, postgres, service_role) hold the full
-- stock Supabase table-level grant on `profiles` — RLS, not privilege, is what gates them today.
-- Both facts matter below: `anon` has UPDATE and so must be revoked too, and `service_role` holds
-- its grant table-wide and so is untouched by a revoke aimed at the client roles.
--
-- The one-directional-link sweep in §4 came back 0 rows, so this closes the hole ahead of any
-- exploitation rather than cleaning up after it.

-- 2. The guard ----------------------------------------------------------------------------------
-- The table-level revoke is not optional: Postgres ignores a column-level REVOKE while the role
-- still holds the privilege table-wide, so it has to come off first and go back on per column.
--
-- `anon` is revoked and granted nothing back. RLS already refused it — `profiles_update` is scoped
-- `TO authenticated` and `auth.uid()` is null for an anon caller — so this is defence in depth, not
-- a behaviour change, and no client path is affected: every profile write in the app calls
-- `requireUID` first and throws without a session.
--
-- `id` stays in the list because PostgREST emits the conflict-target column in the ON CONFLICT SET
-- clause. It grants nothing exploitable: `profiles_update` has no WITH CHECK, so Postgres reuses
-- `USING (id = auth.uid())` as the check and a row cannot be re-pointed at another user.

revoke update on public.profiles from authenticated, anon;

grant update (
  id, display_name, avatar_url, theme, created_at, updated_at,
  focus_mode, push_enabled, quiz_answers
) on public.profiles to authenticated;

-- `created_at` / `updated_at` are granted here only to hold today's behaviour exactly still while
-- one hole is closed. They should come off — a client can currently backdate its own account, and
-- the triggers already maintain `updated_at` — but that is a second change with a different blast
-- radius, and only the iOS client is in this repo to check. See §5.

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

-- 4. Existing bad links -------------------------------------------------------------------------
-- Not cleaned up by this migration, because there was nothing to clean: the sweep below returned
-- 0 rows on 2026-08-10. Re-run it if this is ever applied to another environment.
--
--   select a.id as claimer, a.partner_id as target
--     from public.profiles a
--     join public.profiles b on b.id = a.partner_id
--    where a.partner_id is not null and (b.partner_id is distinct from a.id);
--   -- Expect 0 rows. Anything here is a one-directional link that no invite created.

-- 5. HELD — take the timestamps off the client roles ---------------------------------------------
-- A column-level revoke works once §2 has run, since the privilege is no longer held table-wide:
--
--   revoke update (created_at, updated_at) on public.profiles from authenticated;
--
-- Safe with respect to the triggers: Postgres checks column UPDATE privileges against the columns
-- named in the statement's SET clause, not against columns a BEFORE trigger assigns to NEW. So
-- `set_updated_at()` and `bump_updated_at()` keep stamping `updated_at` for a caller who has no
-- privilege on it.
--
-- Held only because the clients cannot all be checked from this repo. iOS is clear — it writes
-- `profiles` in exactly two shapes, {id, focus_mode, theme, push_enabled} and {id, display_name},
-- and names no timestamp. Android and web are not in this repo. Note iOS *does* send `updated_at`
-- for `ph_readings` (see RemoteModels.swift), so the pattern exists in the codebase and the other
-- clients cannot be assumed clean by inspection of this one.
