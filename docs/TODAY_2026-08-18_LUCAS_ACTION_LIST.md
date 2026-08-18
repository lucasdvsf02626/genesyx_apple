# Today's action list — Lucas · 18 August 2026

> ## ⛔ Read this before anything below it
>
> **Corrected 18 August 2026, after checking App Store Connect in the browser rather than reasoning
> from the repo.** Two assumptions this list was built on were false, and one of them changes what
> the job actually is.
>
> 1. **Genesyx is already live on the App Store.** Version **1.1.0** is "Ready for Distribution" and
>    the public page loads at `apps.apple.com/gb/app/genesyx/id6787682466` — 13+, Health & Fitness,
>    developer SF MEDIA & PR LTD. **This is not a first submission. It is an update to a shipped
>    app.** Everything in §4 is a revision of a live record, not a blank form.
> 2. **Because of (1), `APPLE_REVOKE_REQUIRED=true` is not the harmless early flip it was recorded
>    as.** That decision rested on "nothing has ever shipped, so the only pre-21 installs are our own
>    TestFlight accounts". There are real users on 1.1.0, and an Apple-signed one who asks to delete
>    their account is refused **today**. See `LAUNCH_READINESS.md` §9.2 — the decision is reopened.
>
> What was confirmed *good*: **build 21 has never been uploaded**, the highest build ever sent to
> App Store Connect is **1.1.1 (16)** on 24 July, so the number is free and there is no duplicate to
> work around.

> **Honest framing first.** You cannot *publish* today. Apple review alone is 24–48 h after you
> submit, and two items on this list depend on other people replying. What you **can** finish today
> is **every single thing that is waiting on you** — and get build 21 into TestFlight on a real
> phone. Do that and the release stops being blocked by you and starts being blocked only by a
> clinician, a lawyer's sentence, and Apple's queue.
>
> **Total time: about 4–5 hours.** Do them in this order — each one unblocks the next.
>
> Status of the code, so you know what you are working against: **1.2.0 build 21 is archived and
> signed** at `~/Desktop/Genesyx-b21.xcarchive`. The exported IPA under `build/Export/` is the older
> **build 20** and must not be uploaded — see §3. 431 tests pass, 0 fail, 0 skip. Nothing on this
> list is Swift.

---

## ⏱️ The order, at a glance

| # | Task | Time | Unblocks |
|---|---|---|---|
| 1 | **Decide the Article 9 basis** | 15 min | Everything. Decides whether there is a build 21 at all |
| 2 | **Generate the Apple `.p8` key → Supabase** | 20 min | The last piece of engineering Apple demands |
| 3 | **Upload build 21 to TestFlight** | 30 min | Puts a real binary on a real phone; surfaces ASC problems early |
| 4 | **Revise the App Store Connect record** | 1 h | Already populated for the live 1.1.0 — this is edits, not a blank form |
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

## 3 · Upload build 21 to TestFlight ⏱️ 30 min

You can do this **today, with none of the above resolved.** TestFlight does not require the legal or
content items — only public release does. Get the binary in hand.

⛔ **Upload build 21, not build 20.** This section said build 20 until 18 August and that is now
wrong. The build-20 archive (`build/Archives/Genesyx.xcarchive`, 17 Aug 23:18) and the only exported
IPA (`build/Export/Genesyx.ipa`) both predate the 18 August work: **no Article 9 consent screen, and
no Apple authorization code sent at deletion.** Shipping it against a backend running
`APPLE_REVOKE_REQUIRED=true` would refuse every Apple-signed deletion. Ignore both.

1. Open **Xcode → Window → Organizer → Archives** and select **`Genesyx-b21.xcarchive`**
   — on the **Desktop**, not under `build/`. Verified 18 Aug: 1.2.0 **(21)**, created 12:04:34 GMT.
2. **Distribute App → App Store Connect → Upload.**
3. Confirm before pressing go: bundle `com.genesyx.app`, version **1.2.0**, build **21**, team
   **SF MEDIA & PR LTD (M5L3MM75SG)**, profile **Genesyx App Store**.
4. Wait for "Processing complete" in App Store Connect (usually 5–15 min).
5. **Internal testers only** for now. Do not add an external group until task 8 is done — the
   built-in email sender will not survive it.
6. Test Details notes: `docs/TESTFLIGHT_B20.md` is the newest set and is written for build 20, so it
   does not mention the consent screen or Apple revocation. Read it before pasting.

