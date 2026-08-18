// Accept a partner invite by code, linking both profiles bidirectionally.
// Security: the invite must be pending, unexpired, and addressed to the caller's email.
// Uses the service role to write the reciprocal partner_id.
//
// THE LINK IS BIDIRECTIONAL, SO BOTH SIDES HAVE TO BE FREE.
// This function used to check only the invite, then write both rows unconditionally. If B was
// already linked to C and B accepted A's invite, both of B's and A's rows were overwritten — and
// C's row was never touched. C kept `partner_id = B`, which under `profiles_select`
// (`using (id = auth.uid() or id = public.current_partner_id())`) means C kept READ ACCESS to B's
// profile row after B had left. C is not a party to this request and never finds out. That is the
// gap the party check below closes.
//
// WHY `select("*")` AND NOT A COLUMN LIST.
// `expires_at` arrives with 20260812_partner_invite_hardening.sql. Naming it explicitly would make
// this function fail closed against a database where that migration has not run yet — PostgREST
// rejects the whole select with "column does not exist", which would break EVERY accept, not just
// expiry. A star select costs two unused columns on a single row we already hold the service role
// over, and in exchange the deploy order stops mattering. Undefined and null both mean "no expiry".
import { serviceClient, requireUser, json, NotAuthenticated } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const { code } = await req.json();
    if (!code) return json({ error: "Missing code" }, 400);

    const db = serviceClient();

    const { data: invite, error: invErr } = await db
      .from("partner_invites")
      .select("*")
      .eq("code", code)
      .maybeSingle();
    if (invErr) return json({ error: invErr.message }, 500);
    if (!invite) return json({ error: "Invite not found" }, 404);
    if (invite.status !== "pending") return json({ error: "Invite is not pending" }, 409);
    if (invite.inviter_id === user.id) return json({ error: "Cannot accept your own invite" }, 400);
    // Both sides must be PRESENT and equal. Optional chaining alone was not enough: an account with
    // no email (phone or anonymous auth) made this `undefined !== undefined`, which is false, so the
    // one check standing between a stranger and a partner link did not run at all. A missing email is
    // not a match — it is a reason to refuse.
    const inviteeEmail = invite.invitee_email?.trim().toLowerCase();
    const callerEmail = user.email?.trim().toLowerCase();
    if (!inviteeEmail || !callerEmail || inviteeEmail !== callerEmail) {
      return json({ error: "This invite was sent to a different email" }, 403);
    }
    if (invite.expires_at && new Date(invite.expires_at).getTime() < Date.now()) {
      return json({ error: "This invite has expired" }, 410);
    }

    // Both parties must be free — or already linked to each other.
    //
    // The second case is not just tidiness. It makes a re-tap idempotent (the invite sheet can be
    // re-presented from the same deep link), and it REPAIRS the dangling links this function used to
    // create: where one side points at the other and the other points nowhere, completing the pair
    // is the correct outcome, not an error.
    const { data: parties, error: partiesErr } = await db
      .from("profiles")
      .select("id, partner_id")
      .in("id", [user.id, invite.inviter_id]);
    if (partiesErr) return json({ error: partiesErr.message }, 500);

    const me = parties?.find((p) => p.id === user.id);
    const inviter = parties?.find((p) => p.id === invite.inviter_id);
    // A missing row must not be read as "free" — the update below would silently affect zero rows
    // and leave a one-directional link, which is the exact bug this block exists to prevent.
    if (!me || !inviter) return json({ error: "Profile not found" }, 500);

    if (me.partner_id && me.partner_id !== invite.inviter_id) {
      return json({ error: "You are already linked to a partner. Remove that link first." }, 409);
    }
    if (inviter.partner_id && inviter.partner_id !== user.id) {
      return json({ error: "This person is already linked to a partner." }, 409);
    }

    // Link both profiles.
    const a = await db.from("profiles").update({ partner_id: invite.inviter_id }).eq("id", user.id);
    if (a.error) return json({ error: a.error.message }, 500);
    const b = await db.from("profiles").update({ partner_id: user.id }).eq("id", invite.inviter_id);
    if (b.error) return json({ error: b.error.message }, 500);
    const m = await db.from("partner_invites").update({ status: "accepted" }).eq("id", invite.id);
    if (m.error) return json({ error: m.error.message }, 500);

    return json({ ok: true, partner_id: invite.inviter_id });
  } catch (e) {
    if (e instanceof NotAuthenticated) return json({ error: "Not authenticated" }, 401);
    // Was `String(e)` at 401 for everything, which reported a malformed body or a database outage
    // as an auth failure — sending the app to a sign-in screen that could not fix it.
    console.error("accept_partner_invite: unhandled —", e);
    return json({ error: "Something went wrong" }, 500);
  }
});
