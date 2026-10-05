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
                .withAppEnvironment(container)
                .environmentObject(notifications)
                .tint(GenesyxColor.primary)
                .task { await notifications.reconcile() }
                .task { await container.checkMinimumVersion() }
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

extension View {
    /// Puts the container and every repository on it into the environment.
    ///
    /// Applied at the app root *and* at the root of each presented sheet. A sheet normally
    /// inherits the presenter's environment, but the "Designed for iPad" Mac variant builds the
    /// presented `PresentationHostingController` before that inheritance runs, so modal content
    /// starts with an empty object container and the first `@EnvironmentObject` read traps. Build
    /// 29 crashed exactly that way in `LogView.foodGroupsSection`, the first line of that view to
    /// touch the environment. Re-injecting is a no-op wherever inheritance already works.
    ///
    /// Takes `AppContainer` rather than a bespoke holder so the list below cannot drift from the
    /// repositories the container actually owns. `NotificationService` and `TabRouter` are not on
    /// the container and are injected separately by whoever owns them.
    func withAppEnvironment(_ container: AppContainer) -> some View {
        self
            .environmentObject(container)
            .environmentObject(container.cycle)
            .environmentObject(container.dailyLog)
            .environmentObject(container.ph)
            .environmentObject(container.lh)
            .environmentObject(container.prefs)
            .environmentObject(container.session)
            .environmentObject(container.partner)
            .environmentObject(container.consent)
            .environmentObject(container.learn)
            .environmentObject(container.reachability)
            .environmentObject(container.supplements)
    }
}
