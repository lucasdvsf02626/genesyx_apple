# Genesyx — App Store Connect Listing (copy & answers)

Paste-ready metadata + the exact answers for the questionnaires. Tweak the voice to taste.
Everything here assumes the **local-only v1** (no accounts, no data collected).

## Core listing
- **App Name** (≤30): `Genesyx`
- **Subtitle** (≤30): `Fertility prep, gently guided`
- **Primary category:** Health & Fitness
- **Secondary category:** (optional) Lifestyle
- **Price:** Free
- **Bundle ID:** `com.genesyx.app`

## Promotional text (≤170, updatable anytime)
> A calm companion for your conception journey — track your cycle, log how you feel, follow
> phase-aware nutrition, and watch your urine-pH trends. Private by design, all on your device.

## Description
> **Genesyx is a gentle, premium companion for fertility preparation.** It blends cycle awareness,
> nutrition guidance, daily logging, and urine-pH tracking into one calm, easy space — so you feel
> informed and supported, at your own pace.
>
> **Understand your cycle**
> See your current phase, fertile window, and days until your next period on a clear monthly
> calendar. Set your cycle and period length in seconds.
>
> **Eat for your phase**
> Phase-aware focus foods, a simple supplement plan, hydration tracking, and short, friendly reads.
>
> **Log how you feel**
> Capture mood, energy, symptoms, sleep, water, supplements, and notes in a quick daily check-in.
>
> **Track your pH**
> Record urine-pH readings and see your trend with acidic / optimal / alkaline guidance and gentle,
> personalised observations.
>
> **Private by design**
> No account needed. No ads. No tracking. Everything you enter stays on your device.
>
> Genesyx offers general wellness and educational content and is not a medical device. It does not
> provide medical advice, diagnosis, or treatment.

## Keywords (≤100 chars, comma-separated, no spaces after commas)
`fertility,cycle,ovulation,period tracker,conception,ttc,fertile window,ph,nutrition,wellness`

## URLs
- **Support URL:** [https://your-site/support]  (required)
- **Marketing URL:** [https://your-site]        (optional)
- **Privacy Policy URL:** [host docs/PRIVACY_POLICY.md and paste the URL]  (required)

## App Privacy (the "nutrition label")
- **Data collection:** Select **"Data is not collected."** ✅ (true for v1 — nothing leaves the device.)
- That's the entire section for v1. (If/when Supabase is enabled, this changes — see PRIVACY_POLICY note.)

## Age rating questionnaire (answer honestly)
- Most categories: **None**.
- "Medical/Treatment Information": Genesyx is **wellness/educational**, not medical advice →
  answer **None / Infrequent-Mild** as fits. Expect a final rating around **12+** (possibly higher
  depending on Apple's current reproductive-health handling). Do **not** overstate medical capability.

## App Review notes (paste into "Notes")
> Genesyx is a local-only app: there is **no account and no login required** — set "Sign-In
> Required" to **No**. All data is stored on the device; there are no servers, ads, or tracking.
> To review: launch → tap "Get started" through onboarding → on Home tap "Start tracking" and pick
> a last-period date → explore Track, Nutrition (incl. "Log pH"), Insights, and Profile.

## App Access
- **Sign-in required:** No (v1 has no login). No demo account needed.

## Export compliance
- Uses only standard OS encryption (HTTPS-level). `ITSAppUsesNonExemptEncryption` is set to **NO**
  in the build, so you won't be prompted each upload.

## Screenshots (required: iPhone 6.7" — 1290 × 2796)
Capture from the running app (or the Xcode previews). Suggested set + captions:
1. **Home** — "Know your phase at a glance"
2. **Track** — "Your cycle on a calm calendar"
3. **Nutrition** — "Eat for your phase"
4. **Insights / pH** — "See your pH trends gently"
5. **Daily Log** — "A quick, kind daily check-in"

Tip: a free tool like Canva ("App Store screenshot" templates) works for framing + captions.

## Pre-submit checklist
- [ ] Build uploaded & processed in App Store Connect
- [ ] App Privacy = Data Not Collected
- [ ] Age rating completed
- [ ] Privacy Policy URL live
- [ ] Support URL live
- [ ] 6.7" screenshots uploaded
- [ ] App Review notes + App Access = no sign-in
- [ ] Pricing = Free → Submit for Review
