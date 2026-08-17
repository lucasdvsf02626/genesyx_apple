# Genesyx website — what to change, and the content to change it to

> **Store:** Genesyx (`genesyx.co.uk`), Shopify Basic, GBP · admin: `https://admin.shopify.com/store/trygenesyx/`
> **Written:** 2026-08-17 · **Audience:** whoever is editing the Shopify pages, plus the clinical reviewer
> **Status of every claim below:** verified against the live site and the iOS source on 2026-08-17.
> Page IDs came from the Admin API; quoted website copy is verbatim from the live pages.

This document exists because **change-list row 1A-8 — "Link to further website content about the science
and the Shettles method" — is blocked on content that does not exist yet**, and because checking the live
site turned up two statements that the iOS build does not deliver.

There are two halves to row 1A-8. Publishing the pages is half. Wiring the links into the app is the other
half, and it cannot be done until the URLs are real. §6 covers the app side.

---

## 1. What is actually live right now

| Page | Handle | State | Finding |
|---|---|---|---|
| vaginal-ph-fertility-science | `vaginal-ph-fertility-science` | Published, **body empty** | Title is `"vaginal-ph-fertility-science "` — the raw handle, **with a trailing space**. Renders theme default sections, so a visitor gets marketing copy where a science page was promised. |
| Shettles | `shettles-method-evidence-limitations` | Published, **stub** | Title is `"method-evidence-limitations"` (the word "shettles" is missing). Body is `"Medical Evidence — Coming soon: detailed information about the medical evidence, current research, and its limitations."` |
| pH Tracking | `ph-tracking` | Published | Carries **two claims the iOS build does not deliver**. See §4. |
| Privacy Policy | `privacy-policy` | Published, updated 2026-07-24 | Accurate and authoritative, with **one gap** — see §5. |
| Delete your data | `delete-your-data` | **Unpublished** | A published duplicate exists at `copy-of-delete-your-data`. See §7. |
| Privacy Policy_V1.0 | `privacy-policy_v1-0` | Unpublished | Superseded draft. Leave unpublished; do not delete without a retention check. |

Both science pages were created 2026-08-14 as placeholders. **Publishing a placeholder under a URL the app
will link to is worse than not linking at all**, so the app links stay out until §3 is done.

---

## 2. Blockers, in the order they block the release

| # | Blocker | Owner | Blocks |
|---|---|---|---|
| **B1** | The two science pages have no body content | Content + clinical reviewer | Row 1A-8, and therefore the App Store submission's completeness claim |
| **B2** | `ph-tracking` advertises strip-colour tapping the iOS app does not have | Content | **App Store guideline 2.3.1** (accurate metadata) |
| **B3** | `ph-tracking` states a healthy range that contradicts the app | Content + clinical reviewer | Health-claim accuracy — a user is told two different things |
| **B4** | Privacy policy does not name Resend (US transfer) | Legal | UK GDPR transfer transparency |
| **B5** | No dedicated support page | Content | App Store Connect requires a working support URL |
| **B6** | "Coming soon" App Store buttons | Content | Launch day only |

---

## 3. The two science pages — content is written, needs review then publication

**The content already exists in this repo and does not need rewriting:**

- `docs/website/vaginal-ph-fertility-science.md` — ~9.9 KB, 7 references (NHS ×2, StatPearls ×2, Ravel 2011, and a
  matched pair of 2025 systematic reviews that disagree with each other, cited deliberately as an open question)
- `docs/website/shettles-method-evidence-limitations.md` — ~9.3 KB, 7 references (Wilcox 1995, Gray 1991,
  You 2017, the Shettles/Rorvik original, the HFE Act 2008, HFEA, NHS)

Both are written to say plainly that the Shettles method is **a theory that has not been shown to work**, which
is exactly what row 1A-8 requires. Both carry an opening and a closing disclaimer block.

### 3.1 What to do in Shopify

For each page, in **Online Store → Pages**:

