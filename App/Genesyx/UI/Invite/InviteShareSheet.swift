import SwiftUI
import GenesyxCore

/// Shown the moment the database issues an invite code. Creating the row invited nobody — this is
/// the step that actually gets the link to her partner.
///
/// It also says the one thing that will otherwise cause every failed invite: the code is bound to
/// the address it was sent to, so he has to sign in with *that* email to accept it.
struct InviteShareSheet: View {

    let invite: PartnerInvite
    let senderName: String?
    /// Whether the server actually emailed this invite. Never claim it did when it didn't.
    var emailed: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        DeepLink.inviteShareText(code: invite.code, from: senderName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: emailed ? "paperplane.fill" : "heart.fill")
                    .font(.system(size: 20)).foregroundStyle(GenesyxColor.primary)
                Text(emailed ? "Invite sent" : "Invite ready")
                    .font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            }

            Text(emailed
                 ? "We've emailed the invite to \(invite.email). They'll need to install Genesyx and sign in with that email address — the invite only works for them. You can send it again below if it doesn't arrive."
                 : "Send this to \(invite.email). They'll need to install Genesyx and sign in with that email address — the invite only works for them.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

            Text(DeepLink.inviteURL(code: invite.code)?.absoluteString ?? invite.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(GenesyxColor.foreground)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GenesyxColor.muted)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            ShareLink(item: shareText) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share invite").fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(GenesyxColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button("Done") { dismiss() }
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenesyxColor.background)
        .presentationDetents([.height(360)])
    }
}
