// Withdraw an invite you sent. The INVITER cancelling — not the recipient refusing, which is
// `decline_partner_invite`.
//
// WHY THIS IS A FUNCTION AT ALL.
// This used to be a direct client UPDATE (`SupabaseBackend.swift:199`), which the inviter was
// entitled to make because `authenticated` held table-wide UPDATE on `partner_invites` and
// `partner_invites_owner` scoped it to her own rows. That grant is what
// `20260812_partner_invites_write_lockdown.sql` removes, and it has to be removed: a row-scoped
// policy says WHICH ROWS may be written, never WHICH COLUMNS or WHICH VALUES. While it stood, the
// inviter could PATCH `status` from 'declined' back to 'pending' — resurrecting an invite the
// recipient had explicitly refused — or push `expires_at` forward forever, defeating the TTL that
// `accept_partner_invite` enforces.
//
// A column grant could not have fixed it. `grant update (status)` still permits writing the VALUE
// 'pending'. Privileges express columns; they cannot express a state machine. So the client keeps
// INSERT and SELECT, loses UPDATE entirely, and every status transition now lands in one of three
// auditable service-role functions: accept, decline, revoke.
//
// Requires the invite to be PENDING. Revoking an already-declined invite would overwrite the
// recipient's refusal with the inviter's own record of events — the same invariant the lockdown
// exists to protect, reached from the other side. The UI only ever offers revoke on pending invites
// (`ProfileView.swift` filters `pending` before rendering the row), so this refuses nothing the app
// actually asks for.
//
// Takes `id`, not `code`: the inviter can see her own rows, so the id is the handle she already
// holds. (`decline` takes a code precisely because the recipient cannot see the row at all.)
//
// Writes ONLY `partner_invites.status`. Never touches either `partner_id` — withdrawing an invite
// that was never accepted has nothing to unlink.
import { serviceClient, requireUser, json, NotAuthenticated } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const { id } = await req.json();
    if (!id) return json({ ok: false, reason: "missing_id" }, 400);

    const db = serviceClient();

    const { data: invite, error: invErr } = await db
      .from("partner_invites")
      .select("id, inviter_id, status")
      .eq("id", id)
      .maybeSingle();
    // Detail stays server-side: it can carry schema information and the caller can do nothing
    // with it.
    if (invErr) {
      console.error("revoke_partner_invite: lookup failed —", invErr.message);
      return json({ ok: false, reason: "lookup_failed" }, 500);
    }
    if (!invite) return json({ ok: false, reason: "invite_not_found" }, 404);
    // Ownership, checked server-side now that RLS is no longer the thing standing between the
    // caller and this row — the service role bypasses RLS entirely.
    if (invite.inviter_id !== user.id) return json({ ok: false, reason: "not_your_invite" }, 403);
    if (invite.status !== "pending") return json({ ok: false, reason: "invite_not_pending" }, 409);

    const m = await db
      .from("partner_invites")
      .update({ status: "revoked" })
      .eq("id", invite.id);
    if (m.error) {
      console.error("revoke_partner_invite: update failed —", m.error.message);
      return json({ ok: false, reason: "update_failed" }, 500);
    }

    return json({ ok: true });
  } catch (e) {
    // `verify_jwt` is ON here — verified live 2026-08-13, correcting the 2026-08-12 probe this
    // comment used to report. The gateway does reject an absent or malformed token first, but a
    // token for a deleted user still reaches `requireUser` and fails there. Real 401 either way.
    if (e instanceof NotAuthenticated) return json({ ok: false, reason: "not_authenticated" }, 401);
    console.error("revoke_partner_invite: unhandled —", e);
    return json({ ok: false, reason: "unhandled" }, 500);
  }
});
