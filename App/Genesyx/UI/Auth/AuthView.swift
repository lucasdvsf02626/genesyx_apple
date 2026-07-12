import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Email + password sign in / sign up, plus Sign in with Apple and Continue with Google.
/// Ported from the Android `AuthScreen`; presented as a sheet. Writes to `SessionRepository`.
/// Google is shown only when the GoogleSignIn package is linked; the token exchange happens
/// via Supabase once that backend is active (falls back to a local mock otherwise).
struct AuthView: View {

    @EnvironmentObject private var session: SessionRepository
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: (() -> Void)? = nil

    @State private var signupMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var currentNonce: String?

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
            } catch RemoteError.emailConfirmationRequired {
                self.error = "Almost there — check your inbox and confirm your email, then sign in."
            } catch {
                self.error = "Could not sign in. Please check your details and try again."
            }
            submitting = false
        }
    }

    // MARK: - Sign in with Apple

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                error = "Apple sign-in failed. Please try again."
                return
            }
            let fullName = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            Task {
                do {
                    try await session.signInWithSocial(
                        provider: .apple, idToken: idToken, accessToken: nil, nonce: currentNonce,
                        email: cred.email, name: fullName.isEmpty ? nil : fullName
                    )
                    onSignedIn?(); dismiss()
                } catch {
                    print("[AppleSignIn] Supabase exchange FAILED: \(error)")
                    self.error = "Couldn't complete Apple sign-in. Please try again."
                }
            }
        case .failure(let err):
            print("[AppleSignIn] SDK failed: \(err)")
            if (err as? ASAuthorizationError)?.code == .canceled { return }   // she backed out — not an error
            error = "Couldn't complete Apple sign-in. Please try again."
        }
    }

    // MARK: - Continue with Google

    #if canImport(GoogleSignIn)
    private func handleGoogle() {
        guard let root = Self.rootViewController() else { error = "Couldn't start Google sign-in."; return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: RemoteConfig.googleIOSClientID)
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
                print("[GoogleSignIn] SDK sign-in OK. email=\(result.user.profile?.email ?? "nil") hasIDToken=\(result.user.idToken != nil)")
                guard let idToken = result.user.idToken?.tokenString else {
                    error = "Couldn't complete Google sign-in. Please try again."; return
                }
                do {
                    try await session.signInWithSocial(
                        provider: .google, idToken: idToken,
                        accessToken: result.user.accessToken.tokenString, nonce: nil,
                        email: result.user.profile?.email, name: result.user.profile?.name
                    )
                } catch {
                    print("[GoogleSignIn] Supabase exchange FAILED: \(error)")
                    self.error = "Couldn't complete Google sign-in. Please try again."
                    return
                }
                onSignedIn?(); dismiss()
            } catch {
                print("[GoogleSignIn] SDK sign-in FAILED: \(error)")
                if (error as NSError).code == -5 { return }   // GIDSignInError.canceled — she backed out
                self.error = "Couldn't complete Google sign-in. Please try again."
            }
        }
    }

    /// The top-most presented controller — GoogleSignIn must present ON the visible sheet,
    /// not the window root (the root is already presenting AuthView, which would throw).
    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif

    // MARK: - Nonce helpers (Sign in with Apple)

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
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

                SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleApple)
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                #if canImport(GoogleSignIn)
                Spacer().frame(height: 12)
                Button(action: handleGoogle) {
                    Text("Continue with Google")
                        .font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                #endif

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
