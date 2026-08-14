# Genesyx — App Store Submission Pack

Everything needed to fill out App Store Connect. Drafts below — edit voice/wording to taste.
Bundle ID `com.genesyx.app` · Category **Health & Fitness**.

---

## 1. Listing metadata (copy/paste into App Store Connect)

**App name (30 char max)**
`Genesyx: Cycle & Fertility`

**Subtitle (30 char max)**
`Cycle, pH & nutrition support`

**Promotional text (170 char, editable anytime)**
`Track your cycle, vaginal pH, and nutrition in one calm, private companion — with gentle, phase-aware guidance for your fertility journey.`

**Description**
```
Genesyx is a gentle companion for cycle awareness and fertility preparation.

CYCLE TRACKING
See your current phase (period, fertile window, ovulation, luteal), your day in the
cycle, and your predicted next period — with calm, phase-aware guidance.

VAGINAL pH TRACKING
Log your vaginal pH and review recent trends with clear acidic, optimal, and alkaline
guidance.

PHASE-AWARE NUTRITION
Hydration tracking, focus foods that adapt to your phase, a simple supplement
plan, and short, supportive articles.

DAILY LOG & INSIGHTS
Record mood, energy, symptoms, sleep, water and supplements. Genesyx turns the
entries you provide into gentle hydration, pH, symptom, sleep, and nutrition insights.

Your account and data sync securely so they're there across sign-ins.

Genesyx provides educational wellness information only. It is not a medical device and
does not provide medical advice, diagnosis, or treatment, and should not be used for
contraception. Always consult a qualified healthcare professional about your health.
```

> **A "PARTNER LINKING" paragraph was removed from the description above on 14 Aug 2026.** Partner
> linking is intentionally excluded from the 1.2.0 public release — `FeatureFlags.partnerInvites` is
> `false`, so no screen, control or deep link in the submitted build reaches it. Metadata must only
> describe what the build does (guideline 2.3.1), so do not paste that paragraph back until the flag
> ships as `true`. The keywords below never mentioned partners and are unchanged.

> **Widget and barcode/photo food logging are NOT in 1.2.0, and — unlike partner linking — nothing
> had to be removed here.** Checked line by line on 14 Aug 2026: neither the description above, the
> subtitle, the promotional text nor the keywords has ever mentioned a Home Screen widget, barcode
> scanning or photographing a meal, so this metadata already matches the build. Recording it because
> the risk runs the other way — someone adding "scan your food" or "widget" to the description would
> be describing a capability the binary structurally does not have (no camera or photo-library usage
> string, no extension target), and that is guideline 2.3.1. **Do not add either to any field until a
> build actually ships the feature.** `App/GenesyxTests/ReleaseScopeTests.swift` guards the app-side
> half; nothing can guard App Store Connect text except this note.

**Keywords (100 char, comma-sep, no spaces)**
`cycle,period,fertility,ovulation,ph,vaginal,nutrition,supplements,hydration,women,health,tracker,ttc`

**Support URL**: `https://genesyx.co.uk` (must resolve)
**Marketing URL** (optional): `https://genesyx.co.uk`
**Privacy Policy URL** (REQUIRED): `https://genesyx.co.uk/policies/privacy-policy`  ← verified live (200).

---

## 2. App Privacy answers (App Store Connect → App Privacy)

Answer "Yes, we collect data." Declare exactly these (all **Linked to the user**, **Not used for tracking**, purpose **App Functionality**):

| Category | Data type | Linked | Tracking | Purpose |
|----------|-----------|--------|----------|---------|
| Health & Fitness | **Health** (cycle, pH, symptoms, sleep) | Yes | No | App Functionality |
| Contact Info | **Email Address** | Yes | No | App Functionality |
| Contact Info | **Name** (display name) | Yes | No | App Functionality |
| Identifiers | **User ID** | Yes | No | App Functionality |
| User Content | **Other User Content** (free-text daily-log notes) | Yes | No | App Functionality |

Notes:
- **Reproductive/menstrual health is "sensitive"** — declare it under Health and do NOT use it
  for tracking/advertising. We don't.
