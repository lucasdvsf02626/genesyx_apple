import CoreGraphics
import GenesyxCore

/// Reads a pregnancy test strip from a still image. An implementation measures the test line and
/// the control line and reports how sure it is; whether that is a result is `HcgScanResolver`'s call.
protocol HcgTestAnalyzing: Sendable {
    func analyse(_ image: CGImage, configuration: HcgStripConfiguration) async -> HcgAnalysisOutcome
}
