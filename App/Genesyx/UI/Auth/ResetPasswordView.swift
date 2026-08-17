import SwiftUI

/// The rule for a new password, kept out of the view so it can be tested without SwiftUI.
///
/// Identical to the check in `AuthView.submit` on purpose: a reset screen that accepted a password
/// the sign-in screen would later reject is its own kind of lockout. 72 is the bcrypt input
/// ceiling, not a style choice.
enum NewPasswordRule {
    static let minimumLength = 8
    static let maximumLength = 72

    /// `nil` means the pair is acceptable. Order matters — she is told about her own password
    /// before she is told it does not match a confirmation she may not have finished typing.
    static func problem(password: String, confirmation: String) -> String? {
        if password.count < minimumLength { return "Password must be at least 8 characters" }
        if password.count > maximumLength { return "Password is too long" }
        if confirmation.isEmpty { return "Type your new password again to confirm" }
        if password != confirmation { return "Those two passwords don't match" }
        return nil
    }
}

/// Where a password-reset link lands. Root content, not a sheet: she arrived here holding a live
/// session minted by the link, so anything dismissable would drop her into the app with her old
/// password still working. The only two ways out are setting a new password or cancelling, and
/// both end in a signed-out state at `AuthView`.
///
/// Styled to match `AuthView` deliberately — same field shape, same primary button, same 360pt
/// column — because this screen appears mid-flow from an email and should read as the same app
/// she just left.
struct ResetPasswordView: View {

    @EnvironmentObject private var session: SessionRepository

    /// Non-nil when the link itself failed to redeem. The form is not shown at all in that case:
    /// there is no session to set a password on, so offering the fields would only produce a
    /// second, more confusing failure after she had typed one out.
    var linkError: String?
    /// Clears the host's held link error so leaving this screen actually returns her to sign-in.
    var onFinished: () -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var error: String?
    @State private var submitting = false
    @State private var succeeded = false

    private var validationMessage: String? {
        NewPasswordRule.problem(password: password, confirmation: confirmation)
    }

    private var canSubmit: Bool { validationMessage == nil && !submitting }

    private func submit() {
        // Checked again here rather than trusting the disabled button: the button is the hint,
        // this is the rule.
        if let problem = validationMessage { error = problem; return }
        error = nil
        submitting = true
        Task {
            do {
                try await session.completePasswordRecovery(newPassword: password)
                password = ""
                confirmation = ""
                succeeded = true
            } catch {
                // The caught error is not surfaced: it can name the account and carry token
                // detail. She gets something she can act on instead.
                self.error = "We couldn't set that password. Your reset link may have expired. "
                    + "Ask for a new one and open it on this phone."
            }
            submitting = false
        }
    }

    private func leave() {
        session.cancelPasswordRecovery()
        onFinished()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("brand_lockup")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 220, height: 54)
                    .accessibilityLabel("Genesyx")

                Spacer().frame(height: 24)

                if succeeded {
                    successState
                } else if let linkError {
                    expiredState(linkError)
                } else {
                    form
                }
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .background(GenesyxColor.background.ignoresSafeArea())
        .accessibilityIdentifier("resetPassword.root")
    }

    // MARK: - States

    private var form: some View {
        VStack(spacing: 0) {
            Text("Choose a new password")
                .font(.gxDisplayLarge)
                .foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 8)
            Text("You'll sign in with this from now on.")
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 28)
            field("New password", text: $password)
            Spacer().frame(height: 16)
            field("Confirm new password", text: $confirmation)

            // Shown only once she has typed into the second field, so the mismatch warning does
            // not accuse her of an error she is still halfway through not making.
            if error == nil, !confirmation.isEmpty, let hint = validationMessage {
                Text(hint)
                    .font(.gxBodySmall)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .accessibilityIdentifier("resetPassword.hint")
            }

            if let error {
                Text(error)
                    .font(.gxBodySmall)
                    .foregroundStyle(GenesyxColor.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .accessibilityIdentifier("resetPassword.error")
            }

            Spacer().frame(height: 20)
            Button(action: submit) {
                Text(submitting ? "Saving…" : "Save new password")
                    .font(.gxLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(GenesyxColor.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(canSubmit ? 1 : 0.6)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .accessibilityIdentifier("resetPassword.save")
            .accessibilityHint("Sets your new password and returns you to sign in")

            Spacer().frame(height: 8)
            GxGhostButton(title: "Cancel", action: leave)
                .accessibilityIdentifier("resetPassword.cancel")
        }
    }

    private func expiredState(_ message: String) -> some View {
        VStack(spacing: 0) {
            Text("That link didn't work")
                .font(.gxDisplayLarge)
                .foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 12)
            Text(message)
                .font(.gxBody)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("resetPassword.linkError")
            Spacer().frame(height: 28)
            Button(action: leave) {
                Text("Back to sign in")
                    .font(.gxLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(GenesyxColor.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resetPassword.backFromError")
        }
    }

    private var successState: some View {
        VStack(spacing: 0) {
            Text("Password updated")
                .font(.gxDisplayLarge)
                .foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 12)
            Text("Sign in with your new password. Any other devices you were signed in on will "
                 + "need it too.")
                .font(.gxBody)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("resetPassword.success")
            Spacer().frame(height: 28)
            Button(action: onFinished) {
                Text("Sign in")
                    .font(.gxLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(GenesyxColor.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resetPassword.continue")
        }
    }

    /// Matches `AuthView.field`, minus the keyboard options a password never needs.
    /// `.newPassword` lets the keychain offer to generate and then store one.
    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.foreground)
            SecureField("", text: text)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(GenesyxColor.border, lineWidth: 1))
                .onChange(of: text.wrappedValue) { _ in error = nil }
                .accessibilityLabel(label)
        }
    }
}
