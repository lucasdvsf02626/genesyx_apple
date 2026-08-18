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
//
// EVERY path returns the same shape: { ok, sent, reason? }. iOS decodes EmailInviteResponse with
// `ok` and `sent` non-optional, so a bare { error } body could never decode. Note that
// supabase-swift throws FunctionsError.httpError on any non-2xx BEFORE decoding
// (FunctionsClient.swift:246), so on the error paths the body arrives inside that error's `data`
// rather than through the decoder — the uniform shape is what makes it readable at all.
import { serviceClient, requireUser, json, NotAuthenticated } from "../_shared/client.ts";

const RESEND_ENDPOINT = "https://api.resend.com/emails";

Deno.serve(async (req) => {
  try {
    const user = await requireUser(req);
    const { code } = await req.json();
    if (!code) return json({ ok: false, sent: false, reason: "missing_code" }, 400);

    const db = serviceClient();

    const { data: invite, error: invErr } = await db
      .from("partner_invites")
      .select("id, inviter_id, invitee_email, status")
      .eq("code", code)
      .maybeSingle();
    // `invErr.message` no longer goes to the client — it can carry schema detail, and the caller
    // can do nothing with it. Logged instead, so it is still there when someone debugs.
    if (invErr) {
      console.error("send_partner_invite: lookup failed —", invErr.message);
      return json({ ok: false, sent: false, reason: "lookup_failed" }, 500);
    }
    if (!invite) return json({ ok: false, sent: false, reason: "invite_not_found" }, 404);
    if (invite.inviter_id !== user.id) return json({ ok: false, sent: false, reason: "not_your_invite" }, 403);
    if (invite.status !== "pending") return json({ ok: false, sent: false, reason: "invite_not_pending" }, 409);
    if (!invite.invitee_email) return json({ ok: false, sent: false, reason: "no_recipient" }, 400);

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
        text: plainBody(inviterName, link, needsInstallSteps),
        html: htmlBody(inviterName, invite.invitee_email, link, needsInstallSteps),
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      // Do NOT fail the invite — it exists and is shareable. Report so the app can say so.
      return json({ ok: true, sent: false, reason: "send_failed", detail }, 200);
    }

    return json({ ok: true, sent: true });
  } catch (e) {
    // `verify_jwt` is ON for this function — verified live 2026-08-13, correcting the 2026-08-12
    // probe this comment used to report. There IS a gateway in front of it now, but a token for a
    // deleted user clears the gateway and fails `requireUser`, so this stays a genuine 401.
    if (e instanceof NotAuthenticated) {
      return json({ ok: false, sent: false, reason: "not_authenticated" }, 401);
    }
    // Everything else is ours: a malformed body, a database outage, Resend unreachable. 500, and
    // the detail stays in the log rather than going to a caller who can do nothing with it.
    console.error("send_partner_invite: unhandled —", e);
    return json({ ok: false, sent: false, reason: "unhandled" }, 500);
  }
});

// With a custom-scheme link the copy has to carry the install instructions, because the link does
// nothing on a phone without the app. With a Universal Link it survives a fresh install and can
// stand on its own.
//
// The link is the ONLY way to redeem an invite. There is no code-entry screen in the app — the
// deep link opens `InviteView` and that is the whole redemption path — so the copy must not offer
// the raw code as an alternative. It reads as a fallback and dead-ends whoever tries it.
function plainBody(inviterName: string, link: string, needsInstallSteps: boolean): string {
  const intro = [
    `${inviterName} has invited you to join them on Genesyx.`,
    ``,
    `Genesyx is a calm fertility-prep companion — cycle awareness, hydration, nutrition and pH tracking.`,
    ``,
  ];
  // "Sign in with this email address" is load-bearing and phrased to match the share-sheet copy
  // pinned by PartnerTests.testTheShareMessageTellsHimWhatToDo. accept_partner_invite rejects a
  // mismatch outright, so a recipient who signs in with another address just gets refused.
  const steps = needsInstallSteps
    ? [
      `To accept, on your iPhone:`,
      `1. Install Genesyx.`,
      `2. Sign in with this email address — or create an account with it. The invite is tied to this address and won't work from any other.`,
      `3. Open this link: ${link}`,
      ``,
      `That link only opens on an iPhone with Genesyx installed, so open this email there.`,
    ]
    : [
      `Open this link on your iPhone to accept: ${link}`,
      ``,
      `Sign in with this email address — or create an account with it. The invite is tied to this address and won't work from any other.`,
    ];
  return [
    ...intro,
    ...steps,
    ``,
    `Nothing is shared until you accept — and even then your logs, readings and notes stay private to you.`,
    ``,
    `If you weren't expecting this, you can ignore this email.`,
  ].join("\n");
}

function htmlBody(inviterName: string, to: string, link: string, needsInstallSteps: boolean): string {
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
      <li>Install Genesyx on your iPhone.</li>
      <li>Sign in with <strong>${esc(to)}</strong> — or create an account with it. The invite is tied to this address and won't work from any other.</li>
      <li>Tap the button below to accept.</li>
    </ol>`
      : `<p style="font-size:15px;line-height:1.6;color:#4a4a4a;margin:0 0 24px">
      Sign in with <strong>${esc(to)}</strong> — or create an account with it. The invite is tied to this address and won't work from any other.
    </p>`}
    <p style="margin:0 0 16px">
      <a href="${esc(link)}"
         style="display:inline-block;background:#5a4fcf;color:#fff;text-decoration:none;font-weight:600;font-size:15px;padding:14px 28px;border-radius:16px">
        Accept invite
      </a>
    </p>
    <!-- The raw link, visible as text. A genesyx:// href is stripped or left inert by most webmail
         clients, so a recipient whose client kills the button above would otherwise be left with no
         way to accept at all. -->
    <p style="font-size:13px;color:#6b6b6b;line-height:1.6;margin:0 0 24px">
      ${needsInstallSteps
        ? `If the button doesn't work, open this email on your iPhone, or copy this link into Safari there:`
        : `If the button doesn't work, copy this link into your browser:`}<br>
      <span style="color:#5a4fcf;word-break:break-all">${esc(link)}</span>
    </p>
    <p style="font-size:13px;color:#8a8a8a;line-height:1.6;margin:24px 0 0;border-top:1px solid #e5e5e5;padding-top:16px">
      Nothing is shared until you accept — and even then your logs, readings and notes stay private to you.
      If you weren't expecting this, you can ignore this email.
    </p>
  </div>`;
}
