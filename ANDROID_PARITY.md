# Android parity — iOS fixes still owed in Kotlin

Written 25 Aug 2026, against iOS build 24 (`1.2.0 (24)`) and `genesyx-android` `main` at
`1.4.1 (15)`. Every line reference below was opened and read, not inferred.

Paths are relative to each repo root: iOS `~/genesxy_apple.V1.02`, Android `~/genesyx-android`
(Kotlin under `app/src/main/kotlin/com/genesyx/app/`, elided to `…/` below).

## Status at a glance

| # | Fix | Android state |
|---|---|---|
| 1 | Greeting from `profiles.display_name` | **Broken** — never reads the column |
| 2 | Profile tab saves: refusal + error surfacing | **Broken** — all three dismiss unconditionally |
| 3 | Article 9 consent gate | **Absent entirely** — blocks #2 and #4 |
| 4 | Refusal reporting (`fc9a524`) | **Cannot start** until #3 exists |
| 5 | Tracking Preferences clear | **Different bug, same symptom** — read #5 before porting |
| 6 | Products table read + empty state | **Already done** — no work, see caveat |

Two things worth knowing before you start.

**#3 is the long pole and it gates two others.** #2 and #4 are the same piece of work seen from
two sides, and neither is finishable without a consent gate to refuse anything. If you are
scheduling this, #3 first, then #2/#4 together, then #1 and #5 independently.

**Do not port #5 literally.** The iOS fix is shaped around an iOS-only guard that Android does
not have. Copying it across would fix nothing and would introduce a bug Android currently does
not have. Section 5 explains what to do instead.

**Cancelled:** the `genesyx_products` seed migration. The four supplements bundled in iOS are
nutrition-pathway content, not SKUs, and the range is not finalised. Do not seed the production
table. Nothing is blocked by it being empty — see #6.

---

## 1. Home greeting must come from `profiles.display_name`

**Symptom.** The greeting shows a mangled name — "chezelle.madekwe" or "Chezelle.madekwe" rather
than "Chezelle Madekwe". `profiles.display_name` holds the correct value; the greeting never asks
for it.

**iOS implementation.**

The greeting itself is one line — `App/Genesyx/UI/Home/HomeView.swift:86`, reading
`session.displayName` with `"there"` as the last resort. The work is all behind that property.

`App/Genesyx/Data/SessionRepository.swift` resolves it in a strict order of preference at
:250-252 — a name she typed, else a name already remembered for *this same account*, else the
address fallback. `nameFromAddress` (:278-286) splits the local-part on `.-_+`, uppercases the
first character of each word only, and leaves the remainder untouched so accented and non-Latin
spellings survive.

The two rules that matter more than the formatting:

- `refreshDisplayName` (:310-316) **pushes before it pulls**, and treats an empty remote as no
  answer: `guard let remote = await onFetchDisplayName(), !remote.isEmpty else { return }`. A
  profile row with a null `display_name` therefore cannot blank the name on screen.
- The address fallback is **display-only**. `pendingNamePush` is set only by a name she typed
  (`updateDisplayName`, :288), so a fallback that happens to look like a real name can never be
  pushed into her row and overwrite the real one. `drainPendingName` (:298-304) re-reads
  `displayName` before clearing the flag, so a rename made while the push was in flight stays owed.

**Android defect.**

`…/auth/SupabaseAuthService.kt:187` — verified:

```kotlin
displayName = u?.email?.substringBefore("@"),
```

That is the whole of it. The value flows into `AuthUser` (`…/auth/AuthService.kt:6-11`), through
`HomeViewModel.kt:126` into `sessionInfo`, becomes `userName` at `HomeViewModel.kt:203`
(`session.displayName ?: "Guest"`), and renders at `…/ui/home/HomeScreen.kt:167-168`.

The column is not unreachable — `…/data/remote/SupabaseProfileRemoteDataSource.kt:24-26` already
selects it and :52 already writes it, and `ProfileDto` maps `@SerialName("display_name")`. The
greeting simply never consults that path; it takes the auth session's guess instead.

**Design intent that must survive the port.**

- The address fallback must remain **display-only**. Android's write path
  (`SupabaseProfileRemoteDataSource.kt:52`) will happily push whatever it is handed — if you let
  the derived name reach it, the first sign-in on a new device overwrites her real name with a
  guess, and that is far worse than the bug you are fixing.
