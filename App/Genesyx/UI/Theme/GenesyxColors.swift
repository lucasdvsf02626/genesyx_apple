import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Build a color from a 0xRRGGBB hex literal.
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// A light/dark adaptive color (resolves per trait collection on iOS).
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        light
        #endif
    }
}

/// Genesyx semantic + brand palette, ported from the Android `ui/theme/Color.kt`
/// (oklch values pre-computed to sRGB). Semantic tokens adapt to light/dark automatically.
public enum GenesyxColor {

    // Semantic (adaptive)
    public static let background = Color.adaptive(light: Color(hex: 0xF2F2F2), dark: Color(hex: 0x000000))
    public static let card = Color.adaptive(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1F1F1F))
    public static let foreground = Color.adaptive(light: Color(hex: 0x1F1F1F), dark: Color(hex: 0xFFFFFF))
    public static let mutedForeground = Color.adaptive(light: Color(hex: 0x6B6878), dark: Color(hex: 0xB8B5C4))
    public static let muted = Color.adaptive(light: Color(hex: 0xEEEBF1), dark: Color(hex: 0x2A2730))
    public static let secondary = Color.adaptive(light: Color(hex: 0xF2EFF6), dark: Color(hex: 0x2A2730))
    public static let border = Color.adaptive(light: Color(hex: 0xE6E4EC), dark: Color(hex: 0xFFFFFF, alpha: 0.10))
    public static let destructive = Color.adaptive(light: Color(hex: 0xD93636), dark: Color(hex: 0xE0463A))
    public static let primary = Color.adaptive(light: Color(hex: 0x4D4DAA), dark: Color(hex: 0x9B7BD8))
    public static let onPrimary = Color(hex: 0xFFFFFF)

    // Brand palette (same in both modes)
    public static let electricLavender = Color(hex: 0x4D4DAA)
    public static let primaryLight = Color(hex: 0x8B7FE8)
    public static let primaryContainer = Color(hex: 0xC8C0F5)
    public static let powderBlue = Color(hex: 0x8DD2E2) // fertile-window tint
    public static let powderPink = Color(hex: 0xDDA4D3) // period tint
    public static let electricBlue = Color(hex: 0x57A1CE) // hydration accent
    public static let babyLavender = Color(hex: 0x8888D3) // luteal tint
    public static let electricPink = Color(hex: 0xC782D8) // avatar gradient end
    public static let babyPink = Color(hex: 0xDEBED2)

    // pH status colors (use-ph.ts)
    public static let phAcidic = Color(hex: 0xD85A8A)
    public static let phOptimal = Color(hex: 0x3FA37A)
    public static let phAlkaline = Color(hex: 0x4D4DAA)

    // Nutrition focus-food accents (per phase)
    public static let foodPeriod = Color(hex: 0xF48FB1)
    public static let foodFollicular = Color(hex: 0xA5D6A7)
    public static let foodOvulatory = Color(hex: 0xCE93D8)
    public static let foodLuteal = Color(hex: 0xB39DDB)
}
