import SwiftUI

@main
struct GenesyxApp: App {

    @StateObject private var container: AppContainer
    @StateObject private var notifications: NotificationService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let resolved: AppContainer
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "uiTestSeed") {
            resolved = AppContainer.uiTestSeeded()
        } else {
            resolved = AppContainer()
        }
        #else
        resolved = AppContainer()
        #endif
        _container = StateObject(wrappedValue: resolved)
        let resolvedNotifications = NotificationService(
            prefs: resolved.prefs, dailyLog: resolved.dailyLog, ph: resolved.ph,
            cycle: resolved.cycle, supplements: resolved.supplements, store: resolved.store,
            session: resolved.session)
        #if DEBUG
        // `-uiTestPendingNotification <tab>` reproduces a notification tapped while the app was
        // not running. It goes through the same `payload` → `destination` decode the real
        // `didReceive` handler uses, so a test asserts against a genuinely held destination
        // rather than an app that simply has nothing pending. XCUITest cannot deliver a system
        // notification to a cold-launched app, and the gate's job is what happens to the
        // destination afterwards, not how it arrived.
        if let raw = UserDefaults.standard.string(forKey: "uiTestPendingNotification"),
           let value = Int(raw), let tab = NotificationTab(rawValue: value) {
            resolvedNotifications.pendingDestination =
                NotificationRouter.destination(from: NotificationRouter.payload(tab: tab))
        }
        #endif
        _notifications = StateObject(wrappedValue: resolvedNotifications)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.cycle)
                .environmentObject(container.dailyLog)
                .environmentObject(container.ph)
                .environmentObject(container.prefs)
                .environmentObject(container.session)
                .environmentObject(container.partner)
                .environmentObject(container.consent)
                .environmentObject(container.learn)
                .environmentObject(container.reachability)
                .environmentObject(container.supplements)
                .environmentObject(notifications)
                .tint(GenesyxColor.primary)
                .task { await notifications.reconcile() }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    // Owed writes only move under a valid session. The notification schedule is
                    // re-synced either way so a sign-out tears it down even if she never
                    // foregrounds the Profile toggle.
                    Task {
                        if container.session.isSignedIn {
                            await container.drainPending()
                        }
                        await notifications.reconcile()
                    }
                }
        }
    }
}
