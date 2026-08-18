# Today's action list — Lucas · 18 August 2026

> **Honest framing first.** You cannot *publish* today. Apple review alone is 24–48 h after you
> submit, and two items on this list depend on other people replying. What you **can** finish today
> is **every single thing that is waiting on you** — and get build 20 into TestFlight on a real
> phone. Do that and the release stops being blocked by you and starts being blocked only by a
> clinician, a lawyer's sentence, and Apple's queue.
>
> **Total time: about 4–5 hours.** Do them in this order — each one unblocks the next.
>
> Status of the code, so you know what you are working against: **1.2.0 build 20 is built, signed and
> exported** at `build/Export/Genesyx.ipa`. 431 tests pass, 0 fail, 0 skip. Nothing on this list is
> Swift.

---

## ⏱️ The order, at a glance

| # | Task | Time | Unblocks |
|---|---|---|---|
| 1 | **Decide the Article 9 basis** | 15 min | Everything. Decides whether there is a build 21 at all |
| 2 | **Generate the Apple `.p8` key → Supabase** | 20 min | The last piece of engineering Apple demands |
| 3 | **Upload build 20 to TestFlight** | 30 min | Puts a real binary on a real phone; surfaces ASC problems early |
| 4 | **Fill in the App Store Connect record** | 2 h | The single largest untouched block of work |
| 5 | **Install on a real iPhone and run 7 checks** | 45 min | Closes 6 items nobody has ever tested |
| 6 | **Email the clinician pack** | 10 min | Longest external lead time — send it early |
| 7 | **Two website edits** | 20 min | Removes two small compliance gaps |
| 8 | **Turn on custom SMTP** | 30 min | Required before external testers |
| 9 | **Answer 5 product decisions** | 15 min | Tells me what build 21 contains |

---

## 1 · Decide the Article 9 lawful basis — **do this first** ⏱️ 15 min

This is the largest legal exposure in the release and it forks the whole timeline.

**The situation.** Your published policy (v2.2, 24 July 2026, controller **Genesyx Ltd**, company
16913651) says, in terms:

> "this is special category data. We process it only with your explicit consent (Article 9(2)(a))"

The app **never asks for consent and stores no record of it**. So the basis you publicly claim is
not evidenced anywhere. A regulator comparing the policy to the app finds a gap.

**Pick one:**

| | Option A — amend the policy | Option B — build consent |
|---|---|---|
| What it means | Change the policy to the basis you actually rely on | Add a consent step to the app |
| Your work today | One Shopify page edit | Approve the wording |
| My work | None | Consent screen + `consented_at` column + Android parity + tests + new archive |
| Cost to the timeline | **Zero** | **~1 week, and it forces build 21** |

⚠️ **Do not ask me to write the legal wording.** I will implement whatever a qualified person
approves, and I will not invent it. If you are unsure, Option A with a solicitor's one-line review is
the fast path.

**Send me:** "Article 9 = A" or "Article 9 = B, wording attached".

---

## 2 · Apple `.p8` key into Supabase ⏱️ 20 min

Apple **requires** any app offering Sign in with Apple to call `/auth/revoke` when an account is
deleted. Our client half works; the server call does not exist, and `auth.identities` shows real
Apple accounts already in use. **This is a hard rejection if we ship without it.** I cannot build it
until the key exists.

**Steps:**

1. Go to **developer.apple.com → Certificates, Identifiers & Profiles → Keys → ➕**
2. Name it `Genesyx Sign in with Apple`, tick **Sign in with Apple**, press **Configure**, choose the
   primary App ID `com.genesyx.app`, then **Continue → Register**.
3. **Download the `.p8`.** ⚠️ Apple lets you download it **once, ever**. If you lose it you must
   revoke and start again. Put it straight into your password manager.
