# Genesyx — Product Requirements & Strategy (Consolidated)

**Date:** July 2026
**Status of this document:** single reference point for how all Genesyx deliverables — app, website, pH test kit, supplements and marketing — align to one strategy.
**Language:** British English.

---

## Executive summary (2-minute read)

Genesyx is a **broad-appeal fertility and cycle-tracking platform**. Within it, **vaginal pH testing is the connective thread** that links the app, the test kit, the educational content and the supplements into one coherent customer journey.

The strategy is deliberate, not accidental. A pH-only app would serve a narrow purpose with little reason for daily engagement. Broad tracking (cycle, fertility, symptoms, nutrition, wellbeing) creates daily utility and retention — the proven model of the market leaders (Flo: 70+ trackable symptoms, hundreds of millions of users; Clue: 100M+ downloads). Against that engaged, trusting audience, pH is introduced **at the right moment** in the journey — with education first, a responsible result explanation, a recommended next step, and, where scientifically substantiated and compliant, a connection to Genesyx supplements and the test kit.

**Current release (external TestFlight beta; App Store submission pending).** The Phase 1 MVP is in external beta on TestFlight. It delivers core cycle & fertility tracking across six trackable signals, plus a **corrected pH module**: all urine-pH references and the incorrect 4.5–9.0 scale have been **removed** and replaced with correct **vaginal pH** content (normal range **3.8–4.5**). It also ships the reordered Track page (Cycle → pH → Nutrition → rest), the pH result journey (result → meaning → next step → Genesyx product link), a Genesyx-first supplements section with manual entry, hydration in glasses/cups as well as millilitres, a calendar with full, untruncated day information, and the Learn foundations. The MVP was never the final scope — its purpose is launch, user testing and iterating from real behavioural data.

**Where value comes from:** the app drives daily engagement; the website and targeted landing pages convert relevant visitors (with **vaginal pH as the lead differentiator**); Learn content and weekly email build understanding and ongoing engagement; the Genesyx kit and supplements are the commercial offering.

---

## 1. Product strategy

**Core strategy.** Genesyx is a broad fertility and cycle-tracking platform. Vaginal pH testing is the connective thread linking the four assets — **app, test kit, educational content, supplements** — so each reinforces the others rather than standing alone.

**Rationale.**
- **Daily utility drives retention.** A pH-only app is a single-purpose tool with little reason to open it day to day. Broad tracking — cycle phases, fertile window, symptoms, mood, energy, sleep, hydration, nutrition — gives users a reason to return daily.
- **Proven model.** Market leaders win on breadth and habit: Flo offers 70+ trackable symptoms and has hundreds of millions of users; Clue has 100M+ downloads. Genesyx follows the same engagement-first pattern, then differentiates on pH.
- **Right-moment introduction.** Because the audience is already engaged and trusting, vaginal pH is introduced at the appropriate stage of the journey — never forced on first open — so it lands as helpful, not gimmicky.

**This was a deliberate, agreed strategy** — a single connected product, not an accidental collection of features. Every feature earns its place by either creating daily engagement or advancing the pH → education → product journey.

---

## 2. The pH user journey (most important section)

The complete in-app vaginal pH journey, step by step:

1. **Education first.** Why vaginal pH matters for reproductive and vaginal health, including the normal range (**3.8–4.5**). Framed responsibly, with cited sources.
2. **Testing introduced at the right stage.** The test is surfaced at the appropriate point in the journey for an engaged user — **not forced on first open**.
3. **Result entry.** The user logs their vaginal pH test result.
4. **Result explanation.** What the result means, in plain, responsible language (per band: *Healthy* ≤ 4.5 / *Elevated* > 4.5).
5. **Recommended next step per band.** *Healthy:* keep logging so the trend stays meaningful. *Elevated:* a non-alarming signpost to speak to a GP, nurse or pharmacist if readings persist.
6. **Connection to Genesyx supplements & products** — surfaced where scientifically substantiated and compliant (see §7). Presented as a navigational link into the supplements area, not as a medical claim.
7. **Ongoing tracking.** pH results are visible over time alongside cycle data, so patterns emerge in context.

**Correction — done in the current release.** All **urine pH** references and the incorrect **4.5–9.0** scale have been **REMOVED** and replaced with correct **vaginal pH** content (normal range **3.8–4.5**; loggable scale 3.5–7.0, two-band Healthy/Elevated model). No "Urine pH" page or urine terminology remains user-facing. ✅ Corrected in the current build.

---

## 3. App structure & information architecture

- **Track page order (updated):** **Cycle → pH → Nutrition →** then the remaining tracking functions (mood, energy, symptoms, sleep, hydration, supplements). pH is promoted directly beneath cycle to reflect its role as the differentiator.
- **Supplements:** Genesyx products are featured **prominently and first**; users can also **add their own supplements manually** (name, dose, time). *(Manual entries are stored on-device in the current build; cloud sync follows once the shared schema is finalised — see §4/§7.)*
- **Hydration:** trackable in **glasses/cups** (1 glass = 250 ml) as well as **millilitres**; the unit is a display preference and does not change stored data.
- **Calendar:** improved display — **no truncated "…" entries**; full day information is readable, with a tap-through day detail sheet.
- **Nutrition:** focused on **practical recommendations and food preferences**, with **meal suggestions planned for a later phase**. Hydration and generic articles are supporting elements, **not** the core of Nutrition.

