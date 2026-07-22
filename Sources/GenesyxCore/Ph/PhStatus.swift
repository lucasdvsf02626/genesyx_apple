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

    public static let min = 3.5
    public static let max = 7.0
    public static let step = 0.1

    /// Two-band model: readings above 4.5 are elevated; 4.5 and below (including any below the
    /// healthy band's 3.8 floor) classify as healthy. Boundaries: 3.8→healthy, 4.5→healthy,
    /// 4.51→elevated.
    public static func classify(_ value: Double) -> PhStatus {
        value > 4.5 ? .elevated : .healthy
    }
}
