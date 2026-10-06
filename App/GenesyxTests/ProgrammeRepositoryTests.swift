import XCTest
@testable import Genesyx
import GenesyxCore

/// The programme's own store: the start date, a stop marker, the content version and the three
/// explicit completion records, and nothing else. Shaped like `PeriodRepositoryTests`; the day,
/// week and phase arithmetic itself is tested in the core.
@MainActor
final class ProgrammeRepositoryTests: XCTestCase {

    private static let key = "programme_progress"

    private let start = CalendarDate(2026, 6, 1)

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    /// The bytes under the key, exactly as they sit in the store.
    private func bytes(_ defaults: UserDefaults) -> Data? {
        defaults.data(forKey: "genesyx.\(Self.key)")
    }

    private func saved(_ defaults: UserDefaults) -> ProgrammeProgressDTO? {
        LocalStore(defaults: defaults).load(ProgrammeProgressDTO.self, forKey: Self.key)
    }

    /// A repository with access and consent, as the container will wire it.
    private func open(_ defaults: UserDefaults) -> ProgrammeRepository {
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        repo.isAccessActive = { true }
        return repo
    }

    private func started(_ defaults: UserDefaults) -> ProgrammeRepository {
        let repo = open(defaults)
        XCTAssertEqual(repo.start(today: start), .started(start))
        return repo
    }

    private func write(_ json: String, to defaults: UserDefaults) {
        defaults.set(Data(json.utf8), forKey: "genesyx.\(Self.key)")
    }

    private func stored(_ date: CalendarDate) -> String { #"{"dayNumber":\#(date.dayNumber)}"# }

    // MARK: - Not started

    func testANewRepositoryIsNotStartedAndStoresNothing() {
        let defaults = makeDefaults()
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertEqual(repo.completions, ProgrammeCompletions())
        XCTAssertEqual(repo.position(on: start), .notStarted)
        XCTAssertNil(bytes(defaults), "nothing is written until she starts")
    }

    // MARK: - Start

    /// The default access closure fails closed: a repository nobody wired cannot start anything.
    func testStartIsRefusedWithoutAccessAndWritesNothing() {
        let defaults = makeDefaults()
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.start(today: start), .refusedNoAccess)
        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertNil(bytes(defaults))
    }

    func testStartIsRefusedWithoutConsentAndWritesNothing() {
        let defaults = makeDefaults()
        let repo = open(defaults)
        repo.isCollectionPermitted = { false }
        XCTAssertEqual(repo.start(today: start), .refusedNoConsent)
        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertNil(bytes(defaults))

        // Neither: access is asked first.
        repo.isAccessActive = { false }
        XCTAssertEqual(repo.start(today: start), .refusedNoAccess)
        XCTAssertNil(bytes(defaults))
    }

