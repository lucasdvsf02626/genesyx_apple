import SwiftUI

/// Genesyx type scale, ported from the Android `ui/theme/Type.kt`.
/// The shipping app intentionally uses Apple's system font so every declared font exists in the
/// bundle and Dynamic Type rendering remains reliable. If brand fonts are added later, bundle and
/// register them first, then change this extension in one place.
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
