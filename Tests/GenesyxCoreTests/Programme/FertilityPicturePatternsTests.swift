import XCTest
@testable import GenesyxCore

/// The one producer of pattern statements: each speaks only from its own minimum of recorded
/// data, in order of evidence, and says a count or a length and nothing else.
final class FertilityPicturePatternsTests: XCTestCase {

    private typealias F = FertilityPictureFixtures
    private let today = F.today

    private func input(_ change: (inout FertilityPictureInput) -> Void = { _ in }) -> FertilityPictureInput {
        var input = F.input()
        change(&input)
        return input
    }

    private func statements(_ input: FertilityPictureInput) -> [ProgrammeEvidenceStatement] {
        FertilityPicturePatterns.statements(input)
    }

    private func texts(_ input: FertilityPictureInput, at level: ProgrammeEvidenceLevel) -> [String] {
        statements(input).filter { $0.level == level }.map(\.text)
    }

    /// A cycle she recorded the start of, 17 days ago, so today is its day 18.
    private var recordedCycle: [DerivedCycle] { F.cycles(latestStart: today.minusDays(17)) }

    func testTheMinimumsArePinned() {
        XCTAssertEqual(FertilityPicturePatterns.minimumRecordedDaysInWeek, 3)
        XCTAssertEqual(FertilityPicturePatterns.minimumRecordedDaysInCycle, 10)
        XCTAssertEqual(FertilityPicturePatterns.minimumLhResultsInCycle, 2)
        XCTAssertEqual(FertilityPicturePatterns.minimumPhReadingsInCycle, 4)
        XCTAssertEqual(CycleHistory.minimumCyclesForCrossCycleStatement, 3)
    }

    func testNothingRecordedSaysNothing() {
        XCTAssertEqual(statements(F.input()), [])
        XCTAssertTrue(FertilityPicturePatterns.isStillLearning(F.input()))
    }

    // ── Level 1: the last recorded cycle ──

    func testTheLastRecordedCycleLengthIsStatedOnceACycleHasClosed() {
        let closed = input { $0.cycles = F.cycles(lengths: [29], latestStart: self.today.minusDays(11)) }
        XCTAssertEqual(statements(closed), [
            ProgrammeEvidenceStatement(level: .observation, text: "Your last recorded cycle was 29 days long."),
        ])
        // One below: a single start is an open cycle, with no length to state.
        XCTAssertEqual(texts(input { $0.cycles = F.cycles(latestStart: self.today.minusDays(11)) }, at: .observation), [])

        // The latest closed cycle, not the first.
        let several = input { $0.cycles = F.cycles(lengths: [27, 30], latestStart: self.today.minusDays(11)) }
        XCTAssertEqual(texts(several, at: .observation), ["Your last recorded cycle was 30 days long."])

        // Any length is stated, without comment.
        let long = input { $0.cycles = F.cycles(lengths: [60], latestStart: self.today.minusDays(11)) }
        XCTAssertEqual(texts(long, at: .observation), ["Your last recorded cycle was 60 days long."])

        // A start dated after today (a clock put back) closes the cycle she is still in. That
        // cycle is not her last one: the one before it is, and a start today does close a cycle.
        let ahead = input { $0.cycles = F.cycles(lengths: [29, 20], latestStart: self.today.plusDays(5)) }
        XCTAssertEqual(CycleHistory.cycleDay(on: today, in: ahead.cycles), 16)
        XCTAssertEqual(texts(ahead, at: .observation), ["Your last recorded cycle was 29 days long."])
        XCTAssertEqual(texts(input { $0.cycles = F.cycles(lengths: [20], latestStart: self.today.plusDays(5)) }, at: .observation), [])
        XCTAssertEqual(texts(input { $0.cycles = F.cycles(lengths: [29], latestStart: self.today) }, at: .observation),
                       ["Your last recorded cycle was 29 days long."])
        // A start dated tomorrow: the cycle it closes ends today, and she is still in it.
        XCTAssertEqual(texts(input { $0.cycles = F.cycles(lengths: [29, 20], latestStart: self.today.plusDays(1)) }, at: .observation),
                       ["Your last recorded cycle was 29 days long."])
    }

