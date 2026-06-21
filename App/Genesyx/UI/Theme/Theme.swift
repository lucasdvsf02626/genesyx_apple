import SwiftUI
import GenesyxCore

/// Maps domain enums (kept UI-free in `GenesyxCore`) to their Genesyx colors.
/// This is the single place color decisions for cycle/pH/nutrition live.
enum Theme {

    /// Calendar day-cell color. Mirrors the Android Track palette:
    /// period→powder-pink, follicular→muted, fertile→powder-blue, ovulation→primary, luteal→baby-lavender.
    static func color(for dayType: DayType) -> Color {
        switch dayType {
        case .period: return GenesyxColor.powderPink
        case .follicular: return GenesyxColor.muted
        case .fertile: return GenesyxColor.powderBlue
        case .ovulation: return GenesyxColor.primary
        case .luteal: return GenesyxColor.babyLavender
        }
    }

    static func color(for status: PhStatus) -> Color {
        switch status {
        case .acidic: return GenesyxColor.phAcidic
        case .optimal: return GenesyxColor.phOptimal
        case .alkaline: return GenesyxColor.phAlkaline
        }
    }

    static func color(for accent: FoodAccent) -> Color {
        switch accent {
        case .period: return GenesyxColor.foodPeriod
        case .follicular: return GenesyxColor.foodFollicular
        case .ovulatory: return GenesyxColor.foodOvulatory
        case .luteal: return GenesyxColor.foodLuteal
        }
    }

    /// Shared card corner radius (Android cards/dialogs use 28).
    static let cardRadius: CGFloat = 28
}
