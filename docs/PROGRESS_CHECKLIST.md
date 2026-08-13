# Genesyx iOS — Progress Checklist

> Last verified: **13 Aug 2026**, against HEAD `d0b0c9f` plus the current working tree.
> The date below is the last verification date, not necessarily the original implementation date.
> Only **Done** rows are ticked. Section 4 is deferred and excluded from the Sections 1–3 total.

## Overall progress

| Scope | Done | In progress | In review | Blocked | To do | Total |
|---|---:|---:|---:|---:|---:|---:|
| Sections 1–3 | **36 (82%)** | 1 | 3 | 3 | 1 | 44 |
| Section 4 — deferred | 1 | 0 | 0 | 0 | 4 | 5 |

Latest clean automated evidence: **239 domain, 238 app and 57 UI tests** — 0 failures and 1
pre-existing permission-dependent skip.

## 1A — Vaginal pH feature (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Replace all “urine pH” references with “vaginal pH” | **Done** | 13 Aug 2026 | User-facing Home, pH and guidance copy is vaginal-pH specific. Internal legacy urine typing remains deliberately for safe decoding; it is not shown as the feature. |
| ☑ | Remove pH tracker from Nutrition | **Done** | 13 Aug 2026 | Nutrition opens on its own focus content; pH routes to the dedicated tab. |
| ☑ | Add dedicated pH icon and bottom-navigation link | **Done** | 13 Aug 2026 | Dedicated seventh tab is wired and tested. |
| ☑ | Add result, view history and explain readings | **Done** | 13 Aug 2026 | Logging, trend ranges, interpretation, full dated history, and edit/delete work. Cold-relaunch test proves vaginal type persists. |
| ☑ | Explain pH/vaginal-health relevance to fertility | **Done** | 13 Aug 2026 | Short contextual explanation is present without diagnosis or unsupported causation claims. |
| ☑ | Expand Learn content, including when to seek help | **Done** | 13 Aug 2026 | Cited vaginal-health guidance and professional-help wording are present. |
| ☑ | Move disclaimer into an info/expandable panel | **Done** | 13 Aug 2026 | Main-card disclaimer is collapsible; the logging sheet retains visible safety copy. |
| ☐ | Link to Genesyx website science and Shettles content | **Blocked** | 13 Aug 2026 | H12: exact approved HTTPS pages/URLs are not supplied. Publish/approve both pages first; Shettles must remain framed as an unproven theory. |

## 1B — Tracking, calendar and Profile (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Log symptoms and nutrition from the tracker | **Done** | 13 Aug 2026 | Symptoms work. H4 dated food groups into the Track day sheet, My Logs, Insights and the streak identically on both clients. The daily log sheet now carries its own food-group control, so “Edit this day” can change the meals that same sheet reports, and a meal can be entered from the tracker rather than Nutrition only. Both directions are UI-tested and falsification-proven: ticking/un-ticking round-trips, and saving the sheet no longer wipes a meal logged in Nutrition. **iOS only** — Android reads and syncs meals but still has no control to record one. |
| ☑ | Private sexual-activity logging for TTC users | **Done** | 13 Aug 2026 | Private daily-log field and UI are owner-only; no partner or lock-screen detail exposure. |
| ☑ | Entries persist on the correct calendar date | **Done** | 13 Aug 2026 | Daily logs and pH use dated persistence; pH now survives a real second-process relaunch. |
| ☑ | Colour markers: period, fertile, ovulation, activity, pH, symptoms/notes | **Done** | 13 Aug 2026 | Calendar markers, phase/fertile styling and legend are implemented and tested. |
| ☑ | Notification or highlight for the most fertile stage | **Done** | 13 Aug 2026 | Fertile-window notification and visual fertile-stage highlighting are implemented. |
| ☐ | Audit full Profile section — every edit works | **In review** | 13 Aug 2026 | UI paths exist; H8 still requires disposable-account testing of remote success and failure paths. |
| ☐ | Edit name, password and personal details | **In review** | 13 Aug 2026 | Name editing and password-reset email are wired. Delivery, deep-link return and replacement-password sign-in need live QA; email change is intentionally unsupported and DOB needs a product justification. |
| ☑ | Amend Health Profile and Tracking Preferences | **Done** | 13 Aug 2026 | Both editors are implemented through the existing persistence/sync paths. |
| ☐ | Controls obvious; previous entries genuinely updatable | **In review** | 13 Aug 2026 | Automated tests cover dated logs and older pH edit/delete. Final hands-on Profile and small-screen usability review remains. |