    func testACycleThatRestsOnTheSeededRecordIsNotALengthSheRecorded() {
        let seededStart = input { $0.cycles = F.cycles(lengths: [29], latestStart: self.today.minusDays(11), seedingFirst: true) }
        XCTAssertEqual(statements(seededStart), [])

        let start = today.minusDays(40)
        let seededClose = input {
            $0.cycles = [DerivedCycle(start: start, end: start.plusDays(28), length: 29, periodDays: nil,
                                      source: .recorded, closingSource: .seeded)]
        }
        XCTAssertEqual(texts(seededClose, at: .observation), [])

        // Her last closed cycle rests on the seeded record, so nothing is said. The cycle before
        // it, which she recorded at both ends, is not her last one.
        let before = DerivedCycle(start: start.minusDays(27), end: start.minusDays(1), length: 27, periodDays: nil,
                                  source: .recorded, closingSource: .recorded)
        XCTAssertTrue(before.isRecorded)
        XCTAssertEqual(texts(input { $0.cycles = [before] + seededClose.cycles }, at: .observation), [])
    }

    // ── Level 2: the last seven days ──

    func testRecordedDaysInTheLastSevenDaysFromThreeDays() {
        let three = input { $0.logsByDate = F.logs(daysAgo: [0, 3, 6]) }
        XCTAssertEqual(statements(three), [
            ProgrammeEvidenceStatement(level: .withinWeekTrend, text: "In the last 7 days you recorded something on 3 days."),
        ])
        XCTAssertEqual(statements(input { $0.logsByDate = F.logs(daysAgo: [0, 3]) }), [])
        // Seven days ago is the eighth day back, and tomorrow has not happened.
        XCTAssertEqual(statements(input { $0.logsByDate = F.logs(daysAgo: [0, 3, 7, -1]) }), [])
        XCTAssertEqual(texts(input { $0.logsByDate = F.logs(daysAgo: Array(0..<12)) }, at: .withinWeekTrend),
                       ["In the last 7 days you recorded something on 7 days."])
    }

    func testARecordedDayIsTheAppsExistingRule() {
        // A day with only a pH reading counts, as it does everywhere else in the app.
        let withReading = input {
            $0.logsByDate = F.logs(daysAgo: [0, 3])
            $0.phReadings = [F.ph(4.4, daysAgo: 5)]
        }
        XCTAssertEqual(texts(withReading, at: .withinWeekTrend), ["In the last 7 days you recorded something on 3 days."])

        // A legacy urine reading does not, and neither does a log with nothing in it.
        let withUrine = input {
            $0.logsByDate = F.logs(daysAgo: [0, 3])
            $0.logsByDate[self.today.minusDays(4)] = DailyLog()
            $0.phReadings = [F.ph(6.0, daysAgo: 5, type: .urine)]
        }
        XCTAssertEqual(statements(withUrine), [])

        // Two readings on one day are one day.
        let sameDay = input {
            $0.logsByDate = F.logs(daysAgo: [0])
            $0.phReadings = [F.ph(4.4, daysAgo: 5), PhReading(phValue: 4.5, recordedAt: F.instant(self.today.minusDays(5), hour: 20))]
        }
        XCTAssertEqual(statements(sameDay), [])
    }

    func testTheIntimacyFieldIsNotARecordedDay() {
        let only = input {
            $0.logsByDate = Dictionary(uniqueKeysWithValues: (0..<7).map { (self.today.minusDays($0), DailyLog(sexualActivity: true)) })
            $0.cycles = self.recordedCycle
        }
        XCTAssertEqual(statements(only), [])

        var with = F.rich
        with.logsByDate = with.logsByDate.mapValues { log in
            var log = log
            log.sexualActivity = true
            return log
        }
        XCTAssertEqual(statements(with), statements(F.rich))
    }

    // ── Level 3: inside the current recorded cycle ──

    func testRecordedDaysInTheCycleFromTenDays() {
        let ten = input { $0.cycles = self.recordedCycle; $0.logsByDate = F.logs(daysAgo: Array(0..<10)) }
        XCTAssertEqual(texts(ten, at: .withinCyclePattern),
                       ["In your current recorded cycle you have recorded something on 10 of 18 days."])

        let nine = input { $0.cycles = self.recordedCycle; $0.logsByDate = F.logs(daysAgo: Array(0..<9)) }
        XCTAssertEqual(texts(nine, at: .withinCyclePattern), [])

        // Days before the start are not in the cycle, and nor is a day after today. The start is.
        let outside = input {
            $0.cycles = self.recordedCycle
            $0.logsByDate = F.logs(daysAgo: Array(9...16) + [17] + Array(18...30) + [-1, -2])
        }
        XCTAssertEqual(texts(outside, at: .withinCyclePattern), [])
        let withStart = input { $0.cycles = self.recordedCycle; $0.logsByDate = F.logs(daysAgo: Array(8...17)) }
        XCTAssertEqual(texts(withStart, at: .withinCyclePattern),
                       ["In your current recorded cycle you have recorded something on 10 of 18 days."])
    }

