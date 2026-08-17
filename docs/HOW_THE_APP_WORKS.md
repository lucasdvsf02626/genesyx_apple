# How Genesyx works

**A plain-English guide to every part of the app, and what each part is for.**

Version 1.2.0 · Written 17 August 2026 · For Lucas and the client

No technical knowledge needed. If you read this end to end you will know what every screen does,
why it exists, and what a new user's first week actually looks like.

---

## 1. What the app is for

Genesyx is a fertility-preparation companion. It is not a medical device and it does not diagnose
anything. It does three things, and everything in the app serves one of them:

1. **It records.** A short, honest daily log — mood, energy, symptoms, sleep, water, supplements,
   food, pH — written by someone who does not yet know how the story ends.
2. **It explains.** Where she is in her cycle, what that phase changes, and what the numbers mean.
3. **It shows her the pattern.** After a few weeks the log stops being a diary and starts being
   evidence: energy dips that cluster, hydration that slips on certain days, a pH trend.

The single most important sentence in the whole product is this: **a one-tap entry logged for sixty
days is worth more than a paragraph logged four times.** Every design decision — the optional
fields, the one-tap chips, the "nothing to report is a real entry" line — exists to protect that.

---

## 2. Before the tabs: signing up

A brand-new user goes through five screens before she ever sees the app proper.

| # | Screen | What happens |
|---|--------|--------------|
| 1 | **Splash** | "Step into the future of fertility." Two choices: start the quiz, or sign in if she already has an account. Carries the medical disclaimer. |
| 2 | **Introduction** | Three benefit cards: understand your cycle, support fertility nutrition, receive tailored insights. |
| 3 | **Quiz** | Five questions (below). Progress shown as "3/5". She can go back without losing answers. |
| 4 | **Readiness summary** | Recaps what she told us and what her plan will include. Offers the first-week guide. |
| 5 | **Sign in / create account** | The gate. Only a successful sign-in gets her to the tabs. |

### The five quiz questions

1. **"Where are you in your conception journey?"** — just thinking about it / actively preparing /
   trying now / looking for extra support.
2. **"How regular does your cycle usually feel?"** — very / mostly / often irregular / not sure.
3. **"Are you currently taking fertility supplements?"** — full routine / a few / not yet / I'd love
   guidance.
4. **"When it comes to your baby's sex, what feels right for you?"** — girl / boy / no preference /
   prefer not to say. **This is the only optional question.** She can skip it entirely.
5. **"What would you like the most support with?"** — nutrition / understanding my cycle /
   supplements / feeling calm and informed.

**What the answers do:** they shape the tone and emphasis of her plan, her nutrition focus and her
insights. She can change any of them later in Profile → Tracking Preferences.

**What they explicitly do not do:** question 4 does not change any advice the app gives. There is no
sex-selection guidance anywhere in Genesyx, and the app's own Learn content says so. The question is
there because it is a real thing people feel, and "prefer not to say" is a first-class answer.

**Note:** the answers are saved on her phone the moment she taps them, before she has an account.
They are sent up to the server the first time she signs in, so nothing is lost if she quits halfway.

---

## 3. The seven tabs

The app is seven tabs across the bottom: **Home, Track, pH, Nutrition, Insights, Learn, Profile.**

Here is the one-line version, then a section on each.

| Tab | Its job in one sentence |
|-----|------------------------|
| **Home** | Today, at a glance — where she is in her cycle and the two or three things worth doing now. |
| **Track** | The record: a calendar of what happened, and six trackers she can open and edit. |
| **pH** | One number, taken over time, with the explanation attached to it. |
| **Nutrition** | What to eat this phase, her supplement plan, and today's food and water. |
| **Insights** | What the log adds up to — the patterns, not the entries. |
| **Learn** | The library: how the app works, and the fertility education. |
| **Profile** | Her account, her settings, her reminders, and her data. |

---

### Tab 1 — Home

**Goal: answer "what should I do today?" in under ten seconds.**

Top to bottom:

- **Greeting.** Her name, and good morning / afternoon / evening.
- **Cycle phase card.** The phase she is in, what it means, and three numbers: day of cycle, days
  until her next period, predicted ovulation day. *Only appears once she has set up her cycle.*
- **Setup card.** If she has **not** set up her cycle, this replaces the phase card: "Tell us when
  your last period started." One button starts it.
- **Hydration card.** A progress ring against a 2,400 ml daily target, today's total, whether she is
  on track for this hour of the day, her streak, and a seven-day consistency bar. Tapping it opens
  the full hydration screen.
