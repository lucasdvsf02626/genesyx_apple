# Genesyx iOS — Session Handoff

> Written 2026-08-11, reconstructed from the 2026-08-10 session (which ended on token exhaustion
> before this could be saved). Companion to `CHANGE_LIST_PLAN.md`, which tracks the client's
> change list task-by-task. This file tracks **what is in flight right now**.

**Branch:** `main` · **HEAD:** `24f8255`, plus a large uncommitted tree (§4b) · **Version:** 1.2.0 (18)
· **Test baseline:** 179 domain + 186 app + 39 UI (38 + 1 skipped on a simulator that has already
answered the notification prompt) — all three verified green 2026-08-11

```bash
swift test && xcodebuild test -project Genesyx.xcodeproj -scheme Genesyx \
  -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:GenesyxUITests
```
Do **not** pass `-quiet` — it has returned exit 0 with no summary and hidden a real result.

---

## 1. Shipped 2026-08-10 (committed)

| Commit | What it did |
|---|---|
| `998b5c2` | T28 second half — Learn unread badge + Home dashboard card, one shared rule |
| `24f8255` | T25 — Nutrition phase-change card linking to `eating-with-your-cycle` |
| `9d08d82` | Privacy — moved `quiz_answers` off the partner-readable `profiles` row |
| `1e6ec6f`, `e9a5518` | Security — closed the self-declared-partner exposure |
| `a61d571` | Doc note: `ProfileRow.partner_id` is write-guarded, so a future write fails loud |
| `db9cb07` | Changelog — **Sprint 1 only**, does not yet cover the privacy/security batch |

## 2. Supabase state (dashboard — leaves no trace in this repo)

This is the part git cannot tell you. Verify here before assuming.

| Change | Status |
|---|---|
| `quiz_answers` owner-only table + RLS policy | ✅ Applied & verified |
| `partner_id` UPDATE revoke (`authenticated` + `anon`) | ✅ Applied & verified — 0 pre-existing bad links found |
| `daily_logs.sexual_activity` column | ⚠️ **Unconfirmed — verify first.** Written `20260810_daily_logs_sexual_activity.sql`, never recorded as applied |
| `join_waitlist` RPC + `waitlist_emails` table | ⚠️ **Unconfirmed — verify first.** `20260811_waitlist_emails.sql`, written 11 Aug; the objects were never in this repo at all before that |
| `created_at` / `updated_at` UPDATE revoke | ⬜ Written, **held** pending web check (task 18) |
| `alter table profiles drop column quiz_answers` | ⬜ Written, **held** pending web check (task 18) — *not* on build 18, see §4 |

Both ⚠️ rows fail **silently**, which is why they are pre-flight items in `TESTFLIGHT_B18.md` rather
than something a test could catch. The decoders tolerate a missing `sexual_activity` column, so
intimacy logging would work on screen and sync nothing. The waitlist is the sharper of the two: the
client has called `join_waitlist` since the screen was wired up, but no migration in this repo ever
created it, so the schema existed only in whatever was typed into the dashboard — if it was typed at
all. The new migration is idempotent, so applying it is safe either way.

## 3. Client audits — who writes `profiles`

| Client | `partner_id` write | `quiz_answers` touch | timestamp write | Verdict |
|---|---|---|---|---|
| iOS (this repo) | No — write-guarded | No — repointed to new table | No | Clear |
| Android | No — sole caller hardcodes `null` | No — discarded after onboarding | No | Clear, latent hazard (task 24) |
| Web | Unknown | Unknown | Unknown | **Not checked — blocks 19 and 23** |

## 4. Open tasks

