import XCTest
@testable import GenesyxCore

/// The Programme Guide: the owner's thirty sections in order, each a short read with a typed
/// action, guarded, carrying the approved safety wording and marked for review.
final class ProgrammeGuideDraftTests: XCTestCase {

    private typealias Guard = ProgrammeWrittenCopyGuard
    private let sections = ProgrammeGuideDraft.sections

    private func text(_ slug: String) -> String {
        ProgrammeGuideDraft.section(slug: slug)?.paragraphs.joined(separator: " ") ?? ""
    }

    // ── Structure ──

    func testTheGuideHasExactlyTheOwnersThirtySectionsInOrder() {
        XCTAssertEqual(sections.map(\.title), [
            "Welcome to Genesyx", "Your Fertility Kit", "How the 90-Day Programme Works", "Understanding Your Cycle",
            "Cycle Phases", "Cycle Tracking", "Body Signals", "Mood & Energy", "Symptoms", "Sleep", "Hydration",
            "Your Diet Plan", "Nutrition", "Healthy Routines", "Understanding Fertility", "Ovulation", "LH Testing",
            "Scanning an Ovulation Test", "Vaginal pH", "Scanning a pH Test", "Pregnancy Tests",
            "Understanding Test History", "Supplements", "Consistency", "Understanding Your Insights",
            "Days 1-30", "Days 31-60", "Days 61-90", "Your 90-Day Review", "Continuing With Genesyx",
        ])
        XCTAssertEqual(sections.count, 30)
    }