## 1C — Onboarding question (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Girl / Boy / No preference / Prefer not to say | **Done** | 13 Aug 2026 | Four stable options are stored in the owner-only quiz-answer record. |
| ☑ | Optional, with no sex-guarantee suggestion | **Done** | 13 Aug 2026 | Only this question may be skipped; skipping stores no key. Copy guards prohibit efficacy claims. |

## 1D — Connectivity (critical)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☐ | App works over mobile data as well as Wi-Fi | **Blocked** | 13 Aug 2026 | No Wi-Fi-only restriction exists, but H10 requires a physical-iPhone cellular/dead-zone run before this can be ticked. |
| ☑ | Investigate false offline symbol | **Done** | 13 Aug 2026 | Root cause was a non-published owed-days update, not real reachability; fixed and tested. |
| ☑ | Prevent log loss during temporary connection drops | **Done** | 13 Aug 2026 | Local-first queues, owed writes, foreground/reconnect drains and relaunch tests cover temporary drops. Physical-device confirmation remains part of H10. |

## 2A — Restore intended design

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Light mode default; dark mode optional | **Done** | 13 Aug 2026 | Local and production defaults are light; dark remains selectable. Existing server choices were not overwritten. |
| ☑ | Restore egg graphics, including subtle backgrounds | **Done** | 13 Aug 2026 | Egg assets are restored and guarded by tests. |
| ☐ | Review overall presentation for a warm, premium feel | **Blocked** | 13 Aug 2026 | H11 requires a bounded design brief and content-owner approval; this is subjective, not a code-completeness claim. |
| ☑ | Reduce text blocks; use cards, visuals, icons and expandables | **Done** | 13 Aug 2026 | Key pH, Nutrition and guidance surfaces use cards/disclosures; light/dark and small-screen work is covered. |

## 2B — Simplify Nutrition

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Hide greyed-out explanatory text | **Done** | 13 Aug 2026 | Placeholder-heavy/secondary copy no longer dominates the screen. |
| ☑ | Put secondary information in Learn more/Why dropdowns | **Done** | 13 Aug 2026 | Disclosure controls are present for supporting explanations. |
| ☑ | Keep the main Nutrition screen action-focused | **Done** | 13 Aug 2026 | Meal logging, supplement and hydration actions are prioritised over placeholders. |
| ☑ | Meal logging, food groups/nutrients, suggestions, recipes and reminders | **Done** | 13 Aug 2026 | All five exist on the Nutrition screen: meal/food-group logging, focus-food suggestions, eight recipe cards and per-supplement reminder times (stored, scheduled and cleared on sign-out). H4 closed the last objection by dating those meals into Track, My Logs, Insights and the streak. |
| ☑ | Replace text-only suggestions with meal/recipe cards | **Done** | 13 Aug 2026 | Eight actionable recipe cards replace plain food-name suggestions. Real photography remains part of H11, not this functional row. |

## 2C — Hydration logging

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Add water by glasses or millilitres | **Done** | 13 Aug 2026 | Both display/input modes use canonical ml storage. |
| ☑ | Custom glass size and correction of wrong entries | **Done** | 13 Aug 2026 | Custom size and dated edit/correction paths are implemented. Cross-device preference sync remains H9. |
| ☑ | Show progress towards the daily target | **Done** | 13 Aug 2026 | Home, Track, Nutrition and Insights use real logged water/target data. |

## 2D — Contextual cycle guidance

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Visual card when entering a new cycle phase | **Done** | 13 Aug 2026 | Phase-change card is implemented with once-per-phase presentation logic. |
| ☑ | Link the phase card to a relevant article | **Done** | 13 Aug 2026 | Card routes to the relevant cycle-eating guidance. |
| ☑ | Personalise Home greeting with the user’s name | **Done** | 13 Aug 2026 | Home uses the signed-in display name with a safe fallback. |

