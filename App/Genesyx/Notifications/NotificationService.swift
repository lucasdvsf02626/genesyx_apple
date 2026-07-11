import Combine
import Foundation
import GenesyxCore
import UserNotifications

/// Every local notification the app sends. Nothing is scheduled without all three of:
/// `FeatureFlags.pushNotifications`, her `pushEnabled` preference, and system authorization —
/// and the three are reconciled on every foreground, so revoking permission in Settings quietly
/// tears the schedule down.
///
/// There is no server here: `UNUserNotificationCenter` fires everything on-device.
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// Set on a tap; consumed by `MainTabView`.
    @Published var pendingDestination: NotificationRouter.Destination?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let prefs: PreferencesRepository
    private let dailyLog: DailyLogRepository
    private let cycle: CycleRepository
    private let ph: PhRepository
    private let center: UNUserNotificationCenter
    private var cancellables: Set<AnyCancellable> = []

    init(prefs: PreferencesRepository,
         dailyLog: DailyLogRepository,
         cycle: CycleRepository,
         ph: PhRepository,
         center: UNUserNotificationCenter = .current()) {
        self.prefs = prefs
        self.dailyLog = dailyLog
        self.cycle = cycle
        self.ph = ph
        self.center = center
        super.init()
        center.delegate = self

        // Logging changes both of the things we schedule from: today's hydration nudge becomes
        // unnecessary the moment she logs water, and a log can cross a streak milestone. Observing
        // the repository means no screen has to remember to tell us.
        dailyLog.$logByDate
            .dropFirst()
            .sink { [weak self] _ in self?.onLogChanged() }
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

    /// Re-check permission and re-sync the scheduled set with her preference. Call on foreground.
    func reconcile() async {
        await refreshAuthorizationStatus()
        guard isActive else {
            cancelAll()
            return
        }
        scheduleWeekly()
        scheduleHydrationNudge()
        fireDueMilestones()
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

    // MARK: - Daily hydration nudge

    /// When the next hydration nudge should fire. She is nudged only on days she hasn't started:
    /// once water is logged, today's nudge moves to tomorrow. Never more than one a day, and no
    /// evening follow-up — a missed day costs nothing.
    nonisolated static func nextHydrationFire(now: Date,
                                             hour: Int,
                                             loggedToday: Bool,
                                             calendar: Calendar = .current) -> Date? {
        guard let todayAtHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) else { return nil }
        if !loggedToday && todayAtHour > now { return todayAtHour }
        return calendar.date(byAdding: .day, value: 1, to: todayAtHour)
    }

    /// A one-shot request (not a repeating trigger) so it can be re-evaluated against today's
    /// hydration every time she logs or foregrounds the app.
    private func scheduleHydrationNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationKind.dailyHydration.rawValue])
        guard isActive else { return }
        guard let fire = Self.nextHydrationFire(
            now: Date(),
            hour: NotificationContent.hydrationHour,
            loggedToday: dailyLog.waterMl(on: .today()) > 0
        ) else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        center.add(request(
            .dailyHydration,
            title: NotificationContent.hydrationTitle,
            body: NotificationContent.hydrationBody,
            tab: .nutrition,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    // MARK: - Weekly nudges

    private func scheduleWeekly() {
        guard isActive else { return }
        let requests = weeklyRequests()
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
        for request in requests { center.add(request) }
    }

    private func weeklyRequests() -> [UNNotificationRequest] {
        let article = NotificationContent.rotatingLearnArticle(isoWeek: Self.currentISOWeek())
        return [
            weekly(.weeklyPh, title: NotificationContent.phTitle, body: NotificationContent.phBody,
                   weekday: NotificationContent.phWeekday, hour: NotificationContent.phHour, tab: .track),
            weekly(.weeklyPhase, title: NotificationContent.phaseTitle,
                   body: NotificationContent.phaseBody(phaseLabel: currentPhaseLabel()),
                   weekday: NotificationContent.phaseWeekday, hour: NotificationContent.phaseHour, tab: .track),
            weekly(.weeklyNutrition, title: NotificationContent.nutritionTitle, body: NotificationContent.nutritionBody,
                   weekday: NotificationContent.nutritionWeekday, hour: NotificationContent.nutritionHour, tab: .nutrition),
            weekly(.weeklyLearn, title: NotificationContent.learnTitle,
                   body: NotificationContent.learnBody(article: article),
                   weekday: NotificationContent.learnWeekday, hour: NotificationContent.learnHour,
                   tab: .learn, learnSlug: article.slug),
        ]
    }

    private func weekly(_ kind: NotificationKind, title: String, body: String,
                        weekday: Int, hour: Int, tab: NotificationTab,
                        learnSlug: String? = nil) -> UNNotificationRequest {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        return request(kind, title: title, body: body, tab: tab, learnSlug: learnSlug,
                       trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
    }

    // MARK: - Streak milestones

    /// Fires each newly-crossed milestone once. `StreakEngine` owns the rule; the flags live in
    /// preferences, and a milestone whose streak has since lapsed is un-flagged so re-achieving it
    /// celebrates again.
    private func fireDueMilestones() {
        guard isActive else { return }
        let state = streakState()
        for milestone in state.milestones {
            center.add(request(
                NotificationKind(milestone: milestone),
                title: NotificationContent.milestoneTitle(milestone),
                body: NotificationContent.milestoneBody(milestone),
                tab: .insights,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            ))
        }
        prefs.celebrate(state.milestones.map(\.flagKey))
        prefs.clearCelebrations(state.lapsedCelebrations)
    }

    private func streakState() -> StreakState {
        StreakEngine.compute(
            logsByDate: dailyLog.logByDate,
            phByDate: Set(ph.readings.map { CalendarDate.today(now: $0.recordedAt) }),
            today: .today(),
            celebrated: prefs.celebratedMilestones
        )
    }

    private func onLogChanged() {
        guard isActive else { return }
        scheduleHydrationNudge()
        fireDueMilestones()
    }

    // MARK: - Building + cancelling

    private func request(_ kind: NotificationKind, title: String, body: String,
                         tab: NotificationTab, learnSlug: String? = nil,
                         trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = NotificationRouter.payload(tab: tab, learnSlug: learnSlug)
        return UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger)
    }

    func cancelAll() {
        let ids = NotificationKind.allCases.map(\.rawValue)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Helpers

    private func currentPhaseLabel() -> String? {
        guard let settings = cycle.settings else { return nil }
        return CycleContent.phaseLabel[CycleEngine.cyclePhase(settings: settings).phase]
    }

    private static func currentISOWeek() -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.component(.weekOfYear, from: Date())
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
