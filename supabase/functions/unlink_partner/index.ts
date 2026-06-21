// Unlink the caller from their partner (clears partner_id on both profiles). STUB.
import { serviceClient, requireUser, json } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const db = serviceClient();

    const { data: me } = await db.from("profiles").select("partner_id").eq("id", user.id).single();
    const partnerId = me?.partner_id;

    await db.from("profiles").update({ partner_id: null }).eq("id", user.id);
    if (partnerId) {
      await db.from("profiles").update({ partner_id: null }).eq("id", partnerId);
    }
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 401);
  }
});
