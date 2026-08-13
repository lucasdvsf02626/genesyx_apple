import SwiftUI

/// Genesyx type scale, ported from the Android `ui/theme/Type.kt`.
///
/// These are fixed point sizes. `Font.system(size:)` takes no part in Dynamic Type, so Larger Text
/// in iOS Settings changes nothing here, nor at the ~150 other places that size their own text.
/// Supporting it means `@ScaledMetric` behind these nine names, and the two screens that lay
/// themselves out with flexible spacers — the splash and the quiz — learning to scroll, which today
/// they have no need to do.
///
/// If brand fonts are added later, bundle and register them first, then change this in one place.
extension Font {
    static let gxDisplayLarge = Font.system(size: 32, weight: .semibold) // splash CTA / nutrition title
    static let gxTitle = Font.system(size: 26, weight: .semibold)        // screen title / quiz question
    static let gxCardHeading = Font.system(size: 18, weight: .semibold)
    static let gxCardHeadingSmall = Font.system(size: 16, weight: .semibold)
    static let gxBody = Font.system(size: 15)
    static let gxBodySmall = Font.system(size: 13.5)
    static let gxLabel = Font.system(size: 14, weight: .semibold)
    static let gxEyebrow = Font.system(size: 11, weight: .medium)        // ALL-CAPS section label (use .tracking)
    static let gxPhValue = Font.system(size: 48, weight: .semibold)
}
