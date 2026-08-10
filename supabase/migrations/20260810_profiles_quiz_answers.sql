-- Genesyx — profiles.quiz_answers (client change list T8).
--
-- Onboarding asks her five questions and, until now, threw every answer away the moment the quiz
-- ended. Nothing could be personalised from them because nothing survived the next screen.
--
-- `jsonb`, keyed by question id with the chosen option id as the value, rather than a column per
-- question: the questions are content and they move (T7 rewrites the fourth one). A column per
-- question would mean a migration every time the copy changes, and a dead column every time one is
-- dropped.
--
-- `not null default '{}'` so every existing row is valid the moment this runs. The app writes the
-- key only when it has answers to write — an empty set on the device means "this install has
-- nothing to say about the quiz", not "she answered nothing", so omitting it stops a routine theme
-- change on a reinstalled phone from erasing what she answered before.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. The column --------------------------------------------------------------------------------

alter table public.profiles
  add column if not exists quiz_answers jsonb not null default '{}'::jsonb;

-- 2. RLS — confirm, do not recreate ------------------------------------------------------------
-- `profiles` already has RLS enabled, and it carries an extra partner-read policy alongside the
-- owner-only ones. A drop-and-recreate pass over the schema is exactly how that gets destroyed, so
-- this migration does not touch policies.
--
-- It does, however, put a new kind of answer in a partner-readable row. Run this after applying and
-- read what the partner policy actually exposes:
--
--   select policyname, cmd, qual from pg_policies
--    where schemaname = 'public' and tablename = 'profiles';
--
--   -- ⚠️ If the partner-read policy selects whole rows rather than named columns, her partner can
--   -- read `quiz_answers` — including what she said about her baby's sex, which the quiz itself
--   -- promises is "just for you". Narrow the policy (or move the column) before that ships.

-- 3. Verify ------------------------------------------------------------------------------------
--   select column_name, data_type, is_nullable, column_default
--     from information_schema.columns
--    where table_schema = 'public' and table_name = 'profiles'
--      and column_name = 'quiz_answers';
--   -- Expect: jsonb, NO, '{}'::jsonb
</content>
