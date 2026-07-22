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
`Track your cycle, urine pH, and nutrition in one calm, private companion — with gentle, phase-aware guidance for your fertility journey.`

**Description**
```
Genesyx is a gentle companion for cycle awareness and fertility preparation.

CYCLE TRACKING
See your current phase (period, fertile window, ovulation, luteal), your day in the
cycle, and your predicted next period — with calm, phase-aware guidance.

URINE pH TRACKING
Log your urine pH and review recent trends with clear acidic, optimal, and alkaline
guidance.

PHASE-AWARE NUTRITION
Hydration tracking, focus foods that adapt to your phase, a simple supplement
plan, and short, supportive articles.

DAILY LOG & INSIGHTS
Record mood, energy, symptoms, sleep, water and supplements. Genesyx turns the
entries you provide into gentle hydration, pH, symptom, sleep, and nutrition insights.

PARTNER LINKING
Invite a partner to link accounts. Genesyx shows who you are connected with while
your personal logs and health readings remain private to your account.

Your account and data sync securely so they're there across sign-ins.

Genesyx provides educational wellness information only. It is not a medical device and
does not provide medical advice, diagnosis, or treatment, and should not be used for
contraception. Always consult a qualified healthcare professional about your health.
```

**Keywords (100 char, comma-sep, no spaces)**
`cycle,period,fertility,ovulation,ph,urine,nutrition,supplements,hydration,women,health,tracker,ttc`

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
| Identifiers | **User ID** | Yes | No | App Functionality |

Notes:
- **Reproductive/menstrual health is "sensitive"** — declare it under Health and do NOT use it
  for tracking/advertising. We don't.
- We do **not** use third-party analytics/ads → no Tracking, no Data Used to Track You.
- This matches the on-device `PrivacyInfo.xcprivacy` (already updated to declare Email, Health, User ID).
- Account deletion is in-app (Profile → Delete account) — required by Guideline 5.1.1(v). ✅ built.

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
sleep, symptom, and supplement entries so all six tabs and Insights can be reviewed immediately.

Please retry the sign-in using the updated App Review Information credentials. Thank you.
```

Paste-ready review notes (replace the placeholders before submission):

```text
Genesyx is an educational fertility-preparation and wellness tracker. It is not a medical device
and does not provide diagnosis, treatment, contraception, or medical advice.

Demo account:
Email: [REVIEWER EMAIL]
Password: [REVIEWER PASSWORD]

After signing in, the six tabs are Home, Track, Nutrition, Insights, Learn, and Profile. Sample
cycle, hydration, pH, sleep, symptom, and supplement entries should already be present in the demo
account so Insights can be reviewed. Partner linking only shows the linked relationship; personal
logs and health readings remain private. Account deletion is in Profile → Delete account. The
privacy policy is in Profile → About → Privacy Policy.
```

---

## 6. Pre-submission checklist

App / build:
- [x] Release build compiles, DEBUG seeding excluded (`#if DEBUG` verified)
- [x] Signed App Store archive + local App Store Connect export succeed for version 1.1.0 (12)
- [x] Production App Review password login verified; fictional review data seeded
- [x] Medical disclaimer (onboarding + Profile → About)
- [x] Privacy policy linked in-app (Profile → About → Privacy Policy)
- [x] In-app account deletion (Profile → Delete account, wired to `delete_account`)
- [x] `PrivacyInfo.xcprivacy` declares Email + Health + User ID
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

