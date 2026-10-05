import GenesyxCore
import SwiftUI

/// A scanned reading: the number, its status as a word, the same caveats a typed reading carries,
/// and Save. It is only ever handed a value the resolver has accepted, and shows it as it stands.
struct ScanResultView: View {
    let value: Double
    let isSimulated: Bool
    /// True when this result must not be written (a scripted value and a real account).
    let saveBlocked: Bool
    let saveState: ScanSaveState
    let onSave: () -> Void
    let onScanAgain: () -> Void
    let onViewHistory: () -> Void

    @EnvironmentObject private var consent: ConsentRepository

    init(value: Double, isSimulated: Bool, saveBlocked: Bool, saveState: ScanSaveState,
         onSave: @escaping () -> Void, onScanAgain: @escaping () -> Void, onViewHistory: @escaping () -> Void) {
        self.value = value
        self.isSimulated = isSimulated
        self.saveBlocked = saveBlocked
        self.saveState = saveState
        self.onSave = onSave
        self.onScanAgain = onScanAgain
        self.onViewHistory = onViewHistory
    }

    var body: some View {
        let status = PhStatus.classify(value)
        let color = Theme.color(for: status)
        ScrollView {
            VStack(spacing: 16) {
                #if DEBUG
                if isSimulated { ScanDebugBanner(saveBlocked: saveBlocked) }
                #endif
                Text(PhScanCopy.resultTitle)
                    .font(.gxTitle)
                    .foregroundStyle(GenesyxColor.foreground)
                    .accessibilityAddTraits(.isHeader)

                // The status is a word in a capsule, as in the pH log sheet: never colour alone.
                VStack(spacing: 6) {
                    Text(String(format: "%.1f", value)).font(.gxPhValue).foregroundStyle(color)
                    Text(status.label.uppercased()).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 3)
                        .background(color.opacity(0.18)).clipShape(Capsule())
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 16))
                // One element for VoiceOver, read as "pH 4.4, Healthy".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "pH %.1f", value))
                .accessibilityValue(status.label)
                .accessibilityIdentifier("scan.result.value")

                if status == .elevated {
                    Text(PhScanCopy.elevatedNote)
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("scan.result.elevatedNote")
                }
                Text(PhScanCopy.disclaimer)
                    .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scan.result.disclaimer")

                // Explains a greyed-out Save, and a refused one.
                ConsentWithdrawnBanner()

                if saveState == .saved {
                    Label(PhScanCopy.resultSaved, systemImage: "checkmark.circle.fill")
                        .font(.gxCardHeadingSmall)
                        .foregroundStyle(GenesyxColor.foreground)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("scan.result.saved")
                    GxPrimaryButton(title: PhScanCopy.viewHistory, action: onViewHistory)
                        .accessibilityIdentifier("scan.result.viewHistory")
                } else {
                    // A refusal never reads as saved: the sentence stays until she saves or leaves.
                    if saveState == .refused {
                        Text(PhScanCopy.saveFailed)
                            .font(.gxBody).foregroundStyle(GenesyxColor.destructive)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("scan.result.saveFailed")
                    }
                    GxPrimaryButton(title: PhScanCopy.saveResult, enabled: consent.isActive && !saveBlocked, action: onSave)
                        .accessibilityIdentifier("scan.result.save")
                }
                GxGhostButton(title: PhScanCopy.scanAgain, action: onScanAgain)
                    .accessibilityIdentifier("scan.scanAgain")
            }
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.result")
    }
}

/// The scan could not be read. No number appears here, by rule: an uncertain scan is not a result.
struct ScanUnreadableView: View {
    let issues: [ScanQualityIssue]
    let onScanAgain: () -> Void
    let onManualEntry: () -> Void

    init(issues: [ScanQualityIssue], onScanAgain: @escaping () -> Void, onManualEntry: @escaping () -> Void) {
        self.issues = issues
        self.onScanAgain = onScanAgain
        self.onManualEntry = onManualEntry
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .accessibilityHidden(true)
                Text(PhScanCopy.unreadableTitle)
                    .font(.gxTitle)
                    .foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let issue = issues.first {
                    Text(PhScanCopy.message(for: issue))
                        .font(.gxCardHeadingSmall)
                        .foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("scan.unreadable.issue")
                }
                Text(PhScanCopy.unreadableBody)
                    .font(.gxBody)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                GxPrimaryButton(title: PhScanCopy.scanAgain, action: onScanAgain)
                    .accessibilityIdentifier("scan.scanAgain")
                GxGhostButton(title: PhScanCopy.enterManually, action: onManualEntry)
                    .accessibilityIdentifier("scan.enterManually")
            }
            .padding(20)
            .padding(.top, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.unreadable")
    }
}
