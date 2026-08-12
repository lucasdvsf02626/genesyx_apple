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

    // Vaginal pH status colors (two-band model)
    public static let phHealthy = Color(hex: 0x3FA37A)   // green — 3.8–4.5
    public static let phElevated = Color(hex: 0xE0952B)  // amber — above 4.5

    // Calendar — phase fills.
    //
    // The light values are the exact composites `tintOnWhite(0.55 / 0.25)` produced over a white
    // card, so light mode is pixel-unchanged. Dark is deliberately not the same trick: mixing a
    // pastel into a #1F1F1F card lands mid-grey, and the day number measured 4.2:1 on the fertile
    // fill — under the 4.5 floor, on the one run of days a conception app exists to show her. These
    // take the same hues *down* instead of up, which keeps the hue and returns the contrast
    // (8.8–10.9:1) while still reading as a tint against the card rather than a block.
    public static let calendarPeriod = Color.adaptive(light: Color(hex: 0xECCDE7), dark: Color(hex: 0x5A3A54))
    public static let calendarFertile = Color.adaptive(light: Color(hex: 0xC0E6EF), dark: Color(hex: 0x24505C))
    public static let calendarLuteal = Color.adaptive(light: Color(hex: 0xE1E1F4), dark: Color(hex: 0x3A3A57))
    /// Ovulation is the one solid cell and carries white text, so it has to stay dark in both
    /// schemes. `primary` cannot do that job: it goes *light* in dark mode (#9B7BD8), where white
    /// on it is 3.4:1.
    public static let calendarOvulation = Color.adaptive(light: Color(hex: 0x4D4DAA), dark: Color(hex: 0x6B4FB8))

    // Marks drawn *on* those fills: the fertile-window ring and the three logging dots.
    //
    // Each needs two variants because no single colour clears 3:1 against both a white card and the
    // solid ovulation fill — the two extremes it has to survive. The bright variant is used on the
    // ovulation cell in both schemes, which is the same flip the day number already makes to white,
    // and doubles as the dark-mode half of each pair below.
    public static let fertileRingBright = Color(hex: 0x8FD3E4)
    public static let markerPhBright = Color(hex: 0x86D2EC)
    public static let markerSymptomsBright = Color(hex: 0xF3C173)
    public static let markerIntimacyBright = Color(hex: 0xEBA9F2)

    public static let fertileRing = Color.adaptive(light: Color(hex: 0x1B6C80), dark: fertileRingBright)
    public static let markerPh = Color.adaptive(light: Color(hex: 0x1F6E93), dark: markerPhBright)
    public static let markerSymptoms = Color.adaptive(light: Color(hex: 0x9A5B12), dark: markerSymptomsBright)
    public static let markerIntimacy = Color.adaptive(light: Color(hex: 0x8E3FA3), dark: markerIntimacyBright)

    // Nutrition focus-food accents (per phase)
    public static let foodPeriod = Color(hex: 0xF48FB1)
    public static let foodFollicular = Color(hex: 0xA5D6A7)
    public static let foodOvulatory = Color(hex: 0xCE93D8)
    public static let foodLuteal = Color(hex: 0xB39DDB)
}
