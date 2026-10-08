import Foundation

/// Everything the scanner needs to know about one pregnancy (hCG) strip product: its shape, where
/// its two lines are, and how strong and how sure a read must be before it counts. Every threshold
/// comes from here, so supporting a strip is a data change rather than a code change.
public struct HcgStripConfiguration: Hashable, Sendable, Codable {
    public let id: String
    public let version: String
    /// Width divided by height of the whole strip as it is laid for scanning (horizontal, so well above 1).
    public let expectedAspectRatio: Double
    /// Strip space: the strip's bounding box is the unit square, x = 0 at the sample end, x = 1 at the handle end.
    public let testLineRegion: NormalisedRect
    public let controlLineRegion: NormalisedRect
    /// 0...1. A control line weaker than this is no control line, and the test is invalid.
    public let minimumControlSignal: Double
    /// On `testSignal`. Below it there is no test line. From it up to `detectionThreshold` the
    /// scan is indeterminate and is never a result.
    public let indeterminateLowerBound: Double
    /// On `testSignal`. At or above it a test line is detected.
    public let detectionThreshold: Double
    /// 0...1. A read below this is unreadable, never a result.
    public let minimumConfidence: Double
    /// Not read by any code in phase 1.
    public let developmentTimeSeconds: Int
    /// Nil when it is not known. Not read by any code in phase 1.
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
        indeterminateLowerBound: Double,
        detectionThreshold: Double,
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
        self.indeterminateLowerBound = indeterminateLowerBound
        self.detectionThreshold = detectionThreshold
        self.minimumConfidence = minimumConfidence
        self.developmentTimeSeconds = developmentTimeSeconds
        self.maximumReadTimeSeconds = maximumReadTimeSeconds
        self.stableDetectionMilliseconds = stableDetectionMilliseconds
    }

    /// Whether the thresholds can be judged against at all. A configuration that fails this makes
    /// every scan unreadable, because a result decided by incoherent thresholds is a guess.
    ///
    /// The band must have room in it (`0 < indeterminateLowerBound < detectionThreshold <= 1`):
    /// an empty or inverted band is unusable, so no configuration can switch the band off.
    public var isUsable: Bool {
        guard minimumControlSignal.isFinite, indeterminateLowerBound.isFinite,
              detectionThreshold.isFinite, minimumConfidence.isFinite else { return false }
        return minimumControlSignal > 0 && minimumControlSignal <= 1
            && indeterminateLowerBound > 0 && indeterminateLowerBound < detectionThreshold
            && detectionThreshold <= 1
            && (0.0...1.0).contains(minimumConfidence)
    }

    /// DEVELOPMENT ONLY - REPLACE WITH VALIDATED PRODUCT DATA
    ///
    /// The only configuration that exists. Nothing in it was measured from a real strip, and no
    /// product specification exists: the geometry is a guess at a thin strip laid on its side
    /// with two lines near the middle, and the thresholds are there to give the flow something
    /// to draw and the mock analyser something to be judged against. The band between
    /// `indeterminateLowerBound` and `detectionThreshold` is invented too.
    ///
    /// `developmentTimeSeconds` is 0 and `maximumReadTimeSeconds` is nil because the real times
    /// are on the product leaflet, and a made-up number here would look like one somebody had
    /// checked.
    public static let developmentPlaceholder = HcgStripConfiguration(
        id: "genesyx_hcg_strip_v1",
        version: "0.0.0-dev",
        // Length over width of a strip laid on its side. Approximate strip size supplied by the
        // owner on 8 October 2026: 75 mm long by 3.5 mm wide. Not measured from validated product
        // samples.
        expectedAspectRatio: 75.0 / 3.5,
        testLineRegion: NormalisedRect(x: 0.42, y: 0.1, width: 0.04, height: 0.8),
        controlLineRegion: NormalisedRect(x: 0.52, y: 0.1, width: 0.04, height: 0.8),
        minimumControlSignal: 0.2,
        indeterminateLowerBound: 0.05,
        detectionThreshold: 0.15,
        minimumConfidence: 0.85,
        developmentTimeSeconds: 0,
        maximumReadTimeSeconds: nil,
        stableDetectionMilliseconds: 450
    )
}
