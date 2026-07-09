import SwiftUI

/// The 5-tab main surface — all tabs translated from the Android build.
struct MainTabView: View {
    @State private var selection: Int = MainTabView.initialSelection

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(0)
                .tabItem { Label("Home", systemImage: "house") }
            TrackView()
                .tag(1)
                .tabItem { Label("Track", systemImage: "calendar") }
            NutritionView()
                .tag(2)
                .tabItem { Label("Nutrition", systemImage: "leaf") }
            InsightsView()
                .tag(3)
                .tabItem { Label("Insights", systemImage: "chart.bar") }
            ProfileView()
                .tag(4)
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(GenesyxColor.primary)
    }

    /// Initial tab for screenshot capture (`-uiTestTab N` launch arg); always Home in Release.
    private static var initialSelection: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "uiTestTab")
        #else
        return 0
        #endif
    }
}