    func testOvulationTestResultsInTheCycleFromTwoAndOnlyWithTheScanFeatures() {
        func lh(_ results: [LhResult], scanFeatures: Bool = true) -> [String] {
            texts(input {
                $0.cycles = self.recordedCycle
                $0.scanFeaturesAvailable = scanFeatures
                $0.lhResults = results
            }, at: .withinCyclePattern)
        }
        let two = [F.lh(.low, daysAgo: 4), F.lh(.positive, daysAgo: 2)]
        XCTAssertEqual(lh(two), ["In your current recorded cycle you have recorded 2 ovulation test results."])
        XCTAssertEqual(lh(two + [F.lh(.invalid, daysAgo: 1)]),
                       ["In your current recorded cycle you have recorded 3 ovulation test results."])
        XCTAssertEqual(lh([F.lh(.low, daysAgo: 4)]), [])
        XCTAssertEqual(lh(two, scanFeatures: false), [])
        // One of the two was before the cycle started; an unreadable test is not a result.
        XCTAssertEqual(lh([F.lh(.low, daysAgo: 18), F.lh(.positive, daysAgo: 2)]), [])
        XCTAssertEqual(lh([F.lh(.low, daysAgo: 4), F.lh(.unreadable, daysAgo: 2)]), [])
        // Two on the cycle's first day count.
        XCTAssertEqual(lh([F.lh(.low, daysAgo: 17, hour: 8), F.lh(.low, daysAgo: 17, hour: 20)]).count, 1)
    }

    func testPhReadingsInTheCycleFromFour() {
        func ph(_ readings: [PhReading], logging: Bool = true) -> [String] {
            texts(input {
                $0.cycles = self.recordedCycle
                $0.phLoggingAvailable = logging
                $0.phReadings = readings
            }, at: .withinCyclePattern)
        }
        let four = [F.ph(4.2, daysAgo: 16), F.ph(4.4, daysAgo: 12), F.ph(4.7, daysAgo: 9), F.ph(5.1, daysAgo: 8)]
        XCTAssertEqual(ph(four), ["In your current recorded cycle you have recorded 4 pH readings."])
        XCTAssertEqual(ph(Array(four.dropLast())), [])
        XCTAssertEqual(ph(Array(four.dropLast()) + [F.ph(6.0, daysAgo: 2, type: .urine)]), [])
        XCTAssertEqual(ph(Array(four.dropLast()) + [F.ph(4.4, daysAgo: 18)]), [])
        XCTAssertEqual(ph(four, logging: false), [])
    }

    func testWithinCycleStatementsNeedACycleSheRecorded() {
        func withinCycle(_ cycles: [DerivedCycle]) -> [String] {
            texts(input {
                $0.cycles = cycles
                $0.scanFeaturesAvailable = true
                $0.logsByDate = F.logs(daysAgo: Array(0..<12))
                $0.lhResults = [F.lh(.low, daysAgo: 4), F.lh(.positive, daysAgo: 2)]
                $0.phReadings = [F.ph(4.2, daysAgo: 10), F.ph(4.4, daysAgo: 7), F.ph(4.7, daysAgo: 5), F.ph(5.1, daysAgo: 1)]
            }, at: .withinCyclePattern)
        }
        XCTAssertEqual(withinCycle(recordedCycle), [
            "In your current recorded cycle you have recorded something on 12 of 18 days.",
            "In your current recorded cycle you have recorded 2 ovulation test results.",
            "In your current recorded cycle you have recorded 4 pH readings.",
        ])
        // The current cycle was opened by the seeded record.
        XCTAssertEqual(withinCycle(F.cycles(latestStart: today.minusDays(17), seedingFirst: true)), [])
        // Today is before her first recorded start, or there is no history at all.
        XCTAssertEqual(withinCycle(F.cycles(latestStart: today.plusDays(2))), [])
        XCTAssertEqual(withinCycle([]), [])
        // A recorded start after a seeded one is a cycle she recorded.
        XCTAssertEqual(withinCycle(F.cycles(lengths: [29], latestStart: today.minusDays(17), seedingFirst: true)).count, 3)
    }

    // ── Level 4: across cycles ──

