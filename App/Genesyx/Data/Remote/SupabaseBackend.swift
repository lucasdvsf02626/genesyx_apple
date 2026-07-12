import Foundation
import GenesyxCore

// This file is COMPILED ONLY when the `Supabase` package is linked (see docs/SUPABASE.md to
// activate). Until then `canImport(Supabase)` is false and it is excluded — so the local-only
// v1 keeps building untouched. The API surface targets supabase-swift 2.x; adjust if the
// resolved version differs.

#if canImport(Supabase)
import Supabase

final class SupabaseBackend: GenesyxBackend {
    let client: SupabaseClient
    lazy var auth: AuthBackend = SupabaseAuth(client: client)
    lazy var cycle: CycleBackend = SupabaseCycle(client: client, auth: auth)
    lazy var ph: PhBackend = SupabasePh(client: client, auth: auth)
    lazy var dailyLog: DailyLogBackend = SupabaseDailyLog(client: client, auth: auth)
    lazy var profile: ProfileBackend = SupabaseProfile(client: client, auth: auth)
    lazy var partner: PartnerBackend = SupabasePartner(client: client, auth: auth)

    init?() {
        guard RemoteConfig.isConfigured, let url = URL(string: RemoteConfig.url) else { return nil }
        client = SupabaseClient(supabaseURL: url, supabaseKey: RemoteConfig.anonKey)
    }
}

private struct SupabaseAuth: AuthBackend {
    let client: SupabaseClient
    var currentUserId: String? { client.auth.currentUser?.id.uuidString }
    func signUp(email: String, password: String) async throws { _ = try await client.auth.signUp(email: email, password: password) }
    func signIn(email: String, password: String) async throws { _ = try await client.auth.signIn(email: email, password: password) }
    func signOut() async throws { try await client.auth.signOut() }
    func deleteAccount() async throws {
        try await client.functions.invoke("delete_account", options: .init(body: [String: String]()))
        try? await client.auth.signOut()   // clear the now-invalid local session token
    }
    func signInWithIdToken(provider: SocialProvider, idToken: String, accessToken: String?, nonce: String?) async throws {
        let supaProvider: OpenIDConnectCredentials.Provider = (provider == .google) ? .google : .apple
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: supaProvider, idToken: idToken, accessToken: accessToken, nonce: nonce)
        )
    }
    func resetPassword(email: String) async throws { try await client.auth.resetPasswordForEmail(email) }
}

private func requireUID(_ auth: AuthBackend) throws -> String {
    guard let id = auth.currentUserId else { throw RemoteError.notAuthenticated }
    return id
}

private struct SupabaseCycle: CycleBackend {
    let client: SupabaseClient
    let auth: AuthBackend

    func fetch() async throws -> CycleSettings? {
        let uid = try requireUID(auth)
        let rows: [CycleSettingsRow] = try await client.from("cycle_settings")
            .select().eq("user_id", value: uid).limit(1).execute().value
        return rows.first?.domain
    }

    func upsert(_ settings: CycleSettings) async throws {
        let uid = try requireUID(auth)
        try await client.from("cycle_settings").upsert(CycleSettingsRow(userId: uid, settings: settings)).execute()
    }
}

private struct SupabasePh: PhBackend {
    let client: SupabaseClient
    let auth: AuthBackend

    /// Tombstones are included — a row deleted on another device has to arrive as a deletion, not
    /// as an absence (an absence is indistinguishable from "never pushed" and would resurrect it).
    func list(sinceDays: Int?) async throws -> [PhRecord] {
        let uid = try requireUID(auth)
        var query = client.from("ph_readings").select().eq("user_id", value: uid)
        if let days = sinceDays {
            let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(days) * 86_400))
            query = query.gte("recorded_at", value: cutoff)
        }
        let rows: [PhReadingRow] = try await query.order("recorded_at").execute().value
        return rows.map(\.domain)
    }

    /// Creates, edits and deletes all land here — the row's `deleted` flag carries the tombstone.
    func upsert(_ record: PhRecord) async throws {
        let uid = try requireUID(auth)
        try await client.from("ph_readings").upsert(PhReadingRow(userId: uid, record: record)).execute()
    }
}

private struct SupabaseDailyLog: DailyLogBackend {
    let client: SupabaseClient
    let auth: AuthBackend