4. Write down the **Key ID** (10 characters, on that same page). Team ID is **`M5L3MM75SG`**.
5. Go to **Supabase → project `epltxklawpcxxbaleswg` → Edge Functions → Secrets** and add:

   | Name | Value |
   |---|---|
   | `APPLE_TEAM_ID` | `M5L3MM75SG` |
   | `APPLE_KEY_ID` | the 10-character Key ID |
   | `APPLE_CLIENT_ID` | `com.genesyx.app` |
   | `APPLE_PRIVATE_KEY` | the **entire** contents of the `.p8`, including the `BEGIN`/`END` lines |

🔒 **Never paste the `.p8` into this chat, a commit, a log or a screenshot.** Put it in Supabase
directly. Tell me only *"secrets are in"* — I will read them at runtime via `Deno.env.get` and never
see the value.

**Send me:** "Apple secrets are in."

---

## 3 · Upload build 20 to TestFlight ⏱️ 30 min

You can do this **today, with none of the above resolved.** TestFlight does not require the legal or
content items — only public release does. Get the binary in hand.

1. Open **Xcode → Window → Organizer → Archives**, select the 17 Aug build-20 archive.
   (If it is missing, tell me and I will re-export from `build/Export/Genesyx.ipa`.)
2. **Distribute App → App Store Connect → Upload.**
3. Confirm before pressing go: bundle `com.genesyx.app`, version **1.2.0**, build **20**, team
   **SF MEDIA & PR LTD (M5L3MM75SG)**, profile **Genesyx App Store**.
4. Wait for "Processing complete" in App Store Connect (usually 5–15 min).
5. **Internal testers only** for now. Do not add an external group until task 8 is done — the
   built-in email sender will not survive it.
6. Paste the "What to Test" notes from **`docs/TESTFLIGHT_B20.md`** into Build 20 → Test Details.

⚠️ **Check first whether build 19 or 20 was already uploaded.** If a build number is already used,
App Store Connect rejects the second one carrying the same number, and I will need to cut build 21
purely to renumber it. Look at **TestFlight → iOS builds** before you upload.

**Send me:** the highest build number already showing in App Store Connect.

---

## 4 · App Store Connect record ⏱️ 2 hours — the big one

**None of this has ever been filled in.** It is the largest remaining block of work and it is all
yours. Copy for most fields is already drafted in **`docs/APP_STORE_LISTING.md`**.

### 4a · Listing
- Name, subtitle, description, keywords, support URL, marketing URL — from `APP_STORE_LISTING.md`.
- ⚠️ **Remove every partner-linking claim.** Partner is built but switched off for 1.2.0
  (`FeatureFlags.partnerInvites = false`). Advertising a feature the binary does not expose is a
  straight rejection.
- Category: **Health & Fitness**.

### 4b · Screenshots — ✅ **DONE, this is off your list**
`docs/appstore_screenshots/` now holds **seven** fresh captures from the build 21 tree, all
1320 × 2868 and alpha-flattened: 1-Home, 2-Track, **3-pH**, 4-Nutrition, 5-Insights, 6-Learn,
7-Profile. The July six are deleted. Upload these.

They show the app as it actually is now: seven tabs, light default, egg artwork, and the consent
control on Profile. The account in them is the fictional Maya, so nothing real is exposed.
Note the numbering shifted — pH is new at position 3, so old "screenshot 3" meant Nutrition.

### 4c · App Privacy — answer from the real data flows, not marketing
We collect, **linked to identity**: health & fitness data (cycle, symptoms, pH, intimacy), contact
info (email), user content (notes), identifiers (user ID).
We do **not** track across apps, and there is **no** third-party advertising.
Sub-processors: **Supabase** (database + auth), **Apple** and **Google** (sign-in), **Resend**
(transactional email — see task 7).

### 4d · Age rating
Answer the fertility/health questions **honestly**. Expect **16+ or 18+**. Do not soften it to chase
a lower rating.

### 4e · Review notes — ⚠️ **the one that gets you rejected if you skip it**
Every private tab is now behind a sign-in wall. **Without credentials a reviewer sees a login screen
and rejects under Guideline 2.1.** You must provide:

