import GenesyxCore
import SwiftUI

/// The 7-tab main surface (Home, Track, pH, Nutrition, Insights, Learn, then Profile or More).
///
/// iOS's native `TabView` only shows five tabs before collapsing the rest into a "More" list,
/// which would bury Learn and Profile. Android shows all of them, so we use a custom bottom bar to
/// match: every tab stays visible, and each screen is kept alive (state preserved) via a ZStack.
/// Seven fit because the narrowest device this app supports is 375pt wide (iOS 16 drops the 320pt
/// SE 1), leaving ~53pt a tab against a ~48pt widest label. An eighth does not fit, so anything
/// further goes behind the seventh: it is Profile while Profile is all there is to show, and
/// More (a list of Profile and the rest) once there is something else. Today that something is
/// Scan Test, only while `FeatureFlags.scanTest` is on and `ScanServices.current` exists (DEBUG).
struct MainTabView: View {
    @StateObject private var router = TabRouter(selection: MainTabView.initialSelection)
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var learn: LearnProgress

    private static let learnTab = 5
    private static let profileTab = 6

    /// The one place the Scan Test flag decides what is on screen. Nil, the seventh tab is Profile;
    /// set, it is More, and the tab item and the tab content both hang off this optional.
    private let scanServices: ScanServices? = FeatureFlags.scanTest ? ScanServices.current : nil
    /// What More has pushed. Held here because index 6 still means Profile to whatever selects it.
    @State private var morePath = MainTabView.initialMorePath

    private static let baseItems: [(title: String, icon: String)] = [
        ("Home", "house"),
        ("Track", "calendar"),
        ("pH", "drop"),
        ("Nutrition", "leaf"),
        ("Insights", "chart.bar"),
        ("Learn", "book"),
        ("Profile", "person"),
    ]

    /// More takes Profile's place and nothing is appended, so no tab index moves.
    static func items(moreEnabled: Bool) -> [(title: String, icon: String)] {
        moreEnabled ? Array(baseItems.dropLast()) + [("More", "ellipsis.circle")] : baseItems
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tabContent(0, HomeView())
                tabContent(1, TrackView())
                tabContent(2, PhTabView())
                tabContent(3, NutritionView())
                tabContent(4, InsightsView())
                tabContent(5, LearnLandingView())
                if let scanServices {
                    tabContent(Self.profileTab, MoreView(scanServices: scanServices, path: $morePath))
                } else {
                    tabContent(Self.profileTab, ProfileView())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .environmentObject(router)
        // Above the tab bar rather than inside a tab: she crosses a milestone by logging, and
        // logging happens on Home, Track, pH and Nutrition. A celebration that only appeared on
        // Insights would mostly be shown to nobody.
        .overlay {
            if let milestone = notifications.celebration {
                MilestoneCelebrationView(milestone: milestone) {
                    notifications.celebration = nil
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: notifications.celebration)
        // A notification tap lands on its tab — and, for the Learn nudge, on the article itself.
        .onAppear { applyPendingNotification() }
        .onChange(of: notifications.pendingDestination) { _ in applyPendingNotification() }
    }

    /// A tap taken while signed out is held on the service and applied the first time this
    /// view is allowed to exist — after authentication, never before.
    private func applyPendingNotification() {
        guard let destination = notifications.pendingDestination else { return }
        router.selection = destination.tab.rawValue
        if destination.tab == .profile { morePath = [.profile] }
        router.pendingLearnSlug = destination.learnSlug
        notifications.pendingDestination = nil
    }

    /// Keeps every tab's view alive so state (scroll position, in-tab nav) survives switching,
    /// showing only the selected one and routing touches only to it.
    private func tabContent<Content: View>(_ index: Int, _ content: Content) -> some View {
        let active = router.selection == index
        return content
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
            // So a result left open in a tab she is not looking at hides nothing (`ScanPrivacyShield`).
            .environment(\.tabIsSelected, active)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.items(moreEnabled: scanServices != nil).enumerated()), id: \.offset) { index, item in
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
        let badge = index == Self.learnTab ? learn.unreadNewCount : 0
        return Button {
            router.selection = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.icon).font(.system(size: 20))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 { badgeDot(badge) }
                    }
                Text(item.title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? GenesyxColor.primary : GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.title)
        // VoiceOver gets the count in words; the dot alone would be silent.
        .accessibilityLabel(badge > 0
                            ? "\(item.title), \(badge) new article\(badge == 1 ? "" : "s")"
                            : item.title)
    }

    /// Counts only articles that arrived in an update and are still unread, so it reads 0 on a
    /// first install — a badge of 16 would be a chore list, not an invitation.
    private func badgeDot(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 15, minHeight: 15)
            .background(GenesyxColor.electricPink, in: Capsule())
            .offset(x: 9, y: -5)
    }

    /// Initial tab for screenshot capture (`-uiTestTab N` launch arg); always Home in Release.
    private static var initialSelection: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "uiTestTab")
        #else
        return 0
        #endif
    }

    /// `-uiTestTab 6` has always meant Profile, so under More it opens with Profile pushed.
    /// `-uiTestMore scan` pushes Scan home instead, and `-uiTestMore list` leaves the list showing.
    private static var initialMorePath: [MoreDestination] {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "uiTestMore") {
            return MoreDestination(rawValue: raw).map { [$0] } ?? []
        }
        return initialSelection == profileTab ? [.profile] : []
        #else
        return []
        #endif
    }
}