✅ **Checked for you, 18 August 2026, in App Store Connect → TestFlight → iOS builds.** The highest
build ever uploaded is **1.1.1 (16)**, on 24 July 2026. Builds 17 through 21 have never been
uploaded. **Build 21 is free — there is no duplicate to collide with and no renumbering to do.**
The only build currently in Testing is 16 (expires in 65 days; 9 invites, 3 installs, 26 sessions).

---

## 4 · App Store Connect record ⏱️ 2 hours — the big one

⛔ **"None of this has ever been filled in" was wrong.** Checked in App Store Connect on 18 August:
**Genesyx 1.1.0 is live on the App Store** and every field below was filled in to get it there —
listing, screenshots, App Privacy (published a month ago), age rating, review notes and demo
credentials. This is **not** a blank record you are creating. It is a **shipped** record you are
revising for 1.2.0, and revising it wrongly is worse than leaving a blank, because a live listing
that no longer matches the binary is a 2.3.1 misrepresentation.

Read §4a–§4f as *edits against what is already there*, not as first drafts. What is actually in the
record today, and what each item really needs, is set out under each heading. Drafted copy is in
**`docs/APP_STORE_LISTING.md`**.

⚠️ **There is no 1.2.0 version record yet.** The iOS versions in App Store Connect are 1.1.0 (Ready
for Distribution) and **1.1.1 (Prepare for Submission, with build 16 already attached and never
submitted)**. Before build 21 can be attached to anything you must either retarget 1.1.1 or add a
new 1.2.0 version. Decide which — retargeting 1.1.1 silently discards the 1.1.1 metadata edits
already made.

### 4a · Listing — already written and live; these are edits, not first drafts
All of it is populated. Category is already **Health & Fitness**, support and marketing URLs are both
`https://genesyx.co.uk`, keywords are
`cycle,period,fertility,ovulation,ph,urine,nutrition,supplements,hydration,women,health,tracker,ttc`,
copyright is `© 2026 Genesyx. All rights reserved.` Three things are actually wrong:

- 🔴 **The live description advertises partner linking.** It carries a `PARTNER LINKING` section
  ("Invite a partner to link accounts…"), and build 21 ships `FeatureFlags.partnerInvites = false`.
  The moment 1.2.0 replaces 1.1.0, that paragraph describes a feature the binary does not expose.
  **Delete the whole section**, and check the screenshots too — the live Profile capture shows an
  "Add your partner" control. This was already flagged here; it is now confirmed live, not
  hypothetical.
- 🟠 **The promotional text breaks house style twice** in one sentence: an em dash used as a
  connector, and the phrase *"your fertility journey"*, which is on the banned list the tests
  enforce for in-app copy. The App Store fields are not covered by those tests, which is precisely
  why it slipped through. Rewrite it.
- 🟠 **Copyright says "Genesyx"** while the store shows the developer as **SF MEDIA & PR LTD** and
  the privacy policy names **Genesyx Ltd** as controller. Three names for one product. Worth
  settling with whoever owns the entity question before 1.2.0.

### 4b · Screenshots — ✅ **DONE, this is off your list**
`docs/appstore_screenshots/` now holds **seven** fresh captures from the build 21 tree, all
1320 × 2868 and alpha-flattened: 1-Home, 2-Track, **3-pH**, 4-Nutrition, 5-Insights, 6-Learn,
7-Profile. The July six are deleted. Upload these.

They show the app as it actually is now: seven tabs, light default, egg artwork, and the consent
control on Profile. The account in them is the fictional Maya, so nothing real is exposed.
Note the numbering shifted — pH is new at position 3, so old "screenshot 3" meant Nutrition.

**What is uploaded today, for contrast:** five screenshots, under **iPhone 6.5" Display only**, from
the July build. They show the pre-consent Profile with "Add your partner", and no pH tab. Our seven
are 1320 × 2868, which is the **6.9"** slot — the size Apple wants for new submissions. Delete the
old five rather than mixing sizes.

### 4c · App Privacy — ✅ already published, one omission to check
Published a month ago. It declares **three** data types, all *Linked to the user's identity* and all
*Used for App Functionality*: **Email Address**, **Health**, **User ID**. No tracking, no
advertising — both correct. Privacy Policy URL is set to `https://genesyx.co.uk/policies/privacy-policy`.

