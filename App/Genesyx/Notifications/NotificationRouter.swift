import Foundation

/// Where a notification tap should land. Pure, so the mapping is testable without the system
/// notification centre.
enum NotificationRouter {

    struct Destination: Equatable {
        var tab: NotificationTab
        /// Set only for the Learn nudge — the article to push once the Learn tab is showing.
        var learnSlug: String?
    }

    /// The `userInfo` payload attached to every request we schedule.
    static func payload(tab: NotificationTab, learnSlug: String? = nil) -> [String: Any] {
        var info: [String: Any] = ["tab": tab.rawValue]
        if let learnSlug { info["slug"] = learnSlug }
        return info
    }

    /// Decode a tapped notification's payload. Returns nil for anything we didn't schedule.
    static func destination(from userInfo: [AnyHashable: Any]) -> Destination? {
        guard let raw = userInfo["tab"] as? Int, let tab = NotificationTab(rawValue: raw) else { return nil }
        return Destination(tab: tab, learnSlug: userInfo["slug"] as? String)
    }
}