- **Demo account:** `demo@genesyx.co.uk` — password from your password manager. Put it in the App
  Review field, **not in any file in this repo**.
- **Verify the account still works before you submit.** Sign in with it yourself first.
- Paste this into Review Notes:

  > Educational fertility and wellness app. Sign-in is required for all health features; demo
  > credentials are provided above. All health statements carry inline citations (NHS / EFSA /
  > NCBI-StatPearls / PubMed) — see Nutrition → "Why hydration?" → Sources, and Profile → Medical
  > Sources & Disclaimer. The pH tracker records vaginal pH for personal wellness tracking only; it
  > is not a medical device and not for contraception. Partner-linking code exists in the binary but
  > is unreachable behind a compile-time flag, because the same backend serves our Android app.

### 4f · Declarations
Content rights · Export compliance (**`ITSAppUsesNonExemptEncryption` is already false in the
binary**) · DSA trader status.

### 4g · Release setting
Choose **Manual release**, so nothing goes public without you pressing the button.

---

## 5 · Get it onto a real iPhone ⏱️ 45 min

**This app has never once run on physical hardware.** Seven checks are marked "deferred — no device",
and that is the largest untested surface in the release. One afternoon closes six of them.

Install from **TestFlight** (not Xcode — that would not be the shipping binary), then:

1. **Password reset, all nine steps** — `TESTFLIGHT_B20.md` §1. **Open the email on the same iPhone
   that asked for it**, or it will correctly refuse. Do not skip step 9 (tap the used link a second
   time); that is the most valuable single check on the list.
2. **Cold boot** — sign in, force quit, reopen. You must **not** be asked to sign in again.
3. **Sign in with Apple** on real hardware.
4. **Revocation** — iOS Settings → your name → Sign in with Apple → Genesyx → stop using. Return to
   the app; you should be signed out.
5. **Account deletion**, with **two throwaway accounts, never your own.** Delete one, confirm the
   other still sees its own data.
6. **Reminders** — turn them on from a fresh install and confirm one actually arrives.
7. **Mobile data** — turn off Wi-Fi, log something, walk into a dead zone, come back. Nothing should
   be lost and no false offline symbol should appear.

**Send me:** a pass/fail line per item. Screenshot anything that fails.

---

## 6 · Email the clinician ⏱️ 10 min — **do it early, it has the longest wait**

Send **`docs/CLINICAL_REVIEW_PACK.md`** to your reviewer. Ask for three things:

1. Sign-off on the **bundled 7-day guide PDF** (currently marked internal-use-only, D5).
2. Sign-off on the **new pH support copy** that shipped in build 20.
3. A short, accurate paragraph on **how vaginal pH relates to fertility** — non-absolute, no
   guarantees. This is the only thing standing between us and change-list item 1A-5.

Separately, chase the designer on the **two page-20 artwork corrections** in
`docs/FREE_GUIDE_DESIGNER_BRIEF.md`.

🟢 **Good news: none of this blocks launch.** 1A-5 and 1A-8 are client change-list items, not App
Store requirements. We ship 1.2.0 without them and add them in 1.2.1.

---

## 7 · Two website edits ⏱️ 20 min

Both on the Shopify privacy policy page.

1. **Name Resend.** Your sub-processor list names Supabase, Apple, Google, Shopify and Klaviyo, but
   the transactional email provider is unnamed. Either add *"Resend (transactional email)"* or move
   that processing to the EU region. Naming it is the ten-minute option.
2. **Reconcile the company name.** The policy's controller is **Genesyx Ltd**; the App Store will
   sell the app as **SF MEDIA & PR LTD**. A customer comparing the two sees two companies. Either add
   a line explaining the relationship, or make the App Store listing say Genesyx.

