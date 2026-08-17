import Foundation
import GenesyxCore

/// Reads Supabase credentials injected into Info.plist (from Secrets.xcconfig / build settings).
/// Pure — always compiles. `isConfigured` is false until you provide real values.
enum RemoteConfig {
    static var url: String { (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? "" }
    static var anonKey: String { (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? "" }
    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty && url.hasPrefix("http") }

    /// Google iOS OAuth client (project 413702980668). Used by GoogleSignIn on iOS; the reversed
    /// form is registered as a URL scheme in Info.plist. Not a secret (ships in the app).
    static let googleIOSClientID = "413702980668-tfah1knspa8ip82p51c3i3veuh3ljul4.apps.googleusercontent.com"
}

enum RemoteError: Error {
    case notConfigured
    case notAuthenticated
    /// Sign-up succeeded but produced no session, because the project requires the user to confirm
    /// her email address first. She is NOT signed in — she has to click the link, then sign in.
    case emailConfirmationRequired
    /// No remote backend is configured, so there is no list to join / nothing to store. Surfaced
    /// (never swallowed) so the UI cannot claim a write happened when it did not.
    case notAvailable
}

/// Classifies a sync failure so the queue drains know whether to stop or step over one item.
enum SyncError {
    /// True when the failure is about the *connection*, not about this one row: stop the drain and
    /// keep everything queued for next time. False means the server reached us and rejected this
    /// specific write — step over it, so one poisoned item can't starve every newer one behind it.
    ///
    /// Two cases qualify, and the second is easy to miss. `URLError` is the obvious one: offline,
    /// timed out, DNS. `notAuthenticated` is thrown by `requireUID` *before any request leaves the
    /// device*, when the session hasn't been restored yet or the token has expired — so it says
    /// nothing about the row and everything about the connection.
    ///
    /// It has to be named explicitly because it is not a `URLError`, and the drains used to stop on
    /// *any* failure, so it was covered for free. Stepping over rejections is what made it visible:
    /// a missing session would otherwise be read as "this one row is poison", and a signed-out
    /// foreground would walk the entire backlog, one doomed call per owed day, to learn what the
    /// first call already established. Nothing would be lost — it would just do N times the work,
    /// where N is however many days she logged offline.
    ///
    /// Foundation-only by design: the repositories live in the app module and compile even when the
    /// Supabase package is absent, so they cannot reason about `PostgrestError`. That is also why
    /// the "rejected" branch retries forever rather than dropping the row. From here a 400 the
    /// server will never accept and a 503 it would accept in a minute look identical, and the two
    /// mistakes are not symmetric: retrying a dead row costs one background call per foreground,
    /// while dropping a live one silently loses a day she logged. Until a rejection can carry its
    /// status code up to this layer, the queue keeps it.
    static func shouldHaltDrain(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let remote = error as? RemoteError { return remote == .notAuthenticated }
        return false
    }
}

/// Social identity providers the app can exchange an ID token for a Supabase session.
enum SocialProvider { case google, apple }

/// A validated auth session. Produced by `AuthBackend.validatedSession()`, which refreshes
/// when the SDK can and otherwise returns a non-expired cached session (the offline policy).
struct AuthSessionSnapshot: Equatable {
    let userId: String
}

/// Lifecycle events from `auth.authStateChanges`. The repository maps these onto
/// `SessionAuthState` so an expiry or a remote sign-out cannot leave the UI claiming
/// she is still signed in.
enum AuthLifecycleEvent: Equatable {
    case initialSession(userId: String?)
    case signedIn(userId: String)
    case signedOut
    case tokenRefreshed(userId: String)
    case sessionExpired
}

/// The remote layer the app will use once Supabase is activated (v1.x). Repositories will call
/// these instead of (or alongside) the local store. Defining them as protocols keeps the UI and
/// the rest of the app independent of the concrete Supabase implementation.
protocol AuthBackend {
    var currentUserId: String? { get }
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    /// Permanently deletes the caller's account + all their data (App Store 5.1.1(v)).
    func deleteAccount() async throws
    /// Exchanges a provider ID token (Google/Apple) for a Supabase session.
    func signInWithIdToken(provider: SocialProvider, idToken: String, accessToken: String?, nonce: String?) async throws
    /// Emails a password-reset link to `email`, pointed back at `DeepLink.passwordRecoveryURL`.
    func resetPassword(email: String) async throws
    /// Redeems the recovery deep link, establishing the session that authorises `updatePassword`.
    /// Throws when the link is expired, already used, or malformed.
    func completePasswordRecovery(url: URL) async throws
    /// Sets a new password on the currently authenticated user. Requires a live session — the one
    /// `completePasswordRecovery` just established, or an ordinary signed-in one.
    func updatePassword(_ newPassword: String) async throws
    /// Re-sends the sign-up confirmation email to `email` (for an account created but not yet confirmed).
    func resendConfirmation(email: String) async throws
    /// Refreshes when possible; returns a non-expired cached session when offline.
    func validatedSession() async -> AuthSessionSnapshot?
    /// Subscribe to `initialSession` / `signedIn` / `signedOut` / `tokenRefreshed`.
    func observeAuthState(_ handler: @escaping @MainActor (AuthLifecycleEvent) -> Void)
}

extension AuthBackend {
    // Default no-ops so local/mock backends need not implement these; the real Supabase
    // backend overrides them.
    func deleteAccount() async throws {}
    func signInWithIdToken(provider: SocialProvider, idToken: String, accessToken: String?, nonce: String?) async throws {}
    func resetPassword(email: String) async throws {}
    func resendConfirmation(email: String) async throws {}
    // These two THROW rather than no-op, unlike their neighbours above. A silent default here
    // would be a backend that reports a password successfully changed while changing nothing —
    // she would then be locked out by a password only the app believes in. Failing loudly is the
    // only safe default for a credential write.
    func completePasswordRecovery(url: URL) async throws { throw RemoteError.notConfigured }
    func updatePassword(_ newPassword: String) async throws { throw RemoteError.notConfigured }
    func validatedSession() async -> AuthSessionSnapshot? {
        currentUserId.map { AuthSessionSnapshot(userId: $0) }
    }
    func observeAuthState(_ handler: @escaping @MainActor (AuthLifecycleEvent) -> Void) {}
}

protocol CycleBackend {
    func fetch() async throws -> CycleSettings?
    func upsert(_ settings: CycleSettings) async throws
}

/// One write path: creates, edits and deletes are all an upsert of a `PhRecord` (a delete is a
/// record with `deleted == true`). `list` returns tombstones too, so deletions propagate.
protocol PhBackend {
    func list(sinceDays: Int?) async throws -> [PhRecord]
    func upsert(_ record: PhRecord) async throws
}

/// Her own supplements, in `user_supplements` — the same table Android reads and writes. One write
/// path, as with pH: a delete is an upsert carrying a tombstone, and `list` returns tombstones so a
/// deletion made on her other phone arrives as a deletion rather than as an absence.
protocol SupplementBackend {
    func list() async throws -> [SupplementRecord]
    func upsert(_ record: SupplementRecord) async throws
}

protocol DailyLogBackend {
    func fetch(date: CalendarDate) async throws -> DailyLog?
    /// Every logged day. Needed on sign-in: a device that only ever pulled "today" could never
    /// rebuild a history after a reinstall.
    func list() async throws -> [CalendarDate: DailyLog]
    func upsert(_ log: DailyLog, on date: CalendarDate) async throws
}

/// The user's own row in `profiles`. Written column-by-column so a partial write (prefs only)
/// never nulls out a column it doesn't know about (e.g. `partner_id`).
protocol ProfileBackend {
    func fetch() async throws -> ProfilePrefs?
    /// Read on its own rather than folded into `ProfilePrefs`, for the same reason it is written on
    /// its own: her name belongs to the session, and a prefs struct carrying it would let a prefs
    /// push overwrite a name that push never read.
    func fetchDisplayName() async throws -> String?
    func upsert(_ prefs: ProfilePrefs) async throws
    func upsert(displayName: String) async throws
}

/// The part of her `profiles` row this device owns and syncs. Wider than its name: the onboarding
/// quiz answers ride along because they live in the same row, are written by the same device, and
/// owe the server the same retry — a second pending queue for one dictionary would be more
/// machinery than the thing it carries.
struct ProfilePrefs: Equatable {
    var focusMode: FocusMode
    var themeMode: ThemeMode
    var pushEnabled: Bool
    /// What she answered in onboarding, keyed by `QuizQuestion.id` with `QuizOption.id` as the
    /// value. A dictionary rather than a typed struct because the questions are content, and a
    /// field per question would need a schema change every time the copy does.
    var quizAnswers: [String: String] = [:]
}

protocol PartnerBackend {
    func listInvites() async throws -> [PartnerInvite]
    func fetchPartner() async throws -> Partner?
    /// Returns the invite the SERVER created. The code must come back from the database — inventing
    /// one on the device would hand her a link that redeems nothing.
    func sendInvite(email: String) async throws -> PartnerInvite
    /// Emails the invite to the address it was addressed to. Returns whether the mail actually
    /// went out — the mailer may not be configured, and that must not fail the invite.
    func emailInvite(code: String) async throws -> Bool
    func revoke(id: String) async throws
    func accept(code: String) async throws
    /// The recipient refusing. Distinct from `revoke`, which is the inviter withdrawing — that one
    /// takes an `id` because the inviter can see her own rows; this one takes the `code`, because
    /// the recipient cannot see the invite at all and the code is the only handle she holds.
    func decline(code: String) async throws
    func unlink() async throws
}

extension PartnerBackend {
    /// Local/mock backends don't send mail. Defaulted so no existing conformer has to change.
    func emailInvite(code: String) async throws -> Bool { false }

    /// Defaulted to a THROW, not a no-op. Declining is a claim about a row on the server; a backend
    /// that cannot make that call must fail loudly rather than let the UI report a refusal that
    /// never reached the database and leave the invite quietly redeemable.
    func decline(code: String) async throws { throw RemoteError.notConfigured }
}

/// Aggregate entry point the app resolves at startup.
protocol GenesyxBackend {
    var auth: AuthBackend { get }
    var cycle: CycleBackend { get }
    var ph: PhBackend { get }
    var supplements: SupplementBackend { get }
    var dailyLog: DailyLogBackend { get }
    var profile: ProfileBackend { get }
    var partner: PartnerBackend { get }
    /// Adds an email to the pre-account waiting list. Called from onboarding *before* sign-in, so it
    /// runs under the anon key and must not require a session. Throws on failure so the UI only
    /// confirms once the address is actually stored.
    func joinWaitlist(email: String) async throws
}
