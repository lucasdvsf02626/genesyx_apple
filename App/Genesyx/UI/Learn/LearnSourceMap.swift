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
        "guide-vaginal-ph-tracker": ["vaginal-ph", "statpearls-vaginitis"],
        "guide-how-to-log-ph": ["vaginal-ph", "statpearls-vaginitis"],
        "guide-nutrition-focus": ["nhs-periods", "nhs-eatwell"],
        "guide-how-hydration-works": ["nhs-water", "armstrong-2012"],
        "guide-track-ph-in-nutrition": ["vaginal-ph", "statpearls-vaginitis"],

        // The twelve-week series. Every piece states external health facts, so every piece is
        // cited — they are withheld by date, not by readiness, and the citation must be in
        // place in the build that ships them, not added later.
        "fertile-window": ["nhs-conception", "nhs-periods"],
        "vaginal-ph-explained": ["vaginal-ph", "statpearls-vaginitis"],
        "nutrition-before-conception": ["nhs-preconception", "nhs-vitamin-b", "nhs-vitamin-d", "nhs-eatwell"],
        "cervical-mucus": ["nhs-conception", "nhs-periods"],
        "hydration-and-reproductive-health": ["nhs-water", "efsa-water", "armstrong-2012"],
        "timing-sex-when-ttc": ["nhs-conception"],
        "sleep-stress-and-your-cycle": ["nhs-sleep", "nhs-stress"],
        "understanding-ovulation-tests": ["nhs-conception", "nhs-periods"],
        "supporting-sperm-health": ["nhs-infertility", "nhs-preconception"],
        "fertility-supplements-explained": ["nhs-preconception", "nhs-vitamin-b", "nhs-vitamin-d", "nhs-vitamins"],
        "when-to-ask-for-support": ["nhs-infertility", "nhs-conception"],
    ]

    /// Sources for a slug, or nil when the article carries no external health-fact claims.
    static func sources(for slug: String) -> [String]? { bySlug[slug] }
}
