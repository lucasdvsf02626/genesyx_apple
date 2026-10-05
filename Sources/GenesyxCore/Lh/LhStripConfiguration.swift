import Foundation

/// Everything the scanner needs to know about one ovulation (LH) strip product: its shape, where
/// its two lines are, and how strong and how sure a read must be before it counts. Every threshold
/// comes from here, so supporting a strip is a data change rather than a code change.
public struct LhStripConfiguration: Hashable, Sendable, Codable {
    public let id: String
    public let version: String
    /// Width divided by height of the whole strip as it is laid for scanning (horizontal, so well above 1).
    public let expectedAspectRatio: Double
    /// Strip space: the strip's bounding box is the unit square, x = 0 at the sample end, x = 1 at the handle end.
    public let testLineRegion: NormalisedRect
    public let controlLineRegion: NormalisedRect
    /// 0...1. A control line weaker than this is no control line, and the test is invalid.
    public let minimumControlSignal: Double
    /// On `testSignal / controlSignal`. At or above it the test is positive.
    public let positiveThreshold: Double
    /// On the same ratio. Read only when `risingEnabled`.
    public let risingThreshold: Double
    public let risingEnabled: Bool
    /// 0...1. A read below this is unreadable, never a result.
    public let minimumConfidence: Double
    public let developmentTimeSeconds: Int
    /// Nil when it is not known.
    public let maximumReadTimeSeconds: Int?
    /// How long the strip must sit still in the frame before a capture is taken.
    public let stableDetectionMilliseconds: Int

    public init(
        id: String,
        version: String,
        expectedAspectRatio: Double,
        testLineRegion: NormalisedRect,
        controlLineRegion: NormalisedRect,
        minimumControlSignal: Double,
        positiveThreshold: Double,
        risingThreshold: Double,
        risingEnabled: Bool,
        minimumConfidence: Double,
        developmentTimeSeconds: Int,
        maximumReadTimeSeconds: Int?,
        stableDetectionMilliseconds: Int
    ) {
        self.id = id
        self.version = version
        self.expectedAspectRatio = expectedAspectRatio
        self.testLineRegion = testLineRegion
        self.controlLineRegion = controlLineRegion
        self.minimumControlSignal = minimumControlSignal
        self.positiveThreshold = positiveThreshold
        self.risingThreshold = risingThreshold
        self.risingEnabled = risingEnabled
        self.minimumConfidence = minimumConfidence
        self.developmentTimeSeconds = developmentTimeSeconds
        self.maximumReadTimeSeconds = maximumReadTimeSeconds
        self.stableDetectionMilliseconds = stableDetectionMilliseconds
    }

    /// Whether the thresholds can be judged against at all. A configuration that fails this makes
    /// every scan unreadable, because a result decided by incoherent thresholds is a guess.
    public var isUsable: Bool {
        guard minimumControlSignal.isFinite, positiveThreshold.isFinite,
              risingThreshold.isFinite, minimumConfidence.isFinite else { return false }
        guard minimumControlSignal > 0, minimumControlSignal <= 1,
              positiveThreshold > 0,
              (0.0...1.0).contains(minimumConfidence) else { return false }
        return !risingEnabled || (risingThreshold > 0 && risingThreshold < positiveThreshold)
    }

    /// DEVELOPMENT ONLY - REPLACE WITH VALIDATED PRODUCT DATA
    ///
    /// The only configuration that exists. Nothing in it was measured from a real strip: the
    /// geometry is a guess at a thin strip laid on its side with two lines near the middle, and
    /// the thresholds are there to give the flow something to draw and the mock analyser
    /// something to be judged against. `positiveThreshold` is not 1.0 on purpose: a test line as
    /// dark as the control is not assumed to be what positive means for this product.
    ///
    /// `risingEnabled` is false, so no scan resolves to rising from this configuration.
    /// `developmentTimeSeconds` is 0 and `maximumReadTimeSeconds` is nil because the real times
    /// are on the product leaflet, and a made-up number here would look like one somebody had
    /// checked.
    public static let developmentPlaceholder = LhStripConfiguration(
        id: "genesyx_lh_strip_v1",
        version: "0.0.0-dev",
        expectedAspectRatio: 12.5,
        testLineRegion: NormalisedRect(x: 0.42, y: 0.1, width: 0.04, height: 0.8),
        controlLineRegion: NormalisedRect(x: 0.52, y: 0.1, width: 0.04, height: 0.8),
        minimumControlSignal: 0.2,
        positiveThreshold: 0.9,
        risingThreshold: 0.5,
        risingEnabled: false,
        minimumConfidence: 0.85,
        developmentTimeSeconds: 0,
        maximumReadTimeSeconds: nil,
        stableDetectionMilliseconds: 450
    )
}