## 3A — Daily logging streak

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☐ | Count meaningful symptoms, hydration, nutrition, cycle, pH and article actions | **In progress** | 13 Aug 2026 | Symptoms, hydration, pH and — since H4 — meal-only days all count, under one definition shared by both clients and pinned by the tracking vectors. Cycle edits (H3) and article reads (H6) still do not count. **H6 was scoped on 13 Aug and is larger than it reads:** `LearnReadLog` stores reads as an undated slug `Set` in `UserDefaults`, device-local and cleared on sign-out, and `daily_logs` has no column for them — so there is no date for a daily streak to key on and nothing to sync. Counting reads means dated read events, a new production Supabase column, an Android Room migration and both vector files. Needs sign-off before it starts, because it is a production schema change. |
| ☑ | Show current streak and milestone celebrations | **Done** | 13 Aug 2026 | Current streak is shown on Home and the Consistency card. Milestones now celebrate **in the app** as well as by notification, above the tab bar so the moment reaches her wherever she logged. The in-app half deliberately does not require notification permission — it was behind that gate, which meant the woman who declined notifications was congratulated for nothing. The cross-platform rule is agreed and matched: the 7- and 14-day milestones follow the *logging* streak — the number she is actually shown — on both clients, changed in the same sitting. Restore is still a product decision, tracked in its own row. |
| ☑ | Encouraging, no-guilt language | **Done** | 13 Aug 2026 | Notification and streak-copy guards enforce neutral encouragement. |
| ☐ | Consider occasional streak restore | **To do** | 13 Aug 2026 | H7 product decision: define grace, allowance and whether restore state syncs before implementation. |

## 3B — Education

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | One new article weekly plus dashboard/in-app discovery | **Done** | 13 Aug 2026 | Weekly reveal schedule, Home card, Learn badge and Sunday notification are implemented. |
| ☑ | Push notifications only after opt-in | **Done** | 13 Aug 2026 | App requires user preference plus system permission; production `push_enabled` now defaults false. |
| ☑ | Twelve-week content plan scheduled | **Done** | 13 Aug 2026 | All twelve cited topics, including evidence-framed Shettles content, are present and scheduled. |

## 4 — Clarify/scope separately (excluded from completion percentage)

| ✓ | Task | Status | Date | Notes |
|---|---|---|---|---|
| ☑ | Confirm current Add Partner behaviour | **Done** | 13 Aug 2026 | Invite, account acceptance, linking and unlinking exist. Partner currently receives the user’s display name only; health logs are owner-only and no partner reminder feed exists. |
| ☐ | Define partner sharing controls with privacy by default | **To do — deferred** | 13 Aug 2026 | No per-category permission model exists. Current private health/log tables remain owner-only. |
| ☐ | Confirm/scope Apple Health, Watch and Oura | **To do — deferred** | 13 Aug 2026 | No HealthKit entitlement, usage keys or wearable integration exists; separate estimated scope remains required. |
| ☐ | Scope a privacy-controlled iPhone widget | **To do — deferred** | 13 Aug 2026 | No WidgetKit target exists. Requires a separate privacy and data-refresh design. |
| ☐ | Scope barcode scanning/meal photos | **To do — deferred** | 13 Aug 2026 | No AVFoundation/VisionKit pipeline exists; treat as a future technical/product scope. |

## Remaining work in practical order

1. Reconcile the exact applied Supabase migration into both repos and run disposable-account deletion QA.
2. Add the food-group control to Android's log form — done on iOS 13 Aug, and on Android it is still
   the only way to enter a meal at all (it currently reads and syncs them but cannot record one).
3. Complete H8 Profile/password journeys with disposable accounts and H10 on a physical iPhone.
4. Decide H3 real period history, H6 article/cycle streak events, H7 celebrations/restore and H9 hydration-preference sync.
5. Supply H12 website URLs/content and approve the H11 design/photography brief.
