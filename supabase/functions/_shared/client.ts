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
/// Worth a type rather than a string check because `verify_jwt` is OFF on every function here —
/// probed 2026-08-12, and two of them carry comments claiming the opposite. `requireUser` is the
/// only auth guard there is, so its throw is a real 401 and must not be swallowed into a blanket
/// 500; equally, a blanket 401 reports a malformed body or a database outage as an auth problem and
/// sends the app to a sign-in screen that fixes nothing.
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
