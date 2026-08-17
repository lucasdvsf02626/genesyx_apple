import PDFKit
import XCTest
@testable import Genesyx

/// The PDF sitting in the repository proves nothing. What matters is whether it survived into the
/// app target's Copy Bundle Resources phase — and if it didn't, nothing shouts: the button still
/// opens, the reader is simply blank. These tests run hosted in the app, so `Bundle.main` is the
/// built `.app`, which is the only place worth asking.
final class FreeGuideBundleTests: XCTestCase {

    func testTheGuideResolvesFromTheBuiltAppBundle() throws {
        let url = try XCTUnwrap(
            FreeGuide.url,
            "\(FreeGuide.resourceName).pdf is not in the built app. Check it is still under "
            + "App/Genesyx/Resources and re-run `xcodegen generate`."
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    /// Resolving a URL only proves a file of that name shipped. This proves PDFKit can actually
    /// open what shipped, which is what the reader needs — a truncated or corrupted copy would
    /// pass the test above and still render nothing.
    func testTheBundledGuideIsAReadableMultiPagePdf() throws {
        let url = try XCTUnwrap(FreeGuide.url)
        let document = try XCTUnwrap(PDFDocument(url: url), "the bundled file is not a readable PDF")
        XCTAssertGreaterThan(document.pageCount, 1,
                             "a one-page document means a truncated copy shipped")
    }

    /// The title is shown as the reader's navigation title and as the Learn row's label, and the
    /// UI test asserts on it. Left to drift, those go out of sync silently.
    func testTheGuideTitleIsTheOneTheUiAssertsOn() {
        XCTAssertEqual(FreeGuide.title, "7-Day Fertility Nutrition Starter Guide")
    }

    /// The file arrived titled "Genesyx - Recipe Book" internally, so a woman who saved or shared
    /// it got a different document from the one the app had just shown her. It is corrected now,
    /// but the correction lives in bytes a designer re-export would overwrite — this is what
    /// notices if that happens.
    func testTheBundledPdfCarriesTheTitleTheAppShows() throws {
        let url = try XCTUnwrap(FreeGuide.url)
        let document = try XCTUnwrap(PDFDocument(url: url))
        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        XCTAssertEqual(
            title, FreeGuide.title,
            "the PDF's internal title is what Files, Quick Look and the share sheet display"
        )
    }
}
