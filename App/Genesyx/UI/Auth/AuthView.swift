import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Email + password sign in / sign up (with a mock "Continue with Google").
/// Ported from the Android `AuthScreen`; presented as a sheet. Writes to `SessionRepository`.
/// (When Supabase is wired, replace the mock sign-in with real auth + Sign in with Apple.)
struct AuthView: View {

    @EnvironmentObject private var session: SessionRepository
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: (() -> Void)? = nil

    @State private var signupMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?

    @State private var submitting = false

    private func submit() {
        if !EmailValidator.isValid(email) { error = "Enter a valid email"; return }
        if password.count < 8 { error = "Password must be at least 8 characters"; return }
        if password.count > 72 { error = "Password is too long"; return }
        submitting = true
        Task {
            do {
                try await session.authenticate(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: signupMode ? name : nil,
                    signUp: signupMode
                )
                onSignedIn?(); dismiss()
            } catch {
                self.error = "Could not sign in. Please check your details and try again."
            }
            submitting = false
        }
    }

    /// Mock "Continue with Google" — local sign-in (real Google OAuth lands with Supabase).
    private func complete(emailOverride: String?) {
        session.signIn(email: (emailOverride ?? email).trimmingCharacters(in: .whitespaces), name: signupMode ? name : nil)
        onSignedIn?()
        dismiss()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("GENESYX").font(.gxCardHeading).tracking(2).foregroundStyle(GenesyxColor.foreground)
                Spacer().frame(height: 24)
                Text(signupMode ? "Create your account" : "Welcome back")
                    .font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground).multilineTextAlignment(.center)
                Spacer().frame(height: 8)
                Text(signupMode ? "Save your cycle, nutrition, and partner info securely."
                                : "Sign in to sync your journey across devices.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)

                Spacer().frame(height: 28)
                if signupMode {
                    field("Name", text: $name, placeholder: "Your name")
                    Spacer().frame(height: 16)
                }
                field("Email", text: $email, placeholder: "you@example.com", keyboard: .emailAddress)
                Spacer().frame(height: 16)
                field("Password", text: $password, secure: true)

                if let error {
                    Text(error).font(.gxBodySmall).foregroundStyle(GenesyxColor.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }

                Spacer().frame(height: 20)
                Button(action: submit) {
                    Text(submitting ? "Please wait…" : (signupMode ? "Create account" : "Sign in"))
                        .font(.gxLabel).frame(maxWidth: .infinity).frame(height: 48)
                        .background(GenesyxColor.primary).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(submitting ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(submitting)

                HStack { divider; Text("  OR  ").font(.gxEyebrow).foregroundStyle(GenesyxColor.mutedForeground); divider }
                    .padding(.vertical, 24)

                Button { complete(emailOverride: email.isEmpty ? "you@genesyx.app" : email) } label: {
                    Text("Continue with Google")
                        .font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 28)
                HStack(spacing: 0) {
                    Text(signupMode ? "Already have an account? " : "New here? ")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    Text(signupMode ? "Sign in" : "Create account")
                        .font(.gxBodySmall.weight(.semibold)).foregroundStyle(GenesyxColor.primary)
                        .onTapGesture { signupMode.toggle(); error = nil }
                }
                GxGhostButton(title: "Back to app") { dismiss() }
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24).padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .background(GenesyxColor.background)
    }

    private var divider: some View { Rectangle().fill(GenesyxColor.border).frame(height: 1) }

    private func field(_ label: String, text: Binding<String>, placeholder: String = "", secure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground)
            Group {
                if secure { SecureField(placeholder, text: text) }
                else { TextField(placeholder, text: text).keyboardType(keyboard).textInputAutocapitalization(.never).autocorrectionDisabled() }
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
            .onChange(of: text.wrappedValue) { _ in error = nil }
        }
    }
}
