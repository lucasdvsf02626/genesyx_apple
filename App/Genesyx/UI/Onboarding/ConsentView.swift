import SwiftUI
import GenesyxCore

/// The Article 9(2)(a) explicit-consent screen, shown before the quiz — the first place Genesyx
/// asks her for anything about her body.
///
/// Three things here are legal requirements rather than design choices, and none of them should be
/// "tidied up" without knowing that:
///
/// * **The agreement control starts off and cannot be pre-set.** Article 4(11) requires a clear
///   affirmative action, and a pre-ticked box is the textbook example of what does not count.
/// * **Continue stays disabled until she operates it.** A screen she can dismiss into the quiz is a
///   screen that collected health data without a lawful basis.
/// * **The withdrawal route is named here, before she agrees, not only in Profile afterwards.**
///   That is Article 7(3), and it is why `ConsentPolicy.withdrawal` is on this screen.
///
/// Declining is a real, supported answer with a real destination — see `ConsentDeclinedView`.
struct ConsentView: View {
    let onAgree: () -> Void
    let onDecline: () -> Void
    let onBack: () -> Void

    @State private var agreed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { GxBackButton(action: onBack); Spacer() }
                Text(ConsentPolicy.title)
                    .font(.gxDisplayLarge)
                    .foregroundStyle(GenesyxColor.foreground)
                Spacer().frame(height: 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text(ConsentPolicy.body)
                    Text(ConsentPolicy.purpose)
                    Text(ConsentPolicy.withdrawal)
                }
                .font(.gxBody)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Spacer().frame(height: 24)
                GxOptionPill(text: ConsentPolicy.agreeLabel, selected: agreed) { agreed.toggle() }
                    .accessibilityIdentifier("consent.agree")

                Spacer().frame(height: 24)
                GxPrimaryButton(title: ConsentPolicy.continueLabel, enabled: agreed, action: onAgree)
                    .accessibilityIdentifier("consent.continue")
                GxGhostButton(title: "Not now", action: onDecline)
                    .accessibilityIdentifier("consent.decline")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

/// Sits at the top of every surface whose purpose is recording, and only after she has withdrawn.
///
/// It exists because the gate is at the repository, and a refused write is silent there. Since
/// build 22 the recording controls on these surfaces are disabled rather than merely inert, so this
/// banner is the sentence that explains a greyed-out button — without it the disabled state reads
/// as the app being broken rather than as her decision being honoured, and it hides the one thing
/// she needs to know, which is where to change her mind.
struct ConsentWithdrawnBanner: View {
    @EnvironmentObject private var consent: ConsentRepository

    var body: some View {
        if !consent.isActive {
            Text(ConsentPolicy.blockedBody)
                .font(.gxBody)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(GenesyxColor.border.opacity(0.6), lineWidth: 1))
                .accessibilityIdentifier("consent.blocked")
        }
    }
}

/// Where "Not now" lands. Deliberately not a dead end and deliberately not a nag: without this
/// permission there is no lawful basis to record anything, so the honest thing is to say plainly
/// what is unavailable and let her carry on into the app anyway.
///
/// "Continue anyway" is what makes the refusal real. A decline screen whose only exit is back to
/// the question is not a choice, and the freely-given condition in Article 7(4) is exactly about
/// that: consent obtained by making the app unusable without it is not consent.
struct ConsentDeclinedView: View {
    let onReconsider: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { GxBackButton(action: onReconsider); Spacer() }
            Spacer()
            Text(ConsentPolicy.declinedTitle)
                .font(.gxDisplayLarge)
                .foregroundStyle(GenesyxColor.foreground)
            Spacer().frame(height: 16)
            Text(ConsentPolicy.declinedBody)
                .font(.gxBody)
                .foregroundStyle(GenesyxColor.mutedForeground)
            Spacer()
            GxPrimaryButton(title: "Continue", action: onContinue)
                .accessibilityIdentifier("consent.declinedContinue")
            GxGhostButton(title: "Go back", action: onReconsider)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}
