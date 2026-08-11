import Foundation
import GenesyxCore

/// How she wants water shown: which unit, and — for glasses — how big her glass is (T23).
///
/// Both are device-local, deliberately. `hydration_unit` already was, read straight from
/// `UserDefaults` by Home, Track, Nutrition and Profile, so syncing the glass size alone would be
/// incoherent: she would arrive on a new phone with her 300 ml glass honoured but the unit reset to
/// millilitres, where a glass size means nothing. Moving *both* to her `profiles` row is a single
/// coherent change to make with Android, not half of one to make here.
///
/// This type exists so the two keys are read in one place. Before T23 the unit was re-read from
/// `UserDefaults` at four separate call sites; adding a second key would have doubled that.
enum HydrationPrefs {
    static let unitKey = "hydration_unit"
    static let glassMlKey = "hydration_glass_ml"

    /// `UserDefaults` returns 0 for an absent Int, and 0 is outside `glassRangeMl`, so an unset
    /// glass size resolves to the 250 ml default by both routes. Normalised here anyway so the
    /// intent is stated rather than relied upon.
    static func glassMl(from stored: Int) -> Int {
        HydrationUnit.resolvedGlassMl(stored == 0 ? nil : stored)
    }

    /// The current settings, for the non-`View` call sites that cannot use `@AppStorage`.
    static var current: (unit: HydrationUnit, glassMl: Int) {
        let raw = UserDefaults.standard.string(forKey: unitKey) ?? ""
        return (HydrationUnit(rawValue: raw) ?? .glasses,
                glassMl(from: UserDefaults.standard.integer(forKey: glassMlKey)))
    }
}
