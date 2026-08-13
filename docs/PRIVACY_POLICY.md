# Genesyx — Privacy Policy

_Last updated: 13 August 2026 · Data controller: SF MEDIA & PR LTD · Contact: hello@genesyx.co.uk_

> ⚠️ **DRAFT — NEEDS SIGN-OFF BEFORE PUBLISHING.** This was rewritten on 2026-08-13 because the
> previous version was factually wrong about this build: it said the app collected nothing, had no
> accounts and no servers, at a point when it had all three. That version must not be published.
>
> This replacement describes what the code actually does, verified against `SupabaseBackend.swift`,
> the `supabase/migrations/`, and the six Edge Functions. It is **not legal advice.** Health data is
> special-category data under UK GDPR Article 9, so have a practitioner check this before release.
>
> The brackets were filled on 13 Aug from sources, not guesses: the controller is the name the build
> is signed with (`Apple Distribution: SF MEDIA & PR LTD`, team `M5L3MM75SG`); the Supabase region is
> `eu-west-1` from `supabase projects list`; Resend is the US endpoint the invite function actually
> calls. **Three things still need a human:**
> 1. **Registered office address** — omitted rather than invented. Take it from Companies House.
> 2. **`hello@genesyx.co.uk` must be monitored.** It is the invite sender address; this policy now
>    also makes it the address for UK GDPR rights requests, which carry a one-month deadline.
> 3. **The children's age must match the App Store age rating**, which has not been set yet.
>
> Host this page at a public URL and paste it into App Store Connect → App Privacy → Privacy Policy
> URL. It must agree with the App Privacy answers in `APP_STORE_SUBMISSION.md` §2 — App Review reads
> both, and the previous mismatch was a rejection risk in its own right.

## Summary

Genesyx is a fertility-preparation and cycle-tracking companion. To sync your information between
devices and to let you share progress with a partner, Genesyx uses an **account** and stores your
data on **our cloud provider's servers**. We do not sell your data, we do not use it for advertising,
and there is no third-party analytics or tracking in the app.

You can delete your account and everything in it from inside the app at any time
(**Profile → Delete account**).

## Who we are

**SF MEDIA & PR LTD** is the data controller for the personal data described here.
Contact: **hello@genesyx.co.uk**.

<!-- TODO before publishing: add the registered office address from Companies House. Left out
     deliberately rather than guessed. -->


## What we collect

**Account information**
- Email address
- A user ID we generate for you
- Display name, if you set one
- Whether you signed in with a password, Google, or Apple

**Health and wellbeing information you choose to enter.** This is *special-category data* under UK
GDPR Article 9 and we treat it accordingly:
- Cycle dates and cycle settings
- Vaginal pH readings (older entries may be recorded as urine pH, which earlier versions of the app
  tracked instead)
- Daily logs: mood, energy, symptoms, sleep, supplements, hydration, food groups, and free-text notes
- Sexual activity, if you choose to log it
- Your answers to the onboarding questions, including your stated preference about a baby's sex if
  you gave one

**Partner linking**
- The email address you enter when inviting a partner, and the status of that invitation

We do **not** collect analytics, advertising identifiers, location, contacts, or your device's
address book.

## Why we collect it, and our legal basis

| What | Why | Legal basis (UK GDPR) |
|---|---|---|
| Account information | To create your account, sign you in, and keep your data yours | Article 6(1)(b) — performance of a contract |
| Health and wellbeing entries | To show you your own history, trends and guidance | Article 6(1)(b) **and** Article 9(2)(a) — your explicit consent |
| Partner invitation email | To send the invitation you asked us to send | Article 6(1)(b) |
| Security and abuse prevention | To keep accounts safe | Article 6(1)(f) — legitimate interests |

You can withdraw consent for the health data at any time by deleting the entries or your account.
Withdrawing does not affect processing that already happened.

## Who processes it

We use these providers. They act on our instructions and may not use your data for their own purposes.

| Provider | What it does | Where |
|---|---|---|
| Supabase | Database, authentication, and the server functions behind account deletion and partner invites. **This is where your health entries are stored.** | Ireland (EU) — project region `eu-west-1` |
| Resend | Sends the partner-invitation email only. It receives the recipient's email address and the invitation text, and no health data. | United States |
| Google / Apple | Only if you choose to sign in with them. They tell us you signed in successfully; we do not receive your password. | United States |

**Transfers outside the UK.** Your health entries stay in the EU, and the UK Government has found
the EEA to provide an adequate level of protection, so no additional safeguard is needed for them.
The partner-invitation email is the one thing that leaves for the United States, and it carries an
email address, not health data; that transfer relies on the UK International Data Transfer Addendum
to the EU SCCs in the provider's data-processing terms.

<!-- TODO before publishing: confirm the Resend and Google/Apple DPAs are actually countersigned /
     accepted for this account, and that Resend's UK Addendum is the version in force. The regions
     above are verified (supabase projects list -> eu-west-1; send_partner_invite/index.ts:22 calls
     the global https://api.resend.com/emails, not the EU endpoint) — the paperwork is not. If you
     would rather avoid the US transfer entirely, Resend has an EU region and switching that
     endpoint is a one-line change. -->


## Sharing with your partner

Partner linking is optional and off unless you start it.

- When you invite someone, we email the address you typed, with a link to accept.
- **If they accept, they can see your display name.** That is the whole of what the app shows them
  today. They cannot see your logs, your pH readings, your cycle, or your notes.
- Either of you can unlink at any time, which stops that access immediately.
- You can revoke an invitation before it is accepted.

We do not sell, rent, or trade your data, and we do not share it with anyone else except the
providers listed above, or where the law requires it.

## How long we keep it

We keep your data until you delete it. Deleting your account removes your profile, cycle settings,
daily logs, pH readings, onboarding answers, and partner invitations — including invitations that
were addressed **to** your email address. This happens straight away, not on a schedule.

## Your rights

Under UK GDPR you can ask us to: give you a copy of your data; correct it; delete it; restrict or
object to how we use it; or provide it in a portable form. Email **hello@genesyx.co.uk** and we
will respond within one month.

You can delete everything yourself, immediately, in **Profile → Delete account**.

If you are unhappy with how we handle your data you can complain to the Information Commissioner's
Office (ICO) at [ico.org.uk](https://ico.org.uk), or to your local supervisory authority.

## Security

Data is transmitted over encrypted connections and stored with access rules that restrict every row
to the account that created it. No system is perfectly secure, but we do not expose your entries to
other users except through the partner link described above, which you control.

## Children

Genesyx is intended for adults and is not directed to children under 18. We do not knowingly collect
data from children. If you believe a child has given us their information, email
**hello@genesyx.co.uk** and we will delete it.

<!-- TODO before publishing: 18 is chosen to match what the app is — a fertility-preparation tool
     that logs sexual activity — and it is the strictest defensible line. It is NOT yet backed by an
     App Store age rating, because the questionnaire in APP_STORE_SUBMISSION.md §3 has not been
     completed. Whatever rating you select there must not be lower than the number in this sentence,
     or the two public documents disagree again. -->


## Medical disclaimer

Genesyx provides general educational and wellness content. It is **not a medical device** and does
**not** provide medical advice, diagnosis, or treatment. Speak to a qualified healthcare
professional about anything concerning your health.

## Changes to this policy

If we change what we collect or why, we will update this page and change the date at the top. For
significant changes affecting your health data, we will tell you in the app.

## Contact

**hello@genesyx.co.uk**