1. **Fix the title.** These are wrong today and are what a visitor sees in the browser tab and in Google.
   - `vaginal-ph-fertility-science` → **`Vaginal pH and fertility: what the science says`** (note: the current
     title also has a trailing space that must go)
   - `shettles-method-evidence-limitations` → **`The Shettles method: theory versus evidence`**
2. **Keep both handles exactly as they are.** They are already referenced in this plan and will be hard-coded in
   the app. Changing a handle after the app ships means a dead link inside a shipped binary.
3. **Paste the body**, converting the Markdown to the theme's rich text. Mapping: `##` → H2, `###` → H3,
   `**bold**` → bold, `> blockquote` → the theme's callout/quote block. The two ⚠️ disclaimer blocks must render
   as visually distinct callouts — **first screen, above the fold, not in a footer**.
4. **Set the SEO fields** (Search engine listing → Edit):

   | Page | SEO title | Meta description |
   |---|---|---|
   | pH science | Vaginal pH and fertility: what the science says | What vaginal pH is, the range usually cited, why readings move, and what home tracking can and cannot tell you. Educational information, not medical advice. |
   | Shettles | The Shettles method: theory versus evidence | The Shettles method is a 1960s hypothesis about timing and baby sex. Here is what it claims and what the studies actually found. It is not proven and should not be relied on. |

5. **Do not add the pages to the main navigation.** They are reference pages reached from the app and from
   search. Adding them to the header invites them to be read as marketing.
6. **Fill in the review footer** on both pages before publishing — each draft ends with
   `Page last reviewed: [DATE]` / `Clinical reviewer: [NAME AND REGISTRATION]`. Publishing with those brackets
   still in place is worse than not publishing.

### 3.2 The gate before publication

**Neither page may go live until a suitably qualified clinician has reviewed and signed it off.** This is not a
formality for a fertility app making statements about vaginal health. Both drafts are deliberately written to be
reviewable — every substantive claim is cited, and the uncertain parts are labelled as uncertain rather than
smoothed over.

Two things to point the reviewer at specifically, because they are the judgement calls:

- The pH page cites **two 2025 systematic reviews that reach opposite conclusions** on treating bacterial
  vaginosis in pregnancy, and presents the question as unresolved. That is honest, but a reviewer should confirm
  it is the right framing for a consumer audience.
- The Shettles page **concedes** that a 2017 in-vitro study found a real X/Y sperm difference, then argues the
  outcome studies settle the question anyway. That concession is deliberate — it is what makes the page credible
  rather than merely dismissive — but it is the paragraph most likely to be quoted out of context.

> **Note on wording latitude:** these pages can say things the app cannot. The iOS build has test-enforced banned
> phrases blocking clinical terms ("infection", "vaginosis", "thrush", "candida", "bv") inside pH Learn articles.
> The website carries no such guard, which is precisely why linking out is the right design: **the clinical detail
> lives where it is allowed to live.**

---

## 4. `ph-tracking` — two claims to correct (B2, B3)

This page is live now and both problems are user-facing.

### 4.1 The strip-colour claim is false for iOS

**Live copy, verbatim:**

> "Open, tap your strip colour, done — no manual entry."

**What the iOS app actually does:** logging a reading is numeric entry against a stepper — `PhStatus.min = 3.8`,
`PhStatus.max = 7.0`, `PhStatus.step = 0.1` (`Sources/GenesyxCore/Ph/PhStatus.swift:22-27`). A search of
`App/Genesyx/UI/Ph/` for any swatch or colour-picker control returns **nothing**. There is no tap-the-colour
input, and entry is manual — the exact opposite of the sentence.

This matters beyond tidiness: App Store guideline **2.3.1** prohibits marketing that describes functionality the
build does not include, and a reviewer who reads the linked website will see it.

**Replacement copy:**

> Log a reading in seconds. Enter your result, and Genesyx keeps your history and shows your trend over time.

If the colour-tap interaction is genuinely planned, it belongs in a future release and the sentence should return
when it ships — not before.

### 4.2 The healthy range contradicts the app

**Live copy, verbatim:**

