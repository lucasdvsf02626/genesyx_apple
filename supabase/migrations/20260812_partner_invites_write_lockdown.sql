-- Genesyx — stop the client writing partner_invites, so a decline cannot be undone.
--
-- THE HOLE
-- `partner_invites_owner` is cmd=ALL with qual and with_check both `(inviter_id = auth.uid())`.
-- That governs WHICH ROWS the inviter may write. It says nothing about WHICH COLUMNS, and nothing
-- at all about WHICH VALUES. Combined with a table-wide UPDATE grant to `authenticated`, the row
-- owner could:
--   (a) PATCH `status` from 'declined' back to 'pending', resurrecting an invite the recipient had
--       explicitly refused. This contradicts 20260812_partner_invite_hardening.sql, which states
--       the transition is irreversible, and the promise InviteView.swift makes to the recipient:
--       "The link stops working and they'll need to send a new one."
--   (b) push `expires_at` forward indefinitely, defeating the 30-day TTL that the same migration
--       added and that accept_partner_invite enforces (index.ts:41-42, returns 410).
--   (c) DELETE the row outright — destroying the decline record by a third route.
--
-- WHY NOT A COLUMN-LEVEL REVOKE
-- Postgres will not subtract a column from a table-level grant. `revoke update (status) ... `
-- against a role holding table-wide UPDATE succeeds, reports success, and changes nothing — the
-- table-level `w` still authorises writing every column. The table-level privilege must go first.
-- This repo already says so: 20260810_profiles_partner_id_write_guard.sql:35 —
--   "The table-level revoke is not optional: Postgres ignores a column-level REVOKE while the role
--    holds the privilege table-wide."
-- `information_schema.column_privileges` is what makes this easy to get wrong: it expands a
-- table-level grant into one row per column, so a blanket grant reads as though it were
-- column-scoped. Check `pg_class.relacl` and `pg_attribute.attacl` instead.
--
-- WHY NO NARROW `status` PATH
-- Re-granting `update (status)` to preserve the old client revoke would leave hole (a) wide open:
-- a column privilege constrains which columns may be written, never which values, so the client
-- could still write 'pending'. Privileges cannot express a state machine. Inviter-side revoke
-- therefore moves to an Edge Function, and the client keeps no UPDATE at all.
--
-- MEASURED BEFORE-STATE (2026-08-12, read-only, this project):
--   pg_class.relacl on partner_invites:
--     postgres=arwdDxtm | anon=arwdDxtm | authenticated=arwdDxtm | service_role=arwdDxtm
--   pg_attribute.attacl: NULL on every column — ZERO column-level grants exist, so no
--     column-level cleanup is required below.
--   For contrast, profiles (already guarded by the 20260810 migration) reads
--     authenticated=ardDxtm with 9 columns carrying their own ACL — no table-level `w`, exactly
--     the shape this migration produces.
--   Table held 1 row (status 'revoked'); 0 pending, 0 declined. Nothing live is at risk.
--
-- CLIENT CALL SITES (grepped before applying — `.from("partner_invites")` in App/ and Sources/):
--   SupabaseBackend.swift:161  SELECT  — unaffected, SELECT is retained
--   SupabaseBackend.swift:180  INSERT  — unaffected, INSERT is retained
--   SupabaseBackend.swift:199  UPDATE  — the only write; already moved to functions.invoke
--   No `.delete()` call site exists.
--
-- SCOPE — this file changes BEHAVIOUR, and is gated because of it
-- Revoking a reachable verb breaks any client still using it, and Android shares this database and
-- is not in this repo. Everything that could NOT change any client's behaviour — `anon`'s grants,
-- and TRUNCATE for `authenticated` — was split out into
-- `20260812_client_role_grant_cleanup.sql`, which is gated on nothing and can be applied today.
-- Keeping them here would have parked two free wins behind the Android sweep.
--
-- ORDER OF OPERATIONS — this migration goes LAST:
--   1. grep the Android client for UPDATE/DELETE on partner_invites — a direct PATCH there breaks
--      silently the moment this is applied
--   2. deploy revoke_partner_invite   3. ship SupabaseBackend.swift:199 change   4. apply this file
-- Applying this before step 2 breaks inviter-side revoke.
--
-- Idempotent: REVOKE is declarative and safe to re-run.
-- Apply: supabase db query --linked -f supabase/migrations/20260812_partner_invites_write_lockdown.sql
-- Do NOT use `supabase db push` — this project has no supabase_migrations.schema_migrations table;
-- every migration here has been applied by hand and push would replay all of them.

