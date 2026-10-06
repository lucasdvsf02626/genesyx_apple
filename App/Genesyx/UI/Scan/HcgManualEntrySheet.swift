import GenesyxCore
import SwiftUI

/// Typing a pregnancy test result in, for anyone who cannot or would rather not use the camera.
/// Nothing is chosen for her: Save stays off until she picks what her test strip shows. The three
/// choices are drawn alike, with no symbol of their own.
struct HcgManualEntrySheet: View {
    let onSaved: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var hcg: HcgRepository
    @EnvironmentObject private var consent: ConsentRepository
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: HcgClassification?
    @State private var recordedAt = Date()
    @State private var refused = false

    private static let options: [(classification: HcgClassification, title: String)] = [
        (.testLineDetected, HcgScanCopy.manualDetected),
        (.noTestLineDetected, HcgScanCopy.manualNotDetected),
        (.invalid, HcgScanCopy.manualInvalid),
    ]

    init(onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Explains the disabled Save before she meets it.
                    ConsentWithdrawnBanner()
                    Text(HcgScanCopy.manualPrompt)
                        .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 8) {
                        ForEach(Self.options, id: \.classification) { option in
                            optionButton(option.classification, title: option.title)
                        }
                    }

                    DatePicker(HcgScanCopy.manualDateLabel, selection: $recordedAt, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("hcg.manual.date")

                    // A refusal never reads as saved: the sheet stays open and says so.
                    if refused {
                        Text(HcgScanCopy.saveFailed)
                            .font(.gxBody).foregroundStyle(GenesyxColor.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("hcg.manual.saveFailed")
                    }
                    GxPrimaryButton(title: HcgScanCopy.saveResult, enabled: selection != nil && consent.isActive, action: save)
                        .accessibilityHint(selection == nil ? HcgScanCopy.manualPrompt : "")
                        .accessibilityIdentifier("hcg.manual.save")
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle(HcgScanCopy.manualTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HcgScanCopy.cancel, action: onCancel)
                        .accessibilityIdentifier("hcg.manual.cancel")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hcg.manual")
        .hcgPrivacyCover(scenePhase != .active)
    }

    /// The choice is marked by the tick and the selected trait, not by colour alone.
    private func optionButton(_ classification: HcgClassification, title: String) -> some View {
        let chosen = selection == classification
        return Button { selection = classification } label: {
            HStack(spacing: 12) {
                Text(title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(chosen ? GenesyxColor.primary : GenesyxColor.mutedForeground)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(chosen ? GenesyxColor.primary : GenesyxColor.border, lineWidth: chosen ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("hcg.manual.option.\(classification.rawValue)")
    }

    private func save() {
        guard let selection else { return }
        let saved = hcg.create(HcgResult(recordedAt: recordedAt, classification: selection, scan: nil))
        if saved { onSaved() } else { refused = true }
    }
}

#if DEBUG
#Preview("Pregnancy test manual entry") {
    HcgManualEntrySheet(onSaved: {}, onCancel: {}).withPreviewEnvironment()
}
#endif