- We do **not** use third-party analytics/ads → no Tracking, no Data Used to Track You.
- This matches the on-device `PrivacyInfo.xcprivacy`, which declares the same five types.
- **Name and Other User Content were added 13 Aug 2026** after a third-party audit caught both
  missing from the table *and* the manifest. Neither is optional: the display name upserts at
  `SupabaseBackend.swift:151` and is the one field a linked partner is shown (`:173`), and daily-log
  notes are free text (`DailyLog.swift:41`) that Health does not cover — she can type anything in
  there. Under-declaring is one of the most common 5.1.1 rejections. **The 1.2.0 (18) archive was
  built before this fix, so it must be re-archived before upload.**
- Account deletion is in-app (Profile → Delete account) — required by Guideline 5.1.1(v). ✅ built.
  ⬜ **Sign in with Apple token revocation is missing** from `delete_account` — Apple requires it
  where Sign in with Apple is offered. See P0-15 in `TESTFLIGHT_B18.md`.
- ⚠️ **These answers must agree with the policy at the Privacy Policy URL above** — App Review reads
  both. That is the **live page**, which is accurate. `docs/PRIVACY_POLICY.md` in this repo is an
  engineering reference and is *not* what gets published; an earlier note here claimed the published
  policy said the app collects nothing, which was false and has been retracted (see P0-10). The one
  real gap between the two is **Resend**, a US processor the live policy does not name.
- Keywords are at **exactly** the 100-character cap — adding anything means removing something.

---

## 3. Age rating questionnaire guidance
- Complete Apple's current questionnaire from the submitted build; do not select a target rating.
- Medical/Treatment Information: answer **Infrequent/Mild** if the current questionnaire treats
  the educational fertility and wellness guidance as medical/treatment information.
- The app contains no mature themes, gambling, violence, sexual content, or unrestricted web access.
- Keep the medical-disclaimer copy so the experience is clearly educational rather than clinical advice.

---

## 4. Sign in with Apple note
Because we offer Google sign-in, **Sign in with Apple is required and is implemented** ✅.
Both must be tested on a real device before submission.

---

## 5. App Review access and notes

Set **Sign-in required** to **Yes** and provide an active reviewer account that does not require
an OTP, inbox access, or a newly created social-login identity.

### Build 8 rejection and corrected reviewer access

Apple rejected version 1.0 (build 8) under Guideline 2.1 because the supplied reviewer email did
not exist in the production Supabase project. On 16 July 2026, the dedicated reviewer account was
created and email-confirmed in that same project. A fresh password login returned HTTP 200, and its
authenticated RLS session read one profile, one cycle setup, two daily logs, and three pH readings.
All seeded entries are fictional and exist only to make the review path complete.

Build 8 embeds this exact Supabase project URL and uses the same password-sign-in call as the
current source, so correcting the backend account fixes the rejected binary without requiring a
new build solely for this rejection.

Final resolution: version 1.0 build 8 was removed from the submission and replaced with the current
version 1.1.0 build 12. Build 12 was uploaded, processed, assigned to the internal TestFlight group,
and submitted on 16 July 2026 at 23:53 BST. App Store Connect status: **Waiting for Review**.

Run this immediately before every submission. The script prompts for the credentials securely,
does not print them, and removes its temporary authentication response:

```sh
zsh scripts/verify_review_account.sh
```

Do not commit the reviewer password or paste it into release logs.

Paste-ready Resolution Center reply after the App Review Information fields have been corrected:

```text
Hello App Review,

Thank you for identifying the sign-in issue. We found that the reviewer account had not been
created in the production authentication project used by build 8. The account is now active and
email-confirmed, and we have verified a fresh password sign-in against the production service.

The credentials in App Review Information have been updated. They do not require an OTP, email
access, or any additional setup. The account also contains fictional sample cycle, hydration, pH,
sleep, symptom, and supplement entries so all seven tabs and Insights can be reviewed immediately.

Please retry the sign-in using the updated App Review Information credentials. Thank you.
```

Paste-ready review notes (replace the placeholders before submission):

```text
Genesyx is an educational fertility-preparation and wellness tracker. It is not a medical device
and does not provide diagnosis, treatment, contraception, or medical advice.

Demo account:
Email: [REVIEWER EMAIL]
Password: [REVIEWER PASSWORD]

After signing in, the seven tabs are Home, Track, pH, Nutrition, Insights, Learn, and Profile. Sample
cycle, hydration, pH, sleep, symptom, and supplement entries should already be present in the demo
account so Insights can be reviewed. Account deletion is in Profile → Delete account. The privacy
policy is in Profile → About → Privacy Policy.

Note on partner linking: this release does not offer it. Our Android app shares one backend with
this one and does offer it, so the networking code for it is still compiled into this binary and
you may see it referenced in the app's shared source. It is switched off at compile time for this
release, and there is no screen, control, setting, gesture, or link in this build that reaches it.
```

