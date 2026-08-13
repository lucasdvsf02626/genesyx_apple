import XCTest
@testable import GenesyxCore

/// The personalisation layer is dormant behind `FeatureFlags.personalisedSupplementTiming`, so
/// these tests are the only thing standing between it and the day someone flips the flag without
/// re-reading the design. Two properties matter more than the rest: it can never change WHICH
/// supplements she is reminded about, and with the flag off she gets byte-for-byte what she gets
/// today.
final class SupplementPersonalisationTests: XCTestCase {

    /// Fixed zone: `typicalHour` reads a clock, and a test that passes in London and fails in
    /// Sydney is worse than no test.
    private let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private func at(hour: Int, day: Int = 1) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    private func signals(days: Int = 0,
                         typical: Int? = nil,
                         quiz: [String: String] = [:],
                         phase: Phase? = nil) -> SupplementSignals {
        SupplementSignals(daysLoggingSupplementsLastWeek: days,
                          typicalLogHour: typical,
                          quizAnswers: quiz,
                          phase: phase)
    }

    private let magnesium = SupplementReminder(id: "mag", name: "Magnesium", dose: "200 mg", hour: 8)

    // MARK: - The boundary: timing and wording, never which supplement

    /// Recommending a supplement to a named individual is personalised health advice and needs
    /// medical-review sign-off. This type must be incapable of it — not merely careful about it.
    func testItCannotAddRemoveOrRenameASupplement() {
        let reminders = [magnesium,
                         SupplementReminder(id: "essential.F", name: "Folate", dose: "", hour: 9)]

        let out = SupplementPersonalisation.apply(to: reminders, signals: signals(days: 7, typical: 20))

        XCTAssertEqual(out.map(\.id), reminders.map(\.id))
        XCTAssertEqual(out.map(\.name), reminders.map(\.name))
        XCTAssertEqual(out.map(\.dose), reminders.map(\.dose))
    }

    /// `id` is the notification request identifier. Changing it would leave the old pending request
    /// in place and add a second one beside it, so she'd be reminded twice.
    func testTheRequestIdentifierSurvivesEverySignalCombination() {
        for days in 0...7 {
            for typical in [nil, 0, 12, 23] as [Int?] {
                let out = SupplementPersonalisation.apply(
                    to: [magnesium], signals: signals(days: days, typical: typical))
                XCTAssertEqual(out.first?.id, "mag")
            }
        }
    }

    /// With the flag off nothing calls `apply`, so the manual path has to produce exactly the body
    /// it produced before this file existed. A regression here ships a changed notification to
    /// everyone the day the code lands, flag or no flag.
    func testTheUnpersonalisedPathIsUnchanged() {
        let custom = CustomSupplement(id: "mag", name: "Magnesium", dose: "200 mg", time: "Evening")
        let reminders = SupplementReminder.all(customs: [custom], hours: ["mag": 8])

        XCTAssertEqual(reminders.map(\.context), [nil])
        XCTAssertEqual(reminders[0].body, "200 mg. From your supplement plan.")
        XCTAssertEqual(reminders[0].title, "Time for Magnesium")
    }

    // MARK: - When it fires

