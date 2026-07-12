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
        _notifications = StateObject(wrappedValue: NotificationService(
            prefs: resolved.prefs, dailyLog: resolved.dailyLog, ph: resolved.ph, store: resolved.store))
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
                .environmentObject(notifications)
                .tint(GenesyxColor.primary)
                .task { await notifications.reconcile() }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    // Anything a failed push left owed to the server goes up now — the point at
                    // which the network is most likely back. And the notification schedule is
                    // re-synced against her permission state, which may have changed in Settings.
                    Task {
                        await container.drainPending()
                        await notifications.reconcile()
                    }
                }
        }
    }
}
