import Foundation

/// Which Learn articles she has actually opened. The planner needs it so a nudge never offers her
/// something she's already read — the fastest way to make a notification feel automated.
enum LearnReadLog {
    private static let key = "genesyx.learn_read_slugs"

    /// Slugs renamed after release, mapped old → new. Without this a rename silently resets her
    /// read history, and the Learn nudge offers her an article she has already read.
    private static let renamed = ["guide-urine-tracker-with-stick": "guide-vaginal-ph-tracker"]

    static var readSlugs: Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(stored.map { renamed[$0] ?? $0 })
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

/// Which articles this device has already told her about. Articles are bundled at compile time and
/// carry no publish date, so "new" can only mean "arrived in an update she has just installed" —
/// this set is what that is measured against.
///
/// On a genuinely first run the whole library is recorded at once: nothing is new to someone who is
/// only just starting, and sixteen consecutive "new this week" Sundays would be a lie. Only articles
/// that show up in a *later* build are announced.
enum LearnLibraryLog {
    private static let key = "genesyx.learn_known_slugs"

    static func newSlugs(in library: [String], defaults: UserDefaults = .standard) -> Set<String> {
        guard let known = defaults.stringArray(forKey: key) else {
            defaults.set(library, forKey: key)
            return []
        }
        return Set(library).subtracting(known)
    }

    /// Called once the nudge naming it has actually fired — not when it was merely queued. A replan
    /// between the update and Sunday would otherwise drop the announcement without ever making it.
    static func markAnnounced(_ slug: String, defaults: UserDefaults = .standard) {
        var known = Set(defaults.stringArray(forKey: key) ?? [])
        guard known.insert(slug).inserted else { return }
        defaults.set(Array(known), forKey: key)
    }
}
