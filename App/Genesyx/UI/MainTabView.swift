import SwiftUI

/// The 5-tab main surface — all tabs translated from the Android build.
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            TrackView()
                .tabItem { Label("Track", systemImage: "calendar") }
            NutritionView()
                .tabItem { Label("Nutrition", systemImage: "leaf") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(GenesyxColor.primary)
    }
}
