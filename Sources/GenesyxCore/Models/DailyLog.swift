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

    /// Whether she recorded sexual activity on this day.
    ///
    /// A plain flag, not protected/unprotected: this is a conception-prep app, so the question the
    /// data answers is whether it fell inside the fertile window. Contraception status is a
    /// different product.
    ///
    /// `false` means nothing recorded, the same collapse `waterMl == 0` and an empty `symptoms`
    /// already make — the log sheet offers one toggle, so there is no third state for it to carry.
    ///
    /// The most sensitive field in the app. It is never sent to a partner (`PartnerRepository`
    /// exchanges display names only) and never reaches notification copy, which lands on a lock
    /// screen anyone holding the phone can read.
    public var sexualActivity: Bool

    public init(
        mood: Mood? = nil,
        energy: EnergyLevel? = nil,
        symptoms: Set<String> = [],
        sleepMinutes: Int? = nil,
        supplements: Set<String> = [],
        notes: String? = nil,
        waterMl: Int = 0,
        sexualActivity: Bool = false
    ) {
        self.mood = mood
        self.energy = energy
        self.symptoms = symptoms
        self.sleepMinutes = sleepMinutes
        self.supplements = supplements
        self.notes = notes
        self.waterMl = waterMl
        self.sexualActivity = sexualActivity
    }
}
