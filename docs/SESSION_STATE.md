# Genesyx iOS — Session State Checkpoint

**Branch:** `claude/blissful-carson-wsdb54` (release)
**HEAD at checkpoint:** `9220c69` — "Hide Pregnancy preview entry points for v1.0"
**Working tree:** clean · **Pushed:** no (3 commits ahead of `origin`, all local)

## Commit stack (newest first)
| Hash | Summary |
|------|---------|
| `9220c69` | Hide Pregnancy preview entry points for v1.0 |
| `99fccc4` | Fix: clear local health data on sign-out/delete; rehydrate on sign-in |
| `52fc94f` | v1.0 release baseline: SwiftUI port + submission fixes (tag `v1.0-baseline`) |
| `1549319` | Fix first build (pre-session) |

## Done (verified: clean Release build + 29/29 tests green)
- **Baseline `52fc94f`** — entire working tree committed and tagged `v1.0-baseline`. Includes:
  - **Insights fake content hidden** — mock cycle/nutrition bar charts + `sin()` symptom heatmap wrapped in `/* */` (`InsightsView.swift`); only the real pH insight renders.
  - **Dead Nutrition card removed** — the `"Nutrition" / "On track"` mini-card with empty action deleted from `LogView.swift`. (`"On track"` grep = 0.)
- **Cache-wipe `99fccc4`** — `clearLocalState()` on `AppContainer` wipes cycle/pH/daily-log from memory + `LocalStore` on `signOut()` and `deleteAccount()` success; sign-in rehydrates via existing `refresh()`. Tests: `testSignOutClearsLocalHealthData`, `testDeleteAccountClearsLocalHealthData`, UI `testSignOutClearsHealthDataLocally`.
- **Pregnancy-hide `9220c69`** — both preview entry points made unreachable (commented, destinations intact): `HomeView` `pregnancyPathwayLink` and `ProfileView` focus-segment `showPregnancy = true`. No uncommented entry remains.

## Backend (verified read-only, project `epltxklawpcxxbaleswg`)
- GREEN: live (GoTrue healthy), anon RLS airtight (`*/0` all 5 tables), 3 edge functions deployed + 401-gated, HTTPS/HSTS, OAuth Google+Apple configured, only publishable key ships (matches `project.yml:91`), Release resolves this project with no mock fallback.
- PENDING (human/terminal): authenticated two-account RLS isolation; `delete_account` cascade confirmation.
- ACCEPTED: Free tier (no PITR), server password floor 6 vs app 8, Apple OAuth secret 6-mo renewal, email-confirm OFF (documented).

## Open items (3)
1. **Learn build — awaiting handoff files.** Blocked at READBACK GATE: `docs/android-handoff/IOS_LEARN_PARITY_HANDOFF.md` and `docs/android-handoff/articles.json` do not exist in the repo, and the hero-images folder path was not provided. No Learn code written. `feature/learn-parity` branch (→ `9220c69`) is obsolete; delete once Learn lands.
2. **RED-1 — Nutrition-tab article placeholder still open.** `NutritionView.ArticleSheet` renders one hardcoded paragraph ("Keep the focus simple…") for every article (grep = 1). EDIT 1 never ran (no article content supplied). **Decision needed:** does the new Learn hub supersede the Nutrition-tab articles (hide/remove that section), or fix EDIT 1 separately? Must be resolved before archive.
3. **Archive commit — TBD.** `9220c69` is NOT the archive commit. Archive is gated on: RED-1 resolved, and (if in scope) Learn landed. Carries `1.0.0 (1)`.

## Next-session entry point
Provide the two Learn handoff files + image folder path → do readback → build Learn on release branch. In parallel, decide RED-1 (supersede vs fix). Then designate the archive commit and run the human submission checklist (device QA incl. the 4 cache-wipe checks, ASC record, archive/upload/TestFlight/submit).
