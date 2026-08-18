-- Genesyx — UK GDPR Article 9 explicit consent for special-category (health) data.
--
-- Everything this app exists to record — cycle dates, pH readings, sexual activity, pregnancy
-- intent — is special-category data under Article 9. Processing it needs an Article 9(2) condition,
-- and the only one available to a consumer wellness app is 9(2)(a): explicit consent. Article 7(1)
-- then puts the burden of proof on the controller ("shall be able to demonstrate that the data
-- subject has consented"), which is what this table is for. Genesyx Ltd is that controller.
--
-- WHY AN EVENT LOG AND NOT TWO COLUMNS ON `profiles`.
-- Current state alone cannot answer the question that actually gets asked in a complaint: what was
-- she told, and when, at the moment the data was collected. Consent is versioned because the wording
-- can change, and a grant against v1 is not a grant against v2 — so re-consent has to be visible as
-- a second grant, not an overwrite. Withdrawal (Article 7(3)) has to be visible too, and it does not
-- erase the earlier grant: processing that already happened was lawful, and the record of why it was
-- lawful must survive. Two columns cannot hold that; an append-only log can.
--
-- It also could not live on `profiles` in any case. `profiles_select` is
-- `using (id = auth.uid() or id = current_partner_id())`, and RLS filters rows and never columns —
-- the same trap that moved the quiz answers out on 10 Aug (`20260810_quiz_answers_owner_table.sql`).
-- A linked partner would read her consent history.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. The table ---------------------------------------------------------------------------------
-- One row per event, never updated. `version` is the consent-copy version she was shown, stored as
-- text rather than an integer so it can carry a date (`2026-08-18.v1`) and stay readable in an audit
-- years later, when whoever is reading it has no access to the build that produced it.

create table if not exists public.consent_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  version     text not null,
  action      text not null check (action in ('granted', 'withdrawn')),
  occurred_at timestamptz not null default now()
);

-- Current state is "her latest event", so that lookup is the one that must stay fast.
create index if not exists consent_events_user_time
  on public.consent_events (user_id, occurred_at desc);

-- 2. RLS — owner may read and append, and NOTHING may rewrite ----------------------------------
-- Deliberately not `for all`. Every other owner-scoped table in this schema uses one ALL policy,
-- and copying that here would be wrong: ALL grants UPDATE and DELETE, and an audit trail the
-- subject can edit is not evidence of anything. Withdrawal is expressed by appending a 'withdrawn'
-- row, so nothing in the product needs UPDATE or DELETE, and the absence of those policies is what
-- makes the log trustworthy.
--
-- No policy is needed for `delete_account`: it runs as the service role, which bypasses RLS, and the
-- `on delete cascade` above sweeps these rows with the auth user regardless. Erasure still works.

alter table public.consent_events enable row level security;

drop policy if exists consent_events_owner_read on public.consent_events;
create policy consent_events_owner_read on public.consent_events
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists consent_events_owner_append on public.consent_events;
create policy consent_events_owner_append on public.consent_events
  for insert to authenticated
  with check (user_id = auth.uid());

-- 3. Verify ------------------------------------------------------------------------------------
--   select column_name, data_type, is_nullable from information_schema.columns
--    where table_schema = 'public' and table_name = 'consent_events';
--   -- Expect: id uuid NO, user_id uuid NO, version text NO, action text NO, occurred_at timestamptz NO
--
--   select policyname, cmd, roles, qual, with_check from pg_policies
--    where schemaname = 'public' and tablename = 'consent_events';
--   -- Expect EXACTLY two rows: consent_events_owner_read (SELECT) and
--   -- consent_events_owner_append (INSERT). ⚠️ An ALL, UPDATE or DELETE policy here is a defect —
--   -- it would let the data subject rewrite the record that proves what she was told.
--   -- ⚠️ Any mention of partner_id is a privacy defect, as it is on daily_logs.
--
--   -- Latest state for one user, which is what the app reads:
--   select action, version, occurred_at from public.consent_events
--    where user_id = '<uuid>' order by occurred_at desc limit 1;
