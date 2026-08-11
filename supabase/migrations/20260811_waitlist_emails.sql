-- Genesyx — the waiting-list table and the one RPC that may write to it.
--
-- `SupabaseBackend.joinWaitlist` has called `join_waitlist` since the waitlist screen was wired to
-- the backend, and the comment above it describes this exact shape — but no migration in this repo
-- ever created either object. So the schema existed only in whatever was typed into the dashboard,
-- if it was typed at all. This file is that schema, written to be safe in both cases: every
-- statement is idempotent, so applying it against a project where the objects already exist is a
-- no-op, and against one where they don't it creates them.
--
-- Why an RPC rather than an insert policy. The write happens during onboarding, before there is an
-- account, so it runs under the anon key. A table that anon can insert into is a table anon can be
-- pointed at; and any select policy wide enough to be useful would make the list readable. RLS is
-- therefore on with **no policies at all** — PostgREST denies every direct read and write, for
-- every role — and the only door is a SECURITY DEFINER function that inserts one normalised row
-- and returns nothing.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. The table ---------------------------------------------------------------------------------
-- No `references auth.users`: the whole point is that she has no account yet. `email` carries the
-- unique constraint directly rather than a functional index, because the function below is the
-- only writer and it always normalises first — so the plain column is already the lowered form.

create table if not exists public.waitlist_emails (
  id         uuid primary key default gen_random_uuid(),
  email      text not null unique,
  created_at timestamptz not null default now()
);

-- 2. RLS — on, and deliberately empty ----------------------------------------------------------
-- Enabling RLS with zero policies is the lock, not an oversight. Anything added here later is a
-- hole: the table holds addresses of people who are not users and cannot consent to a read.

alter table public.waitlist_emails enable row level security;

-- 3. The only write path ------------------------------------------------------------------------
-- `set search_path = ''` is required, not stylistic: a SECURITY DEFINER function runs as its owner,
-- and without a pinned search_path a caller who can create objects can shadow an unqualified name
-- and have it executed with those rights. Every reference below is schema-qualified for that reason.
--
-- `returns void` and `on conflict do nothing` together mean a second submission of an address
-- already on the list is indistinguishable from the first. That is intentional: a caller who could
-- tell the difference could test addresses for membership one at a time.
--
-- The regex mirrors `EmailValidator.isValid` on the client. The client check is for her benefit —
-- it produces a useful message before a round trip. This one is the actual constraint, because the
-- RPC is reachable with the anon key and nothing obliges a caller to have gone through the app.

create or replace function public.join_waitlist(p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(p_email));
begin
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid email' using errcode = '22023';
  end if;

  insert into public.waitlist_emails (email)
  values (v_email)
  on conflict (email) do nothing;
end;
$$;

-- 4. Grants -------------------------------------------------------------------------------------
-- `public` is revoked first because CREATE FUNCTION grants EXECUTE to it by default, which would
-- otherwise leave the door open to roles nobody enumerated. `anon` is the one that matters — the
-- call happens pre-auth — and `authenticated` is granted too so the screen keeps working for
-- someone who signed in on another device and came back through onboarding.

revoke all on function public.join_waitlist(text) from public;
grant execute on function public.join_waitlist(text) to anon, authenticated;

-- 5. Verify -------------------------------------------------------------------------------------
--   select relrowsecurity from pg_class
--    where oid = 'public.waitlist_emails'::regclass;
--   -- Expect: t
--
--   select count(*) from pg_policies
--    where schemaname = 'public' and tablename = 'waitlist_emails';
--   -- Expect: 0. Any policy here is a hole — see step 2.
--
--   select prosecdef, proconfig from pg_proc
--    where oid = 'public.join_waitlist(text)'::regprocedure;
--   -- Expect: t | {search_path=""}
--
--   -- The door opens:
--   select public.join_waitlist('Test.Person@Example.com ');
--   select email from public.waitlist_emails where email = 'test.person@example.com';
--   -- Expect one row, lowercased and trimmed. Run it twice — still one row, no error.
--
--   -- The walls hold (run as anon, e.g. from the REST endpoint with the anon key):
--   --   GET  /rest/v1/waitlist_emails  → [] or permission denied, never the list
--   --   POST /rest/v1/waitlist_emails  → denied
--
--   delete from public.waitlist_emails where email = 'test.person@example.com';