- An empty or null `display_name` must mean *no answer*, not *blank her name*.
- Push before pull.

---

## 2 & 4. Profile tab saves: honour the refusal, surface the error

These are one job. `fc9a524` is the iOS commit for the Tracking Preferences half; build 22 did the
Health Profile half the same way.

**Symptom.** All three Profile sections appear to save and then revert. Two distinct causes sit
behind the one symptom, and you need both fixed:

1. A refused write (consent withdrawn) closes the dialog exactly as a successful one does.
2. A *failed* write (offline, RLS, network) is swallowed — no snackbar, no dialog, nothing.

**iOS implementation.**

The contract is: a repository save returns `Bool`; `false` means the gate refused; the sheet stays
open and shows why. It is deliberately the same contract in all three places rather than three
bespoke solutions — the `fc9a524` message is explicit about this ("Health Profile solved this in
build 22; this is the same solution, not a second one").

| Section | Repository | Sheet |
|---|---|---|
| Personal Details | `SessionRepository.updateDisplayName` :288 → `Void` | `ProfileView.swift:86` |
| Health Profile | `CycleRepository.upsert` :41 → `Bool` | `CycleSettingsSheet.swift:12, 92-100` |
| Tracking Preferences | `PreferencesRepository.recordQuizAnswers` :147 → `Bool` | `ProfileView.swift:929, 976-980` |

Both gated sheets guard the dismiss:

```swift
// CycleSettingsSheet.swift:95-100
guard onSave(CycleSettings(
    ...
)) else { return }
dismiss()
```

```swift
// ProfileView.swift:976-980
Button("Save") { if onSave(answers) { dismiss() } }
    .fontWeight(.semibold)
    .disabled(!consent.isActive)
```

The disabled Save and the `ConsentWithdrawnBanner` are the visible half; the guarded `dismiss()`
is defence in depth behind it (there is a comment saying exactly that at
`CycleSettingsSheet.swift:92`).

**Note Personal Details is deliberately `Void`.** A display name is not Article 9 health data, so
there is no gate and nothing to refuse. Do not add a consent check there — that would be a
correctness regression, not parity. It still needs *error* surfacing (cause 2), just not refusal
handling.

**Android defect.**

All three dismiss unconditionally. Verified verbatim:

```kotlin
// …/ui/profile/ProfileScreen.kt:298
EditNameDialog(initial = name, onDismiss = { nameOpen = false }, onSave = { viewModel.updateName(it); nameOpen = false })

// …/ui/profile/ProfileScreen.kt:332-335
onSave = {
    viewModel.saveCycleSettings(it)
    healthOpen = false
},

// …/ui/profile/ProfileScreen.kt:360
onSave = { viewModel.saveQuizAnswers(it); prefsOpen = false },
```

Each is `call(it); dialogOpen = false` — a statement, then an unconditional close. There is no
value to inspect because the ViewModel methods are fire-and-forget into `viewModelScope.launch`
(`ProfileViewModel.kt:89-91`, `:57`, `:66`), and the `DataResult` dies inside the coroutine.

`DataResult` is defined at `…/core/result/DataResult.kt:8-11` (`Success` / `Error` / `Loading`).
Where it is discarded on these paths:

- `…/data/ProfileRepository.kt:52-56` — `setDisplayName` returns `DataResult<Unit>`; the caller
  ignores it.
- `…/data/CycleRepository.kt:44-54` — the `Error` branch is logged (`logger.w`) and goes no further.
- `…/data/QuizAnswersRepository.kt:43-48` — `remote.upsert(uid, answers)` result is not bound at all.

A log line is not user-facing. From her side the three failures are indistinguishable from success.

**Design intent that must survive the port.**

- **One contract, three call sites.** Resist solving this three ways. Kotlin has a better tool than
  `Bool` here — return the `DataResult` (or a small `SaveOutcome` sealed type) so *refused*,
  *failed* and *saved* are three distinct cases rather than two. iOS collapses refused/failed into
  `false` because Swift's sheet API made that cheap; you do not have to inherit that limitation.
- The dialog must stay open on anything that is not success, and say which it was — "you've
  withdrawn consent" and "couldn't reach the server" need different copy and different remedies.
- The ViewModel methods must stop being fire-and-forget. They need to expose state the dialog can
  collect — there is already a pattern for this next door in the password flow
  (`ProfileScreen.kt:301-302` collects `pwChanging` and `pwError`); follow it.
- Do not gate Personal Details behind consent.

---

## 3. Article 9 consent gate — absent entirely

**Symptom.** None visible. That is the problem: Android writes and reads health data with no
lawful-basis check anywhere, and pulls it back down from the server after a withdrawal. On iOS
this was serious enough that build 21 is marked void for submission over the read side alone.

**Verified absent.** `grep -ril "consent\|article 9\|gdpr" app/src/main/kotlin/` returns **nothing**.
Not a screen without enforcement — nothing at all.

**iOS implementation.**

- `App/Genesyx/Data/ConsentRepository.swift:16` defines the gate as a closure type:
  `typealias HealthDataCollectionGate = @MainActor () -> Bool`.
- Consent state is an **append-only event log**, not a boolean. `grant()` and `withdraw()` append
  `ConsentEvent`s and never mutate or delete; `isActive` is derived from the trail
  (`ConsentRepository.swift:43`). That shape is the point — it is the audit evidence.
- Each repository holds an injected gate defaulting to permissive, e.g.
  `PreferencesRepository.swift:49` and `PhRepository.swift:34`:
  `var isCollectionPermitted: HealthDataCollectionGate = { true }`.
- **Writes** guard early and report the refusal: `PreferencesRepository.swift:148`,
  `PhRepository.swift:55` and `:63` — `guard isCollectionPermitted() else { return false }`.
- **Reads** are gated too, and this is the half that is easy to miss. `PreferencesRepository.apply`
  (:282-290) applies theme and push unconditionally but gates the health fields:

```swift
private func apply(_ remote: ProfilePrefs) {
    isApplyingRemote = true
    themeMode = remote.themeMode
    pushEnabled = remote.pushEnabled
    if isCollectionPermitted() {
        focusMode = remote.focusMode
        quizAnswers = remote.quizAnswers
    }
    isApplyingRemote = false
}
```

**Android sites needing the gate.** All currently ungated: `…/data/CycleRepository.kt` (:44-54),
`…/data/QuizAnswersRepository.kt` (:43-48 write, :52-68 read), `…/data/DailyLogRepository.kt`,
`…/data/PhRepository.kt`.

**Design intent that must survive the port.**

- **Append-only.** Do not model consent as a boolean in DataStore. A withdrawal that overwrites a
  grant destroys the evidence that the grant happened, which is the one thing the trail exists to
  prove. Room table, insert-only.
- **Gate reads, not just writes.** After a withdrawal there is no lawful basis to pull her health
  data back down. This is the specific point that voided iOS build 21.
- **Withdrawal does not delete.** What the device already holds is left alone; withdrawal stops
  collection, it is not an erasure request. iOS has a test named
  `testWithdrawingKeepsWhatSheAlreadyRecorded` pinning this.
- Split settings from health data the way `apply` does — theme and push notifications are not
  Article 9 and must keep syncing after a withdrawal.

---

## 5. Tracking Preferences clear — read this before porting

**Do not copy the iOS fix across.** iOS and Android reach the same symptom by different routes,
and the iOS remedy is shaped around a guard Android does not have.

**The iOS bug.** `QuizAnswersRow.init?` (`App/Genesyx/Data/Remote/RemoteModels.swift`) returns
`nil` for an empty answer set, so `SupabaseBackend.upsert` skipped the quiz table entirely and
returned without throwing. `drainPending` read that silence as success, cleared `pendingPush`, and
the next pull reinstated the answers she had just cleared.

That `nil` is deliberate and stays: onboarding runs once, so most installs hold no answers, and a
device that has not yet pulled them must not erase them on the first theme toggle.

**The iOS fix** makes the *intent* explicit rather than removing the guard —
`App/Genesyx/Data/PreferencesRepository.swift`:

- `quizAnswersCleared`, persisted (:80-82) — survives relaunch, because a clear made offline is
  still owed afterwards.
- Set only by `recordQuizAnswers` (:152), the single deliberate path to an empty set.
- Cleared by `clearQuizAnswers` (:162-170) on sign-out, so an owed delete cannot outlive her
  session and land on whoever signs in next.
- `drainPending` (:254-270) follows the upsert with an explicit `deleteQuizAnswers()`.

**Android is different in a way that matters.** `…/data/remote/SupabaseQuizAnswersRemoteDataSource.kt:33-40`
writes the map unconditionally:

```kotlin
override suspend fun upsert(userId: String, answers: Map<String, String>): DataResult<Unit> =
    try {
        client.from("quiz_answers").upsert(QuizAnswersDto(userId = userId, answers = answers))
```

There is no nil-on-empty guard, so an empty map is genuinely written and the clear *does* stick —
**while online**. Porting a tombstone here would add machinery for a problem Android does not have.

**What Android actually has is worse, and it is not limited to clears.**
`…/data/QuizAnswersRepository.kt:43-48`:

```kotlin
fun record(answers: Map<String, String>) {
    scope.launch {
        store.setQuizAnswers(answers)
        val uid = signedInUserId() ?: return@launch
        remote.upsert(uid, answers)
    }
}
```

The local write lands, the push is fired and never checked, and **there is no pending flag and no
retry**. If that push fails — offline, flaky, RLS — the write is simply lost. Then `refresh`
(:52-68) runs on next sign-in:

```kotlin
if (server.isNotEmpty()) {
    store.setQuizAnswers(server)
} else if (local.isNotEmpty()) {
    remote.upsert(userId, local)
}
```

The stale server copy overwrites her local edit. Same visible symptom as the iOS bug, wider blast
radius: it applies to *any* edit made while the network is unhappy, not just a full clear.

Note also that `refresh` pulls first and reconciles second — the inverse of the iOS order.

**Design intent that must survive the port.**

- What to actually port is the **push-then-pull discipline and a persisted pending flag**, not the
  tombstone. Give `record` an owed-push marker in DataStore, drain it before `refresh` pulls, and
  clear it only after a confirmed success — re-reading the answers first, so an edit made during
  the push stays owed.
- Once the gate from #3 exists, `record` must also refuse and report (#2).
- **Keep Android's unconditional empty write.** It is not a bug here; it is why clears work. But if
  you ever add an iOS-style skip-on-empty optimisation, you inherit the iOS bug wholesale.
- iOS's sign-out rule applies to whatever owed-push flag you add: clear it on sign-out so it cannot
  fire against the next account on the device.

---

## 6. Products table read and empty state — already done

Checked because it was on the list; no work needed. Recording the evidence so nobody re-opens it.

- **The read exists.** `…/data/remote/SupabaseUserSupplementRemoteDataSource.kt:58` queries
  `genesyx_products` filtered on `active = true`.
- **Zero rows is handled.** `…/data/GenesyxProductRepository.kt:24-32` — guests short-circuit, and
  both an empty `Success` and an `Error` return `emptyList()`.
- **The empty state exists and reads well.** `…/ui/nutrition/UserSupplementsSection.kt:314-318`:
  "Genesyx supplements are coming soon. They'll appear here the moment they launch."
- **The pH CTA already routes correctly.** `…/ui/track/detail/PhDetailScreen.kt:100-104` calls
  `onOpenPlan`, wired at `…/ui/navigation/GenesyxNavGraph.kt:172-173` to
  `Screen.Nutrition.create(openPlan = true)` → route `nutrition?plan=1` (`Screen.kt:19-20`) →
  `NutritionScreen.kt:88` opens the plan. It does not dump her at the top of Nutrition.

**One caveat.** With the seed migration cancelled and the table empty, Android will show the
"coming soon" copy indefinitely, which is correct and safe. iOS shows four supplements in the same
place because it renders from a bundled constant —
`Sources/GenesyxCore/Content/NutritionContent.supplementPlan`,
`Sources/GenesyxCore/Content/NutritionContent.swift:250-255` — and reads no products table at all.
So the two platforms will legitimately differ here until the range is finalised. That is a content
decision, not a defect; don't "fix" it by seeding products.

---

## 7. Cycle history: the `period_records` table (contract, not yet live)

Added 5 Oct 2026 with the iOS data layer for cycle history. Nothing here is applied or shipped:
the migration is a file (`supabase/migrations/20261006_period_records.sql`) waiting for the
database review gate, and iOS keeps the feature behind `FeatureFlags.cycleHistory` (DEBUG only).
**The migration is not to be applied until this contract is agreed.**

**What changes for Android today: nothing.** Android reads and writes `cycle_settings` only, and
that table, its columns and its meaning are unchanged. `cycle_settings.last_period_date` is
still written by iOS on every change and is still the only input to predictions.

**The new table.** One row per user per period start date.

| Column | Type | Meaning |
|---|---|---|
| `user_id` | `uuid` | owner; row level security is owner only |
| `start_date` | `date` (`yyyy-MM-dd`) | first day of the period. Together with `user_id` it is the primary key |
| `end_date` | `date`, nullable | last day of the period, inclusive. Null until she records one |
| `source` | `text` | `recorded` (she entered it) or `seeded` (the one row copied from her cycle settings when history first switched on). Read an unknown value as `recorded` |
| `created_at` | `timestamptz` | server default |
| `updated_at` | `timestamptz` | stamped by the server on insert and on update; the sync cursor |
| `deleted_at` | `timestamptz`, nullable | tombstone. Null means live |

**Rules a client must follow.**

- **The key is the start date.** Upsert on `(user_id, start_date)`. There is no row id. The same
  start recorded on two devices is one row.
- **A correction is a tombstone plus an insert.** Moving a start from one date to another cannot
  change the key, so it is two upserts: the old date with `deleted_at` set, then the new date.
  Push the tombstone first. If the second write fails, keep it queued and retry: other devices
  then briefly see that period missing, never twice.
- **Send `end_date` and `deleted_at` on every upsert, as an explicit null when empty.** Recording
  again on a date that holds a tombstone must clear `deleted_at`, and clearing an end must clear
  `end_date`; an omitted key leaves the stored value in place.
- **A delete is a tombstone**, never a row delete, so it reaches her other devices.
- **Cycles are derived, never stored.** A cycle runs from one live start to the day before the
  next; the latest is open. Lengths are plain date differences and are never clamped.
- **`cycle_settings.last_period_date` must follow the latest live start** whenever a client adds,
  corrects or deletes a start. `cycle_length` and `period_length` are never rewritten from
  history. Deleting her only start leaves the settings as they are.
- **Which of "new period", "correction" or "past period" a date means** is decided by one rule
  set, in `Sources/GenesyxCore/CycleHistory/CycleHistoryRules.swift` (`apply`, `setEnd`, `delete`,
  `seed`, `settingsInStep`): the same date is no change; within 10 days of an existing start,
  either side, is a correction of the nearest; later than the latest start is a new period;
  earlier is a past period; a future date is refused. Android should adopt these rules
  unchanged. **A JSON test-vector file for them has not been produced yet**; until it exists the
  Swift tests in `Tests/GenesyxCoreTests/CycleHistory/` are the reference.
- **The server range-checks both dates.** `start_date` must be on or after 1900-01-01 and neither
  `start_date` nor `end_date` may be later than tomorrow's date in UTC (the server's clock plus one
  day, so a user ahead of UTC is never refused); anything else is rejected with Postgres error
  23514 (`check_violation`), so validate the same way before sending.
- **Tolerate what a merge can produce.** Two starts a few days apart (two devices recorded the
  same period on different dates) and an `end_date` on or after the next start are both valid
  rows. Show them; never merge or repair them silently. The database has no constraint across
  rows on purpose.

**Until Android implements this, it must tolerate the table and not write it.** Android has no
consent gate (section 3), and period dates are special-category data: no writes to
`period_records` before that gate exists. When Android (or an older iOS build) changes
`last_period_date`, the new iOS app turns that into history on its next sync
(`PeriodReconcile` in `App/Genesyx/Data/PeriodRepository.swift`): more than 10 days after the
latest start appends a record; within 10 days corrects the latest start; anything earlier
changes no history and leaves the settings as they were set.

**Account deletion.** `period_records` is added to `delete_current_user()`
(`20261006b_delete_current_user_period_records.sql`) and to the `delete_account` edge function.
Android's deletion path needs no code change.