- **pH nudge.** Her last reading, or an invitation to take a first one. Tapping opens the pH tab.
- **Learn card.** The next article she has not read. *Disappears when she has read everything.*
- **"Log today" button.** The main action on the screen. Opens the daily log.
- **"New here? What your first week looks like."** A link into the first-week guide.

---

### Tab 2 — Track

**Goal: be the place where the record lives, and where she edits it.**

- **Calendar.** A month at a time. Days are tinted by phase — period, fertile window, ovulation,
  luteal, follicular — and carry small dots for what was logged that day, labelled in the legend
  underneath as **pH test**, **Symptoms / notes**, and **Intimacy**. Today has a white ring.
  Tapping any day opens it: a summary of what was logged, and a button to add or edit.
- **Current phase card.** The phase, a "fertile window" badge if she is in one, and a sentence of
  context.
- **"Add to today's log."** The same log sheet as Home.
- **Six trackers.** Each row shows the current value and seven dots for the last seven days, and
  opens its own detail screen:

  | Tracker | Shows | The detail screen lets her |
  |---------|-------|---------------------------|
  | **Cycle** | Day and phase | See predicted timing and edit her cycle settings |
  | **Vaginal pH** | Latest reading | See the full pH tracker (same as the pH tab) |
  | **Nutrition** | Food groups and supplements today | See the week's consistency |
  | **Symptoms** | How many logged today | See the last seven days |
  | **Sleep** | Hours and minutes | Set sleep with steppers, see the week |
  | **Hydration** | ml against goal | Quick-add buttons, manual entry, seven-day history |

- **"How the log works, and what each entry is for."** Link into that guide.

**Worth saying to the client:** every field in the daily log is optional. Mood, energy, symptoms,
sleep, water, supplements, food, notes — she can fill in one and save. The log saves to her phone
instantly, even with no signal, and syncs itself later.

---

### Tab 3 — pH

**Goal: make one number meaningful, and keep it honest.**

- **Two caveats, always on screen before any result.** That pH varies naturally across the cycle,
  and that test strips have a margin of error. These are not buried in a disclaimer at the bottom —
  they sit above the reading.
- **"+ Log pH."** A slider from 3.8 to 7.0 in steps of 0.1, with plus/minus buttons, a date and time,
  and an optional note. Saving is one tap.
- **Latest reading panel.** The value, when it was taken, and a status: healthy or elevated.
- **Chart.** Her readings over 7 / 30 / 90 days or all time, drawn against a green band (healthy)
  and an amber band (elevated). *Needs at least two readings in the range to draw.*
- **Reading history.** Every reading, newest first, each one tappable to edit or delete.
- **The explanation, in order:**
  1. **Why pH matters** — general vaginal-health context, with NHS and clinical sources cited.
  2. **What this result means** — changes depending on whether her latest reading is healthy or
     elevated. *Only shown once she has a reading.*
  3. **What to do next** — again, specific to her result.
  4. **Supporting vaginal health** — general guidance.
  5. **Genesyx supplements** — and a link to her plan.
- Links out to the "Understanding your vaginal pH" guide and to the Nutrition tab.

**The design intent here:** she should never see a number without seeing what it means, and she
should never see what it means without seeing the caveats first.

---

### Tab 4 — Nutrition

**Goal: turn "eat well" into a short list of things to actually put in the basket this week.**

- **Header.** "Today · [her current phase]", and what that phase asks of her nutritionally.
- **Phase change card.** When she moves into a new phase, this appears once to tell her the focus
  foods below have changed. She dismisses it, or taps through to read about that phase.
- **Focus foods.** A handful of foods for the phase she is in. Tap one to expand it and read why.
- **Featured recipes.** Cards she can scroll sideways through. Each opens a full recipe —
  ingredients, method, time, servings — with a "Log this" button that fills in the food groups for
  her.
- **Supplement plan.** The four Genesyx essentials (Folate, Omega-3, Vitamin D, Zinc) and how many
  she has taken today. "Review Plan" opens a screen where she can:
  - Set a daily reminder time for each of the four, or turn it off;
  - **Add her own supplements** — name, dose, and time of day (breakfast, lunch, dinner, bedtime),
    each with its own reminder.
- **Hydration card.** Today's total against the 2,400 ml goal, her streak, coaching for this hour,
  a note on how it relates to her current phase, and a "Why hydration?" section she can expand — with
  sources.
