// Emails a partner invite to the address it was addressed to.
//
// Until now no email was ever sent: the app created a `partner_invites` row and left the user to
// paste a link into a share sheet herself. The address she typed was only ever used as a
// server-side check at accept time — it was never contacted.
//
// Security: the caller must own the invite (inviter_id === caller). The recipient address is read
// from the DATABASE, never from the request body, so a caller cannot use this to mail an arbitrary
// address (i.e. it cannot be turned into an open relay / spam cannon).
//
// Degrades gracefully: with no RESEND_API_KEY configured this returns ok:true, sent:false rather
// than failing. The invite still exists and the in-app share sheet still works, so a missing key
// can never break invites — it just means the email leg is off.
import { serviceClient, requireUser, json } from "../_shared/client.ts";

const RESEND_ENDPOINT = "https://api.resend.com/emails";

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
    if (invite.inviter_id !== user.id) return json({ error: "Not your invite" }, 403);
    if (invite.status !== "pending") return json({ error: "Invite is not pending" }, 409);
    if (!invite.invitee_email) return json({ error: "Invite has no recipient" }, 400);

    const apiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("INVITE_FROM_EMAIL");
    if (!apiKey || !from) {
      // Not configured yet — the app falls back to the share sheet.
      return json({ ok: true, sent: false, reason: "email_not_configured" });
    }

    // The inviter's name, so the email doesn't arrive from a stranger.
    const { data: profile } = await db
      .from("profiles").select("display_name").eq("id", user.id).maybeSingle();
    const inviterName = profile?.display_name?.trim() || "Someone";

    // Universal Link when the domain is live (set INVITE_WEB_BASE=https://genesyx.co.uk once
    // apple-app-site-association is served); otherwise the custom scheme, which at least opens the
    // app for someone who already has it. An https link with no AASA behind it is worse than
    // useless — it opens Safari to a 404.
    const webBase = Deno.env.get("INVITE_WEB_BASE")?.replace(/\/$/, "");
    const link = webBase ? `${webBase}/invite/${code}` : `genesyx://invite/${code}`;
    const needsInstallSteps = !webBase;

    const res = await fetch(RESEND_ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [invite.invitee_email],
        subject: `${inviterName} invited you to Genesyx`,
        text: plainBody(inviterName, code, link, needsInstallSteps),
        html: htmlBody(inviterName, code, invite.invitee_email, link, needsInstallSteps),
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      // Do NOT fail the invite — it exists and is shareable. Report so the app can say so.
      return json({ ok: true, sent: false, reason: "send_failed", detail }, 200);
    }

    return json({ ok: true, sent: true });
  } catch (e) {
    return json({ error: String(e) }, 401);
  }
});

// With a custom-scheme link the copy has to carry the install instructions, because the link does
// nothing on a phone without the app. With a Universal Link it survives a fresh install and can
// stand on its own.
function plainBody(inviterName: string, code: string, link: string, needsInstallSteps: boolean): string {
  const intro = [
    `${inviterName} has invited you to join them on Genesyx.`,
    ``,
    `Genesyx is a calm fertility-prep companion — cycle awareness, hydration, nutrition and pH tracking.`,
    ``,
  ];
  const steps = needsInstallSteps
    ? [
      `To accept:`,
      `1. Install Genesyx from the App Store.`,
      `2. Sign in with THIS email address (the invite is tied to it).`,
      `3. Open this link: ${link}`,
    ]
    : [
      `Open this link to accept: ${link}`,
      ``,
      `Sign in with THIS email address — the invite is tied to it.`,
    ];
  return [
    ...intro,
    ...steps,
    ``,
    `Or enter this invite code in the app: ${code}`,
    ``,
    `If you weren't expecting this, you can ignore this email — nothing is shared until you accept.`,
  ].join("\n");
}

function htmlBody(inviterName: string, code: string, to: string, link: string, needsInstallSteps: boolean): string {
  const esc = (s: string) => s.replace(/[<>&"]/g, (c) =>
    ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;" }[c]!));
  return `
  <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:520px;margin:0 auto;padding:32px 24px;color:#1c1b1f">
    <p style="font-size:13px;letter-spacing:2px;color:#6b6b6b;margin:0 0 24px">GENESYX</p>
    <h1 style="font-size:24px;font-weight:600;margin:0 0 12px">${esc(inviterName)} invited you</h1>
    <p style="font-size:15px;line-height:1.6;color:#4a4a4a;margin:0 0 24px">
      Genesyx is a calm fertility-prep companion — cycle awareness, hydration, nutrition and pH tracking.
    </p>
    ${needsInstallSteps
      ? `<ol style="font-size:15px;line-height:1.8;color:#4a4a4a;padding-left:20px;margin:0 0 24px">
      <li>Install Genesyx from the App Store.</li>
      <li>Sign in with <strong>${esc(to)}</strong> — the invite is tied to this address.</li>
      <li>Open the link below to accept.</li>
    </ol>`
      : `<p style="font-size:15px;line-height:1.6;color:#4a4a4a;margin:0 0 24px">
      Sign in with <strong>${esc(to)}</strong> — the invite is tied to this address.
    </p>`}
    <p style="margin:0 0 24px">
      <a href="${esc(link)}"
         style="display:inline-block;background:#5a4fcf;color:#fff;text-decoration:none;font-weight:600;font-size:15px;padding:14px 28px;border-radius:16px">
        Accept invite
      </a>
    </p>
    <p style="font-size:14px;color:#6b6b6b;margin:0 0 8px">
      Or enter this code in the app: <strong style="letter-spacing:1px">${esc(code)}</strong>
    </p>
    <p style="font-size:13px;color:#8a8a8a;line-height:1.6;margin:24px 0 0;border-top:1px solid #e5e5e5;padding-top:16px">
      If you weren't expecting this, ignore this email — nothing is shared until you accept.
    </p>
  </div>`;
}
