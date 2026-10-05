import XCTest
@testable import GenesyxCore

/// The written lesson text: one body for every lesson reference the ninety days use, within the
/// word limits, guarded, carrying the approved safety wording and marked for review.
final class ProgrammeLessonsDraftTests: XCTestCase {

    private typealias Guard = ProgrammeWrittenCopyGuard
    private let content = ProgrammeContent.draft
    private let lessons = ProgrammeLessonsDraft.all

    private func text(ofDay day: Int) -> String {
        ProgrammeContent.draftLessons.body(forLessonID: content.day(day)?.lesson.id ?? "")?
            .paragraphs.joined(separator: " ") ?? ""
    }

    // ── Every reference resolves ──

    func testEveryLessonReferenceResolvesToABodyWithinTheWordLimits() throws {
        for definition in content.days {
            let body = try XCTUnwrap(ProgrammeContent.draftLessons.body(forLessonID: definition.lesson.id),
                                     "no lesson text for day \(definition.day)")
            let words = Guard.wordCount(body.paragraphs)
            XCTAssertTrue((80...220).contains(words), "day \(definition.day) has \(words) words")
            XCTAssertGreaterThanOrEqual(body.paragraphs.count, 3, "day \(definition.day) is one block of text")
            for paragraph in body.paragraphs {
                XCTAssertLessThanOrEqual(Guard.wordCount([paragraph]), 70, "long paragraph on day \(definition.day)")
            }
        }
    }

    func testTheLessonsAreExactlyTheScheduledOnes() {
        XCTAssertEqual(lessons.map(\.id), content.days.map(\.lesson.id))
        XCTAssertEqual(Set(lessons.map(\.id)).count, 90)
        XCTAssertNil(ProgrammeContent.draftLessons.body(forLessonID: "programme-day-000"))
        XCTAssertNil(ProgrammeContent.draftLessons.body(forLessonID: "programme-day-091"))
        XCTAssertNil(ProgrammeContent.draftLessons.body(forLessonID: ""))
        XCTAssertEqual(ProgrammeLessonsDraft.lesson(forID: "programme-day-040")?.id, "programme-day-040")
    }

    func testADayIsShownWithItsWrittenCopyAndItsLesson() throws {
        for day in 1...90 {
            let shown = try XCTUnwrap(content.presentation(ofDay: day, lessons: ProgrammeContent.draftLessons))
            XCTAssertNotNil(shown.lesson, "day \(day)")
            XCTAssertEqual(shown.estimatedReadMinutes, shown.definition.estimatedReadMinutes)
            XCTAssertEqual(shown.definition.title, ProgrammeDayCopyDraft.writing(forDay: day)?.copy.title)
        }
    }

    func testNoTwoLessonsRepeatAParagraphExceptTheApprovedSafetyWording() {
        let shared: Set<String> = [HcgScanCopy.resultNote]
        var seen = Set<String>()
        for lesson in lessons {
            for paragraph in lesson.body.paragraphs where !shared.contains(paragraph) {
                XCTAssertTrue(seen.insert(paragraph).inserted, "repeated in \(lesson.id): \(paragraph)")
            }
        }
    }

    // ── Guard ──

    func testLessonTextPassesTheGuard() {
        XCTAssertEqual(Guard.violations(in: ProgrammeLessonsDraft.allSurfaces, allowingProductName: true), [])
    }

    /// The test product is named in three lessons and no others: the kit contents on day 5 and
    /// the two lessons of the tests week. A fourth is a compliance decision.
    func testTheTestProductIsNamedOnlyWhereItHasToBe() {
        let naming = lessons.filter { lesson in
            lesson.body.paragraphs.contains { $0.lowercased().contains("pregnan") }
        }
        XCTAssertEqual(naming.map(\.id), ["programme-day-005", "programme-day-043", "programme-day-047"])
    }

    func testEveryLessonStringIsInTheRegistry() {
        let all = Set(ProgrammeContent.draftWrittenSurfaces)
        for lesson in lessons {
            for paragraph in lesson.body.paragraphs { XCTAssertTrue(all.contains(paragraph), paragraph) }
        }
        XCTAssertEqual(ProgrammeLessonsDraft.allSurfaces.count, lessons.reduce(0) { $0 + $1.body.paragraphs.count })
    }

    // ── Safety wording ──

    func testAnOvulationTestResultIsNeverReadAsOvulation() {
        // The approved result note and disclaimer, by reference.
        for day in [40] {
            XCTAssertTrue(text(ofDay: day).contains(LhScanCopy.resultNote), "day \(day)")
            XCTAssertTrue(text(ofDay: day).contains(LhScanCopy.disclaimer), "day \(day)")
        }
        XCTAssertTrue(text(ofDay: 37).contains("It does not tell you when ovulation will happen, and it does not show that ovulation has happened."))
        XCTAssertTrue(text(ofDay: 43).contains("It cannot tell you when ovulation will happen or show that it has."))
        // An estimate is called an estimate wherever the fertile window is introduced.
        XCTAssertTrue(text(ofDay: 36).contains("It is not a measurement of your body"))
        XCTAssertTrue(text(ofDay: 36).contains("It is not a method of contraception and should not be used as one."))
    }

