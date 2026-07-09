import Foundation

/// Auth/session state. Local-first: works as a mock when no `AuthBackend` is provided (v1), and
/// routes through the backend (Supabase) when one is. Mirrors the Android `SessionRepository`.
@MainActor
final class SessionRepository: ObservableObject {

    @Published private(set) var isSignedIn = false
    @Published private(set) var email: String?
    @Published private(set) var displayName: String?

    private let auth: AuthBackend?

    init(auth: AuthBackend? = nil) {
        self.auth = auth
        if auth?.currentUserId != nil { isSignedIn = true }
    }

    /// Unified entry used by the Auth screen. Calls the backend when present, then updates state.
    func authenticate(email: String, password: String, name: String?, signUp: Bool) async throws {
        if let auth {
            if signUp { try await auth.signUp(email: email, password: password) }
            else { try await auth.signIn(email: email, password: password) }
        }
        applySignIn(email: email, name: name)
    }

    /// Local/mock sign-in (no backend) — also used by the mock "Continue with Google".
    func signIn(email: String, name: String?) {
        applySignIn(email: email, name: name)
    }

    /// Social sign-in (Google/Apple). Exchanges the provider ID token for a Supabase session
    /// when a backend is present, then updates local state. Works as a local mock otherwise.
    func signInWithSocial(provider: SocialProvider, idToken: String, accessToken: String?, nonce: String?, email: String?, name: String?) async throws {
        if let auth {
            try await auth.signInWithIdToken(provider: provider, idToken: idToken, accessToken: accessToken, nonce: nonce)
        }
        applySignIn(email: email ?? "", name: name)
    }

    private func applySignIn(email: String, name: String?) {
        self.email = email
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = (trimmed?.isEmpty == false ? trimmed : String(email.prefix(while: { $0 != "@" })))
        self.isSignedIn = true
    }

    func updateDisplayName(_ name: String) {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { displayName = name }
    }

    func signOut() {
        isSignedIn = false
        email = nil
        displayName = nil
        if let auth { Task { try? await auth.signOut() } }
    }

    /// Permanently deletes the account via the backend, then clears local session state.
    /// With no backend (local-only), this just signs the user out. Throws if the remote
    /// deletion fails, so the UI can surface the error and leave the account intact.
    func deleteAccount() async throws {
        if let auth { try await auth.deleteAccount() }
        email = nil
        displayName = nil
        isSignedIn = false
    }
}