    func testStartStoresTheDateAndTheContentVersion() {
        let defaults = makeDefaults()
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults), contentVersion: "version-under-test")
        repo.isAccessActive = { true }

        XCTAssertEqual(repo.start(today: start), .started(start))

        XCTAssertEqual(repo.state, ProgrammeState(startedOn: start, contentVersion: "version-under-test"))
        XCTAssertEqual(repo.position(on: start), .active(day: 1, week: 1, phase: .buildTheFoundation))
        XCTAssertEqual(saved(defaults)?.startedOn, start)
        XCTAssertEqual(saved(defaults)?.contentVersion, "version-under-test")
        XCTAssertNil(saved(defaults)?.stoppedOn)

        XCTAssertEqual(started(makeDefaults()).state.contentVersion, ProgrammeContent.draft.version,
                       "the draft content's version unless another is passed")
    }

    /// A double tap, a later day, access since lost, consent since withdrawn: the first date
    /// stands and not a byte of the store moves.
    func testASecondStartChangesNothingAndNeverRestarts() {
        let defaults = makeDefaults()
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        var access = true
        var consent = true
        repo.isAccessActive = { access }
        repo.isCollectionPermitted = { consent }
        XCTAssertEqual(repo.start(today: start), .started(start))
        let state = repo.state
        let before = bytes(defaults)
        XCTAssertNotNil(before)

        XCTAssertEqual(repo.start(today: start), .alreadyStarted(start), "a double tap")
        XCTAssertEqual(repo.start(today: start.plusDays(12)), .alreadyStarted(start), "a later day")
        access = false
        XCTAssertEqual(repo.start(today: start.plusDays(13)), .alreadyStarted(start), "access since lost")
        consent = false
        XCTAssertEqual(repo.start(today: start.plusDays(14)), .alreadyStarted(start), "consent since withdrawn")
        XCTAssertEqual(repo.start(today: start.minusDays(5)), .alreadyStarted(start), "a clock moved back")

        XCTAssertEqual(repo.state, state)
        XCTAssertEqual(bytes(defaults), before)
    }

    func testStateAndCompletionsSurviveARelaunch() {
        let defaults = makeDefaults()
        let repo = started(defaults)
        repo.markLessonRead("programme-day-001")
        repo.markWeeklyReviewViewed(week: 1)

        let relaunched = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(relaunched.state, repo.state)
        XCTAssertEqual(relaunched.state.startedOn, start)
        XCTAssertEqual(relaunched.completions, repo.completions)
        XCTAssertEqual(relaunched.start(today: start.plusDays(3)), .alreadyStarted(start),
                       "and it is still started, with the default access closure")
    }

    // MARK: - Derived values

    func testDayWeekAndPhaseComeFromTheCalendar() {
        let repo = started(makeDefaults())
        let expected: [(day: Int, position: ProgrammePosition)] = [
            (1, .active(day: 1, week: 1, phase: .buildTheFoundation)),
            (7, .active(day: 7, week: 1, phase: .buildTheFoundation)),
            (8, .active(day: 8, week: 2, phase: .buildTheFoundation)),
            (30, .active(day: 30, week: 5, phase: .buildTheFoundation)),
            (31, .active(day: 31, week: 5, phase: .discoverYourPatterns)),
            (90, .active(day: 90, week: 13, phase: .personaliseAndSustain)),
            (91, .completed(day: 91)),
        ]
        for (day, position) in expected {
            XCTAssertEqual(repo.position(on: start.plusDays(day - 1)), position, "day \(day)")
        }
        XCTAssertEqual(repo.position(on: start.minusDays(1)), .beforeStart(daysUntilStart: 1))
        XCTAssertEqual(repo.position(on: start.minusDays(3)), .beforeStart(daysUntilStart: 3))
        for offset in [-3, 0, 22, 90, 400] {
            let date = start.plusDays(offset)
            XCTAssertEqual(repo.position(on: date), ProgrammeCalendar.position(repo.state, on: date))
        }
    }

    /// Forty days in which she never opens the programme. The day moves on by itself, and the
    /// start date and the stored bytes are exactly as they were.
    func testMissedDaysNeverResetOrRestart() {
        let defaults = makeDefaults()
        let repo = started(defaults)
        let before = bytes(defaults)

        for offset in 0..<40 { _ = repo.position(on: start.plusDays(offset)) }

        XCTAssertEqual(repo.position(on: start.plusDays(40)), .active(day: 41, week: 6, phase: .discoverYourPatterns))
        XCTAssertEqual(repo.state.startedOn, start)
        XCTAssertEqual(bytes(defaults), before)
        XCTAssertEqual(ProgrammeRepository(store: LocalStore(defaults: defaults)).position(on: start.plusDays(40)),
                       .active(day: 41, week: 6, phase: .discoverYourPatterns), "a launch after forty days is day 41")
    }

    // MARK: - Clocks

    private func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    private func instant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// The start is a date, not an instant: one minute to midnight is all of day 1 she gets.
    func testAStartAtOneMinuteToMidnightIsDayOneAndTheNextMinuteIsDayTwo() {
        let zone = calendar(TimeZone(secondsFromGMT: 3_600)!)
        let lateNight = instant(2026, 6, 1, 23, 59, in: zone)
        let repo = open(makeDefaults())

        XCTAssertEqual(repo.start(today: CalendarDate.today(zone, now: lateNight)), .started(start))

        func position(_ now: Date) -> ProgrammePosition { repo.position(on: CalendarDate.today(zone, now: now)) }
        XCTAssertEqual(position(lateNight), .active(day: 1, week: 1, phase: .buildTheFoundation))
        XCTAssertEqual(position(lateNight.addingTimeInterval(60)), .active(day: 2, week: 1, phase: .buildTheFoundation))
        XCTAssertEqual(position(lateNight.addingTimeInterval(-23 * 3_600)), .active(day: 1, week: 1, phase: .buildTheFoundation))
    }

    /// The clocks go back on 25 October 2026 in London, so that date lasts twenty-five hours, and
    /// forward on 29 March, so that one lasts twenty-three. The day moves once per calendar date.
    func testAcrossADaylightSavingChangeTheDayMovesOncePerCalendarDate() throws {
        let london = calendar(try XCTUnwrap(TimeZone(identifier: "Europe/London")))
        func day(_ repo: ProgrammeRepository, _ now: Date) -> ProgrammePosition {
            repo.position(on: CalendarDate.today(london, now: now))
        }
        func active(_ day: Int) -> ProgrammePosition { .active(day: day, week: 1, phase: .buildTheFoundation) }

        let autumn = open(makeDefaults())
        let midnight = instant(2026, 10, 25, 0, 0, in: london)
        autumn.start(today: CalendarDate.today(london, now: midnight))
        XCTAssertEqual(day(autumn, midnight), active(1))
        XCTAssertEqual(day(autumn, midnight.addingTimeInterval(24 * 3_600)), active(1), "24 hours on it is still the 25th")
        XCTAssertEqual(day(autumn, midnight.addingTimeInterval(25 * 3_600)), active(2))
        XCTAssertEqual(day(autumn, instant(2026, 10, 26, 23, 59, in: london)), active(2))
        XCTAssertEqual(day(autumn, instant(2026, 10, 27, 0, 0, in: london)), active(3))

        let spring = open(makeDefaults())
        let springMidnight = instant(2026, 3, 29, 0, 0, in: london)
        spring.start(today: CalendarDate.today(london, now: springMidnight))
        XCTAssertEqual(day(spring, springMidnight.addingTimeInterval(22 * 3_600 + 59 * 60)), active(1))
        XCTAssertEqual(day(spring, springMidnight.addingTimeInterval(23 * 3_600)), active(2), "23 hours on it is the 30th")
        XCTAssertEqual(day(spring, instant(2026, 3, 31, 12, 0, in: london)), active(3))
    }

    // MARK: - Explicit completions

    func testEachMarkIsRecordedOnceAndSurvivesARelaunch() {
        let defaults = makeDefaults()
        let repo = started(defaults)
        let state = repo.state

        XCTAssertTrue(repo.markLessonRead("programme-day-002"))
        XCTAssertTrue(repo.markLessonRead("programme-day-001"))
        XCTAssertTrue(repo.markWeeklyReviewViewed(week: 13))
        XCTAssertTrue(repo.markWeeklyReviewViewed(week: 1))
        XCTAssertTrue(repo.markNinetyDayReviewViewed())
        let once = bytes(defaults)

        XCTAssertTrue(repo.markLessonRead("programme-day-001"), "a repeat is a no-op that still succeeds")
        XCTAssertTrue(repo.markWeeklyReviewViewed(week: 1))
        XCTAssertTrue(repo.markNinetyDayReviewViewed())
        XCTAssertEqual(bytes(defaults), once, "a repeat writes nothing")

        let expected = ProgrammeCompletions(lessonsRead: ["programme-day-001", "programme-day-002"],
                                            weeklyReviewsViewed: [1, 13], ninetyDayReviewViewed: true)
        XCTAssertEqual(repo.completions, expected)
        XCTAssertEqual(saved(defaults)?.lessonsRead, ["programme-day-001", "programme-day-002"])
        XCTAssertEqual(saved(defaults)?.weeklyReviewsViewed, [1, 13])
        XCTAssertEqual(saved(defaults)?.ninetyDayReviewViewed, true)
        XCTAssertEqual(repo.state, state, "a completion record never touches the programme state")
        XCTAssertEqual(saved(defaults)?.startedOn, start)

        let relaunched = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(relaunched.completions, expected)
        XCTAssertEqual(relaunched.state, state)
    }

    func testMarksAreRefusedBeforeTheStart() {
        let defaults = makeDefaults()
        let repo = open(defaults)
        XCTAssertFalse(repo.markLessonRead("programme-day-001"))
        XCTAssertFalse(repo.markWeeklyReviewViewed(week: 1))
        XCTAssertFalse(repo.markNinetyDayReviewViewed())
        XCTAssertEqual(repo.completions, ProgrammeCompletions())
        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertNil(bytes(defaults))
    }

    func testMarksAreRefusedForABlankIdAndForWeeksOutsideTheProgramme() {
        let defaults = makeDefaults()
        let repo = started(defaults)
        let before = bytes(defaults)
        // A blank id, and one with space around it: stored as given it would match no lesson.
        for id in ["", " ", "\n\t ", " programme-day-001", "programme-day-001\n"] {
            XCTAssertFalse(repo.markLessonRead(id), "lesson id \(id.debugDescription)")
        }
        for week in [0, 14, -1, 99] { XCTAssertFalse(repo.markWeeklyReviewViewed(week: week), "week \(week)") }
        XCTAssertEqual(repo.completions, ProgrammeCompletions())
        XCTAssertEqual(bytes(defaults), before)
        XCTAssertEqual(repo.state.startedOn, start)
    }

    func testMarksAreRefusedWithoutConsent() {
        let defaults = makeDefaults()
        let repo = started(defaults)
        XCTAssertTrue(repo.markLessonRead("programme-day-001"))
        let state = repo.state
        let completions = repo.completions
        let before = bytes(defaults)

        repo.isCollectionPermitted = { false }
        XCTAssertFalse(repo.markLessonRead("programme-day-002"))
        XCTAssertFalse(repo.markLessonRead("programme-day-001"), "refused even for one already recorded")
        XCTAssertFalse(repo.markWeeklyReviewViewed(week: 1))
        XCTAssertFalse(repo.markNinetyDayReviewViewed())

        XCTAssertEqual(repo.completions, completions)
        XCTAssertEqual(repo.state, state)
        XCTAssertEqual(bytes(defaults), before)
    }

    // MARK: - Stop marker

    /// Nothing here writes a stop marker. One that is already in the store is honoured and kept.
    func testAStoredStopMarkerIsHonouredAndWrittenBackUnchanged() {
        let defaults = makeDefaults()
        let stop = start.plusDays(10)
        LocalStore(defaults: defaults).save(
            ProgrammeProgressDTO(startedOn: start, stoppedOn: stop, contentVersion: "draft-1"), forKey: Self.key)

        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.state, ProgrammeState(startedOn: start, stoppedOn: stop, contentVersion: "draft-1"))
        XCTAssertEqual(repo.position(on: stop.minusDays(1)), .active(day: 10, week: 2, phase: .buildTheFoundation))
        XCTAssertEqual(repo.position(on: stop), .stopped)
        XCTAssertEqual(repo.position(on: stop.plusDays(200)), .stopped)

        repo.isAccessActive = { true }
        XCTAssertEqual(repo.start(today: stop.plusDays(5)), .alreadyStarted(start), "a stopped programme is not restarted")
        XCTAssertTrue(repo.markLessonRead("programme-day-003"))

        XCTAssertEqual(saved(defaults)?.stoppedOn, stop)
        XCTAssertEqual(saved(defaults)?.startedOn, start)
        XCTAssertEqual(saved(defaults)?.contentVersion, "draft-1")
        XCTAssertEqual(saved(defaults)?.lessonsRead, ["programme-day-003"])
        XCTAssertEqual(ProgrammeRepository(store: LocalStore(defaults: defaults)).position(on: stop), .stopped)
    }

    // MARK: - What is in the store

    func testAnEmptyOrUnreadableRecordLoadsAsNotStarted() {
        for json in ["{}", "[1, 2]", "not json at all"] {
            let defaults = makeDefaults()
            write(json, to: defaults)
            let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
            XCTAssertEqual(repo.state, .notStarted, json)
            XCTAssertEqual(repo.completions, ProgrammeCompletions(), json)
        }
    }

    /// A build that stored more than this one knows: the extra keys are ignored, and a day number
    /// found in the store is never believed over the calendar.
    func testUnknownExtraKeysAreIgnored() {
        let defaults = makeDefaults()
        write("""
            {"startedOn":\(stored(start)),"contentVersion":"draft-1","day":57,"week":9,"phase":3,"completed":true,
             "lessonsRead":["programme-day-001"],"somethingNew":{"a":[1,2]}}
            """, to: defaults)
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.state, ProgrammeState(startedOn: start, contentVersion: "draft-1"))
        XCTAssertEqual(repo.completions, ProgrammeCompletions(lessonsRead: ["programme-day-001"]))
        XCTAssertEqual(repo.position(on: start.plusDays(1)), .active(day: 2, week: 1, phase: .buildTheFoundation))
    }

    /// One unreadable value costs that value and not the record.
    func testAWrongTypeInOneFieldCostsOnlyThatField() {
        let lessons = makeDefaults()
        write("""
            {"startedOn":\(stored(start)),"contentVersion":7,"lessonsRead":"programme-day-001",
             "weeklyReviewsViewed":[1,2],"ninetyDayReviewViewed":true}
            """, to: lessons)
        var repo = ProgrammeRepository(store: LocalStore(defaults: lessons))
        XCTAssertEqual(repo.state, ProgrammeState(startedOn: start))
        XCTAssertEqual(repo.completions, ProgrammeCompletions(weeklyReviewsViewed: [1, 2], ninetyDayReviewViewed: true))

        let flag = makeDefaults()
        write("""
            {"startedOn":\(stored(start)),"lessonsRead":["programme-day-004"],"weeklyReviewsViewed":"all",
             "ninetyDayReviewViewed":"yes"}
            """, to: flag)
        repo = ProgrammeRepository(store: LocalStore(defaults: flag))
        XCTAssertEqual(repo.state.startedOn, start)
        XCTAssertEqual(repo.completions, ProgrammeCompletions(lessonsRead: ["programme-day-004"]))

        // An unreadable start date is no start date.
        let date = makeDefaults()
        write(#"{"startedOn":"2026-06-01","contentVersion":"draft-1","lessonsRead":["programme-day-001"]}"#, to: date)
        repo = ProgrammeRepository(store: LocalStore(defaults: date))
        XCTAssertEqual(repo.state, .notStarted)
    }

    /// Completion records with no start date belonged to a run that can no longer be placed.
    /// They are not loaded, so the programme she then starts does not begin with them.
    func testCompletionsWithNoStartDateAreNotCarriedIntoANewRun() {
        let defaults = makeDefaults()
        write("""
            {"startedOn":"2026-06-01","lessonsRead":["programme-day-001"],"weeklyReviewsViewed":[4],
             "ninetyDayReviewViewed":true}
            """, to: defaults)
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertEqual(repo.completions, ProgrammeCompletions())

        repo.isAccessActive = { true }
        XCTAssertEqual(repo.start(today: start), .started(start))
        XCTAssertEqual(repo.completions, ProgrammeCompletions())
        XCTAssertEqual(saved(defaults)?.lessonsRead, [])
        XCTAssertEqual(saved(defaults)?.weeklyReviewsViewed, [])
        XCTAssertEqual(saved(defaults)?.ninetyDayReviewViewed, false)
        XCTAssertEqual(ProgrammeRepository(store: LocalStore(defaults: defaults)).completions, ProgrammeCompletions())
    }

    func testWeeksOutsideTheProgrammeAndBlankLessonIdsAreDroppedOnRead() {
        let defaults = makeDefaults()
        write("""
            {"startedOn":\(stored(start)),"weeklyReviewsViewed":[0,4,99,13,-2,4],
             "lessonsRead":["","programme-day-002","  ","programme-day-002"," programme-day-003"]}
            """, to: defaults)
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.completions,
                       ProgrammeCompletions(lessonsRead: ["programme-day-002"], weeklyReviewsViewed: [4, 13]))
    }

    func testAStopMarkerWithNoStartDateIsIgnored() {
        let defaults = makeDefaults()
        write(#"{"stoppedOn":\#(stored(start.plusDays(4))),"contentVersion":"old"}"#, to: defaults)
        let repo = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertEqual(repo.position(on: start.plusDays(9)), .notStarted)

        // And it does not come back to stop the programme she then starts.
        repo.isAccessActive = { true }
        XCTAssertEqual(repo.start(today: start.plusDays(9)), .started(start.plusDays(9)))
        XCTAssertNil(saved(defaults)?.stoppedOn)
        XCTAssertEqual(repo.position(on: start.plusDays(10)), .active(day: 2, week: 1, phase: .buildTheFoundation))
    }

    func testClearLocalStateEmptiesMemoryAndRemovesTheKey() {
        let defaults = makeDefaults()
        let repo = started(defaults)
        repo.markLessonRead("programme-day-001")
        repo.markWeeklyReviewViewed(week: 1)
        repo.markNinetyDayReviewViewed()
        XCTAssertNotNil(bytes(defaults))

        repo.clearLocalState()

        XCTAssertEqual(repo.state, .notStarted)
        XCTAssertEqual(repo.completions, ProgrammeCompletions())
        XCTAssertNil(bytes(defaults))
        let next = ProgrammeRepository(store: LocalStore(defaults: defaults))
        XCTAssertEqual(next.state, .notStarted)
        XCTAssertEqual(next.completions, ProgrammeCompletions())
    }

    /// Only the six facts are ever stored. A day, a week, a phase or a "completed" flag in the
    /// store would be a second answer to a question the calendar already answers.
    func testTheEncodedKeysAreExactlyTheSixFields() throws {
        let six: Set<String> = ["startedOn", "stoppedOn", "contentVersion", "lessonsRead", "weeklyReviewsViewed",
                                "ninetyDayReviewViewed"]
        XCTAssertEqual(Set(Mirror(reflecting: ProgrammeProgressDTO()).children.compactMap(\.label)), six)

        let full = ProgrammeProgressDTO(startedOn: start, stoppedOn: start.plusDays(3), contentVersion: "v",
                                        lessonsRead: ["a"], weeklyReviewsViewed: [1], ninetyDayReviewViewed: true)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(full)) as? [String: Any])
        XCTAssertEqual(Set(encoded.keys), six)

        // What the repository itself writes: the same fields, less the stop marker it never sets.
        let defaults = makeDefaults()
        let repo = started(defaults)
        repo.markLessonRead("programme-day-001")
        repo.markWeeklyReviewViewed(week: 1)
        repo.markNinetyDayReviewViewed()
        let written = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(bytes(defaults))) as? [String: Any])
        XCTAssertEqual(Set(written.keys), six.subtracting(["stoppedOn"]))
        XCTAssertEqual((written["startedOn"] as? [String: Any])?["dayNumber"] as? Int, start.dayNumber,
                       "the date is stored as `CalendarDate` encodes itself")
    }

    // MARK: - Source guard

    /// No clock is read here, nothing is written to the console, and the file knows neither the
    /// access service nor the pregnancy test records.
    func testTheRepositorySourceReadsNoClockAndNamesNothingItMustNot() throws {
        let source = try String(contentsOf: Self.repoRoot.appendingPathComponent("App/Genesyx/Data/ProgrammeRepository.swift"),
                                encoding: .utf8)
        XCTAssertTrue(source.contains("final class ProgrammeRepository"), "the path is wrong, not the code")
        for banned in ["Date()", ".today()", "print(", "FertilityKitAccessService", "hcg", "Hcg"] {
            XCTAssertFalse(source.contains(banned), "ProgrammeRepository.swift must not contain `\(banned)`")
        }
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GenesyxTests
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // repo root
    }
}
