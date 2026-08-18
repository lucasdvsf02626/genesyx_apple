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

        /// Recovery links redeemed, and passwords actually written. Recorded rather than counted
        /// so a test can prove the NEW password reached the backend — a flow that reports success
        /// without writing is the failure mode that matters here.
        private(set) var redeemedLinks: [URL] = []
        private(set) var updatedPasswords: [String] = []
        var recoveryError: Error?
        var updateError: Error?

        var currentUserId: String? { userId }
        func signUp(email: String, password: String) async throws { userId = "u1" }
        func signIn(email: String, password: String) async throws { userId = "u1" }
        func signOut() async throws { userId = nil }
        func resetPassword(email: String) async throws {
            if let resetError { throw resetError }
            resetEmails.append(email)
        }
        /// Mirrors the real thing: a successful redemption leaves her holding a session.
        func completePasswordRecovery(url: URL) async throws {
            if let recoveryError { throw recoveryError }
            redeemedLinks.append(url)
            userId = "u1"
        }
        func updatePassword(_ newPassword: String) async throws {
            if let updateError { throw updateError }
            updatedPasswords.append(newPassword)
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

    // MARK: - Coming back from the email

    private let link = URL(string: "genesyx://reset-password?code=abc123")!

    /// The link redeems, and she is held in recovery rather than released into the app.
    func testRedeemingTheLinkHoldsHerOnTheResetScreen() async throws {
        let (session, auth) = await signedOutRepository()
        XCTAssertFalse(session.passwordRecoveryActive, "precondition: not recovering")

        try await session.beginPasswordRecovery(url: link)

        XCTAssertEqual(auth.redeemedLinks, [link], "the link must be handed to the backend")
        XCTAssertTrue(session.passwordRecoveryActive,
                      "the redeemed session must not release her into the app")
    }

    /// An expired or already-used link must not leave the flag raised. If it did she would sit on
    /// a reset screen with no session behind it, and every password she typed would fail.
    func testAnExpiredLinkLeavesNoRecoveryInProgress() async throws {
        let (session, auth) = await signedOutRepository()
        auth.recoveryError = RemoteError.notAuthenticated

        do {
            try await session.beginPasswordRecovery(url: link)
            XCTFail("an expired link must throw so the UI can say so")
        } catch {}

        XCTAssertFalse(session.passwordRecoveryActive,
                       "a failed redemption must not strand her mid-recovery")
        XCTAssertFalse(session.isSignedIn, "a failed link must never grant a session")
    }

    /// The whole point: the new password reaches the backend, and she is then signed out so she
    /// has to prove it works. Staying signed in would leave other sessions alive after a reset.
    func testSettingANewPasswordWritesItAndReturnsHerToSignIn() async throws {
        let (session, auth) = await signedOutRepository()
        try await session.beginPasswordRecovery(url: link)

        try await session.completePasswordRecovery(newPassword: "a-new-password")

        XCTAssertEqual(auth.updatedPasswords, ["a-new-password"],
                       "the password she chose must be the one written")
        XCTAssertFalse(session.passwordRecoveryActive, "recovery is over")
        XCTAssertEqual(session.state, .signedOut, "a reset must end at the sign-in screen")
        await assertBackendSignedOut(auth, "the recovery session must not outlive the reset")
    }

    /// A failed write must not report success or drop the recovery. She should be able to try
    /// again on the same link rather than be told to request another.
    func testAFailedPasswordWriteKeepsHerInRecovery() async throws {
        let (session, auth) = await signedOutRepository()
        try await session.beginPasswordRecovery(url: link)
        auth.updateError = RemoteError.notAuthenticated

        do {
            try await session.completePasswordRecovery(newPassword: "a-new-password")
            XCTFail("a failed write must throw rather than claim the password changed")
        } catch {}

        XCTAssertTrue(session.passwordRecoveryActive, "she should be able to try again")
        XCTAssertEqual(auth.updatedPasswords, [], "nothing was written")
    }

    /// Backing out must discard the session the link created. Otherwise "Cancel" is a way into the
    /// app on a link she never completed.
    ///
    /// Asserted at the BACKEND rather than on `session.state`. The repository is already
    /// `.signedOut` here (the fake does not drive the auth observer the way Supabase does), so
    /// checking state alone would pass even if the redeemed token were left alive on the client —
    /// which is the thing that would actually be dangerous.
    func testCancellingDiscardsTheSessionTheLinkCreated() async throws {
        let (session, auth) = await signedOutRepository()
        try await session.beginPasswordRecovery(url: link)
        XCTAssertEqual(auth.currentUserId, "u1", "precondition: redemption produced a session")

        session.cancelPasswordRecovery()

        XCTAssertFalse(session.passwordRecoveryActive)
        XCTAssertEqual(session.state, .signedOut, "cancelling must not leave her signed in")
        await assertBackendSignedOut(auth, "cancelling must revoke the token the link minted")
    }

    /// `signOut()` hands the backend call to a detached task, so the revocation lands a hop later.
    /// Polled rather than slept on, so the test is neither flaky nor artificially slow.
    private func assertBackendSignedOut(
        _ auth: FakeResetAuth, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        for _ in 0..<50 {
            if auth.currentUserId == nil { return }
            await Task.yield()
        }
        XCTFail(message, file: file, line: line)
    }

    /// With no backend there is nothing to redeem against, and a silent success would show her a
    /// password form that could never save.
    func testRecoveryWithNoBackendThrows() async throws {
        let session = SessionRepository(store: makeStore(), auth: nil)
        await session.waitUntilResolved()

        do {
            try await session.beginPasswordRecovery(url: link)
            XCTFail("with no backend there is nothing to redeem")
        } catch {}
        XCTAssertFalse(session.passwordRecoveryActive)
    }

    // MARK: - In-app change (signed in, no email)

    /// The in-app "Change password" writes the new password on the live session and — unlike a
    /// recovery — leaves her signed in. She chose to change it from inside a session we already
    /// trust; dropping her to the sign-in screen for a routine change would be hostile.
    func testChangingPasswordWhileSignedInWritesItAndKeepsHerSignedIn() async throws {
        let auth = FakeResetAuth()
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        try await session.authenticate(email: "ada@example.com", password: "old-password", name: nil, signUp: false)
        XCTAssertEqual(session.state, .signedIn, "precondition: signed in")

        try await session.changePassword("a-new-password")

        XCTAssertEqual(auth.updatedPasswords, ["a-new-password"], "the chosen password must be written")
        XCTAssertEqual(auth.resetEmails, [], "an in-app change must not send an email")
        XCTAssertEqual(session.state, .signedIn, "a voluntary change must not sign her out")
        XCTAssertEqual(auth.currentUserId, "u1", "her session must survive the change")
    }

    /// A failed write must surface and must not touch her session, so the sheet can show the error
    /// inline and she stays exactly where she was.
    func testAFailedInAppChangeThrowsAndLeavesHerSignedIn() async throws {
        let auth = FakeResetAuth()
        let session = SessionRepository(store: makeStore(), auth: auth)
        await session.waitUntilResolved()
        try await session.authenticate(email: "ada@example.com", password: "old-password", name: nil, signUp: false)
        auth.updateError = RemoteError.notAuthenticated

        do {
            try await session.changePassword("a-new-password")
            XCTFail("a failed write must throw so the sheet can show it")
        } catch {}

        XCTAssertEqual(auth.updatedPasswords, [], "nothing was written")
        XCTAssertEqual(session.state, .signedIn, "a failed change must not sign her out")
    }

    /// With no backend there is nothing to write, and a silent success would tell her a password
    /// changed that never did.
    func testAnInAppChangeWithNoBackendThrows() async throws {
        let session = SessionRepository(store: makeStore(), auth: nil)
        await session.waitUntilResolved()

        do {
            try await session.changePassword("a-new-password")
            XCTFail("with no backend there is nothing to write, and the UI must be told")
        } catch {}
    }

    // MARK: - The rule for the new password

    func testAShortPasswordIsRejected() {
        XCTAssertEqual(NewPasswordRule.problem(password: "short", confirmation: "short"),
                       "Password must be at least 8 characters")
    }

    /// 72 is the bcrypt input ceiling. Anything past it is silently truncated by the hasher, so a
    /// password accepted here could later be matched by a different, shorter string.
    func testAnOverlongPasswordIsRejected() {
        let tooLong = String(repeating: "a", count: 73)
        XCTAssertEqual(NewPasswordRule.problem(password: tooLong, confirmation: tooLong),
                       "Password is too long")
        let atTheLimit = String(repeating: "a", count: 72)
        XCTAssertNil(NewPasswordRule.problem(password: atTheLimit, confirmation: atTheLimit),
                     "72 itself must be allowed — the boundary is inclusive")
    }

    func testAMismatchIsRejected() {
        XCTAssertEqual(NewPasswordRule.problem(password: "correct-horse", confirmation: "correct-hors"),
                       "Those two passwords don't match")
    }

    /// An empty confirmation is its own message. Calling it a mismatch would accuse her of a typo
    /// in a field she has not started filling in.
    func testAnEmptyConfirmationAsksHerToConfirmRatherThanCallingItAMismatch() {
        XCTAssertEqual(NewPasswordRule.problem(password: "correct-horse", confirmation: ""),
                       "Type your new password again to confirm")
    }

    /// The length rule is checked before the match rule, so a woman typing two identical short
    /// passwords is told the real problem rather than being told they match and then rejected.
    func testTheLengthComplaintComesBeforeTheMatchComplaint() {
        XCTAssertEqual(NewPasswordRule.problem(password: "abc", confirmation: "xyz"),
                       "Password must be at least 8 characters")
    }

    func testAValidMatchingPairPasses() {
        XCTAssertNil(NewPasswordRule.problem(password: "a-new-password", confirmation: "a-new-password"))
    }

    /// The rule must not drift from the sign-in screen's. If this screen accepted something
    /// `AuthView.submit` rejects, she would set a password she could not then sign in with.
    func testTheRuleMatchesTheSignInScreen() {
        XCTAssertEqual(NewPasswordRule.minimumLength, 8)
        XCTAssertEqual(NewPasswordRule.maximumLength, 72)
    }
}
