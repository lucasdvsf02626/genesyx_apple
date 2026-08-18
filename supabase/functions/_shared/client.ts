// Shared helpers for Genesyx Edge Functions.
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/** Service-role client (full access — never expose this key to the app). */
export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/// Thrown by `requireUser` and by nothing else, so a catch block can tell "you are not signed in"
/// (401) from "something broke server-side" (500).
///
/// `verify_jwt` is ON for every function here — verified live 2026-08-13, correcting the 2026-08-12
/// probe this comment used to report. So the gateway now turns away a caller with no token or a bad
/// signature before any of this runs, and `requireUser` is the second guard rather than the only one.
///
/// It still has to throw its own type. A signature the gateway accepts is not the same as a user who
/// exists: a token minted for a since-deleted account passes the gateway and fails `getUser`, and
/// that is a genuine 401. Swallowing it into a blanket 500 hides it; equally, a blanket 401 reports a
/// malformed body or a database outage as an auth problem and sends the app to a sign-in screen that
/// fixes nothing. The distinction is what the type buys.
export class NotAuthenticated extends Error {
  constructor() {
    super("Not authenticated");
    this.name = "NotAuthenticated";
  }
}

/** Resolves the calling user from the request's Authorization (JWT) header. */
export async function requireUser(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new NotAuthenticated();
  return data.user;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
