import Foundation

/// What a pH reading measured. Mirrors the Supabase `ph_readings.measurement_type` column
/// (`text NOT NULL DEFAULT 'urine'`, CHECK in {'urine','vaginal'}). `urine` is the legacy value;
/// every reading written by the migrated app is `vaginal`.
public enum PhMeasurementType: String, Codable, Sendable, CaseIterable {
    case urine, vaginal
}

/// A single pH reading. Mirrors `ph_readings` (see docs/DATA_LAYER.md ph.functions).
/// `recordedAt` is a wall-clock instant; the Android model uses `LocalDateTime`.
public struct PhReading: Identifiable, Hashable, Sendable {
    public let id: String
    public let phValue: Double
    public let recordedAt: Date
    public let notes: String?
    /// New readings are `.vaginal`; rows decoded without the field are `.urine` (legacy).
    public let measurementType: PhMeasurementType

    public init(
        id: String = UUID().uuidString,
        phValue: Double,
        recordedAt: Date,
        notes: String? = nil,
        measurementType: PhMeasurementType = .vaginal
    ) {
        self.id = id
        self.phValue = phValue
        self.recordedAt = recordedAt
        self.notes = notes
        self.measurementType = measurementType
    }
}
