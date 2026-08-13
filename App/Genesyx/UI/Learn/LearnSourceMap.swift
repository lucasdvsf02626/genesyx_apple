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
        "guide-cycle-and-phases": ["nhs-periods", "nhs-conception"],
        "guide-understanding-vaginal-ph": ["vaginal-ph", "statpearls-vaginitis"],

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
        // The piece that says a widely-repeated theory is not supported needs its citation more
        // than any of the others, not less: "there is no good evidence for this" is itself a claim
        // about the literature, and a reader who has been told the opposite for years is owed the
        // study rather than our word for it.
        "shettles-method": ["wilcox-1995", "nhs-conception"],
    ]

    /// Sources for a slug, or nil when the article carries no external health-fact claims.
    static func sources(for slug: String) -> [String]? { bySlug[slug] }
}
