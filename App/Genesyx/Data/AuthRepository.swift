import Foundation
import Combine

/// iOS counterpart of the Android `AuthRepository` (`auth/AuthRepository_V2.kt`).
///
/// ## What this is
/// A single, intention-revealing auth API surface for the whole app — `signInWithPassword`,
/// `signUp`, `signInWithGoogle`, `signInWithApple`, `signOut`, `deleteAccount`, `resetPassword`,
/// `resendConfirmation` — matching the Android repository method-for-method (plus the two
/// Apple/iOS-only additions). It is the place a screen or a coordinator asks "sign her in" without
/// caring which backend answers.
///
/// ## How it maps to Android
/// | Android (`AuthRepository_V2.kt`)                | iOS                                        |
/// |-------------------------------------------------|--------------------------------------------|
/// | `authService: AuthService`                      | `AuthBackend` (held by `SessionRepository`)|
/// | `session: SessionRepository`                    | `SessionRepository` (injected here)        |
/// | `profile/cycle/dailyLog/phRepository.refresh()` | `SessionRepository.onHydrate` → `AppContainer.hydrate()` |
/// | `database.clearAllTables()`                     | `SessionRepository.onClearLocalState` → `AppContainer.clearLocalState()` |
/// | `DataResult<Unit>` (Success/Error/Loading)      | Swift `async throws` (throw = Error)       |
/// | `StateFlow<Boolean> isSignedIn`                 | `@Published private(set) var isSignedIn`   |
/// | private `persist(result, op)`                   | `SessionRepository.applySignIn` (fires hydrate) |
///
/// ## Why it delegates instead of re-implementing
/// On iOS the coordinator role Android splits across `AuthRepository` + `SessionRepository` is
/// already carried end-to-end by `SessionRepository` (it owns the `AuthBackend`, applies sign-in,
/// and fires the hydrate/clear hooks wired in `AppContainer`). Re-implementing that here would mean
/// two objects owning "am I signed in?" — a split-brain bug waiting to happen. So this type holds no
/// duplicate state: it mirrors `SessionRepository`'s `isSignedIn` and forwards every call to it. That
/// gives the app the same tidy Android-style facade **without** a second source of truth.
///
/// `SessionRepository` remains the object injected into the SwiftUI environment and the live
/// coordinator. Use this facade wherever you'd prefer the Android-shaped API.
@MainActor
final class AuthRepository: ObservableObject {

    private let session: SessionRepository

    /// Mirrors `SessionRepository.isSignedIn` (Android `isSignedIn: StateFlow<Boolean>`).
    @Published private(set) var isSignedIn: Bool

    init(session: SessionRepository) {
        self.session = session
        self.isSignedIn = session.isSignedIn
        // Keep this facade's published flag in lock-step with the single source of truth, so a view
        // observing either object sees the same value at the same time.
        session.$isSignedIn.assign(to: &$isSignedIn)
    }

    // MARK: - Email + password

    /// Android `signInWithPassword(email, password): DataResult<Unit>`.
    func signInWithPassword(email: String, password: String) async throws {
        try await session.authenticate(email: email, password: password, name: nil, signUp: false)
    }

    /// Android `signUp(email, password, name): DataResult<Unit>`.
    /// Throws `RemoteError.emailConfirmationRequired` when the project withholds the session pending
    /// email confirmation — she is NOT signed in, and the UI offers `resendConfirmation`.
    func signUp(email: String, password: String, name: String?) async throws {
        try await session.authenticate(email: email, password: password, name: name, signUp: true)
    }

    // MARK: - Social

    /// Android `signInWithGoogle(idToken): DataResult<Unit>` (iOS also forwards the access token,
    /// which supabase-swift accepts for the Google OIDC exchange).
    func signInWithGoogle(idToken: String, accessToken: String?, email: String?, name: String?) async throws {
        try await session.signInWithSocial(
            provider: .google, idToken: idToken, accessToken: accessToken, nonce: nil,
            email: email, name: name)
    }

    /// iOS-only: Sign in with Apple (nonce + SHA256 handshake happens in `AuthView`; the raw nonce is
    /// passed through for Supabase to verify). No Android equivalent — Android has no Apple button.
    func signInWithApple(idToken: String, nonce: String?, email: String?, name: String?) async throws {
        try await session.signInWithSocial(
            provider: .apple, idToken: idToken, accessToken: nil, nonce: nonce,
            email: email, name: name)
    }

    // MARK: - Session lifecycle

    /// Android `signOut()`. Clears the session and wipes on-device health data (via the hooks
    /// `SessionRepository` fires into `AppContainer`).
    func signOut() {
        session.signOut()
    }

    /// Android `deleteAccount(): DataResult<Unit>` — remote delete, then local wipe. Throws if the
    /// remote deletion fails, leaving the account intact so the UI can surface the error.
    func deleteAccount() async throws {
        try await session.deleteAccount()
    }

    // MARK: - Password + confirmation (iOS additions)

    /// Emails a password-reset link to the signed-in account. Throws with no backend / no email.
    func resetPassword() async throws {
        try await session.resetPassword()
    }

    /// Re-sends the sign-up confirmation email. Used right after a sign-up whose session was withheld
    /// pending confirmation, so the address is passed in rather than read from the (absent) session.
    func resendConfirmation(email: String) async throws {
        try await session.resendConfirmation(email: email)
    }

    // MARK: - Local (debug) sign-in

    #if DEBUG
    /// Android `signIn(email, name)` — local, verifies nothing. Debug-only on iOS: a Release build
    /// with no configured backend refuses to fake a sign-in (see `SessionRepository`).
    func signIn(email: String, name: String?) {
        session.signIn(email: email, name: name)
    }
    #endif
}
