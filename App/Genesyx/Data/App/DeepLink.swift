import Foundation

/// Parses partner-invite deep links, supporting both the custom scheme
/// (`genesyx://invite/{code}`) and Universal Links (`https://…/invite/{code}`).
enum DeepLink {

    /// The domain that serves `apple-app-site-association` (see `public/.well-known/`).
    static let webHost = "genesyx.co.uk"

    /// Universal Links need TWO things live before the https link is safe to hand out:
    ///   1. `https://genesyx.co.uk/.well-known/apple-app-site-association` served over HTTPS as
    ///      `application/json`, and
    ///   2. a build carrying the `associated-domains` entitlement installed on the phone.
    ///
    /// Until BOTH are true, an https link opens Safari to a 404 — strictly worse than the custom
    /// scheme, which at least opens the app for someone who has it. So the link she hands out stays
    /// `genesyx://` until this is flipped.
    ///
    /// **Flip to `true` once the AASA file is live** (verify: `curl -sI https://genesyx.co.uk/.well-known/apple-app-site-association`
    /// returns 200 with `content-type: application/json`). Nothing else needs to change — the
    /// parser already accepts both forms, so old custom-scheme links keep working forever.
    static let universalLinksLive = false

    /// The Universal Link. Survives a fresh install: a partner without the app lands on the web
    /// page, installs, and the link still resolves.
    static func webInviteURL(code: String) -> URL? {
        URL(string: "https://\(webHost)/invite/\(code)")
    }

    /// The custom scheme. Only opens on a phone that already has the app.
    static func schemeInviteURL(code: String) -> URL? {
        URL(string: "genesyx://invite/\(code)")
    }

    /// The link she shares with her partner. Built from the code the DATABASE issued.
    static func inviteURL(code: String) -> URL? {
        universalLinksLive ? webInviteURL(code: code) : schemeInviteURL(code: code)
    }

    /// The message she sends. While we're on the custom scheme it has to carry the instructions
    /// too, because the link does nothing on a phone that doesn't have the app yet. Once Universal
    /// Links are live the link stands on its own.
    static func inviteShareText(code: String, from name: String?) -> String {
        let who = name.map { "\($0) has" } ?? "You've been"
        let link = inviteURL(code: code)?.absoluteString ?? code
        if universalLinksLive {
            return """
            \(who) invited you to join them on Genesyx.

            Open this link to accept — sign in with this email address, it's what the invite is tied to:
            \(link)
            """
        }
        return """
        \(who) invited you to join them on Genesyx.

        Install Genesyx, sign in with this email address, then open this link to accept:
        \(link)
        """
    }

    // MARK: - Password recovery

    /// Where Supabase sends her back to after she taps the link in a reset email.
    ///
    /// Deliberately the CUSTOM SCHEME and not the https link, even though the `associated-domains`
    /// entitlement is present. Universal Links need the AASA file served before an https link is
    /// safe (see `universalLinksLive`), and a recovery link that opens Safari to a 404 is a woman
    /// locked out of her account. The custom scheme has no such dependency: if the app is installed,
    /// it opens. She must have the app installed to be resetting its password, so nothing is lost.
    ///
    /// **This exact string must be on the Supabase Auth "Redirect URLs" allow-list**, or the
    /// `redirect_to` parameter is discarded server-side and the email falls back to the Site URL —
    /// which is the bug this whole path exists to fix. See `docs/SUPABASE.md`.
    static let passwordRecoveryURL = URL(string: "genesyx://reset-password")!

    /// True when `url` is the recovery callback. Host-checked for the same reason `inviteCode` is:
    /// any app on the device can open a `genesyx://` URL, so only the shape we issue is honoured.
    ///
    /// Note this deliberately does NOT inspect the query. A callback carrying `?error=...` (an
    /// expired or already-used link) is still a recovery callback — it has to reach the recovery
    /// screen so she can be told what went wrong, rather than being dropped in silence the way
    /// every reset URL is dropped today.
    static func isPasswordRecovery(_ url: URL) -> Bool {
        url.scheme == "genesyx" && url.host == "reset-password"
    }

    static func inviteCode(from url: URL) -> String? {
        // Custom scheme: genesyx://invite/{code} and nothing else.
        //
        // The whole scheme is decided HERE, including the rejection. Letting a non-matching
        // `genesyx://` URL fall through to the web branch below is what allowed
        // `genesyx://anything/invite/CODE` to be read as an invite: the host check failed, and the
        // path check then matched anyway. Any app or web page on the device can open a custom-scheme
        // URL, so that fallthrough let an arbitrary page raise the "Accept to link your accounts"
        // sheet carrying a code of its choosing.
        //
        // Not a way in — `accept_partner_invite` still refuses a code not addressed to her email, so
        // the ceiling was a spoofed sheet rather than a link. But the sheet should only ever appear
        // for a URL shaped like one we issued, and `schemeInviteURL` only ever issues that shape.
        if url.scheme == "genesyx" {
            guard url.host == "invite" else { return nil }
            return url.pathComponents.filter { $0 != "/" }.last
        }
        // Universal Link: https://{webHost}/invite/{code}, on our domain and no other.
        //
        // The host was previously unchecked, so ANY https URL carrying an `/invite/` path yielded a
        // code. That existed to keep links on the retired `…lovable.app` prototype resolving; that
        // domain is dead, and with it the reason to honour a stranger's.
        //
        // Compared case-insensitively: Foundation does not normalise host case, while Universal Link
        // matching is case-insensitive, so `https://GENESYX.CO.UK/invite/x` is a link iOS would
        // legitimately deliver and an exact `==` would silently drop.
        guard url.scheme == "https", url.host?.lowercased() == webHost else { return nil }
        let comps = url.pathComponents.filter { $0 != "/" }
        if let i = comps.firstIndex(of: "invite"), i + 1 < comps.count {
            return comps[i + 1]
        }
        return nil
    }
}

/// Identifiable wrapper so an incoming invite code can drive a `.sheet(item:)`.
struct InvitePresentation: Identifiable {
    let code: String
    var id: String { code }
}
