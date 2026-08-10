-- Genesyx — daily_logs.sexual_activity (client change list T10 · T11).
--
-- A conception-prep app that cannot record when sex happened cannot tell her whether it fell in her
-- fertile window, which is the one question the whole cycle model exists to answer. The column is a
-- plain boolean, not protected/unprotected: contraception status is a different product.
--
-- `not null default false` so every existing row is valid the moment this runs, and so the app's
-- decoders never have to distinguish "she said no" from "she was never asked" — the log sheet
-- offers a single toggle, so that third state has nowhere to come from. Same collapse `water_ml = 0`
-- and an empty `symptoms` already make.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. The column --------------------------------------------------------------------------------

alter table public.daily_logs
  add column if not exists sexual_activity boolean not null default false;

-- 2. RLS — confirm, do not recreate ------------------------------------------------------------
-- daily_logs already has RLS enabled with owner-only policies (verified 2026-07-12, see
-- 20260712_sync_hardening.sql, which deliberately does not touch policies). This migration does not
-- either: `profiles` carries an extra partner-read policy, and a drop-and-recreate pass over the
-- schema is exactly how that kind of thing gets destroyed.
--
-- The check below is the one that matters for this column. A partner link is a row in `profiles`,
-- not a read grant — if a partner-visible policy ever appears on daily_logs, this column turns the
-- most private thing she records into something her partner can query. Run it after applying:
--
--   select policyname, cmd, qual from pg_policies
--    where schemaname = 'public' and tablename = 'daily_logs';
--   -- Expect owner-only: every `qual` resolves to auth.uid() = user_id.
--   -- ⚠️ Any policy referencing partner_id on this table is a privacy defect, not a feature.

-- 3. Verify ------------------------------------------------------------------------------------
--   select column_name, data_type, is_nullable, column_default
--     from information_schema.columns
--    where table_schema = 'public' and table_name = 'daily_logs'
--      and column_name = 'sexual_activity';
--   -- Expect: boolean, NO, false
