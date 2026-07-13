# Genesyx — unattended session report
**2026-07-12** · branch `main` · started at build 11 (`0883477`), ended at `29ea210`

---

## TL;DR

Everything asked for is done and green. **Four real bugs found and fixed**, all of the
"passes every unit test but is broken in real life" kind. Build 10 has been **expired** in
TestFlight; **build 11 is Ready to Test**. The end-to-end sync round-trip against the live
database **passed with zero failures**, and all test data was deleted. The partner-invite
feature is now real: the backend was already sound, but the app never actually sent the invite
to anyone.

**Nothing is left half-done. Nothing needs a decision from you before it works.**
The only outstanding items are things only you can do: install on a phone, and cut a build 12.

| | Status |
|---|---|
| Build 11 in TestFlight | ✅ VALID / Ready to Test |
| Build 10 (dead notifications) | ✅ **EXPIRED** — testers cannot get it |
| Build 8 (in App Store review) | untouched, as instructed |
| Core tests | ✅ 86 / 86 |
| App tests | ✅ 90 / 90 (was 81 — 9 added) |
| UI tests | ✅ 8 / 8 |
| Live sync round-trip | ✅ passed, test data deleted |
| Notification copy audit | ✅ 37 states, 210 sentences, 0 violations |
| Partner invite | ✅ now works end to end |

---

## 1. TestFlight

Queried via the App Store Connect API (key `3252VFV2KW`).

```
build 11  VALID  expired=False   ← Ready to Test
build 10  VALID  expired=True    ← EXPIRED BY ME
build  8  VALID  expired=False   ← left alone (in App Store review)
```

Build 11 had already finished processing. Build 10 was still live and testers could have
installed it — it contains the dead-notification bug — so I expired it. Build 8 was not
touched, per the guardrail.

---

## 2. Test suite

| Suite | Result |
|---|---|
| `swift test` (GenesyxCore) | **86 passed, 0 failed** |
| `xcodebuild test` GenesyxAppTests | **90 passed, 0 failed** |
| `xcodebuild test` GenesyxUITests | **8 passed, 0 failed** |
| Release build (device config) | **BUILD SUCCEEDED** |

