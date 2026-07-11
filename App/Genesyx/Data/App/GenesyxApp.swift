import SwiftUI

@main
struct GenesyxApp: App {

    @StateObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "uiTestSeed") {
            _container = StateObject(wrappedValue: AppContainer.uiTestSeeded())
            return
        }
        #endif
        _container = StateObject(wrappedValue: AppContainer())
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
                .environmentObject(container.notifications)
                .tint(GenesyxColor.primary)
                .task { await container.notifications.refresh() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task { await container.notifications.refresh() }
                    }
                }
        }
    }
}
