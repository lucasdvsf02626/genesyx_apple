import Foundation

/// A rectangle in strip space: the strip's own bounding box is the unit square, origin top-left,
/// so every component is 0...1 whatever size the strip appears in the frame.
public struct NormalisedRect: Hashable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A CIELAB colour. A plain value in phase 1: no colour maths lives in Core yet.
public struct LabColour: Hashable, Sendable, Codable {
    public let l: Double
    public let a: Double
    public let b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }
}

/// The colours the reagent pads are expected to show at one pH value, in `reagentRegions` order.
public struct PhReferenceProfile: Hashable, Sendable, Codable {
    public let ph: Double
    public let padColours: [LabColour]

    public init(ph: Double, padColours: [LabColour]) {
        self.ph = ph
        self.padColours = padColours
    }
}

/// Everything the scanner needs to know about one strip product: its shape, where its pads are,
/// what their colours mean and how sure a read must be before it counts. Every threshold and all
/// geometry come from here, so supporting a strip is a data change rather than a code change.
public struct PhStripConfiguration: Hashable, Sendable, Codable {
    public let id: String
    public let version: String
    /// Width divided by height of the whole strip, held upright.
    public let expectedAspectRatio: Double
    public let reagentRegions: [NormalisedRect]
    public let calibrationRegions: [NormalisedRect]
    public let referenceProfiles: [PhReferenceProfile]
    /// 0...1. A read below this is unreadable, never a result.
    public let minimumConfidence: Double
    public let developmentTimeSeconds: Int
    /// How long the strip must sit still in the frame before a capture is taken.
    public let stableDetectionMilliseconds: Int

    public init(
        id: String,
        version: String,
        expectedAspectRatio: Double,
        reagentRegions: [NormalisedRect],
        calibrationRegions: [NormalisedRect],
        referenceProfiles: [PhReferenceProfile],
        minimumConfidence: Double,
        developmentTimeSeconds: Int,
        stableDetectionMilliseconds: Int
    ) {
        self.id = id
        self.version = version
        self.expectedAspectRatio = expectedAspectRatio
        self.reagentRegions = reagentRegions
        self.calibrationRegions = calibrationRegions
        self.referenceProfiles = referenceProfiles
        self.minimumConfidence = minimumConfidence
        self.developmentTimeSeconds = developmentTimeSeconds
        self.stableDetectionMilliseconds = stableDetectionMilliseconds
    }

    /// DEVELOPMENT ONLY - REPLACE WITH VALIDATED PRODUCT DATA
    ///
    /// The only configuration that exists. Nothing in it was measured from a real strip: the
    /// geometry is a guess at a thin upright strip with three pads near the top and a bare patch
    /// of backing below them, there to give the flow something to draw and the mock analyser
    /// something to be handed.
    ///
    /// `referenceProfiles` is empty on purpose. There is no manufacturer colour chart yet and one
    /// must not be invented, so nothing can turn a colour into a pH from this configuration.
    /// `developmentTimeSeconds` is 0 for the same reason: the real wait is on the product leaflet,
    /// and a made-up number here would look like one somebody had checked.
    public static let developmentPlaceholder = PhStripConfiguration(
        id: "genesyx_ph_multizone_v1",
        version: "0.0.0-dev",
        // Width over length of an upright strip. Approximate strip size supplied by the owner on
        // 8 October 2026: 65 mm long by 5 mm wide. Not measured from validated product samples.
        expectedAspectRatio: 5.0 / 65.0,
        reagentRegions: [
            NormalisedRect(x: 0.1, y: 0.04, width: 0.8, height: 0.08),
            NormalisedRect(x: 0.1, y: 0.14, width: 0.8, height: 0.08),
            NormalisedRect(x: 0.1, y: 0.24, width: 0.8, height: 0.08),
        ],
        calibrationRegions: [
            NormalisedRect(x: 0.1, y: 0.4, width: 0.8, height: 0.08),
        ],
        referenceProfiles: [],
        minimumConfidence: 0.85,
        developmentTimeSeconds: 0,
        stableDetectionMilliseconds: 450
    )
}
