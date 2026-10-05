import Foundation

/// What a pH reading measured. Mirrors the Supabase `ph_readings.measurement_type` column
/// (`text NOT NULL DEFAULT 'urine'`, CHECK in {'urine','vaginal'}). `urine` is the legacy value;
/// every reading written by the migrated app is `vaginal`.
public enum PhMeasurementType: String, Codable, Sendable, CaseIterable {
    case urine, vaginal
}

/// How a pH reading got into the app. Readings written before scanning existed carry no source
/// and are `.manual`.
public enum PhReadingSource: String, Codable, Sendable {
    case manual, cameraScan
}

/// What produced a scanned reading, kept beside the value so a result can be traced back to the
/// scanner and strip configuration that read it. Only the value and this metadata are stored;
/// the image never is.
public struct PhScanMetadata: Hashable, Sendable, Codable {
    public let scannerVersion: String
    public let configurationID: String
    public let configurationVersion: String
    /// 0...1, as reported by the analyser.
    public let confidence: Double

    public init(scannerVersion: String, configurationID: String, configurationVersion: String, confidence: Double) {
        self.scannerVersion = scannerVersion
        self.configurationID = configurationID
        self.configurationVersion = configurationVersion
        self.confidence = confidence
    }
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
    /// Typed in by her unless a scan says otherwise.
    public let source: PhReadingSource
    /// Non-nil only when `source == .cameraScan`.
    public let scan: PhScanMetadata?

    public init(
        id: String = UUID().uuidString,
        phValue: Double,
        recordedAt: Date,
        notes: String? = nil,
        measurementType: PhMeasurementType = .vaginal,
        source: PhReadingSource = .manual,
        scan: PhScanMetadata? = nil
    ) {
        self.id = id
        self.phValue = phValue
        self.recordedAt = recordedAt
        self.notes = notes
        self.measurementType = measurementType
        self.source = source
        self.scan = scan
    }
}
