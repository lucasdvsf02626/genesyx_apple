import GenesyxCore
import SwiftUI

extension LhClassification {
    /// Drawn beside the words, never in place of them, and in one colour for every result.
    var symbolName: String {
        switch self {
        case .low: return "minus.circle"
        case .rising: return "arrow.up.right.circle"
        case .positive: return "plus.circle"
        case .invalid: return "xmark.circle"
        case .unreadable: return "exclamationmark.triangle"
        }
    }
}

/// How one LH scan ended: a result she can save, an invalid test, or a scan that could not be
/// read. It shows only what the resolver decided, in words: no signal, ratio or confidence.
struct LhResultView: View {
    let resolution: LhScanResolution
    let isSimulated: Bool
    /// True when this result must not be written (a scripted result and a real account).
    let saveBlocked: Bool
    let saveState: ScanSaveState
    let onSave: () -> Void
    let onScanAgain: () -> Void
    let onManualEntry: () -> Void
    let onDone: () -> Void

    @EnvironmentObject private var consent: ConsentRepository

    init(resolution: LhScanResolution, isSimulated: Bool, saveBlocked: Bool, saveState: ScanSaveState,
         onSave: @escaping () -> Void, onScanAgain: @escaping () -> Void,
         onManualEntry: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.resolution = resolution
        self.isSimulated = isSimulated
        self.saveBlocked = saveBlocked
        self.saveState = saveState
        self.onSave = onSave
        self.onScanAgain = onScanAgain
        self.onManualEntry = onManualEntry
        self.onDone = onDone
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                #if DEBUG
                if isSimulated { ScanDebugBanner(saveBlocked: saveBlocked) }
                #endif
                switch resolution {
                case .reading(let classification, _): reading(classification)
                case .invalid: invalid
                case .unreadable(let issues): unreadable(issues)
                }
            }
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var identifier: String {
        switch resolution {
        case .reading: return "lh.result"
        case .invalid: return "lh.invalid"
        case .unreadable: return "lh.unreadable"
        }
    }

    @ViewBuilder private func reading(_ classification: LhClassification) -> some View {
        summary(classification, identifier: "lh.result.title")
            .frame(maxWidth: .infinity).padding(20)
            .background(GenesyxColor.primary.opacity(0.10)).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))

        Text(LhScanCopy.resultNote)
            .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("lh.result.note")
        Text(LhScanCopy.disclaimer)
            .font(.gxEyebrow).foregroundStyle(GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("lh.result.disclaimer")

        // Explains a greyed-out Save, and a refused one.
        ConsentWithdrawnBanner()

        if saveState == .saved {
            Label(LhScanCopy.resultSaved, systemImage: "checkmark.circle.fill")
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("lh.result.saved")
            GxPrimaryButton(title: LhScanCopy.done, action: onDone)
                .accessibilityIdentifier("lh.result.done")
        } else {
            // A refusal never reads as saved: the sentence stays until she saves or leaves.
            if saveState == .refused {
                Text(LhScanCopy.saveFailed)
                    .font(.gxBody).foregroundStyle(GenesyxColor.destructive)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("lh.result.saveFailed")
            }
            GxPrimaryButton(title: LhScanCopy.saveResult, enabled: consent.isActive && !saveBlocked, action: onSave)
                .accessibilityIdentifier("lh.result.save")
        }
        GxGhostButton(title: LhScanCopy.scanAgain, action: onScanAgain)
            .accessibilityIdentifier("lh.scanAgain")
    }

    /// The control line is missing: a statement about the strip, so the way on is a new one.
    @ViewBuilder private var invalid: some View {
        summary(.invalid, identifier: "lh.invalid.title")
            .padding(.top, 24)
        GxPrimaryButton(title: LhScanCopy.scanNewTest, action: onScanAgain)
            .accessibilityIdentifier("lh.scanNewTest")
        GxGhostButton(title: LhScanCopy.enterManually, action: onManualEntry)
            .accessibilityIdentifier("lh.enterManually")
    }

    /// No classification appears here, by rule: an uncertain scan is not a result.
    @ViewBuilder private func unreadable(_ issues: [ScanQualityIssue]) -> some View {
        summary(.unreadable, identifier: "lh.unreadable.title")
            .padding(.top, 24)
        if let issue = issues.first {
            Text(LhScanCopy.message(for: issue))
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lh.unreadable.issue")
        }
        GxPrimaryButton(title: LhScanCopy.tryAgain, action: onScanAgain)
            .accessibilityIdentifier("lh.tryAgain")
        GxGhostButton(title: LhScanCopy.enterManually, action: onManualEntry)
            .accessibilityIdentifier("lh.enterManually")
    }

    /// Symbol, title and body. The two lines are one element, read as "Low LH, No LH surge…",
    /// so the identifier names both.
    private func summary(_ classification: LhClassification, identifier: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: classification.symbolName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(classification == .unreadable ? GenesyxColor.mutedForeground : GenesyxColor.primary)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(LhScanCopy.title(for: classification))
                    .font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                Text(LhScanCopy.body(for: classification))
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(identifier)
        }
    }
}

#if DEBUG
@MainActor
private func lhPreviewResult(_ resolution: LhScanResolution, _ saveState: ScanSaveState = .unsaved,
                             saveBlocked: Bool = false) -> some View {
    LhResultView(
        resolution: resolution, isSimulated: true, saveBlocked: saveBlocked, saveState: saveState,
        onSave: {}, onScanAgain: {}, onManualEntry: {}, onDone: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

private func lhPreviewReading(_ classification: LhClassification) -> LhScanResolution {
    .reading(classification, LhScanMeasurement(
        testSignal: 0.1, controlSignal: 0.6, testControlRatio: 0.17, confidence: 0.95,
        scannerVersion: "preview", configurationID: "preview", configurationVersion: "0"))
}

#Preview("LH result: low") { lhPreviewResult(lhPreviewReading(.low)) }
#Preview("LH result: positive") { lhPreviewResult(lhPreviewReading(.positive)) }
#Preview("LH result: saved") { lhPreviewResult(lhPreviewReading(.low), .saved) }
#Preview("LH result: refused") { lhPreviewResult(lhPreviewReading(.low), .refused) }
#Preview("LH result: save blocked") { lhPreviewResult(lhPreviewReading(.low), saveBlocked: true) }
#Preview("LH invalid") { lhPreviewResult(.invalid) }
#Preview("LH unreadable") { lhPreviewResult(.unreadable([])) }
#Preview("LH unreadable: glare") { lhPreviewResult(.unreadable([.glare])) }
#endif
