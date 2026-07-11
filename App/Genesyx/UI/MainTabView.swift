import SwiftUI

/// The 6-tab main surface (Home, Track, Nutrition, Insights, Learn, Profile).
///
/// iOS's native `TabView` only shows five tabs before collapsing the rest into a "More" list,
/// which would bury Learn and Profile. Android shows all six, so we use a custom bottom bar to
/// match: every tab stays visible, and each screen is kept alive (state preserved) via a ZStack.
struct MainTabView: View {
    @StateObject private var router = TabRouter(selection: MainTabView.initialSelection)
    @EnvironmentObject private var notifications: NotificationService

    private static let items: [(title: String, icon: String)] = [
        ("Home", "house"),
        ("Track", "calendar"),
        ("Nutrition", "leaf"),
        ("Insights", "chart.bar"),
        ("Learn", "book"),
        ("Profile", "person"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tabContent(0, HomeView())
                tabContent(1, TrackView())
                tabContent(2, NutritionView())
                tabContent(3, InsightsView())
                tabContent(4, LearnLandingView())
                tabContent(5, ProfileView())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .environmentObject(router)
        // A notification tap lands on its tab — and, for the Learn nudge, on the article itself.
        .onChange(of: notifications.pendingDestination) { destination in
            guard let destination else { return }
            router.selection = destination.tab.rawValue
            router.pendingLearnSlug = destination.learnSlug
            notifications.pendingDestination = nil
        }
    }

    /// Keeps every tab's view alive so state (scroll position, in-tab nav) survives switching,
    /// showing only the selected one and routing touches only to it.
    private func tabContent<Content: View>(_ index: Int, _ content: Content) -> some View {
        let active = router.selection == index
        return content
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                tabButton(index, item)
            }
        }
        .padding(.top, 8)
        .background(
            GenesyxColor.card
                .overlay(Rectangle().fill(GenesyxColor.border).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ index: Int, _ item: (title: String, icon: String)) -> some View {
        let selected = router.selection == index
        return Button {
            router.selection = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon).font(.system(size: 20))
                Text(item.title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? GenesyxColor.primary : GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.title)
        .accessibilityLabel(item.title)
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
