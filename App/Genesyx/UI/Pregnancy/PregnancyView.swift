import SwiftUI

/// Pregnancy mode — an honest "coming soon" teaser for the upcoming prenatal experience.
/// Presented as a sheet from Profile. No functional pregnancy tracking ships in v1, so this
/// screen only previews what's ahead; it never presents empty ("—") data as a working feature.
struct PregnancyView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { GxBackButton { dismiss() }; Spacer() }
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill").font(.system(size: 36)).foregroundStyle(GenesyxColor.electricPink)
                        .frame(width: 80, height: 80).background(GenesyxColor.powderPink.tintOnWhite(0.30))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    Spacer().frame(height: 24)
                    Text("Support for the next chapter")
                        .font(.gxTitle).foregroundStyle(GenesyxColor.foreground).multilineTextAlignment(.center)
                    Spacer().frame(height: 12)
                    Text("Whenever you're ready, Genesyx can gently shift to support you through pregnancy — at your pace.")
                        .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 28)
                featureCard("figure.child", "Trimester tracking", "Week-by-week guidance with calm, clear updates.")
                Spacer().frame(height: 12)
                featureCard("fork.knife", "Prenatal nutrition", "Updated focus foods and supplement guidance.")

                Spacer().frame(height: 24)
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 13)).foregroundStyle(GenesyxColor.electricLavender)
                    Text("Coming soon — we'll let you know the moment it's ready.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 24)
                GxPrimaryButton(title: "Keep tracking") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(GenesyxColor.background)
    }

    private func featureCard(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).foregroundStyle(GenesyxColor.electricPink)
                .frame(width: 48, height: 48).background(GenesyxColor.powderPink.tintOnWhite(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                Text(desc).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
        }
        .padding(16).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