App tests went 81 → 90: one for the sign-out leak (bug #1), eight for partner invites.

---

## 3. End-to-end sync — THE FLAGSHIP RESULT

This is the proof that the App Store promise ("keep your health information organized in one
place") is now literally true. Run against the **live production project**, with a disposable
account, no simulator involved.

**Device A** signed up, pushed a daily log and a pH reading. **Device B** signed in
*separately* (its own JWT, its own session) and pulled.

| What | Result |
|---|---|
| `daily_logs.water_ml` = 1750 | ✅ arrived intact on device B |
| mood / energy / symptoms round-trip | ✅ `good` / `normal` / `["Fatigue"]` |
| `ph_readings.ph_value` = 6.4 | ✅ arrived intact |
| pH deletion → tombstone | ✅ device A deleted it, device B saw `deleted_at` set (row retained, so the deletion propagates instead of the row being resurrected) |
| **Failures** | **none** |

**Cleanup — confirmed, nothing left behind:**
- `delete_account` edge function returned `{ok: true}`
- re-signing in with the test account → **HTTP 400 invalid_credentials** (user genuinely gone)
- the old JWT reads zero rows

*Limit worth knowing:* I confirmed the user is gone and its rows return empty. Confirming
row-level deletion from an admin view would need the service-role key, which I deliberately do
not hold.

---

## 4. Bugs found and fixed

Ranked by how badly they'd hurt a real user.

### 🔴 #1 — Sign-out leaked the previous user's notification state to the next one
**`App/Genesyx/Data/App/AppContainer.swift:~62`** (`clearLocalState`)
It wiped cycle, pH and daily logs — but left **milestone flags** and the **read-article list**
behind. On a shared or resold device the next user inherited them: her 7-day and weekly
celebrations already marked "spent" so they would *never fire for her*, and Learn nudges
silently skipping articles she had never opened.
**Fixed:** `PreferencesRepository.clearNotificationState()` + `LearnReadLog.clear()`, both
called from `clearLocalState()`. Theme/focus/push preferences stay — those belong to the
device, not the account. Test fails before the fix, passes after. → commit `de70acf`

### 🔴 #2 — The partner invite never reached the partner
**`App/Genesyx/UI/Profile/ProfileView.swift`** (invite form)
She typed an email, a database row was created… and that was it. **No email was sent, no link
was shared, the code never left the device.** The feature was, in practice, a form that did
nothing.
**Fixed:** an `InviteShareSheet` opens the moment the database issues the code, offering the
invite through the system share sheet (iMessage/WhatsApp/mail); every pending invite keeps a
share button. → commit `29ea210`

### 🟠 #3 — The shared invite code was the wrong code
**`App/Genesyx/Data/PartnerRepository.swift:22`** (old `sendInvite`)
The device invented a 16-character code for instant UI feedback, while the server generated a
**different** one. Any link built from the device's code **redeemed nothing**. Even once #2 was
fixed, every invite would have failed.
**Fixed:** `PartnerBackend.sendInvite` now returns the row the database actually stored, and
the repository awaits it instead of guessing. → commit `29ea210`

### 🟠 #4 — A refused invite still showed a linked partner
**`App/Genesyx/Data/PartnerRepository.swift:33`** (old `accept`)
`accept()` set `partner` optimistically before the server replied. The server correctly refuses
a code addressed to someone else (verified live: **HTTP 403**) — but the app showed a linked
partner anyway. She would have believed a link that never happened.
**Fixed:** accept/revoke/unlink await the server and throw; `InviteView` surfaces the refusal.
→ commit `29ea210`

### ⚪ Noted, not changed
- **`FeatureFlags.partnerInvites` was never referenced anywhere** — the Partner UI was already
  visible regardless of the flag. It's now `true`, so the flag and reality agree.
- **`profiles.push_enabled` still defaults to `true` server-side.** Harmless now (the client
  gates on iOS authorization), so I only *wrote* the migration — see §7.

---

## 5. Partner invites — verified against the live database

Three throwaway accounts, real edge functions, real RLS. **All deleted afterwards.**

| Check | Result |
|---|---|
| A can create an invite row | ✅ RLS allows the inviter |
| B (a stranger) reading A's invites | ✅ **blocked** — zero rows |
| C redeeming a code addressed to B | ✅ **refused, HTTP 403** — invites are bound to the invitee's email |
| B accepting her own invite | ✅ both profiles linked bidirectionally |
| Re-using an accepted code | ✅ **refused, HTTP 409** "Invite is not pending" |
| A reading her linked partner's profile | ✅ the partner-read policy works |
| `unlink_partner` | ✅ clears **both** sides |
| Cleanup (3 accounts deleted) | ✅ all gone, none can sign in |

**The backend was never the problem — the app was.** Nothing needs changing server-side.

**One design limit you should know about:** the share link is `genesyx://invite/<code>`, a
custom scheme. It only opens if the partner **already has the app installed**. The share message
therefore says "Install Genesyx, sign in with this email address, then open this link." A proper
Universal Link (`https://genesyx.co.uk/invite/<code>`) would survive a fresh install, but it
needs an `apple-app-site-association` file hosted on genesyx.co.uk — a domain change I did not
make unattended. **Recommended as the next improvement to this feature.**

---

## 6. Notification copy audit

`NotificationPlanner` enumerated across **37 data states** — streaks 0/1/2/6/7/9/13/22, weekly
consistency 0-of-7 through 7-of-7, broken streaks (best 3/9/30), pH never/stale/thin/rich, log
gaps 0→60 days, three symptom patterns, an exhausted article library, and a brand-new user.

**210 sentences. 0 banned-phrase hits. 0 guilt hits. 0 invariant violations.**

- Banned scan: `alkaline diet`, `balance your ph`, `boy or girl`, `sex selection`, `gender sway`,
  `sway the sex`, `choose the sex`, `detox`, `flush toxins` → **all clear**
- Guilt scan: `broke`, `broken`, `lost`, `missed`, `failed`, `streak is over` → **all clear**
- **Invariant 3 (a broken streak is never named): HOLDS.** With a 30-day streak just lost, she
  gets *"A fresh one — Today's an easy one to log. One glass is a start."* The word "streak"
  does not appear.
- **Invariant 4 (she goes quiet, we go quiet): HOLDS.** 14+ silent days → exactly one hand-back
  (*"Whenever you're ready — Your data is where you left it."*). Once sent, **silence**.
- Budget (≤4 weekly) and one-a-day: never violated in any state.

### Sample of the actual sentences (eyeball the tone)

**Brand-new user, nothing logged ever**
- hydration (daily 10:00) — *A glass to start — Nothing logged yet today, one tap on the coach and you're going.*
- pH (Mon 09:00) — *Your first pH reading — One reading is where the trend starts. It takes a minute.*
- learn (Sun 09:00) — *A read for your week — 'Reading your pH trend', a 4 min read.*

**Streak of 6**
- hydration — *Six days — One more makes a full week.*

**BROKEN streak (best was 30, now 0)**
- hydration — *A fresh one — Today's an easy one to log. One glass is a start.* ← never names the loss

**pH stale 11 days, 6 readings this month**
- pH — *Keep the trend honest — Your last reading was 11 days ago. You've got 6 this month, one more keeps the line true.*

**pH logged yesterday** → *(no pH nudge at all — nothing true to say)*

**14 days silent** → *Whenever you're ready — Your data is where you left it. Pick up any time, a single log is enough to start again.*

**30 days silent, already reached out to** → **silence.**

**Every article read** → *(no Learn nudge)*

Nothing read wrong to me, so no copy was rewritten.

---

## 7. Written but NOT applied

**`supabase/migrations/20260712_push_enabled_default_false.sql`** — sets
`profiles.push_enabled` default to `false`, so the column means what it says. **Optional**: the
client now gates on iOS authorization, so a `true` here can no longer switch reminders on behind
a permission that was never granted. The file notes the one risk: if Android/web read that column
and treat false as "don't send", new users there default to no reminders until they opt in (which
is correct, but confirm those clients agree). **I did not run it.**

---

## 8. What to test on the device (for you)

The Simulator proved a lot, but not these four:

1. **Permission → schedule.** Profile → Weekly reminders → the sheet explains → iOS asks → Allow.
   The toggle must go on. (Verified in Simulator; confirm on a real phone.)
2. **Banner actually renders.** Only a real device shows a real lock-screen banner. Change the
   phone's clock to just before 10:00 with no water logged for the day.
3. **Cold-start deep link.** Force-quit the app, tap the Sunday Learn notification → it must open
   *that article*, not just the Learn tab.
4. **Two-device sync.** Sign in on two phones, log water on one, watch it appear on the other.
   (The database round-trip is proven — what's unproven is the app's own push/pull wiring on real
   hardware.)
5. **Partner invite, for real.** Invite a second email → share the link to another phone → install,
   sign in **with that exact email**, tap the link → both should show as linked. Try accepting from
   the *wrong* account too: it must refuse.

---

## 9. What I changed

| Commit | What |
|---|---|
| `de70acf` | Sign-out leaked the previous user's notification state (bug #1) + the unapplied migration |
| `29ea210` | Partner invites made real (bugs #2, #3, #4) |

All pushed to `origin/main`. **I did not:** submit anything for review, upload a build, flip
Confirm-email, drop `trg_ph_readings_updated_at`, touch build 8 or the frozen branch, or leave
any test data in the production database.

## 10. What's left for you

1. **Build 12 + upload.** The partner fixes are on `main` but not in any TestFlight build.
   `CURRENT_PROJECT_VERSION` is still `11` — bump it before archiving (the guardrail says a new
   upload requires it, and I left it alone deliberately).
2. **Device pass** — the five checks in §8.
3. **Flip "Confirm email" ON** in Supabase — only once build 11 (or later) is live. The app
   handles it correctly now; the build in review does not.
4. **Diary entry:** the Sign in with Apple key expires roughly every 6 months and will fail
   *silently* when it lapses.
5. Optional: **Universal Links** for invites (§5), so a partner without the app installed can
   still accept.
