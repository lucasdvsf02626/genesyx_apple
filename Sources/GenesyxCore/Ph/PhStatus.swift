import Foundation

/// Vaginal pH classification (two-band model). Reference: Android `PhStatus`.
/// UI-free: the status → color mapping lives in the app layer (colors are applied where the
/// status is rendered).
public enum PhStatus: String, CaseIterable, Sendable {
    case healthy, elevated

    public var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .elevated: return "Elevated"
        }
    }

    /// Loggable input floor — client-signed-off 3.8 (the bottom of the healthy band), NOT 3.5.
    public static let min = 3.8
    public static let max = 7.0
    public static let step = 0.1

    /// Two-band model: readings above 4.5 are elevated; 4.5 and below classify as healthy.
    /// Boundaries: 3.8→healthy, 4.5→healthy, 4.51→elevated.
    public static func classify(_ value: Double) -> PhStatus {
        value > 4.5 ? .elevated : .healthy
    }

    /// Clamp a raw value to the loggable range [min, max] (3.8–7.0).
    public static func clamped(_ value: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    /// Where the trend chart's Y axis stops when nothing forces it higher. Chosen so the 4.5
    /// threshold lands on the halfway line: healthy is the bottom half, elevated the top half.
    public static let chartCeiling = 5.2

    /// Visible span of the trend chart — deliberately narrower than the loggable range.
    ///
    /// Scaling to the full 3.8–7.0 put the threshold 78% of the way up, so the chart was mostly
    /// amber and every real reading was crushed into the bottom fifth. Two months of weekly
    /// logging drew a flat line along the floor of a warning-coloured box — the opposite of the
    /// "read the shape, not the point" instruction the Learn guide gives her.
    ///
    /// The floor stays at `min` so charts from different months are comparable at a glance. The
    /// ceiling opens up if she has actually logged above it, because clamping a genuinely high
    /// reading flat against the top would hide the one result that matters most.
    public static func chartDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let highest = values.map(clamped).max(), highest + 0.3 > chartCeiling else {
            return min...chartCeiling
        }
        return min...Swift.min(max, highest + 0.3)
    }
}