| # | Task | Blocked by | Where |
|---|---|---|---|
| 18 | Confirm whether a live web client writes `profiles` | — | Supabase Edge Logs → `PATCH /rest/v1/profiles`, group by user agent |
| 21 | CHANGELOG entry for the privacy/security batch **+ T23** | — | Covers `9d08d82` → HEAD |
| 25 | Sync hydration display prefs (unit **and** glass size) to `profiles` | — | New — see below. One change with Android, not half of one here |
| 24 | Android: drop `partner_id` from the DTO write path | — | Android repo — harmless today only because the caller passes `null` |
| — | Verify `daily_logs.sexual_activity` applied | — | Supabase SQL Editor — **pre-flight 1** in `TESTFLIGHT_B18.md` |
| — | Apply `20260811_waitlist_emails.sql` | — | Supabase SQL Editor — **pre-flight 2**. Idempotent |
| 19 | Supabase: revoke UPDATE on `created_at` / `updated_at` | 18 | One-liner once web is cleared; triggers unaffected |
| 22 | Ship build 18 to TestFlight | pre-flight 1–3 | Version bumped to 1.2.0 (18) and notes written — `TESTFLIGHT_B18.md`. What remains is the three pre-flight checks, then archive and upload |
| 23 | Supabase: drop `profiles.quiz_answers` | 18 | ~~Blocked on build 18 being live~~ — it never was. See below |

**Critical path:** 18 → 23, and 22 on its own. Everything else runs in parallel.

### Task 23 is not blocked by build 18 — corrected 2026-08-11

This table used to read `18, 22`, on the grounds that "build 17 users still select that column." They
do not, and the dates settle it: build 17 was cut at `6bc452d` and its TestFlight notes written at
`ddce23f`, **both on 29 July**. `quiz_answers` was first added to the client's `profiles` select at
`148e754` on **10 August** — twelve days later — and was moved off the row again at `9d08d82` the
same day. So the column was never in a shipped binary's select list; it existed only in commits that
have never been uploaded. That is the same fact the migration states in its own words: *"the column
landed today and has never shipped in a TestFlight build."*

Nor does the build-18 candidate write it: `ProfilePrefsRow` (`RemoteModels.swift:202`) encodes
`id, focus_mode, theme, push_enabled` and nothing else, which `RepositoryTests.swift:580` already
asserts. Both directions are clear.

What remains is task 18 alone — a web client nobody has checked could still be selecting the column,
and that has nothing to do with which iOS build is live. Shipping 22 first was doing no work.

### Task 25 — why it exists

T23 shipped the custom glass size **device-local**, matching `hydration_unit`, which was already
device-local (read straight from `UserDefaults` at four call sites, now consolidated into
`HydrationPrefs`). Syncing the glass size on its own would be incoherent: she would arrive on a new
phone with her 300 ml glass honoured but the unit reset to millilitres, where a glass size means
nothing. So the real task is moving **both** to her `profiles` row — one migration, one coordinated
change with Android, which also closes the display-parity gap T23 opens (iOS can now describe the
same water as a different number of glasses than Android). No data divergence either way: storage
is always `waterMl`.

## 4b. Shipped 2026-08-11 (uncommitted)

**T23 — custom glass size.** The last gate-free item on the client change list.
- `Sources/GenesyxCore/Insights/HydrationUnit.swift` — `glassRangeMl` (50–1000), `resolvedGlassMl`,
  `mlPerUnit` property → method taking `glassMl`, `HydrationFormat` threads `glassMl` throughout
- `App/Genesyx/UI/HydrationPrefs.swift` — **new**; the two keys read in one place
- `ProfileView` — glass-size field, shown only when the unit is glasses
- `HomeView` · `TrackView` · `NutritionView` — call sites updated; Home's card also moved from an
  unobserved `UserDefaults` read to `@AppStorage`, so it no longer went stale when the unit changed
- `Tests/GenesyxCoreTests/HydrationUnitTests.swift` — +5 tests (bounds, fallback, cups/ml ignore the
  setting, divide-by-zero, pre-T23 default behaviour preserved)

Adding `HydrationPrefs.swift` required `xcodegen generate`; regeneration was verified diff-clean
beforehand, and `project.yml` already pins the version keys so it cannot clobber the build number.