begin;

-- 1. Preconditions — fail loudly rather than half-apply -------------------------------------------
do $$
begin
  if to_regclass('public.partner_invites') is null then
    raise exception 'public.partner_invites does not exist; wrong database?';
  end if;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'public'
       and tablename  = 'partner_invites'
       and policyname = 'partner_invites_owner'
  ) then
    raise exception 'partner_invites_owner policy missing; refusing to change grants';
  end if;
end $$;

-- 2. Take UPDATE and row destruction away from `authenticated` ------------------------------------
-- UPDATE closes (a) and (b). DELETE closes (c). Both are verbs a client can actually emit, which is
-- exactly why this file is gated and the cleanup migration is not.
--
-- TRUNCATE — the third route to an empty table, and the one RLS never filtered — is handled in
-- `20260812_client_role_grant_cleanup.sql` along with `anon`'s grants on this table, because
-- neither is reachable from any HTTP client and neither needs to wait for Android.
revoke update, delete on public.partner_invites from authenticated;

-- 3. INSERT and SELECT for `authenticated` are deliberately UNCHANGED -----------------------------
-- Creating an invite (SupabaseBackend.swift:180) and listing her own (161) stay direct client
-- operations, still row-scoped by partner_invites_owner. `service_role` is untouched: it holds its
-- own table-level grant, which is how the Edge Functions still write.
--
-- Validating invite CREATION server-side is a separate decision and is NOT taken here.

commit;

-- 4. Verification ---------------------------------------------------------------------------------
-- Run after the above.
--
-- V1. Table ACLs for authenticated. Expect `w` (UPDATE) and `d` (DELETE) gone:
--       arwdDxtm -> arDxtm   if this migration ran alone
--       arwdDxtm -> arxtm    if 20260812_client_role_grant_cleanup.sql has also run (it removes
--                            the `D`, and removes anon's row entirely)
--     The two are independent and either order is fine. Both leave INSERT/SELECT/REFERENCES/
--     TRIGGER/MAINTAIN intact. service_role and postgres unchanged at arwdDxtm.
--
-- select coalesce(nullif(split_part(acl, '=', 1), ''), 'PUBLIC') as grantee,
--        split_part(split_part(acl, '=', 2), '/', 1)             as privs
--   from (select unnest(c.relacl)::text as acl
--           from pg_class c join pg_namespace n on n.oid = c.relnamespace
--          where n.nspname = 'public' and c.relname = 'partner_invites') s
--  order by 1;
--
-- V2. Nothing writable by authenticated at either level. Expect ZERO rows.
--     `information_schema.column_privileges` is used here deliberately, despite the warning at the
--     top of this file. That warning is about DIAGNOSIS — the view expands a table-level grant into
--     one row per column, so it makes a blanket grant look column-scoped. For VERIFICATION the same
--     property is exactly what is wanted: it reports a surviving table-level grant AND any
--     column-level residue, so zero rows here rules out both at once.
--
-- select privilege_type, column_name
--   from information_schema.column_privileges
--  where table_name = 'partner_invites' and grantee = 'authenticated'
--    and privilege_type in ('UPDATE', 'DELETE')
--  order by 1, 2;
--
-- V3. Policy untouched — still ALL, still qual = with_check.
--
-- select policyname, cmd, qual = with_check as qual_equals_check
--   from pg_policies where tablename = 'partner_invites';
--
-- V4. RLS still on; counts only, no invite PII.
--
-- select c.relrowsecurity as rls_enabled,
--        (select count(*) from public.partner_invites) as total_rows,
--        (select count(*) from public.partner_invites where status = 'pending')  as pending,
--        (select count(*) from public.partner_invites where status = 'declined') as declined
--   from pg_class c join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'public' and c.relname = 'partner_invites';
