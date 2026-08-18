<!-- converted from Genesyx_Intelligent_Partner_Implementation_Blueprint.docx -->

PRODUCT & ENGINEERING BLUEPRINT
Genesyx Intelligent Partner
Repository assessment, 7-to-30-day guidance programme, notification logic and implementation plan

Positioning  Genesyx turns the information you choose to track into a clear personal picture. It helps you notice routines, review repeated timing and decide what to track or discuss next - without pretending to diagnose you.


This document consolidates the technical assessment and implementation planning discussed in the working session. Current repository facts are separated from proposed behaviour and from decisions that require medical, product or privacy approval.

# Contents
- 1. Executive summary
- 2. Current repository and technical architecture
- 3. Existing product capabilities
- 4. Target intelligent-partner experience
- 5. Evidence and maturity model
- 6. The 7-to-30-day customer programme
- 7. Domain guidance specifications
- 8. Track and Insights experience
- 9. Notification programme
- 10. Proposed technical architecture
- 11. Implementation contracts and algorithms
- 12. Delivery roadmap
- 13. Testing and verification
- 14. Safety, privacy and approval gates
- 15. Definition of done and implementation backlog
How to use this document  Engineering should implement the core evidence and guidance contracts before adding new UI or notification copy. Product and clinical owners must approve thresholds and health language before release.

# 1. Executive summary
Genesyx is already a local-first fertility and cycle-awareness application with repository-backed daily tracking, pure calculation logic, real-data insights, local notification scheduling and optional Supabase synchronization. The proposed programme should connect these existing parts into one explainable system that behaves like a thoughtful partner rather than a collection of independent trackers.
## Target outcome
After customers record data, Genesyx should progressively unlock summaries, comparisons and early patterns. Every output should distinguish recorded fact from derived observation, state why it appeared, show its evidence coverage, include an honest limitation and offer a small action inside the app.
Core product rule  The system must often choose silence. Thin or missing data is not a reason to manufacture a chart, prediction, recommendation or notification.
## Recommended implementation order
- Approve evidence thresholds and language.
- Build a pure GuidanceEngine in GenesyxCore.
- Integrate individual signal results into Track and Insights.
- Add cross-signal observations only after individual results are verified.
- Extend NotificationPlanner with exact destinations, deduplication and sensitivity rules.
- Add two- and three-cycle intelligence only after historical cycle-event data is sufficient.
## What success looks like
- Customers understand what was recorded and what was calculated.
- Track and Insights never disagree.
- Every recommendation is tied to evidence and an in-app action.
- Sensitive data stays off the lock screen.
- No result implies diagnosis, causation or confirmed ovulation.
- Notifications stop when the underlying task is complete.

# 2. Current repository and technical architecture
## 2.1 Verified current state

## 2.2 Runtime flow
SwiftUI screen -> observable repository -> immediate local write -> optional remote push/pull -> GenesyxCore calculation -> view model/result -> cards, charts, guidance and notification candidates.
## 2.3 Responsibilities

## 2.4 Architectural strengths
- Core calculations are independently testable without launching Xcode.
- Repositories are local-first and preserve pending changes during network failure.
- The UI is connected to actual records rather than sample charts.
- Notification copy is produced by pure logic and is reachable from unit tests.
- Account-scoped health state is cleared on sign-out or deletion.
## 2.5 Current constraints
- UserDefaults is lightweight storage, not an encrypted relational health database.
- Most screens use repositories directly rather than dedicated ViewModel types.
- Cycle settings describe one projected cycle; they do not yet form a longitudinal period-event history.
- Daily water is a total, so the app cannot infer morning or evening drinking patterns.
- Sleep stores duration, not sleep quality or sleep stages.
- Repository documentation contains older snapshots and cannot prove live App Store or backend state.

# 3. Existing product capabilities

## Current notification invariants
- No filler: a slot with nothing true to say returns no notification.
- At most one general notification on a day.
- Never guilt customers for lost streaks or missed days.
- After two silent weeks, send one gentle hand-back and then stop.
- Keep sensitive fertility, pH, symptoms and intimacy detail off the lock screen.
- Customer-created supplement reminders are opt-in and use stable supplement identifiers.