- **Water challenge.** Seven capsules, one per day, filled for each day she hit the goal.
- **Today's food log.** Six chips she taps on and off: **Proteins, Whole grains, Vegetables, Fruits,
  Dairy, Healthy fats.** A line telling her which to emphasise in her current phase, and a "What
  counts as what?" section with examples.
- **Learn more.** Three to five nutrition articles.
- **"How your focus foods are chosen."** Link into that guide.

**Be clear with the client about the boundary:** this is food-*group* logging, not calorie or macro
tracking. There is no barcode scanner and no photo logging in this release (see §6).

---

### Tab 5 — Insights

**Goal: show her what the log adds up to — and only what the data can actually support.**

Cards, top to bottom. Several are conditional, and that is deliberate: a card that would be a
guess simply is not drawn.

| Card | What it shows | When it appears |
|------|---------------|-----------------|
| **Your habit** | Streak, which of the last seven days she logged, a summary line | Always |
| **Vaginal pH** | Seven-day average, status, and whether the trend is rising, falling or stable | Once she has a reading |
| **Hydration** | Days on goal this week, a seven-day bar chart, her streak | Always |
| **Nutrition consistency** | Supplements taken this week, and how many of the six food groups | Always |
| **Sleep** | Average hours, seven-day chart | Always |
| **Cycle regularity** | Her range in days, and whether her cycles are consistent | After **two** cycles |
| **Symptom patterns** | A heat map: which symptoms cluster on which day of her cycle | Once she has logged symptoms |
| **Ovulation** | Days until ovulation, her position in the cycle, fertile window | Once her cycle is set up |
| **Log history** | The full read-only list of every day she has logged | Always |

Every number on this tab is computed from what she actually logged. Nothing is filled in, estimated
or mocked.

Ends with **"Reading your trends without over-reading them"** — the guide that exists because
Insights is the tab most likely to be misread.

---

### Tab 6 — Learn

**Goal: be both the education library and the app's own manual.**

- **First visit** shows a short explainer, then the library.
- **Featured article** at the top.
- **Six categories** she can filter by: Getting started, Tracking, Nutrition, Insights, Wellness,
  Guides.
- **Search** across titles, summaries and tags.
- **Articles** open into a clean reading view: hero image, structured body (headings, paragraphs,
  bullets, highlighted callouts), the medical disclaimer where one is required, the sources, related
  articles, and often a button that takes her straight to the relevant part of the app — "Log pH",
  "Open today's log", and so on.
- **A badge** on the tab shows how many *newly released* articles she has not read. It is zero on a
  fresh install, so the app never greets a new user with a chore list.

**Two things sit at the top of this tab:**

- **"How to use Genesyx"** — the index of the twelve how-to guides, grouped by the tab each one
  explains. This is the app's manual (see §5).
- **The 12-week plan** — a series of twelve articles released one per week from 23 August 2026. They
  are all already built into the app and simply revealed on their date. This is on purpose: twelve
  articles would otherwise mean twelve App Store submissions, and one rejected review would break
  the run.

---

### Tab 7 — Profile

**Goal: her account, her settings, and her control over her own data.**

- **Her card.** Name, email, avatar.
- **Current focus.** "Fertility Prep" (the live mode) and "Pregnancy" (a coming-soon teaser).
- **Account.** Personal details (edit her display name), and change password (emails her a reset
  link).
- **Tracking.** Health profile (last period date, cycle length) and Tracking Preferences (re-answer
  the five onboarding questions at any time).
- **Notifications.** One master switch. The first time she turns it on she gets a plain-English
  screen explaining exactly what she will receive, *before* iOS asks for permission. Then she can set
  the hour, and mute any category individually. If she has denied permission at the iOS level, the
  app tells her so and offers a button into Settings.
- **Hydration display.** Glasses, cups, or millilitres — and if glasses, she sets her own glass size.
  This changes the display only; what she logged never changes.
- **Theme.** System, Light, or Dark.
- **About.** "How to use Genesyx" (the manual), Privacy & Data, Privacy Policy, Help & Support,
  Medical Disclaimer, and Medical Sources.
- **Log out**, and **Delete account** — which permanently removes her account and all of her data.

---

## 4. How the parts connect

The tabs are not seven separate apps. The connections are the product.

```
        the daily log
              │
   ┌──────────┼───────────┐
   ▼          ▼           ▼
 Home      Track      Insights
(today)  (the record) (the pattern)
              │
     cycle phase drives:
              │
   ┌──────────┴───────────┐
   ▼                      ▼
Nutrition               pH
(focus foods,      (context for
 recipes)          the reading)
              │
              ▼
            Learn
   (explains all of the above,
    and links back into each tab)
```

