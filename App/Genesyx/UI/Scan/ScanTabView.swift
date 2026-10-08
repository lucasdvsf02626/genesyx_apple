import GenesyxCore
import SwiftUI

/// Scan home: a list of the tests that can be scanned, the instructions for one, and the two
/// things the instructions lead to (the camera cover and typing the result in).
///
/// Pushed onto More's stack, which supplies the `NavigationStack`. It does no camera work and
/// builds no frame source: the camera exists only while the cover is up.
struct ScanTabView: View {
    let services: ScanServices
    /// A scan was saved and she has been sent to the pH tab: More goes back to its list.
    let onSaved: () -> Void
    /// The screen to open as Scan home appears, when the Fertility Kit sent her here for one test.
    let opening: ScanDeepLink?

    @EnvironmentObject private var router: TabRouter
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var consent: ConsentRepository
    /// Handed on to the LH screen for the same reason More hands it to this one: a pushed screen
    /// does not see the scene phase change, and its camera cover depends on it.
    @Environment(\.scenePhase) private var scenePhase

    @State private var showInstructions = false
    @State private var showLh = false
    @State private var showHcg = false
    @State private var showCapture = false
    @State private var showManualEntry = false
    /// How the cover ended. Acted on once it has gone: a sheet raised from a view that is still
    /// being dismissed does not appear.
    @State private var pendingExit: ScanExit?
    /// The deep link is honoured once: coming Back to Scan home must not push it again.
    @State private var openedDeepLink = false

    init(services: ScanServices, opening: ScanDeepLink? = nil, onSaved: @escaping () -> Void) {
        self.services = services
        self.opening = opening
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ConsentWithdrawnBanner()
                VStack(alignment: .leading, spacing: 4) {
                    Text(PhScanCopy.homeTitle).font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
                        .accessibilityAddTraits(.isHeader)
                    Text(PhScanCopy.homeSubtitle).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                // One card per test.
                testCard(title: PhScanCopy.phCardTitle, description: PhScanCopy.phCardDescription,
                         icon: "drop", identifier: "scan.home.phCard") { showInstructions = true }
                testCard(title: LhScanCopy.cardTitle, description: LhScanCopy.cardDescription,
                         icon: "testtube.2", identifier: "scan.home.lhCard") { showLh = true }
                testCard(title: HcgScanCopy.cardTitle, description: HcgScanCopy.cardDescription,
                         icon: "doc.text.magnifyingglass", identifier: "scan.home.hcgCard") { showHcg = true }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scan.home")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !openedDeepLink else { return }
            openedDeepLink = true
            if opening == .ovulationTest { showLh = true }
            if opening == .pregnancyTest { showHcg = true }
        }
        .navigationDestination(isPresented: $showInstructions) {
            ScanInstructionsView(
                onOpenCamera: { showCapture = true },
                onEnterManually: { showManualEntry = true })
        }
        .navigationDestination(isPresented: $showLh) {
            LhScanHomeView().environment(\.scenePhase, scenePhase)
        }
        .navigationDestination(isPresented: $showHcg) {
            HcgScanHomeView().environment(\.scenePhase, scenePhase)
        }
        .fullScreenCover(isPresented: $showCapture, onDismiss: coverDismissed) {
            ScanCaptureView(services: services) { exit in
                pendingExit = exit
                showCapture = false
            }
            .withAppEnvironment(container)
            .tint(GenesyxColor.primary)
        }
        .sheet(isPresented: $showManualEntry) {
            PhLogSheet(
                existing: nil,
                canSave: consent.isActive,
                onSave: { reading in
                    // A refused write keeps the sheet open, as on the pH tab.
                    if ph.create(reading) {
                        showManualEntry = false
                        router.selection = 2   // pH tab
                    }
                },
                onDelete: { _ in }
            )
            .withAppEnvironment(container)
        }
    }

    private func coverDismissed() {
        let exit = pendingExit
        pendingExit = nil
        switch exit {
        case .manualEntry:
            showManualEntry = true
        case .saved:
            onSaved()
            router.selection = 2   // pH tab
        case .cancelled, nil:
            break
        }
    }

    private func testCard(title: String, description: String, icon: String, identifier: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .accessibilityIdentifier(identifier)
    }
}

/// What to do before the camera opens, and the way round the camera for anyone who cannot or
/// would rather not use it.
private struct ScanInstructionsView: View {
    let onOpenCamera: () -> Void
    let onEnterManually: () -> Void

    @EnvironmentObject private var consent: ConsentRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(PhScanCopy.instructionSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.gxLabel.weight(.semibold)).foregroundStyle(GenesyxColor.primary)
                                .frame(width: 28, height: 28)
                                .background(GenesyxColor.primary.opacity(0.12))
                                .clipShape(Circle())
                            Text(step).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                        // VoiceOver reads "1, Complete the test…" as one element.
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("scan.instructions.step.\(index + 1)")
                    }
                }
                .padding(20)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock").accessibilityHidden(true)
                    Text(PhScanCopy.privacyNote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("scan.privacyNote")
                }
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                // Explains the two greyed-out buttons below it.
                ConsentWithdrawnBanner()

                GxPrimaryButton(title: PhScanCopy.openCamera, leadingSystemImage: "camera", action: onOpenCamera)
                    .disabled(!consent.isActive).opacity(consent.isActive ? 1 : 0.5)
                    .accessibilityIdentifier("scan.openCamera")
                GxGhostButton(title: PhScanCopy.enterManually, action: onEnterManually)
                    .disabled(!consent.isActive).opacity(consent.isActive ? 1 : 0.5)
                    .accessibilityIdentifier("scan.enterManually")
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scan.instructions")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(PhScanCopy.instructionsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Scan home") {
    NavigationStack { ScanTabView(services: .debug(scenario: .reading(4.4)), onSaved: {}) }
        .environmentObject(TabRouter(selection: 6))
        .withPreviewEnvironment()
}
#Preview("Scan instructions") {
    NavigationStack { ScanInstructionsView(onOpenCamera: {}, onEnterManually: {}) }
        .environmentObject(TabRouter(selection: 6))
        .withPreviewEnvironment()
}
#endif
