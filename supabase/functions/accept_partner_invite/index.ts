// Accept a partner invite by code, linking both profiles bidirectionally.
// Security: the invite must be pending and addressed to the caller's email (invitee_email).
// Uses the service role to write the reciprocal partner_id.
// Columns match docs/supabase_schema.sql (partner_invites: id, inviter_id, invitee_email,
// code, status). No expires_at / accepted_* columns — kept in step with the live schema.
import { serviceClient, requireUser, json } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const { code } = await req.json();
    if (!code) return json({ error: "Missing code" }, 400);

    const db = serviceClient();

    const { data: invite, error: invErr } = await db
      .from("partner_invites")
      .select("id, inviter_id, invitee_email, status")
      .eq("code", code)
      .maybeSingle();
    if (invErr) return json({ error: invErr.message }, 500);
    if (!invite) return json({ error: "Invite not found" }, 404);
    if (invite.status !== "pending") return json({ error: "Invite is not pending" }, 409);
    if (invite.inviter_id === user.id) return json({ error: "Cannot accept your own invite" }, 400);
    if (invite.invitee_email?.toLowerCase() !== user.email?.toLowerCase()) {
      return json({ error: "This invite was sent to a different email" }, 403);
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
    return json({ error: String(e) }, 401);
  }
});