    func testAPhReadingIsANumberAndAHistoryWithTheApprovedSignposts() {
        XCTAssertTrue(text(ofDay: 44).contains(PhCopy.accuracyCaveat))
        XCTAssertTrue(text(ofDay: 45).contains(PhCopy.elevatedSignpost))
        XCTAssertTrue(text(ofDay: 45).contains(PhCopy.disclaimer))
        XCTAssertTrue(text(ofDay: 45).contains("It does not interpret a reading for you."))
        XCTAssertTrue(text(ofDay: 43).contains("A reading is not a statement about your health or your fertility"))
    }

    func testAHomeTestResultIsARecordedResultAndNothingMore() {
        XCTAssertTrue(text(ofDay: 47).contains(HcgScanCopy.aboutNote))
        XCTAssertTrue(text(ofDay: 47).contains(HcgScanCopy.resultNote))
        XCTAssertTrue(text(ofDay: 43).contains(HcgScanCopy.resultNote))
        XCTAssertTrue(text(ofDay: 47).contains("Recording a result changes nothing else in the app."))
        XCTAssertTrue(text(ofDay: 47).contains("never counted in your consistency"))
    }

    func testTestGuidanceIsTrueWithOrWithoutAScanner() {
        // Scanning is offered conditionally and entering a result by hand is always named with it.
        for day in [40, 44, 47] {
            let lesson = text(ofDay: day)
            XCTAssertTrue(lesson.contains("scan"), "day \(day)")
            XCTAssertTrue(lesson.contains("enter"), "day \(day)")
            XCTAssertTrue(lesson.contains("where that option is shown") || lesson.contains("If your app offers scanning")
                || lesson.contains("Where Genesyx offers a place to record"), "day \(day) promises a scanner")
        }
    }

    func testTheFoodLogIsNeverScoredAndConsistencyIsNeverGuilt() {
        let all = ProgrammeLessonsDraft.allSurfaces.joined(separator: " ")
        XCTAssertTrue(text(ofDay: 4).contains("This is a record, not a target. Nothing here is scored"))
        XCTAssertTrue(text(ofDay: 15).contains("it is a record, not a target, and nothing here is scored"))
        XCTAssertTrue(text(ofDay: 54).contains("continue with today"))
        XCTAssertTrue(text(ofDay: 54).contains("pick up your routine"))
        XCTAssertTrue(text(ofDay: 54).contains("never sends you back to day 1"))
        for phrase in ["catch up on", "make up for", "fell short", "let yourself down", "no excuse", "must log", "you need to log"] {
            XCTAssertFalse(all.lowercased().contains(phrase), phrase)
        }
    }

    // ── Review status ──

    func testEveryLessonIsADraftAndHealthTopicsAreFlaggedForClinicalReview() {
        for lesson in lessons {
            XCTAssertEqual(lesson.review.status, .draft, lesson.id)
            if Guard.namesAHealthTopic(lesson.body.paragraphs.joined(separator: " ")) {
                XCTAssertTrue(lesson.review.containsHealthInterpretation, "\(lesson.id) names a health topic and is not flagged")
            }
        }
        // Wherever the schedule already marks a lesson as health content, the text agrees.
        for definition in content.days where definition.lesson.review.containsHealthInterpretation {
            XCTAssertEqual(ProgrammeLessonsDraft.lesson(forID: definition.lesson.id)?.review.containsHealthInterpretation, true,
                           definition.lesson.id)
        }
        for day in [40, 47] {
            XCTAssertEqual(content.dayKind(forDay: day), .testGuidance)
            XCTAssertEqual(ProgrammeLessonsDraft.lesson(forID: content.day(day)?.lesson.id ?? "")?.review.containsHealthInterpretation, true)
        }
    }

    // ── House style and pinned totals ──

    func testUKSpellingIsUsedAcrossTheWrittenContent() {
        let all = ProgrammeContent.draftWrittenSurfaces.joined(separator: " ").lowercased()
        for word in ["programme", "colour", "organise", "recognise", "fibre", "yoghurt", "practising", "judgement"] {
            XCTAssertTrue(all.contains(word), "expected the UK spelling \"\(word)\" somewhere in the content")
        }
    }

    func testTotalsArePinnedSoLaterEditsAreDeliberate() {
        XCTAssertEqual(lessons.count, 90)
        XCTAssertEqual(lessons.reduce(0) { $0 + $1.body.paragraphs.count }, 341)
        XCTAssertEqual(lessons.filter { $0.review.containsHealthInterpretation }.count, 82)
        XCTAssertEqual(ProgrammeContent.draftWrittenSurfaces.count,
                       content.allSurfaces.count + ProgrammeDayCopyDraft.allSurfaces.count
                           + ProgrammeLessonsDraft.allSurfaces.count + ProgrammeGuideDraft.allSurfaces.count)
    }
}
