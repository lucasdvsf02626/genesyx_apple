import Foundation

/// Which Learn articles she has actually opened. The planner needs it so a nudge never offers her
/// something she's already read — the fastest way to make a notification feel automated.
enum LearnReadLog {
    private static let key = "genesyx.learn_read_slugs"

    static var readSlugs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func markRead(_ slug: String) {
        var slugs = readSlugs
        guard slugs.insert(slug).inserted else { return }
        UserDefaults.standard.set(Array(slugs), forKey: key)
    }

    /// Cleared on sign-out: the next user on this device has not read anything yet, and a Learn
    /// nudge that skips articles she never opened would be quietly wrong.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
