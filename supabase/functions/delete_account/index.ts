// Permanently delete the caller's account and all their data.
// REQUIRED by App Store Guideline 5.1.1(v) once the app has accounts. STUB — verify table list.
import { serviceClient, requireUser, json } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const db = serviceClient();
    const uid = user.id;

    // Unlink any partner first so we don't leave dangling references.
    const { data: me } = await db.from("profiles").select("partner_id").eq("id", uid).single();
    if (me?.partner_id) {
      await db.from("profiles").update({ partner_id: null }).eq("id", me.partner_id);
    }

    // Delete owned rows (extend this list as the schema grows).
    await db.from("ph_readings").delete().eq("user_id", uid);
    await db.from("daily_logs").delete().eq("user_id", uid);
    await db.from("cycle_settings").delete().eq("user_id", uid);
    await db.from("partner_invites").delete().eq("inviter_id", uid);
    await db.from("profiles").delete().eq("id", uid);

    // Finally delete the auth user (admin).
    const { error } = await db.auth.admin.deleteUser(uid);
    if (error) return json({ error: error.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 401);
  }
});
