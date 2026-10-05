import Foundation

extension LhStripConfiguration: ScanFlowRules {
    public func resolve(_ outcome: LhAnalysisOutcome) -> LhScanResolution {
        LhScanResolver.resolve(outcome, configuration: self)
    }

    public static var captureFailed: LhScanResolution { .unreadable([]) }
}

/// The LH flow: the shared reducer, whose results always go through `LhScanResolver`.
public typealias LhScanSession = ScanSession<LhStripConfiguration>
public typealias LhScannerState = ScanFlowState<LhScanResolution>
public typealias LhScanEvent = ScanFlowEvent<LhAnalysisOutcome>
