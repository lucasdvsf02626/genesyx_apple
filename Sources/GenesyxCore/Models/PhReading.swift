import Foundation

/// A single urine-pH reading. Mirrors `ph_readings` (see docs/DATA_LAYER.md ph.functions).
/// `recordedAt` is a wall-clock instant; the Android model uses `LocalDateTime`.
public struct PhReading: Identifiable, Hashable, Sendable {
    public let id: String
    public let phValue: Double
    public let recordedAt: Date
    public let notes: String?

    public init(
        id: String = UUID().uuidString,
        phValue: Double,
        recordedAt: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.phValue = phValue
        self.recordedAt = recordedAt
        self.notes = notes
    }
}