> "A typical healthy range of about 3.8–5.0"

**What the app tells her:** anything **above 4.5** is classified `elevated`
(`Sources/GenesyxCore/Ph/PhStatus.swift:29-31`, two-band model, "readings above 4.5 are elevated").

So a woman reads 3.8–5.0 on the website, logs 4.8, and the app labels it **Elevated**. The website and the
product disagree about her health data. The reviewed science page uses **3.8–4.5**, which matches the app and
matches the usual clinical citation.

**Replacement copy:**

> Vaginal pH in reproductive-age women is commonly described as sitting somewhere around 3.8–4.5. A single
> reading is not a verdict — what is usual varies between people, and readings move for ordinary reasons.
> [Read more about what the science does and does not show →](/pages/vaginal-ph-fertility-science)

That link also gives the science page an internal inbound link, which it needs.

> **Where to edit:** the Shopify page body for `ph-tracking` is empty — this copy is rendered from **theme
> sections**. Edit via **Online Store → Themes → Customize**, select the `ph-tracking` page from the top
> dropdown, and edit the section text. It is not in the Pages editor. Check whether the same section is reused on
> `vaginal-ph-fertility-science`, since that page also renders theme defaults today.

---

## 5. Privacy policy — the Resend gap (B4)

The live policy at `/policies/privacy-policy` is **authoritative and otherwise accurate**. It declares vaginal pH,
cycle and daily logs, states UK GDPR Article 9(2)(a) explicit consent, names Supabase, Apple, Google, Shopify and
Klaviyo, and promises immediate deletion. Do not reason about compliance from `docs/PRIVACY_POLICY.md` in the
repo — that file is an engineering reference and has been wrong before.

**The gap:** partner-invite emails are sent through **Resend's global US endpoint**
(`supabase/functions/send_partner_invite/index.ts:22` calls `https://api.resend.com/emails`), and **Resend is not
named in the policy's provider list.** Everything else stays in the EU — the Supabase project is `eu-west-1`
(Ireland), which UK adequacy covers, so no IDTA is needed for it. The invite email is the only US transfer, and it
carries an email address, not health data.

**Two ways to close it — pick one:**

| Option | Change | Trade-off |
|---|---|---|
| **A — switch to Resend EU** | One-line change to the Edge Function endpoint | Removes the transfer entirely; nothing to disclose. Preferred. |
| **B — disclose it** | Add Resend to the policy's provider list and the international-transfers section | No code change, but you are now maintaining a US transfer disclosure |

**Suggested wording if you take option B:**

> **Resend (email delivery).** We use Resend to send invitation emails. Resend processes the recipient's email
> address and the message content in order to deliver it. This processing takes place in the United States, and
> we rely on the International Data Transfer Addendum to the EU Commission Standard Contractual Clauses. No
> health data — including cycle, pH or symptom information — is sent to Resend.

**Relevant to the 1.2.0 iOS release specifically:** partner linking is switched off in this build
(`FeatureFlags.partnerInvites = false`), so **the iOS app cannot trigger a Resend email at all**. The Android app
can, and it shares the backend — so the gap is real for the site and the company, just not caused by this
binary. That makes Option A cheap to do now, before anyone is relying on the disclosure.

---

## 6. Wiring the app to the pages — the other half of row 1A-8

Do this **only after the pages are published with real content**, and in a build that is re-tested.

Today the app contains **no link to either page**. The only `genesyx.co.uk` references in the app are the
entitlements, the privacy-policy link, a support link and a Learn share root.

**Where the links belong**, from the pH surface audit:

| Link | File | Why here |
|---|---|---|
| Vaginal pH science | `App/Genesyx/UI/Ph/PhTrackerSection.swift:354-356` | The "Why pH matters" section already renders a `SourcesFooter`; a `Link` row slots in with no new layout. |
| Shettles-is-a-theory | `App/Genesyx/UI/Learn/LearnContent.swift:702` (`guide-understanding-vaginal-ph`) | See the warning below. |

