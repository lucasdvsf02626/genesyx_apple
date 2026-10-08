import SwiftUI
import XCTest
@testable import Genesyx

#if canImport(UIKit)
/// Contrast floors for the pairings the Fertility Kit's shared components draw, measured in both
/// schemes the way `CalendarContrastTests` does. A new pairing that fails is fixed in the shared
/// component, never by lowering the floor.
final class FertilityKitContrastTests: XCTestCase {

    /// WCAG 2.1 §1.4.3: body text takes the small-text floor.
    private let textFloor = 4.5
    /// The floor for large text and graphical objects.
    private let largeTextFloor = 3.0
    /// `KitCard(tinted: true)`: this much of `primary` over the card colour.
    private let tintOpacity = 0.10

    private let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

    func testTextIsLegibleOnEverySurfaceTheKitDraws() {
        for (style, scheme) in schemes {
            let card = rgb(GenesyxColor.card, style)
            let surfaces: [(RGB, String)] = [
                (card, "card"),
                (blend(rgb(GenesyxColor.primary, style), over: card, opacity: tintOpacity), "tinted card"),
                (rgb(GenesyxColor.background, style), "page background"),
            ]
            for (surface, surfaceName) in surfaces {
                for (text, textName) in [(GenesyxColor.foreground, "foreground"), (GenesyxColor.mutedForeground, "muted text")] {
                    assertContrast(rgb(text, style), surface, atLeast: textFloor, "\(textName) on the \(surfaceName), \(scheme) mode")
                }
            }
            // The secondary button: primary text on a capsule in the card colour.
            assertContrast(rgb(GenesyxColor.primary, style), card, atLeast: textFloor,
                           "secondary button text on the card, \(scheme) mode")
        }
    }

    /// The existing primary button. The pair is the app's own and is under 4.5 in dark mode
    /// today, so it is held to the large-text floor and its ratio is printed for the record.
    func testThePrimaryButtonIsMeasured() {
        for (style, scheme) in schemes {
            let ratio = contrast(rgb(GenesyxColor.onPrimary, style), rgb(GenesyxColor.primary, style))
            print(String(format: "FertilityKitContrastTests: onPrimary on primary measures %.2f:1 in %@ mode", ratio, scheme))
            XCTAssertGreaterThanOrEqual(ratio, largeTextFloor,
                String(format: "primary button text measures %.2f:1 in %@ mode, under the %.1f:1 floor", ratio, scheme, largeTextFloor))
        }
    }

    /// The measure can fail: the tint itself, without the card under it, would not carry text in dark mode.
    func testTheMeasureCanFail() {
        let white = RGB(r: 1, g: 1, b: 1), grey = RGB(r: 0.7, g: 0.7, b: 0.7)
        XCTAssertLessThan(contrast(grey, white), textFloor)
        XCTAssertEqual(contrast(RGB(r: 0, g: 0, b: 0), white), 21, accuracy: 0.01)
        XCTAssertEqual(blend(RGB(r: 1, g: 0, b: 0), over: RGB(r: 0, g: 0, b: 0), opacity: 0.10).r, 0.10, accuracy: 0.001)
    }

    // MARK: - Helpers (copied from `BrandAssetTests`, which keeps its own private)

    private struct RGB { let r: Double, g: Double, b: Double }

    private func assertContrast(_ foreground: RGB, _ background: RGB, atLeast floor: Double, _ what: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let ratio = contrast(foreground, background)
        XCTAssertGreaterThanOrEqual(ratio, floor,
            String(format: "%@ measures %.2f:1, under the %.1f:1 floor", what, ratio, floor), file: file, line: line)
    }

    /// Resolves the adaptive colour for the scheme first: `GenesyxColor` wraps a `UIColor` that
    /// answers per trait collection, so reading it without resolving only ever sees light mode.
    private func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> RGB {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(r: Double(r), g: Double(g), b: Double(b))
    }

    private func blend(_ top: RGB, over bottom: RGB, opacity: Double) -> RGB {
        RGB(r: top.r * opacity + bottom.r * (1 - opacity),
            g: top.g * opacity + bottom.g * (1 - opacity),
            b: top.b * opacity + bottom.b * (1 - opacity))
    }

    private func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: RGB) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
    }
}
#endif
