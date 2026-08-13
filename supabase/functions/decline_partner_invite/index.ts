// Decline a partner invite by code. The recipient refusing — not the inviter withdrawing, which is
// `revoke_partner_invite`. (That was a direct client UPDATE until
// `20260812_partner_invites_write_lockdown.sql` took UPDATE away from `authenticated`; the row-scoped
// policy could not stop the row owner writing `status` back to 'pending' and undoing the decline
// this function performs.)
//
// Security: identical checks to accept_partner_invite — the invite must be pending and addressed to
// the caller's email — because declining an invite that is not yours is itself an action on someone
// else's row. Closing an invite you were never sent would let a stranger who guessed a code cancel
// a real link before the right person ever saw it.
//
// WHY THIS IS A FUNCTION AND NOT AN RLS POLICY.
// `partner_invites_owner` is `using (inviter_id = auth.uid())`, so the invitee cannot see her own
// invite. The obvious fix — a SELECT/UPDATE policy keyed on `invitee_email` — opens a new READ
// surface (she would gain `inviter_id` and every other column) in order to close a WRITE gap, and
// the read is the more sensitive half. Here the service role bypasses RLS entirely, so she gains
// exactly one verb and reads nothing. No policy change ships with this.
//
// This function writes ONLY `partner_invites.status`. It never touches either `partner_id` —
// declining is not unlinking, and there is nothing to unlink.
import { serviceClient, requireUser, json, NotAuthenticated } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const { code } = await req.json();
    if (!code) return json({ error: "Missing code" }, 400);

    const db = serviceClient();

    const { data: invite, error: invErr } = await db
      .from("partner_invites")
      .select("id, invitee_email, status")
      .eq("code", code)
      .maybeSingle();
    if (invErr) return json({ error: invErr.message }, 500);
    if (!invite) return json({ error: "Invite not found" }, 404);
    // Already accepted, revoked, or declined — nothing pending to refuse. Deliberately the same 409
    // wording accept uses, so a client cannot tell the two states apart by the message.
    if (invite.status !== "pending") return json({ error: "Invite is not pending" }, 409);
    if (invite.invitee_email?.toLowerCase() !== user.email?.toLowerCase()) {
      return json({ error: "This invite was sent to a different email" }, 403);
    }

    const m = await db
      .from("partner_invites")
      .update({ status: "declined" })
      .eq("id", invite.id);
    if (m.error) return json({ error: m.error.message }, 500);

    return json({ ok: true });
  } catch (e) {
    if (e instanceof NotAuthenticated) return json({ error: "Not authenticated" }, 401);
    // Was `String(e)` at 401 for everything. A malformed body or a database outage is not an auth
    // problem, and the raw text can carry schema detail the caller has no business seeing.
    console.error("decline_partner_invite: unhandled —", e);
    return json({ error: "Something went wrong" }, 500);
  }
});
