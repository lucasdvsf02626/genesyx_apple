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

    static func inviteCode(from url: URL) -> String? {
        // Custom scheme: genesyx://invite/{code}
        if url.scheme == "genesyx", url.host == "invite" {
            let comps = url.pathComponents.filter { $0 != "/" }
            return comps.last
        }
        // Universal Link: …/invite/{code}
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
