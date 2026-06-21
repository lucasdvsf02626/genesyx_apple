import Foundation
import GenesyxCore

/// Reads Supabase credentials injected into Info.plist (from Secrets.xcconfig / build settings).
/// Pure — always compiles. `isConfigured` is false until you provide real values.
enum RemoteConfig {
    static var url: String { (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? "" }
    static var anonKey: String { (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? "" }
    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty && url.hasPrefix("http") }
}

enum RemoteError: Error { case notConfigured, notAuthenticated }

/// The remote layer the app will use once Supabase is activated (v1.x). Repositories will call
/// these instead of (or alongside) the local store. Defining them as protocols keeps the UI and
/// the rest of the app independent of the concrete Supabase implementation.
protocol AuthBackend {
    var currentUserId: String? { get }
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}

protocol CycleBackend {
    func fetch() async throws -> CycleSettings?
    func upsert(_ settings: CycleSettings) async throws
}

protocol PhBackend {
    func list(sinceDays: Int?) async throws -> [PhReading]
    func create(_ reading: PhReading) async throws
    func update(_ reading: PhReading) async throws
    func delete(id: String) async throws
}

protocol DailyLogBackend {
    func fetch(date: CalendarDate) async throws -> DailyLog?
    func upsert(_ log: DailyLog, on date: CalendarDate) async throws
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
    var partner: PartnerBackend { get }
}