    func fetch(date: CalendarDate) async throws -> DailyLog? {
        let uid = try requireUID(auth)
        let rows: [DailyLogRow] = try await client.from("daily_logs")
            .select().eq("user_id", value: uid).eq("date", value: date.iso).limit(1).execute().value
        return rows.first?.domain
    }

    func list() async throws -> [CalendarDate: DailyLog] {
        let uid = try requireUID(auth)
        let rows: [DailyLogRow] = try await client.from("daily_logs")
            .select().eq("user_id", value: uid).execute().value
        return rows.reduce(into: [:]) { map, row in
            if let date = CalendarDate(iso: row.date) { map[date] = row.domain }
        }
    }

    func upsert(_ log: DailyLog, on date: CalendarDate) async throws {
        let uid = try requireUID(auth)
        try await client.from("daily_logs").upsert(DailyLogRow(userId: uid, date: date, log: log)).execute()
    }
}

/// Prefs and display name are written as separate partial upserts: `profiles` also holds
/// `partner_id`, and a whole-row write would clobber whatever this device doesn't know about.
private struct SupabaseProfile: ProfileBackend {
    let client: SupabaseClient
    let auth: AuthBackend

    func fetch() async throws -> ProfilePrefs? {
        let uid = try requireUID(auth)
        let rows: [ProfilePrefsRow] = try await client.from("profiles")
            .select("id,focus_mode,theme,push_enabled").eq("id", value: uid).limit(1).execute().value
        return rows.first?.domain
    }

    func upsert(_ prefs: ProfilePrefs) async throws {
        let uid = try requireUID(auth)
        try await client.from("profiles").upsert(ProfilePrefsRow(id: uid, prefs: prefs)).execute()
    }

    func upsert(displayName: String) async throws {
        let uid = try requireUID(auth)
        try await client.from("profiles")
            .upsert(["id": uid, "display_name": displayName]).execute()
    }
}

private struct SupabasePartner: PartnerBackend {
    let client: SupabaseClient
    let auth: AuthBackend

    func listInvites() async throws -> [PartnerInvite] {
        let uid = try requireUID(auth)
        let rows: [PartnerInviteRow] = try await client.from("partner_invites")
            .select().eq("inviter_id", value: uid).execute().value
        return rows.map(\.domain)
    }

    func fetchPartner() async throws -> Partner? {
        let uid = try requireUID(auth)
        let me: [ProfileRow] = try await client.from("profiles")
            .select("id,display_name,partner_id").eq("id", value: uid).limit(1).execute().value
        guard let partnerId = me.first?.partnerId else { return nil }
        let p: [ProfileRow] = try await client.from("profiles")
            .select("id,display_name,partner_id").eq("id", value: partnerId).limit(1).execute().value
        return p.first.map { Partner(name: $0.displayName ?? "Partner") }
    }

    /// Returns the row the database actually stored, so the link she shares is the link that works.
    func sendInvite(email: String) async throws -> PartnerInvite {
        let uid = try requireUID(auth)
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
        let rows: [PartnerInviteRow] = try await client.from("partner_invites")
            .insert(["inviter_id": uid, "invitee_email": email, "code": code, "status": "pending"])
            .select()
            .execute().value
        guard let invite = rows.first?.domain else { throw RemoteError.notConfigured }
        return invite
    }

    /// Asks the server to email the invite. The function reports `sent: false` when the mailer
    /// isn't configured (or the send failed) rather than erroring, because the invite itself is
    /// still valid and still shareable — a missing API key must not break invites.
    func emailInvite(code: String) async throws -> Bool {
        let response: EmailInviteResponse = try await client.functions.invoke(
            "send_partner_invite", options: .init(body: ["code": code]))
        return response.sent
    }

    func revoke(id: String) async throws {
        _ = try requireUID(auth)
        try await client.from("partner_invites").update(["status": "revoked"]).eq("id", value: id).execute()
    }

    // Privileged (bidirectional link / service role on web) → Supabase Edge Functions.
    func accept(code: String) async throws {
        try await client.functions.invoke("accept_partner_invite", options: .init(body: ["code": code]))
    }

    func unlink() async throws {
        try await client.functions.invoke("unlink_partner", options: .init(body: [String: String]()))
    }
}
#endif