    func testAcrossCyclesNeedsThreeCountableCycles() {
        func across(_ cycles: [DerivedCycle]) -> [String] {
            texts(input { $0.cycles = cycles }, at: .crossCyclePattern)
        }
        let latest = today.minusDays(11)
        XCTAssertEqual(across(F.cycles(lengths: [27, 30, 28], latestStart: latest)),
                       ["Across your 3 recorded cycles, cycle length ranged from 27 to 30 days."])
        XCTAssertEqual(across(F.cycles(lengths: [28, 28, 28], latestStart: latest)),
                       ["Your 3 recorded cycles were each 28 days long."])
        XCTAssertEqual(across(F.cycles(lengths: [30, 21, 35, 28], latestStart: latest)),
                       ["Across your 4 recorded cycles, cycle length ranged from 21 to 35 days."])

        // Two is not enough.
        XCTAssertEqual(across(F.cycles(lengths: [27, 30], latestStart: latest)), [])
        // A third that is outside the range the app accepts is not counted.
        XCTAssertEqual(across(F.cycles(lengths: [27, 30, 40], latestStart: latest)), [])
        XCTAssertEqual(across(F.cycles(lengths: [20, 27, 30], latestStart: latest)), [])
        // A third that rests on the seeded record is not counted.
        XCTAssertEqual(across(F.cycles(lengths: [27, 30, 28], latestStart: latest, seedingFirst: true)), [])
    }

    /// A recorded cycle outside 21 to 35 days is left out of the count and the range. The sentence
    /// then says which cycles it is about: it may not speak for all of her recorded cycles.
    func testAcrossCyclesNamesTheCyclesItCountedWhenARecordedCycleIsLeftOut() {
        XCTAssertEqual(CycleEngine.cycleLengthRange, 21...35)
        let latest = today.minusDays(11)
        func history(_ lengths: [Int], seedingFirst: Bool = false) -> FertilityPictureInput {
            input { $0.cycles = F.cycles(lengths: lengths, latestStart: latest, seedingFirst: seedingFirst) }
        }

        XCTAssertEqual(texts(history([27, 40, 30, 28]), at: .crossCyclePattern),
                       ["Across your 3 recorded cycles of 21 to 35 days, cycle length ranged from 27 to 30 days."])
        // One missed period log makes one long cycle among four.
        XCTAssertEqual(texts(history([28, 56, 29, 28]), at: .crossCyclePattern),
                       ["Across your 3 recorded cycles of 21 to 35 days, cycle length ranged from 28 to 29 days."])
        XCTAssertEqual(texts(history([20, 28, 28, 28]), at: .crossCyclePattern),
                       ["Your 3 recorded cycles of 21 to 35 days were each 28 days long."])

        // The last cycle was 45 days and is stated as that. Nothing beside it may say her
        // recorded cycles were each 28 days long.
        let longLast = statements(history([28, 28, 28, 45]))
        XCTAssertEqual(longLast.map(\.text), [
            "Your last recorded cycle was 45 days long.",
            "Your 3 recorded cycles of 21 to 35 days were each 28 days long.",
        ])
        XCTAssertFalse(longLast.contains { $0.text.contains("Your 3 recorded cycles were each") })
        XCTAssertFalse(statements(history([28, 56, 29, 28])).contains { $0.text.contains("Across your 3 recorded cycles,") })

        // A cycle that rests on the seeded record is not one she recorded, so leaving it out
        // leaves nothing to name. The same holds when every recorded cycle is counted.
        XCTAssertEqual(texts(history([40, 27, 30, 28], seedingFirst: true), at: .crossCyclePattern),
                       ["Across your 3 recorded cycles, cycle length ranged from 27 to 30 days."])
        XCTAssertEqual(texts(history([28, 28, 28]), at: .crossCyclePattern), ["Your 3 recorded cycles were each 28 days long."])
    }

    func testStillLearningMirrorsTheCrossCycleGate() {
        let latest = today.minusDays(11)
        let histories: [(cycles: [DerivedCycle], stillLearning: Bool)] = [
            ([], true),
            (F.cycles(latestStart: latest), true),
            (F.cycles(lengths: [27, 30], latestStart: latest), true),
            (F.cycles(lengths: [27, 30, 40], latestStart: latest), true),
            (F.cycles(lengths: [27, 30, 28], latestStart: latest, seedingFirst: true), true),
            (F.cycles(lengths: [27, 30, 28], latestStart: latest), false),
            (F.cycles(lengths: [28, 28, 28, 28], latestStart: latest), false),
        ]
        for history in histories {
            let input = input { $0.cycles = history.cycles }
            XCTAssertEqual(FertilityPicturePatterns.isStillLearning(input), history.stillLearning)
            XCTAssertEqual(FertilityPicturePatterns.isStillLearning(input), !CycleHistory.canMakeCrossCycleStatement(history.cycles))
            XCTAssertEqual(statements(input).contains { $0.level == .crossCyclePattern }, !history.stillLearning)
        }
    }

    // ── All together ──

