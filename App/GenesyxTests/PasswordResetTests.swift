import XCTest
@testable import Genesyx

/// Password recovery for a woman who is signed OUT.
///
/// The mandatory authentication gate (H22) changed what a forgotten password costs. Before it,
/// private tabs mounted from `onboardingComplete` alone, so she kept using the app and the only
/// route to a reset — Profile → Change password — was reachable. After it, `RootRouting` sends a
/// signed-out user to `AuthView` and nowhere else, and Profile sits behind the very session she
/// cannot obtain. A forgotten password became a permanent lockout with no in-app way out.
///
/// `resetPassword()` reads the address off the live session, which is exactly what she does not
/// have. So these tests are about `sendPasswordReset(email:)` — the signed-out variant — and about
/// the two things it must NOT do: sign her in, or stay silent when it fails.
@MainActor
final class PasswordResetTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    /// Records the address the reset was actually addressed to. That is the whole point: the
    /// signed-out path must send to what she typed, and the signed-in path to her own account.
    private final class FakeResetAuth: AuthBackend {
        var userId: String?
        private(set) var resetEmails: [String] = []
        var resetError: Error?

        var currentUserId: String? { userId }
        func signUp(email: String, password: String) async throws { userId = "u1" }
        func signIn(email: String, password: String) async throws { userId = "u1" }
        func signOut() async throws { userId = nil }
        func resetPassword(email: String) async throws {
            if let resetError { throw resetError }
            resetEmails.append(email)
        }
    }

    private func signedOutRepository() async -> (SessionRepository, FakeResetAuth) {
        let auth = FakeResetAuth()
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        return (session, auth)
    }

    /// The lockout itself. She is at the mandatory gate with no session, types her address, and the
    /// reset must reach that address — there is no session email to fall back on.
    func testAForgottenPasswordCanBeSentWhileSignedOut() async throws {
        let (session, auth) = await signedOutRepository()
        XCTAssertEqual(session.state, .signedOut, "precondition: she is at the gate")
        XCTAssertNil(session.email, "precondition: no session means no address to read")

        try await session.sendPasswordReset(email: "ada@example.com")

        XCTAssertEqual(auth.resetEmails, ["ada@example.com"],
                       "the reset must be addressed to what she typed, not to a session that does not exist")
    }

    /// Asking for a reset must not be a way past the gate. The email is the credential, not the
    /// request for it, so state must be unchanged afterwards.
    func testAskingForAResetDoesNotSignHerIn() async throws {
        let (session, _) = await signedOutRepository()

        try await session.sendPasswordReset(email: "ada@example.com")

        XCTAssertEqual(session.state, .signedOut, "requesting a reset must never grant a session")
        XCTAssertFalse(session.isSignedIn)
        XCTAssertNil(session.email)
    }

    /// Profile's existing "Change password" must keep addressing HER account. It takes no input, so
    /// if the refactor let it read anything other than the live session's address it would email a
    /// reset link for one account to whoever's address leaked in.
    func testTheSignedInPathStillUsesHerOwnAddress() async throws {
        let auth = FakeResetAuth()
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        try await session.authenticate(email: "ada@example.com", password: "pw", name: nil, signUp: false)
        XCTAssertEqual(session.state, .signedIn, "precondition: signed in")

        try await session.resetPassword()

        XCTAssertEqual(auth.resetEmails, ["ada@example.com"],
                       "the signed-in route must address her own account")
    }

    /// A failure has to surface. Swallowing it leaves her looking at a confirmation for an email
    /// that was never sent — and she has no other route in, so she would simply wait.
    func testAFailedSendThrowsRatherThanReportingSuccess() async throws {
        let (session, auth) = await signedOutRepository()
        auth.resetError = RemoteError.notConfigured

        do {
            try await session.sendPasswordReset(email: "ada@example.com")
            XCTFail("a failed send must throw so the UI can tell her")
        } catch {}
    }

    /// No backend configured is the same contract: throw, do not pretend.
    func testAResetWithNoBackendThrows() async throws {
        let session = SessionRepository(store: makeStore(), auth: nil)
        await session.waitUntilResolved()

        do {
            try await session.sendPasswordReset(email: "ada@example.com")
            XCTFail("with no backend there is nothing to send, and the UI must be told")
        } catch {}
    }
}
