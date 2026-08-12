import Foundation

/// Auth/session state. Local-first: works as a mock when no `AuthBackend` is provided (v1), and
/// routes through the backend (Supabase) when one is. Mirrors the Android `SessionRepository`.
@MainActor
final class SessionRepository: ObservableObject {

    @Published private(set) var isSignedIn = false
    @Published private(set) var email: String?
    @Published private(set) var displayName: String?

    private let auth: AuthBackend?
    private let store: LocalStore
    private let emailKey = "session_email"
    private let nameKey = "session_display_name"
    /// Who the store's contents belong to. Outlives sign-out on purpose — see `applySignIn`.
    private let identityKey = "session_identity"

    /// Auth-transition hooks wired by `AppContainer`: wipe on-device health data on sign-out /
    /// account deletion, and rehydrate from the backend on sign-in. No-ops in isolation.
    var onClearLocalState: (() -> Void)?
    var onHydrate: (() async -> Void)?
    /// Mirrors a renamed display name to her `profiles` row.
    var onDisplayNameChanged: ((String) -> Void)?

    init(store: LocalStore, auth: AuthBackend? = nil) {
        self.store = store
        self.auth = auth
        // The Supabase SDK restores the session itself, but her name and address lived only in
        // memory — so every relaunch greeted a signed-in user as "Guest", and Personal Details
        // opened prefilled with the word "Guest" ready to be saved over her real name.
        if auth?.currentUserId != nil {
            isSignedIn = true
            email = store.string(forKey: emailKey)
            displayName = store.string(forKey: nameKey)
        }
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
        let identity = auth?.currentUserId ?? email
        let previous = store.string(forKey: identityKey)
        // Sign-out wipes, but the app stays usable signed out — onboarding does not re-run, so the
        // tabs are still there and every write queues. Whatever was logged in that window belongs
        // to whoever last held the session; handing it to a different account on hydrate would file
        // one person's cycle and logs into another person's history.
        //
        // Only when there *was* a previous owner. Onboarding runs before the account exists, so a
        // device that has never held a session is carrying her own quiz answers, cycle and logs into
        // her first sign-in — wiping those would throw away everything she just entered.
        if let previous, previous != identity { onClearLocalState?() }
        let sameUser = previous == identity
        store.setString(identity, forKey: identityKey)

        self.email = email
        store.setString(email, forKey: emailKey)
        // Sign-in never asks for a name, so falling straight through to the address would rename
        // her on every sign-in. Her own name wins where we still hold it for this account.
        let typed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remembered = sameUser ? store.string(forKey: nameKey) : nil
        let resolved = (typed?.isEmpty == false ? typed! : nil)
            ?? remembered
            ?? String(email.prefix(while: { $0 != "@" }))
        self.displayName = resolved
        store.setString(resolved, forKey: nameKey)

        self.isSignedIn = true
        // Any sign-in path: pull the signing-in user's data from the backend (no-op when local-only).
        if let onHydrate { Task { await onHydrate() } }
    }

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        store.setString(trimmed, forKey: nameKey)
        onDisplayNameChanged?(trimmed)
    }

    func signOut() {
        isSignedIn = false
        email = nil
        displayName = nil
        store.remove(forKey: emailKey)
        store.remove(forKey: nameKey)
        if let auth { Task { try? await auth.signOut() } }
        // Wipe the previous user's on-device health data so a next sign-in starts clean.
        onClearLocalState?()
    }

    /// Emails a password-reset link to the signed-in account. Throws if there's no backend or no
    /// known email, so the UI can tell her instead of silently doing nothing.
    func resetPassword() async throws {
        guard let auth, let email, !email.isEmpty else { throw RemoteError.notConfigured }
        try await auth.resetPassword(email: email)
    }

    /// Re-sends the sign-up confirmation email. Used right after a sign-up whose session was
    /// withheld pending confirmation — she isn't signed in yet, so the address is passed in rather
    /// than read from `email`. Throws if there's no backend, so the UI can say so.
    func resendConfirmation(email: String) async throws {
        guard let auth, !email.isEmpty else { throw RemoteError.notConfigured }
        try await auth.resendConfirmation(email: email)
    }

    /// Permanently deletes the account via the backend, then clears local session state.
    /// With no backend (local-only), this just signs the user out. Throws if the remote
    /// deletion fails, so the UI can surface the error and leave the account intact.
    func deleteAccount() async throws {
        if let auth { try await auth.deleteAccount() }
        email = nil
        displayName = nil
        isSignedIn = false
        store.remove(forKey: emailKey)
        store.remove(forKey: nameKey)
        store.remove(forKey: identityKey)
        // Deletion succeeded — wipe the on-device health data too.
        onClearLocalState?()
    }
}
