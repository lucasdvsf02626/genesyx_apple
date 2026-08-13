-- Genesyx — daily_logs.food_groups (client change list T26, meal logging).
--
-- The Nutrition screen has always told her what to eat this phase and never let her say she had.
-- This column closes that loop. It stores food-*group* tokens (`FoodGroup.rawValue`: vegetables,
-- fruit, starchyCarbs, protein, dairy, oilsAndFats), not foods and not nutrients — naming a group
-- makes no health claim, so nothing on that screen needs substantiating under the CAP Code, and
-- nothing needs the food database that lives in the deferred barcode work.
--
-- `text[] not null default '{}'` mirrors `symptoms` and `supplements`, which the client already
-- reads and writes as plain arrays. Same shape, same decoder, no new machinery.
--
-- Not an enum, and not a foreign key to a lookup table. The set of groups is client-side content;
-- pinning it in the database means a schema migration every time the vocabulary moves, and a row
-- the server rejects for carrying a token from a newer build — which under the drain rules is a
-- day of her log stepped over and never retried.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. The column --------------------------------------------------------------------------------

alter table public.daily_logs
  add column if not exists food_groups text[] not null default '{}';

-- 2. RLS — confirm, do not recreate ------------------------------------------------------------
-- daily_logs already has RLS enabled with owner-only policies (see 20260712_sync_hardening.sql and
-- 20260810_daily_logs_sexual_activity.sql, neither of which touches policies). This one does not
-- either. Run the check below after applying:
--
--   select policyname, cmd, qual from pg_policies
--    where schemaname = 'public' and tablename = 'daily_logs';
--   -- Expect owner-only: every `qual` resolves to auth.uid() = user_id.

-- 3. Verify ------------------------------------------------------------------------------------
--   select column_name, data_type, is_nullable, column_default
--     from information_schema.columns
--    where table_schema = 'public' and table_name = 'daily_logs'
--      and column_name in ('food_groups', 'symptoms', 'supplements')
--    order by column_name;
--   -- Expect food_groups to match symptoms/supplements: ARRAY, NO, '{}'::text[].
--   -- If symptoms is jsonb rather than text[] on this project, STOP and match it instead —
--   -- `DailyLogRow.foodGroups` decodes whichever the sibling columns already use.

-- 4. Until this is applied ---------------------------------------------------------------------
-- `DailyLogRow.foodGroups` is optional on decode, so the app keeps working: she can tick groups
-- all week, see them on the card, and sync none of them. No error, no warning. That is the same
-- silent-failure shape as the sexual_activity column, and it is on the build-18 pre-flight list
-- (docs/TESTFLIGHT_B18.md) for the same reason.