---

## 4. Phased roadmap

The MVP was never the final scope; its purpose is launch, user testing and iterating from real behavioural data.

| Phase | Status | Scope |
|---|---|---|
| **Phase 1 — MVP** | **Shipped to external TestFlight beta; App Store submission pending** | Core cycle & fertility tracking; six trackable signals (cycle, symptoms, mood, energy, sleep, hydration); **corrected pH module & journey** (vaginal, 3.8–4.5); Track reorder (Cycle → pH → Nutrition → rest); supplements section with Genesyx prominent + manual entry; hydration units (glasses/ml); calendar fix; Learn section foundations. |
| **Phase 2** | Planned | Deeper nutrition recommendations & food preferences; personalised recommendations; expanded pH education; notification logic & personalised patterns; stronger content-to-product connections; custom-supplement cloud sync. |
| **Phase 3** | Planned | Meal suggestions; advanced personalisation from behavioural data; expanded product-ecosystem integration. |

---

## 5. Ecosystem map

Each element plays a distinct role in **one** customer journey. Diagram (left → right is the typical acquisition-to-retention flow):

```
        Ads / Email / UGC
               │
        Targeted landing pages ──► Website (genesyx.co.uk)
               │                          │
               ▼                          ▼
        App download  ◄───────────  Brand + conversion
               │
               ▼
   ┌───────────────────────────────────────────────┐
   │  APP  (daily value, repeat engagement)          │
   │   cycle · fertility · symptoms · nutrition      │
   │   ── pH journey ──►  Genesyx kit & supplements  │
   │   Learn section (credibility)                   │
   └───────────────────────────────────────────────┘
               ▲                          │
               │                          ▼
        Weekly email  ◄──────────  Kit & supplement sales
     (ongoing engagement,          (the commercial offering)
      new features & products)
```

| Element | Role in the journey |
|---|---|
| **App** | Daily value and repeat engagement — the retention engine. |
| **Website (genesyx.co.uk)** | Explains the brand and what problem Genesyx solves; converts relevant visitors. |
| **Targeted landing pages** | Speak to specific interests (pH education, app download) for ads / email / UGC campaigns. |
| **Educational content & Learn section** | Build understanding and credibility. Topics: vaginal pH awareness; cycle phases & fertile window; nutrition by cycle phase; preparing data for healthcare conversations. |
| **Weekly email marketing** | Ongoing engagement; introduces new functionality and products. |
| **Genesyx kit & supplements** | The commercial offering — the kit: **3 months of capsules, ovulation sticks, and vaginal pH test strips in a premium reusable box**. |

---

## 6. Website requirements

The website must clearly communicate:
- **What Genesyx is** and what problem it solves.
- **Why vaginal pH is relevant to fertility.**
- **How the test, app and supplements work together.**
- **What users gain from downloading the app.**

**Positioning:** vaginal pH is the **lead topic on landing pages** — it is Genesyx's key differentiator among cycle trackers. General cycle-tracking parity is table stakes; pH is the hook.

---

## 7. Scientific & regulatory compliance

- **Shettles method:** educational content may reference it, but **all references to gender selection / family balancing must be carefully worded, properly substantiated, responsible and compliant before publication.** Nothing in this area ships without review. *(The onboarding quiz has already had an unsupported diet/sex-selection claim removed.)*
- **Medical devices:** the **pH test strips and ovulation sticks are medical devices** — licensed to Genesyx via a manufacturer under **UK/EU safety registration, with an appointed UK responsible person.**
- **Product claims:** **all claims connecting pH results to supplements are subject to scientific and regulatory review.** In-app, the pH → supplements link is currently framed as navigation/wellbeing, carrying no causal medical claim, and all health statements use the cited-sources infrastructure (NHS / EFSA / NCBI-StatPearls / PubMed) to remain App Store Guideline 1.4.1 compliant.

---

## 8. Success metrics

| Metric | What it tells us |
|---|---|
| App downloads | Top-of-funnel acquisition |
| DAU / WAU retention | Daily-utility thesis is working |
| Tracking frequency | Depth of engagement / habit formation |
| pH test engagement rate | The differentiator is being adopted |
| Learn content engagement | Credibility & education are landing |
| Email opt-in & engagement | Owned-channel retention |
| Landing page conversion rate | Ad/UGC efficiency |
| Kit / supplement conversions | Commercial outcome |

---

## Appendix — current-build verification (app, TestFlight 1.1.1)

Verified in the codebase this cycle: vaginal-only pH (no urine terms, 3.8–4.5 normal band); pH result journey present (result → meaning → next step → Genesyx product link, with cited sources); Track order Cycle → pH → Nutrition → rest; Genesyx-first supplements + manual entry; hydration glasses/ml; calendar with no truncation; Nutrition recommendations-first with meal suggestions deferred to a later phase. Full automated suite green. Custom-supplement cloud sync is intentionally deferred pending the shared schema.
