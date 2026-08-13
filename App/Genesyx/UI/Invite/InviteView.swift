import SwiftUI

/// Partner invite-accept screen (deep link `genesyx://invite/{code}`).
/// Ported from the Android `InviteScreen`. Deep-link routing into this view is wired separately;
/// it can be presented once a `code` is parsed from the incoming URL.
struct InviteView: View {

    let code: String
    var onAccepted: () -> Void
    var onBack: () -> Void
    var onSignIn: () -> Void

    @EnvironmentObject private var session: SessionRepository
    @EnvironmentObject private var partner: PartnerRepository

    @State private var accepting = false
    @State private var declining = false
    @State private var confirmingDecline = false
    @State private var error: String?

    private var valid: Bool { code.count >= 8 }
    private var busy: Bool { accepting || declining }

    /// The server refuses an invite that isn't hers — wrong email, already used, or revoked. That
    /// refusal has to be shown, not swallowed: the old code linked her optimistically and she would
    /// have believed a link that never happened.
    private func acceptInvite() {
        accepting = true
        error = nil
        Task {
            do {
                try await partner.accept(code: code)
                onAccepted()
            } catch {
                self.error = "This invite couldn't be accepted. It may have been sent to a different email address, already used, or withdrawn."
            }
            accepting = false
        }
    }

    /// Refusing the invite outright, which "Not now" does NOT do — that only dismisses the sheet,
    /// and the invite stays pending. A pending invite is a standing offer to whoever holds the link,
    /// which may no longer be only the person it was sent to.
    ///
    /// Irreversible: there is no path from `declined` back to `pending`, so the server will refuse a
    /// later accept on the same code. Hence the confirmation, and hence the quietest styling on the
    /// screen — this is the one action here she cannot undo.
    private func declineInvite() {
        declining = true
        error = nil
        Task {
            do {
                try await partner.decline(code: code)
                onBack()
            } catch {
                self.error = "This invite couldn't be declined. It may already have been used or withdrawn."
            }
            declining = false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("GENESYX").font(.gxCardHeading).tracking(2).foregroundStyle(GenesyxColor.foreground)

            if !session.isSignedIn {
                Spacer().frame(height: 24)
                Text("You've been invited").font(.gxTitle).foregroundStyle(GenesyxColor.foreground).multilineTextAlignment(.center)
                Spacer().frame(height: 8)
                Text("Sign in or create an account to accept this partner invite.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
                Spacer().frame(height: 24)
                GxPrimaryButton(title: "Sign in to continue", action: onSignIn)
            } else if !valid {
                Spacer().frame(height: 28)
                Text("Partner invite").font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                Spacer().frame(height: 12)
                Text("This invite link doesn't look valid or has already been used.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
                Spacer().frame(height: 24)
                GxGhostButton(title: "Back to app", action: onBack)
            } else {
                Spacer().frame(height: 28)
                Image(systemName: "heart.fill").font(.system(size: 40)).foregroundStyle(GenesyxColor.primary)
                Spacer().frame(height: 16)
                Text("Partner invite").font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                Spacer().frame(height: 12)
                Text("Accept to link your accounts. You'll each see that you're connected — your logs, readings and notes stay private to you.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
                if let error {
                    Spacer().frame(height: 12)
                    Text(error)
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.destructive)
                        .multilineTextAlignment(.center)
                }
                Spacer().frame(height: 24)
                GxPrimaryButton(title: accepting ? "Accepting…" : "Accept invite",
                                enabled: !busy) { acceptInvite() }
                GxGhostButton(title: "Not now", action: onBack)
                Button(declining ? "Declining…" : "Decline invite") { confirmingDecline = true }
                    .font(.gxBodySmall.weight(.medium))
                    .foregroundStyle(GenesyxColor.destructive)
                    .disabled(busy)
                    .padding(.vertical, 6)
                    .confirmationDialog("Decline this invite?", isPresented: $confirmingDecline,
                                        titleVisibility: .visible) {
                        Button("Decline invite", role: .destructive) { declineInvite() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("The link stops working and they'll need to send a new one. "
                             + "Either way, your logs, readings and notes were never shared.")
                    }
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GenesyxColor.background)
    }
}
