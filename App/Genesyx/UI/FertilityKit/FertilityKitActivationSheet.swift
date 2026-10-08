import GenesyxCore
import SwiftUI

/// Enter the code from the kit. The view shapes nothing she types: trimming and case are core's,
/// the entry is cleared in the turn it is sent, and nothing here knows what a valid code is.
struct FertilityKitActivationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var kitAccess: FertilityKitAccessService

    @State private var entry = ""
    @State private var message: String?
    @State private var succeeded = false
    @FocusState private var focused: Bool

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if succeeded { successState } else { form }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                .kitContainer("kit.activate.sheet")
            }
            .background(GenesyxColor.background)
            .navigationTitle(FertilityKitAccessCopy.activationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FertilityKitCopy.cancel) { dismiss() }.accessibilityIdentifier("kit.activate.cancel")
                }
            }
        }
        .onDisappear { entry = "" }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            KitLine(FertilityKitAccessCopy.activationBody, muted: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(FertilityKitAccessCopy.fieldLabel).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground)
                TextField("", text: $entry)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .font(.gxBody)
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
                    // Padding around a TextField is dead until the box is made part of it.
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }
                    .onChange(of: entry) { _ in message = nil }
                    .accessibilityLabel(FertilityKitAccessCopy.fieldLabel)
                    .accessibilityIdentifier("kit.activate.field")
            }
            if let message {
                KitLine(message)
                    .accessibilityIdentifier("kit.activate.message")
            }
            GxPrimaryButton(title: FertilityKitAccessCopy.activateAction,
                            enabled: FertilityKitAccessPresentation.canSubmit(entry: entry, isWorking: kitAccess.isWorking)) {
                submit()
            }
            .accessibilityIdentifier("kit.activate.submit")
        }
    }

    private var successState: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let message { KitLine(message) }
            GxPrimaryButton(title: FertilityKitCopy.done) { dismiss() }
                .accessibilityIdentifier("kit.activate.done")
        }
        .kitContainer("kit.activate.success")
    }

    private func submit() {
        guard FertilityKitAccessPresentation.canSubmit(entry: entry, isWorking: kitAccess.isWorking) else { return }
        let typed = entry
        entry = ""
        focused = false
        Task {
            let result = await kitAccess.redeem(typed)
            guard let line = FertilityKitAccessPresentation.activationMessage(for: result) else { return }
            message = line
            succeeded = FertilityKitAccessPresentation.isSuccess(result)
        }
    }
}

#if DEBUG
#Preview {
    FertilityKitActivationSheet().withKitPreview(access: false)
}
#endif
