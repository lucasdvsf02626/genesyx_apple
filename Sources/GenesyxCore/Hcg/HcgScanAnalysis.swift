import Foundation

/// What an analyser believes it measured on a pregnancy (hCG) strip. An estimate, not yet a
/// result: `HcgScanResolver` decides whether it is good enough to show her.
public struct HcgAnalysisResult: Hashable, Sendable {
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

public enum HcgAnalysisOutcome: Hashable, Sendable {
    case result(HcgAnalysisResult)
    case unreadable([ScanQualityIssue])
}

/// Why a scan could not be read.
public enum HcgUnreadableReason: Hashable, Sendable {
    /// Empty: unreadable for no reason the screen can name.
    case quality([ScanQualityIssue])
    /// The test signal fell inside the configuration's band.
    case indeterminateTestLine
}

/// What the flow may act on. A `.reading` is only ever `testLineDetected` or
/// `noTestLineDetected`. `.invalid` means the scan was sure the control line is missing;
/// `.unreadable` means it was not sure enough to say anything about the strip.
public enum HcgScanResolution: Hashable, Sendable {
    case reading(HcgClassification, HcgScanProvenance)
    case invalid
    case unreadable(HcgUnreadableReason)
}

/// The one place an analyser's estimate becomes a result, or does not.
///
/// The rule is that uncertainty never turns into a result. Every threshold is the
/// configuration's, and the test line is judged on its absolute signal: no ratio is computed.
public enum HcgScanResolver {
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
    ///    signal is, so a test line with no control is never detected and a missing control is
    ///    never "no test line";
    /// 8. the test signal is at or above the detection threshold: test line detected;
    /// 9. the test signal is at or above the indeterminate lower bound: unreadable, with the
    ///    indeterminate reason, never a result;
    /// 10. otherwise no test line detected.
    ///
    /// 5 comes before 7 because invalid is a confident statement: it tells her the strip failed
    /// and to use a new one. An uncertain read of a missing control line is unreadable instead.
    /// An empty issue list means unreadable for no reason the screen can name. A reading's
    /// provenance names the configuration it was resolved against.
    public static func resolve(_ outcome: HcgAnalysisOutcome, configuration: HcgStripConfiguration) -> HcgScanResolution {
        let result: HcgAnalysisResult
        switch outcome {
        case .unreadable(let issues): return .unreadable(.quality(issues))
        case .result(let analysed): result = analysed
        }

        guard result.configurationID == configuration.id,
              result.configurationVersion == configuration.version,
              configuration.isUsable else {
            return .unreadable(.quality([]))
        }
        guard result.qualityFlags.isEmpty else {
            return .unreadable(.quality(result.qualityFlags))
        }
        // Written as `>=` so a NaN confidence fails the test instead of slipping past a `<`. The
        // `0...1` checks stop a percent-scale 85 from passing as certainty or as a signal.
        guard result.confidence.isFinite, (0.0...1.0).contains(result.confidence),
              result.confidence >= configuration.minimumConfidence,
              result.testSignal.isFinite, (0.0...1.0).contains(result.testSignal),
              result.controlSignal.isFinite, (0.0...1.0).contains(result.controlSignal) else {
            return .unreadable(.quality([]))
        }
        guard result.controlSignal >= configuration.minimumControlSignal else {
            return .invalid
        }

        let provenance = HcgScanProvenance(
            scannerVersion: scannerVersion,
            configurationID: configuration.id,
            configurationVersion: configuration.version
        )
        if result.testSignal >= configuration.detectionThreshold {
            return .reading(.testLineDetected, provenance)
        }
        if result.testSignal >= configuration.indeterminateLowerBound {
            return .unreadable(.indeterminateTestLine)
        }
        return .reading(.noTestLineDetected, provenance)
    }
}