    /// She set 8am and it isn't working; she is demonstrably around at 10.
    func testAnAlarmSheIsIgnoringMovesTowardWhenSheIsActuallyAwake() {
        let out = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 1, typical: 10))

        XCTAssertEqual(out[0].hour, 10)
    }

    /// She picked that hour for reasons the app cannot see — with food, spaced from a medication.
    /// A nudge is defensible; relocating her morning supplement to the evening is not.
    func testTheMoveIsCappedSoItNudgesRatherThanRelocates() {
        let toLate = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 0, typical: 21))
        let toEarly = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 0, typical: 2))

        XCTAssertEqual(toLate[0].hour, 10)
        XCTAssertEqual(toEarly[0].hour, 6)
    }

    /// Above the threshold she is already acting on the alarm, and moving it would be change for
    /// its own sake.
    func testAnAlarmThatIsWorkingIsLeftWhereShePutIt() {
        let out = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 6, typical: 20))

        XCTAssertEqual(out[0].hour, 8)
    }

    func testTheAdherenceThresholdIsInclusive() {
        // 3/7 is below half, 4/7 is above it.
        XCTAssertEqual(SupplementPersonalisation.shiftedHour(from: 8, daysLogged: 3, toward: 12), 10)
        XCTAssertEqual(SupplementPersonalisation.shiftedHour(from: 8, daysLogged: 4, toward: 12), 8)
    }

    func testWithoutAnObservedHourNothingMoves() {
        let out = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 0, typical: nil))

        XCTAssertEqual(out[0].hour, 8)
    }

    /// Signals can be built from stored JSON, and a corrupt hour must not reach a calendar trigger.
    func testAnImpossibleObservedHourIsIgnoredRatherThanTrusted() {
        XCTAssertEqual(SupplementPersonalisation.shiftedHour(from: 8, daysLogged: 0, toward: 24), 8)
        XCTAssertEqual(SupplementPersonalisation.shiftedHour(from: 8, daysLogged: 0, toward: -1), 8)
    }

    /// `UNCalendarNotificationTrigger` takes an hour component; 24 or -1 would be a silent no-fire.
    func testTheShiftedHourIsAlwaysAValidHourOfDay() {
        for hour in 0...23 {
            for typical in 0...23 {
                let shifted = SupplementPersonalisation.shiftedHour(from: hour, daysLogged: 0, toward: typical)
                XCTAssertTrue((0...23).contains(shifted), "hour \(hour) toward \(typical) gave \(shifted)")
            }
        }
    }

    // MARK: - What it says

    func testKeepingItUpEarnsTheAffirmingLine() {
        let out = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 5))

        XCTAssertEqual(out[0].context, SupplementPersonalisation.consistency)
        XCTAssertTrue(out[0].body.hasPrefix("200 mg. From your supplement plan. "))
    }

    /// The planner's standing rule is never to make her feel guilty, and there is no sentence about
    /// a week of blanks that reads as encouragement to the person who lived it. The reminder still
    /// arrives — only the commentary is withheld.
    func testAMissedWeekIsMetWithSilenceNotEncouragement() {
        let out = SupplementPersonalisation.apply(to: [magnesium], signals: signals(days: 0))

        XCTAssertNil(out[0].context)
        XCTAssertEqual(out[0].body, "200 mg. From your supplement plan.")
    }

    /// The pointer to Nutrition is for the woman who said supplements were what she wanted help
    /// with. Sending it to everyone makes it filler.
    func testTheGuidanceLineOnlyReachesTheWomanWhoAskedForIt() {
        let asked = SupplementPersonalisation.apply(
            to: [magnesium], signals: signals(days: 2, quiz: ["support": "supplements"]))
        let didNot = SupplementPersonalisation.apply(
            to: [magnesium], signals: signals(days: 2, quiz: ["support": "tracking"]))

        XCTAssertEqual(asked[0].context, SupplementPersonalisation.guidance)
        XCTAssertNil(didNot[0].context)
    }

    /// `support` is a `quiz_answers.answers` key and `supplements` one of its stored option ids.
    /// If either is renamed this feature silently stops speaking to anyone.
    func testTheQuizKeyItReadsStillExists() {
        let support = QuizContent.questions.first { $0.id == "support" }

        XCTAssertNotNil(support)
        XCTAssertTrue(support?.options.contains { $0.id == "supplements" } == true)
    }

    /// Phase is plumbed because the plumbing is the expensive half, and deliberately unread: any
    /// wording tying a supplement to a phase asserts the supplement does something phase-specific,
    /// which is the unsupported claim the gender question already had stripped out of it. Wiring it
    /// into copy is a medical-reviewer decision, and this test is where that conversation starts.
    func testCyclePhaseChangesNothingUntilAReviewerSaysItMay() {
        let outputs = (Phase.allCases.map { Optional($0) } + [nil]).map {
            SupplementPersonalisation.apply(
                to: [magnesium], signals: signals(days: 5, typical: 12, phase: $0))[0]
        }

        XCTAssertEqual(Set(outputs.map(\.hour)).count, 1)
        XCTAssertEqual(Set(outputs.map { $0.context ?? "" }).count, 1)
    }

    /// The copy scans in the app target walk `allPossibleCopy`, which reaches these through
    /// `allContexts`. A context string added without listing it there ships unscanned.
    func testEveryContextStringIsExposedToTheCopyScans() {
        XCTAssertEqual(Set(SupplementPersonalisation.allContexts),
                       [SupplementPersonalisation.consistency, SupplementPersonalisation.guidance])

        let scanned = SupplementReminder.allPossibleCopy
        for context in SupplementPersonalisation.allContexts {
            XCTAssertTrue(scanned.contains { $0.contains(context) }, "unscanned: \(context)")
        }
    }

    // MARK: - Reading the signals out of her data

    func testItCountsTheDaysOfTheTrailingWeekSheTickedSomething() {
        let today = CalendarDate(2026, 8, 12)
        let logs: [CalendarDate: DailyLog] = [
            today: DailyLog(supplements: ["Folic acid"]),
            today.minusDays(3): DailyLog(supplements: ["Iron"]),
            today.minusDays(6): DailyLog(supplements: ["Vitamin D"]),
            today.minusDays(7): DailyLog(supplements: ["Omega-3"]),   // outside the window
        ]

        XCTAssertEqual(SupplementSignals.daysLoggingSupplements(logs: logs, today: today), 3)
    }

    /// A day she logged water and nothing else is not a day she took her supplements.
    func testADayLoggedWithoutSupplementsDoesNotCount() {
        let today = CalendarDate(2026, 8, 12)
        let logs = [today: DailyLog(mood: .good, supplements: [], waterMl: 2000)]

        XCTAssertEqual(SupplementSignals.daysLoggingSupplements(logs: logs, today: today), 0)
    }

    /// One reading at 3am on a bad night is not a habit, and must not move a morning alarm.
    func testOneOddHourIsNotAHabit() {
        let dates = (0..<SupplementSignals.minimumHourSample - 1).map { at(hour: 3, day: $0 + 1) }

        XCTAssertNil(SupplementSignals.typicalHour(of: dates, calendar: utc))
        XCTAssertNil(SupplementSignals.typicalHour(of: [], calendar: utc))
    }

    func testTheObservedHourIsTheOneSheUsesMostOften() {
        let dates = [at(hour: 7, day: 1), at(hour: 7, day: 2), at(hour: 7, day: 3),
                     at(hour: 19, day: 4), at(hour: 22, day: 5)]

        XCTAssertEqual(SupplementSignals.typicalHour(of: dates, calendar: utc), 7)
    }

    /// The scheduled set is diffed against a remembered one, so the same history must give the same
    /// answer every launch — a tie resolved by dictionary order would reschedule at random.
    func testATieResolvesTheSameWayEveryLaunch() {
        let dates = [at(hour: 21, day: 1), at(hour: 21, day: 2),
                     at(hour: 8, day: 3), at(hour: 8, day: 4)]

        for _ in 0..<20 {
            XCTAssertEqual(SupplementSignals.typicalHour(of: dates.shuffled(), calendar: utc), 8)
        }
    }

    /// A woman who never opens the pH tracker has no timestamped history at all, and gets her alarm
    /// left exactly where she put it. That is the intended outcome, not a gap.
    func testWithoutPhReadingsSheIsSimplyLeftAlone() {
        let today = CalendarDate(2026, 8, 12)
        let built = SupplementSignals.from(logs: [:], readingDates: [], quizAnswers: [:],
                                           phase: nil, today: today, calendar: utc)

        XCTAssertNil(built.typicalLogHour)
        XCTAssertEqual(SupplementPersonalisation.apply(to: [magnesium], signals: built)[0].hour, 8)
    }
}
