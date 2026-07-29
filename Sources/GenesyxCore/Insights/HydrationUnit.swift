import Foundation

/// Display unit for hydration. Storage is ALWAYS millilitres (`DailyLog.waterMl`); this enum only
/// affects presentation. 1 glass = 250 ml (client/Android parity). Glasses is the default primary
/// unit; millilitres is the secondary option offered in settings.
public enum HydrationUnit: String, CaseIterable, Sendable, Identifiable {
    case glasses, milliliters
    public var id: String { rawValue }

    public static let mlPerGlass = 250

    /// Settings label.
    public var settingsLabel: String { self == .glasses ? "Glasses" : "Millilitres" }
}

/// Pure display formatting for hydration volumes. No storage/rounding of the underlying ml value.
public enum HydrationFormat {
    /// Millilitres as a (possibly fractional) glass count.
    public static func glasses(fromMl ml: Int) -> Double { Double(ml) / Double(HydrationUnit.mlPerGlass) }

    private static func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    /// Bare glass count (no unit word), for compact tiles, e.g. "2" or "1.5".
    public static func trimmedGlasses(fromMl ml: Int) -> String { trimmed(glasses(fromMl: ml)) }

    /// A single amount in the chosen unit, e.g. "2 glasses", "1.5 glasses", "1 glass", "500 ml".
    public static func amount(ml: Int, unit: HydrationUnit) -> String {
        switch unit {
        case .milliliters:
            return "\(ml) ml"
        case .glasses:
            let g = glasses(fromMl: ml)
            return "\(trimmed(g)) \(g == 1 ? "glass" : "glasses")"
        }
    }

    /// A progress readout in the chosen unit, e.g. "2 / 10 glasses" or "500 / 2400 ml".
    public static func progress(ml: Int, goalMl: Int, unit: HydrationUnit) -> String {
        switch unit {
        case .milliliters:
            return "\(ml) / \(goalMl) ml"
        case .glasses:
            return "\(trimmed(glasses(fromMl: ml))) / \(trimmed(glasses(fromMl: goalMl))) glasses"
        }
    }
}
