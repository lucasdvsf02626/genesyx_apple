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
                .tint(GenesyxColor.primary)
                // Anything a failed push left owed to the server goes up when we're foregrounded —
                // the point at which the network is most likely back.
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task { await container.drainPending() }
                }
        }
    }
}
