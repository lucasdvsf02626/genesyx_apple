import XCTest
@testable import GenesyxCore

/// The words My Fertility Picture shows: its own registry, the evidence copy it shares with the
/// Programme Reviews, and every string a generated picture really holds. Then the source itself:
/// the assembly and the pattern rules may hold no wording of their own.
final class FertilityPictureCopyTests: XCTestCase {

    private typealias F = FertilityPictureFixtures

    // ── Banned-phrase guard ──

    /// `ProgrammeContentTests`' two lists, copied by hand as every banned list in this target is.
    /// Relaxing either is a compliance decision, not a code change.
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
    ]
    private let bannedWords = ["bv", "sti", "stis", "boy", "girl", "hcg"]

    /// The picture's own. Nothing is marked or judged, no cycle is called anything, and nothing
    /// says ovulation took place.
    private let pictureBannedWords = ["streak", "score", "grade", "bad", "poor", "regular", "irregular"]
    private let pictureBannedAnywhere = ["ovulated", "ovulation happened"]

    /// The stem for the word pregnancy is refused everywhere except in a string that is exactly
    /// this: the name of the screen the row opens.
    private let productName = "Pregnancy Test"

    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func violations(in surfaces: [String]) -> [String] {
        var found: [String] = []
        for s in surfaces {
            let lower = s.lowercased()
            for term in bannedAnywhere + pictureBannedAnywhere where lower.contains(term) {
                if term == "pregnan" && s == productName { continue }
                found.append("\"\(term)\" in: \(s)")
            }
            for term in bannedWords + pictureBannedWords where containsWord(term, in: s) {
                found.append("\"\(term)\" in: \(s)")
            }
            if s.contains("\u{2014}") || s.contains("\u{2013}") { found.append("dash in: \(s)") }
            if lower.contains("analyz") || lower.contains("personaliz") { found.append("US spelling in: \(s)") }
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("empty string registered") }
        }
        return found
    }

    func testThePictureCopyHasNoBannedTermsAndFollowsHouseStyle() {
        XCTAssertGreaterThanOrEqual(FertilityPictureCopy.allSurfaces.count, 81, "the registry must not shrink")
        XCTAssertEqual(violations(in: FertilityPictureCopy.allSurfaces), [])
    }

    func testTheSharedEvidenceCopyHasNoBannedTerms() {
        XCTAssertEqual(ProgrammeEvidenceCopy.allSurfaces, [
            "We're still learning your pattern. Continue tracking to build a clearer picture over time.",
            "Observation", "Within-week trend", "Within-cycle pattern", "Cross-cycle pattern",
        ])
        XCTAssertEqual(violations(in: ProgrammeEvidenceCopy.allSurfaces), [])
        XCTAssertEqual(ProgrammeEvidenceLevel.allCases.map(\.rawValue), [1, 2, 3, 4])
        XCTAssertEqual(ProgrammeEvidenceLevel.allCases, ProgrammeEvidenceLevel.allCases.sorted())
    }

    func testTheProductNameIsTheOnlyUseOfThatStemAndIsPinned() {
        XCTAssertEqual(HcgScanCopy.cardTitle, "Pregnancy Test")
        XCTAssertEqual(productName, HcgScanCopy.cardTitle)
        XCTAssertEqual(FertilityPictureCopy.allSurfaces.filter { $0.lowercased().contains("pregnan") }, ["Pregnancy Test"])
    }

    /// The guard has to be able to fail, or the tests above prove nothing.
    func testTheGuardCatchesWhatItShould() {
        XCTAssertEqual(violations(in: ["Estimated fertile window", "Pregnancy Test", "Latest ovulation test",
                                       "Your last recorded cycle was 29 days long."]), [])
        for bad in [
            // The product name with anything beside it, a result included.
            "Pregnancy Test: line detected", "Pregnancy test", "Your pregnancy test results", "Your result was positive",
            // Ovulation stated as having happened.
            "Ovulation confirmed on cycle day 14", "You ovulated on Tuesday", "Ovulated", "Ovulation happened this week",
            // A verdict on a cycle or a day.
            "Your cycles are regular", "An irregular cycle", "A poor night", "A bad week", "Nutrition score",
            "Grade A", "A 5 day streak",
            // House style.
            "Days 9 \u{2013} 15", "Day 3 \u{2014} today", "Unlock your picture", "An empowering view", "Personalized for you", " ",
        ] {
            XCTAssertFalse(violations(in: [bad]).isEmpty, "the guard let through: \(bad)")
        }
    }

    // ── The registry holds everything ──

    func testEveryDraftStringIsRegistered() {
        let drafts = [
            "My Fertility Picture", "Current cycle", "Testing", "Everyday health", "Programme", "Patterns",
            "Estimated cycle day", "Estimated phase", "Estimated fertile window", "Recorded cycle day",
            "Estimated from your cycle settings. An estimate is not a record.",
            "Latest ovulation test", "Latest pH reading", "pH readings in the last 30 days",
            "Last recorded sleep", "Water today", "Food groups", "Latest mood", "Latest energy", "Low", "Normal", "High",
            "Symptoms recorded today",
            "Programme day", "Day 23 of 90", "90-Day Programme completed", "Today", "2 of 5 activities completed today",
            "This programme week", "Programme consistency",
            "Your last recorded cycle was 29 days long.",
            "In the last 7 days you recorded something on 5 days.",
            "In your current recorded cycle you have recorded something on 12 of 18 days.",
            "In your current recorded cycle you have recorded 3 ovulation test results.",
            "In your current recorded cycle you have recorded 4 pH readings.",
            "Across your 3 recorded cycles, cycle length ranged from 27 to 30 days.",
            "Your 3 recorded cycles were each 28 days long.",
            // The same two where a recorded cycle was left out of the count.
            "Across your 3 recorded cycles of 21 to 35 days, cycle length ranged from 28 to 29 days.",
            "Your 3 recorded cycles of 21 to 35 days were each 28 days long.",
            // The singular forms.
            "Day 1 of 90", "1 of 1 activity completed today",
            "Your last recorded cycle was 1 day long.",
            "In the last 7 days you recorded something on 1 day.",
            "In your current recorded cycle you have recorded something on 1 of 1 day.",
            "In your current recorded cycle you have recorded 1 ovulation test result.",
            "In your current recorded cycle you have recorded 1 pH reading.",
        ]
        let registry = Set(FertilityPictureCopy.allSurfaces)
        for draft in drafts { XCTAssertTrue(registry.contains(draft), draft) }
    }

    func testEveryBorrowedStringIsRegistered() {
        let registry = Set(FertilityPictureCopy.allSurfaces)
        let borrowed = [HcgScanCopy.cardTitle, HcgScanCopy.showHistory, LhScanCopy.resultNote, "Cycle day 1",
                        "Low LH", "LH rising", "LH surge detected", "Test invalid",
                        "Period", "Follicular Phase", "Ovulatory Phase", "Luteal Phase",
                        "Healthy", "Elevated", "Great", "Good", "Okay", "Low",
                        "1 of 6 food groups today", "6 of 6 food groups today",
                        // A consistency figure, in the Programme Reviews' words.
                        "79%", "1 of 1 activity completed", "29 of 37 activities completed",
                        "29 of 37 activities completed, 1 partly completed", "3 of 37 activities partly completed"]
            + ProgrammeEvidenceCopy.allSurfaces
        for string in borrowed { XCTAssertTrue(registry.contains(string), string) }
        // The unreadable title is never shown, so it is not borrowed.
        XCTAssertFalse(registry.contains(LhScanCopy.unreadableTitle))
    }

    // ── What a picture really shows ──

    /// What the registry's functions and the borrowed formatters give for any figure in reach.
    private static let anyFigure: Set<String> = {
        var strings: Set<String> = []
        for n in 0...100 {
            strings.formUnion([
                String(n), ProgrammeReviewCopy.percentage(n), FertilityPictureCopy.dayOfProgramme(n),
                FertilityPictureCopy.phValue(Double(n) / 10), LhScanCopy.cycleDayLabel(n),
                FertilityPictureCopy.lastCycleLength(n), FertilityPictureCopy.recordedDaysThisWeek(n),
                FertilityPictureCopy.lhResultsInCycle(n), FertilityPictureCopy.phReadingsInCycle(n),
            ])
            for m in 0...100 {
                strings.formUnion([
                    FertilityPictureCopy.activitiesCompletedToday(n, of: m),
                    FertilityPictureCopy.recordedDaysInCycle(n, of: m),
                ])
                // A week or a programme with no credit has no row, so its counts are not among them.
                for partly in 0...5 where n + partly > 0 {
                    strings.insert(ProgrammeReviewCopy.activitiesCompleted(n, of: m, partlyCompleted: partly))
                }
            }
        }
        // Nought is never shown: not as a count of nothing, and not as a percentage.
        strings.subtract([String(0), ProgrammeReviewCopy.percentage(0)])
        for cycles in 3...6 {
            for bounds in [nil, CycleEngine.cycleLengthRange] {
                for shortest in CycleEngine.cycleLengthRange {
                    strings.insert(FertilityPictureCopy.cycleLengthsEqual(cycles: cycles, length: shortest, ofLength: bounds))
                    for longest in CycleEngine.cycleLengthRange {
                        strings.insert(FertilityPictureCopy.cycleLengthRange(
                            cycles: cycles, shortest: shortest, longest: longest, ofLength: bounds))
                    }
                }
            }
        }
        for minutes in 0...(24 * 60) { strings.insert(SleepInsightLogic.durationLabel(minutes)) }
        return strings
    }()

    private func pictures() -> [(name: String, input: FertilityPictureInput)] {
        var completed = F.rich
        completed.programmeState = ProgrammeState(startedOn: F.today.minusDays(90))
        var fewCycles = F.rich
        fewCycles.cycles = F.cycles(lengths: [30, 28], latestStart: F.today.minusDays(17))
        fewCycles.consistency = F.report(today: ProgrammeTodayProgress(completed: 1, partlyCompleted: 0, total: 1),
                                         week: F.figure(completed: 2, of: 4))
        fewCycles.hydrationUnit = .milliliters
        // Part credit in the week, and a recorded cycle too long to be counted across cycles.
        var partCredit = F.rich
        partCredit.cycles = F.cycles(lengths: [27, 45, 30, 28], latestStart: F.today.minusDays(17))
        partCredit.consistency = F.report(week: F.figure(completed: 5, partly: Array(repeating: 0.9, count: 5), of: 10))
        // One glass of water in a week of thirty activities: credit that rounds to nought.
        var littleCredit = F.rich
        littleCredit.consistency = F.report(week: F.figure(completed: 0, partly: [0.1], of: 30))
        // A week with activities counted and none done.
        var noCredit = F.rich
        noCredit.consistency = F.report(week: F.figure(completed: 0, of: 6))
        return [("rich", F.rich), ("sparse", F.sparse), ("empty", F.input()), ("completed", completed), ("few cycles", fewCycles),
                ("part credit", partCredit), ("little credit", littleCredit), ("no credit", noCredit)]
    }

    func testGeneratedPicturesPassTheGuard() {
        var shown: [String] = []
        for (name, input) in pictures() {
            let surfaces = FertilityPictureLogic.picture(input).surfaces
            XCTAssertFalse(surfaces.isEmpty, name)
            XCTAssertEqual(violations(in: surfaces), [], name)
            shown += surfaces
        }
        // The fixtures reach the wording they are there for.
        for wording in ["5 partly completed", "1 of 30 activities partly completed", "recorded cycles of 21 to 35 days"] {
            XCTAssertTrue(shown.contains { $0.contains(wording) }, wording)
        }
    }

    func testEveryGeneratedStringIsRegisteredOrComesFromARegisteredFormatter() {
        for (name, input) in pictures() {
            var allowed = Set(FertilityPictureCopy.allSurfaces).union(Self.anyFigure)
            allowed.formUnion(ProgrammePhase.allCases.compactMap { input.content.phaseTitles[$0] })
            if let water = input.logsByDate[input.today]?.waterMl {
                allowed.insert(HydrationFormat.progress(ml: water, goalMl: input.waterGoalMl, unit: input.hydrationUnit,
                                                        glassMl: input.glassMl))
            }
            for surface in FertilityPictureLogic.picture(input).surfaces {
                XCTAssertTrue(allowed.contains(surface), "\(name): \(surface)")
            }
        }
        // The check can fail: a string from nowhere is not in the set, and nor is a nought.
        for stray in ["Your fertile window is open", "0", "0%", "0 of 6 activities completed"] {
            XCTAssertFalse(Set(FertilityPictureCopy.allSurfaces).union(Self.anyFigure).contains(stray), stray)
        }
    }

    // ── Source ──

    private let sourceNames = ["FertilityPicture.swift", "FertilityPictureCopy.swift", "FertilityPictureEvidence.swift",
                               "FertilityPicturePatterns.swift"]

    private func source(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Sources/GenesyxCore/Programme").appendingPathComponent(name),
                          encoding: .utf8)
    }

    private func withoutComments(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line }
            .joined(separator: "\n")
    }

    private func stringLiterals(in code: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: "\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
        let range = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: range).compactMap {
            Range($0.range(at: 1), in: code).map { String(code[$0]) }
        }
    }

    /// No clock or device calendar read inside a rule, and none of the existing strings that
    /// break the picture's rules: the dashed lines, the phase line that folds the fertile window
    /// into the phase, and the copy that says what a result or a reading means.
    func testThePictureSourcesNameNothingTheyMustNot() throws {
        let forbidden = [".today()", "Calendar.current", "positiveBody", "phaseSubLabel", "readingCountLine",
                         "OvulationLogic", "PhContextLogic", "PhCopy."]
        for name in sourceNames {
            let text = try source(name)
            XCTAssertGreaterThan(text.count, 500, name)
            for term in forbidden { XCTAssertFalse(text.contains(term), "\(name) names \(term)") }
        }
    }

    /// The assembly and the pattern rules build rows and statements from the registry. A string
    /// with a space in it would be wording the guard never sees.
    func testTheAssemblyAndThePatternRulesHoldNoWordingOfTheirOwn() throws {
        for name in ["FertilityPicture.swift", "FertilityPicturePatterns.swift"] {
            let literals = try stringLiterals(in: withoutComments(try source(name)))
            XCTAssertEqual(literals.filter { $0.contains(" ") }, [], name)
        }
        // The check can fail, and a comment is left alone.
        let sample = "row(label: \"Two words\", id: \"one-word\") // \"in a comment\""
        XCTAssertEqual(try stringLiterals(in: withoutComments(sample)), ["Two words", "one-word"])
        // The registry is where the wording is.
        XCTAssertFalse(try stringLiterals(in: withoutComments(try source("FertilityPictureCopy.swift"))).filter { $0.contains(" ") }.isEmpty)
    }
}
