// ARCHIVE ONLY — NOT DEPLOYED FROM HERE, NOT PART OF THE BUILD.
//
// Verbatim production source of the orphan Edge Function `change-password`, downloaded from project
// epltxklawpcxxbaleswg on 2026-08-17 at v5 ACTIVE, verify_jwt=true, bundle
// ezbr_sha256 ae292161316979f1a5b8ed846d6247413954c9dfce1a227156d1c7aee35ae69e.
//
// No client calls it. iOS changes passwords through supabase-swift directly; Android does the same
// in SupabaseAuthService.changePassword, re-authenticating with signInWith(Email) first. Kept only
// so the live function can be deleted deliberately and still be recoverable. That deletion is a
// separate, explicit change — see docs/LAUNCH_READINESS.md §6.4.
//
// Worth preserving one detail before it goes: line 35 of the original refuses outright when the
// account has no email on file. That is the fail-safe shape the H1 bug in accept_partner_invite was
// missing, in code that predates it.
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
  let body: { currentPassword?: string; newPassword?: string } = {};
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  const currentPassword = body.currentPassword ?? "";
  const newPassword = body.newPassword ?? "";
  if (!currentPassword) return json({ error: "Current password is required" }, 400);
  if (newPassword.length < 8 || newPassword.length > 200) {
    return json({ error: "New password must be 8-200 characters" }, 400);
  }
  const email = data.user.email;
  if (!email) return json({ error: "Account has no email on file" }, 400);
  const verifier = createClient(
    Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { error: signErr } = await verifier.auth.signInWithPassword({ email, password: currentPassword });
  if (signErr) return json({ error: "Current password is incorrect" }, 403);
  await verifier.auth.signOut().catch(() => {});
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { error } = await admin.auth.admin.updateUserById(data.user.id, { password: newPassword });
  if (error) { console.error("[change-password]", error.message); return json({ error: "Could not update password." }, 500); }
  return json({ ok: true });
});