import XCTest
@testable import Genesyx

/// The expired/revoked-token half of the P0 authentication gate (H22).
///
/// `AuthGateUITests` drives the *missing*-session path: launch arguments put the app in
/// `signedOut` and the root is asserted to show mandatory login. That is a different path from
/// this one. Here the device holds a cached credential the server no longer honours — a refresh
/// token revoked from another device, a deleted account, a lapsed session — which is the case
/// that decides whether "signed in" can outlive the server's willingness to say so.
///
/// No Supabase, no network, no account: `AuthBackend` is injected, so the whole lifecycle is
/// driven from the fake.
@MainActor
final class SessionExpiryTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    /// Captures the observer `SessionRepository` installs, so a test can play the lifecycle
    /// events Supabase would emit. `validated` is answered separately from `currentUserId` on
    /// purpose — an expired cache is exactly the case where a user id is still present and the
    /// session is worthless.
    private final class FakeExpiringAuth: AuthBackend {
        var userId: String?
        var validated: AuthSessionSnapshot?
        private var observer: (@MainActor (AuthLifecycleEvent) -> Void)?

        var currentUserId: String? { userId }
        func signUp(email: String, password: String) async throws {}
        func signIn(email: String, password: String) async throws {}
        func signOut() async throws { userId = nil; validated = nil }
        func validatedSession() async -> AuthSessionSnapshot? { validated }
        func observeAuthState(_ handler: @escaping @MainActor (AuthLifecycleEvent) -> Void) {
            observer = handler
        }

        var isObserved: Bool { observer != nil }
        @MainActor func emit(_ event: AuthLifecycleEvent) { observer?(event) }
    }

    private func signedInRepository() async -> (SessionRepository, FakeExpiringAuth) {
        let auth = FakeExpiringAuth()
        auth.userId = "u1"
        auth.validated = AuthSessionSnapshot(userId: "u1")
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        return (session, auth)
    }

    /// The server revokes the token while she is using the app. She must be signed out, and the
    /// sign-out hook must fire — that hook is what drops the held notification destination and
    /// cancels the schedule, so a silent state change here leaves private routing armed.
    func testExpiredSessionSignsOutAndFiresTheBecameSignedOutHook() async {
        let (session, auth) = await signedInRepository()
        XCTAssertEqual(session.state, .signedIn, "precondition: a validated session is signed in")
        XCTAssertTrue(auth.isObserved, "the repository must subscribe to auth lifecycle events")

        var signedOutHookFired = false
        session.onBecameSignedOut = { signedOutHookFired = true }

        auth.emit(.sessionExpired)

        XCTAssertEqual(session.state, .signedOut, "an expired token must not leave her signed in")
        XCTAssertFalse(session.isSignedIn)
        XCTAssertTrue(signedOutHookFired, "onBecameSignedOut must fire so held private state is dropped")
    }

    /// After expiry the SDK still holds the dead session. Neither a refresh event nor the
    /// expired initial session may put her back inside.
    func testAnExpiredSessionCannotComeBackFromARefreshOrAnExpiredInitialSession() async {
        let (session, auth) = await signedInRepository()
        auth.emit(.sessionExpired)
        XCTAssertEqual(session.state, .signedOut)

        // `tokenRefreshed` only ever describes an already-live session. Treating it as a
        // credential would re-open the tabs on the strength of the very token that just lapsed.
        auth.emit(.tokenRefreshed(userId: "u1"))
        XCTAssertEqual(session.state, .signedOut, "a refresh event must not resurrect an expired session")

        // Supabase maps an expired cached session to a nil user id (`SupabaseBackend`), so this
        // is what the expired cache actually looks like when it arrives as an initial session.
        auth.emit(.initialSession(userId: nil))
        XCTAssertEqual(session.state, .signedOut, "an expired cached session must stay signed out")
        XCTAssertFalse(session.isSignedIn)
    }

    /// Cold launch holding a cached user whose token no longer validates. `currentUserId` is
    /// non-nil throughout — mounting private tabs off that alone is the defect this gate exists
    /// to prevent — so the repository must resolve to `signedOut`, never `signedIn`.
    func testLaunchWithAnExpiredCachedSessionNeverSignsIn() async {
        let auth = FakeExpiringAuth()
        auth.userId = "u1"
        auth.validated = nil

        let session = SessionRepository(store: makeStore(), auth: auth)
        XCTAssertEqual(session.state, .resolving, "private tabs must not mount while the token is unverified")

        await session.waitUntilResolved()

        XCTAssertEqual(session.state, .signedOut, "an unvalidated cached user is not a credential")
        XCTAssertFalse(session.isSignedIn)
        XCTAssertNotNil(auth.currentUserId, "the cached user is still present — validation, not its absence, is what decided this")
    }

    /// A genuine new sign-in after an expiry works normally. Without this the gate could be
    /// "correct" by refusing everything.
    func testAFreshSignInAfterExpiryReachesSignedIn() async {
        let (session, auth) = await signedInRepository()
        auth.emit(.sessionExpired)
        XCTAssertEqual(session.state, .signedOut)

        auth.emit(.signedIn(userId: "u1"))
        XCTAssertEqual(session.state, .signedIn, "a real new session must still be able to sign her in")
        XCTAssertTrue(session.isSignedIn)
    }

    // MARK: - Sign in with Apple revocation

    private func appleSignedIn(_ session: SessionRepository, _ auth: FakeExpiringAuth) async throws {
        auth.userId = "apple-user"
        try await session.signInWithSocial(
            provider: .apple, idToken: "id-token", accessToken: nil,
            nonce: nil, email: "ada@example.com", name: "Ada"
        )
    }

    /// She revokes this app under Settings → Apple ID → Sign in with Apple. Apple's credential is
    /// gone, but the Supabase refresh token is independent of it and stays valid, and no auth
    /// lifecycle event fires. Without this handler she remains signed in indefinitely and the
    /// revocation means nothing.
    func testRevokingAppleSignInEndsAnAppleSession() async throws {
        let auth = FakeExpiringAuth()
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        try await appleSignedIn(session, auth)
        XCTAssertEqual(session.state, .signedIn, "precondition: signed in through Apple")

        var signedOutHookFired = false
        session.onBecameSignedOut = { signedOutHookFired = true }

        session.handleAppleCredentialRevoked()

        XCTAssertEqual(session.state, .signedOut, "a revoked Apple credential must not leave her signed in")
        XCTAssertFalse(session.isSignedIn)
        XCTAssertTrue(signedOutHookFired, "onBecameSignedOut must fire so held private state is dropped")
    }

    /// The notification is app-wide, not per-session. A woman who used Apple once, signed out, and
    /// signed back in with her email and password must keep that session when she later tidies up
    /// her Apple ID settings — otherwise the fix above throws out sessions Apple never governed.
    func testRevokingAppleSignInLeavesAnEmailSessionAlone() async throws {
        let auth = FakeExpiringAuth()
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        try await appleSignedIn(session, auth)
        session.signOut()

        auth.userId = "email-user"
        try await session.authenticate(
            email: "ada@example.com", password: "pw", name: nil, signUp: false
        )
        XCTAssertEqual(session.state, .signedIn, "precondition: signed in with email and password")

        session.handleAppleCredentialRevoked()

        XCTAssertEqual(session.state, .signedIn, "an Apple revocation must not end an unrelated email session")
        XCTAssertTrue(session.isSignedIn)
    }

    /// The handler almost always runs against a session restored from a cached token, not a fresh
    /// `applySignIn`, so which provider she used has to outlive the process. Held in memory it
    /// would be lost on the first relaunch and revocation would quietly stop working — the failure
    /// nobody would notice, because it looks exactly like staying signed in.
    func testAnAppleSessionIsStillRevocableAfterARelaunch() async throws {
        let store = makeStore()
        let auth = FakeExpiringAuth()
        let first = SessionRepository(store: store, auth: auth)
        await first.waitUntilResolved()
        try await appleSignedIn(first, auth)

        // Relaunch: same device store, a validated cached session, a brand-new repository.
        auth.validated = AuthSessionSnapshot(userId: "apple-user")
        let relaunched = SessionRepository(store: store, auth: auth)
        await relaunched.waitUntilResolved()
        XCTAssertEqual(relaunched.state, .signedIn, "precondition: the cached Apple session restored")

        relaunched.handleAppleCredentialRevoked()

        XCTAssertEqual(relaunched.state, .signedOut, "the provider must survive relaunch or revocation stops working")
    }
}
