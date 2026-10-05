import GenesyxCore
import SwiftUI

/// Typing an ovulation test result in, for anyone who cannot or would rather not use the camera.
/// Nothing is chosen for her: Save stays off until she picks what her test shows.
struct LhManualEntrySheet: View {
    let onClose: () -> Void

    @EnvironmentObject private var lh: LhRepository
    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var consent: ConsentRepository

    @State private var selection: LhClassification?
    @State private var recordedAt = Date()
    @State private var refused = false

    /// What she can read off a strip herself. Rising is a scanner's reading, never offered here.
    private static let options: [(classification: LhClassification, title: String)] = [
        (.low, LhScanCopy.manualLow),
        (.positive, LhScanCopy.manualPositive),
        (.invalid, LhScanCopy.manualInvalid),
    ]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Explains the disabled Save before she meets it.
                    ConsentWithdrawnBanner()
                    Text(LhScanCopy.manualPrompt)
                        .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 8) {
                        ForEach(Self.options, id: \.classification) { option in
                            optionButton(option.classification, title: option.title)
                        }
                    }

                    DatePicker(LhScanCopy.manualDateLabel, selection: $recordedAt, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("lh.manual.date")

                    // A refusal never reads as saved: the sheet stays open and says so.
                    if refused {
                        Text(LhScanCopy.saveFailed)
                            .font(.gxBody).foregroundStyle(GenesyxColor.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("lh.manual.saveFailed")
                    }
                    GxPrimaryButton(title: LhScanCopy.saveResult, enabled: selection != nil && consent.isActive, action: save)
                        .accessibilityHint(selection == nil ? LhScanCopy.manualPrompt : "")
                        .accessibilityIdentifier("lh.manual.save")
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle(LhScanCopy.manualTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LhScanCopy.cancel, action: onClose)
                        .accessibilityIdentifier("lh.manual.cancel")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lh.manual")
    }

    /// The choice is marked by the tick and the selected trait, not by colour alone.
    private func optionButton(_ classification: LhClassification, title: String) -> some View {
        let chosen = selection == classification
        return Button { selection = classification } label: {
            HStack(spacing: 12) {
                Image(systemName: classification.symbolName)
                    .font(.system(size: 18)).foregroundStyle(GenesyxColor.primary)
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
        .accessibilityIdentifier("lh.manual.option.\(classification.rawValue)")
    }

    private func save() {
        guard let selection else { return }
        let saved = lh.create(LhResult(
            recordedAt: recordedAt,
            cycleDay: LhCycleDay.snapshot(settings: cycle.settings, at: recordedAt),
            classification: selection, scan: nil))
        if saved { onClose() } else { refused = true }
    }
}

#if DEBUG
#Preview("LH manual entry") {
    LhManualEntrySheet(onClose: {}).withPreviewEnvironment()
}
#endif
