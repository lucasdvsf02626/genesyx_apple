import GenesyxCore
import SwiftUI

/// How one pregnancy test scan ended: what the strip showed, an invalid test, or a scan that
/// could not be read. It shows only what the resolver decided, in words: no signal and no
/// confidence. The two outcomes are drawn identically; the words are the only difference.
struct HcgResultView: View {
    let resolution: HcgScanResolution
    let isSimulated: Bool
    /// True when this result must not be written (a scripted result and a real account).
    let saveBlocked: Bool
    let saveState: ScanSaveState
    let onSave: () -> Void
    let onScanAgain: () -> Void
    let onManualEntry: () -> Void
    let onDone: () -> Void

    @EnvironmentObject private var consent: ConsentRepository

    init(resolution: HcgScanResolution, isSimulated: Bool, saveBlocked: Bool, saveState: ScanSaveState,
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
                case .unreadable(let reason): unreadable(reason)
                }
            }
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var identifier: String {
        switch resolution {
        case .reading: return "hcg.result"
        case .invalid: return "hcg.invalid"
        case .unreadable: return "hcg.unreadable"
        }
    }

    /// One symbol, one tint and one background for both outcomes.
    @ViewBuilder private func reading(_ classification: HcgClassification) -> some View {
        summary(symbol: "doc.text", tint: GenesyxColor.primary,
                title: HcgScanCopy.title(for: classification), detail: HcgScanCopy.body(for: classification),
                identifier: "hcg.result.title")
            .frame(maxWidth: .infinity).padding(20)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 16))

        Text(HcgScanCopy.resultNote)
            .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("hcg.result.note")
        Text(HcgScanCopy.disclaimer)
            .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("hcg.result.disclaimer")

        // Explains a greyed-out Save, and a refused one.
        ConsentWithdrawnBanner()

        if saveState == .saved {
            Label(HcgScanCopy.resultSaved, systemImage: "checkmark.circle.fill")
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("hcg.result.saved")
            GxPrimaryButton(title: HcgScanCopy.done, action: onDone)
                .accessibilityIdentifier("hcg.result.done")
        } else {
            // A refusal never reads as saved: the sentence stays until she saves or leaves.
            if saveState == .refused {
                Text(HcgScanCopy.saveFailed)
                    .font(.gxBody).foregroundStyle(GenesyxColor.destructive)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hcg.result.saveFailed")
            }
            GxPrimaryButton(title: HcgScanCopy.saveResult, enabled: consent.isActive && !saveBlocked, action: onSave)
                .accessibilityIdentifier("hcg.result.save")
        }
        GxGhostButton(title: HcgScanCopy.scanAgain, action: onScanAgain)
            .accessibilityIdentifier("hcg.scanAgain")
    }

    /// The control line is missing: a statement about the strip, so the way on is a new one.
    @ViewBuilder private var invalid: some View {
        summary(symbol: "xmark.circle", tint: GenesyxColor.primary,
                title: HcgScanCopy.invalidTitle, detail: HcgScanCopy.invalidBody,
                identifier: "hcg.invalid.title")
            .padding(.top, 24)
        GxPrimaryButton(title: HcgScanCopy.scanNewTest, action: onScanAgain)
            .accessibilityIdentifier("hcg.scanNewTest")
        GxGhostButton(title: HcgScanCopy.enterManually, action: onManualEntry)
            .accessibilityIdentifier("hcg.enterManually")
    }

    /// Neither outcome appears here, by rule: an uncertain scan is not a result.
    @ViewBuilder private func unreadable(_ reason: HcgUnreadableReason) -> some View {
        summary(symbol: "exclamationmark.triangle", tint: GenesyxColor.mutedForeground,
                title: HcgScanCopy.unreadableTitle, detail: HcgScanCopy.unreadableBody,
                identifier: "hcg.unreadable.title")
            .padding(.top, 24)
        if let message = HcgScanCopy.unreadableMessage(for: reason) {
            Text(message)
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("hcg.unreadable.reason")
        }
        GxPrimaryButton(title: HcgScanCopy.tryAgain, action: onScanAgain)
            .accessibilityIdentifier("hcg.tryAgain")
        GxGhostButton(title: HcgScanCopy.enterManually, action: onManualEntry)
            .accessibilityIdentifier("hcg.enterManually")
    }

    /// Symbol, title and body. The two lines are one element, read exactly as they are written,
    /// so the identifier names both. The symbol is decoration and is hidden from VoiceOver.
    private func summary(symbol: String, tint: Color, title: String, detail: String, identifier: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                Text(detail)
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
private func hcgPreviewResult(_ resolution: HcgScanResolution, _ saveState: ScanSaveState = .unsaved,
                              saveBlocked: Bool = false) -> some View {
    HcgResultView(
        resolution: resolution, isSimulated: true, saveBlocked: saveBlocked, saveState: saveState,
        onSave: {}, onScanAgain: {}, onManualEntry: {}, onDone: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

private func hcgPreviewReading(_ classification: HcgClassification) -> HcgScanResolution {
    .reading(classification, HcgScanProvenance(
        scannerVersion: "preview", configurationID: "preview", configurationVersion: "0"))
}

#Preview("Pregnancy test result: test line") { hcgPreviewResult(hcgPreviewReading(.testLineDetected)) }
#Preview("Pregnancy test result: no test line") { hcgPreviewResult(hcgPreviewReading(.noTestLineDetected)) }
#Preview("Pregnancy test result: saved") { hcgPreviewResult(hcgPreviewReading(.noTestLineDetected), .saved) }
#Preview("Pregnancy test result: refused") { hcgPreviewResult(hcgPreviewReading(.noTestLineDetected), .refused) }
#Preview("Pregnancy test result: save blocked") { hcgPreviewResult(hcgPreviewReading(.noTestLineDetected), saveBlocked: true) }
#Preview("Pregnancy test invalid") { hcgPreviewResult(.invalid) }
#Preview("Pregnancy test unreadable") { hcgPreviewResult(.unreadable(.quality([]))) }
#Preview("Pregnancy test unreadable: glare") { hcgPreviewResult(.unreadable(.quality([.glare]))) }
#Preview("Pregnancy test unreadable: not clear enough") { hcgPreviewResult(.unreadable(.indeterminateTestLine)) }
#endif
