# Genesyx — Feature Overview

Genesyx is a SwiftUI iOS app for cycle-aware fertility and wellness tracking. All insights are
computed from the user's own logged data (no mock values). Storage is local-first and syncs to
Supabase; data is wiped locally on sign-out.

## Authentication & onboarding
- Sign up / sign in with **email + password**, **Sign in with Apple**, and **Continue with Google**
  (token exchange via Supabase).
- Onboarding ends at a **sign-in gate** — the main dashboard unlocks only after authentication.
- **Cycle setup** (last period date + cycle length) drives every phase/ovulation prediction.

## Home
- Personalised greeting and a **current cycle-phase hero** (phase, cycle day, days to next period,
  predicted ovulation).
- **Today's focus** food card, a **hydration ring** (synced from Track), a compact **"Check your pH"**
  nudge that jumps to the pH tracker, and a **Log today** shortcut.

## Track
- Month **calendar** colour-coded by phase (period / fertile window / ovulation / luteal / follicular).
- **Current-phase card** and an editable **cycle-settings** sheet.
- **Trackers list** — Cycle, Hydration, **Vaginal pH**, Sleep, Symptoms, Nutrition — each opening a
  detail sheet with history and a de-pressured insight line.
- **Add to today's log** entry point.

## Nutrition
- Phase-aware **focus foods**.
- **Hydration coach**: daily goal, time-of-day coaching line, weekly streak, and an expandable
  **"Why hydration?"** explainer with cited sources.
- The **vaginal-pH tracker card** (log + trend chart).
- A **supplement plan** overview.
- Links to relevant **Learn** articles.

## Insights (all from real logged data)
- **Consistency** — daily/weekly streaks and a week-dots row.
- **Vaginal pH** — current reading, 7-/30-day averages, trend, cycle-tied caveat.
- **Hydration** — weekly bar chart vs goal, days-on-goal, week-over-week delta.
- **Nutrition consistency** — supplements logged per day this week.
- **Sleep** — nightly hours this ISO week, nightly average, nights logged.
- **Current cycle length** — her configured cycle length vs the typical 21–35 day range. Not a regularity measure: there is no per-cycle history to compute one from.
- **Symptom patterns** — 4×7 (28-day) heatmap of logged symptoms, tap-through to that day's log.
- **Ovulation** — predicted ovulation day + fertile window on a cycle timeline.
- **My Logs** — full history of daily entries.

## Learn
- 30 bundled articles and guides across Getting started, Tracking, Nutrition, Insights, Wellness and
  Guides. 19 are readable from day one; the other 11 are a weekly series, shipped in the same build
  and revealed one Sunday at a time with an unread badge and a Home card.
- Search over titles/excerpts/tags, per-article **medical disclaimers**, and **cited Sources** on
  articles that make health claims.

## Profile
- **Account**: edit display name, password reset, **sign out**, **delete account** (with full local
  data wipe).
- ~~**Partner linking**: send an invite by email / share link, accept, and unlink.~~
  ⚠️ **Not in the 1.2.0 public release.** Built and working, but withheld from the user-facing flow:
  `FeatureFlags.partnerInvites` is a compile-time `false`, so no screen or control reaches it. The
  code stays compiled because the Android app shares this backend and does ship it. See
  `CHANGE_LIST_PLAN.md` §0.2.
- **Preferences**: focus mode, theme (light / dark / system), reminder notifications.
- **Legal**: privacy & data, privacy policy, help & support, and a **Medical Sources & Disclaimer**
  screen listing all references.

## Cross-cutting
- **Daily log**: mood, energy, symptoms, sleep, water, meals (food groups), supplements, notes.
- **Local-first storage** with Supabase sync (offline-safe; owed writes retried; sign-out clears
  on-device health data).
- **Local notifications**: hydration nudges, weekly reminders, Learn nudges, milestone
  celebrations — with tap routing to the right tab/article.
- **Streak milestones**: celebrated *in the app* as well as by notification. The in-app half
  deliberately does not require notification permission — it is the only half most people get.
- **Deep links**: the custom scheme (`genesyx://invite/{code}`) and universal links are still
  registered and still parsed, but in the 1.2.0 public release an invite URL opens the app and then
  does nothing — `RootView.receiveInvite` discards the code. See `CHANGE_LIST_PLAN.md` §0.2.
- **Medical citations**: an NHS / EFSA / NCBI-StatPearls / PubMed reference system surfaced inline
  next to health content (App Store Guideline 1.4.1).

## Notes
- Fertility/wellness guidance is educational only — not medical advice, and not for contraception.
- The pH tracker is fully **vaginal pH** (completed in build 15): scale **3.5–7.0**, two-band
  **Healthy / Elevated** model, vaginal-only insights, and legacy urine readings preserved and
  marked `urine (legacy)`. See the CHANGELOG "build 15" entry.
