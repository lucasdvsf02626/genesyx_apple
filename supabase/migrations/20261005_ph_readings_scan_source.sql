-- Genesyx — pH reading provenance for camera-scanned readings.
--
-- WHY THIS EXISTS
-- The Scan Test feature reads a pH strip with the camera. A scanned reading is stored beside how it
-- was produced: its source and the scanner / strip-configuration that read it, plus the analyser's
-- confidence. Only the value and this metadata are stored; the image never leaves the phone.
--
-- ADDITIVE AND SAFE FOR OLDER APP BUILDS
-- Every column is nullable and `source` has NO default: null means a typed (manual) reading, which
-- is what every existing row and every older app build writes. Older builds never send these keys
-- and ignore them on read. Nothing existing changes.
--
-- WHEN TO APPLY
-- By hand in the Supabase dashboard → SQL Editor → paste → Run (no auto-push from this repo). It
-- MUST be applied BEFORE `FeatureFlags.scanTest` is ever enabled in a shipped build: a scanned
-- reading pushed to a database without these columns is rejected and stays queued on the phone.
-- Manual readings are unaffected either way (the app omits these keys for them).
--
-- ANDROID PARITY
-- ph_readings is shared with the Android app. Android must tolerate these columns when reading and
-- preserve them when it edits or re-upserts a row, or a scanned reading loses its provenance.
-- Android (and iOS builds older than this feature) edit a row in place without the scan columns, so
-- a value edit there leaves `camera_scan` on a typed value; the owner must decide on a server-side
-- rule or an Android change before the feature ships. Android's JSON decoding must be confirmed to
-- ignore unknown columns BEFORE this file is applied.
--
-- Fully idempotent — safe to run more than once.

-- 1. Columns ----------------------------------------------------------------------------------
alter table public.ph_readings add column if not exists source                    text;
alter table public.ph_readings add column if not exists scan_confidence           double precision;
alter table public.ph_readings add column if not exists scan_configuration_id     text;
alter table public.ph_readings add column if not exists scan_configuration_version text;
alter table public.ph_readings add column if not exists scanner_version           text;

-- 2. source domain (null = manual) ------------------------------------------------------------
alter table public.ph_readings drop constraint if exists ph_readings_source_check;
alter table public.ph_readings
  add constraint ph_readings_source_check
  check (source is null or source in ('manual', 'camera_scan'));

-- 3. confidence is a 0–1 fraction -------------------------------------------------------------
alter table public.ph_readings drop constraint if exists ph_readings_scan_confidence_range;
alter table public.ph_readings
  add constraint ph_readings_scan_confidence_range
  check (scan_confidence is null or (scan_confidence >= 0 and scan_confidence <= 1));

-- 4. scan_* columns exist exactly when the row is a camera scan ------------------------------
-- Holds in both directions and is NULL-safe: a manual row stores source as NULL, and a plain
-- `source = 'camera_scan' or (...)` would evaluate to NULL there, which a CHECK accepts.
alter table public.ph_readings drop constraint if exists ph_readings_scan_fields_require_scan;
alter table public.ph_readings
  add constraint ph_readings_scan_fields_require_scan
  check (
    (source is not distinct from 'camera_scan'
       and scan_confidence is not null and scan_configuration_id is not null
       and scan_configuration_version is not null and scanner_version is not null)
    or
    (source is distinct from 'camera_scan'
       and scan_confidence is null and scan_configuration_id is null
       and scan_configuration_version is null and scanner_version is null)
  );

-- 5. Verify -----------------------------------------------------------------------------------
--   select column_name, data_type, is_nullable from information_schema.columns
--    where table_schema = 'public' and table_name = 'ph_readings'
--      and column_name in ('source','scan_confidence','scan_configuration_id',
--                          'scan_configuration_version','scanner_version');
--   -- Expect 5 rows, all nullable.