**T28 — the weekly Learn series.** Eleven articles released one a week, with hero art, an unread
badge, a Home card and an opt-in-gated Sunday nudge. The articles are a `let` array in the binary;
the drip is date-gated on `CalendarDate`, so no server is involved. Guarded by 11 new tests — 6 on
the drip gate, 3 on citation integrity, 1 hero-asset existence, 1 end-to-end drop.

**T21 — egg artwork.** `BrandEgg` in `GenesyxControls.swift` replaces the four `BrandOrb` stand-ins
on the onboarding splash. The blocker G4 said "request original design files from client"; the files
had been sitting in the asset catalog since 10 July with zero Swift references, so nobody was ever
waiting on anyone. Re-exported 1024px → 512px first (1.4 MB → 222 KB; 512 is exactly 1:1 for the
largest 170pt use at 3x). `BrandAssetTests` — **new file, needed `xcodegen generate`** — guards both
existence and minimum resolution, because `Image("egg_female")` renders nothing when the asset is
missing and says so nowhere.

**Waitlist.** Copy fix, backend wiring, and `supabase/migrations/20260811_waitlist_emails.sql` —
which is new not because the schema changed but because it had never been written down. RLS on with
zero policies as the lock, one `SECURITY DEFINER` RPC as the only door.

**P0-4 — `drainPending()`.** `SyncError.isTransport` → `shouldHaltDrain`, now also true for
`RemoteError.notAuthenticated`. A regression **inside this uncommitted batch, never shipped** —
build 17 stops the drain on any failure and has no `SyncError` at all. Introducing "step over a
rejected row" was right, but it also made a missing session look like a per-row rejection, so a
signed-out foreground would have walked the whole backlog one doomed call at a time instead of
stopping at the first. Full reasoning in `TESTFLIGHT_B18.md`.

**Version.** `project.yml` → 1.2.0 (18), `xcodegen generate` run. The pbxproj delta was exactly the
four version lines plus eight for `HydrationPrefs.swift` and `BrandAssetTests.swift`.

> **This file is untracked in git** (`git log -- docs/HANDOFF.md` is empty; it is not ignored).
> Pre-existing, not deliberate as far as anyone has recorded. Worth adding in the next commit.

## 5. Still gated on the client (unchanged)

| Gate | Needs | Blocks |
|---|---|---|
| G1 | Written client + medical-reviewer sign-off to relax banned-phrase guards | T7, T29b (Shettles, Girl/Boy) |
| G2 | pH tab placement decision — 6 tabs already, a 7th is cramped on an SE | T1 + T2 |
| G3 | Build number + screenshot for the "offline symbol" — no such code path exists | T9 |
| ~~G4~~ | ~~Original egg artwork files~~ — never actually blocked; the files had been in the catalog since 10 Jul. T21 shipped. | — |

AI compresses engineering days, not approval days. G1 is calendar time.

## 6. Carried constraints — do not trip these

- **Banned-phrase guards are test-enforced**, not documentation. Seven test files assert
  user-facing copy excludes `sex selection`, `boy or girl`, `gender sway`, `alkaline diet`,
  `detox` and others; pH articles also ban `infection`, `thrush`, `candida`, `vaginosis`, `bv`.
  Changing copy can fail the build. Relaxing them is a compliance decision, never a quiet test edit.
- **`sexualActivity` is deliberately excluded** from `TrackingEngine.isMeaningfulLog` and
  `StreakEngine.hasAnyEntry`. Those predicates mirror the Android client against a shared
  `tracking_test_vectors.json`. Widening one alone gives the two platforms different streaks for
  identical data. Flip it in both clients and the vectors in one change, or not at all.
  `MeaningfulLogTests` fails if someone flips it unilaterally.
- **Quiz question ids are storage keys.** Renaming one orphans every answer already given to it,
  on both clients. `QuizContentTests.testFiveQuestionsInOrder` pins them.