    func testStatementsComeLowestLevelFirst() {
        let statements = statements(F.rich)
        XCTAssertEqual(statements.map(\.text), [
            "Your last recorded cycle was 28 days long.",
            "In the last 7 days you recorded something on 7 days.",
            "In your current recorded cycle you have recorded something on 12 of 18 days.",
            "In your current recorded cycle you have recorded 3 ovulation test results.",
            "In your current recorded cycle you have recorded 4 pH readings.",
            "Across your 3 recorded cycles, cycle length ranged from 27 to 30 days.",
        ])
        XCTAssertEqual(statements.map(\.level),
                       [.observation, .withinWeekTrend, .withinCyclePattern, .withinCyclePattern, .withinCyclePattern, .crossCyclePattern])
        XCTAssertEqual(statements.map(\.level), statements.map(\.level).sorted())
        XCTAssertEqual(Set(statements.map(\.level)), Set(ProgrammeEvidenceLevel.allCases))
    }

    func testWithoutConsentNothingIsSaid() {
        var input = F.rich
        input.consentActive = false
        XCTAssertEqual(statements(input), [])
    }

    func testNoStatementCarriesAValueAClassificationOrAVerdict() {
        var input = F.rich
        input.logsByDate[today] = DailyLog(mood: .low, energy: .low, symptoms: ["cramps"], sleepMinutes: 181, waterMl: 1234)
        // And with a long cycle among them, where the cross-cycle sentence names what it counted.
        var longCycle = input
        longCycle.cycles = F.cycles(lengths: [27, 45, 30, 28], latestStart: today.minusDays(17))
        let text = (statements(input) + statements(longCycle)).map(\.text).joined(separator: " ")
        XCTAssertTrue(text.contains("recorded cycles of 21 to 35 days"))

        for value in ["4.7", "4.2", "4.4", "5.3", "6.1", "181", "1234", "3h", "cramps"] {
            XCTAssertFalse(text.contains(value), value)
        }
        let titles = LhClassification.allCases.map(LhScanCopy.title(for:)) + PhStatus.allCases.map(\.label)
            + Phase.allCases.compactMap { CycleContent.phaseLabel[$0] } + [LhScanCopy.manualPositive, LhScanCopy.manualLow]
        for title in titles {
            XCTAssertFalse(text.localizedCaseInsensitiveContains(title), title)
        }
        for word in ["regular", "irregular", "normal", "typical", "average", "usual", "should", "window", "fertile", "ovulated", "surge"] {
            XCTAssertFalse(text.localizedCaseInsensitiveContains(word), word)
        }
    }

    // ── As the picture shows them ──

    func testThePictureShowsEachStatementUnderItsLevel() {
        let rows = FertilityPictureLogic.picture(F.rich).sections.first { $0.kind == .patterns }?.rows ?? []
        let statements = statements(F.rich)
        XCTAssertEqual(rows.map(\.kind), Array(repeating: .pattern, count: 6))
        XCTAssertEqual(rows.map(\.id), ["pattern-0", "pattern-1", "pattern-2", "pattern-3", "pattern-4", "pattern-5"])
        XCTAssertEqual(rows.compactMap(\.value), statements.map(\.text))
        XCTAssertEqual(rows.compactMap(\.evidenceLevel), statements.map(\.level))
        XCTAssertEqual(rows.map(\.label), ["Observation", "Within-week trend", "Within-cycle pattern", "Within-cycle pattern",
                                           "Within-cycle pattern", "Cross-cycle pattern"])
        XCTAssertTrue(rows.allSatisfy { $0.destination == .programme(.insights) })
    }

    func testTheOwnersSentenceIsShownOnceBesideLowerLevelsUntilCyclesCanBeCompared() {
        var input = F.rich
        input.cycles = F.cycles(lengths: [30, 28], latestStart: today.minusDays(17))
        let rows = FertilityPictureLogic.picture(input).sections.first { $0.kind == .patterns }?.rows ?? []

        XCTAssertEqual(rows.map(\.kind), [.pattern, .pattern, .pattern, .pattern, .pattern, .stillLearning])
        XCTAssertFalse(rows.contains { $0.evidenceLevel == .crossCyclePattern })
        XCTAssertEqual(rows.last?.value, "We're still learning your pattern. Continue tracking to build a clearer picture over time.")
        XCTAssertEqual(rows.filter { $0.value == ProgrammeEvidenceCopy.stillLearning }.count, 1)
        XCTAssertFalse((FertilityPictureLogic.picture(F.rich).surfaces).contains(ProgrammeEvidenceCopy.stillLearning))
    }
}
