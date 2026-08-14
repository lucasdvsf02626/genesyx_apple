import Combine
import Foundation
import GenesyxCore
import UserNotifications

/// Executes the plan. It decides *nothing* about what she is told — `NotificationPlanner` reads her
/// data and returns the sentences; this schedules them, cancels them, and routes the taps.
///
/// Nothing is scheduled without all three of: `FeatureFlags.pushNotifications`, her `pushEnabled`
/// preference, and system authorization — reconciled on every foreground, so revoking permission in
/// Settings quietly tears the schedule down. No server: everything fires on-device.
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// Set on a tap; consumed by `MainTabView`.
    @Published var pendingDestination: NotificationRouter.Destination?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// A milestone she has just crossed and not yet been shown *in the app*, consumed by
    /// `MainTabView`. Published from `checkMilestones` rather than recomputed by the UI on
    /// purpose: that method flags each milestone celebrated the moment it handles it, so anything
    /// reading `StreakEngine` a second time would find the list already empty and never show a
    /// thing. One computation, one flag set, and the notification and the in-app moment cannot
    /// disagree about what she achieved.
    @Published var celebration: Milestone?

    private let prefs: PreferencesRepository
    private let dailyLog: DailyLogRepository
    private let ph: PhRepository
    private let cycle: CycleRepository
    private let supplements: SupplementsRepository
    private let store: LocalStore
    private let session: SessionRepository
    private let center: UNUserNotificationCenter
    private var cancellables: Set<AnyCancellable> = []

    private let lastSentKey = "notification_last_sent"
    private let scheduledFireKey = "notification_scheduled_fire"
    private let queuedLearnSlugKey = "notification_queued_learn_slug"
    private let scheduledSupplementIdsKey = "notification_scheduled_supplements"

    init(prefs: PreferencesRepository,
         dailyLog: DailyLogRepository,
         ph: PhRepository,
         cycle: CycleRepository,
         supplements: SupplementsRepository,
         store: LocalStore,
         session: SessionRepository,
         center: UNUserNotificationCenter = .current()) {
        self.prefs = prefs
        self.dailyLog = dailyLog
        self.ph = ph
        self.cycle = cycle
        self.supplements = supplements
        self.store = store
        self.session = session
        self.center = center
        super.init()
        center.delegate = self
        session.onBecameSignedOut = { [weak self] in
            self?.pendingDestination = nil
            self?.cancelAll()
        }

        // `@Published` publishes from `willSet`, so a subscriber that runs synchronously reads the
        // property's OLD value — re-planning off the state she just left. Hopping to the next turn
        // of the run loop lets the write land first. Without it, moving the reminder time schedules
        // the hour she moved away from.
        func onChange(_ publisher: some Publisher<some Any, Never>, _ act: @escaping () -> Void) -> AnyCancellable {
            publisher.dropFirst().receive(on: RunLoop.main).sink { _ in act() }
        }

        // Correcting a period date moves the predicted fertile window, and with it the day the
        // cycle nudge is due — re-plan rather than let a stale date sit in the schedule.
        onChange(cycle.$settings) { [weak self] in self?.replan() }
            .store(in: &cancellables)

        // Logging changes everything the plan is built from: today's hydration nudge becomes
        // unnecessary the moment she logs water, a gap closes, a streak crosses a milestone.
        // Observing the repository means no screen has to remember to tell us.
        onChange(dailyLog.$logByDate) { [weak self] in self?.replanAndCelebrate() }
            .store(in: &cancellables)

        // Moving the reminder time changes when tonight's check-in should fire — re-plan so the
        // scheduled request follows her choice without her having to toggle reminders off and on.
        onChange(prefs.$reminderHour) { [weak self] in self?.replan() }
            .store(in: &cancellables)

        // Switching a category off has to take effect now: a request for it is already queued with
        // the system and would still fire. `replan` cancels the lot and rebuilds without it.
        onChange(prefs.$mutedNotifications) { [weak self] in self?.replan() }
            .store(in: &cancellables)

        // Setting or clearing a supplement's time is a direct instruction about when to speak.
        onChange(prefs.$supplementReminders) { [weak self] in self?.replan() }
            .store(in: &cancellables)

        // The list itself now arrives from the server as well as from this phone. The reminder hour
        // is device-local and keyed by id, so a supplement she deleted on her Android phone would
        // otherwise keep its alarm here — the entry disappears on the pull, and nothing tells the
        // schedule.
        onChange(supplements.$supplements) { [weak self] in self?.replan() }
            .store(in: &cancellables)
    }

    /// What the Profile toggle shows. Reminders are on only when she asked for them AND iOS agreed
    /// — anything else would be the switch claiming to send things the app cannot send. In
    /// particular, `profiles.push_enabled` defaults to true server-side, so a pulled profile must
    /// not be able to flip this on behind a permission she never granted.
    var isOn: Bool { prefs.pushEnabled && authorizationStatus == .authorized }

    /// True when she denied at the system level — Profile offers a link into Settings.
    var isSystemDenied: Bool { authorizationStatus == .denied }

    // MARK: - Master switch (the Profile toggle)

    func setEnabled(_ on: Bool) {
        prefs.pushEnabled = on
        Task {
            if on { await requestAuthorizationIfNeeded() }
            await reconcile()
        }
    }

    /// Re-check permission, re-plan from her current data, re-sync the scheduled set — and
    /// celebrate anything she crossed while the app was closed.
    func reconcile() async {
        await refreshAuthorizationStatus()
        if !isActive { cancelAll() }
        replanAndCelebrate()
    }

    /// The two halves of "her data changed", in the order they have to happen. `replan` begins by
    /// cancelling every pending request, so a milestone scheduled ahead of it would be swept away
    /// by the very call that was meant to follow it.
    private func replanAndCelebrate() {
        replan()
        checkMilestones()
    }

    /// Internal rather than private so a test can pin the definition. All three terms matter and
    /// the third is the one that gets dropped by accident: wanting notifications is not the same as
    /// having been granted them, and the schedule must not move until the system says yes.
    var isActive: Bool {
        FeatureFlags.pushNotifications && prefs.pushEnabled && authorizationStatus == .authorized
            && session.isSignedIn
    }

    // MARK: - Permission

    /// Only ever called from the Profile toggle, after the pre-prompt sheet has explained what
    /// she'll get — never at launch.
    func requestAuthorizationIfNeeded() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorizationStatus()
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    // MARK: - Planning

    private func replan() {
        guard isActive else { return }
        recordWhatHasFired()

        let plan = NotificationPlanner.plan(snapshot())
        cancelAll()
        for planned in plan.weekly { schedule(planned) }
        if let hydration = plan.hydration {
            schedule(hydration, restDays: plan.hydrationRestDays)
        }
        scheduleSupplementReminders()
        dumpScheduleForDebugging()
    }

    #if DEBUG
    /// Prints what is actually queued with the system, so a real run can be checked against what
    /// the planner intended. Debug-only — this is a diagnostic, not a feature.
    private func dumpScheduleForDebugging() {
        Task {
            let pending = await center.pendingNotificationRequests()
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMM HH:mm"
            NSLog("📬 GENESYX SCHEDULE — \(pending.count) queued")
            for request in pending.sorted(by: { $0.identifier < $1.identifier }) {
                let when = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                    .map(formatter.string(from:)) ?? "—"
                NSLog("📬   [\(when)] \(request.identifier)")
                NSLog("📬      \(request.content.title) — \(request.content.body)")
            }
        }
    }
    #else
    private func dumpScheduleForDebugging() {}
    #endif

    /// The whole of what the planner knows about her.
    private func snapshot() -> NotificationSnapshot {
        let today = CalendarDate.today()
        let phDays = ph.readings.map { CalendarDate.today(now: $0.recordedAt) }
        // `sexualActivity` is folded in here and in `lastActivityDay`, but NOT into the engines'
        // `isMeaningfulLog` / `hasAnyEntry`: those two are the cross-platform streak contract and
        // cannot widen until Android does (see `TrackingEngine`). Notifications are iOS-only and
        // mirror nothing, so widening here diverges nothing — and the alternative is nudging her to
        // log on a day she logged. `foodGroups` needed the same treatment until H4 put it in the
        // shared predicates on both clients.
        let log = dailyLog.log(on: today)
        let loggedToday = log.isMeaningfulLog || log.sexualActivity || phDays.contains(today)

        return NotificationSnapshot(
            streak: StreakEngine.compute(
                logsByDate: dailyLog.logByDate,
                phByDate: Set(phDays),
                today: today,
                celebrated: prefs.celebratedMilestones),
            daysSinceLastPh: phDays.max().map { today.dayNumber - $0.dayNumber },
            phReadingsLast30Days: phDays.filter { today.dayNumber - $0.dayNumber <= 30 }.count,
            daysSinceLastLog: lastActivityDay(phDays: phDays).map { today.dayNumber - $0.dayNumber },
            topSymptom: topSymptom(),
            learnCandidates: learnCandidates(),
            daysSinceSent: daysSinceSent(),
            hasMeaningfulLogToday: loggedToday,
            waterTodayMl: dailyLog.waterMl(on: today),
            waterGoalMl: TrackingEngine.defaultWaterGoalMl,
            reminderHour: prefs.reminderHour,
            daysUntilFertileWindow: OvulationLogic.daysUntilFertileWindow(settings: cycle.settings, today: today),
            todayWeekday: Self.isoWeekday(of: Date()),
            mutedCategories: prefs.mutedNotifications
        )
    }

    /// Any activity at all — a log or a pH reading. Drives "she went quiet, so we go quiet", which
    /// is why `sexualActivity` counts here (see `snapshot`).
    private func lastActivityDay(phDays: [CalendarDate]) -> CalendarDate? {
        let logDays = dailyLog.logByDate
            .filter { $0.value.hasAnyEntry || $0.value.sexualActivity }
            .keys
        return (Array(logDays) + phDays).max()
    }

    /// Her most-logged symptom over the last four weeks.
    private func topSymptom() -> (name: String, count: Int)? {
        let today = CalendarDate.today()
        var counts: [String: Int] = [:]
        for (date, log) in dailyLog.logByDate where today.dayNumber - date.dayNumber <= 28 {
            for symptom in log.symptoms { counts[symptom, default: 0] += 1 }
        }
        // Sorted by name on ties so the choice is stable between launches.
        guard let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else { return nil }
        return (name: best.key, count: best.value)
    }

    /// Read fresh rather than from `LearnProgress`: a replan can happen long after launch, and the
    /// nudge must not offer her something she read an hour ago.
    /// `LearnLibrary.articles`, not the raw `learnArticles`: the raw array includes the pieces that
    /// are compiled in but date-withheld, and this was the one Learn surface not going through the
    /// publication gate. Because the "new" pool is exclusive, the nudge picked *only* from unreleased
    /// articles — a push headed "New this week" naming a piece that resolves to "That article isn't
    /// available" — and `markAnnounced` then spent the slug, so no badge appeared on the real drop.
    /// Internal, not private, so a test can reach the production composition. Every other test in
    /// this area builds its own `LearnProgress` from `LearnLibrary.articles` and so was structurally
    /// incapable of catching the one caller that did not.
    func learnCandidates() -> [LearnCandidate] {
        let published = LearnLibrary.articles
        return LearnProgress.candidates(
            published,
            read: LearnReadLog.readSlugs(),
            arrived: LearnLibraryLog.newSlugs(in: published.map(\.slug))
        )
    }

    // MARK: - Scheduling

    private func schedule(_ planned: PlannedNotification, restDays: Set<Int> = []) {
        let fire: Date?
        if planned.slot == .hydration {
            // The check-in is the one nudge that has to respect the mornings the weekly nudges own,
            // so it goes through `nextHydrationFire` rather than a flat day offset. An offset on it
            // means only "not tonight — she has already finished today", which is exactly what
            // `loggedToday` steps over.
            fire = Self.nextHydrationFire(
                now: Date(),
                hour: planned.hour,
                loggedToday: (planned.dayOffset ?? 0) > 0,
                restDays: restDays
            )
        } else if let offset = planned.dayOffset {
            fire = Self.fireDate(daysFromNow: offset, hour: planned.hour, now: Date())
        } else if let weekday = planned.weekday {
            fire = Self.nextOccurrence(isoWeekday: weekday, hour: planned.hour, now: Date())
        } else {
            fire = nil
        }
        guard let fire else { return }

        let kind = NotificationKind(slot: planned.slot)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default
        content.userInfo = NotificationRouter.payload(
            tab: NotificationTab(rawValue: planned.target.rawValue) ?? .home,
            learnSlug: planned.learnSlug
        )

        center.add(UNNotificationRequest(
            identifier: kind.rawValue,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
        rememberScheduledFire(kind, at: fire)
        if let slug = planned.learnSlug { store.setString(slug, forKey: queuedLearnSlugKey) }
    }

    /// A specific day at a specific hour. Returns nil when that moment has already passed — the
    /// window opened earlier today and she is being told about it after the fact, which is worth
    /// nothing: the app itself shows her where she is the moment she opens it.
    nonisolated static func fireDate(daysFromNow: Int, hour: Int, now: Date,
                                     calendar: Calendar = .current) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: daysFromNow, to: now),
              let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
              fire > now else { return nil }
        return fire
    }

    /// The next time this weekday and hour comes round.
    nonisolated static func nextOccurrence(isoWeekday: Int, hour: Int, now: Date,
                                           calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.weekday = (isoWeekday % 7) + 1   // ISO Mon=1…Sun=7 → Calendar Sun=1…Sat=7
        components.hour = hour
        components.minute = 0
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
    }

    /// The next morning she should be nudged about water. She is nudged only on days she hasn't
    /// started — once water is logged, today's nudge moves on — and never on a day a weekly nudge
    /// already lands (invariant 2: one a day).
    nonisolated static func nextHydrationFire(now: Date,
                                              hour: Int,
                                              loggedToday: Bool,
                                              restDays: Set<Int> = [],
                                              calendar: Calendar = .current) -> Date? {
        guard var candidate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) else { return nil }
        if loggedToday || candidate <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = tomorrow
        }
        // Step over any morning a weekly nudge owns. A week can't be fully blocked — the planner
        // never schedules more than four of seven days — so this terminates.
        var guard7 = 0
        while restDays.contains(isoWeekday(of: candidate, calendar: calendar)), guard7 < 7 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = next
            guard7 += 1
        }
        return candidate
    }

    nonisolated static func isoWeekday(of date: Date, calendar: Calendar = .current) -> Int {
        let sundayFirst = calendar.component(.weekday, from: date)   // Sun = 1 … Sat = 7
        return sundayFirst == 1 ? 7 : sundayFirst - 1                // → Mon = 1 … Sun = 7
    }

    func cancelAll() {
        // Supplement reminders repeat, so they are the one thing here that outlives neglect: missing
        // them would leave the master switch off and her phone still going off every morning. Their
        // ids are dynamic, hence remembered rather than enumerated.
        let ids = NotificationKind.allCases.map(\.rawValue)
            + (store.load([String].self, forKey: scheduledSupplementIdsKey) ?? [])
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        store.save([String](), forKey: scheduledSupplementIdsKey)
        // Forget the fire times too. Nothing cancelled here can still go off, so leaving them
        // remembered lets `recordWhatHasFired` promote them to "sent" once the hour passes — and a
        // slot believed to have spoken stays quiet for a fortnight. `replan` calls this *after*
        // recording, so fires that genuinely happened are already banked before we clear.
        store.save([String: Date](), forKey: scheduledFireKey)    }

    // MARK: - What has already fired
    //
    // The planner needs to know how long ago each slot last spoke (so it doesn't nudge twice in a
    // week). We can't observe delivery while the app is closed, so a scheduled fire time that has
    // now passed counts as delivered — which it will have been, barring her turning notifications
    // off in between, and in that case nothing was scheduled anyway.

    private func recordWhatHasFired() {
        var scheduled = dateMap(forKey: scheduledFireKey)
        var sent = dateMap(forKey: lastSentKey)
        let now = Date()

        for (id, fire) in scheduled where fire <= now {
            sent[id] = fire
            scheduled[id] = nil
            // An article stops being "new" the moment she has actually been told about it. Doing
            // this at schedule time instead would let any replan before Sunday — logging a glass of
            // water is enough — quietly demote the drop back to an ordinary weekly read.
            if id == NotificationKind.weeklyLearn.rawValue, let slug = store.string(forKey: queuedLearnSlugKey) {
                LearnLibraryLog.markAnnounced(slug)
            }
        }
        store.save(scheduled, forKey: scheduledFireKey)
        store.save(sent, forKey: lastSentKey)
    }

    private func rememberScheduledFire(_ kind: NotificationKind, at date: Date) {
        var scheduled = dateMap(forKey: scheduledFireKey)
        scheduled[kind.rawValue] = date
        store.save(scheduled, forKey: scheduledFireKey)
    }

    private func daysSinceSent() -> [NotificationSlot: Int] {
        let sent = dateMap(forKey: lastSentKey)
        let now = Date()
        return NotificationSlot.allCases.reduce(into: [:]) { result, slot in
            guard let date = sent[NotificationKind(slot: slot).rawValue] else { return }
            result[slot] = Int(now.timeIntervalSince(date) / 86_400)
        }
    }

    private func dateMap(forKey key: String) -> [String: Date] {
        store.load([String: Date].self, forKey: key) ?? [:]
    }

    // MARK: - Streak milestones

    /// Celebrates each newly-crossed milestone once. `StreakEngine` owns the rule; the flags live in
    /// preferences, and a milestone whose streak has since lapsed is un-flagged so re-achieving it
    /// celebrates again.
    ///
    /// Deliberately *outside* the `isActive` gate that holds back the schedule. A banner reaches her
    /// when the app is closed; the in-app moment reaches her when it isn't, and for everyone who
    /// never granted notification permission — the common case — it is the only half there is.
    /// Both halves are handled here together rather than split in two, because the flag write below
    /// consumes the list: whichever ran first would leave the other with nothing to show.
    private func checkMilestones() {
        let state = StreakEngine.compute(
            logsByDate: dailyLog.logByDate,
            phByDate: Set(ph.readings.map { CalendarDate.today(now: $0.recordedAt) }),
            today: .today(),
            celebrated: prefs.celebratedMilestones
        )

        // Muted or not, they are still flagged as celebrated below: switching milestones back on
        // should not deliver a backlog of every one she passed while they were off. Muting covers
        // the in-app moment too — someone who turned milestones off did not ask for a quieter
        // celebration, she asked for none.
        if !prefs.mutedNotifications.contains(.milestones) {
            // `allCases` order is significance order, so `last` is the biggest thing she did. Only
            // one is shown: crossing day7 and week1 together is one good week, not two modals.
            // Assigned only when there IS one — writing `nil` here would tear a celebration off the
            // screen the moment she logs anything else, which is the moment she is most likely to.
            if let crossed = state.milestones.last { celebration = crossed }

            // The banner half, which unlike the modal above does need permission to exist.
            if isActive {
                for milestone in state.milestones {
                    let content = UNMutableNotificationContent()
                    content.title = NotificationContent.milestoneTitle(milestone)
                    content.body = NotificationContent.milestoneBody(milestone)
                    content.sound = .default
                    content.userInfo = NotificationRouter.payload(tab: .insights)
                    center.add(UNNotificationRequest(
                        identifier: NotificationKind(milestone: milestone).rawValue,
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    ))
                }
            }
        }
        prefs.celebrate(state.milestones.map(\.flagKey))
        prefs.clearCelebrations(state.lapsedCelebrations)
    }

    // MARK: - Supplement reminders

    /// Alarms she set herself, so they are scheduled outside the plan: no weekly budget, no
    /// one-a-day rule, and no going quiet when she does. See `SupplementReminder`.
    ///
    /// These repeat, unlike everything else here. The planned nudges are single-shot because their
    /// content is recomputed from her data each time the app opens; a supplement reminder says the
    /// same thing every day, and one that stopped working because she hadn't opened the app in a
    /// week would be an alarm clock that needs winding.
    private func scheduleSupplementReminders() {
        // `cancelAll` has already torn down the previous set, including any supplement she has since
        // deleted — which is why the ids it cancels are remembered rather than derived from what
        // exists now.
        guard !prefs.mutedNotifications.contains(.supplements) else { return }

        var reminders = SupplementReminder.all(customs: supplements.supplements,
                                               hours: prefs.supplementReminders)
        if FeatureFlags.personalisedSupplementTiming {
            reminders = SupplementPersonalisation.apply(to: reminders, signals: supplementSignals())
        }
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = NotificationRouter.payload(tab: .nutrition)

            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = 0

            center.add(UNNotificationRequest(
                identifier: Self.supplementRequestId(reminder.id),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            ))
        }
        store.save(reminders.map { Self.supplementRequestId($0.id) },
                   forKey: scheduledSupplementIdsKey)
    }

    nonisolated static func supplementRequestId(_ key: String) -> String { "genesyx.supplement.\(key)" }

    /// Everything `SupplementPersonalisation` reads, taken from the repositories this service
    /// already holds. Nothing is collected that wasn't already being stored for another reason.
    private func supplementSignals() -> SupplementSignals {
        SupplementSignals.from(
            logs: dailyLog.logByDate,
            readingDates: ph.readings.map(\.recordedAt),
            quizAnswers: prefs.quizAnswers,
            phase: cycle.settings.map { CycleEngine.cyclePhase(settings: $0).phase }
        )
    }

    // MARK: - Delegate

    /// She's in the app. Show the banner — except the evening check-in on a day she's already
    /// answered: a meaningful log is in AND water has reached goal, so it has nothing left to say.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        return await MainActor.run {
            if identifier == NotificationKind.dailyHydration.rawValue {
                let today = CalendarDate.today()
                let dayComplete = dailyLog.log(on: today).isMeaningfulLog
                    && dailyLog.waterMl(on: today) >= TrackingEngine.defaultWaterGoalMl
                if dayComplete { return [] }
            }
            return [.banner, .sound]
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let destination = NotificationRouter.destination(from: response.notification.request.content.userInfo)
        await MainActor.run { self.pendingDestination = destination }
    }
}
