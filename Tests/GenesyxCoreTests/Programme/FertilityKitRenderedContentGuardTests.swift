import XCTest
@testable import GenesyxCore

/// The one check over text the Fertility Kit screens print but this wave did not write: the
/// ninety days, the lessons, the guide, the review and picture copy, the Diet Plan, and the
/// strings borrowed from the scan, recipe and tracker screens. A UI sweep visits a handful of
/// the ninety days; this reads all of them.
final class FertilityKitRenderedContentGuardTests: XCTestCase {

    /// Every pre-existing core string a kit screen renders.
    private var rendered: [String] {
        let content = ProgrammeContent.draft
        var out: [String] = []
        // The ninety days: title, focus, introduction, reflection, the written day and its lesson.
        for day in 1...ProgrammeCalendar.totalDays {
            if let definition = content.day(day) {
                out += [definition.title, definition.focus, definition.introduction]
                out += definition.optionalReflection.map { [$0] } ?? []
                out += definition.nutritionFocus.map { [$0.title, $0.detail] } ?? []
            }
            if let writing = ProgrammeDayCopyDraft.writing(forDay: day) {
                out += [writing.copy.title, writing.copy.focus, writing.copy.introduction, writing.whyThisMatters]
                out += writing.reflection.map { [$0] } ?? []
            }
        }
        out += ProgrammeLessonsDraft.all.flatMap(\.body.paragraphs)
        out += content.weeks.flatMap { [$0.themeTitle, $0.purpose, $0.nutritionFocus.title, $0.nutritionFocus.detail] }
        out += ProgrammePhase.allCases.compactMap { content.phaseTitles[$0] }
        out += ProgrammeGuideDraft.allSurfaces
        out += ProgrammeReviewCopy.allSurfaces
        out += ProgrammeTaskCategory.allCases.compactMap(ProgrammeReviewCopy.routineName(for:))
        // The picture's registry already lists what it borrows: the ovulation test note and
        // titles, the pH labels, the pregnancy row's title and detail, the phase labels.
        out += FertilityPictureCopy.allSurfaces
        out += ProgrammeEvidenceCopy.allSurfaces
        // Your Diet Plan, and the recipes its meal cards show.
        out += DietPlanContent.draft.allSurfaces
        out += [FoodLogCopy.footnote, RecipeCopy.ingredientsHeading, RecipeCopy.methodHeading]
        out += DietPlanContent.draft.mealCards.compactMap(\.recipe).flatMap { [$0.name] + $0.ingredients + $0.method }
        out += FoodGroup.allCases.map(\.label)
        out += DietPlanMealCategory.allCases.map(\.label)
        out += [LhScanCopy.resultNote] + PhStatus.allCases.map(\.label)
        out += Phase.allCases.compactMap { CycleContent.phaseLabel[$0] }
        // A day's words are reached by more than one road: each string is read once.
        return Array(Set(out)).sorted()
    }

    func testTheSetIsTheWholeOfTheWrittenProgramme() {
        XCTAssertGreaterThan(rendered.count, 1_000, "the gathering found almost nothing: the sources moved, not the words")
        XCTAssertEqual(ProgrammeLessonsDraft.all.count, 90)
        XCTAssertEqual(ProgrammeGuideDraft.sections.count, 30)
    }

    /// The product rules that hold for every word a user can read.
    func testNothingAKitScreenPrintsBreaksAProductRule() {
        for text in rendered {
            XCTAssertEqual(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.onScreenFailing, in: text), [], text)
        }
    }

    /// Words that are fair in a lesson and would not be in new interface copy. Nothing here is
    /// changed by this test: the count per term is pinned, so a NEW occurrence turns it red and
    /// is read by a person. The three phrases at the top are the disputed set (C-01).
    func testTheWordsReadByAPersonAreCountedAndPinned() {
        var counts: [String: Int] = [:]
        for text in rendered {
            for term in FertilityKitCopyGuard.hits(FertilityKitCopyGuard.onScreenReported, in: text) {
                counts[term, default: 0] += 1
            }
        }
        if ProcessInfo.processInfo.environment["KIT_PRINT_REPORTED"] != nil {
            for text in rendered {
                let hits = FertilityKitCopyGuard.hits(FertilityKitCopyGuard.onScreenReported, in: text)
                if !hits.isEmpty { print("REPORTED \(hits): \(text.prefix(160))") }
            }
        }
        XCTAssertEqual(counts, Self.pinned, "a string a kit screen prints gained or lost one of the reported words")
    }

    /// Strings holding each term, as found on 6 Oct 2026. Recorded, not approved.
    /// Run with `KIT_PRINT_REPORTED=1` to print each string beside the terms found in it.
    private static let pinned: [String: Int] = [
        "welcome back": 3, "continue with today": 8, "pick up your routine": 5,
        "score": 11, "grade": 6, "rating": 2, "catch up": 1,
        "poor": 3, "regular": 5, "irregular": 3, "normal": 11, "late": 3,
        // The en dash: three recipe method steps ("20\u{2013}25 minutes").
        "\u{2013}": 3,
    ]
}
