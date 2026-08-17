import XCTest
@testable import GenesyxCore

/// The text equivalent exists so a VoiceOver user gets the guide rather than an unnavigable image
/// of it. These tests defend the two things that would quietly undo that: losing coverage of a
/// page, and re-importing the printed page's defects into the one surface that was supposed to be
/// free of them.
final class FreeGuideContentTests: XCTestCase {

    func testEveryPrintedPageHasAnEquivalent() {
        XCTAssertEqual(FreeGuideContent.pages.count, 20,
                       "the bundled PDF is 20 pages; a missing entry is content a screen reader "
                       + "user simply never receives")
        XCTAssertEqual(FreeGuideContent.pages.map(\.number), Array(1...20),
                       "page numbers are announced, so they must match the printed document")
    }

    func testNoPageIsEmpty() {
        for page in FreeGuideContent.pages {
            XCTAssertFalse(page.heading.trimmingCharacters(in: .whitespaces).isEmpty,
                           "page \(page.number) has no heading to navigate to")
            XCTAssertFalse(page.blocks.isEmpty, "page \(page.number) has no content")
        }
    }

    /// Every page of the PDF carries a letter-spaced `FOODS FOR FERTILITY` device, stored in the
    /// text layer as `FO O D S FO R F E RT I L I TY`. Transcribing it would make VoiceOver spell
    /// out twenty lines of decoration.
    func testTheDecorativeRunningFooterWasNotTranscribed() {
        for page in FreeGuideContent.pages {
            XCTAssertFalse(allText(page).uppercased().contains("FOODS FOR FERTILITY"),
                           "page \(page.number) carries the running footer")
            XCTAssertFalse(allText(page).contains("FO O D S"),
                           "page \(page.number) carries the letter-spaced footer artefact")
        }
    }

    /// Page 20 of the printed guide reads "Download out free app now…" beside a QR code to the
    /// website. Read inside the app the typo is embarrassing, the instruction is circular, and the
    /// QR is a route out to Safari the reader deliberately blocks.
    func testTheClosingPageDoesNotRepeatThePrintedPagesMistakes() throws {
        let closing = try XCTUnwrap(FreeGuideContent.pages.first { $0.number == 20 })
        let text = allText(closing)
        XCTAssertFalse(text.contains("Download out"), "the printed typo was transcribed")
        XCTAssertFalse(text.lowercased().contains("download"),
                       "the reader is already inside the app; there is nothing to download")
        XCTAssertFalse(text.lowercased().contains("qr"),
                       "a QR code is meaningless to a screen reader and unreachable on screen")
    }

    /// The guide is general information, not advice, and the page that says so is the reason it can
    /// ship at all. Losing it in transcription would be worse than not having a text version.
    func testTheDisclaimerPageSurvivedTranscription() throws {
        let note = try XCTUnwrap(FreeGuideContent.pages.first { $0.number == 3 })
        let text = allText(note).lowercased()
        XCTAssertTrue(text.contains("general information only"))
        XCTAssertTrue(text.contains("no diet or lifestyle approach can guarantee"))
    }

    func testTheTitleMatchesTheOneTheReaderShows() {
        XCTAssertEqual(FreeGuideContent.title, "7-Day Fertility Nutrition Starter Guide")
    }

    private func allText(_ page: FreeGuideContent.Page) -> String {
        var parts = [page.heading]
        for block in page.blocks {
            switch block {
            case .paragraph(let t), .subheading(let t): parts.append(t)
            case .bullets(let items): parts.append(contentsOf: items)
            }
        }
        return parts.joined(separator: "\n")
    }
}
