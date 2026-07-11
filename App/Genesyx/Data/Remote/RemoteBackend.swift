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
}

/// Social identity providers the app can exchange an ID token for a Supabase session.
enum SocialProvider { case google, apple }

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
}

extension AuthBackend {
    // Default no-ops so local/mock backends need not implement these; the real Supabase
    // backend overrides them.
    func deleteAccount() async throws {}
    func signInWithIdToken(provider: SocialProvider, idToken: String, accessToken: String?, nonce: String?) async throws {}
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
    func upsert(_ prefs: ProfilePrefs) async throws
    func upsert(displayName: String) async throws
}

struct ProfilePrefs: Equatable {
    var focusMode: FocusMode
    var themeMode: ThemeMode
    var pushEnabled: Bool
}

protocol PartnerBackend {
    func listInvites() async throws -> [PartnerInvite]
    func fetchPartner() async throws -> Partner?
    func sendInvite(email: String) async throws
    func revoke(id: String) async throws
    func accept(code: String) async throws
    func unlink() async throws
}

/// Aggregate entry point the app resolves at startup.
protocol GenesyxBackend {
    var auth: AuthBackend { get }
    var cycle: CycleBackend { get }
    var ph: PhBackend { get }
    var dailyLog: DailyLogBackend { get }
    var profile: ProfileBackend { get }
    var partner: PartnerBackend { get }
}
