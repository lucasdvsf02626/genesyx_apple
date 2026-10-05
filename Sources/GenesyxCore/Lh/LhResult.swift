import Foundation

/// What one ovulation (LH) test strip showed. `rising` is produced only by a strip configuration
/// that enables it, and `unreadable` is never saved: it is here so a screen can switch over one type.
///
/// Raw values are stored locally and on the server: never rename a case.
public enum LhClassification: String, Codable, Sendable, CaseIterable {
    case low, rising, positive, invalid, unreadable
}

/// How an LH result got into the app.
public enum LhResultSource: String, Codable, Sendable {
    case manual, cameraScan
}

/// What a scan measured, kept beside the classification so a result can be traced back to the
/// scanner and strip configuration that read it. The image never is.
public struct LhScanMeasurement: Hashable, Sendable, Codable {
    /// 0...1, line intensity above background.
    public let testSignal: Double
    /// 0...1, line intensity above background.
    public let controlSignal: Double
    /// `testSignal / controlSignal`, computed by the resolver so it cannot disagree with them.
    public let testControlRatio: Double
    /// 0...1, as reported by the analyser.
    public let confidence: Double
    public let scannerVersion: String
    public let configurationID: String
    public let configurationVersion: String

    public init(
        testSignal: Double,
        controlSignal: Double,
        testControlRatio: Double,
        confidence: Double,
        scannerVersion: String,
        configurationID: String,
        configurationVersion: String
    ) {
        self.testSignal = testSignal
        self.controlSignal = controlSignal
        self.testControlRatio = testControlRatio
        self.confidence = confidence
        self.scannerVersion = scannerVersion
        self.configurationID = configurationID
        self.configurationVersion = configurationVersion
    }
}

/// A single logged ovulation test result. It is a record of one test and nothing more: no cycle
/// prediction reads it.
public struct LhResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let recordedAt: Date
    /// A snapshot taken when the result was saved; nil without cycle settings. Never recomputed.
    public let cycleDay: Int?
    public let classification: LhClassification
    /// Nil for a result she typed in.
    public let scan: LhScanMeasurement?

    /// Computed, never stored, so a result cannot claim a source its measurement contradicts.
    public var source: LhResultSource { scan == nil ? .manual : .cameraScan }

    public init(
        id: String = UUID().uuidString,
        recordedAt: Date,
        cycleDay: Int? = nil,
        classification: LhClassification,
        scan: LhScanMeasurement? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.cycleDay = cycleDay
        self.classification = classification
        self.scan = scan
    }
}

/// The cycle-day label on a logged result. A label only: nothing here feeds a prediction.
public enum LhCycleDay {
    /// The 1-based cycle day `date` falls on, or nil when she has no cycle settings.
    public static func snapshot(settings: CycleSettings?, at date: Date, calendar: Calendar = .current) -> Int? {
        guard let settings else { return nil }
        return CycleEngine.cyclePhase(settings: settings, target: CalendarDate.today(calendar, now: date)).dayOfCycle
    }
}
