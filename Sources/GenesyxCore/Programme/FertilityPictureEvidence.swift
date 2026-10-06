import Foundation

// The evidence vocabulary shared by My Fertility Picture and the Programme Reviews. Value types and
// two pieces of copy; no rules. Each surface decides what it can support and tags it with a level.

/// How much recorded data stands behind a statement. A statement is made at a level only when
/// that level's minimum data exists; below it, nothing is said at that level.
public enum ProgrammeEvidenceLevel: Int, CaseIterable, Comparable, Sendable {
    /// One recorded fact.
    case observation = 1
    /// Something counted inside one week, or between two weeks next to each other.
    case withinWeekTrend = 2
    /// Something counted inside one recorded cycle.
    case withinCyclePattern = 3
    /// Something that holds across several recorded cycles.
    case crossCyclePattern = 4

    public static func < (lhs: ProgrammeEvidenceLevel, rhs: ProgrammeEvidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One supported statement and the level of evidence behind it.
public struct ProgrammeEvidenceStatement: Hashable, Sendable {
    public let level: ProgrammeEvidenceLevel
    public let text: String

    public init(level: ProgrammeEvidenceLevel, text: String) {
        self.level = level
        self.text = text
    }
}

/// The copy the evidence levels share. Scanned by the guard tests of both surfaces.
public enum ProgrammeEvidenceCopy {
    /// Shown once, in place of what cannot be said yet.
    public static let stillLearning = "We're still learning your pattern. Continue tracking to build a clearer picture over time."

    public static func title(for level: ProgrammeEvidenceLevel) -> String {
        switch level {
        case .observation: return "Observation"
        case .withinWeekTrend: return "Within-week trend"
        case .withinCyclePattern: return "Within-cycle pattern"
        case .crossCyclePattern: return "Cross-cycle pattern"
        }
    }

    public static let allSurfaces: [String] = [stillLearning] + ProgrammeEvidenceLevel.allCases.map(title(for:))
}
