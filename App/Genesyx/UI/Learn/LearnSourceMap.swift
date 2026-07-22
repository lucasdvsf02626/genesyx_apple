import Foundation

/// Maps a Learn article slug to the medical sources that substantiate its health claims
/// (Guideline 1.4.1). Only articles that state external health facts appear here; behavioural
/// or methodology articles rely on the existing medical disclaimer alone.
/// Keys MUST match the `slug` values in `LearnContent.swift` exactly.
enum LearnSourceMap {
    static let bySlug: [String: [String]] = [
        "hydration-basics": ["nhs-water", "valtin-2002", "efsa-water"],
        "eating-with-your-cycle": ["nhs-periods", "nhs-iron", "nhs-eatwell"],
        "gentle-guide-supplements": ["nhs-preconception", "nhs-vitamin-b", "nhs-vitamin-d"],
        "guide-urine-tracker-with-stick": ["vaginal-ph", "statpearls-vaginitis"],
        "guide-how-to-log-ph": ["vaginal-ph", "statpearls-vaginitis"],
        "guide-nutrition-focus": ["nhs-periods", "nhs-eatwell"],
        "guide-how-hydration-works": ["nhs-water", "armstrong-2012"],
        "guide-track-ph-in-nutrition": ["vaginal-ph", "statpearls-vaginitis"],
    ]

    /// Sources for a slug, or nil when the article carries no external health-fact claims.
    static func sources(for slug: String) -> [String]? { bySlug[slug] }
}
