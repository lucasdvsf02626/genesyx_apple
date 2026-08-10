-- Genesyx — move the onboarding quiz answers off the partner-readable profiles row.
--
-- Supersedes `20260810_profiles_quiz_answers.sql`, which added `profiles.quiz_answers` earlier the
-- same day. The audit that migration asked for came back badly:
--
--   profiles_select | SELECT | {authenticated} | ((id = auth.uid()) OR (id = current_partner_id()))
--
-- That is a bare row-level clause, and Postgres RLS filters rows, never columns — so a linked
-- partner reads the whole profile row, including what she said about her baby's sex on a screen
-- that promises the answer is "just for you". Narrowing the policy cannot fix it; only moving the
-- data can. `REVOKE SELECT (quiz_answers)` was considered and rejected: it blocks the owner's own
-- sync too, so the read path would need a SECURITY DEFINER view, and the data would still sit
-- physically inside a row the partner can select.
--
-- No backfill. `profiles.quiz_answers` is empty in production — the column landed today and has
-- never shipped in a TestFlight build — so this is a pure move while there is nothing to move.
-- That window closes the moment build 18 goes out.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. The table ---------------------------------------------------------------------------------
-- Same jsonb shape as before, keyed by question id: the questions are content and they move, so a
-- column per question would mean a migration every time the copy changes.

create table if not exists public.quiz_answers (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  answers    jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- 2. RLS — owner only, no partner clause -------------------------------------------------------
-- Safe to drop-and-recreate here, unlike on `profiles`: this table is new and owns exactly one
-- policy, so there is no partner-read policy alongside it to destroy.

alter table public.quiz_answers enable row level security;

drop policy if exists quiz_answers_owner on public.quiz_answers;
create policy quiz_answers_owner on public.quiz_answers
  for all to authenticated
  using      (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 3. Drop the old column — HOLD until the app change ships -------------------------------------
-- The shipped client still selects `profiles.quiz_answers`; dropping it first breaks profile sync
-- for anyone on an older build. Run this only once the release that reads `public.quiz_answers` is
-- the one in people's hands.
--
--   alter table public.profiles drop column if exists quiz_answers;

-- 4. Verify ------------------------------------------------------------------------------------
--   select column_name, data_type, is_nullable, column_default
--     from information_schema.columns
--    where table_schema = 'public' and table_name = 'quiz_answers';
--   -- Expect: user_id uuid NO, answers jsonb NO '{}'::jsonb, updated_at timestamptz NO now()
--
--   select policyname, cmd, roles, qual, with_check from pg_policies
--    where schemaname = 'public' and tablename = 'quiz_answers';
--   -- Expect exactly one row: quiz_answers_owner | ALL | {authenticated} | (user_id = auth.uid())
--   -- for BOTH qual and with_check. Any mention of a partner here is a bug.
--
--   -- Nothing left behind on the old column:
--   select count(*) from public.profiles where quiz_answers <> '{}'::jsonb;
--   -- Expect 0. If not, step 3 needs a backfill into public.quiz_answers first.
