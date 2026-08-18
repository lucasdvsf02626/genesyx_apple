// Unlink the caller from their partner (clears partner_id on both profiles).
//
// THE PARTNER'S ROW IS CLEARED FIRST, AND BOTH WRITES ARE CHECKED.
// `profiles_select` is `using (id = auth.uid() or id = public.current_partner_id())`, so it is HIS
// `partner_id` that grants him a read on HER row, not hers on his. This function used to fire both
// updates and discard both results, so a failure on the second one returned `{ok:true}` over a
// half-cleared link — she is told she has unlinked, he still points at her, and he keeps reading
// her profile indefinitely. Nothing would ever detect it: her UI shows no partner, so it never
// offers her the unlink that would retry.
//
// Clearing his pointer first means a failure leaves the residue on the harmless side — she still
// points at him, which grants HER a read on HIM, and she is the one who asked for this and whose
// screen will still offer the retry. The reported failure is what makes that retry happen.
import { serviceClient, requireUser, json, NotAuthenticated } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const db = serviceClient();

    const { data: me, error: meErr } = await db
      .from("profiles").select("partner_id").eq("id", user.id).maybeSingle();
    if (meErr) {
      console.error("unlink_partner: lookup failed —", meErr.message);
      return json({ error: "Something went wrong" }, 500);
    }
    const partnerId = me?.partner_id;
    if (!partnerId) return json({ ok: true });

    // `.eq("partner_id", user.id)` is the whole point of this line, not a redundancy. Without it,
    // this cleared whoever her row pointed at, whether or not he pointed back. Where the link is
    // asymmetric — she points at him, he points at a third person — her unlink silently severed HIS
    // link to someone who is not a party to this request, and that third person kept pointing at
    // him, so under `profiles_select` they kept reading his row while he lost the link entirely.
    //
    // Matching zero rows is the correct outcome for that case, not a failure: nothing reciprocal
    // exists to clear. Her own row is still cleared below, which is what removes the read SHE holds
    // on him, and a one-directional pointer is exactly the residue accept_partner_invite repairs.
    const his = await db
      .from("profiles").update({ partner_id: null })
      .eq("id", partnerId).eq("partner_id", user.id);
    if (his.error) {
      console.error("unlink_partner: clearing partner's row failed —", his.error.message);
      return json({ error: "Something went wrong" }, 500);
    }

    const hers = await db.from("profiles").update({ partner_id: null }).eq("id", user.id);
    if (hers.error) {
      console.error("unlink_partner: clearing caller's row failed —", hers.error.message);
      return json({ error: "Something went wrong" }, 500);
    }

    return json({ ok: true });
  } catch (e) {
    if (e instanceof NotAuthenticated) return json({ error: "Not authenticated" }, 401);
    console.error("unlink_partner: unhandled —", e);
    return json({ error: "Something went wrong" }, 500);
  }
});
