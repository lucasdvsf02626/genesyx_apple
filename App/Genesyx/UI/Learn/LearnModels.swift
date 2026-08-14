import GenesyxCore
import SwiftUI

/// Compile-time feature gates (parity with Android `FeatureFlags`).
/// Only `phTracking` is on for v1.0; the rest are dormant-but-present.
enum FeatureFlags {
    static let phTracking = true
    static let adminClients = false
    /// **OFF for the 1.2.0 public release — partner linking is intentionally out of scope.**
    ///
    /// A compile-time constant, so while this is `false` there is no runtime path — no setting,
    /// gesture, debug menu or server response — that turns partner linking on in a shipped build.
    /// Re-enabling it means editing this line and submitting a new binary.
    ///
    /// The partner code stays compiled (`PartnerRepository`, `PartnerBackend`, `InviteView`,
    /// `InviteShareSheet`) because the same Supabase backend serves the Android app, which does
    /// ship partner linking; deleting it here would not remove it there.
    ///
    /// To restore: set this to `true` — every gate reads this one flag. To remove permanently:
    /// `grep -rn partnerInvites` and delete each guarded block plus the files named above.
    static let partnerInvites = false
    static let pushNotifications = true
    /// Off: supplement reminders fire at the hour she set, with the plain body. On: the hour may
    /// shift by up to two hours toward when she actually logs, and a personalised sentence is
    /// appended. Never changes WHICH supplements are reminded — see `SupplementPersonalisation`.
    static let personalisedSupplementTiming = false
}

// MARK: - Learn content model (parity with Android LearnContent.kt)

/// The five Learn categories. Raw values match the Android/JSON taxonomy.
enum LearnCategory: String, CaseIterable, Identifiable {
    case gettingStarted = "GETTING_STARTED"
    case tracking = "TRACKING"
    case nutrition = "NUTRITION"
    case insights = "INSIGHTS"
    case wellness = "WELLNESS"
    case guides = "GUIDES"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gettingStarted: return "Getting started"
        case .tracking: return "Tracking"
        case .nutrition: return "Nutrition"
        case .insights: return "Insights"
        case .wellness: return "Wellness"
        case .guides: return "Guides"
        }
    }

    /// Category tint — also the base for the missing-hero gradient fallback.
    var tint: Color {
        switch self {
        case .gettingStarted: return GenesyxColor.primary
        case .tracking: return GenesyxColor.electricBlue
        case .nutrition: return GenesyxColor.electricPink
        case .insights: return GenesyxColor.electricLavender
        case .wellness: return GenesyxColor.powderBlue
        case .guides: return GenesyxColor.babyLavender
        }
    }
}

/// A typed body block — exactly four cases, no Markdown (parity with Android).
enum ArticleBlock {
    case heading(String)
    case paragraph(String)
    case bulletList([String])
    case callout(String)
}

/// CTA destinations an article can jump to.
enum CtaType {
    case openLog, openTrack, openPh, openNutrition, openInsights, openArticle
}

/// A CTA button. Construction guard: an `.openArticle` CTA MUST carry a non-empty
/// `targetSlug`, otherwise `init?` returns nil (never crashes a reader).
struct ArticleCta {
    let type: CtaType
    let label: String
    let targetSlug: String?

    init?(type: CtaType, label: String, targetSlug: String? = nil) {
        if case .openArticle = type {
            guard let t = targetSlug, !t.isEmpty else { return nil }
        }
        self.type = type
        self.label = label
        self.targetSlug = targetSlug
    }
}

/// One bundled Learn article. `slug` is stable and used in the route — never change after release.
struct LearnArticle: Identifiable {
    let id: String
    let slug: String
    let title: String
    let excerpt: String
    let body: [ArticleBlock]
    let category: LearnCategory
    let tags: [String]
    let readingTime: String
    let heroImage: String?          // asset name, e.g. "learn_hero_first_week"
    let featured: Bool
    let relatedArticleIds: [String]
    let cta: ArticleCta?
    let disclaimerRequired: Bool

    /// The day this article becomes visible, or `nil` for one that always has been.
    ///
    /// The weekly series is compiled into the app like everything else and revealed on a date
    /// rather than by an update: twelve articles would otherwise mean twelve App Store
    /// submissions, and one rejected review would break the run. `var` with a default so the
    /// articles that predate the series need no edit.
    var publishedAt: CalendarDate? = nil
}

/// Exact medical-disclaimer string (parity with Android `MEDICAL_DISCLAIMER`),
/// shown above the footer on the six flagged articles only.
let MEDICAL_DISCLAIMER = "This is educational content, not medical advice. It can't account for your individual circumstances, and it isn't a substitute for talking to a doctor, nurse, or pharmacist. If something feels wrong, or you're worried, please speak to a healthcare professional."

// MARK: - Library helpers

enum LearnLibrary {
    /// Every article compiled into the app, whether or not it has been released yet.
    ///
    /// Integrity checks scan this — slugs and ids must be unique across the whole set, not just
    /// the visible part. No reader-facing surface should use it; they all use `articles`.
    static let allArticles: [LearnArticle] = learnArticles

    /// What a reader can see today. An article dated in the future is shipped but withheld.
    ///
    /// Every Learn surface — the tab list, search, the Home card, the Sunday nudge, related
    /// links, deep links — resolves through this, so a withheld article is invisible everywhere
    /// at once. That matters most for the deep link: a notification or share URL naming an
    /// article that hasn't landed yet resolves to nil and is ignored, rather than opening a
    /// piece the rest of the app is pretending not to have.
    static var articles: [LearnArticle] { published(asOf: .today()) }

    /// The visible set on a given day. `nil` means an article that has always been here.
    static func published(asOf today: CalendarDate) -> [LearnArticle] {
        allArticles.filter { $0.publishedAt.map { $0 <= today } ?? true }
    }

    static func articleBySlug(_ slug: String) -> LearnArticle? { articles.first { $0.slug == slug } }
    static func articleById(_ id: String) -> LearnArticle? { articles.first { $0.id == id } }

    /// The twelve-week series in week order, including pieces that have not been revealed yet.
    /// The plan page lists the whole run; opening a week still goes through `articleBySlug`,
    /// which only returns a published piece.
    static let weeklySeries: [LearnArticle] = allArticles
        .filter { $0.publishedAt != nil }
        .sorted { ($0.publishedAt ?? CalendarDate(1970, 1, 1)) < ($1.publishedAt ?? CalendarDate(1970, 1, 1)) }

    /// Related articles resolved from hand-authored id lists (unknown ids are dropped).
    static func related(_ article: LearnArticle) -> [LearnArticle] {
        article.relatedArticleIds.compactMap { articleById($0) }
    }

    /// Case-insensitive search over title, excerpt, and tags. Empty query → no results.
    static func search(_ query: String) -> [LearnArticle] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return articles.filter { a in
            a.title.lowercased().contains(q)
                || a.excerpt.lowercased().contains(q)
                || a.tags.contains { $0.lowercased().contains(q) }
        }
    }

    static var featured: LearnArticle? { articles.first { $0.featured } }
}
