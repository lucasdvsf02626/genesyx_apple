import XCTest
@testable import GenesyxCore

/// The wording of the two reviews: every sentence is in a registry, the registries pass the
/// banned-phrase guard, and the logic and the models hold no sentence of their own.
final class ProgrammeReviewCopyTests: XCTestCase {

    private typealias RF = ProgrammeReviewFixtures
    private typealias Logic = ProgrammeReviewLogic

    // ── Banned-phrase guard ──

    /// The two lists `ProgrammeContentTests` holds, copied by hand as every guard in this target
    /// is, with "catch up" added for the reviews.
    private let bannedAnywhere = [
        "unlock", "guarantee", "diagnos", "cure", "treat", "infertil", "you are pregnant", "get pregnant fast", "empower",
        "thrush", "infection", "candida", "vaginosis", "prescrib", "leafy greens", "whole grains", "mineral water",
        "you are ovulating", "you ovulated", "you will ovulate", "ovulation confirmed", "confirms ovulation",
        "confirmed", "peak fertility", "most fertile", "best time", "conceive", "conception", "pregnan",
        "intercourse", "have sex", "baby", "gender", "shettles", "sex selection", "boy or girl", "alkaline diet",
        "balance your ph", "sway the sex", "choose the sex", "detox", "flush toxins",
        "congratulat", "due date", "miscarr", "unfortunately", "sorry", "positive", "negative", "expecting", "celebrat",
        "you broke", "you failed", "you missed", "don't lose", "streak is over", "missed", "failed", "should have",
        "behind", "don't forget", "hormone", "optimis", "your journey", "take control of", "boost",
        "catch up",
    ]
    /// Whole words only. The second line is the reviews' own: no word that marks or ranks her.
    private let bannedWords = [
        "bv", "sti", "stis", "boy", "girl", "hcg",
        "streak", "score", "scored", "grade", "bad", "poor",
    ]

    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func violations(in surfaces: [String]) -> [String] {
        var found: [String] = []
        for s in surfaces {
            let lower = s.lowercased()
            for term in bannedAnywhere where lower.contains(term) { found.append("\"\(term)\" in: \(s)") }
            for term in bannedWords where containsWord(term, in: s) { found.append("\"\(term)\" in: \(s)") }
            if s.contains("\u{2014}") { found.append("em dash in: \(s)") }
            if s.contains("\u{2013}") { found.append("en dash in: \(s)") }
            if lower.contains("analyz") || lower.contains("personaliz") { found.append("US spelling in: \(s)") }
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("empty string registered") }
        }
        return found
    }

    func testReviewCopyHasNoBannedTermsAndFollowsHouseStyle() {
        // 18 constants, 10 consistency samples, 2 per tracked kind, 5 noticed samples, and a name
        // and a line to continue for each of the 14 named routines.
        XCTAssertGreaterThanOrEqual(ProgrammeReviewCopy.allSurfaces.count, 18 + 10 + 12 * 2 + 5 + 14 + 14,
                                    "the registry must not shrink")
        XCTAssertEqual(violations(in: ProgrammeReviewCopy.allSurfaces), [])
    }

    func testTheSharedEvidenceCopyPassesTheSameGuard() {
        XCTAssertGreaterThanOrEqual(ProgrammeEvidenceCopy.allSurfaces.count, 5, "the registry must not shrink")
        XCTAssertEqual(violations(in: ProgrammeEvidenceCopy.allSurfaces), [])
    }

    /// The guard has to be able to fail, or the tests above prove nothing.
    func testTheGuardCatchesWhatItShould() {
        XCTAssertEqual(violations(in: ["Week 3 complete", "Welcome back. Continue with today."]), [])
        for bad in ["You failed this week", "You are behind", "Streak broken", "You missed your goal",
                    "Your score this week", "A poor week", "Time to catch up", "Week 3 \u{2013} complete",
                    "Week 3 \u{2014} complete", "Unlock your review"] {
            XCTAssertFalse(violations(in: [bad]).isEmpty, "the guard let through: \(bad)")
        }
    }

    // ── The registry ──

    func testTheRegistryHoldsEveryConstantAndEveryFunction() {
        let surfaces = Set(ProgrammeReviewCopy.allSurfaces)
        for constant in [
            "Programme consistency", "What you tracked", "What we noticed", "Your strongest routine",
            "Next week's focus", "Your 90-Day Review", "Programme period", "Hydration consistency",
            "Sleep tracking", "Body check-ins", "Your strongest routines", "Patterns", "What to continue",
            "No Programme activities recorded.", "Welcome back. Continue with today.",
            "Pick up your routine whenever you are ready.", "You recorded something on every day of the week.",
            "Everything in your Fertility Kit stays available. Continue with today.",
        ] {
            XCTAssertTrue(surfaces.contains(constant), constant)
        }
        for sample in [
            "Week 3 complete", "79%", "1 of 1 activity completed", "29 of 37 activities completed",
            "29 of 37 activities completed, 1 partly completed", "3 of 37 activities partly completed",
            "1 of 1 activity partly completed", "79%, 29 of 37 activities completed", "Something recorded on 5 of 7 days", "Nutrition check-in on 1 day",
            "Water recorded on 5 days", "Water goal reached on 1 day", "Sleep recorded for 1 night",
            "Sleep recorded for 5 nights", "Mood recorded on 5 days", "Energy recorded on 5 days",
            "Symptoms recorded on 1 day", "1 period start recorded", "5 period starts recorded",
            "1 pH reading recorded", "5 pH readings recorded", "1 ovulation test result recorded",
            "5 ovulation test results recorded", "1 programme lesson read", "5 programme lessons read",
            "You reached your water goal on 4 days.",
            "You recorded something on 1 day this week and 3 the week before.",
            "You recorded something on 5 days this week and 3 the week before.",
            "Your programme consistency was 79% this week and 71% the week before.",
            "Sleep check-in", "pH test", "Fertility Kit guide",
            "Continue with your sleep check-in.", "Continue with your pH test.", "Continue with your Fertility Kit guide.",
        ] {
            XCTAssertTrue(surfaces.contains(sample), sample)
        }
    }

    func testEveryActivityButThePregnancyTestGuidanceHasARoutineName() {
        for category in ProgrammeTaskCategory.allCases {
            let name = ProgrammeReviewCopy.routineName(for: category)
            XCTAssertEqual(name == nil, category == .pregnancyTestRelatedAction, category.rawValue)
            XCTAssertEqual(ProgrammeReviewCopy.continueWith(category) == nil, name == nil, category.rawValue)
        }
    }

    // ── What the reviews really produce ──

    /// The six reviews of the fixtures: a full week, a partly recorded week, an empty week, week
    /// 13, a full programme and an empty programme.
    private func generated() throws -> [(name: String, surfaces: [String], input: ProgrammeReviewInput)] {
        let weeks: [(String, Int, ProgrammeReviewInput)] = [
            ("full week", 4, RF.fullWeeks), ("partial week", 4, RF.workedWeek),
            ("empty week", 4, RF.emptyWeek), ("week 13", 13, RF.lastWeek),
        ]
        let programmes = [("full programme", RF.fullProgramme()), ("empty programme", RF.emptyProgramme)]
        return try weeks.map { ($0.0, try XCTUnwrap(Logic.weekly(week: $0.1, input: $0.2)).surfaces, $0.2) }
            + programmes.map { ($0.0, try XCTUnwrap(Logic.ninetyDay($0.1)).surfaces, $0.1) }
    }

    /// A string with its numbers taken out, so "5 of 7 days" and "6 of 6 days" are one sentence.
    private func shape(_ text: String) -> String {
        text.replacingOccurrences(of: "[0-9]+", with: "#", options: .regularExpression)
    }

    func testEveryStringAReviewProducesPassesTheGuardAndComesFromARegistry() throws {
        let registries = Set((ProgrammeReviewCopy.allSurfaces + ProgrammeEvidenceCopy.allSurfaces).map(shape))
        for review in try generated() {
            XCTAssertGreaterThanOrEqual(review.surfaces.count, 4, review.name)
            XCTAssertEqual(violations(in: review.surfaces), [], review.name)
            // Besides the two registries, a review repeats the programme content's own guarded
            // strings and the pattern statements it was handed.
            let known = registries
                .union(review.input.content.allSurfaces.map(shape))
                .union(review.input.patterns.map { shape($0.text) })
            for surface in review.surfaces {
                XCTAssertTrue(known.contains(shape(surface)), "\(review.name): \(surface)")
            }
        }
    }

    // ── Source guards ──

    private func source(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Sources/GenesyxCore/Programme/" + name), encoding: .utf8)
    }

    /// String literals that hold a space, comments left out: where a sentence would have to be.
    private func sentenceLiterals(in text: String) throws -> Int {
        let code = text.components(separatedBy: "\n")
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line }
            .joined(separator: "\n")
        let literal = try NSRegularExpression(pattern: "\"[^\"\\n]* [^\"\\n]*\"")
        return literal.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
    }

    func testTheLogicAndTheModelsHoldNoSentence() throws {
        XCTAssertEqual(try sentenceLiterals(in: source("ProgrammeReviewLogic.swift")), 0)
        XCTAssertEqual(try sentenceLiterals(in: source("ProgrammeReviewModels.swift")), 0)
        // The same check finds the sentences where they do live.
        XCTAssertGreaterThan(try sentenceLiterals(in: source("ProgrammeReviewCopy.swift")), 30)
        XCTAssertEqual(try sentenceLiterals(in: "let a = \"one two\" // \"three four\"\n// \"five six\""), 1)
    }

    /// No clock, and nothing of the weekly summary that is not a count: its ready-made sentence
    /// and its pH average are never read.
    func testTheReviewSourcesReadNoClockAndNoSummaryWording() throws {
        for name in ["ProgrammeReviewModels.swift", "ProgrammeReviewLogic.swift", "ProgrammeReviewCopy.swift"] {
            let text = try source(name)
            for term in [".today()", "Calendar.current", "narrative", "phAverage"] {
                XCTAssertFalse(text.contains(term), "\(name) references \(term)")
            }
        }
    }
}
