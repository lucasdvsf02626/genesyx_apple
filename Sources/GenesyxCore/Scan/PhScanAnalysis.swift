import Foundation

/// Why a frame or a captured image is not good enough to read. Shared by the live guidance and
/// the analyser, so the same problem is described the same way before and after capture.
public enum ScanQualityIssue: String, Sendable, CaseIterable, Codable {
    case noStrip, partialStrip, tooFar, tooClose, badAngle, tooDark, overexposed, glare, blurred, moving
    case multipleStrips, unrecognisedStrip, reagentAreaNotFound
}

/// The colour sampled from one reagent pad. `regionIndex` indexes the configuration's
/// `reagentRegions`.
public struct PhPadMeasurement: Hashable, Sendable {
    public let regionIndex: Int
    public let colour: LabColour

    public init(regionIndex: Int, colour: LabColour) {
        self.regionIndex = regionIndex
        self.colour = colour
    }
}

/// What an analyser believes it read. An estimate, not yet a reading: `PhScanResolver` decides
/// whether it is good enough to show her.
public struct PhAnalysisResult: Hashable, Sendable {
    public let estimatedPH: Double
    /// 0...1.
    public let confidence: Double
    public let padMeasurements: [PhPadMeasurement]
    public let qualityFlags: [ScanQualityIssue]
    public let configurationID: String
    public let configurationVersion: String

    public init(
        estimatedPH: Double,
        confidence: Double,
        padMeasurements: [PhPadMeasurement] = [],
        qualityFlags: [ScanQualityIssue] = [],
        configurationID: String,
        configurationVersion: String
    ) {
        self.estimatedPH = estimatedPH
        self.confidence = confidence
        self.padMeasurements = padMeasurements
        self.qualityFlags = qualityFlags
        self.configurationID = configurationID
        self.configurationVersion = configurationVersion
    }
}

public enum PhAnalysisOutcome: Hashable, Sendable {
    case result(PhAnalysisResult)
    case unreadable([ScanQualityIssue])
}

/// What the flow may act on. A `.reading` value is already rounded to 0.1 and inside
/// `PhStatus.min...PhStatus.max`, so it can go to `PhRepository.create` as it stands.
public enum PhScanResolution: Hashable, Sendable {
    case reading(value: Double, metadata: PhScanMetadata)
    case unreadable([ScanQualityIssue])
}

/// The one place an analyser's estimate becomes a reading, or does not.
///
/// The rule is that uncertainty never turns into a result. A manual entry can be clamped into the
/// loggable range because she chose the number; a scanned value outside it means the scan was
/// wrong, and clamping would hand her a confident-looking 7.0 that nobody measured.
public enum PhScanResolver {
    public static let scannerVersion = "0.1.0"

    /// Unreadable, checked in this order, when:
    /// 1. the analyser said so (its issues pass through);
    /// 2. the result was produced under another configuration id or version, because a result
    ///    judged against thresholds it was not produced under is not a reading;
    /// 3. the result carries any quality flag, however confident it is (the flags pass through);
    /// 4. the confidence is not finite, is outside `0...1`, or is below the configuration's minimum;
    /// 5. the estimate is not finite, or rounds to a value outside `PhStatus.min...PhStatus.max`.
    /// Never clamped, never defaulted. An empty issue list means unreadable for no reason the
    /// screen can name.
    ///
    /// Rounding is the app's own (`PhRepository.round1`), so the value shown on the result screen
    /// is the value that gets saved. The range is checked after rounding: 3.75 rounds to 3.8 and
    /// is a reading, 3.74 rounds to 3.7 and is not. A reading's metadata names the configuration
    /// it was resolved against.
    public static func resolve(_ outcome: PhAnalysisOutcome, configuration: PhStripConfiguration) -> PhScanResolution {
        let result: PhAnalysisResult
        switch outcome {
        case .unreadable(let issues): return .unreadable(issues)
        case .result(let analysed): result = analysed
        }

        guard result.configurationID == configuration.id,
              result.configurationVersion == configuration.version else {
            return .unreadable([])
        }
        guard result.qualityFlags.isEmpty else {
            return .unreadable(result.qualityFlags)
        }
        // Written as `>=` so a NaN confidence fails the test instead of slipping past a `<`. The
        // `0...1` check stops a percent-scale 85 from passing as certainty.
        guard result.confidence.isFinite, (0.0...1.0).contains(result.confidence),
              result.confidence >= configuration.minimumConfidence,
              result.estimatedPH.isFinite else {
            return .unreadable([])
        }
        let rounded = (result.estimatedPH * 10).rounded() / 10
        guard (PhStatus.min...PhStatus.max).contains(rounded) else {
            return .unreadable([])
        }
        return .reading(
            value: rounded,
            metadata: PhScanMetadata(
                scannerVersion: scannerVersion,
                configurationID: configuration.id,
                configurationVersion: configuration.version,
                confidence: result.confidence
            )
        )
    }
}
