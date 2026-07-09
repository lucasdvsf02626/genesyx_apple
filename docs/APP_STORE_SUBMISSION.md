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
Genesyx is a gentle, premium companion for cycle awareness and fertility preparation.

CYCLE TRACKING
See your current phase (period, fertile window, ovulation, luteal), your day in the
cycle, and your predicted next period — with calm, phase-aware guidance.

URINE pH TRACKING
Log your urine pH and watch trends over 7/30/90 days, with optimal-range banding,
rolling averages, and a clear at-a-glance status.

PHASE-AWARE NUTRITION
Hydration tracking, focus foods that adapt to your phase, a personalised supplement
plan, and short, supportive articles.

DAILY LOG & INSIGHTS
Record mood, energy, symptoms, sleep, water and supplements. Genesyx turns your
entries into gentle insights — pH summaries, cycle regularity, symptom patterns, and
nutrition consistency.

PARTNER SUPPORT
Invite a partner to share your journey.

PREGNANCY PATHWAY
When you're ready, Genesyx gently shifts to support you through pregnancy.

Your account and data sync securely so they're there across sign-ins.

Genesyx provides educational wellness information only. It is not a medical device and
does not provide medical advice, diagnosis, or treatment, and should not be used for
contraception. Always consult a qualified healthcare professional about your health.
```

**Keywords (100 char, comma-sep, no spaces)**
`cycle,period,fertility,ovulation,ph,urine,nutrition,supplements,hydration,women,health,tracker,ttc`

**Support URL**: `https://genesyx.co.uk` (must resolve)
**Marketing URL** (optional): `https://genesyx.co.uk`
**Privacy Policy URL** (REQUIRED): `https://genesyx.co.uk/policies/privacy-policy`  ← verified live (200). NOTE: `/privacy` 404s — do NOT use it.

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
- Medical/Treatment Information: **Infrequent/Mild** (educational wellness, has disclaimer)
- Everything else: None
- Expected rating: **12+**. (Not 17+ — no mature content; keep the medical-disclaimer copy so it
  reads as educational, not clinical advice.)

---

## 4. Sign in with Apple note
Because we offer Google sign-in, **Sign in with Apple is required and is implemented** ✅.
Both must be tested on a real device before submission.

---

## 5. Pre-submission checklist

App / build:
- [x] Release build compiles, DEBUG seeding excluded (`#if DEBUG` verified)
- [x] Medical disclaimer (onboarding + Profile → About)
- [x] In-app account deletion (Profile → Delete account, wired to `delete_account`)
- [x] `PrivacyInfo.xcprivacy` declares Email + Health + User ID
- [x] `ITSAppUsesNonExemptEncryption = false` (skips export-compliance prompt)
- [ ] `DEVELOPMENT_TEAM` set in project.yml (need your Apple Team ID)
- [ ] Real-device test: email + Google + Apple sign-in; log pH/cycle; delete account

Assets:
- [x] Screenshots 6.9" (1320×2868) — `docs/appstore_screenshots/`
- [x] App icon 1024 present
- [ ] (optional) 6.5" screenshots if you want to also target older devices

Store Connect:
- [ ] App record created (Health & Fitness)
- [ ] Metadata (section 1) entered
- [ ] Privacy labels (section 2) entered
- [ ] Age rating (section 3)
- [ ] Privacy Policy URL live at genesyx.co.uk/privacy

Backend (done):
- [x] Supabase auth (email/Google/Apple), tables, RLS, 3 edge functions — verified live
- [x] Confirm-email intentionally OFF for v1

Ship:
- [ ] Archive (Release) → upload via Xcode Organizer
- [ ] TestFlight internal test on device
- [ ] Submit for review
