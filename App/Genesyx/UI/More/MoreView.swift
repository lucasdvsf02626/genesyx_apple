import GenesyxCore
import SwiftUI

/// What More can push. The raw values are the `-uiTestMore` launch values.
enum MoreDestination: String, Hashable {
    case profile, scan
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    row(.profile, title: "Profile", description: "Your account, reminders and settings",
                        icon: "person", identifier: "more.profile")
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
                case .profile: ProfileView(embedded: true)
                case .scan:
                    ScanTabView(services: scanServices, onSaved: { path = [] })
                        .environment(\.scenePhase, scenePhase)
                }
            }
        }
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
