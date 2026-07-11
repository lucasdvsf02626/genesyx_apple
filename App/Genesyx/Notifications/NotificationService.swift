// NotificationService.swift
// WS2 §4 — permission flow, scheduling, cancel, reconcile, and the smart daily
// hydration suppression. Everything is LOCAL (UNUserNotificationCenter) — no APNs.
//
// Invariants enforced here (§8):
//  - guard FeatureFlags.pushNotifications on every entry point
//  - never more than one hydration nudge per day; suppressed once water is logged
//  - milestones fire once; flags persist; lapsed flags cleared so re-achieving re-fires
//  - no prompt at launch — permission only via the Profile toggle's pre-prompt
//
// Wiring note: the handoff's stand-alone NotificationRouter assumed a singleton
// TabRouter with `.select`/`.openLearnArticle`. This app's TabRouter is a plain
// `@Published var selection: Int`, so taps are bridged through `pendingTab` /
// `pendingLearnSlug`, which `MainTabView` observes and applies to its router.

import Foundation
import UserNotifications
import GenesyxCore

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    // Injected via AppContainer (no singletons — matches the app's DI idiom).
    private let prefs: PreferencesRepository
    private let dailyLog: DailyLogRepository
    private let ph: PhRepository
    private let cycle: CycleRepository
    private let learnSlugs: () -> [String]
    private let center = UNUserNotificationCenter.current()

    /// Set on a notification tap; consumed and cleared by `MainTabView`.
    @Published var pendingTab: Int?
    @Published var pendingLearnSlug: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init(
        prefs: PreferencesRepository,
        dailyLog: DailyLogRepository,
        ph: PhRepository,
        cycle: CycleRepository,
        learnSlugs: @escaping () -> [String] = { LearnLibrary.articles.map(\.slug) }
    ) {
        self.prefs = prefs
        self.dailyLog = dailyLog
        self.ph = ph
        self.cycle = cycle
        self.learnSlugs = learnSlugs
        super.init()
        center.delegate = self
    }

    /// True when the user must be sent to Settings (system-denied).
    var isSystemDenied: Bool { authorizationStatus == .denied }

    // MARK: - Permission (review-critical flow, §4)

    /// Called ONLY from the Profile pre-prompt's "Turn on" button — never at launch.
    func requestPermission() async -> Bool {
        guard FeatureFlags.pushNotifications else { return false }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        prefs.pushEnabled = granted
        if granted { await refresh() }
        return granted
    }

    /// Profile master switch. On → request permission then schedule. Off → cancel all.
    func setEnabled(_ on: Bool) {
        prefs.pushEnabled = on
        Task {
            if on {
                _ = await requestPermission()
            } else {
                prefs.pushEnabled = false
                await cancelAll()
            }
        }
    }

    // MARK: - Reconcile + schedule (call on every app foreground)

    /// Reconciles system permission vs the pushEnabled preference, refreshes dynamic
    /// copy (phase, Learn rotation), applies hydration suppression, and fires any
    /// newly crossed streak milestones.
    func refresh(
        today: CalendarDate = .today(),
        isoWeek: Int = Calendar(identifier: .iso8601).component(.weekOfYear, from: Date())
    ) async {
        guard FeatureFlags.pushNotifications else { return }
        await refreshAuthorizationStatus()

        let authorized = authorizationStatus == .authorized || authorizationStatus == .provisional
        guard authorized, prefs.pushEnabled else {
            await cancelAll()
            return
        }

        await scheduleRepeating(today: today, isoWeek: isoWeek)
        await fireMilestonesIfCrossed(today: today)
    }

    /// Call after a successful daily-log save so a just-crossed milestone celebrates
    /// and the hydration nudge is suppressed for the rest of today.
    func onDailyLogSaved() {
        Task { await refresh() }
    }

    func cancelAll() async {
        center.removePendingNotificationRequests(withIdentifiers: NotificationID.all)
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    // MARK: - Repeating set

    private func scheduleRepeating(today: CalendarDate, isoWeek: Int) async {
        var specs: [NotificationSpec] = [
            NotificationContent.weeklyPh,
            NotificationContent.weeklyPhase(phaseName: currentPhaseName()),
            NotificationContent.weeklyNutrition,
            NotificationContent.weeklyLearn(articleSlugs: learnSlugs(), isoWeek: isoWeek),
        ]

        // Smart hydration nudge: schedule the repeating 10:00 trigger only while
        // today's water is still zero. Once she logs water, the pending request is
        // removed for the rest of the day; tomorrow's refresh re-adds it.
        if dailyLog.waterMl(on: today) == 0 {
            specs.append(NotificationContent.dailyHydration)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [NotificationID.dailyHydration])
        }

        // Replace-in-place keeps dynamic copy fresh without duplicating requests.
        center.removePendingNotificationRequests(withIdentifiers: specs.map(\.id))
        for spec in specs {
            guard let schedule = spec.schedule else { continue }
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default
            content.userInfo = spec.route.userInfo
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: spec.id, content: content, trigger: trigger))
        }
    }

    // MARK: - Milestones (read from StreakEngine, fire once)

    private func fireMilestonesIfCrossed(today: CalendarDate) async {
        let state = StreakEngine.compute(
            logsByDate: dailyLog.logByDate,
            phByDate: phReadingDates(),
            today: today,
            celebrated: prefs.celebratedMilestones
        )

        // Clear lapsed flags so a re-achieved streak celebrates again (§3).
        for key in state.lapsedCelebrations {
            prefs.celebratedMilestones.remove(key)
        }

        for milestone in state.milestones {
            let spec = NotificationContent.milestone(milestone)
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default
            content.userInfo = spec.route.userInfo
            // Small delay so a save that crossed the threshold isn't interrupted.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: spec.id, content: content, trigger: trigger))
            prefs.celebratedMilestones.insert(milestone.flagKey)
        }
    }

    // MARK: - Helpers

    private func currentPhaseName() -> String? {
        guard let settings = cycle.settings else { return nil }
        return CycleEngine.cyclePhase(settings: settings).phase.rawValue
    }

    private func phReadingDates() -> Set<CalendarDate> {
        Set(ph.readings.map { CalendarDate.today(now: $0.recordedAt) })
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Foreground suppression: if the hydration nudge fires while the app is open
    /// and water is already logged, show nothing. All other nudges present normally.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.identifier
        if id == NotificationID.dailyHydration {
            Task { @MainActor in
                let logged = self.dailyLog.waterMl(on: .today()) > 0
                completionHandler(logged ? [] : [.banner, .sound])
            }
            return
        }
        completionHandler([.banner, .sound])
    }

    /// Tap → publish the intent for `MainTabView` to route.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            if let route = NotificationRoute.from(userInfo: userInfo) {
                self.pendingTab = route.tabIndex
                if case .learn(let slug) = route { self.pendingLearnSlug = slug }
            }
            completionHandler()
        }
    }
}