Concretely:

- **Her cycle setup** is the single input that unlocks the phase card on Home, the tinting on the
  Track calendar, the focus foods and recipes in Nutrition, the ovulation card in Insights, and the
  cycle context on pH.
- **The daily log** is written from Home *or* Track, and read by Track, Insights and the hydration
  and nutrition cards everywhere.
- **Learn is bidirectional.** Articles carry buttons back into the app ("Log pH", "Open today's
  log"), and every tab carries a link out into the article that explains it.
- **Nothing dead-ends.** Every result screen offers the next step.

---

## 5. How someone learns to use the app

This is the part that was just added, and it is worth showing the client directly.

**The problem it solves:** the app already contained ten well-written "How X works" guides. They were
reachable only if you knew to tap the "Guides" chip on the Learn tab. In other words, the manual
existed and nobody could find it.

**Three ways in, now:**

1. **A link at the bottom of each tab.** Home, Track, Nutrition and Insights each carry one
   "How this works" link, pointing at the guide that answers *"what is this screen for?"*:

   | Tab | The link says |
   |-----|---------------|
   | Home | "New here? What your first week looks like" |
   | Track | "How the log works, and what each entry is for" |
   | pH | (its own existing link, into "Understanding your vaginal pH") |
   | Nutrition | "How your focus foods are chosen" |
   | Insights | "Reading your trends without over-reading them" |

2. **"How to use Genesyx" — the index.** A card at the top of the Learn tab, and a row in Profile →
   About. It lists all twelve guides, grouped by the tab each one explains, with a one-line
   description of *why* she would read it (not just what it is called):

   - **Home** — your first seven days · how your water target is set, and why it is not eight glasses
   - **Track** — recording a day · how your phases are worked out · noting how you feel · logging sleep
   - **pH** — what the tracker is for · taking a reading you can trust · what the number means ·
     reading the trend rather than a single result
   - **Nutrition** — how your focus foods are chosen
   - **Insights** — reading your patterns without over-reading them

3. **The Learn tab itself**, with its "Guides" category and search.

**A note on why there are no pop-up tutorials.** We deliberately did not add first-run coach marks —
the overlays that point at things when you first open an app. They are the highest-risk thing to add
immediately before an App Store submission (they can trap a user in a loop, they interact badly with
accessibility settings, and they are hard to test), and the evidence is that people look for help
*when they are stuck*, not on the first launch when they are still exploring. A link that is always
there on the screen she is stuck on serves her better.

---

## 6. What a first week actually looks like

This is the honest version — worth setting expectations with the client, because the app is
deliberately quiet at the start.

**Day 1.** She signs up, answers five questions, and lands on Home. If she entered her last period
date, she immediately sees her phase and her predicted fertile window. She logs her first day —
probably just a mood and some water. Insights is nearly empty, and says so.

**Days 2–6.** She logs most days. The hydration streak starts to mean something. The Track calendar
starts to fill with dots. She might take her first pH reading. Nutrition shows her focus foods for
her current phase.

**Day 7.** The first milestone — *"One week strong. Seven days logged. That's a habit forming."* The
Insights tab now has a real seven-day picture: hydration consistency, sleep average, food-group
variety.

**Week 2.** Day 14 milestone. Symptom patterns start appearing if she has logged symptoms. She has
moved through at least one phase change, so she has seen the Nutrition phase-change card.

**Week 4 onwards.** *"Four weeks of showing up."* This is the point at which the app changes
character: cycle regularity appears (it needs two cycles), the pH trend has direction, and the
symptom heat map has enough entries to show clustering. From here, Insights is genuinely telling her
something she did not already know.

**The message to give a new user:** the first two weeks are deposits. The fourth week is the first
withdrawal.

---

## 7. What she is reminded about

Reminders are **off** until she turns them on, and the app explains what she will get before iOS
asks for permission.

There are **eight categories**, and she can mute any one of them individually without turning
everything off. The names below are the ones she sees in Profile.

| Category | What it is, and when |
|----------|---------------------|
| **Evening check-in** | At the hour she chose — and only if she has not already logged that day |
| **pH readings** | A nudge to take a reading |
| **Weekly read** | The next article she has not read |
| **Insights** | A prompt to look at her trends |
| **Logging reminders** | Encouragement when there is a gap in her log |
| **Cycle** | When she reaches her predicted fertile window |
| **Supplement reminders** | One per supplement, at the times she sets, including her own additions |
| **Milestones** | The four celebrations below |

**Milestones** are the four moments the app marks: 7 days logged, 14 days, one consistent week, and
four consistent weeks. Each arrives **twice over** — as a notification, and as a celebration inside
the app the next time she opens it. Muting the category silences both, which is deliberate: someone
who turned milestones off did not ask for a quieter version of them.

**Two things worth knowing about the design here.** First, a category conditioned on a *gap* in her
logging correctly says nothing to a consistent user — which is why the evening check-in queues
tomorrow's invitation rather than falling silent when she has already done everything. Second,
reminders are queued while the app is open. A woman who stops opening the app entirely will
eventually run out of queue; re-engaging a fully dormant user needs background execution, which this
release does not have.

---

## 8. Where her data lives

- **Everything saves to her phone first**, instantly, with no signal required. Then it syncs to the
  server by itself when there is a connection.
- **Synced to her account:** her daily logs, pH readings, cycle settings, supplements, quiz answers,
  name and email. This is what makes a new phone work.
- **Stays on the phone only:** her theme, her hydration display unit and glass size, her supplement
  reminder times, and which articles she has read.
- **Offline is a first-class state**, not an error. A log written on a plane is saved, marked as
  pending, and pushed when she lands. A pending local edit is never overwritten by the server.
- **She can delete her account** from Profile. It removes the account and its data permanently, and
  the app no longer reports success for a deletion that did not fully happen.

> **One caveat for Lucas, not for the client:** two server-side deletion fixes are written and
> tested but **not yet deployed** — an explicit clear-down of her custom supplements, and a failure
> that used to be swallowed. Deploy before launch. Sign in with Apple token revocation also still
> needs the Apple key installed in the server's secret store. Neither is an engineering task now;
> both are listed in `LAUNCH_READINESS.md`.

---

## 9. What is deliberately not in this release

Worth being explicit, so nobody goes looking:

| Not in 1.2.0 | Status |
|--------------|--------|
| **Partner linking** | Built and tested, but switched off for the public iOS release. The code stays compiled because the same backend serves the Android app, which does ship it. Turning it back on is a one-line change and a new build. |
| **Pregnancy mode** | The "Pregnancy" option in Profile is a coming-soon teaser. No screen behaves differently. |
| **Apple Health / wearables** | Not in scope for this release. |
| **Home-screen widget** | Not in scope for this release. |
| **Barcode or photo food logging** | Not in scope. Food logging is the six-group chip system. |
| **Personalised supplement timing** | Built but off. When on, a reminder could shift by up to two hours toward when she actually logs. It would never change *which* supplements are reminded. |
| **Weeks 1–12 of the article series** | All twelve are in the app already, revealed one per week from 23 August 2026. |

---

## 10. The claims the app does and does not make

Important for sign-off:

**It does say:** here is where you are in your cycle, here is your predicted fertile window, here is
what this pH reading falls into, here is what you logged, here is the pattern in it.

**It does not say:** that it can diagnose anything, that it can influence the sex of a baby, that
it can replace a doctor, or that any prediction is a certainty. Cycle predictions are labelled as
predictions. pH results carry their caveats above the number, not below it. Educational articles that
touch on health carry the medical disclaimer verbatim, and cite their sources.

This is enforced in the codebase, not just in the copy: there are automated tests that fail the build
if banned clinical or sex-selection phrasing appears anywhere in the content. Changing that is a
compliance decision, not an editorial one.

---

## Appendix — one-line summary of every feature

**Home:** greeting · cycle phase · hydration ring · pH nudge · next article · log today · first-week guide
**Track:** month calendar with phase tinting and per-day markers · current phase · add to log · six trackers (cycle, pH, nutrition, symptoms, sleep, hydration) with seven-day sparks and detail screens
**pH:** caveats · log a reading (3.8–7.0) · latest result with status · chart over 7/30/90/all days · full history · why pH matters · what this result means · what to do next · supporting vaginal health · supplements
**Nutrition:** phase header · phase-change card · focus foods · recipes with logging · four-supplement plan plus her own, each with reminders · hydration with sources · water challenge · six food-group chips · nutrition articles
**Insights:** habit streak · pH average and trend · hydration week · nutrition consistency · sleep · cycle regularity · symptom heat map · ovulation timing · full log history
**Learn:** how-to index · 12-week plan · featured article · six categories · search · articles with sources, disclaimers, related reading and buttons back into the app · unread badge
**Profile:** account · personal details · password · cycle settings · tracking preferences · notification master switch, hour and per-category mutes · hydration display units · theme · how-to index · privacy · disclaimer and sources · log out · delete account
