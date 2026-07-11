import Foundation

/// Auth/session state. Local-first: works as a mock when no `AuthBackend` is provided (v1), and
/// routes through the backend (Supabase) when one is. Mirrors the Android `SessionRepository`.
@MainActor
final class SessionRepository: ObservableObject {

    @Published private(set) var isSignedIn = false
    @Published private(set) var email: String?
    @Published private(set) var displayName: String?

    private let auth: AuthBackend?

    /// Auth-transition hooks wired by `AppContainer`: wipe on-device health data on sign-out /
    /// account deletion, and rehydrate from the backend on sign-in. No-ops in isolation.
    var onClearLocalState: (() -> Void)?
    var onHydrate: (() async -> Void)?
    /// Mirrors a renamed display name to her `profiles` row.
    var onDisplayNameChanged: ((String) -> Void)?

    init(auth: AuthBackend? = nil) {
        self.auth = auth
        if auth?.currentUserId != nil { isSignedIn = true }
    }

    /// Unified entry used by the Auth screen. Calls the backend when present, then updates state.
    func authenticate(email: String, password: String, name: String?, signUp: Bool) async throws {
        guard let auth else {
            try requireMockIsAllowed()
            applySignIn(email: email, name: name)
            return
        }
        if signUp {
            try await auth.signUp(email: email, password: password)
            // With email confirmation required, sign-up returns a user but NO session. Marking her
            // signed in here would be a lie: every write would fail the server's auth check and
            // queue forever while the UI said everything was fine.
            guard auth.currentUserId != nil else { throw RemoteError.emailConfirmationRequired }
        } else {
            try await auth.signIn(email: email, password: password)
        }
        applySignIn(email: email, name: name)
    }

    /// Social sign-in (Google/Apple). Exchanges the provider ID token for a Supabase session.
    func signInWithSocial(provider: SocialProvider, idToken: String, accessToken: String?, nonce: String?, email: String?, name: String?) async throws {
        guard let auth else {
            try requireMockIsAllowed()
            applySignIn(email: email ?? "", name: name)
            return
        }
        try await auth.signInWithIdToken(provider: provider, idToken: idToken, accessToken: accessToken, nonce: nonce)
        applySignIn(email: email ?? "", name: name)
    }

    /// With no backend, "signing in" means accepting whatever was typed — no password is ever
    /// checked. That is fine for a local-only dev build and must never happen in a shipped one, so
    /// a Release build with no configured backend refuses to sign in rather than faking it.
    private func requireMockIsAllowed() throws {
        #if !DEBUG
        throw RemoteError.notConfigured
        #endif
    }

    #if DEBUG
    /// Local sign-in with no backend. Debug-only: it verifies nothing.
    func signIn(email: String, name: String?) {
        applySignIn(email: email, name: name)
    }
    #endif

    private func applySignIn(email: String, name: String?) {
        self.email = email
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = (trimmed?.isEmpty == false ? trimmed : String(email.prefix(while: { $0 != "@" })))
        self.isSignedIn = true
        // Any sign-in path: pull the signing-in user's data from the backend (no-op when local-only).
        if let onHydrate { Task { await onHydrate() } }
    }

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        onDisplayNameChanged?(trimmed)
    }

    func signOut() {
        isSignedIn = false
        email = nil
        displayName = nil
        if let auth { Task { try? await auth.signOut() } }
        // Wipe the previous user's on-device health data so a next sign-in starts clean.
        onClearLocalState?()
    }

    /// Permanently deletes the account via the backend, then clears local session state.
    /// With no backend (local-only), this just signs the user out. Throws if the remote
    /// deletion fails, so the UI can surface the error and leave the account intact.
    func deleteAccount() async throws {
        if let auth { try await auth.deleteAccount() }
        email = nil
        displayName = nil
        isSignedIn = false
        // Deletion succeeded — wipe the on-device health data too.
        onClearLocalState?()
    }
}