# 4. Target intelligent-partner experience
## 4.1 The customer loop

## 4.2 The standard insight card

Trust requirement  Never show an unexplained score or percentage confidence. Use evidence labels such as Building, Ready to review, Early pattern and Repeated across cycles.

# 5. Evidence and maturity model
## 5.1 Internal evidence states

## 5.2 Per-signal coverage
A report must never use one global statement such as “30 days of data” when individual signals have different coverage. It must count actual valid entries for water, sleep, supplements, symptoms, pH and cycle context independently.

## 5.3 Proposed thresholds requiring approval

# 6. The 7-to-30-day customer programme
## 6.1 Day 0: start the picture
Customer message  A few small entries will help Genesyx understand your routines. You do not need to track everything at once.
- Set up cycle.
- Log sleep, water, supplements and symptoms as relevant.
- Add vaginal pH only if the customer uses pH testing.
- Choose notification categories and reminder times.
Allowed intelligence: none beyond onboarding answers, recorded facts and cycle estimates from completed settings.
## 6.2 Days 1-3: the picture is beginning
Customer message  You have started tracking. Genesyx can show what you recorded, but there is not enough information to describe a pattern yet.

## 6.3 Day 7: first weekly picture
Unlock message  Your first weekly picture is ready. You logged enough to review your hydration, sleep and supplement routine.
- Show days logged and exact per-signal coverage.
- Show hydration goal days and average across logged days.
- Show average sleep across logged nights only.
- Show supplement days and most consistently recorded items.
- Show symptom counts but avoid a pattern claim unless the symptom threshold is met.
- Show a basic pH comparison only with enough valid vaginal readings.
- Show cycle predictions as estimates.
## 6.4 Day 14: two-week comparison
Unlock message  You now have enough recorded information to compare this week with last week.
- Compare water averages and goal days when both weeks contain water.
- Compare sleep averages only when both weeks contain sleep.
- Compare supplement logging days.
- Compare symptom frequency and contributing dates.
- Do not treat a missing week as zero.
- Do not describe current-cycle observations as recurring cycle patterns.

## 6.5 Day 21: emerging routines
Unlock message  Three weeks of records can show which routines are steady and which areas still need more information.
- Rank signals by tracking coverage.
- Identify stable routines without claiming biological causation.
- Compare weekdays where appropriate.
- Show cycle-day timing as a current-cycle observation.
- Tell the customer which signal needs more data.
## 6.6 Day 30: personal monthly picture
Unlock message  Your 30-day picture is ready. Genesyx can summarize your routines, show early repeated timing and help you choose what to focus on next.
### Thirty-day report sections
- What you tracked: exact dates and coverage.
- Your strongest routine: highest-quality signal.
- What changed: valid week or period comparisons.
- What appeared together: cross-signal timing with denominators.
- Three next actions: prioritized and achievable inside the app.
- What is not known yet: explicit evidence gaps.
- Optional shareable factual summary for a healthcare professional.
## 6.7 Beyond 30 days: cycle-aware intelligence

# 7. Domain guidance specifications
## 7.1 Cycle
Inputs: last period date, cycle length, period length, calendar date and future period-event history when added.
- Current cycle day and phase estimate.
- Predicted fertile window and estimated ovulation day.
- Days until predicted window or period.
- Recorded symptoms, sleep and pH placed in cycle-day context.
- Multi-cycle timing only after enough complete cycles.
Required limitation  Predictions come from saved cycle settings. They are not measurements and do not confirm ovulation.
## 7.2 Vaginal pH
- Use vaginal readings only for vaginal insights.
- Preserve legacy urine readings with neutral labelling.
- Show latest value, seven- and thirty-day averages where valid, and recent direction.
- Require at least two recent readings before interpretive copy.
- Do not infer cause, diet, condition or treatment.
- Show approved healthcare signposting only under clinically approved rules.
## 7.3 Supplements and nutrition
- Count logged days and per-supplement frequency.
- Support fixed and custom supplements.
- Respect customer-created reminder times.
- Connect phase-aware nutrition content without claiming prescription.
- Do not infer deficiency, effectiveness, suitability or adherence from logging.
## 7.4 Symptoms
- Count occurrences and symptom days over 28 days.
- Show contributing dates and co-occurring recorded signals.
- Use “appeared together” rather than causal language.
- Keep the existing thin-data guard for pattern claims.
- Require clinical approval for red-flag signposts and escalation wording.
## 7.5 Sleep
- Average across logged nights only.
- Compare weeks only when both contain sleep.
- Relate sleep duration to next-day energy only on comparable dates.
- Do not infer quality, sleep stages or a disorder from duration.
- Offer optional bedtime and morning logging reminders.
## 7.6 Hydration
- Store and calculate in millilitres.
- Convert only the input/display layer to glasses or cups.
- Show goal days, average, current progress and streak.
- Use time-of-day coaching only from current progress and clock time.
- Do not claim hydration caused an energy, symptom or pH outcome.