> **⚠️ A launch-visibility problem that must be solved at the same time.** The in-app Shettles article is
> **date-gated to 8 November 2026** (`LearnContent.swift:1112`) and the main pH article to **30 August 2026**
> (`:786`). At submission both render as disabled "Arrives 8 November" rows. So the app's own honest Shettles
> copy is **invisible at launch**, and row 1A-8 asks for the statement to be visible. Put the outbound link and
> the "this is a theory, not proven" sentence in an **ungated** surface — `guide-understanding-vaginal-ph`
> (`LearnContent.swift:702`) is available at launch and is the natural home.

---

## 7. Smaller items

**B5 — Support page.** App Store Connect requires a support URL. The app currently points at the shop homepage
(`ProfileView.swift:10`), which is a storefront, not support. Create a page at handle **`support`**:

> ## Genesyx support
>
> **Email:** info@genesyx.co.uk — we aim to reply within 2 working days.
>
> ### Common questions
>
> **How do I change my password?** Open the app, go to Profile → Account, and choose Change password. If you are
> signed out, choose "Forgot password" on the sign-in screen and we will email you a reset link.
>
> **How do I delete my account and my data?** In the app, go to Profile → Account → Delete account. This removes
> your account and the data attached to it. You can also request deletion at
> [Delete your data](/pages/delete-your-data).
>
> **My readings or logs are not showing on the right day.** Make sure the app has finished syncing — logs are
> saved on your device first and upload when you are back online. If a log is still on the wrong date after
> syncing, email us with the date and what you logged.
>
> **Is Genesyx medical advice?** No. Genesyx is an educational wellness app. It is not a medical device, it does
> not diagnose anything, and it must not be used for contraception. If you have symptoms or concerns, please
> speak to a GP, pharmacist or sexual health clinic.
>
> **Who can see my data?** Your logs are private to your account. See our
> [Privacy policy](/policies/privacy-policy).

Then set the App Store Connect support URL to `https://genesyx.co.uk/pages/support`.

**B6 — Launch-day flips.** `ph-tracking` (and any other page carrying the badge) says **"Download on the App
Store — coming soon"**. Flip to a real App Store link only once the app is *live*, not when it is approved.

**Duplicate "Delete your data".** `delete-your-data` is **unpublished** while `copy-of-delete-your-data` is
**published**. Apple and the ICO both care that this route works. Decide which is canonical — the clean handle
is `delete-your-data` — publish that one, and redirect `copy-of-delete-your-data` to it (**URL Redirects**, do
not just delete: the footer and possibly the policy link to it).

---

## 8. Order of work

1. **Now, no gate:** fix the two page titles (§3.1), correct the two `ph-tracking` claims (§4), create the support
   page (§7), resolve the delete-your-data duplicate (§7).
2. **Now, one-line code change:** switch Resend to its EU endpoint (§5, option A) — or start the legal decision.
3. **Blocked on the clinical reviewer:** publish the two science pages (§3).
4. **After (3) is live:** wire the two app links and fix the launch-visibility gating (§6). Needs a new build and
   a re-run of the UI suite.
5. **Launch day:** flip the "coming soon" badges (§7).

Steps 1, 2 and 3 are website work and need no app release. **Step 4 needs a new binary** — so if the app links
are to be in 1.2.0, step 3 has to clear the reviewer before the archive is cut.

---

## 9. Verification

- [ ] Both science page titles read as English, no trailing whitespace
- [ ] Both pages return 200 with real body content, disclaimers above the fold
- [ ] Review footer filled in — date and named reviewer with registration
- [ ] `ph-tracking` no longer claims strip-colour tapping
- [ ] `ph-tracking` range reads 3.8–4.5 and matches `PhStatus.classify`
- [ ] `/pages/support` returns 200 and is set in App Store Connect
- [ ] `delete-your-data` published; `copy-of-delete-your-data` redirects to it
- [ ] Resend either moved to EU or named in the policy
- [ ] App links added and opening the real URLs (only after publication)
- [ ] Shettles "theory, not proven" statement visible at launch, not date-gated
