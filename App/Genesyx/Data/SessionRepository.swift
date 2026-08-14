import Foundation

/// Auth/session state. Local-first: works as a mock when no `AuthBackend` is provided (DEBUG),
/// and routes through the backend (Supabase) when one is. Mirrors the Android `SessionRepository`.
///
/// `state` is the credential the root view reads. `isSignedIn` is kept as a derived published
/// flag so existing screens and tests do not have to change. `onboardingComplete` is not read
/// here — it is a progress flag, not a session.
@MainActor
final class SessionRepository: ObservableObject {

    @Published private(set) var state: SessionAuthState
    @Published private(set) var isSignedIn = false
    @Published private(set) var email: String?
    @Published private(set) var displayName: String?

    private let auth: AuthBackend?
    private let store: LocalStore
    private let emailKey = "session_email"
    private let nameKey = "session_display_name"
    /// Who the store's contents belong to. Outlives sign-out on purpose — see `applySignIn`.
    private let identityKey = "session_identity"
    private let namePendingKey = "session_name_pending"
    /// DEBUG local-only: persist a mock session so a keep-store relaunch can restore it. Never
    /// consulted in Release — Release without a backend fails closed at the root.
    private let mockSignedInKey = "session_mock_signed_in"
    private var bootstrap: Task<Void, Never>?

    /// Auth-transition hooks wired by `AppContainer`: wipe on-device health data on sign-out /
    /// account deletion, and rehydrate from the backend on sign-in. No-ops in isolation.
    var onClearLocalState: (() -> Void)?
    var onHydrate: (() async -> Void)?
    /// Pushes her name to her `profiles` row. Returns whether the server actually took it, because
    /// that answer is what clears the owed write — a closure returning `Void` cannot distinguish a
    /// write that landed from one that threw, which is how the name came to be lost in the first
    /// place. No-op (and unpushed) when local-only.
    var onPushDisplayName: ((String) async -> Bool)?
    /// Reads the name back off her `profiles` row. Without it the name was write-only: a reinstall
    /// or a second device had nothing to restore from and fell through to the part of her address
    /// before the @, so a woman who set up the app on a new phone was greeted as "ada".
    var onFetchDisplayName: (() async -> String?)?
    /// Fired the moment `state` leaves `.signedIn`. Used to cancel notifications and drop held
    /// private destinations without waiting for a Combine hop.
    var onBecameSignedOut: (() -> Void)?

    /// A rename the server has not accepted yet, persisted so it survives the relaunch. Same
    /// contract as `PreferencesRepository.pendingPush`: the local write wins immediately and the
    /// server is caught up later, on foreground, on reconnect or on the next sign-in.
    private var pendingNamePush: Bool {
        didSet { store.setBool(pendingNamePush, forKey: namePendingKey) }
    }

    init(store: LocalStore, auth: AuthBackend? = nil) {
        self.store = store
        self.auth = auth
        self.pendingNamePush = store.bool(forKey: namePendingKey, default: false)
        if auth != nil {
            // Never mount private tabs off `currentUser` alone. A cached user can be expired
            // or revoked; the root stays on `.resolving` until `validatedSession` answers.
            self.state = .resolving
            self.isSignedIn = false
            self.bootstrap = Task { [weak self] in
                await self?.bootstrapAuth()
            }
        } else {
            #if DEBUG
            if store.bool(forKey: mockSignedInKey, default: false) {
                self.email = store.string(forKey: emailKey)
                self.displayName = store.string(forKey: nameKey)
                self.state = .signedIn
                self.isSignedIn = true
            } else {
                self.state = .signedOut
                self.isSignedIn = false
            }
            #else
            self.state = .signedOut
            self.isSignedIn = false
            #endif
        }
    }

    /// Tests wait here so they never assert against `.resolving`.
    func waitUntilResolved() async {
        await bootstrap?.value
    }

    private func setState(_ new: SessionAuthState) {
        let wasSignedIn = isSignedIn
        state = new
        isSignedIn = new == .signedIn
        if wasSignedIn && !isSignedIn {
            onBecameSignedOut?()
        }
    }

    private func bootstrapAuth() async {
        guard let auth else {
            setState(.signedOut)
            return
        }
        if let snapshot = await auth.validatedSession() {
            restoreSignedIn(userId: snapshot.userId)
        } else {
            setState(.signedOut)
        }
        auth.observeAuthState { [weak self] event in
            self?.handleAuthEvent(event)
        }
    }

    private func handleAuthEvent(_ event: AuthLifecycleEvent) {
        switch event {
        case .initialSession(let userId):
            // Bootstrap already decided from `validatedSession`. An expired initial session
            // must not flip a signed-out user back on.
            if let userId, state == .signedOut {
                restoreSignedIn(userId: userId)
            } else if userId == nil, state == .signedIn {
                setState(.signedOut)
            }
        case .signedIn(let userId):
            if state != .signedIn { restoreSignedIn(userId: userId) }
        case .signedOut, .sessionExpired:
            if state == .signedIn { setState(.signedOut) }
        case .tokenRefreshed:
            break
        }
    }