# 8. Track and Insights experience
## 8.1 Track answers: What did I record and what next?
Every Track card should include today’s value, recent coverage, sync state, honest empty state, log/edit action and a View insight action when evidence is ready.

## 8.2 Insights answers: What is the data beginning to show?
- Ready now: results with sufficient evidence.
- Building: progress toward a useful result.
- Your week: sleep, hydration, supplements and meaningful logging.
- Cycle context: estimates and current-cycle observations.
- Review with a professional: approved signposts only.
- Your 30-day picture: consolidated monthly programme.
## 8.3 Recommended top-level card
Your picture  You logged on 5 of the last 7 days. Genesyx can now show your hydration rhythm, average sleep across 4 logged nights and supplement consistency. Keep tracking symptoms and pH to unlock those patterns.
## 8.4 Navigation requirements
- Track card -> exact detail editor.
- Track “View insight” -> exact insight card.
- Insight -> contributing dates.
- Contributing date -> existing daily record.
- Notification -> exact report/card/editor, not just a general tab.
- Back navigation preserves selected tab and scroll state.

# 9. Notification programme
## 9.1 Priority order
- Customer-created supplement or sleep reminder.
- Time-sensitive predicted cycle event.
- Newly unlocked meaningful report.
- New pattern that crossed an approved threshold.
- pH tracking cadence.
- Sleep or hydration check-in.
- General Track or Learn invitation.
## 9.2 Notification matrix

## 9.3 Global scheduling rules
- Maximum one app-selected notification per day.
- Maximum three intelligent-partner notifications per week; retain a separate cap for the established weekly planner if required.
- Customer-created supplement reminders remain separate and individually controlled.
- Never notify again for an unchanged result; use a data signature.
- Recalculate after a save, edit, delete, foreground refresh or preference change.
- Cancel a scheduled message when its condition becomes false.
- Respect quiet hours, category mutes and system authorization.
- After 14 inactive days, send one gentle return invitation and then stop.
- Never expose symptoms, pH values, intimacy or fertility detail on the lock screen.
## 9.4 Required preference controls
- Master notification switch.
- Daily check-in time and quiet hours.
- Cycle, pH, symptoms, sleep, hydration, Insights and Learn categories.
- Per-supplement reminder time.
- Sleep bedtime and morning-log choices.
- Discreet versus descriptive preview preference, subject to privacy review.

# 10. Proposed technical architecture
## 10.1 New core module
Create Sources/GenesyxCore/Guidance/ with pure, synchronous, deterministic logic. It should accept a snapshot and produce ordered GuidanceResult values. It must not read UserDefaults, call Supabase, schedule notifications or render UI.

## 10.2 App integration

Data ownership  GuidanceRepository must read the existing CycleRepository, DailyLogRepository and PhRepository. It must not create another health-data store.

# 11. Implementation contracts and algorithms
## 11.1 GuidanceResult contract

