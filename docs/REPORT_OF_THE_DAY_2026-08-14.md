# Genesyx iOS — Report of the day

**Date:** 14 Aug 2026
**Repo:** `/Users/lucasvalenca_sf/genesxy_apple.V1.02`
**HEAD:** `1b61e81` on `main` **plus** the uncommitted batches 1–9 tree
**Nothing committed, pushed, or deployed.**

This note covers two things: the H21 verification pass requested today, and a seeded-app walk of **Track**, **pH**, and **Insights** the way a user would see them.

Screenshots: `docs/day-report-assets/track.png`, `ph.png`, `insights.png`.

---

## 1. H21 — free guide (engineering Done)

The production CTA was confirmed as `onOpenGuide: { showGuide = true }`. A **fresh** backup was taken at `/tmp/onb_h21_prod_20260814T104552.swift`. The only temporary change was `onOpenGuide: { }`. `WaitlistView` was not rebuilt.

| Check | Result |
|---|---|
| Negative falsification | **Failed as required.** Exit **65**. `GenesyxUITests.swift:130` `XCTAssertTrue failed - the bundled PDF should render — a blank reader means it is not in the app bundle`. Duration **28.044 s**. |
| Restore | Copied back from the fresh backup. `cmp` byte-identical. md5 `b85686926825890766d64990ae2f747e`. **342 lines.** Zero `waitlist` / `joinWaitlist`. Sheet still presents `FreeGuideScreen()`. |
| `build-for-testing` | `** TEST BUILD SUCCEEDED **` |
| `FreeGuideBundleTests` | **3 / 0**, 0.003 s |
| Two guide UI tests | **2 / 0**, 32.091 s (Learn 11.351 s, onboarding 20.740 s) |
| PDF in built `.app` | 6,568,029 bytes, md5 `618149b77247080cc9061f971886d379`, **byte-identical** to the repo resource |
| Full `GenesyxUITests` | **67 executed, 1 skipped, 0 failures**, 785.545 s. `** TEST SUCCEEDED **`. Log: `/tmp/genesyx_h21_full_ui.log` |

Previous baseline was 66 executed + 1 skip. Net +1 is expected: the old waitlist UI test was replaced by two guide tests.

H21 is **Done** as engineering. Sections 1–3 stay **36/44 (82%)**. The PDF is **not** App Store-ready: filename/metadata, page-20 typo, page-20 QR/download CTA, accessibility tagging, and medical review all remain open.

---

## 2. Seeded walk — Track, pH, Insights

Launched `com.genesyx.app` on iPhone 17 with `-uiTestSeed YES` and `-uiTestTab` 1 / 2 / 4. Seeded Maya: last period 8 days ago (28/5), water 750 ml today, logs on yesterday and 3 days ago, vaginal pH 6.3 / 6.7 / 6.9.

### Track — data is running

- Header: **August 2026 · Cycle 1 · Day 9**. Matches `today − 8 days` as day 1.
- Period fill 6–10 Aug (five days). Ovulation on **19 Aug** (cycle day 14). Today (14) is ringed.
- Dots match the seed: pH on 9 / 12 / 14 (teal), symptoms/notes on 11 / 13 (brown).
- Phase card: **Follicular Phase · Fertile window** — “You're in your fertile window.” Day 9 is the first day of a day-14 ovulation window. Honest.
- All seven tabs visible. Track selected.

**Bug to fix — primary CTA clipped.** The purple **+ Add to today's log** button sits under the custom tab bar. The top of the bar is visible; the label is cut off. A user who does not scroll cannot reliably tap the main action on this screen. This is a layout bug, not a data bug.

**Visual check, not yet proven as an engine fault.** 17 Aug (cycle day 12, should be fertile) looks paler than 16 and 18, while 20 Aug (cycle day 15, after ovulation) still looks fertile-teal. Worth tapping those cells next. Do not treat this as confirmed until the day sheet is opened.

### pH — data is running

- Title **Vaginal pH**. Tracker, **+ Log pH**, safety copy, collapsible **Safety note**.
- Latest reading **6.9 · ELEVATED · 14 Aug at 11:03**. That is the seeded “now” reading.
- Range control **7d / 30d / 90d / All** with **30d** selected as a real selected state (not colour-only).
- Chart: three points, bands at 3.8 / 4.5 / 7.0. History **(3)** collapsed.
- Copy tells her to put cycle day in the **note** field. There is still no cycle-day control on the log sheet; that wording is the H15 correction, not a regression.

No crash, no urine-scale label, no empty chart. This tab is usable.

### Insights — data is running and visualising real logs

- **My logs** card present (opens history; UI-tested).
- **Consistency:** daily streak **4 days**, weekly **1 week**, Tue–Fri ticked, “4 of 7 days this week”.
  - Week of 10–16 Aug: Tue 11 log, Wed 12 pH, Thu 13 log, Fri 14 pH. Monday empty. That is the seed, not a mock.
- **Vaginal pH** card: current **6.9 ELEVATED**, ↑ vs previous, 7-day and 30-day averages both **6.63**.
  - (6.3 + 6.7 + 6.9) / 3 = 6.63. Both windows agree because all three readings sit inside seven days. Honest.
- GP / pharmacist line is on the card. No “regularity” claim on this first screen.

**Product risk, not a red crash.** The Insights pH card is the most clinical surface in the first viewport (value, ELEVATED, GP advice). A **Safety note** was added in H15 and is covered by `testInsightsPhCardKeepsTheDisclaimerOneTapAway`, but it is **not visible without scrolling** on this screenshot. A woman who only reads the first card never sees the small print.

---

## 3. What is working

| Surface | What a user can see / do |
|---|---|
| Track calendar | Period, fertile, ovulation, pH dots, symptom dots, day sheet, add-log (once she scrolls) |
| Track phase | Real day-of-cycle and fertile-window copy |
| pH tab | Log, latest value, elevated badge, range chart, 3-reading history, safety note |
| Insights | Streak from real days, pH trend from real readings, My logs |
| Cross-tab | Same 6.9 and the same dated logs appear on Track, pH, and Insights |

The full UI suite (including calendar marks, meal → Track/Insights, pH edit/delete, Insights history, sign-out wipe) is green against this tree.

---

## 4. Bugs / follow-ups (do not start these in this pass)

1. **Track — “Add to today's log” clipped by the tab bar.** Fix: give the scroll content a bottom inset equal to the custom tab bar, or lift the CTA. This is the one that should be fixed first if the goal is “a real user can log from Track.”
2. **Track — fertile fill on 17 Aug vs 20 Aug** looks inconsistent. Confirm by opening those day sheets before changing `CycleEngine`.
3. **Insights pH card — disclaimer below the fold.** Consider a one-line safety affordance in the first viewport, same as the pH tab.
4. **PDF guide** still needs the four content corrections and medical review. Not App Store-ready.
5. Already known, not iOS-code: website science/Shettles pages missing; cellular QA needs a physical iPhone; Android still has no food-group control.

---

## 5. Files touched in this verification pass

- `App/Genesyx/UI/Onboarding/OnboardingFlowView.swift` — one-line no-op, then **restored to the fresh backup** (no net change vs that backup).
- `docs/HANDOFF.md`, `docs/CHANGE_LIST_PLAN.md`, `docs/PROGRESS_CHECKLIST.md`, `GENESYX_PROGRESS.md` — H21 numbers and stale HEAD `d0b0c9f` → `1b61e81` + working tree.
- `docs/REPORT_OF_THE_DAY_2026-08-14.md` (this file) and `docs/day-report-assets/{track,ph,insights}.png`.

Stopped here. No further checklist item started.
