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
    lazy var supplements: SupplementBackend = SupabaseUserSupplements(client: client, auth: auth)
    lazy var dailyLog: DailyLogBackend = SupabaseDailyLog(client: client, auth: auth)
    lazy var profile: ProfileBackend = SupabaseProfile(client: client, auth: auth)
    lazy var partner: PartnerBackend = SupabasePartner(client: client, auth: auth)

    init?() {
        guard RemoteConfig.isConfigured, let url = URL(string: RemoteConfig.url) else { return nil }
        client = SupabaseClient(supabaseURL: url, supabaseKey: RemoteConfig.anonKey)
    }

    /// `waitlist_emails` is locked down (RLS on, no client policies); the only write path is the
    /// SECURITY DEFINER `join_waitlist` RPC, callable under the anon key from pre-auth onboarding.
    func joinWaitlist(email: String) async throws {
        try await client.rpc("join_waitlist", params: ["p_email": email]).execute()
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
    /// `redirectTo` is the whole fix. Called bare, the SDK omits `redirect_to` and Supabase falls
    /// back to the project's Site URL — a web page — so the link in her inbox opened Safari and the
    /// app never saw it. She was told "check your inbox" for a link that could not come home.
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: DeepLink.passwordRecoveryURL)
    }

    /// The client runs the SDK's default PKCE flow, so `resetPasswordForEmail` stashed a code
    /// verifier on THIS device and only this device can redeem the link. `session(from:)` performs
    /// that exchange and stores the resulting session. It throws on an expired, reused or
    /// foreign-device link, which is what lets the UI say so instead of hanging.
    func completePasswordRecovery(url: URL) async throws {
        _ = try await client.auth.session(from: url)
    }

    func updatePassword(_ newPassword: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func resendConfirmation(email: String) async throws { try await client.auth.resend(email: email, type: .signup) }

    /// `client.auth.session` refreshes when it can. If that throws (typically offline), a
    /// non-expired cached session is still a valid credential — the agreed local-first policy.
    /// An expired cache with no refresh is not: that is a revoked-or-lapsed token.
    func validatedSession() async -> AuthSessionSnapshot? {
        do {
            let session = try await client.auth.session
            guard !session.isExpired else { return nil }
            return AuthSessionSnapshot(userId: session.user.id.uuidString)
        } catch {
            if let cached = client.auth.currentSession, !cached.isExpired {
                return AuthSessionSnapshot(userId: cached.user.id.uuidString)
            }
            return nil
        }
    }

    func observeAuthState(_ handler: @escaping @MainActor (AuthLifecycleEvent) -> Void) {
        Task {
            for await (event, session) in client.auth.authStateChanges {
                let mapped: AuthLifecycleEvent
                switch event {
                case .initialSession:
                    let id = session.flatMap { $0.isExpired ? nil : $0.user.id.uuidString }
                    mapped = .initialSession(userId: id)
                case .signedIn:
                    guard let id = session?.user.id.uuidString else { continue }
                    mapped = .signedIn(userId: id)
                case .signedOut:
                    mapped = .signedOut
                case .tokenRefreshed:
                    if let session, !session.isExpired {
                        mapped = .tokenRefreshed(userId: session.user.id.uuidString)
                    } else {
                        mapped = .sessionExpired
                    }
                default:
                    continue
                }
                await handler(mapped)
            }
        }
    }
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

private struct SupabaseUserSupplements: SupplementBackend {
    let client: SupabaseClient
    let auth: AuthBackend

    /// Tombstones included, for the same reason as pH: a row deleted on her Android phone has to
    /// arrive as a deletion, and an absence is indistinguishable from "this device never pushed it".
    /// Ordered by `created_at` so a first sign-in rebuilds her list in the order she added it.
    func list() async throws -> [SupplementRecord] {
        let uid = try requireUID(auth)
        let rows: [UserSupplementRow] = try await client.from("user_supplements")
            .select().eq("user_id", value: uid).order("created_at").execute().value
        return rows.map(\.domain)
    }

    /// Adds and deletes both land here — the row's `deleted_at` carries the tombstone.
    func upsert(_ record: SupplementRecord) async throws {
        let uid = try requireUID(auth)
        try await client.from("user_supplements").upsert(UserSupplementRow(userId: uid, record: record)).execute()
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
        guard let row = rows.first else { return nil }
        let quiz: [QuizAnswersRow] = try await client.from("quiz_answers")
            .select("user_id,answers").eq("user_id", value: uid).limit(1).execute().value
        return row.domain(quizAnswers: quiz.first?.answers ?? [:])
    }

    func fetchDisplayName() async throws -> String? {
        let uid = try requireUID(auth)
        let rows: [ProfileRow] = try await client.from("profiles")
            .select("id,display_name,partner_id").eq("id", value: uid).limit(1).execute().value
        return rows.first?.displayName
    }

    func upsert(_ prefs: ProfilePrefs) async throws {
        let uid = try requireUID(auth)
        try await client.from("profiles").upsert(ProfilePrefsRow(id: uid, prefs: prefs)).execute()
        guard let quiz = QuizAnswersRow(userId: uid, answers: prefs.quizAnswers) else { return }
        try await client.from("quiz_answers").upsert(quiz).execute()
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

    /// The inviter withdrawing her own invite. No longer a direct UPDATE: `authenticated` lost
    /// UPDATE on `partner_invites` in `20260812_partner_invites_write_lockdown.sql`, because a
    /// row-scoped RLS policy governs which ROWS may be written and says nothing about which VALUES
    /// — so the owner could write `status` back to 'pending' and undo a recipient's decline. Every
    /// status transition is now a service-role function: accept, decline, revoke.
    func revoke(id: String) async throws {
        _ = try requireUID(auth)
        try await client.functions.invoke("revoke_partner_invite", options: .init(body: ["id": id]))
    }

    // Privileged (bidirectional link / service role on web) → Supabase Edge Functions.
    func accept(code: String) async throws {
        try await client.functions.invoke("accept_partner_invite", options: .init(body: ["code": code]))
    }

    /// Also an Edge Function, though it writes only a status. `partner_invites_owner` is
    /// `using (inviter_id = auth.uid())`, so the recipient cannot see — let alone update — the
    /// invite addressed to her. Giving her a policy would open a read on the whole row; the
    /// function gives her the one verb and no read.
    func decline(code: String) async throws {
        try await client.functions.invoke("decline_partner_invite", options: .init(body: ["code": code]))
    }

    func unlink() async throws {
        try await client.functions.invoke("unlink_partner", options: .init(body: [String: String]()))
    }
}
#endif
