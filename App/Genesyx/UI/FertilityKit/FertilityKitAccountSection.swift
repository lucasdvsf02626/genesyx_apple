import GenesyxCore
import SwiftUI

/// The Fertility Kit area of My Account: a muted label and the access card, styled like the
/// groups around it.
struct FertilityKitAccountSection: View {
    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(FertilityKitCopy.kitName).padding(.leading, 4)
            FertilityKitAccessCard(placement: .account)
        }
        .kitContainer("kit.account")
    }
}

#if DEBUG
#Preview {
    ScrollView { FertilityKitAccountSection().padding(20) }
        .gxPageBackground()
        .withKitPreview(access: true, day: 5)
}
#endif