🔴 **Do NOT** publish the two pH science pages as a rush job. I checked them live today:
`/pages/vaginal-ph-fertility-science` is uncited marketing copy with the word *fertility* only in the
slug, and `/pages/shettles-method-evidence-limitations` says *"Coming soon"*. **Linking to either
from the app would be worse than linking to nothing**, and a "Medical evidence" button that opens
"Coming soon" is its own review risk. Leave them until the clinician answers task 6.

---

## 8 · Custom SMTP ⏱️ 30 min

Password reset and invite emails currently ride Supabase's built-in sender, which is rate-limited to
a handful per hour and documented as **not for production**.

Fine for a few internal testers today. **Not fine for external testers or public release** — and the
failure mode is identical to the bug build 20 was cut to fix: she asks for a reset and no email
arrives.

**Supabase → Project Settings → Authentication → SMTP Settings.** Use Resend (already a
sub-processor). Verify the sending domain, then send yourself one test reset.

---

## 9 · Five decisions I need from you ⏱️ 15 min

Quick answers; each one changes what build 21 contains.

| | Question | My recommendation |
|---|---|---|
| **G1** | The Shettles article is dated **8 Nov 2026**, so it is invisible for the entire launch window. Move it earlier? | Move it to week 1 or accept it is post-launch |
| **G2** | The 12-week programme is anchored to absolute dates, **23 Aug → 8 Nov**. Today **0 of 12 articles are readable**; the first unlocks in 5 days. Fine? | Fine — the screen shows "Arrives 23 Aug", so it reads as a schedule, not an empty app |
| **G3** | **Two different numbers are both labelled "streak."** Home shows a hydration-only streak; Insights labels the daily-logging streak "Daily streak". Both calculations are right; the labels are wrong. | **Fix this** — it is the most customer-visible Partial and it is a copy change |
| **G4** | Recipes were **added beneath** the food list; you asked for them to **replace** it. | Two-line reorder — tell me yes or no |
| **G5** | Profile → Current focus → **Pregnancy** opens a screen ending *"Coming soon."* I confirmed it is in the shipping binary. Guideline 2.1 rejects placeholder content. | **Remove the segment.** Cheapest possible insurance against a rejection |

---

## What I do, the moment you send each thing

| You send | I do |
|---|---|
| "Article 9 = A" | Nothing — no build 21 needed on that count |
| "Article 9 = B" | Consent screen, `consented_at`, Android parity, tests |
| "Apple secrets are in" | Implement `/auth/revoke` in `delete_account`, deploy, verify version **and** bundle hash |
| G3/G4/G5 answers | The copy and ordering fixes |
| ~~"Regenerate screenshots"~~ | ✅ Done 18 Aug — seven captures, see 4b |
| Device pass results | Write them up as evidence, or fix what failed |

⚠️ **Until you answer, I will not touch `App/` or `Sources/`.** The source tree is byte-identical to
the signed build-20 IPA. The moment I edit one Swift file that IPA is dead and we re-archive. So I
would rather collect every change and cut **one** build 21 than burn four archives.

---

## Realistically, when does this launch?

| If | Then |
|---|---|
| Article 9 = A, and you defer the pH content to 1.2.1 | **Submit in 2–3 days**, live in ~1 week |
| Article 9 = B (consent must be built) | **Submit in ~1.5 weeks**, live in ~2.5 weeks |
| You wait for the clinician before submitting | However long they take — **and you do not need to** |

**The fastest honest path: Article 9 = A, ship 1.2.0 without the pH science links, add them in
1.2.1.** Nothing in that plan is dishonest — those two items are your change list, not Apple's
requirements.

---

## Today's finish line

If you get through tasks 1–8, then by tonight:

- ✅ Build 20 is on a real iPhone and has been walked end to end
- ✅ The App Store Connect record is complete and ready to attach a build
- ✅ Every legal, key and content decision that was waiting on you is answered
- ✅ The only things left are a clinician's reply, my `/auth/revoke` work, and Apple's queue

That is genuinely a day's work, and it moves the release from *"blocked on Lucas"* to *"blocked on
Apple"* — which is the last honest step before shipping.