    /// Slugs are routes and read-history keys. Pinned so a rename is a decision.
    func testSlugsAreUniqueAndPinned() {
        XCTAssertEqual(sections.map(\.id), [
            "welcome-to-genesyx", "your-fertility-kit", "how-the-90-day-programme-works", "understanding-your-cycle",
            "cycle-phases", "cycle-tracking", "body-signals", "mood-and-energy", "symptoms", "sleep", "hydration",
            "your-diet-plan", "nutrition", "healthy-routines", "understanding-fertility", "ovulation", "lh-testing",
            "scanning-an-ovulation-test", "vaginal-ph", "scanning-a-ph-test", "pregnancy-tests",
            "understanding-test-history", "supplements", "consistency", "understanding-your-insights",
            "days-1-30", "days-31-60", "days-61-90", "your-90-day-review", "continuing-with-genesyx",
        ])
        XCTAssertEqual(Set(sections.map(\.id)).count, 30)
        for section in sections {
            XCTAssertEqual(section.slug, section.id)
            XCTAssertNotNil(section.id.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression), section.id)
            XCTAssertEqual(ProgrammeGuideDraft.section(slug: section.id)?.title, section.title)
        }
        XCTAssertNil(ProgrammeGuideDraft.section(slug: "shettles-method"))
        XCTAssertNil(ProgrammeGuideDraft.section(slug: ""))
    }

    func testEverySectionIsAShortReadInParagraphs() {
        var seen = Set<String>()
        for section in sections {
            let words = Guard.wordCount(section.paragraphs)
            XCTAssertTrue((60...180).contains(words), "\(section.id) has \(words) words")
            XCTAssertGreaterThanOrEqual(section.paragraphs.count, 3, section.id)
            for paragraph in section.paragraphs {
                XCTAssertFalse(paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, section.id)
                XCTAssertLessThanOrEqual(Guard.wordCount([paragraph]), 70, "long paragraph in \(section.id)")
                XCTAssertTrue(seen.insert(paragraph).inserted, "repeated in \(section.id): \(paragraph)")
            }
        }
    }

    // ── Calls to action ──

    func testEverySectionLeadsToATypedActionInTheApp() {
        let allowed: Set<ProgrammeDestination> = [
            .hydration, .nutrition, .cycle, .dailyLog, .insights, .lhTest, .phTest, .fertilityKitGuide,
            .weeklyReview, .programmeProgress,
        ]
        for section in sections {
            XCTAssertTrue(allowed.contains(section.callToAction.destination), section.id)
            XCTAssertFalse(section.callToAction.label.isEmpty, section.id)
            XCTAssertLessThanOrEqual(section.callToAction.label.count, 30, "button label in \(section.id)")
            XCTAssertFalse(section.callToAction.label.hasSuffix("."), section.id)
        }
        func slugs(_ destination: ProgrammeDestination) -> [String] {
            sections.filter { $0.callToAction.destination == destination }.map(\.id)
        }
        // The ovulation-test screen is absent from a Release build today, so the two sections
        // that lead there are pinned: the app has to hide or redirect exactly these.
        XCTAssertEqual(slugs(.lhTest), ["lh-testing", "scanning-an-ovulation-test"])
        XCTAssertEqual(slugs(.phTest), ["vaginal-ph", "scanning-a-ph-test"])
        XCTAssertEqual(slugs(.fertilityKitGuide), ["your-fertility-kit", "pregnancy-tests", "understanding-test-history"])
        XCTAssertEqual(slugs(.hydration), ["hydration"])
        XCTAssertEqual(slugs(.nutrition), ["your-diet-plan", "nutrition"])
        XCTAssertEqual(slugs(.insights), ["understanding-your-insights", "continuing-with-genesyx"])
    }

    // ── Related Learn content ──

    func testRelatedLearnSlugsAreRealAndNeverTheShettlesPiece() throws {
        guard let source = Guard.learnSource() else { throw XCTSkip("App sources not present") }
        var checked = 0
        for section in sections {
            let slugs = Guard.learnSlugs(in: section.relatedContent)
            XCTAssertEqual(slugs.count, section.relatedContent.count, section.id)
            XCTAssertEqual(Set(slugs).count, slugs.count, "slug repeated in \(section.id)")
            for slug in slugs {
                XCTAssertTrue(source.contains("slug: \"\(slug)\""), "no Learn article with slug \(slug) (\(section.id))")
                XCTAssertFalse(slug.contains("shettles"))
                XCTAssertNotEqual(slug, "timing-sex-when-ttc")
                // A guide section never shares a slug with a Learn article, or one route means two things.
                XCTAssertNil(ProgrammeGuideDraft.section(slug: slug), slug)
                checked += 1
            }
        }
        XCTAssertEqual(checked, 53, "related Learn links across the guide")
    }

    func testShettlesIsNeverMentionedAnywhereInTheWrittenContent() {
        for surface in ProgrammeContent.draftWrittenSurfaces {
            XCTAssertFalse(surface.lowercased().contains("shettles"), surface)
        }
        let slugs = ProgrammeDayCopyDraft.all.flatMap { Guard.learnSlugs(in: $0.relatedContent) }
            + sections.flatMap { Guard.learnSlugs(in: $0.relatedContent) }
            + ProgrammeContent.draft.weeks.flatMap { Guard.learnSlugs(in: $0.relatedContent) }
        XCTAssertFalse(slugs.isEmpty)
        for slug in slugs { XCTAssertFalse(slug.lowercased().contains("shettles"), slug) }
    }

    // ── Guard ──

    func testGuideTextPassesTheGuard() {
        XCTAssertEqual(Guard.violations(in: ProgrammeGuideDraft.allSurfaces, allowingProductName: true), [])
    }

    /// The owner's section title is why the product name is let through at all. It appears in
    /// that section and in the list of what the kit contains, and nowhere else in the guide.
    func testTheTestProductIsNamedOnlyInTheTwoSectionsThatNeedIt() {
        let naming = sections.filter { section in
            ([section.title, section.callToAction.label] + section.paragraphs).contains { $0.lowercased().contains("pregnan") }
        }
        XCTAssertEqual(naming.map(\.id), ["your-fertility-kit", "pregnancy-tests"])
    }

    func testEveryGuideStringIsInTheRegistry() {
        let own = Set(ProgrammeGuideDraft.allSurfaces)
        let all = Set(ProgrammeContent.draftWrittenSurfaces)
        for section in sections {
            for s in [section.title, section.callToAction.label] + section.paragraphs {
                XCTAssertTrue(own.contains(s), s)
                XCTAssertTrue(all.contains(s), s)
            }
        }
        XCTAssertEqual(ProgrammeGuideDraft.allSurfaces.count, sections.reduce(0) { $0 + 2 + $1.paragraphs.count })
    }

    // ── Safety wording ──

    func testTestSectionsCarryTheApprovedWording() {
        XCTAssertTrue(text("lh-testing").contains(LhScanCopy.resultNote))
        XCTAssertTrue(text("ovulation").contains("The app never states that ovulation has happened."))
        XCTAssertTrue(text("understanding-fertility").contains("It is not a method of contraception and should not be used as one."))
        XCTAssertTrue(text("vaginal-ph").contains(PhCopy.accuracyCaveat))
        XCTAssertTrue(text("vaginal-ph").contains(PhCopy.elevatedSignpost))
        XCTAssertTrue(text("vaginal-ph").contains(PhCopy.disclaimer))
        XCTAssertTrue(text("vaginal-ph").contains("a reading is not a statement about your health or your fertility"))
        XCTAssertTrue(text("pregnancy-tests").contains(HcgScanCopy.aboutNote))
        XCTAssertTrue(text("pregnancy-tests").contains(HcgScanCopy.resultNote))
        XCTAssertTrue(text("pregnancy-tests").contains("it does not stop or alter your programme"))
    }

    func testScanningSectionsNeverPromiseThatTheAppReadsAStrip() {
        for slug in ["scanning-an-ovulation-test", "scanning-a-ph-test"] {
            let section = text(slug)
            XCTAssertTrue(section.contains("Where your version of Genesyx offers"), slug)
            XCTAssertTrue(section.contains("by hand"), slug)
        }
        XCTAssertTrue(text("pregnancy-tests").contains("Where Genesyx offers a place to record a test"))
    }

    func testTheGuideKeepsTheFoodLogUnscoredAndConsistencySupportive() {
        XCTAssertTrue(text("your-diet-plan").contains("The food record is a record, not a target. Nothing here is scored."))
        XCTAssertTrue(text("your-diet-plan").contains("It never produces a nutrition percentage or a grade."))
        XCTAssertTrue(text("consistency").contains("Pick up your routine and continue with today."))
        XCTAssertTrue(text("how-the-90-day-programme-works").contains("welcome back"))
        XCTAssertTrue(text("supplements").contains("This guide does not tell you which supplements to take or in what amount."))
    }

    // ── Review status ──

    func testEverySectionIsADraftAndHealthTopicsAreFlaggedForClinicalReview() {
        for section in sections {
            XCTAssertEqual(section.review.status, .draft, section.id)
            let text = ([section.title, section.callToAction.label] + section.paragraphs).joined(separator: " ")
            if Guard.namesAHealthTopic(text) {
                XCTAssertTrue(section.review.containsHealthInterpretation, "\(section.id) names a health topic and is not flagged")
            }
        }
        XCTAssertEqual(sections.filter { !$0.review.containsHealthInterpretation }.map(\.id),
                       ["how-the-90-day-programme-works", "days-61-90"])
    }

    // ── Pinned totals ──

    func testTotalsArePinnedSoLaterEditsAreDeliberate() {
        XCTAssertEqual(sections.count, 30)
        XCTAssertEqual(sections.reduce(0) { $0 + $1.paragraphs.count }, 114)
        XCTAssertEqual(sections.filter { $0.review.containsHealthInterpretation }.count, 28)
        XCTAssertEqual(sections.filter { $0.relatedContent.isEmpty }.map(\.id), ["your-fertility-kit", "how-the-90-day-programme-works", "pregnancy-tests"])
    }
}
