import Foundation

/// Display unit for hydration. Storage is ALWAYS millilitres (`DailyLog.waterMl`); this enum only
/// affects presentation. 1 glass = 250 ml, 1 cup = 240 ml (client/Android parity). Glasses is the
/// default primary unit; millilitres and cups are the other options offered in settings.
public enum HydrationUnit: String, CaseIterable, Sendable, Identifiable {
    case milliliters, glasses, cups
    public var id: String { rawValue }

    public static let mlPerGlass = 250
    public static let mlPerCup = 240

    /// Millilitres per one unit; nil for the base millilitre unit.
    public var mlPerUnit: Int? {
        switch self {
        case .milliliters: return nil
        case .glasses: return HydrationUnit.mlPerGlass
        case .cups: return HydrationUnit.mlPerCup
        }
    }

    /// Settings/menu label.
    public var settingsLabel: String {
        switch self {
        case .milliliters: return "Millilitres"
        case .glasses: return "Glasses"
        case .cups: return "Cups"
        }
    }

    /// Singular / plural noun used in amounts.
    public var noun: (one: String, many: String) {
        switch self {
        case .milliliters: return ("ml", "ml")
        case .glasses: return ("glass", "glasses")
        case .cups: return ("cup", "cups")
        }
    }
}

/// Pure display formatting for hydration volumes. No storage/rounding of the underlying ml value.
public enum HydrationFormat {
    /// Millilitres as a (possibly fractional) count of the given unit. For millilitres, returns ml.
    public static func units(fromMl ml: Int, unit: HydrationUnit) -> Double {
        guard let per = unit.mlPerUnit else { return Double(ml) }
        return Double(ml) / Double(per)
    }

    /// Back-compat convenience: millilitres as glasses.
    public static func glasses(fromMl ml: Int) -> Double { units(fromMl: ml, unit: .glasses) }

    private static func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    /// Bare unit count (no unit word), for compact tiles, e.g. "2" or "1.5". For ml, the integer ml.
    public static func trimmedUnits(fromMl ml: Int, unit: HydrationUnit) -> String {
        unit == .milliliters ? "\(ml)" : trimmed(units(fromMl: ml, unit: unit))
    }

    /// A single amount in the chosen unit, e.g. "2 glasses", "1 cup", "500 ml".
    public static func amount(ml: Int, unit: HydrationUnit) -> String {
        if unit == .milliliters { return "\(ml) ml" }
        let v = units(fromMl: ml, unit: unit)
        return "\(trimmed(v)) \(v == 1 ? unit.noun.one : unit.noun.many)"
    }

    /// A progress readout in the chosen unit, e.g. "2 / 10 glasses", "2 / 10 cups", "500 / 2400 ml".
    public static func progress(ml: Int, goalMl: Int, unit: HydrationUnit) -> String {
        if unit == .milliliters { return "\(ml) / \(goalMl) ml" }
        return "\(trimmedUnits(fromMl: ml, unit: unit)) / \(trimmedUnits(fromMl: goalMl, unit: unit)) \(unit.noun.many)"
    }
}
