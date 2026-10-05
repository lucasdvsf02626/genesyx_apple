import Foundation

/// What one pregnancy (hCG) test strip showed. It names the strip, never the person: a line in
/// the test line area was detected, was not detected, or the strip did not work.
///
/// Raw values are stored on the device: never rename a case. There is no `unreadable` case,
/// so an unreadable scan cannot be stored.
public enum HcgClassification: String, Codable, Sendable, CaseIterable {
    case testLineDetected, noTestLineDetected, invalid
}

/// How a result got into the app.
public enum HcgResultSource: String, Codable, Sendable {
    case manual, cameraScan
}

/// Which scanner and strip configuration read a scanned result. No signal, no confidence, no image.
public struct HcgScanProvenance: Hashable, Sendable, Codable {
    public let scannerVersion: String
    public let configurationID: String
    public let configurationVersion: String

    public init(scannerVersion: String, configurationID: String, configurationVersion: String) {
        self.scannerVersion = scannerVersion
        self.configurationID = configurationID
        self.configurationVersion = configurationVersion
    }
}

/// A single saved test result. It is a record of one strip and nothing more: nothing else in the
/// app reads it, and it carries no cycle day.
public struct HcgResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let recordedAt: Date
    public let classification: HcgClassification
    /// Nil for a result she typed in.
    public let scan: HcgScanProvenance?

    /// Computed, never stored, so a result cannot claim a source its provenance contradicts.
    public var source: HcgResultSource { scan == nil ? .manual : .cameraScan }

    public init(
        id: String = UUID().uuidString,
        recordedAt: Date,
        classification: HcgClassification,
        scan: HcgScanProvenance? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.classification = classification
        self.scan = scan
    }
}
