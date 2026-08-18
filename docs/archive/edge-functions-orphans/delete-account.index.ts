// ARCHIVE ONLY — NOT DEPLOYED FROM HERE, NOT PART OF THE BUILD.
//
// Verbatim production source of the orphan Edge Function `delete-account` (hyphen), downloaded from
// project epltxklawpcxxbaleswg on 2026-08-17 at v5 ACTIVE, verify_jwt=true, bundle
// ezbr_sha256 463ecca44125405c6fa74e8f7b6dccab464acdda73059ece6ae751c5867f9a0c.
//
// It is superseded by `delete_account` (underscore, v10), which is what iOS calls. This one deletes
// the auth user and leans entirely on `on delete cascade` for the owned rows — it has none of the
// explicit app-data cleanup the underscore version does. Kept only so the live function can be
// deleted deliberately and still be recoverable. That deletion is a separate, explicit change —
// see docs/LAUNCH_READINESS.md §6.4.
//
// Lives under docs/ rather than supabase/functions/ on purpose: a bare `supabase functions deploy`
// with no slug deploys every directory under supabase/functions/, which would resurrect it.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) return json({ error: "Unauthorized" }, 401);
  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data, error: authErr } = await anon.auth.getUser(authHeader.slice(7));
  if (authErr || !data.user) return json({ error: "Unauthorized" }, 401);
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { error } = await admin.auth.admin.deleteUser(data.user.id);
  if (error) { console.error("[delete-account]", error.message); return json({ error: "Could not delete account." }, 500); }
  return json({ ok: true });
});