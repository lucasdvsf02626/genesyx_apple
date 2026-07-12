import SwiftUI

/// Compile-time feature gates (parity with Android `FeatureFlags`).
/// Only `phTracking` is on for v1.0; the rest are dormant-but-present.
enum FeatureFlags {
    static let phTracking = true
    static let adminClients = false
    static let partnerInvites = true
    static let pushNotifications = true
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
    case openLog, openTrack, openNutrition, openInsights, openArticle
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
}

/// Exact medical-disclaimer string (parity with Android `MEDICAL_DISCLAIMER`),
/// shown above the footer on the six flagged articles only.
let MEDICAL_DISCLAIMER = "This is educational content, not medical advice. It can't account for your individual circumstances, and it isn't a substitute for talking to a doctor, nurse, or pharmacist. If something feels wrong, or you're worried, please speak to a healthcare professional."

// MARK: - Library helpers

enum LearnLibrary {
    /// Compile-time constant article set (bundled, not fetched).
    static let articles: [LearnArticle] = learnArticles

    static func articleBySlug(_ slug: String) -> LearnArticle? { articles.first { $0.slug == slug } }
    static func articleById(_ id: String) -> LearnArticle? { articles.first { $0.id == id } }

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
