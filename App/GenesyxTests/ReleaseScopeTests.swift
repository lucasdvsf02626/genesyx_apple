import GenesyxCore
import XCTest
@testable import Genesyx

/// Three feature areas are deliberately out of 1.2.0: Home Screen widgets, barcode / photo meal
/// logging, and any health-data consent flow. Nothing was removed to achieve that — none of the
/// three was ever built. That is precisely why a guard is worth having: an absence leaves no code
/// to review, so the next person to add a widget target or a camera key would face nothing that
/// objects.
///
/// These assertions read the built `.app`, not the source tree, because the shipped bundle is what
/// Apple reviews and what the metadata must match (guideline 2.3.1).
final class ReleaseScopeTests: XCTestCase {

    private var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    // MARK: - Barcode / photo meal logging

    /// Barcode scanning and photo-based logging both require a capture path, and iOS terminates an
    /// app the moment it touches the camera or photo library without the matching usage string.
    /// Their absence therefore proves the capability is missing from the bundle rather than merely
    /// switched off behind a flag — a distinction a string grep cannot make.
    func testTheBuiltAppHasNoCameraOrPhotoLibraryCapability() {
        for key in ["NSCameraUsageDescription",
                    "NSPhotoLibraryUsageDescription",
                    "NSPhotoLibraryAddUsageDescription"] {
            XCTAssertNil(info[key],
                "\(key) is in the shipped Info.plist. Barcode and photo meal logging are out of "
                + "1.2.0 scope, so nothing in this release should be able to open a capture UI. "
                + "If a capture feature is landing, update docs/APP_STORE_SUBMISSION.md and this test together.")
        }
    }

    // MARK: - Home Screen widget

    /// A Home Screen widget ships as an embedded `.appex`. Walking the whole bundle rather than
    /// reading `PlugIns/` is deliberate twice over: an absent `PlugIns` directory would make a
    /// directory-listing check pass by asserting nothing, and an extension can also arrive nested
    /// inside a framework. Reading the built bundle beats reading `project.yml` because a target
    /// added in Xcode is lost at the next `xcodegen generate`, while whatever is in the `.app` is
    /// what reaches the reviewer.
    func testTheBuiltAppEmbedsNoAppExtensions() throws {
        let bundle = Bundle.main.bundleURL
        let contents = FileManager.default
            .enumerator(at: bundle, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []

        // Self-check, because the failure mode of a search is finding nothing for the wrong
        // reason. Under XCTest the host app always embeds this very test bundle at
        // `PlugIns/GenesyxAppTests.xctest`, so if the walk cannot see that, it is not reaching
        // the directory extensions live in and the assertion below would pass on an empty list.
        XCTAssertTrue(contents.contains { $0.pathExtension == "xctest" },
            "the walk of \(bundle.path) never reached PlugIns/ — it is not looking where an "
            + "embedded extension would be, so the check below proves nothing")

        let extensions = contents.filter { $0.pathExtension == "appex" }
        XCTAssertTrue(extensions.isEmpty,
            "The build embeds \(extensions.map(\.lastPathComponent)). The Home Screen widget is "
            + "deferred past 1.2.0 and no extension should ship in this release.")
    }

    // MARK: - Apple Health

    /// Narrow claim, stated precisely: the app reads and writes no Apple Health data, because
    /// HealthKit cannot be used without these strings.
    ///
    /// This does NOT establish that the app's own cycle and pH records have a settled UK GDPR
    /// Article 9 basis. They are still special-category data and that question is open — see P0-13.
    /// All this proves is that the open question is bounded by what the app collects directly, and
    /// that no second stream of health data arrives from HealthKit.
    func testTheBuiltAppReadsNoAppleHealthData() {
        for key in ["NSHealthShareUsageDescription",
                    "NSHealthUpdateUsageDescription",
                    "NSHealthClinicalHealthRecordsShareUsageDescription"] {
            XCTAssertNil(info[key],
                "\(key) is in the shipped Info.plist. HealthKit access widens the special-category "
                + "data the app processes, and the Article 9 basis for what it already collects is "
                + "not yet settled (P0-13). Do not add this before that decision.")
        }
    }

    // MARK: - Copy

    /// The structural checks above stop the features shipping. This stops the *claim* shipping —
    /// one sentence in a Learn article or a quiz option telling a reader to scan a barcode is a
    /// functionality/metadata mismatch even though the capture code does not exist, and it is the
    /// far likelier mistake because it needs no build change to happen.
    func testNoShippingCopyAdvertisesWidgetOrBarcodeLogging() {
        let outOfScope = [
            "barcode",
            "scan a food",
            "scan your food",
            "scan the label",
            "scan your meal",
            "home screen widget",
            "add the widget",
            "add a widget",
            "photo of your meal",
            "snap a photo",
            "photograph your meal",
        ]

        var copy: [(surface: String, text: String)] = []
        for a in LearnLibrary.allArticles {
            var strings = [a.title, a.excerpt] + a.tags
            if let cta = a.cta { strings.append(cta.label) }
            for block in a.body {
                switch block {
                case .heading(let t), .paragraph(let t), .callout(let t): strings.append(t)
                case .bulletList(let items): strings += items
                }
            }
            copy += strings.map { (surface: "article \(a.slug)", text: $0) }
        }
        for q in QuizContent.questions {
            var strings = [q.question, q.helper] + q.options.map(\.label)
            if let fact = q.fact { strings += [fact.title, fact.body] }
            copy += strings.map { (surface: "quiz \(q.id)", text: $0) }
        }
        XCTAssertFalse(copy.isEmpty, "expected reader-facing copy to scan")

        for entry in copy {
            let lower = entry.text.lowercased()
            for phrase in outOfScope {
                XCTAssertFalse(lower.contains(phrase),
                    "Out-of-scope phrase \"\(phrase)\" in \(entry.surface): \(entry.text). "
                    + "Widget and barcode/photo logging are not in 1.2.0 and must not be described "
                    + "as available.")
            }
        }
    }
}
