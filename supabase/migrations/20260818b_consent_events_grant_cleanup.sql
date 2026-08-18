-- Genesyx — bring `consent_events` under the same client-role cleanup as the other app tables.
--
-- WHY THIS FILE EXISTS AT ALL
-- 20260812_client_role_grant_cleanup.sql revoked `anon`'s grants on the six app tables that existed
-- on 12 August. `consent_events` was created six days later by 20260818_consent_events.sql and so
-- was never in that list — it inherits the default grant Supabase gives `anon` and `authenticated`
-- on new tables in `public`. Nothing was done wrong; the hardening simply predates the table.
--
-- HOW IT WAS NOTICED, AND WHAT THE EVIDENCE ACTUALLY IS
-- Probed over PostgREST on 18 August with the published anon key, status codes only, no rows read:
--
--   consent_events  -> 200   (exists, exposed, and `anon` holds a table grant)
--   profiles        -> 401   (exists; `anon` holds nothing, so PostgREST maps 42501 to 401)
--   partner_invites -> 401   (same)
--   a name with no relation behind it -> 404
--
-- That is weaker evidence than the ACL dump in the 12 August file, and deliberately so: this repo
-- has no service-role credential and `pg_class.relacl` cannot be read without one. The 200/401 split
-- is an inference about grants from PostgREST's error mapping, not a measurement of them. §1 is what
-- makes that acceptable — the preconditions assert the state this file depends on at apply time,
-- inside the transaction, where it can still refuse.
--
-- WHY IT IS NOT AN EXPOSURE TODAY, AND WHY IT IS STILL WORTH CLOSING
-- Both policies on the table are `TO authenticated` and owner-scoped, so `auth.uid()` is null for an
-- unauthenticated caller and no row matches. The 200 is an empty array. What the grant costs is
-- depth: RLS becomes the only thing between a published key and a table of Article 9 consent
-- records, and TRUNCATE is not subject to RLS at all. That single-point-of-failure posture is the
-- exact thing the 12 August migration was written to remove, and the argument there applies here
-- with more force, not less — the anon key ships inside the app binary by design.
--
-- WHAT THIS FILE DELIBERATELY DOES NOT DO
-- It does not touch `authenticated`'s UPDATE or DELETE on this table, even though the append-only
-- design means neither should ever be exercised. See §4 — that is a real tightening, but it is a
-- different decision from this one and it should not ride in on its coat-tails.
--
-- Idempotent: REVOKE is declarative and safe to re-run.
-- Apply: paste this file into the Supabase Dashboard SQL Editor and run it.
-- Do NOT use `supabase db push` — this project has no supabase_migrations.schema_migrations table;
-- every migration here has been applied by hand and push would replay all of them.

begin;

-- 1. Preconditions --------------------------------------------------------------------------------
-- Two claims hold this file up, and both are asserted rather than trusted.
--
-- The first is "no policy grants `anon` anything", same as the 12 August file: a policy added
-- between the audit and the apply must stop this migration instead of silently locking out a role
-- something had come to depend on.
--
-- The second is "RLS is enabled". If it were not, the sentence above — that this changes no
-- behaviour because RLS already refuses `anon` every row — would be false. An unauthenticated caller
-- would have been reading the whole consent log, the 200 seen on 18 August would not have been an
-- empty array, and this file would be responding to an incident rather than tidying up depth. That
-- deserves someone's attention before a REVOKE quietly papers over it, so it raises.
do $$
declare
  anon_policies int;
  rls_on boolean;
begin
  if to_regclass('public.consent_events') is null then
    raise exception 'missing table public.consent_events; wrong database, or 20260818_consent_events.sql was never applied';
  end if;

  select relrowsecurity into rls_on
    from pg_class where oid = 'public.consent_events'::regclass;

  if not rls_on then
    raise exception
      'RLS is DISABLED on consent_events — anon has been able to read the consent log. Investigate before revoking';
  end if;

  select count(*)
    into anon_policies
    from pg_policies
   where schemaname = 'public'
     and tablename = 'consent_events'
     and ('anon' = any(roles) or 'public' = any(roles));

  if anon_policies > 0 then
    raise exception
      'a policy on consent_events names anon or PUBLIC; revoking anon''s grants would change behaviour';
  end if;
