#if DEBUG
import GenesyxCore
import SwiftUI

/// Development only: starts the activation flow over, or clears the programme, so a journey can
/// be run again. Neither draws anything when `-uiTestKitHideDebug` is given, so a deliverable
/// screenshot carries no QA buttons.
struct FertilityKitDebugControls: View {
    @EnvironmentObject private var kitAccess: FertilityKitAccessService
    @EnvironmentObject private var programme: ProgrammeRepository

    init() {}

    var body: some View {
        if !FertilityKitDebugOptions.hidesDebugControls {
            HStack(spacing: 16) {
                button("Reset access", id: "kit.debug.resetAccess") { kitAccess.resetForQA() }
                button("Reset programme", id: "kit.debug.resetProgramme") { programme.clearLocalState() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kitContainer("kit.debug")
        }
    }

    private func button(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
#endif
