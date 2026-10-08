import XCTest
@testable import GenesyxCore

/// The shared Fertility Kit registry, the guard every kit registry is held to, and the dates the
/// kit prints.
final class FertilityKitCopyTests: XCTestCase {

    // MARK: - The registry

    func testTheSharedRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(FertilityKitCopy.allSurfaces.count, 60, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: FertilityKitCopy.allSurfaces), [])
    }

    func testEveryStringInTheSharedRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "FertilityKitCopy.swift", surfaces: FertilityKitCopy.allSurfaces), [])
    }

    func testTheBriefsExactStringsArePresent() {
        XCTAssertEqual(FertilityKitCopy.activate, "Activate My Kit")
        XCTAssertEqual(FertilityKitCopy.premium, "Premium")
        XCTAssertEqual(FertilityKitCopy.accessActive, "Premium access active")
        XCTAssertEqual(FertilityKitCopy.startProgramme, "Start My 90-Day Programme")
        XCTAssertEqual(FertilityKitCopy.continueProgramme, "Continue Programme")
        XCTAssertEqual(FertilityKitCopy.programmeCompleted, "90-Day Programme Completed")
        XCTAssertEqual(FertilityKitCopy.viewNinetyDayReview, "View My 90-Day Review")
        XCTAssertEqual(FertilityKitCopy.continueWithGenesyx, "Continue with Genesyx")
        XCTAssertEqual(FertilityKitCopy.includedItems(scanAvailable: true),
                       ["90-Day Fertility Programme", "Your Diet Plan", "Programme Reviews", "Fertility Kit Guidance",
                        "Testing Integration"])
        XCTAssertEqual(FertilityKitCopy.includedItems(scanAvailable: false),
                       ["90-Day Fertility Programme", "Your Diet Plan", "Programme Reviews", "Fertility Kit Guidance"],
                       "testing is listed only where the scan screens exist")
        XCTAssertEqual(FertilityKitCopy.productName, "Genesyx Fertility Kit")
        XCTAssertEqual(FertilityKitCopy.weekOfProgramme(4), "Week 4 of 13")
        XCTAssertEqual(FertilityKitCopy.minutesToRead(3), "3 min read")
        XCTAssertEqual(FertilityKitCopy.foodGroupsRecorded(4, of: 6), "Food groups recorded: 4 of 6")
    }

    // MARK: - The guard can fail

    func testTheGuardCatchesEveryTermItBans() {
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: ["Your latest reading", "Start later", "Testing Integration",
                                                             "50% of 4 activities", "100%", "A block of text"]), [])
        let samples = [
            "This screen is locked", "Lock your plan", "Welcome back", "Continue with today", "Pick up your routine",
            "Enter GX90", "editorial_reviewed", "clinical_reviewed", "Approved by the team", "0% this week",
            "Your score this week", "A grade for the week", "Your rating", "Catch up on your week", "A poor week",
            "A bad day", "A regular cycle", "An irregular cycle", "A normal reading", "Your period is late",
            "A check-in is overdue", "You should log today", "You must log today",
        ]
        for bad in samples {
            XCTAssertFalse(FertilityKitCopyGuard.violations(in: [bad]).isEmpty, "the guard let through: \(bad)")
        }
        XCTAssertEqual(samples.count, FertilityKitCopyGuard.newCopy.all.count, "one sample for each banned term")
        // The older guard still applies underneath.
        XCTAssertFalse(FertilityKitCopyGuard.violations(in: ["Unlock your plan"]).isEmpty)
        XCTAssertFalse(FertilityKitCopyGuard.violations(in: ["A day \u{2014} and counting"]).isEmpty)
    }

    func testTheNutritionPromiseIsTheOnlySentenceThatMaySayScored() {
        XCTAssertTrue(FoodLogCopy.footnote.contains(FertilityKitCopyGuard.allowedSentence))
        XCTAssertEqual(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.newCopy, in: FoodLogCopy.footnote), [])
        XCTAssertEqual(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.newCopy, in: "Nothing here is scored."), ["score"])
    }

    func testTheTwoMatchingRules() {
        let nought = FertilityKitCopyGuard.Terms(noughtPerCent: true)
        XCTAssertEqual(FertilityKitCopyGuard.hits(nought, in: "0%"), ["0%"])
        XCTAssertEqual(FertilityKitCopyGuard.hits(nought, in: "Week 3: 0% of activities"), ["0%"])
        for fine in ["50%", "100%", "10% of 20", "No figure"] {
            XCTAssertEqual(FertilityKitCopyGuard.hits(nought, in: fine), [], fine)
        }
        let words = FertilityKitCopyGuard.Terms(wholeWords: ["late", "lock"])
        XCTAssertEqual(FertilityKitCopyGuard.hits(words, in: "Too Late to lock"), ["late", "lock"])
        for fine in ["Your latest result", "Start later", "A block of text", "Three o'clock"] {
            XCTAssertEqual(FertilityKitCopyGuard.hits(words, in: fine), [], fine)
        }
    }

    func testTheOnScreenListsCatchWhatTheyShould() {
        for bad in ["Unlock this", "It is locked", "Lock it", "Coming soon", "Lesson to follow", "A day \u{2014} more",
                    "0% done", "GX90", "editorial_reviewed", "clinical_reviewed", "draft", "Approved", "Reviewed",
                    "A 3 day streak", "You missed a day", "You failed", "You are behind", "We guarantee it",
                    "This can diagnose", "Boost your energy"] {
            XCTAssertFalse(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.onScreenFailing, in: bad).isEmpty, bad)
        }
        for bad in ["Welcome back", "Continue with today", "Pick up your routine", "Your score", "A grade", "A rating",
                    "Catch up", "You should rest", "You must rest", "Poor", "Bad", "Regular", "Irregular", "Normal",
                    "Late", "Overdue", "Days 1 \u{2013} 30"] {
            XCTAssertFalse(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.onScreenReported, in: bad).isEmpty, bad)
        }
        XCTAssertEqual(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.onScreenFailing,
                                                  in: "Day 23 of 90. 50% of 4 activities. Your latest review is ready."), [])
    }

    func testTheLiteralCheckCanFailAndReadsInterpolations() {
        let surfaces = ["Week 4 of 13", "Two words"]
        let source = """
            static let a = "Two words"   // "in a comment"
            static func b(_ n: Int) -> String { "Week \\(n) of \\(total(of: "x y"))" }
            static let c = "one-word"
            static let d = "Not registered"
            static func e(_ n: Int) -> String { "Day \\(n) of the week" }
            """
        XCTAssertEqual(FertilityKitCopyGuard.unregisteredLiterals(inSource: source, surfaces: surfaces),
                       ["Not registered", "Day \\(…) of the week"])
    }

    // MARK: - A figure in words

    func testAFigureWithNoCreditHasNoLineAndNeverANoughtPerCent() {
        let noCredit = ProgrammeConsistencyFigure(counted: 12, credit: 0, completed: 0, partlyCompleted: 0,
                                                  percentage: 0, withheld: nil)
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: noCredit), [])
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: noCredit, nothingTracked: true), [ProgrammeReviewCopy.nothingRecorded])
        let nothingCounted = ProgrammeConsistencyFigure(counted: 0, credit: 0, completed: 0, partlyCompleted: 0,
                                                        percentage: nil, withheld: nil)
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: nothingCounted, nothingTracked: true), [])
        // A little credit over many activities rounds to nought: the counts are stated, the figure is not.
        let roundsToNought = ProgrammeConsistencyFigure(counted: 300, credit: 0.5, completed: 0, partlyCompleted: 1,
                                                        percentage: 0, withheld: nil)
        let lines = ProgrammeReviewLogic.lines(for: roundsToNought)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(FertilityKitCopyGuard.hits(FertilityKitCopyGuard.Terms(noughtPerCent: true), in: lines.joined(separator: " ")), [])
        let ordinary = ProgrammeConsistencyFigure(counted: 5, credit: 4.5, completed: 4, partlyCompleted: 1,
                                                  percentage: 90, withheld: nil)
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: ordinary).first, ProgrammeReviewCopy.percentage(90))
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: ordinary).count, 2)
    }

    // MARK: - Today

    func testTodayIsCountsOnly() {
        XCTAssertEqual(FertilityKitCopy.todayProgressLines(ProgrammeTodayProgress(completed: 0, partlyCompleted: 0, total: 0)),
                       ["Nothing is counted today."])
        XCTAssertEqual(FertilityKitCopy.todayProgressLines(ProgrammeTodayProgress(completed: 2, partlyCompleted: 0, total: 5)),
                       [FertilityPictureCopy.activitiesCompletedToday(2, of: 5)])
        XCTAssertEqual(FertilityKitCopy.todayProgressLines(ProgrammeTodayProgress(completed: 2, partlyCompleted: 1, total: 5)),
                       [FertilityPictureCopy.activitiesCompletedToday(2, of: 5), "1 activity partly completed"])
        XCTAssertEqual(FertilityKitCopy.partlyCompletedToday(2), "2 activities partly completed")
        for total in 0...5 {
            let lines = FertilityKitCopy.todayProgressLines(ProgrammeTodayProgress(completed: 0, partlyCompleted: 0, total: total))
            XCTAssertFalse(lines.joined().contains("%"), "today never gets a percentage")
        }
    }

    // MARK: - Labels

    func testLabels() {
        XCTAssertEqual(FertilityKitCopy.rowLabel("Mood check-in", status: FertilityKitCopy.statusDone), "Mood check-in, done.")
        XCTAssertEqual(
            FertilityKitCopy.rowLabel("Nutrition check-in", status: FertilityKitCopy.statusDone,
                                      details: [FertilityKitCopy.nutritionCheckInCompleted,
                                                FertilityKitCopy.foodGroupsRecorded(4, of: 6)]),
            "Nutrition check-in, done. Nutrition check-in: completed. Food groups recorded: 4 of 6")
        XCTAssertEqual(FertilityKitCopy.titleAndDetail("Programme Guide", "Thirty short sections"),
                       "Programme Guide. Thirty short sections")
        XCTAssertEqual(FertilityKitCopy.titleAndDetail("Programme Guide", nil), "Programme Guide")
        XCTAssertEqual(FertilityKitCopy.sentences(["95%", "4 of 5 activities completed, 1 partly completed"]),
                       "95%. 4 of 5 activities completed, 1 partly completed")
        XCTAssertEqual(FertilityKitCopy.sentences(["One.", "Two"]), "One. Two", "a full stop is not doubled")
        XCTAssertEqual(FertilityKitCopy.sentences([]), "")
        XCTAssertEqual(FertilityKitCopy.dotJoined(["Day 23 of 90", "Week 4 of 13", "3 min read"]),
                       "Day 23 of 90 · Week 4 of 13 · 3 min read")
    }

    // MARK: - Dates

    func testDatesAreDayThenMonth() {
        func dayMonth(_ date: CalendarDate) -> String { FertilityKitCopy.dayMonth(day: date.day, month: date.month) }
        XCTAssertEqual(dayMonth(CalendarDate(2026, 10, 6)), "6 October")
        XCTAssertEqual(dayMonth(CalendarDate(2026, 10, 25)), "25 October")
        XCTAssertEqual(dayMonth(CalendarDate(2028, 2, 29)), "29 February")
        XCTAssertEqual(FertilityKitCopy.dateRange(dayMonth(CalendarDate(2026, 12, 31)), dayMonth(CalendarDate(2027, 1, 1))),
                       "31 December to 1 January")
        XCTAssertEqual(FertilityKitCopy.dayMonthYear(day: 6, month: 10, year: 2026), "6 October 2026")
        XCTAssertEqual(Set((1...12).map(FertilityKitCopy.monthName)).count, 12, "twelve distinct month names")
        XCTAssertEqual(FertilityKitCopy.monthName(1), "January")
        XCTAssertEqual(FertilityKitCopy.monthName(12), "December")
    }

    // MARK: - The journeys' lists

    /// The UI journeys hold the two on-screen lists as literals, because a UI test cannot import
    /// this guard. Every term must be there, or the journeys check less than the guard does.
    func testTheJourneyListsMatchTheGuard() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let mirror = try String(contentsOf: root.appendingPathComponent("App/GenesyxUITests/FertilityKitBannedText.swift"),
                                encoding: .utf8)
        func block(_ name: String) throws -> String {
            let start = try XCTUnwrap(mirror.range(of: "static let \(name) = Terms("), "no `\(name)` list in the mirror")
            let rest = mirror[start.upperBound...]
            return String(rest[..<(try XCTUnwrap(rest.range(of: "noughtPerCent:"))).upperBound]) + String(rest[(try XCTUnwrap(rest.range(of: "noughtPerCent:"))).upperBound...].prefix(8))
        }
        /// A term as it is typed in a Swift literal: a dash is written as its escape.
        func literal(_ term: String) -> String {
            "\"" + term.unicodeScalars.map { $0.isASCII ? String($0) : "\\u{" + String($0.value, radix: 16).uppercased() + "}" }.joined() + "\""
        }
        for (name, terms) in [("failing", FertilityKitCopyGuard.onScreenFailing), ("reported", FertilityKitCopyGuard.onScreenReported)] {
            let text = try block(name)
            for term in terms.anywhere + terms.wholeWords {
                XCTAssertTrue(text.contains(literal(term)), "the journeys' `\(name)` list is missing \(literal(term))")
            }
            XCTAssertTrue(text.contains("noughtPerCent: \(terms.noughtPerCent)"), "`\(name)` disagrees about a nought per cent")
            // And nothing extra: the same number of literals.
            XCTAssertEqual(FertilityKitCopyGuard.literals(in: text).count, terms.anywhere.count + terms.wholeWords.count,
                           "the journeys' `\(name)` list holds a term the guard does not")
        }
        XCTAssertTrue(mirror.contains("static let allowedSentence = \"\(FertilityKitCopyGuard.allowedSentence)\""))
        XCTAssertTrue(mirror.contains("(?<![0-9])0%"), "the journeys match a nought per cent as the guard does")
    }
}
