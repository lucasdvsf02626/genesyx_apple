import Foundation

/// Parses partner-invite deep links, supporting both the custom scheme
/// (`genesyx://invite/{code}`) and Universal Links (`https://…/invite/{code}`).
enum DeepLink {

    /// The link she shares with her partner. Built from the code the DATABASE issued.
    static func inviteURL(code: String) -> URL? {
        URL(string: "genesyx://invite/\(code)")
    }

    /// The message she sends. It has to carry the link *and* say what to do with it, because the
    /// custom scheme does nothing on a phone that doesn't have the app yet.
    static func inviteShareText(code: String, from name: String?) -> String {
        let who = name.map { "\($0) has" } ?? "You've been"
        return """
        \(who) invited you to join them on Genesyx.

        Install Genesyx, sign in with this email address, then open this link to accept:
        \(inviteURL(code: code)?.absoluteString ?? code)
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
