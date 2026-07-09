import Foundation

/// Parses partner-invite deep links, supporting both the custom scheme
/// (`genesyx://invite/{code}`) and Universal Links (`https://…/invite/{code}`).
enum DeepLink {
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