> **Why there is no equivalent note for the widget or barcode scanning, and why one should not be
> added.** The partner note exists because partner *networking code is genuinely compiled into this
> binary* — Android shares the backend — so a reviewer reading the shared source could see it and
> reasonably ask. Widget and barcode have no counterpart: no target, no framework, no capture
> permission, not a line of code. There is nothing for a reviewer to notice, so a note explaining
> their absence would introduce two features into the review conversation that the metadata does not
> mention and the binary does not contain. Checked 14 Aug 2026; leave this block as it stands.

---

## 6. Pre-submission checklist

App / build:
- [x] Release build compiles, DEBUG seeding excluded (`#if DEBUG` verified) — **it did not, from
      `dad4afb` until 13 Aug 2026.** `AppContainer.swift` imported `GenesyxCore` inside `#if DEBUG`
      while the sign-out wipe referenced `CustomSupplement.storageKey` in release code. Every test
      target is a Debug build, so 236 + 233 + 46 green tests never touched it and only `archive`
      failed. Do not read a green suite as "it builds"
- [x] Signed App Store archive + local App Store Connect export succeed for version 1.1.0 (12)
- [x] **Signed archive for version 1.2.0 (18)** — `build/Genesyx_1.2.0_18.xcarchive`, 13 Aug 2026,
      `Apple Distribution: SF MEDIA & PR LTD (M5L3MM75SG)`, `com.genesyx.app`, dSYM present.
      **Re-archived later the same day** after `PrivacyInfo.xcprivacy` gained Name and Other User
      Content — the manifest is baked into the bundle, so the first cut was stale the moment it did.
      Verified in the archive itself: all five types present, 1.2.0 (18), same signing identity
- [x] Production App Review password login verified; fictional review data seeded
- [x] Medical disclaimer (onboarding + Profile → About)
- [x] Privacy policy linked in-app (Profile → About → Privacy Policy)
- [x] In-app account deletion (Profile → Delete account, wired to `delete_account`)
- [x] `PrivacyInfo.xcprivacy` declares Email + Health + User ID + Name + Other User Content
      (the last two added 13 Aug 2026; `plutil -lint` clean)
- [x] `ITSAppUsesNonExemptEncryption = false` (skips export-compliance prompt)
- [x] `DEVELOPMENT_TEAM` set in project.yml (`M5L3MM75SG`)
- [ ] Real-device test: email + Google + Apple sign-in; log pH/cycle; delete account

Assets:
- [x] Six current-build screenshots 6.9" (1320×2868, opaque PNG) — `docs/appstore_screenshots/`
- [x] App icon 1024 present
- [ ] (optional) 6.5" screenshots if you want to also target older devices

Screenshot order: Home, Track, Nutrition, Insights, Learn, Profile. To remove the alpha channel
from fresh Simulator captures, run:

```sh
zsh scripts/prepare_store_screenshots.sh INPUT_DIR docs/appstore_screenshots
```

Store Connect:
- [x] App record created (Health & Fitness)
- [x] Audited listing metadata entered for version 1.1.0
- [ ] Privacy labels (section 2) entered
- [ ] Updated age-rating questionnaire (section 3) completed
- [ ] Regulated-medical-device declaration completed
- [ ] EU Digital Services Act trader status completed
- [ ] Privacy Policy URL entered as `https://genesyx.co.uk/policies/privacy-policy`
- [x] Active App Review demo account created and backend preflight passed
- [x] Correct demo credentials + review notes entered in App Store Connect
- [x] Guideline 2.1 response sent to App Review

Backend (done):
- [x] Supabase auth (email/Google/Apple), tables, RLS, 3 edge functions — verified live
- [x] Confirm-email intentionally OFF for v1

Ship:
- [x] Signed version 1.1.0 build 12 uploaded and processed by App Store Connect
- [x] Build 12 assigned to the internal TestFlight group with test instructions
- [ ] Commit/freeze the exact submitted source tree for reproducibility
- [ ] TestFlight internal test on device
- [x] Submitted for review — **Waiting for Review** (16 July 2026, 23:53 BST)
- [x] Manual release selected — approval will not publish automatically

