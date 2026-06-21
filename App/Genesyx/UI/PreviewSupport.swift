#if DEBUG
import SwiftUI
import GenesyxCore

// Preview-only scaffolding: a seeded, isolated AppContainer + an environment helper, plus a
// #Preview for every screen so you can iterate the UI in Xcode's canvas without running the app.
// Compiled only in DEBUG; never ships.

extension AppContainer {
    /// An isolated container (its own UserDefaults suite) seeded with realistic sample data.
    @MainActor
    static func previewSeeded(signedIn: Bool = true) -> AppContainer {
        let store = LocalStore(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!)
        let container = AppContainer(store: store, backend: nil)
        container.cycle.upsert(CycleSettings(lastPeriodDate: CalendarDate.today().minusDays(8), cycleLength: 28, periodLength: 5))
        container.dailyLog.setWater(750)
        container.ph.create(PhReading(phValue: 6.3, recordedAt: Date().addingTimeInterval(-5 * 86_400)))
        container.ph.create(PhReading(phValue: 6.7, recordedAt: Date().addingTimeInterval(-2 * 86_400)))
        container.ph.create(PhReading(phValue: 6.9, recordedAt: Date()))
        if signedIn { container.session.signIn(email: "lucas@example.com", name: "Lucas") }
        return container
    }
}

extension View {
    /// Injects a seeded container and all repositories into the environment for previews.
    @MainActor
    func withPreviewEnvironment(_ container: AppContainer = .previewSeeded()) -> some View {
        self
            .environmentObject(container)
            .environmentObject(container.cycle)
            .environmentObject(container.dailyLog)
            .environmentObject(container.ph)
            .environmentObject(container.prefs)
            .environmentObject(container.session)
            .environmentObject(container.partner)
            .tint(GenesyxColor.primary)
    }
}

#Preview("Home") { HomeView().withPreviewEnvironment() }
#Preview("Track") { TrackView().withPreviewEnvironment() }
#Preview("Nutrition") { NutritionView().withPreviewEnvironment() }
#Preview("Insights") { InsightsView().withPreviewEnvironment() }
#Preview("Profile") { ProfileView().withPreviewEnvironment() }
#Preview("Daily Log") { LogView().withPreviewEnvironment() }
#Preview("Auth") { AuthView().withPreviewEnvironment() }
#Preview("Pregnancy") { PregnancyView().withPreviewEnvironment() }
#Preview("Onboarding") { OnboardingFlowView(onFinished: {}).withPreviewEnvironment() }
#Preview("Main Tabs") { MainTabView().withPreviewEnvironment() }
#Preview("Home — Dark") { HomeView().withPreviewEnvironment().preferredColorScheme(.dark) }
#endif
