import Combine
import Foundation
import GenesyxCore

/// Which Learn articles she has actually opened. The planner needs it so a nudge never offers her
/// something she's already read — the fastest way to make a notification feel automated.
enum LearnReadLog {
    private static let key = "genesyx.learn_read_slugs"

    /// Slugs renamed after release, mapped old → new. Without this a rename silently resets her
    /// read history, and the Learn nudge offers her an article she has already read.
    private static let renamed = ["guide-urine-tracker-with-stick": "guide-vaginal-ph-tracker"]

    static func readSlugs(defaults: UserDefaults = .standard) -> Set<String> {
        let stored = defaults.stringArray(forKey: key) ?? []
        return Set(stored.map { renamed[$0] ?? $0 })
    }

    static func markRead(_ slug: String, defaults: UserDefaults = .standard) {
        var slugs = readSlugs(defaults: defaults)
        guard slugs.insert(slug).inserted else { return }
        defaults.set(Array(slugs), forKey: key)
    }

    /// Cleared on sign-out: the next user on this device has not read anything yet, and a Learn
    /// nudge that skips articles she never opened would be quietly wrong.
    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
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

/// The Learn library's read state, as a view can watch it. The two logs above stay the storage;
/// this is the part that tells SwiftUI when it changed, so the tab badge clears the moment she
/// finishes reading rather than the next time she happens to switch tabs.
@MainActor
final class LearnProgress: ObservableObject {

    @Published private(set) var readSlugs: Set<String>

    /// Which slugs arrived in an update she has just installed — fixed at launch, deliberately.
    ///
    /// `LearnLibraryLog.markAnnounced` fires when the Sunday nudge *delivers*, so a badge that
    /// re-read that set live would vanish the moment the notification arrived: dismiss the banner
    /// and the article is gone from both surfaces at once. Captured here, the badge outlives the
    /// session the nudge fired in, and only reading clears it.
    private var arrived: Set<String>
    private let articles: [LearnArticle]
    private let defaults: UserDefaults

    init(articles: [LearnArticle] = LearnLibrary.articles, defaults: UserDefaults = .standard) {
        self.articles = articles
        self.defaults = defaults
        self.arrived = LearnLibraryLog.newSlugs(in: articles.map(\.slug), defaults: defaults)
        self.readSlugs = LearnReadLog.readSlugs(defaults: defaults)
    }

    /// New since her last update and still unread — what the Learn tab badges. Zero on a first
    /// install, because nothing is new to someone only just starting: badging all sixteen would be
    /// a chore list, not a nudge.
    var unreadNewCount: Int { arrived.subtracting(readSlugs).count }

    /// The article to point her at next, with the headline to put above it — nil once she's read
    /// them all. Same rule and the same two titles as the Sunday nudge, so the card and the
    /// notification can't name different articles or describe the same one differently.
    var nextRead: (article: LearnArticle, headline: String)? {
        let ranked = Self.candidates(articles, read: readSlugs, arrived: arrived)
        guard let pick = NotificationPlanner.nextRead(from: ranked),
              let article = articles.first(where: { $0.slug == pick.slug }) else { return nil }
        return (article, NotificationPlanner.learnHeadline(pick))
    }

    func markRead(_ slug: String) {
        LearnReadLog.markRead(slug, defaults: defaults)
        readSlugs = LearnReadLog.readSlugs(defaults: defaults)
    }

    /// Signed out: the next user on this device has read nothing, and what she read is her business.
    func clear() {
        LearnReadLog.clear(defaults: defaults)
        readSlugs = []
        // Nothing is "new" to an account that has just arrived on this phone either.
        arrived = []
    }

    /// The library as the planner sees it. Shared with `NotificationService` so the badge, the card
    /// and the nudge all rank the same list.
    static func candidates(_ articles: [LearnArticle],
                           read: Set<String>, arrived: Set<String>) -> [LearnCandidate] {
        articles.map { article in
            LearnCandidate(
                slug: article.slug,
                title: article.title,
                readingTime: article.readingTime,
                tags: article.tags.map { $0.lowercased() },
                read: read.contains(article.slug),
                isNew: arrived.contains(article.slug)
            )
        }
    }
}
