import GenesyxCore
import SwiftUI

extension View {
    /// Hides a pregnancy test screen while the app is not active, so the app-switcher snapshot
    /// shows nothing of it. An overlay, so no state is lost.
    func hcgPrivacyCover(_ hidden: Bool) -> some View {
        accessibilityHidden(hidden).overlay {
            if hidden { GenesyxColor.background.ignoresSafeArea().accessibilityHidden(true) }
        }
    }
}

/// The pregnancy test screen: what to do before the camera opens, the two ways to record a
/// result, and the results already recorded, kept behind a control that starts closed. Pushed
/// from Scan home.
///
/// It does no camera work and builds no frame source: the camera exists only while the cover is
/// up. A result here is a record of one strip. Nothing else in the app reads it.
struct HcgScanHomeView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var hcg: HcgRepository
    @EnvironmentObject private var consent: ConsentRepository
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var shield = ScanPrivacyShield.shared

    @State private var showCapture = false
    @State private var showManual = false
    /// How the cover ended. Acted on once it has gone: a sheet raised from a view that is still
    /// being dismissed does not appear.
    @State private var pendingExit: ScanExit?
    /// Closed whenever the screen is pushed, a cover or sheet is raised, or the app leaves the
    /// foreground.
    @State private var showHistory = false
    /// A typed-in result was just saved. Names no outcome.
    @State private var justSaved = false
    @State private var deleting: HcgResult?
    @State private var confirmDeleteAll = false

    /// Nil outside DEBUG, where there is nothing to scan with: manual entry and history remain.
    private let services = HcgScanServices.current

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(HcgScanCopy.instructionSteps.enumerated()), id: \.offset) { index, step in
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
                        .accessibilityIdentifier("hcg.instructions.step.\(index + 1)")
                    }
                }
                .padding(20)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                VStack(alignment: .leading, spacing: 8) {
                    Text(HcgScanCopy.aboutNote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("hcg.aboutNote")
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock").accessibilityHidden(true)
                        Text(HcgScanCopy.privacyNote)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("hcg.privacyNote")
                    }
                    Text(HcgScanCopy.storageNote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("hcg.storageNote")
                }
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                // Explains the two greyed-out buttons below it.
                ConsentWithdrawnBanner()

                if services != nil {
                    GxPrimaryButton(title: HcgScanCopy.openCamera, leadingSystemImage: "camera") {
                        closeDown()
                        showCapture = true
                    }
                    .disabled(!consent.isActive).opacity(consent.isActive ? 1 : 0.5)
                    .accessibilityIdentifier("hcg.openCamera")
                }
                GxGhostButton(title: HcgScanCopy.enterManually) {
                    closeDown()
                    showManual = true
                }
                .disabled(!consent.isActive).opacity(consent.isActive ? 1 : 0.5)
                .accessibilityIdentifier("hcg.enterManually")

                if justSaved {
                    Label(HcgScanCopy.resultSaved, systemImage: "checkmark.circle.fill")
                        .font(.gxCardHeadingSmall)
                        .foregroundStyle(GenesyxColor.foreground)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("hcg.home.saved")
                }

                // The control states its own state in its title. While closed there is no row, no
                // count and no empty text behind it.
                GxGhostButton(title: showHistory ? HcgScanCopy.hideHistory : HcgScanCopy.showHistory) {
                    showHistory.toggle()
                }
                .accessibilityIdentifier("hcg.history.toggle")
                if showHistory { history }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("hcg.home")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .hcgPrivacyCover(obscured)
        .scanPrivacyShield(presented: false)
        .navigationTitle(HcgScanCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: obscured) { hidden in
            if hidden { closeDown() }
        }
        .fullScreenCover(isPresented: $showCapture, onDismiss: coverDismissed) {
            if let services {
                HcgScanCaptureView(services: services) { exit in
                    pendingExit = exit
                    showCapture = false
                }
                .withAppEnvironment(container)
                .tint(GenesyxColor.primary)
            }
        }
        .sheet(isPresented: $showManual) {
            HcgManualEntrySheet(
                onSaved: {
                    showManual = false
                    justSaved = true
                },
                onCancel: { showManual = false })
                .withAppEnvironment(container)
        }
        // Alerts, as on the pH log sheet: a confirmation dialog is drawn as a popover at the top
        // of the screen, nowhere near the row it is about. The system adds its own Cancel.
        .alert(
            HcgScanCopy.deleteConfirmTitle,
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { result in
            Button(HcgScanCopy.deleteResult, role: .destructive) { hcg.delete(id: result.id) }
                .accessibilityIdentifier("hcg.history.delete")
        }
        .alert(HcgScanCopy.deleteAllConfirmTitle, isPresented: $confirmDeleteAll) {
            Button(HcgScanCopy.deleteAllConfirmButton, role: .destructive) { hcg.deleteAll() }
                .accessibilityIdentifier("hcg.history.deleteAll.confirm")
        } message: {
            Text(HcgScanCopy.deleteAllConfirmMessage)
        }
    }

    /// On UIKit's own notice, which arrives as the app stops being active. The scene phase gets
    /// here late, and is kept only in case a notice is ever missed.
    private var obscured: Bool { !shield.appIsActive || scenePhase != .active }

    private func closeDown() {
        showHistory = false
        justSaved = false
    }

    /// A saved scan needs nothing here: it said so on its own screen.
    private func coverDismissed() {
        let exit = pendingExit
        pendingExit = nil
        if case .manualEntry = exit { showManual = true }
    }

    /// Newest first. Deleting stays available with consent withdrawn: erasing what she already
    /// recorded is hers to do.
    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(HcgScanCopy.historyTitle)
                .font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                .accessibilityAddTraits(.isHeader)
            if hcg.results.isEmpty {
                Text(HcgScanCopy.historyEmpty)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .accessibilityIdentifier("hcg.history.empty")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(hcg.results.reversed().enumerated()), id: \.element.id) { index, result in
                        Button { deleting = result } label: { historyRow(result) }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(details(result).joined(separator: ", "))
                            .accessibilityHint(HcgScanCopy.deleteResult)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("hcg.history.row.\(index)")
                    }
                }
                Button(HcgScanCopy.deleteAll) { confirmDeleteAll = true }
                    .font(.gxBody).foregroundStyle(GenesyxColor.destructive)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("hcg.history.deleteAll")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hcg.history")
    }

    /// What the strip showed as words, then when, and how it got here. Never a cycle day.
    private func details(_ result: HcgResult) -> [String] {
        [
            HcgScanCopy.title(for: result.classification),
            result.recordedAt.formatted(.dateTime.day().month().hour().minute()),
            result.source == .cameraScan ? HcgScanCopy.sourceScanned : HcgScanCopy.sourceManual,
        ]
    }

    /// One symbol for every row, whatever it records.
    private func historyRow(_ result: HcgResult) -> some View {
        let parts = details(result)
        return HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 18)).foregroundStyle(GenesyxColor.primary)
                .frame(width: 34, height: 34)
                .background(GenesyxColor.primary.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(parts[0]).font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                Text(parts.dropFirst().joined(separator: " · "))
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            Image(systemName: "trash").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GenesyxColor.mutedForeground)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
#Preview("Pregnancy test home") {
    NavigationStack { HcgScanHomeView() }.withPreviewEnvironment()
}

#Preview("Pregnancy test home: with results") {
    let container = AppContainer.previewSeeded()
    container.hcg.create(HcgResult(recordedAt: Date().addingTimeInterval(-86_400), classification: .noTestLineDetected))
    container.hcg.create(HcgResult(recordedAt: Date(), classification: .testLineDetected))
    return NavigationStack { HcgScanHomeView() }.withAppEnvironment(container)
}
#endif
