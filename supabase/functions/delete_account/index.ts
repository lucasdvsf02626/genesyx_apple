// Permanently delete the caller's account and all their data.
// REQUIRED by App Store Guideline 5.1.1(v) once the app has accounts.
//
// NOTHING IS REPORTED DELETED THAT WAS NOT DELETED.
// Every statement here used to discard its result, so the function could fail to remove a table,
// carry on, delete the auth user, and return `{ok:true}`. That is the worst available outcome: the
// rows survive, and the only person entitled to ask for their removal no longer exists. Nobody can
// retry, because from the app's side it already succeeded. So each delete is checked now, and a
// failure returns 500 with the auth user still in place — she stays deletable, and the retry is the
// same call again.
//
// The auth user goes LAST for the same reason. It is the handle everything else hangs off.
//
// WHAT CASCADES AND WHAT DOES NOT.
// `quiz_answers.user_id` is `references auth.users(id) on delete cascade`, so it would go with the
// auth user regardless; it is listed explicitly anyway, because that FK lives in a migration this
// function cannot see, and because the explicit delete happens BEFORE the auth-user step, so it
// still holds if that last step fails. `partner_invites.invitee_email` is the opposite case — free
// text with no foreign key, because an invite can be addressed to someone who has no account yet —
// and it is handled separately below.
import { serviceClient, requireUser, json, NotAuthenticated } from "../_shared/client.ts";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const db = serviceClient();
    const uid = user.id;

    const failed = (what: string, message: string) => {
      console.error(`delete_account: ${what} failed —`, message);
      return json({ error: "Something went wrong" }, 500);
    };

    // Unlink any partner first. Not just tidiness: `profiles.partner_id` points at a profile row,
    // so deleting hers while he still points at it is the one ordering that can fail outright. It
    // also closes the read — `profiles_select` is
    // `using (id = auth.uid() or id = public.current_partner_id())`, and his pointer is what grants
    // him her row.
    const { data: me, error: meErr } = await db
      .from("profiles").select("partner_id").eq("id", uid).maybeSingle();
    if (meErr) return failed("profile lookup", meErr.message);
    if (me?.partner_id) {
      const unlink = await db
        .from("profiles").update({ partner_id: null }).eq("id", me.partner_id);
      if (unlink.error) return failed("partner unlink", unlink.error.message);
    }

    // Rows she owns by id. Extend this list as the schema grows.
    //
    // `user_supplements` is here for the same reason `quiz_answers` is: it already cascades
    // (`user_id uuid not null references auth.users (id) on delete cascade`, created
    // 13 Aug in `20260813_android_supplements_backend.sql`), so the auth-user step below would
    // sweep it regardless. But a cascade is the foreign key's promise, not this function's, and
    // it only fires if the LAST step succeeds. Everything else in this list survives a failed
    // auth delete already erased; without this line supplements would be the one table that does
    // not, and they would sit there until she retried. Android's RPC was given exactly this
    // backstop on 13 Aug (H1) and this path was not — that asymmetry is what this closes.
    for (const [table, column] of [
      ["ph_readings", "user_id"],
      ["daily_logs", "user_id"],
      ["cycle_settings", "user_id"],
      ["quiz_answers", "user_id"],
      ["user_supplements", "user_id"],
      ["partner_invites", "inviter_id"],
    ] as const) {
      const { error } = await db.from(table).delete().eq(column, uid);
      if (error) return failed(`${table} delete`, error.message);
    }

    const email = user.email?.trim();
    if (email) {
      const lowered = email.toLowerCase();

      // Invites addressed TO her. Keyed by email with no foreign key, so nothing cascades these
      // away — her address would sit in this table permanently, and she could never reach it:
      // `partner_invites_owner` is `using (inviter_id = auth.uid())`, so once her account is gone
      // there is nobody who can even see the row, let alone delete it.
      //
      // Case-insensitive because that is how accept and decline match this column, and `ilike` is
      // the only case-insensitive filter PostgREST offers. But `_` and `%` are LIKE wildcards and
      // both are legal in an address, so the pattern can match MORE rows than it should — never
      // fewer. Deleting on the `ilike` alone would take a stranger's pending invite with it:
      // `a_b@x.com` also matches `axb@x.com`. So `ilike` narrows and the exact comparison decides.
      const { data: addressed, error: addrErr } = await db
        .from("partner_invites").select("id, invitee_email").ilike("invitee_email", email);
      if (addrErr) return failed("partner_invites lookup", addrErr.message);

      const mine = (addressed ?? [])
        .filter((r) => r.invitee_email?.toLowerCase() === lowered)
        .map((r) => r.id);
      if (mine.length > 0) {
        const { error } = await db.from("partner_invites").delete().in("id", mine);
        if (error) return failed("partner_invites (invitee) delete", error.message);
      }

      // The waitlist she may have joined before she had an account at all. `join_waitlist` stores
      // `lower(trim(...))`, so an exact match is sound here and needs no wildcard dance.
      //
      // This used to be the ONE table whose failure did not stop the deletion. It was written that
      // way because `waitlist_emails` might not exist on the live project yet, making "relation does
      // not exist" an expected error. That premise died on 13 Aug 2026, when both the table and
      // `join_waitlist` were confirmed present — any failure here is a real one.
      //
      // It was then left non-fatal on a risk argument: blocking erasure over a marketing table is
      // worse than leaving an address on a waitlist. That argument is now retired (decision 14 Aug
      // 2026, P0-15 in TESTFLIGHT_B18.md), because it traded a permanent silent lie for a temporary
      // one. Swallowing this returns `{ok: true}` for a deletion that did not happen, and she is
      // the only person entitled to ask for it — after the auth user goes, nobody can even see the
      // row to retry. Failing here costs her nothing by comparison: this runs BEFORE the profile and
      // auth-user steps, so her account is untouched, she stays deletable, and the retry is the same
      // call again — the identical contract every other table in this function already has.
      const wait = await db.from("waitlist_emails").delete().eq("email", lowered);
      if (wait.error) return failed("waitlist_emails delete", wait.error.message);
    }

    const profile = await db.from("profiles").delete().eq("id", uid);
    if (profile.error) return failed("profiles delete", profile.error.message);

    const { error } = await db.auth.admin.deleteUser(uid);
    if (error) return failed("auth user delete", error.message);

    return json({ ok: true });
  } catch (e) {
    if (e instanceof NotAuthenticated) return json({ error: "Not authenticated" }, 401);
    console.error("delete_account: unhandled —", e);
    return json({ error: "Something went wrong" }, 500);
  }
});
