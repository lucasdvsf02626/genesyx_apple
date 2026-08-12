import XCTest
import SwiftUI
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

#if canImport(UIKit)
/// Contrast floors for the calendar grid, measured in both schemes.
///
/// The calendar draws four phase fills and then draws *on top of them*: the day number, the
/// fertile-window ring, and up to three logging dots. Nothing about that stack is checked by the
/// compiler or visible in a light-mode screenshot, and it is easy to break by adjusting one hex —
/// which is how the dark grid previously shipped with the day number at 4.2:1 on the fertile fill
/// and dots at 1.2:1 on the ovulation cell, on exactly the days a conception app exists to show her.
///
/// Fills are deliberately *not* checked against the card. The light tints sit at 1.3–1.5:1 by
/// design and always have; the legend, not the fill, is what names a phase.
final class CalendarContrastTests: XCTestCase {

    /// WCAG 2.1 §1.4.3 — the day number is 13pt regular, so it takes the small-text floor.
    private let textFloor = 4.5
    /// WCAG 2.1 §1.4.11 — the ring and the dots are graphical objects carrying meaning.
    private let graphicFloor = 3.0

    private let schemes: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

    /// Every day that is not ovulation, plus the card itself for follicular and no-cycle days.
    private var tintedFills: [(Color, String)] {
        [(GenesyxColor.card, "card"), (GenesyxColor.calendarPeriod, "period"),
         (GenesyxColor.calendarFertile, "fertile"), (GenesyxColor.calendarLuteal, "luteal")]
    }

    func testDayNumberIsLegibleOnEveryPhaseFill() {
        for (style, name) in schemes {
            for (fill, fillName) in tintedFills {
                assertContrast(GenesyxColor.foreground, on: fill, style, atLeast: textFloor,
                               "day number on the \(fillName) fill, \(name) mode")
            }
            // The one solid cell, and the one that flips its number to white.
            assertContrast(GenesyxColor.onPrimary, on: GenesyxColor.calendarOvulation, style,
                           atLeast: textFloor, "day number on the ovulation fill, \(name) mode")
        }
    }

    /// The ring marks the fertile window, and the window can open while she is still bleeding — so
    /// it has to survive the period fill too, not just the fertile one.
    func testFertileRingSurvivesEveryFillItCanLandOn() {
        for (style, name) in schemes {
            for (fill, fillName) in [(GenesyxColor.calendarFertile, "fertile"),
                                     (GenesyxColor.calendarPeriod, "period")] {
                assertContrast(GenesyxColor.fertileRing, on: fill, style, atLeast: graphicFloor,
                               "fertile ring on the \(fillName) fill, \(name) mode")
            }
            assertContrast(GenesyxColor.fertileRingBright, on: GenesyxColor.calendarOvulation, style,
                           atLeast: graphicFloor, "fertile ring on the ovulation fill, \(name) mode")
        }
    }

    /// The "Fertile window" badge on the Current phase card reuses the ring colour on the fertile
    /// fill — the same pair as the grid, but as *text*, so it owes the higher floor. It clears by
    /// 0.01 in light mode, which is exactly the kind of margin that disappears in a later tweak
    /// without anyone noticing.
    func testFertileBadgeTextIsLegibleOnItsCapsule() {
        for (style, name) in schemes {
            assertContrast(GenesyxColor.fertileRing, on: GenesyxColor.calendarFertile, style,
                           atLeast: textFloor, "fertile-window badge text, \(name) mode")
        }
    }

    /// A dot can land on any day of the cycle, so each is checked against all five backgrounds.
    /// On the solid ovulation cell they take the bright variant — the same flip the day number
    /// makes to white — because no single colour clears the floor on both a white card and a
    /// saturated indigo fill.
    func testLoggingDotsSurviveEveryFillTheyCanLandOn() {
        let markers: [(Color, Color, String)] = [
            (GenesyxColor.markerPh, GenesyxColor.markerPhBright, "pH"),
            (GenesyxColor.markerSymptoms, GenesyxColor.markerSymptomsBright, "symptoms"),
            (GenesyxColor.markerIntimacy, GenesyxColor.markerIntimacyBright, "intimacy"),
        ]
        for (style, name) in schemes {
            for (dot, bright, dotName) in markers {
                for (fill, fillName) in tintedFills {
                    assertContrast(dot, on: fill, style, atLeast: graphicFloor,
                                   "\(dotName) dot on the \(fillName) fill, \(name) mode")
                }
                assertContrast(bright, on: GenesyxColor.calendarOvulation, style,
                               atLeast: graphicFloor,
                               "\(dotName) dot on the ovulation fill, \(name) mode")
            }
        }
    }

    private func assertContrast(_ foreground: Color, on background: Color,
                                _ style: UIUserInterfaceStyle, atLeast floor: Double,
                                _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        let ratio = contrast(foreground, background, style)
        XCTAssertGreaterThanOrEqual(ratio, floor,
            String(format: "%@ measures %.2f:1, under the %.1f:1 floor", what, ratio, floor),
            file: file, line: line)
    }

    private func contrast(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
        let (la, lb) = (luminance(a, style), luminance(b, style))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Resolves the adaptive colour for the scheme first — `GenesyxColor` wraps a `UIColor` that
    /// answers per trait collection, so reading it without resolving only ever sees light mode.
    private func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
#endif
