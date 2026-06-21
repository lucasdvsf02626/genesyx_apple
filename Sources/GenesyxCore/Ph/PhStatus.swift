import Foundation

/// Urine pH classification, ported from web `src/hooks/use-ph.ts` and Android `PhStatus`.
/// UI-free: the status → color mapping lives in the app layer (`PhStatus` carried a Compose
/// `Color` on Android; here colors are applied where the status is rendered).
public enum PhStatus: String, CaseIterable, Sendable {
    case acidic, optimal, alkaline

    public var label: String {
        switch self {
        case .acidic: return "Acidic"
        case .optimal: return "Optimal"
        case .alkaline: return "Alkaline"
        }
    }

    public static let min = 4.5
    public static let max = 9.0
    public static let step = 0.1

    public static func classify(_ value: Double) -> PhStatus {
        if value < 6.0 {
            return .acidic
        } else if value > 7.5 {
            return .alkaline
        } else {
            return .optimal
        }
    }
}
