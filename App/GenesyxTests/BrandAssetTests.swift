import XCTest
@testable import Genesyx
#if canImport(UIKit)
import UIKit
#endif

/// Existence guards for the brand artwork the app draws by name.
///
/// `Image("egg_female")` renders an empty view when the asset is missing — no crash, no warning at
/// runtime, and nothing at compile time either, because the name is only a string. The splash would
/// simply go back to being a bare screen, which is exactly what it looked like for the months the
/// artwork was outstanding, so nobody would read it as a regression.
final class BrandAssetTests: XCTestCase {

    #if canImport(UIKit)
    /// The same lookup `BrandEgg` performs, for both tints.
    func testBrandEggArtworkExists() {
        for name in ["egg_female", "egg_male"] {
            XCTAssertNotNil(UIImage(named: name),
                "Missing brand asset \"\(name)\" — BrandEgg would render nothing and the onboarding "
                + "splash would silently lose its artwork")
        }
    }

    /// Both tints are 1x-only entries, so the pixel width *is* the point size SwiftUI lays out
    /// against. `BrandEgg` is used at up to 170pt, which needs 510px on a 3x screen; 512 is the
    /// deliberate figure. Re-exporting at 256 would look soft on device and nowhere else.
    func testBrandEggArtworkIsLargeEnoughForItsBiggestUse() {
        for name in ["egg_female", "egg_male"] {
            guard let image = UIImage(named: name) else { continue }   // covered above
            XCTAssertGreaterThanOrEqual(image.size.width, 512,
                "\(name) is \(Int(image.size.width))px; BrandEgg draws up to 170pt, which needs 510px at 3x")
        }
    }

    /// The lookup `gxPageBackground()` performs on all seven tab screens.
    func testPageBackgroundArtworkExists() {
        XCTAssertNotNil(UIImage(named: "page_background"),
            "Missing brand asset \"page_background\" — the tab screens would fall back to a flat "
            + "fill, which is what they looked like before, so nobody would read it as a regression")
    }

    /// The asset shipped as one 1323×2868 file *declared 1x*, which is how a 3x export ends up laid
    /// out at three times its intended size. The point size is the tell: it should be one phone
    /// screen, not three. Asserted here rather than against the files, because this is the number
    /// SwiftUI actually lays out against.
    func testPageBackgroundIsDeclaredAtTheRightScale() {
        guard let image = UIImage(named: "page_background") else { return }   // covered above
        XCTAssertEqual(image.size.width, 441, accuracy: 1,
            "page_background lays out \(Int(image.size.width))pt wide; a phone is ~440pt, so the "
            + "scale declarations in Contents.json are wrong")
    }
    #endif
}
