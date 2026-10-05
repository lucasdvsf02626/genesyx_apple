import Foundation

/// What an analyser believes it measured on an LH strip. An estimate, not yet a result:
/// `LhScanResolver` decides whether it is good enough to show her. It carries the two signals
/// only; the ratio is the resolver's to compute.
public struct LhAnalysisResult: Hashable, Sendable {
    /// 0...1, line intensity above background.
    public let testSignal: Double
    /// 0...1, line intensity above background.
    public let controlSignal: Double
    /// 0...1.
    public let confidence: Double
    public let qualityFlags: [ScanQualityIssue]
    public let configurationID: String
    public let configurationVersion: String

    public init(
        testSignal: Double,
        controlSignal: Double,
        confidence: Double,
        qualityFlags: [ScanQualityIssue] = [],
        configurationID: String,
        configurationVersion: String
    ) {
        self.testSignal = testSignal
        self.controlSignal = controlSignal
        self.confidence = confidence
        self.qualityFlags = qualityFlags
        self.configurationID = configurationID
        self.configurationVersion = configurationVersion
    }
}

public enum LhAnalysisOutcome: Hashable, Sendable {
    case result(LhAnalysisResult)
    case unreadable([ScanQualityIssue])
}

/// What the flow may act on. A `.reading` is only ever low, rising or positive. `.invalid` means
/// the scan was sure the control line is missing; `.unreadable` means it was not sure of anything.
public enum LhScanResolution: Hashable, Sendable {
    case reading(LhClassification, LhScanMeasurement)
    case invalid
    case unreadable([ScanQualityIssue])

    public var classification: LhClassification {
        switch self {
        case .reading(let classification, _): return classification
        case .invalid: return .invalid
        case .unreadable: return .unreadable
        }
    }
}

/// The one place an analyser's estimate becomes an LH result, or does not.
///
/// The rule is that uncertainty never turns into a result. Every threshold is the
/// configuration's: nothing here assumes what ratio means positive.
public enum LhScanResolver {
    public static let scannerVersion = "0.1.0"

    /// Checked in this order, the first match deciding:
    /// 1. the analyser said unreadable (its issues pass through);
    /// 2. the result was produced under another configuration id or version: unreadable, because
    ///    a result judged against thresholds it was not produced under is not a result;
    /// 3. the configuration is not usable: unreadable;
    /// 4. the result carries any quality flag, however confident it is: unreadable (the flags
    ///    pass through);
    /// 5. the confidence is not finite, is outside `0...1`, or is below the configuration's
    ///    minimum: unreadable;
    /// 6. either signal is not finite or is outside `0...1`: unreadable, never clamped;
    /// 7. the control signal is below the configuration's minimum: invalid, whatever the test
    ///    signal is, so a test line with no control is never positive;
    /// 8. the test to control ratio is at or above the positive threshold: positive;
    /// 9. rising is enabled and the ratio is at or above the rising threshold: rising;
    /// 10. otherwise low.
    ///
    /// 5 comes before 7 because invalid is a confident statement: it tells her the strip failed
    /// and to use a new one. An uncertain read of a missing control line is unreadable instead.
    /// An empty issue list means unreadable for no reason the screen can name. A reading's
    /// measurement names the configuration it was resolved against.
    public static func resolve(_ outcome: LhAnalysisOutcome, configuration: LhStripConfiguration) -> LhScanResolution {
        let result: LhAnalysisResult
        switch outcome {
        case .unreadable(let issues): return .unreadable(issues)
        case .result(let analysed): result = analysed
        }

        guard result.configurationID == configuration.id,
              result.configurationVersion == configuration.version,
              configuration.isUsable else {
            return .unreadable([])
        }
        guard result.qualityFlags.isEmpty else {
            return .unreadable(result.qualityFlags)
        }
        // Written as `>=` so a NaN confidence fails the test instead of slipping past a `<`. The
        // `0...1` checks stop a percent-scale 85 from passing as certainty or as a signal.
        guard result.confidence.isFinite, (0.0...1.0).contains(result.confidence),
              result.confidence >= configuration.minimumConfidence,
              result.testSignal.isFinite, (0.0...1.0).contains(result.testSignal),
              result.controlSignal.isFinite, (0.0...1.0).contains(result.controlSignal) else {
            return .unreadable([])
        }
        guard result.controlSignal >= configuration.minimumControlSignal else {
            return .invalid
        }

        // A usable configuration's minimum control signal is above zero, so this never divides by zero.
        let ratio = result.testSignal / result.controlSignal
        let measurement = LhScanMeasurement(
            testSignal: result.testSignal,
            controlSignal: result.controlSignal,
            testControlRatio: ratio,
            confidence: result.confidence,
            scannerVersion: scannerVersion,
            configurationID: configuration.id,
            configurationVersion: configuration.version
        )
        if ratio >= configuration.positiveThreshold {
            return .reading(.positive, measurement)
        }
        if configuration.risingEnabled, ratio >= configuration.risingThreshold {
            return .reading(.rising, measurement)
        }
        return .reading(.low, measurement)
    }
}
