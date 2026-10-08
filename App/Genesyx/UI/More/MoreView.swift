import GenesyxCore
import SwiftUI

/// What More can push. The raw values are the `-uiTestMore` launch values.
enum MoreDestination: String, Hashable {
    case profile, scan
    case fertilityKit, kitToday, kitGuide, kitGuideSection, kitDietPlan, kitReviews, kitWeeklyReview
    case kitNinetyDayReview, kitPicture, kitCycleHistory
}

/// A scan screen the Fertility Kit can open directly. Scan home pushes it as it appears.
enum ScanDeepLink: Equatable {
    case ovulationTest, pregnancyTest
}

/// The seventh tab once there is more to show than the bar has room for: a list of the
/// destinations that have no tab of their own. New destinations are added here, not to the bar.
///
/// Only built while Scan Test is available (see `MainTabView`), which is why it cannot exist
/// without a set of scan services.
struct MoreView: View {
    let scanServices: ScanServices
    /// Owned by `MainTabView`, so a notification or launch argument aimed at Profile can push it.
    @Binding var path: [MoreDestination]

    /// Read here and handed to Scan home: a pushed screen does not see the scene phase change,
    /// and the camera cover depends on it to drop a scan when the app goes to the background.
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var kitAccess: FertilityKitAccessService
    /// Set immediately before the push that reads them, and kept until the next one replaces
    /// them, so Back from a screen opened on top returns to the same section or week.
    @State private var scanOpening: ScanDeepLink?
    @State private var guideSlug: String?
    @State private var reviewWeek: Int?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    row(.profile, title: "Profile", description: "Your account, reminders and settings",
                        icon: "person", identifier: "more.profile")
                    // Only while the account holds access. Without it nothing of the kit is
                    // offered outside the Fertility Kit area of Profile.
                    if container.fertilityKit && kitAccess.hasAccess {
                        row(.fertilityKit, title: FertilityKitCopy.productName,
                            description: FertilityKitCopy.moreRowDescription,
                            icon: "shippingbox", identifier: "more.fertilityKit")
                    }
                    row(.scan, title: PhScanCopy.homeTitle, description: PhScanCopy.homeSubtitle,
                        icon: "viewfinder", identifier: "more.scan")
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("more.home")
            }
            .frame(maxWidth: .infinity)
            .gxPageBackground()
            .navigationTitle("More")
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .profile:
                    if container.fertilityKit { kit(gated: false) { ProfileView(embedded: true) } }
                    else { ProfileView(embedded: true) }
                case .scan:
                    ScanTabView(services: scanServices, opening: scanOpening, onSaved: { path = [] })
                        .environment(\.scenePhase, scenePhase)
                case .fertilityKit:       kit(gated: false) { FertilityKitHomeView() }
                case .kitToday:           kit { ProgrammeDayReaderView() }
                case .kitGuide:           kit { ProgrammeGuideView() }
                case .kitGuideSection:
                    kit {
                        if let section = guideSlug.flatMap(ProgrammeGuideDraft.section(slug:)) {
                            ProgrammeGuideSectionView(section: section)
                        } else {
                            ProgrammeGuideView()
                        }
                    }
                case .kitDietPlan:        kit { DietPlanView() }
                case .kitReviews:         kit { ProgrammeReviewsView() }
                case .kitWeeklyReview:
                    kit {
                        if let week = reviewWeek { ProgrammeWeeklyReviewView(week: week) } else { ProgrammeReviewsView() }
                    }
                case .kitNinetyDayReview: kit { ProgrammeNinetyDayReviewView() }
                case .kitPicture:         kit { FertilityPictureView() }
                case .kitCycleHistory:    if container.cycleHistory { kit { CycleHistoryView() } }
                }
            }
            // A scan opened from the kit is opened once: leaving Scan forgets the target, so the
            // More row afterwards shows Scan home.
            .onChange(of: path) { path in
                if !path.contains(.scan) { scanOpening = nil }
            }
        }
    }

    // MARK: - The Fertility Kit

    /// The one place the kit's host is built. `gated` screens show only the access card until the
    /// account holds access; the kit home and Profile are not gated, because they are where she
    /// activates.
    @ViewBuilder
    private func kit<Content: View>(gated: Bool = true, @ViewBuilder _ content: () -> Content) -> some View {
        if container.fertilityKit {
            FertilityKitHost(gated: gated, scanAvailable: kitScanAvailable,
                             cycleHistoryAvailable: container.cycleHistory,
                             navigation: FertilityKitNavigation(open: open, openScan: openScan,
                                                                openGuideSection: openGuideSection,
                                                                openWeeklyReview: openWeeklyReview)) { content() }
        }
    }

    /// A destination already on the path is popped back to, so Back always returns to where she
    /// came from and the stack cannot grow without bound.
    private func open(_ destination: MoreDestination) {
        if let index = path.firstIndex(of: destination) {
            path = Array(path.prefix(through: index))
        } else {
            path.append(destination)
        }
    }

    private func openScan(_ target: ScanDeepLink) {
        scanOpening = target
        open(.scan)
    }

    private func openGuideSection(_ slug: String) {
        guideSlug = slug
        open(.kitGuideSection)
    }

    private func openWeeklyReview(_ week: Int) {
        reviewWeek = week
        open(.kitWeeklyReview)
    }

    /// Scanning exists wherever More does. The launch argument is the one way to see the kit's
    /// scan-off path in a running development build.
    private var kitScanAvailable: Bool {
        #if DEBUG
        return !UserDefaults.standard.bool(forKey: "uiTestKitNoScan")
        #else
        return true
        #endif
    }

    private func row(_ destination: MoreDestination, title: String, description: String, icon: String,
                     identifier: String) -> some View {
        Button { path = [destination] } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18)).foregroundStyle(GenesyxColor.primary)
                    .frame(width: 44, height: 44)
                    .background(GenesyxColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    Text(description).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(20)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(description)")
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview("More") {
    MoreView(scanServices: .debug(scenario: .reading(4.4)), path: .constant([]))
        .environmentObject(TabRouter(selection: 6))
        .withPreviewEnvironment()
}
#endif
