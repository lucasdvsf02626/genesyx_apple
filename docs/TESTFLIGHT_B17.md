# TestFlight — Genesyx 1.1.1 (17)

## "What to Test" (paste into TestFlight → Build 17 → Test Details)

This build adds several Track and Nutrition changes on top of the vaginal-pH update. Please focus on:

1. **Track tab order** — trackers now read Cycle → Vaginal pH → Nutrition → Symptoms → Sleep → Hydration. Check the order looks right and each row opens the correct detail.
2. **Vaginal pH detail** — open the pH tracker (Track → Vaginal pH, or Insights → Open tracker). Below the chart you should see four short sections: *Why pH matters*, *What this result means*, *What to do next*, and *Genesyx supplements* (with tappable sources). Log a reading and confirm the latest card and chart update immediately.
3. **Hydration in glasses** — hydration now shows in glasses by default (1 glass = 250 ml). In the Track hydration sheet, the quick-add buttons are +1 / +2 glasses. Switch **Profile → Hydration → Millilitres** and confirm everything flips to ml (your totals should be unchanged either way).
4. **Supplements** — Nutrition → Review Plan. Genesyx essentials appear first, then "Add your own supplement" (name, dose, time) with delete. Add a couple and confirm they persist after closing/reopening. *(Note: custom supplements are saved on-device in this build.)*
5. **Nutrition layout** — phase focus foods now lead the screen; hydration and articles sit below. A "coming soon" card marks meal suggestions / food preferences.
6. **General** — sign in with your test account, complete cycle setup, and sanity-check Home, Insights, and Learn.

Please report anything that looks wrong with a screenshot and the steps to reproduce. Thank you!

---

## Beta App Review Information (for the External test submission)

- **Sign-in required:** Yes.
- **Demo account:** `demo@genesyx.co.uk` / (password — from the password manager; do NOT paste into logs)
- **Verify path for reviewers:** Nutrition → expand "Why hydration?" → Sources footer; and Settings → Medical Sources & Disclaimer.
- **Notes:** Educational fertility/wellness app. All health statements carry inline citations (NHS / EFSA / NCBI-StatPearls / PubMed). The pH tracker records vaginal pH for personal wellness tracking only; it is not a medical device and not for contraception.

## What's NOT in this build (say so if asked)
- Custom-supplement **cloud sync** — local-only in build 17 (pending shared schema); works offline.
- **Meal suggestions / food preferences** — placeholder "coming soon" only.

## Build facts
- Version **1.1.1 (17)**, signed Apple Distribution (M5L3MM75SG), archive dated 2026-07-29.
- Contains build 16 (vaginal pH + citations) plus the Track/UX batch (reorder, pH spine, glasses hydration, manual supplements, Nutrition re-order).
