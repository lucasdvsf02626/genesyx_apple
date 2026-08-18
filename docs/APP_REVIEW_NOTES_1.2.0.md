# App Review Notes — Genesyx 1.2.0 (build 22)

Written 18 August 2026. Paste the block below into **App Store Connect → App Review Information →
Notes**, then fill the password field in ASC directly.

**This replaces the existing notes entirely — do not merge.** The notes currently on the record were
written for **build 13** and are a reply to the earlier Guideline 1.4.1 rejection. They describe an
app with no consent screen, no withdrawal control and no deletion flow, none of which was true then
and all of which is true now. A stale claim a reviewer can disprove in thirty seconds is worse than
saying nothing, and it costs the credibility of every other sentence around it.

**On tone.** These notes do not mention the 1.4.1 rejection or argue against it. They walk the
reviewer to the four places the disclaimers actually live and let them verify. Raising a closed
decision invites it to be reopened.

---

## Paste this

```
Genesyx is behind a sign-in gate. Please use the demo account below rather than
registering: a new account starts empty, and most of the app only becomes
meaningful with logged data.

  Email:    demo@genesyx.co.uk
  Password: [enter directly in this field]

THE CONSENT SCREEN BEFORE ONBOARDING IS DELIBERATE. Genesyx is a UK app handling
special category health data, so UK GDPR Article 9(2)(a) requires explicit
consent — captured separately, unticked by default, and versioned. It is not a
paywall and it is not skippable, because it is the lawful basis for everything
after it.

WITHDRAWING CONSENT: Profile tab > "Health Data Permission" > "Withdraw consent".
It takes effect immediately and in both directions: no new health data is
recorded, and none is fetched back down from the server. Entry controls show a
blocked state rather than accepting a save that cannot be kept. Data already on
the device stays readable — withdrawal stops processing, it is not erasure, which
is what "Delete account" below is for.

DELETING THE ACCOUNT: Profile tab > scroll to the bottom > "Delete account". For
Sign in with Apple accounts this revokes the Apple token before any data is
erased.

VAGINAL pH TRACKER: third tab. "Log pH" adds a reading.

ON HEALTH CLAIMS. Genesyx is a wellness tracker, not a medical device, and states
so where a user will meet it:
  - Profile > About > "Medical Disclaimer", and "Medical Sources & Disclaimer"
  - "Safety note" disclosures on both the pH tab and the Insights tab
  - pH guidance signposts a GP, nurse or pharmacist rather than interpreting a
    reading, and says plainly that a reading is not a diagnosis
  - The app states it must not be relied on for contraception

Nothing is region-locked or needs external hardware.
```

---

## Every claim above, and where it is in the source

Checked against the build 22 tree on 18 August 2026, not written from memory. A reviewer following
these notes must find what they say they will find, so each line is traceable. Re-verify before
reusing this for a later build — labels move.

| Claim in the notes | Source |
| --- | --- |
| Withdrawal lives in Profile under Health Data Permission | `ProfileView.swift:111` — the comment there names it as the Article 17 neighbour; the control is visible in `docs/appstore_screenshots/` capture 7, since dropped from the store set |
| No new health data is recorded | The `HealthDataCollectionGate` wired at `AppContainer.swift:49-54` over every write in `CycleRepository`, `DailyLogRepository`, `PhRepository`, `SupplementsRepository` and `PreferencesRepository` |
| None is fetched back down from the server | The same gate on the *read* side: `CycleRepository.refresh`, `DailyLogRepository.refresh`, `PhRepository.refresh`, `SupplementsRepository.refresh`, and per-field in `PreferencesRepository.apply`. Proved by `RepositoryTests.testWithdrawingConsentStopsThePullOfHerHealthData` — new in build 22; in build 21 the pull was ungated |
| Entry controls show a blocked state | `ConsentWithdrawnBanner` (`ConsentView.swift:67`) on Home, Track, Nutrition and the pH tab, plus disabled Save on `LogView`, `PhLogSheet` and `CycleSettingsSheet`. Each save path also returns false rather than dismissing, so a refused write cannot look like a successful one |
| Data already on the device stays readable | Nothing is deleted on withdrawal; only `clearLocalState()` on sign-out and account deletion wipes the store. `RepositoryTests.testHerDeletionsStillReachTheServerAfterAWithdrawal` covers the other half — her Article 17 deletions still propagate |
| "Delete account" is at the bottom of Profile | `ProfileView.swift:542` (`deleteButton`), placed after `signOutButton` |
| Deletion revokes the Apple token first | `ProfileView.swift:289` — `session.deleteAccount(appleAuthorizationCode:)`; the edge function revokes before it destroys, §9.2 |
| Profile → About holds both disclaimer entries | `ProfileView.swift:500-522` (`aboutGroup`) — `"Medical Disclaimer"` at :520 and `navRow("Medical Sources & Disclaimer")` at :520 |
| "Safety note" on the pH tab | `PhTrackerSection.swift:159` |
| "Safety note" on Insights | `InsightsView.swift:333` |
| GP / nurse / pharmacist signposting, and "not a diagnosis" | `LearnContent.swift:344`, `:526`, `:702` — all three say a GP, nurse or pharmacist can talk it through and that the tracker is not a diagnosis |
| Not a medical device | `ProfileView.swift:50`; `MedicalSourcesView.swift:11` |
| **Must not be relied on for contraception** | `ProfileView.swift:50` — *"Do not rely on this app for contraception."* · `MedicalSourcesView.swift:11` — same sentence · `LearnContent.swift:576` — *"This is not contraception, and it should not be used as any part of it."* |

## Two things to do before submitting

1. **Sign in as the demo account on build 22 first.** Build 21 moved `ConsentPolicy.currentVersion`
   to `2026-08-18.v2` and the pin is invariant by design, so **every** v1 agreement is re-prompted on
   first launch — the demo account included. Consent granted in a build 20 session does not carry
   over. Agree again inside build 22, then log a cycle start, a daily entry and two or three pH
   readings, or the reviewer meets an empty Insights tab and an empty pH chart. The consent state
   matters more than it did: with the read gate in build 22, an un-consented session pulls nothing
   down, so a reviewer who skips the agreement sees an empty app on a populated account.
2. **Rotate the credentials currently on the 1.1.0 record.** That record holds a personal email and a
   weak plaintext password for a real account. Replace it with the demo account and change that
   password wherever else it is used. The demo password belongs in the ASC field only — not in this
   file, not in a commit, not in an agent transcript.
