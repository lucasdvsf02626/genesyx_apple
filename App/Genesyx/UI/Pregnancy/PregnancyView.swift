import SwiftUI

/// Pregnancy mode (preview/stub) — a transition sell screen, then a stub pregnancy home.
/// Ported from the Android `PregnancyScreen`; presented as a sheet from Profile.
struct PregnancyView: View {

    @EnvironmentObject private var session: SessionRepository
    @Environment(\.dismiss) private var dismiss
    @State private var switched = false

    var body: some View {
        if switched {
            pregnancyHome
        } else {
            transition
        }
    }

    // MARK: Transition

    private var transition: some View {
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

                Spacer().frame(height: 32)
                GxPrimaryButton(title: "Switch to pregnancy mode") { switched = true }
                GxGhostButton(title: "Not yet, keep tracking") { dismiss() }
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

    // MARK: Pregnancy home (stub)

    private var pregnancyHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pregnancy mode").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                Text(session.displayName ?? "Guest").font(.gxTitle).foregroundStyle(GenesyxColor.foreground)

                Spacer().frame(height: 24)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Week-by-week", color: GenesyxColor.electricPink)
                    Text("Gentle prenatal guidance").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                    Text("Once you confirm your due date, Genesyx will guide you through each week with calm prenatal nutrition, symptom tracking, and supplement reminders.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                Spacer().frame(height: 12)
                HStack(spacing: 12) {
                    statTile("figure.child", "Trimester", "—", GenesyxColor.electricPink)
                    statTile("sparkles", "Focus", "Folate", GenesyxColor.electricLavender)
                }

                Spacer().frame(height: 20)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prenatal essentials").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    ForEach([
                        "Folate 400–800 mcg daily",
                        "Vitamin D 600 IU daily",
                        "Omega-3 (DHA) 200 mg daily",
                        "Stay hydrated and rest when needed",
                    ], id: \.self) { item in
                        Text("• \(item)").font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))

                Spacer().frame(height: 24)
                Button { switched = false } label: {
                    Text("Switch back to fertility prep").font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(GenesyxColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.vertical, 20)
        }
        .background(GenesyxColor.background)
    }

    private func statTile(_ icon: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(tint)
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
