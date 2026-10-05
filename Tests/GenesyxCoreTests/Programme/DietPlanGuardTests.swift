import XCTest
@testable import GenesyxCore

/// The two promises Your Diet Plan has to keep, checked against the copy and against the source.
///
/// 1. The food group tracker is a record, not a target. The Diet Plan sources may count days; they
///    may not turn what she ate into a mark of any kind.
/// 2. The copy names food groups, examples and practical ideas. It makes no claim about what a food
///    does, and none of the phrases the other content guards refuse.
final class DietPlanGuardTests: XCTestCase {

    private let content = DietPlanContent.draft

    // ── Sources ──

    private struct Source {
        let name: String
        /// The file as written.
        let text: String
        /// The file with comments removed: what compiles, including every string.
        let code: String
    }

    private func withoutComments(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line }
            .joined(separator: "\n")
    }

    private func dietPlanSources() throws -> [Source] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("Sources/GenesyxCore/Programme")
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent.hasPrefix("DietPlan") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map {
                let text = try String(contentsOf: $0, encoding: .utf8)
                return Source(name: $0.lastPathComponent, text: text, code: withoutComments(text))
            }
    }

    private func stringLiterals(in code: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: "\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
        let range = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: range).compactMap {
            Range($0.range(at: 1), in: code).map { String(code[$0]) }
        }
    }

    // ── A record, not a target ──

    /// The words a diet mark would be built from. None may appear in Diet Plan code: not in a name,
    /// not in a string. A comment may use one only to state this rule.
    private let neverInCode = ["score", "percent", "%", "grade", "rating", "quality"]
    /// Kept out for the same reason: nothing here works out a share, orders the groups, or lists
    /// what was left blank.
    private let alsoNeverInCode = ["double", "float", "rank", "best", "worst", "missing"]

    private func markTerms(in code: String) -> [String] {
        let lower = code.lowercased()
        return (neverInCode + alsoNeverInCode).filter { lower.contains($0) }
    }

    func testDietPlanSourcesHoldNothingADietMarkCouldBeBuiltFrom() throws {
        let sources = try dietPlanSources()
        XCTAssertEqual(sources.map(\.name),
                       ["DietPlan.swift", "DietPlanContent.swift", "DietPlanDraftContent.swift", "DietPlanFacts.swift"])
        for source in sources {
            XCTAssertEqual(markTerms(in: source.code), [], "\(source.name) holds a term a diet mark is built from")
        }
    }

    /// The guard has to be able to fail, or the test above proves nothing.
    func testTheSourceGuardCatchesWhatItShould() {
        for bad in ["let percentage = days * 100 / elapsed", "func dietScore() -> Int { 0 }", "let share = \"40%\"",
                    "var foodGrade: String", "let starRating = 4", "let dietQuality = 1", "let share: Double = 0.5",
                    "groups.sorted { rank($0) < rank($1) }", "let missingGroups: [FoodGroup] = []"] {
            XCTAssertFalse(markTerms(in: withoutComments(bad)).isEmpty, "the guard let through: \(bad)")
        }
        // A comment may state the rule, and ordinary counting code is left alone.
        XCTAssertEqual(markTerms(in: withoutComments("// There is no score and no percentage here.")), [])
        XCTAssertEqual(markTerms(in: withoutComments("let daysWithCheckIn = days.filter(\\.hasCheckIn).count")), [])
    }

    /// The facts are whole-number counts and nothing else, in the type as well as in the wording.
    func testEveryFigureIsAWholeNumberOfDaysOrGroups() {
        let facts = DietPlanFacts.trailing(days: 7, endingOn: CalendarDate(2026, 3, 30), logsByDate: [:])
        let today = DietPlanFacts.day(nil)
        let figures: [Any] = [facts.daysElapsed, facts.daysWithCheckIn, facts.days(recording: .fruit),
                              today.recordedCount, today.groupTotal] + facts.groupDays.map { $0.days as Any }
        XCTAssertTrue(figures.allSatisfy { $0 is Int })
    }

    // ── Banned phrases ──

    /// The nutrition guards: the app's `NutritionHydrationTests` and `HydrationInsightTests`, and
    /// the claim words in `ContentTests`, `RecipeContentTests` and `NutritionDaySignalTests`.
    private let nutritionGuards = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection", "detox", "flush toxins",
        "boost", "improve", "helps you", "help you", "good for", "supports", "support your", "increases",
        "reduces", "prevents", "treats", "cures", "balances", "optimis", "fertility", "conceive", "egg quality",
        "hormone", "cleanse",
    ]
    /// The programme guard, as held in `ProgrammeContentTests`.
    private let programmeGuard = [
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
    /// The Diet Plan's own: no claim for a food, no figure to eat to, no judgement of a food.
    private let dietPlanGuard = [
        "fertil", "ovulat", "conceiv", "conception", "pregnan", "hormone", "egg quality", "boost", "superfood",
        "detox", "cleanse", "calorie", "kcal", "macro", "weight", "bmi", "slim", "good food", "bad food",
        "should", "must eat", "cure", "treat", "diagnos", "guarantee", "alcohol",
        "supplement", "vitamin", "dosage", "portion", "unhealthy", "junk", "guilt",
    ]
    private let bannedWords = ["bv", "sti", "stis", "boy", "girl", "hcg"]
    private let placeholders = ["coming soon", "placeholder", "tbc", "tbd", "todo", "lorem", "to follow", "to be written", "draft"]

    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func violations(in surfaces: [String]) -> [String] {
        var found: [String] = []
        for s in surfaces {
            let lower = s.lowercased()
            for term in Set(nutritionGuards + programmeGuard + dietPlanGuard).sorted() where lower.contains(term) {
                found.append("\"\(term)\" in: \(s)")
            }
            for term in bannedWords where containsWord(term, in: s) { found.append("\"\(term)\" in: \(s)") }
            if s.contains("\u{2014}") || s.contains("\u{2013}") { found.append("dash in: \(s)") }
            if lower.contains("analyz") || lower.contains("personaliz") || lower.contains("yogurt") || lower.contains("fiber") {
                found.append("US spelling in: \(s)")
            }
        }
        return found
    }

    func testDietPlanCopyHasNoBannedTermsAndFollowsHouseStyle() {
        XCTAssertGreaterThanOrEqual(content.allSurfaces.count, 120, "the registry must not shrink")
        XCTAssertEqual(violations(in: content.allSurfaces), [])
        for s in content.allSurfaces {
            XCTAssertFalse(s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty string registered")
            XCTAssertEqual(s, s.trimmingCharacters(in: .whitespacesAndNewlines), "stray space around: \(s)")
            XCTAssertFalse(s.contains("  "), "double space in: \(s)")
            for term in placeholders {
                XCTAssertFalse(s.lowercased().contains(term), "placeholder wording \"\(term)\" in: \(s)")
            }
        }
    }

    /// Every string written in the Diet Plan sources, whether or not it reached the registry: the
    /// same guard is run over the string literals of the files themselves.
    func testEveryStringLiteralInTheDietPlanSourcesPassesTheSameGuard() throws {
        var count = 0
        for source in try dietPlanSources() {
            let literals = try stringLiterals(in: source.code)
            count += literals.count
            XCTAssertEqual(violations(in: literals), [], source.name)
            XCTAssertFalse(source.text.contains("\u{2014}"), "em dash in \(source.name)")
            XCTAssertFalse(source.text.contains("\u{2013}"), "en dash in \(source.name)")
            XCTAssertFalse(source.text.lowercased().contains("unlock"), "banned word in \(source.name)")
            XCTAssertFalse(source.text.lowercased().contains("empower"), "banned word in \(source.name)")
        }
        XCTAssertGreaterThan(count, 150)
    }

    /// Every piece of prose written in the draft file reaches the registry, so no string can be
    /// added there and left unguarded. The recipe ids are the recipes' own names, not new copy.
    func testEveryStringInTheDraftFileReachesTheRegistry() throws {
        let draft = try XCTUnwrap(try dietPlanSources().first { $0.name == "DietPlanDraftContent.swift" })
        let recipeIDs = Set(RecipeContent.all.map(\.id))
        let surfaces = content.allSurfaces
        let literals = try stringLiterals(in: draft.code).filter { !recipeIDs.contains($0) }
        XCTAssertGreaterThan(literals.count, 120)
        for literal in literals {
            XCTAssertTrue(surfaces.contains { $0.contains(literal) }, "not in the registry: \(literal)")
        }
    }

    /// The guard has to be able to fail, or the tests above prove nothing.
    func testTheCopyGuardCatchesWhatItShould() {
        XCTAssertEqual(violations(in: ["Tick Vegetables on any day a meal included some.", "Wholemeal or white bread"]), [])
        for bad in ["Lentils support fertility", "Folate for egg quality", "This can boost your energy",
                    "A superfood breakfast", "A gentle detox", "A three-day cleanse", "Only 200 calories", "Count your macros",
                    "Watch your weight", "Check your BMI", "A slimming lunch", "Berries are a good food",
                    "Crisps are a bad food", "You should eat more greens", "You must eat protein", "A cure for tiredness",
                    "Treat yourself", "This can diagnose a problem", "We guarantee results", "A glass of alcohol",
                    "Good for ovulation", "Helps you conceive", "When you are pregnant", "Balances your hormones",
                    "An alkaline diet", "More likely a boy", "Unlock your plan", "An empowering read",
                    "Take a vitamin D supplement", "One portion of fruit", "A day \u{2014} and counting",
                    "A day \u{2013} and counting", "Plain yogurt", "Leafy greens", "You missed a day"] {
            XCTAssertFalse(violations(in: [bad]).isEmpty, "the guard let through: \(bad)")
        }
    }

    // ── The promise, in the product's own words ──

    func testThePromiseIsRepeatedFromTheTrackerAndNeverRewritten() throws {
        XCTAssertTrue(FoodLogCopy.footnote.hasPrefix("A record, not a target. Nothing here is scored"))
        // The line is read from `FoodLogCopy`; no Diet Plan file types it out a second time.
        for source in try dietPlanSources() {
            XCTAssertFalse(source.code.contains("A record, not a target"), source.name)
        }
        let plan = DietPlan.assemble(logsByDate: [:], state: .notStarted, today: CalendarDate(2026, 3, 30))
        XCTAssertEqual(plan.recordNote, FoodLogCopy.footnote)
    }

    /// No sentence tells her how many groups to reach or what she ought to eat.
    func testNoCopySetsANumberOfGroupsOrAnInstructionToEat() {
        let targets = ["all six", "six a day", "at least", "aim for", "aim to", "try to eat", "eat more", "eat less",
                       "every day", "each day you", "five a day", "5 a day", "avoid", "cut out", "cut down", "limit",
                       "too much", "too little", "not enough", "healthier", "need to eat", "have to eat", "ought"]
        for s in content.allSurfaces {
            for term in targets {
                XCTAssertFalse(s.lowercased().contains(term), "\"\(term)\" in: \(s)")
            }
        }
    }
}
