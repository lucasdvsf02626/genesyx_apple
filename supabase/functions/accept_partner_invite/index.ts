// Accept a partner invite by code, linking both profiles bidirectionally.
// Requires the caller's email to match the invite's invitee_email and the invite to be pending
// and unexpired. Uses the service role to write the reciprocal partner_id. STUB — verify vs schema.
import { serviceClient, requireUser, json } from "../_shared/client.ts";

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
      .single();
    if (invErr || !invite) return json({ error: "Invite not found" }, 404);

    if (invite.status !== "pending") return json({ error: "Invite is not pending" }, 409);
    if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
      return json({ error: "Invite expired" }, 410);
    }
    if (!user.email_confirmed_at) return json({ error: "Verify your email first" }, 403);
    if (invite.invitee_email?.toLowerCase() !== user.email?.toLowerCase()) {
      return json({ error: "This invite was sent to a different email" }, 403);
    }

    // Link both profiles.
    await db.from("profiles").update({ partner_id: invite.inviter_id }).eq("id", user.id);
    await db.from("profiles").update({ partner_id: user.id }).eq("id", invite.inviter_id);
    await db.from("partner_invites")
      .update({ status: "accepted", accepted_by: user.id, accepted_at: new Date().toISOString() })
      .eq("id", invite.id);

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 401);
  }
});
