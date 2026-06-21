import Foundation

/// Mood options shown on Log Today (web ids: great/good/ok/low).
public enum Mood: String, CaseIterable, Sendable {
    case great, good, okay, low

    /// Stable id persisted to storage (note: `okay` persists as "ok", matching the web/Android).
    public var id: String {
        switch self {
        case .great: return "great"
        case .good: return "good"
        case .okay: return "ok"
        case .low: return "low"
        }
    }

    public var label: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .okay: return "Okay"
        case .low: return "Low"
        }
    }
}

/// Energy level segmented control (web: low/normal/high).
public enum EnergyLevel: String, CaseIterable, Sendable {
    case low, normal, high

    public var id: String { rawValue }
}

/// A full daily log entry. Mirrors `daily_logs` (docs/DATA_LAYER.md).
public struct DailyLog: Hashable, Sendable {
    public var mood: Mood?
    public var energy: EnergyLevel?
    public var symptoms: Set<String>
    public var sleepMinutes: Int?
    public var supplements: Set<String>
    public var notes: String?
    public var waterMl: Int

    public init(
        mood: Mood? = nil,
        energy: EnergyLevel? = nil,
        symptoms: Set<String> = [],
        sleepMinutes: Int? = nil,
        supplements: Set<String> = [],
        notes: String? = nil,
        waterMl: Int = 0
    ) {
        self.mood = mood
        self.energy = energy
        self.symptoms = symptoms
        self.sleepMinutes = sleepMinutes
        self.supplements = supplements
        self.notes = notes
        self.waterMl = waterMl
    }
}