    /// Restore from a validated session without treating it as a fresh typed sign-in.
    private func restoreSignedIn(userId: String) {
        let previous = store.string(forKey: identityKey)
        if let previous, previous != userId {
            onClearLocalState?()
            pendingNamePush = false
        }
        store.setString(userId, forKey: identityKey)
        email = store.string(forKey: emailKey)
        displayName = store.string(forKey: nameKey)
        setState(.signedIn)
        if let onHydrate { Task { await onHydrate() } }
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
        // After sign-out the private tabs are gone. Writes can still land locally from a leftover
        // repository handle (tests, a race). Those writes belong to whoever last held the session;
        // handing them to a different account on hydrate would file one person's cycle and logs
        // into another person's history.
        //
        // Only when there *was* a previous owner. Onboarding runs before the account exists, so a
        // device that has never held a session is carrying her own quiz answers, cycle and logs into
        // her first sign-in — wiping those would throw away everything she just entered.
        if let previous, previous != identity {
            onClearLocalState?()
            // A rename the last account never managed to push is hers, not the incoming user's.
            // Left set, the next drain would write her name into their row.
            pendingNamePush = false
        }
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
        // Only a name she actually typed is owed to the server, and sign-up is the one path that
        // asks for one — before this, the name she registered under never left the device, so her
        // partner saw the word "Partner". The two fallbacks must never be pushed: on a reinstall
        // `resolved` is the email prefix, and sending that would overwrite the real name already on
        // her row with "lucas". Only ever set here, never cleared, so a rename still owed from
        // before a re-sign-in is not dropped by the sign-in itself.
        if typed?.isEmpty == false { pendingNamePush = true }

        #if DEBUG
        if auth == nil { store.setBool(true, forKey: mockSignedInKey) }
        #endif
        setState(.signedIn)
        // Any sign-in path: pull the signing-in user's data from the backend (no-op when local-only).
        if let onHydrate { Task { await onHydrate() } }
    }

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        store.setString(trimmed, forKey: nameKey)
        pendingNamePush = true
        Task { await drainPendingName() }
    }

    /// Retry the rename the server never received. Called on sign-in, on foreground and on
    /// reconnect, alongside every other owed write.
    func drainPendingName() async {
        guard pendingNamePush, let onPushDisplayName, let name = displayName else { return }
        guard await onPushDisplayName(name) else { return }
        // Unless she renamed herself again while that was in flight, in which case the newer name
        // is still owed and this drain has no claim to clear it.
        if displayName == name { pendingNamePush = false }
    }

    /// Push what is owed, then pull — the same order every other repository uses, and for the same
    /// reason: a rename this device has not managed to send yet must never be overwritten by the
    /// very copy it is on its way to replace. A row with no name at all leaves hers alone, so a
    /// missing `display_name` cannot blank the name she is looking at.
    func refreshDisplayName() async {
        await drainPendingName()
        guard !pendingNamePush, let onFetchDisplayName else { return }
        guard let remote = await onFetchDisplayName(), !remote.isEmpty else { return }
        displayName = remote
        store.setString(remote, forKey: nameKey)
    }

    func signOut() {
        setState(.signedOut)
        email = nil
        displayName = nil
        store.remove(forKey: emailKey)
        store.remove(forKey: nameKey)
        #if DEBUG
        store.setBool(false, forKey: mockSignedInKey)
        #endif
        // The owed write outlives the session that owed it. Left set, the next account's first
        // drain would push the previous user's name — which is now `nil` — or, worse, theirs.
        pendingNamePush = false
        store.remove(forKey: namePendingKey)
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
        setState(.signedOut)
        store.remove(forKey: emailKey)
        store.remove(forKey: nameKey)
        #if DEBUG
        store.setBool(false, forKey: mockSignedInKey)
        #endif
        // Both of these for the same reasons `signOut()` gives, and deletion is the one path that
        // used to get them backwards.
        //
        // The owed rename is the deleted account's, not the next account's. Left set, the next
        // sign-in resolves a name from the only thing it still has — the email prefix — and drains
        // *that* onto the incoming user's row, overwriting the real name she registered under.
        //
        // The identity key outlives the account deliberately. Removing it made `applySignIn` read
        // `previous == nil`, which is how a device that has never held a session looks, so the
        // owner-change wipe was skipped and anything logged between the deletion and the next
        // sign-in was filed as the new user's — and pushed to her rows.
        pendingNamePush = false
        store.remove(forKey: namePendingKey)
        // Deletion succeeded — wipe the on-device health data too.
        onClearLocalState?()
    }
}
