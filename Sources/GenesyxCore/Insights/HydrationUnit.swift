import Foundation

/// Display unit for hydration. Storage is ALWAYS millilitres (`DailyLog.waterMl`); this enum only
/// affects presentation. 1 glass = 250 ml, 1 cup = 240 ml (client/Android parity). Glasses is the
/// default primary unit; millilitres and cups are the other options offered in settings.
///
/// Since T23 the glass — and only the glass — can be sized by her, because a glass is a real object
/// in her kitchen and 250 ml is a guess about it. A cup stays fixed: it is a recipe measure, not
/// something she owns. Storage is unaffected either way, so a custom size can never make a logged
/// volume wrong — it changes only the number of glasses that volume is described as.
public enum HydrationUnit: String, CaseIterable, Sendable, Identifiable {
    case milliliters, glasses, cups
    public var id: String { rawValue }

    public static let mlPerGlass = 250
    public static let mlPerCup = 240

    /// Bounds for a glass she sizes herself. Under 50 ml the readout stops meaning anything (a 2 l
    /// day becomes 40-odd glasses); over 1000 ml it is not a glass. Out-of-range values fall back to
    /// the 250 ml default rather than being clamped — a clamp would quietly rewrite her setting to a
    /// number she never chose, where the fallback leaves the visible default in place.
    public static let glassRangeMl = 50...1000

    /// A stored glass size, or the 250 ml default when it is absent or out of range. The single
    /// place that decision is made, so every surface agrees on it — and the rule Android mirrors.
    public static func resolvedGlassMl(_ ml: Int?) -> Int {
        guard let ml, glassRangeMl.contains(ml) else { return mlPerGlass }
        return ml
    }

    /// Millilitres per one unit; nil for the base millilitre unit.
    ///
    /// A method rather than a property so that adding a custom glass size could not leave a call
    /// site silently reading 250 ml: every existing caller had to be visited to keep compiling.
    /// `glassMl` is ignored by `.milliliters` and `.cups`.
    public func mlPerUnit(glassMl: Int = HydrationUnit.mlPerGlass) -> Int? {
        switch self {
        case .milliliters: return nil
        case .glasses: return HydrationUnit.resolvedGlassMl(glassMl)
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
///
/// `glassMl` defaults to the standard 250 ml throughout, so a caller that has no custom size — and
/// every caller outside the hydration surfaces — reads exactly as it did before T23.
public enum HydrationFormat {
    /// Millilitres as a (possibly fractional) count of the given unit. For millilitres, returns ml.
    public static func units(fromMl ml: Int, unit: HydrationUnit,
                             glassMl: Int = HydrationUnit.mlPerGlass) -> Double {
        guard let per = unit.mlPerUnit(glassMl: glassMl) else { return Double(ml) }
        return Double(ml) / Double(per)
    }

    /// Back-compat convenience: millilitres as glasses.
    public static func glasses(fromMl ml: Int, glassMl: Int = HydrationUnit.mlPerGlass) -> Double {
        units(fromMl: ml, unit: .glasses, glassMl: glassMl)
    }

    private static func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    /// Bare unit count (no unit word), for compact tiles, e.g. "2" or "1.5". For ml, the integer ml.
    public static func trimmedUnits(fromMl ml: Int, unit: HydrationUnit,
                                    glassMl: Int = HydrationUnit.mlPerGlass) -> String {
        unit == .milliliters ? "\(ml)" : trimmed(units(fromMl: ml, unit: unit, glassMl: glassMl))
    }

    /// A single amount in the chosen unit, e.g. "2 glasses", "1 cup", "500 ml".
    public static func amount(ml: Int, unit: HydrationUnit,
                              glassMl: Int = HydrationUnit.mlPerGlass) -> String {
        if unit == .milliliters { return "\(ml) ml" }
        let v = units(fromMl: ml, unit: unit, glassMl: glassMl)
        return "\(trimmed(v)) \(v == 1 ? unit.noun.one : unit.noun.many)"
    }

    /// A progress readout in the chosen unit, e.g. "2 / 10 glasses", "2 / 10 cups", "500 / 2400 ml".
    public static func progress(ml: Int, goalMl: Int, unit: HydrationUnit,
                                glassMl: Int = HydrationUnit.mlPerGlass) -> String {
        if unit == .milliliters { return "\(ml) / \(goalMl) ml" }
        return "\(trimmedUnits(fromMl: ml, unit: unit, glassMl: glassMl)) / \(trimmedUnits(fromMl: goalMl, unit: unit, glassMl: glassMl)) \(unit.noun.many)"
    }
}
