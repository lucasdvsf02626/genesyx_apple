import Foundation
import UserNotifications
import GenesyxCore

/// Owns all local-notification behaviour: permission, four weekly nudges, and streak milestones.
/// Publishes tap intents (`pendingTab` / `pendingLearnSlug`) that `MainTabView` bridges to the
/// `TabRouter`. Everything is gated behind `FeatureFlags.pushNotifications` and the user's
/// `pushEnabled` preference; nothing is scheduled without both plus system authorization.
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// Set on a notification tap; consumed by `MainTabView`.
    @Published var pendingTab: Int?
    @Published var pendingLearnSlug: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let prefs: PreferencesRepository
    private let dailyLog: DailyLogRepository
    private let cycle: CycleRepository
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private let milestone7Key = "genesyx.milestone_7_sent"
    private let milestone14Key = "genesyx.milestone_14_sent"

    init(prefs: PreferencesRepository, dailyLog: DailyLogRepository, cycle: CycleRepository) {
        self.prefs = prefs
        self.dailyLog = dailyLog
        self.cycle = cycle
        super.init()
        center.delegate = self
    }

    // MARK: - Master switch (called from Profile toggle)

    /// Turn the whole system on/off. On → request permission then schedule. Off → cancel all.
    func setEnabled(_ on: Bool) {
        prefs.pushEnabled = on
        Task {
            if on {
                await requestAuthorizationIfNeeded()
                await reconcile()
            } else {
                cancelAll()
            }
        }
    }

    /// Re-check permission and re-sync the scheduled set with `pushEnabled`. Call on foreground.
    func reconcile() async {
        await refreshAuthorizationStatus()
        guard FeatureFlags.pushNotifications, prefs.pushEnabled, authorizationStatus == .authorized else {
            cancelAll()
            return
        }
        scheduleWeeklyNotifications()
        checkStreakMilestones()
    }

    // MARK: - Permission

    func requestAuthorizationIfNeeded() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorizationStatus()
    }

    private func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// True when the user denied at the system level — Profile shows a "open Settings" hint.
    var isSystemDenied: Bool { authorizationStatus == .denied }

    // MARK: - Weekly scheduling

    func scheduleWeeklyNotifications() {
        guard FeatureFlags.pushNotifications, prefs.pushEnabled else { return }
        let requests = Self.weeklyRequests(
            phaseLabel: currentPhaseLabel(),
            learnArticle: NotificationContent.rotatingLearnArticle(isoWeek: Self.currentISOWeek())
        )
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
        for request in requests { center.add(request) }
    }

    func cancelAll() {
        let ids = NotificationKind.allCases.map(\.rawValue)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Pure builder for the four weekly requests — unit-testable without the live center.
    static func weeklyRequests(phaseLabel: String?, learnArticle: LearnArticle) -> [UNNotificationRequest] {
        [
            weekly(.weeklyPh, title: NotificationContent.phTitle, body: NotificationContent.phBody,
                   weekday: NotificationContent.phWeekday, hour: NotificationContent.phHour,
                   tab: .track),
            weekly(.weeklyPhase, title: NotificationContent.phaseTitle,
                   body: NotificationContent.phaseBody(phaseLabel: phaseLabel),
                   weekday: NotificationContent.phaseWeekday, hour: NotificationContent.phaseHour,
                   tab: .track),
            weekly(.weeklyNutrition, title: NotificationContent.nutritionTitle, body: NotificationContent.nutritionBody,
                   weekday: NotificationContent.nutritionWeekday, hour: NotificationContent.nutritionHour,
                   tab: .nutrition),
            weekly(.weeklyLearn, title: NotificationContent.learnTitle,
                   body: NotificationContent.learnBody(article: learnArticle),
                   weekday: NotificationContent.learnWeekday, hour: NotificationContent.learnHour,
                   tab: .learn, slug: learnArticle.slug),
        ]
    }

    private static func weekly(_ kind: NotificationKind, title: String, body: String,
                               weekday: Int, hour: Int, tab: NotificationTab, slug: String? = nil) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var info: [String: Any] = ["tab": tab.rawValue]
        if let slug { info["slug"] = slug }
        content.userInfo = info

        var date = DateComponents()
        date.weekday = weekday
        date.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        return UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger)
    }

    // MARK: - Streak milestones

    /// Pure decision so the flag logic is unit-testable. Fires once per milestone; resets the
    /// flag when the streak drops below the threshold so a later re-achievement fires again.
    struct MilestoneDecision: Equatable {
        var fire7: Bool, fire14: Bool, sent7: Bool, sent14: Bool
    }

    static func milestoneDecision(streak: Int, sent7: Bool, sent14: Bool) -> MilestoneDecision {
        var s7 = sent7, s14 = sent14
        if streak < 7 { s7 = false }
        if streak < 14 { s14 = false }
        let fire7 = streak >= 7 && !s7
        let fire14 = streak >= 14 && !s14
        if fire7 { s7 = true }
        if fire14 { s14 = true }
        return MilestoneDecision(fire7: fire7, fire14: fire14, sent7: s7, sent14: s14)
    }

    /// Call on launch and after every successful daily-log save.
    func checkStreakMilestones() {
        guard FeatureFlags.pushNotifications, prefs.pushEnabled, authorizationStatus == .authorized else { return }
        let decision = Self.milestoneDecision(
            streak: dailyLog.streak(),
            sent7: defaults.bool(forKey: milestone7Key),
            sent14: defaults.bool(forKey: milestone14Key)
        )
        defaults.set(decision.sent7, forKey: milestone7Key)
        defaults.set(decision.sent14, forKey: milestone14Key)
        if decision.fire7 {
            fireImmediate(.milestone7, title: NotificationContent.milestone7Title, body: NotificationContent.milestone7Body)
        }
        if decision.fire14 {
            fireImmediate(.milestone14, title: NotificationContent.milestone14Title, body: NotificationContent.milestone14Body)
        }
    }

    private func fireImmediate(_ kind: NotificationKind, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["tab": NotificationTab.insights.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger))
    }

    // MARK: - Helpers

    private func currentPhaseLabel() -> String? {
        guard let settings = cycle.settings else { return nil }
        let phase = CycleEngine.cyclePhase(settings: settings).phase
        return CycleContent.phaseLabel[phase]
    }

    private static func currentISOWeek() -> Int {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal.component(.weekOfYear, from: Date())
    }

    // MARK: - Delegate (foreground presentation + taps)

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let tab = info["tab"] as? Int
        let slug = info["slug"] as? String
        await MainActor.run {
            self.pendingTab = tab
            if let slug { self.pendingLearnSlug = slug }
        }
    }
}
