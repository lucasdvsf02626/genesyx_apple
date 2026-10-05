import GenesyxCore
import SwiftUI

/// The ovulation (LH) test screen: what to do before the camera opens, the two ways to record a
/// result, and the results already recorded. Pushed from Scan home.
///
/// It does no camera work and builds no frame source: the camera exists only while the cover is
/// up. A result here is a record of one test. Nothing on this screen reads or changes a
/// predicted date.
struct LhScanHomeView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var lh: LhRepository
    @EnvironmentObject private var consent: ConsentRepository

    @State private var showCapture = false
    @State private var showManual = false
    /// How the cover ended. Acted on once it has gone: a sheet raised from a view that is still
    /// being dismissed does not appear.
    @State private var pendingExit: ScanExit?
    @State private var deleting: LhResult?

    /// Nil outside DEBUG, where there is nothing to scan with: manual entry and history remain.
    private let services = LhScanServices.current

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(LhScanCopy.instructionSteps.enumerated()), id: \.offset) { index, step in
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
                        .accessibilityIdentifier("lh.instructions.step.\(index + 1)")
                    }
                }
                .padding(20)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock").accessibilityHidden(true)
                    Text(LhScanCopy.privacyNote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lh.privacyNote")
                }
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                // Explains the two greyed-out buttons below it.
                ConsentWithdrawnBanner()

                if services != nil {
                    GxPrimaryButton(title: LhScanCopy.openCamera, leadingSystemImage: "camera") { showCapture = true }
                        .disabled(!consent.isActive).opacity(consent.isActive ? 1 : 0.5)
                        .accessibilityIdentifier("lh.openCamera")
                }
                GxGhostButton(title: LhScanCopy.enterManually) { showManual = true }
                    .disabled(!consent.isActive).opacity(consent.isActive ? 1 : 0.5)
                    .accessibilityIdentifier("lh.enterManually")

                history
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lh.home")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(LhScanCopy.instructionsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCapture, onDismiss: coverDismissed) {
            if let services {
                LhScanCaptureView(services: services) { exit in
                    pendingExit = exit
                    showCapture = false
                }
                .withAppEnvironment(container)
                .tint(GenesyxColor.primary)
            }
        }
        .sheet(isPresented: $showManual) {
            LhManualEntrySheet { showManual = false }
                .withAppEnvironment(container)
        }
        // An alert, as on the pH log sheet: a confirmation dialog is drawn as a popover at the top
        // of the screen, nowhere near the row it is about. The system adds its own Cancel.
        .alert(
            LhScanCopy.deleteConfirmTitle,
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { result in
            Button(LhScanCopy.deleteResult, role: .destructive) { lh.delete(id: result.id) }
                .accessibilityIdentifier("lh.history.delete")
        }
    }

    /// A saved scan needs nothing here: the list below is the repository's.
    private func coverDismissed() {
        let exit = pendingExit
        pendingExit = nil
        if case .manualEntry = exit { showManual = true }
    }

    /// Newest first. Deleting stays available with consent withdrawn: erasing what she already
    /// recorded is hers to do.
    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LhScanCopy.historyTitle)
                .font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                .accessibilityAddTraits(.isHeader)
            if lh.results.isEmpty {
                Text(LhScanCopy.historyEmpty)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .accessibilityIdentifier("lh.history.empty")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(lh.results.reversed().enumerated()), id: \.element.id) { index, result in
                        Button { deleting = result } label: { historyRow(result) }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(details(result).joined(separator: ", "))
                            .accessibilityHint(LhScanCopy.deleteResult)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("lh.history.row.\(index)")
                    }
                }
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lh.history")
    }

    /// The result as words, then when, the cycle day it was saved on, and how it got here.
    private func details(_ result: LhResult) -> [String] {
        [
            LhScanCopy.title(for: result.classification),
            result.recordedAt.formatted(.dateTime.day().month().hour().minute()),
            result.cycleDay.map(LhScanCopy.cycleDayLabel),
            result.source == .cameraScan ? LhScanCopy.sourceScanned : LhScanCopy.sourceManual,
        ].compactMap { $0 }
    }

    private func historyRow(_ result: LhResult) -> some View {
        let parts = details(result)
        return HStack(spacing: 12) {
            Image(systemName: result.classification.symbolName)
                .font(.system(size: 18)).foregroundStyle(GenesyxColor.primary)
                .frame(width: 34, height: 34)
                .background(GenesyxColor.primary.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(parts[0]).font(.system(size: 15, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
                Text(parts.dropFirst().joined(separator: " · "))
                    .font(.system(size: 11)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            Image(systemName: "trash").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GenesyxColor.mutedForeground)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
#Preview("LH home") {
    NavigationStack { LhScanHomeView() }.withPreviewEnvironment()
}
#endif
