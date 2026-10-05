import Foundation

extension HcgStripConfiguration: ScanFlowRules {
    public func resolve(_ outcome: HcgAnalysisOutcome) -> HcgScanResolution {
        HcgScanResolver.resolve(outcome, configuration: self)
    }

    public static var captureFailed: HcgScanResolution { .unreadable(.quality([])) }
}

/// The pregnancy test flow: the shared reducer, whose results always go through `HcgScanResolver`.
public typealias HcgScanSession = ScanSession<HcgStripConfiguration>
public typealias HcgScannerState = ScanFlowState<HcgScanResolution>
public typealias HcgScanEvent = ScanFlowEvent<HcgAnalysisOutcome>
