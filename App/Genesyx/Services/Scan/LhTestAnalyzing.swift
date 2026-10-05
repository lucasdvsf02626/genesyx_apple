import CoreGraphics
import GenesyxCore

/// Reads an ovulation test strip from a still image. An implementation measures the test line and
/// the control line and reports how sure it is; whether that is a result is `LhScanResolver`'s call.
protocol LhTestAnalyzing: Sendable {
    func analyse(_ image: CGImage, configuration: LhStripConfiguration) async -> LhAnalysisOutcome
}
