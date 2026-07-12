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

    private let prefs: PreferencesRepository
    private let dailyLog: DailyLogRepository
    private let ph: PhRepository
    private let store: LocalStore
    private let center: UNUserNotificationCenter
    private var cancellables: Set<AnyCancellable> = []

    private let lastSentKey = "notification_last_sent"
    private let scheduledFireKey = "notification_scheduled_fire"

    init(prefs: PreferencesRepository,
         dailyLog: DailyLogRepository,
         ph: PhRepository,
         store: LocalStore,
         center: UNUserNotificationCenter = .current()) {
        self.prefs = prefs
        self.dailyLog = dailyLog
        self.ph = ph
        self.store = store
        self.center = center
        super.init()
        center.delegate = self

        // Logging changes everything the plan is built from: today's hydration nudge becomes
        // unnecessary the moment she logs water, a gap closes, a streak crosses a milestone.
        // Observing the repository means no screen has to remember to tell us.
        dailyLog.$logByDate
            .dropFirst()
            .sink { [weak self] _ in self?.replan() }
            .store(in: &cancellables)
    }

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

    /// Re-check permission, re-plan from her current data, re-sync the scheduled set.
    func reconcile() async {
        await refreshAuthorizationStatus()
        guard isActive else {
            cancelAll()
            return
        }
        replan()
    }

    private var isActive: Bool {
        FeatureFlags.pushNotifications && prefs.pushEnabled && authorizationStatus == .authorized
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
        fireDueMilestones()
    }

    /// The whole of what the planner knows about her.
    private func snapshot() -> NotificationSnapshot {
        let today = CalendarDate.today()
        let phDays = ph.readings.map { CalendarDate.today(now: $0.recordedAt) }

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
            daysSinceSent: daysSinceSent()
        )
    }

    /// Any activity at all — a log or a pH reading.
    private func lastActivityDay(phDays: [CalendarDate]) -> CalendarDate? {
        let logDays = dailyLog.logByDate.filter { $0.value.hasAnyEntry }.keys
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

    private func learnCandidates() -> [LearnCandidate] {
        let read = LearnReadLog.readSlugs
        return learnArticles.map { article in
            LearnCandidate(
                slug: article.slug,
                title: article.title,
                readingTime: article.readingTime,
                tags: article.tags.map { $0.lowercased() },
                read: read.contains(article.slug)
            )
        }
    }

    // MARK: - Scheduling

    private func schedule(_ planned: PlannedNotification, restDays: Set<Int> = []) {
        let fire: Date?
        if let weekday = planned.weekday {
            fire = Self.nextOccurrence(isoWeekday: weekday, hour: planned.hour, now: Date())
        } else {
            fire = Self.nextHydrationFire(
                now: Date(),
                hour: planned.hour,
                loggedToday: dailyLog.waterMl(on: .today()) > 0,
                restDays: restDays
            )
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
        let ids = NotificationKind.allCases.map(\.rawValue)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

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

    /// Fires each newly-crossed milestone once. `StreakEngine` owns the rule; the flags live in
    /// preferences, and a milestone whose streak has since lapsed is un-flagged so re-achieving it
    /// celebrates again.
    private func fireDueMilestones() {
        let state = StreakEngine.compute(
            logsByDate: dailyLog.logByDate,
            phByDate: Set(ph.readings.map { CalendarDate.today(now: $0.recordedAt) }),
            today: .today(),
            celebrated: prefs.celebratedMilestones
        )

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
        prefs.celebrate(state.milestones.map(\.flagKey))
        prefs.clearCelebrations(state.lapsedCelebrations)
    }

    // MARK: - Delegate

    /// She's in the app. Show the banner — except a hydration nudge she has already answered by
    /// logging water since it was scheduled.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        return await MainActor.run {
            if identifier == NotificationKind.dailyHydration.rawValue, dailyLog.waterMl(on: .today()) > 0 {
                return []
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
