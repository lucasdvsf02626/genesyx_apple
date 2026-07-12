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

## 4. Universal Links — built, tested, and waiting on TWO things only you can do

Without this, **a partner who doesn't already have the app cannot accept from the email.** The
`genesyx://` link opens nothing on a phone without Genesyx, and many mail clients won't even make
it tappable.

Everything on my side is now done: the AASA file, the link builders, the parser, the email, and
tests. It is **switched off on purpose**, because switching it on early breaks things in two
separate ways.

### ⚠️ Why it is off — I tested both failure modes, they're real

**1. It breaks your archive.** With the `associated-domains` entitlement enabled, `xcodebuild
archive` fails outright:
```
error: Provisioning profile "Genesyx App Store" doesn't include the Associated Domains capability.
** ARCHIVE FAILED **
```
That is not a warning. **You could not upload build 12 at all.** So the entitlement sits
commented-out in `App/Genesyx/Genesyx.entitlements`, with these same steps beside it. Archive
currently **succeeds** — I re-verified after commenting it back out.

**2. It breaks every invite.** If the app hands out `https://genesyx.co.uk/invite/<code>` before
that domain actually serves the AASA file, the link opens **Safari to a 404** — strictly worse than
today, where the link at least opens the app for someone who has it. So `DeepLink.universalLinksLive`
is `false`, and a test (`testHandedOutLinkMatchesWhatTheDomainCanActuallyServe`) fails if anyone
flips it without shipping the file.

### The switch-on sequence (do them in this order)

1. **Apple Developer portal** → Identifiers → `com.genesyx.app` → tick **Associated Domains** → Save.
2. **Regenerate + download** the `Genesyx App Store` provisioning profile.
3. **Host the file.** It's already written for you at `public/.well-known/apple-app-site-association`
   (Team ID `M5L3MM75SG`, bundle `com.genesyx.app`, path `/invite/*`). Serve it at
   `https://genesyx.co.uk/.well-known/apple-app-site-association` — **HTTPS, no redirect,
   `Content-Type: application/json`, no `.json` extension.**
   Verify: `curl -sI https://genesyx.co.uk/.well-known/apple-app-site-association` → `200` + json.
4. **Uncomment** the `associated-domains` block in `App/Genesyx/Genesyx.entitlements`.
5. **Flip** `DeepLink.universalLinksLive` to `true` (one line, `DeepLink.swift`).
6. **Set the mail secret** so the email uses the web link too:
   `supabase secrets set INVITE_WEB_BASE=https://genesyx.co.uk`
7. **Archive** — it should now succeed. Install that build, then tap a link.

> Apple caches the AASA file. Test on a device with a **freshly installed** build, and be aware
> the link only starts working from the build that carries the entitlement onward.

**Old links never stop working.** The parser accepts both forms permanently, and a test pins it
(`testCustomSchemeStillParsesAfterUniversalLinksGoLive`) — invites already sitting in someone's
inbox stay valid after you switch the domain on.

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
