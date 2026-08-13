-- Genesyx — let an invite be refused, and let it stop being redeemable.
--
-- TWO GAPS, BOTH IN THE SAME TABLE
--
-- 1. NO DECLINE. `status` allowed only ('pending','accepted','revoked'). Revoked is the *inviter*
--    withdrawing; there was no value for the *recipient* refusing. Worse, `partner_invites_owner`
--    is `using (inviter_id = auth.uid())`, so the invitee cannot even SELECT the invite addressed
--    to her. "Not now" in InviteView only dismissed the sheet — the invite stayed pending and stayed
--    redeemable by anyone the link was forwarded to.
--
-- 2. NO EXPIRY. No `expires_at`, no TTL, no cleanup. A code shared once works forever. An invite
--    sent to a work address, or into a group chat, or to an ex, is a permanent standing offer to
--    link accounts — and linking grants a read on the whole `profiles` row.
--
-- WHY DECLINE IS A FUNCTION AND NOT A POLICY
-- The obvious fix is an RLS policy letting the invitee read and update her own invite. That is the
-- wrong tool: a SELECT policy keyed on `invitee_email` would hand her `inviter_id` and every other
-- column of the row, which is a NEW read surface opened in order to close a write gap. The
-- `decline_partner_invite` Edge Function needs no policy at all — the service role bypasses RLS —
-- so the invitee gains exactly one verb and reads nothing. This is the same shape as
-- `accept_partner_invite`, and the same reasoning `20260810_profiles_partner_id_write_guard.sql`
-- gives for preferring a grant over a trigger: put the check where the privilege already is.
--
-- WHY EXISTING ROWS ARE LEFT IMMORTAL
-- `expires_at` is nullable with a default, NOT backfilled. Null means "never expires", so every
-- invite that exists today keeps working. Backfilling `created_at + 30 days` would retroactively
-- kill invites that are alive right now, including any a real user is mid-flow on — a data-loss
-- decision taken on a guess about how many there are. New invites carry the TTL from the moment
-- this runs; the legacy rows can be swept separately once someone has looked at them. That sweep is
-- deliberately NOT included here (see the commented query at the bottom).
--
-- FORWARD COMPATIBILITY — safe to apply before either client ships
-- iOS decodes status with `InviteStatus(rawValue:) ?? .pending` (RemoteModels.swift:171), so an
-- unrecognised 'declined' degrades to "pending" in the list rather than throwing. Confirm the
-- Android client does the same before applying; if it decodes strictly, apply this AFTER Android
-- ships a build that tolerates the new value, or it will crash on the invite list.
--
-- Idempotent. Apply: Supabase dashboard → SQL Editor → paste → Run. (No auto-push from this repo.)
--
-- APPLIED 2026-08-12 to project epltxklawpcxxbaleswg via `supabase db query --linked -f`, and
-- verified with the section 3 queries below. Recorded here because this project has NO
-- `supabase_migrations.schema_migrations` table — every migration has been run by hand, so nothing
-- else tracks what has landed. `supabase db push` would try to replay all of them; do not use it.
-- Pre-state at time of apply: constraint was ('pending','accepted','revoked'), no `expires_at`, and
-- the table held one row (status 'revoked'), so nothing live was at risk.

-- 1. Allow 'declined' -----------------------------------------------------------------------------
-- The constraint is inline in the original DDL, so Postgres auto-named it. Dropping by that
-- conventional name first makes the whole block re-runnable.
alter table public.partner_invites
    drop constraint if exists partner_invites_status_check;

alter table public.partner_invites
    add constraint partner_invites_status_check
    check (status in ('pending', 'accepted', 'revoked', 'declined'));

-- 2. Give new invites a life span ----------------------------------------------------------------
alter table public.partner_invites
    add column if not exists expires_at timestamptz;

alter table public.partner_invites
    alter column expires_at set default (now() + interval '30 days');

comment on column public.partner_invites.expires_at is
    'When this invite stops being redeemable. Null = never (legacy rows predating the TTL). '
    'Enforced in accept_partner_invite, not by a constraint — an expired invite must still be '
    'readable by its inviter so the app can show it as expired rather than silently dropping it.';

-- 3. Verification ---------------------------------------------------------------------------------
-- Run after the above. Expect: four allowed statuses, and expires_at present with a default.
--
-- select conname, pg_get_constraintdef(oid) as definition
--   from pg_constraint
--  where conrelid = 'public.partner_invites'::regclass and contype = 'c';
--
-- select column_name, data_type, is_nullable, column_default
--   from information_schema.columns
--  where table_schema = 'public' and table_name = 'partner_invites' and column_name = 'expires_at';

-- 4. NOT RUN — the legacy sweep, for later --------------------------------------------------------
-- Only after someone has looked at how many pending invites exist and how old they are. This gives
-- every immortal invite 30 days from the moment it is run, rather than killing them outright:
--
-- update public.partner_invites
--    set expires_at = now() + interval '30 days'
--  where status = 'pending' and expires_at is null;
