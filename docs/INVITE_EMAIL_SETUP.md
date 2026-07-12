# Partner invite email — what's built, and the 15 minutes you need to finish it

**2026-07-12** · branch `build-12-data-honesty`

The code is done and tested. It **cannot send a single email until you do the three steps in §2**,
because sending mail needs an API key and a domain you own — neither of which I can create.

---

## 1. What was wrong, and what now happens

**Before:** she typed her partner's email, tapped invite, a database row was created… and **no
email was ever sent to anybody.** There is no mail provider anywhere in `supabase/functions/`. The
address she typed was used *only* as a server-side check when the invite was later accepted — it
was **never contacted**. The one and only delivery mechanism was her manually pasting a
`genesyx://` link into a share sheet.

**Now:** creating an invite calls a new edge function, `send_partner_invite`, which emails the
invite to the address it was addressed to — with the code, an "Accept invite" button, and the
instruction that decides whether the invite works at all: *sign in with **this** email address.*

### The safety property that matters

**A mail failure never destroys an invite.** If the key isn't set, or Resend is down, or the send
is rejected, the function returns `sent: false` — it does **not** error. The invite still exists,
is still valid, and the share sheet still works exactly as it does today.

And the app **never claims an email it didn't send**: the sheet says *"Invite sent — we've emailed
…"* only when the server confirms it went out; otherwise it says *"Invite ready"* and shows the
share link, as before. Three tests pin this (`PartnerTests`):
- `testCreatingAnInviteEmailsIt`
- `testAnUnsentEmailStillLeavesAUsableInvite` (key not configured → invite survives)
- `testAFailingMailerDoesNotFailTheInvite` (mailer throws → invite survives)

### Abuse guard

The recipient address is read **from the database, never from the request body**, and the caller
must own the invite (`inviter_id === caller`). So this endpoint cannot be used to mail an arbitrary
address — it cannot be turned into an open relay.

---

## 2. What YOU need to do (≈15 min)

### Step 1 — Get a sending domain + key
Sign up at **resend.com** (free tier is plenty), then **verify `genesyx.co.uk`** as a sending
domain. This means adding the DNS records Resend gives you (SPF/DKIM) to your domain's DNS.

> ⚠️ **Do not skip domain verification.** Sending from an unverified domain means invites land in
> spam or are rejected outright. This DNS step is the reason this can't be automated.

### Step 2 — Set the two secrets
```bash
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
supabase secrets set INVITE_FROM_EMAIL="Genesyx <hello@genesyx.co.uk>"
```
Both are read by the function. If **either** is missing it returns `sent: false` and the app falls
back to the share sheet — safe, just no email.

### Step 3 — Deploy the function
```bash
supabase functions deploy send_partner_invite
```

### Step 4 — Verify (2 min)
In the app: Profile → Add your partner → enter an address you own → the sheet should say
**"Invite sent"**. Check the inbox. Then confirm the accept path still works end to end.

---

## 3. Files added / changed

| File | What |
|---|---|
| `supabase/functions/send_partner_invite/index.ts` | **new** — the mailer (Resend), with the ownership check and graceful degradation |
| `RemoteBackend.swift` | `emailInvite(code:) -> Bool` on `PartnerBackend`, defaulted so no mock had to change |
| `SupabaseBackend.swift` | invokes the function, decodes whether the mail actually went out |
| `RemoteModels.swift` | `EmailInviteResponse` DTO |
| `PartnerRepository.swift` | emails after creating; a mail failure is non-fatal; `lastInviteEmailed` flag |
| `InviteShareSheet.swift` | says "Invite sent" only when it truly was; otherwise "Invite ready" |
| `ProfileView.swift` | passes the flag through |
| `PartnerTests.swift` | 3 new tests (above) |

Tests: **86 core + 93 app + 9 UI, 0 failures.**

---

## 4. The remaining gap — read this before you call invites "done"

Even with email working, **a partner who does not already have the app installed still cannot
accept from the email.**

The link is `genesyx://invite/<code>` — a custom URL scheme. It opens nothing on a phone without
Genesyx, and many mail clients won't even make it tappable. The email works around this by telling
them to install the app first and including the code — but it's a workaround, not a fix.

**The real fix is Universal Links, and the app code for it already exists and is already dead:**
`DeepLink.swift` parses `https://…/invite/<code>`, and `RootView` listens for
`.onContinueUserActivity` — but `Genesyx.entitlements` has **no `associated-domains`**, so neither
can ever fire.

To turn it on:
1. Add `applinks:genesyx.co.uk` to `Genesyx.entitlements` (and the App ID's Associated Domains
   capability in the Apple Developer portal).
2. Host `apple-app-site-association` (JSON, no extension, served as `application/json` over HTTPS
   at `https://genesyx.co.uk/.well-known/apple-app-site-association`) with your Team ID + bundle ID.
3. Change `DeepLink.inviteURL` to build the `https://` link.

I did **not** do this: it changes app entitlements and requires publishing a file to your live
domain. Both are yours to authorise. It is roughly a 30-minute job once you say go.

---

## 5. And the deeper one: "linked" still shares nothing

Worth being clear-eyed, since the whole point of a partner feature is sharing. Once linked, the
`Partner` model has exactly **one field: `name`**, rendered as an avatar on Profile. Nothing else
is shared — and it isn't merely unimplemented, **the database forbids it**: RLS on
`cycle_settings`, `ph_readings` and `daily_logs` is owner-only.

So the invite now genuinely *works*, but what it buys her is a name on a screen.

Deciding what a partner should actually see (her cycle phase? hydration? nothing but a nudge to
support her?) is a **product and privacy decision on a health app**, and implementing it means new
RLS policies on your production database. I've left the copy honest in the meantime ("your logs,
readings and notes stay private to you"). **Tell me what a partner should see and I'll build it.**