## 11.2 Comparable-date algorithm
- Select the requested date window.
- Create the set of dates where signal A has a valid entry.
- Create the set of dates where signal B has a valid entry.
- Intersect the sets; these are the only comparable dates.
- Require the approved minimum denominator.
- Calculate counts without filling missing values with zero.
- Return contributing dates and denominator.
- Attach the approved non-causation limitation.
## 11.3 Period comparison algorithm
- Build the current and previous windows using CalendarDate.
- Calculate coverage independently for each period.
- Return collecting state if either period lacks evidence.
- Compare averages or counts only across valid recorded values.
- Name the denominator for both periods.
- Use neutral direction wording: higher, lower or level.
- Do not label change as improvement or deterioration unless explicitly approved.
## 11.4 Prioritization model

# 12. Delivery roadmap

## 12.1 Suggested code sequence
- Define types and fixtures before UI.
- Implement per-signal coverage calculators.
- Implement 7-, 14-, 21- and 30-day windows.
- Implement result builders and limitations.
- Implement stable signatures and ordering.
- Add GuidanceRepository and dependency injection.
- Add Your picture UI and detail views.
- Add exact route support.
- Extend NotificationPlanner and NotificationService.
- Complete tests, device verification and approval review.

# 13. Testing and verification
## 13.1 Pure logic tests
- Zero data, one entry, threshold-minus-one, exact threshold and threshold-plus-one.
- Missing dates are absent, not zeros.
- Previous-week comparisons require evidence in both periods.
- Cross-signal denominators use intersected dates only.
- Legacy urine pH never enters vaginal guidance.
- Millilitres remain unchanged across display units.
- Cycle language always says predicted or estimated.
- Every output includes its evidence state and limitation.
- Stable input produces a stable signature and ordering.
## 13.2 Notification tests
- Maximum frequency and day collision rules.
- Muted category consumes no budget or schedule.
- Task completion cancels the related notification.
- Unchanged result does not notify twice.
- Sensitive content never appears in title/body.
- Every payload resolves to the exact destination.
- Time-zone, DST, midnight and past-fire handling.
- Fourteen-day inactivity hand-back then silence.
- Customer-created reminders are retained or removed correctly.
## 13.3 Repository and data tests
- Local-first update publishes guidance immediately.
- Stale remote state cannot overwrite pending local changes.
- Delete/tombstone removes the associated guidance result.
- Sign-out clears guidance, reviewed state and sensitive reminder state.
- Another account cannot inherit cached results.
- Hydration, sleep, symptoms and supplements continue using DailyLogRepository.
## 13.4 UI and device verification
- Track and Insights display identical metrics.
- Empty, collecting and ready states render correctly.
- Contributing dates open the correct records.
- Dynamic Type, VoiceOver, contrast and reduced-motion checks.
- Notification permission denial and Settings recovery.
- Cold-start notification routing on a physical device.
- No sensitive notification preview.
- Archive/signing and release build contain no debug seed path.

# 14. Safety, privacy and approval gates
## 14.1 Engineering must not decide
- Clinically appropriate pH cadence or escalation threshold.
- Symptom red flags and professional-help wording.
- Sleep-duration thresholds or age-specific health recommendations.
- Hydration recommendations beyond existing approved goals and citations.
- Supplement dose, interaction, suitability or treatment language.
- Default opt-in state for sensitive cycle and symptom notifications.
- Any diagnosis, classification or treatment recommendation not already approved.
## 14.2 Prohibited behaviours

## 14.3 Required limitation patterns
- These entries appeared together; Genesyx cannot determine whether one caused another.
- This is an estimate based on your saved cycle settings.
- One reading is a record, not a trend.
- This early pattern is based on two recorded cycles; continue tracking to see whether it repeats.
- This summary is not a diagnosis and does not replace professional medical advice.

# 15. Definition of done and implementation backlog
## 15.1 Programme definition of done
- Every insight is generated from repository data.
- Every metric includes an honest denominator.
- Every result has an explanation, limitation and contributing evidence.
- Every action is specific and achievable.
- No more than three actions are prioritized.
- Track and Insights reuse the same GuidanceResult.
- Every notification has an exact destination and deduplication signature.
- Sensitive information stays inside the authenticated app.
- All medical language and thresholds are approved.
- Pure, repository, UI and device tests pass.
- Inventory and architecture documentation are refreshed after implementation.
## 15.2 Build backlog