🟠 **What is missing against the real data flows:** free-text **notes** are collected and are
"User Content" in Apple's taxonomy, which is not among the three declared. Confirm whether notes
still persist to the backend in build 21; if they do, add User Content before submitting.
Sub-processors for your own records: **Supabase** (database + auth), **Apple** and **Google**
(sign-in), **Resend** (transactional email — see task 7).

### 4d · Age rating — ✅ already answered; live at **13+**, not 16+/18+
This section previously said "expect 16+ or 18+". The questionnaire has in fact been completed and
the app is live at **13+** (172 countries; 12+ in Vietnam and Korea, A12 in Brazil). The two answers
that produced it:

- *Medical or Treatment Information* → **Infrequent**
- *Health or Wellness Topics* ("content that provides self-care or lifestyle recommendations") → **No**
- Everything under Sexuality or Nudity → **None**

🟠 **That second answer looks wrong.** The app gives hydration targets, phase-aware focus foods and a
supplement plan; that is self-care and lifestyle recommendation by Apple's own definition. Changing
it to Yes may raise the rating, which is the honest outcome and the one this list asked for. Note
the app has already been rejected once under **Guideline 1.4.1** (see 4e), so understating health
content is the exact axis review is sensitive to here.

### 4e · Review notes — ✅ already filled in on 1.1.1; verify, do not rewrite
Every private tab is behind a sign-in wall, and **without credentials a reviewer sees a login screen
and rejects under Guideline 2.1.** The 1.1.1 record already carries a full set: sign-in required is
ticked, the account is **`demo@genesyx.co.uk`** with a password, contact details are Lucas Dvalenca
with phone and email, notes are written, and a screenshot attachment is present.

🔴 **The live 1.1.0 record is a different story.** Its reviewer sign-in is
**`lucas@mysupplementfactory.com`** — your own personal account — with a weak password stored in
plain text in App Store Connect. Change it to the demo account and rotate that password wherever
else it is used. It is not something to leave sitting in a submission record.

🟠 **The existing notes are stale.** They open by answering **Guideline 1.4.1** for **build 13** —
so the app has been rejected before, on health-information grounds, and these notes are the reply.
They say nothing about the Article 9 consent screen or Apple token revocation, both new in build 21.
Rewrite for 1.2.0 rather than resubmitting July's defence.

- **Verify the demo account still works before you submit.** Sign in with it yourself first.
- Replace the notes with this:

  > Educational fertility and wellness app. Sign-in is required for all health features; demo
  > credentials are provided above. All health statements carry inline citations (NHS / EFSA /
  > NCBI-StatPearls / PubMed) — see Nutrition → "Why hydration?" → Sources, and Profile → Medical
  > Sources & Disclaimer. The pH tracker records vaginal pH for personal wellness tracking only; it
  > is not a medical device and not for contraception. Partner-linking code exists in the binary but
  > is unreachable behind a compile-time flag, because the same backend serves our Android app.
  > New in this version: an explicit opt-in screen is shown before any health question is asked, and
  > it can be withdrawn at any time from Profile; and deleting an account signed in with Apple
  > revokes the Apple token before any data is erased.

### 4f · Declarations
Content rights (**already answered Yes**) · Export compliance
(**`ITSAppUsesNonExemptEncryption` is already false in the binary**) · DSA trader status
(**already declared: "this developer has identified itself as a trader for this app"**).

### 4g · Release setting
Choose **Manual release**, so nothing goes public without you pressing the button. Already set that
way on both existing version records, so this is a check rather than a change.

### 4h · 🟠 Stray macOS platform record
A **macOS App 1.0, Prepare for Submission** record exists alongside the iOS one, holding a single
placeholder screenshot of the app icon on a gradient and nothing else. Nobody has explained it. It
does not block the iOS submission, but it is a half-built product page attached to a live app, and
the public listing already reads "Not verified for macOS". Delete it unless someone intended it.

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

⚠️ **Until you answer, I will not touch `App/` or `Sources/`.** *Written against build 20; the same
rule now applies to build 21.* The source tree is byte-identical to the signed **build-21** archive
on the Desktop — `git diff v1.2.0-b21 -- App/ Sources/ Tests/` is empty. The moment one Swift file
changes, that archive is dead and we re-archive as build 22. So I would rather collect every change
and cut one build than burn four archives.

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
