-- Genesyx — pH conditional value-range constraint (vaginal migration).
--
-- WHY THIS EXISTS
-- The vaginal-pH migration was applied to the LIVE genesyx project on 22 Jul 2026 directly in the
-- dashboard (measurement_type column + its domain check), but the change was never committed as a
-- migration. Meanwhile ph_readings still carried the old *unconditional* ph_value CHECK (4.5–9.0),
-- which is wrong for vaginal readings (valid 3.8–7.0). This migration captures the production reality
-- in version control so a future `db push` / rebuild reproduces it instead of drifting back to the
-- old single-range rule.
--
-- Fully idempotent — safe to run against the live DB (which already has all of this) or a fresh one.
-- Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)

-- 1. measurement_type column ------------------------------------------------------------------
-- Present in production since 22 Jul 2026; declared here for parity. Legacy rows keep 'urine';
-- new rows are written 'vaginal' by the app.
alter table public.ph_readings
  add column if not exists measurement_type text not null default 'urine';

-- 2. measurement_type domain check (matches the live `ph_measurement_type_check`) --------------
alter table public.ph_readings drop constraint if exists ph_measurement_type_check;
alter table public.ph_readings
  add constraint ph_measurement_type_check
  check (measurement_type in ('urine', 'vaginal'));

-- 3. Drop the stale unconditional ph_value CHECK, whatever it was named ------------------------
-- The old range lived under a name we can't assume (e.g. ph_readings_ph_value_check or ph_value_range).
-- This finds any CHECK on ph_readings that references ph_value but NOT measurement_type — i.e. the old
-- single-range one — and drops it. The new conditional constraint (added below) references
-- measurement_type, so it is skipped here, keeping this block idempotent on re-run.
do $$
declare c record;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_class     rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'ph_readings'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%ph_value%'
      and pg_get_constraintdef(con.oid) not ilike '%measurement_type%'
  loop
    execute format('alter table public.ph_readings drop constraint %I', c.conname);
  end loop;
end $$;

-- 4. The conditional value-range constraint ---------------------------------------------------
-- vaginal: 3.8–7.0 (app PhStatus.min/max). urine (legacy): 4.5–9.0 (old range; keeps existing
-- urine rows valid). Bounds inclusive to match the client clamp.
alter table public.ph_readings drop constraint if exists ph_value_range;
alter table public.ph_readings
  add constraint ph_value_range
  check (
    (measurement_type = 'vaginal' and ph_value >= 3.8 and ph_value <= 7.0)
    or
    (measurement_type = 'urine'   and ph_value >= 4.5 and ph_value <= 9.0)
  );

-- 5. Verify -----------------------------------------------------------------------------------
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--    where conrelid = 'public.ph_readings'::regclass and contype = 'c';
--   -- Expect exactly: ph_measurement_type_check + ph_value_range (conditional). No bare 4.5–9.0 check.