## 15.3 Final positioning
Genesyx Intelligent Partner  Genesyx turns the information you choose to track into a clear personal picture. It helps you notice routines, review repeated timing and decide what to track or discuss next - without pretending to diagnose you.
End of implementation blueprint.
| Document field | Value |
| --- | --- |
| Purpose | A build-ready specification for the intelligent tracking and insights programme. |
| Scope | Cycle, vaginal pH, supplements, nutrition, symptoms, sleep, hydration, insights and local notifications. |
| Current code baseline | Native SwiftUI app with GenesyxCore, repository persistence and optional Supabase sync. |
| Implementation status | Planning only. The intelligent-partner programme described here is not yet implemented. |
| Prepared | 12 August 2026 |
| Area | Current state |
| --- | --- |
| Platform | Native iPhone application; iOS 16.0 minimum. |
| Language and UI | Swift 5.9, SwiftUI and Swift Charts. |
| Architecture | Observable repositories, manual dependency injection and a pure domain package. |
| Configured version | 1.2.0, build 18 in project.yml. |
| Navigation | Seven persistent tabs: Home, Track, pH, Nutrition, Insights, Learn and Profile. |
| Local persistence | Codable records stored through LocalStore in namespaced UserDefaults keys. |
| Remote services | Supabase Auth, PostgREST tables and Edge Functions. |
| Dependencies | Supabase Swift and Google Sign-In; system AuthenticationServices and Charts. |
| Analytics and ads | No third-party analytics or advertising pipeline found. |
| Core verification | 180 GenesyxCore tests passed with zero failures during the assessment. |
| Layer | Responsibility | Key current locations |
| --- | --- | --- |
| App composition | Construct store, backend and repositories; hydrate and clear account state. | App/Genesyx/Data/App/AppContainer.swift |
| Repositories | Own observable feature state, persistence, pending writes and remote merging. | App/Genesyx/Data/*Repository.swift |
| Pure domain | Own calendar, cycle, tracking, pH, insights, streaks, notification planning and content models. | Sources/GenesyxCore/ |
| Presentation | Render screens, forms, charts, sheets, accessibility and navigation. | App/Genesyx/UI/ |
| Remote adapter | Implement backend protocols using Supabase. | App/Genesyx/Data/Remote/ |
| Server operations | Perform privileged invite, unlink and account deletion operations. | supabase/functions/ |
| Database evolution | Define RLS, tables, constraints and incremental hardening. | supabase/migrations/ |
| Capability | Implemented behaviour | Boundary |
| --- | --- | --- |
| Cycle | Cycle setup, day/phase calculation, fertile-window and ovulation estimates. | Predicted from settings; ovulation is not measured. |
| Daily log | Mood, energy, symptoms, sleep minutes, water, supplements, notes and intimacy. | One record per calendar day; not event-level history. |
| Vaginal pH | Entry, history, two-band status, trend, local/remote sync and legacy urine preservation. | Legacy urine is excluded from vaginal insights. |
| Hydration | Quick add, manual entry, goal progress, seven-day history, streak and display units. | Millilitres remain the storage and calculation unit. |
| Sleep | Duration entry, current-week view, history and weekly average. | Duration alone does not establish sleep quality. |
| Nutrition | Phase-aware guidance, hydration context and supplement completion. | Guidance is not a prescription or deficiency diagnosis. |
| Symptoms | Daily selection and 28-day frequency heatmap. | Timing is descriptive; cause is unknown. |
| Insights | Weekly summary, consistency, pH, hydration, nutrition, sleep, cycle, symptoms and ovulation. | Empty and thin-data states must remain honest. |
| Notifications | Hydration/check-in, pH, insights, Track, Learn, fertile window and supplement reminders. | Local notifications only; frequency and privacy invariants apply. |
| Partner | Invite, share, accept, revoke and unlink. | Partner does not receive health records under current RLS. |
| Step | Customer question | Genesyx response |
| --- | --- | --- |
| Track | What did I record today? | Show saved values, sync status and one clear next action. |
| Understand | What is my data beginning to show? | Present counts, averages, comparisons or repeated timing with evidence. |
| Act | What can I do now? | Offer no more than three specific, safe, in-app actions. |
| Continue | What should I track next? | Explain what additional data would unlock. |
| Review | Has anything changed over time? | Compare valid periods and show contributing dates. |
| Discuss | What should I take to a professional? | Provide an explicit, privacy-controlled factual summary without diagnosis. |
| Field | Purpose | Example |
| --- | --- | --- |
| Headline | Plain-language observation. | Your sleep and energy records overlap |
| Recorded evidence | Facts and denominators. | Sleep: 18 nights; next-day energy: 14 comparable entries. |
| Observation | What appeared in the records. | Longer sleep appeared with normal/high energy on 9 of 14 comparable days. |
| Why shown | Threshold that unlocked the result. | Both fields had at least seven comparable entries. |
| Limitation | What the result cannot establish. | This association does not prove that sleep caused the energy level. |
| Next action | Small useful step. | Continue logging sleep and morning energy for another week. |
| Contributing dates | Audit trail for the customer. | Open the 14 dates used in the result. |
| Destination | Direct action or drill-down. | Open Sleep insight / Log today. |
| State | Meaning | Allowed output |
| --- | --- | --- |
| Unavailable | No usable entries. | Empty state and first action only. |
| Collecting | Some valid entries but below threshold. | Counts and progress toward unlock. |
| Observation ready | Enough to calculate counts or averages. | Factual summary with denominator. |
| Comparison ready | Two periods contain sufficient comparable data. | Week-over-week comparison. |
| Pattern emerging | Repeated timing crosses an approved threshold. | Early pattern plus limitation. |
| Repeated across cycles | Pattern appears in at least two complete cycles. | Cycle-linked observation with early-pattern wording. |
| Signal | Coverage example | Result |
| --- | --- | --- |
| Hydration | 24 of 30 days | Strong routine picture |
| Sleep | 18 of 30 nights | Useful duration picture |
| Supplements | 21 of 30 days | Strong logging picture |
| Symptoms | 8 symptom days | Pattern may be available |
| Vaginal pH | 5 valid readings | Trend may be available |
| Cycle | One configured cycle | Current-cycle context only |
| Result | Proposed minimum | Notes |
| --- | --- | --- |
| First weekly picture | 4 meaningful days in a trailing 7-day window. | Matches the current complete-week concept. |
| Hydration weekly observation | Water on at least 3 days. | Always show exact coverage. |
| Sleep weekly observation | At least 3 logged nights. | Average logged nights only. |
| Supplement weekly observation | At least 3 logged days. | No adherence or prescription claim. |
| Basic pH comparison | At least 2 recent valid vaginal readings. | Existing logic uses two recent readings for an insight. |
| pH trend-ready notice | At least 4 valid readings in 30 days. | Matches current notification readiness. |
| Symptom observation | One or more occurrences. | Counts only; no pattern claim. |
| Symptom pattern | At least 7 symptom days in 28 days. | Matches current thin-data guard. |
| Two-week comparison | Relevant data in both seven-day periods. | Use stronger copy only with 3-4 points per period. |
| Cycle-linked pattern | At least 2 complete cycles. | Three cycles supports stronger repeated-pattern wording. |
| Signal | Example message | Next action |
| --- | --- | --- |
| Hydration | Water logged on 3 days. | Keep going to unlock the seven-day view. |
| Sleep | Sleep recorded for 2 nights. | Record more nights for an average. |
| pH | Your first vaginal pH reading is saved. | A second valid reading begins a comparison. |
| Symptoms | Fatigue was recorded once. | Continue logging if it returns. |
| Supplements | Supplements logged on 2 days. | Set optional reminders or continue tracking. |
| Evidence | Allowed wording | Not allowed |
| --- | --- | --- |
| One cycle | Fatigue was recorded on cycle days 18, 20 and 22. | Fatigue usually occurs in your luteal phase. |
| Two cycles | Across two recorded cycles, fatigue appeared more often during the predicted luteal phase. | This phase caused fatigue. |
| Three cycles | This timing has repeated across three recorded cycles. | Diagnosis, treatment or confirmed ovulation. |
| Tracker card | Today | Recent context | Primary action |
| --- | --- | --- | --- |
| Cycle | Cycle day / setup state | Predicted phase and window | Review or edit cycle |
| pH | Latest valid reading | Reading count and trend readiness | Add reading |
| Nutrition | Supplements logged | Current-week consistency | Log supplements |
| Symptoms | Symptoms today | 28-day coverage | Edit symptoms |
| Sleep | Last sleep duration | Current-week nights and average | Log sleep |
| Hydration | Water and goal progress | Seven-day goal days | Add water |
| Type | Eligibility | Discreet lock-screen copy | Destination |
| --- | --- | --- | --- |
| First week ready | Weekly picture crosses evidence threshold. | Your first weekly picture is ready. | Insights / First week |
| Two-week comparison | Both periods contain valid comparable data. | A comparison is ready. | Insights / Comparison |
| 30-day picture | Thirty-day report contains at least one ready result. | Your 30-day picture is ready. | Insights / 30-day report |
| One entry to unlock | Exactly one valid entry would unlock a useful result. | One more entry can complete your week. | Exact Track editor |
| Pattern ready | Approved pattern threshold crossed and result is new. | A pattern is ready to review. | Exact insight |
| Cycle window | Predicted window opens within scheduling horizon. | A note about your cycle. | Track / Cycle |
| pH cadence | No valid reading or last reading older than approved interval. | A pH check-in is ready. | pH tab |
| Sleep | Customer opted into bedtime or morning reminder. | Your sleep reminder. | Track / Sleep |
| Hydration | Below goal, enabled and no higher-priority message. | A gentle water check-in. | Track / Hydration |
| Supplement | Customer set a time for this supplement. | Your supplement reminder. | Track / Nutrition |
| Proposed file | Responsibility |
| --- | --- |
| GuidanceSnapshot.swift | Immutable inputs assembled from repositories. |
| EvidenceState.swift | Unavailable, collecting, observation-ready, comparison-ready, pattern-emerging and repeated-across-cycles states. |
| GuidanceResult.swift | Normalized result contract, actions, evidence, limitations and routing. |
| GuidanceEngine.swift | Run signal engines, cross-signal engines and prioritization. |
| GuidancePriority.swift | Stable scoring, freshness and deduplication. |
| CycleGuidanceLogic.swift | Cycle estimates and later multi-cycle context. |
| PhGuidanceLogic.swift | Valid vaginal pH evidence and trend readiness. |
| HydrationGuidanceLogic.swift | Seven-, fourteen- and thirty-day hydration summaries. |
| SleepGuidanceLogic.swift | Logged-night summaries and comparisons. |
| SupplementGuidanceLogic.swift | Routine and per-supplement logging summaries. |
| SymptomGuidanceLogic.swift | Counts, thin-data guards and repeated timing. |
| CrossSignalLogic.swift | Approved pairwise comparisons using comparable dates only. |
| Component | Responsibility |
| --- | --- |
| GuidanceRepository | Observe existing repositories, build snapshots, cache reviewed/dismissed state and publish current results. |
| GuidanceDestination | Represent exact tab, report, card, date or editor destination. |
| YourPictureView | Render progress, unlocked reports, building cards and top actions. |
| GuidanceDetailView | Show evidence, contributing dates, limitation and actions. |
| NotificationService extension | Translate eligible guidance results into planned local notifications. |
| Profile controls | Expose categories, quiet hours and privacy preferences. |
| Field | Type intent | Purpose |
| --- | --- | --- |
| id | Stable string | Identity of the insight family. |
| category | Enum | Cycle, pH, hydration, sleep, supplements, symptoms or cross-signal. |
| window | Date range | Exact evidence period. |
| recordedEvidence | Structured metrics | Counts, denominators, averages and dates. |
| observation | Structured result | What appeared in the data. |
| explanation | String/key | Why the result appeared. |
| limitation | Approved copy key | What cannot be concluded. |
| nextActions | Ordered actions | Maximum three in-app actions. |
| contributingDates | CalendarDate array | Audit trail. |
| evidenceState | Enum | Maturity state. |
| sensitivity | Enum | Controls previews and sharing. |
| notificationEligibility | Policy result | Whether and when it may notify. |
| destination | Route | Exact screen/report/editor. |
| dataSignature | Stable hash | Deduplicate unchanged results. |
| generatedAt | Timestamp | Freshness and debugging. |
| Input | Effect |
| --- | --- |
| Evidence readiness | Ready results outrank collecting states. |
| Newness | Newly crossed thresholds outrank unchanged results. |
| Time sensitivity | Cycle event can outrank evergreen guidance. |
| Actionability | Result with a clear in-app action ranks higher. |
| Customer focus | Selected focus can break otherwise equal priorities. |
| Sensitivity | Sensitive result is less eligible for notification. |
| Recent exposure | Recently viewed/notified result is suppressed. |
| Data quality | Higher coverage ranks above weaker coverage. |
| Phase | Scope | Primary deliverable | Gate |
| --- | --- | --- | --- |
| 1. Contract | Metrics, thresholds, approved copy, prohibited claims and destinations. | Insight and notification matrix. | Product + clinical + privacy approval. |
| 2. Evidence engine | Snapshot, evidence states, windows, signatures and prioritization. | Tested GenesyxCore Guidance module. | Pure unit tests pass. |
| 3. Individual signals | Hydration, sleep, supplements, symptoms, pH and cycle. | GuidanceResult outputs. | Golden fixtures approved. |
| 4. Track integration | Progress, unlock and view-insight states. | Updated tracker cards and exact routing. | Repository/UI tests pass. |
| 5. Insights integration | Your picture, Building, comparisons and 30-day report. | New Insights experience. | Accessibility/UI tests pass. |
| 6. Cross-signal | Approved pairwise comparable-date observations. | Explainable cross-signal cards. | Safety and denominator tests pass. |
| 7. Notifications | New candidates, exact destinations, quiet hours, signatures and cancellation. | Expanded planner/service. | Copy, scheduling and device tests pass. |
| 8. Multi-cycle | Historical period events and repeated-cycle patterns. | Two/three-cycle insights. | Data-model and clinical review. |
| 9. Release | Instrumentation-free QA, docs, archive and device verification. | Release candidate. | All technical and human gates complete. |
| Prohibited | Reason |
| --- | --- |
| Inventing entries, averages, charts or patterns | Destroys data honesty. |
| Treating missing data as zero | Creates false comparisons. |
| Causal language from observational records | The app cannot establish cause. |
| Exposing sensitive detail on the lock screen | Privacy risk. |
| Calling an estimate a measurement | Misrepresents cycle predictions. |
| Using one cycle to claim a recurring pattern | Insufficient longitudinal evidence. |
| Sharing health data with a partner by default | Current privacy model is owner-only. |
| Opaque AI-generated medical conclusions | Not explainable or appropriately validated. |
| Epic | Key tasks | Acceptance outcome |
| --- | --- | --- |
| Guidance contracts | Types, windows, evidence states, copy keys, routes and signatures. | Stable public core API. |
| Coverage calculators | Per-signal valid-date selection and denominators. | No missing-as-zero errors. |
| Signal engines | Cycle, pH, hydration, sleep, supplements and symptoms. | Individual cards match fixtures. |
| Cross-signal engine | Comparable-date intersections and non-causation output. | Every association is auditable. |
| Your picture UI | Progress, unlock, Building, weekly and monthly reports. | Customer sees what is known and missing. |
| Track integration | Next action, insight-ready state and direct routes. | Track is the operational hub. |
| Notification expansion | Candidate generation, priority, privacy, cancellation and routing. | Useful, restrained local notifications. |
| Preferences | Categories, quiet hours, sleep controls and privacy preview. | Customer controls cadence and sensitivity. |
| Multi-cycle model | Period-event history and repeated-cycle evaluation. | No single-cycle “usual” claims. |
| QA and release | Tests, accessibility, device routing, archive and docs. | Release evidence is complete. |