end $$;

-- 2. `anon` keeps nothing ---------------------------------------------------------------------------
-- Not a behaviour change: no client path reaches this table without a session. `SupabaseConsent`
-- inserts on grant and on withdraw, and `AppContainer` refreshes the trail on sign-in — every one of
-- those runs as `authenticated` and none is touched here.
revoke all on public.consent_events from anon;

-- 3. `authenticated` keeps no TRUNCATE ---------------------------------------------------------------
-- Its other privileges are untouched. PostgREST has no TRUNCATE verb, so no HTTP client could ask
-- for one — but RLS could not have refused it either, and on an append-only audit trail the verb
-- that empties the table in one statement is the one worth removing on principle.
revoke truncate on public.consent_events from authenticated;

-- `service_role` is untouched. It bypasses RLS and holds its own grant, which is how `delete_account`
-- erases a user's consent rows under Article 17. Narrowing it here would break account deletion.

commit;

-- 4. HELD — a decision this file will not make for you -----------------------------------------------
--
-- 4A. Should `authenticated` lose UPDATE and DELETE on consent_events?
--     On the design, yes. 20260818_consent_events.sql deliberately declined to write one `for all`
--     policy precisely because ALL would carry UPDATE and DELETE, and an audit trail whose subject
--     can rewrite it is not an audit trail. The table-level grants are the same hole by another
--     route: RLS has no UPDATE or DELETE policy, so both verbs are already refused every row, and
--     the grants sit there unreachable — the same "unreachable grant" this file's §2 removes for
--     `anon`.
--
--     It is held back anyway, for one reason: unlike §2 and §3, it cannot be shown to be inert from
--     this repo alone. Android shares this database and is not here, and the erasure path has not
--     been traced end to end against the live function. If some client does issue a direct DELETE,
--     this revoke turns a working delete into a 403. Answering it needs the same Android sweep that
--     20260812 §4B is already waiting on. Group it with that one rather than guessing here.
--
--     When it is answered, it is one statement:
--       revoke update, delete on public.consent_events from authenticated;

-- 5. Verification ------------------------------------------------------------------------------------
-- Run after the above.
--
-- V1. Table ACL. Expect NO anon row, and `authenticated` with `D` (TRUNCATE) gone and nothing else
--     removed. postgres and service_role unchanged.
--
-- select coalesce(nullif(split_part(s.acl, '=', 1), ''), 'PUBLIC') as grantee,
--        split_part(split_part(s.acl, '=', 2), '/', 1)             as privs
--   from pg_class c
--   cross join lateral (select unnest(c.relacl)::text as acl) s
--  where c.oid = 'public.consent_events'::regclass
--  order by 1;
--
-- V2. No anon privilege survives at COLUMN level. Expect ZERO rows. A table-level REVOKE does not
--     reach into column-level grants — they live in pg_attribute.attacl, which §2 never touches.
--
-- select a.attname, a.attacl::text
--   from pg_attribute a
--  where a.attrelid = 'public.consent_events'::regclass
--    and a.attnum > 0 and not a.attisdropped
--    and a.attacl::text like '%anon=%'
--  order by 1;
--
-- V3. Policies untouched — expect exactly two rows, consent_events_owner_read (SELECT) and
--     consent_events_owner_append (INSERT), both {authenticated}. An ALL, UPDATE or DELETE policy
--     appearing here is a defect regardless of this file.
--
-- select policyname, cmd, roles::text from pg_policies
--  where schemaname = 'public' and tablename = 'consent_events' order by 1;
--
-- V4. Then prove it over the API, which the catalog cannot do. With the published anon key:
--       GET {SUPABASE_URL}/rest/v1/consent_events?select=id&limit=0
--     Expect 401, matching profiles and partner_invites. It read 200 before this file.
--
-- V5. And prove the app is unharmed, signed in on a device: agree to consent on a fresh account,
--     withdraw it in Profile, turn it back on. Three rows, none overwritten. All three run as
--     `authenticated` and nothing above narrows that role's INSERT or SELECT.
