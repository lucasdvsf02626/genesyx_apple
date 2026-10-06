import Foundation
import GenesyxCore

/// Explicit records for the actions that have no health data behind them. Kept apart from derived completion.
struct ProgrammeCompletions: Equatable {
    var lessonsRead: Set<String> = []          // lesson ids
    var weeklyReviewsViewed: Set<Int> = []     // programme weeks 1...13
    var ninetyDayReviewViewed = false
}

enum ProgrammeStartOutcome: Equatable {
    case started(CalendarDate)          // day 1 is this date
    case alreadyStarted(CalendarDate)   // nothing changed; the stored start date
    case refusedNoAccess
    case refusedNoConsent
}

/// The 90-Day Programme's own facts: the date she started, a stop marker, the content version in
/// force at the start, and the three explicit completion records. Nothing else is stored. Day,
/// week, phase, progress and "completed" are worked out by `ProgrammeCalendar` every time they are
/// asked for, and every task status and consistency figure comes from the trackers' own records.
///
/// Local only. A backend table (working name `programme_enrolments`, owner-only, in both deletion
/// paths) is a later increment. Until it exists the start date and the completion records do not
/// follow her to a new phone and do not survive a reinstall or a sign-out.
///
/// The start date shows she is taking part in a fertility programme, so it is treated as health
/// data, and so are the completion records: every write is refused without consent, and all of it
/// is wiped by `clearLocalState()`.
///
/// There is deliberately no stop and no restart here: neither has an approved product flow. A stop
/// marker found in the store is loaded, honoured by `position(on:)` and written back unchanged.
/// Missed days change nothing: only `clearLocalState()` ever removes the start date.
@MainActor
final class ProgrammeRepository: ObservableObject {

    /// `.notStarted` until she starts.
    @Published private(set) var state: ProgrammeState
    @Published private(set) var completions: ProgrammeCompletions

    var isCollectionPermitted: HealthDataCollectionGate = { true }
    /// Whether she has access to the programme. Wired to the access service later; until then it
    /// fails closed, so nothing can be started.
    var isAccessActive: @MainActor () -> Bool = { false }

    private let store: LocalStore
    private let contentVersion: String
    private let key = "programme_progress"

    init(store: LocalStore, contentVersion: String = ProgrammeContent.draft.version) {
        self.store = store
        self.contentVersion = contentVersion
        let stored = store.load(ProgrammeProgressDTO.self, forKey: key)
        self.state = stored?.state ?? .notStarted
        self.completions = stored?.completions ?? ProgrammeCompletions()
    }

    /// Where `date` falls in the programme. Derived, never stored.
    func position(on date: CalendarDate) -> ProgrammePosition {
        ProgrammeCalendar.position(state, on: date)
    }

    /// Makes `today` day 1. The only way a start date is written: being given access does not
    /// start the programme. Once a start date is stored this changes nothing, whatever access and
    /// consent say now, so a double tap is safe and a programme is never restarted.
    @discardableResult
    func start(today: CalendarDate) -> ProgrammeStartOutcome {
        if let started = state.startedOn { return .alreadyStarted(started) }
        guard isAccessActive() else { return .refusedNoAccess }
        guard isCollectionPermitted() else { return .refusedNoConsent }
        state = ProgrammeState(startedOn: today, contentVersion: contentVersion)
        persist()
        return .started(today)
    }

    // The three records below say she opened something. Whether a review exists yet is decided by
    // the core review rules, not here.

    /// **Returns false when nothing was recorded**: consent refused, not started, or an id that
    /// is blank or has space around it.
    @discardableResult
    func markLessonRead(_ lessonID: String) -> Bool {
        guard ProgrammeProgressDTO.isLessonID(lessonID) else { return false }
        return record { $0.lessonsRead.insert(lessonID) }
    }

    /// **Returns false when nothing was recorded**: consent refused, not started, or a week
    /// outside 1 to 13.
    @discardableResult
    func markWeeklyReviewViewed(week: Int) -> Bool {
        guard ProgrammeProgressDTO.isWeek(week) else { return false }
        return record { $0.weeklyReviewsViewed.insert(week) }
    }

    /// **Returns false when nothing was recorded**: consent refused, or not started.
    @discardableResult
    func markNinetyDayReviewViewed() -> Bool {
        record { $0.ninetyDayReviewViewed = true }
    }

    /// The one way an explicit record is written. A repeat writes nothing and returns true.
    private func record(_ change: (inout ProgrammeCompletions) -> Void) -> Bool {
        guard isCollectionPermitted(), state.startedOn != nil else { return false }
        var changed = completions
        change(&changed)
        guard changed != completions else { return true }
        completions = changed
        persist()
        return true
    }

    private func persist() {
        store.save(ProgrammeProgressDTO(state: state, completions: completions), forKey: key)
    }

    /// Clear on-device state (memory + store). For sign-out and account deletion.
    func clearLocalState() {
        state = .notStarted
        completions = ProgrammeCompletions()
        store.remove(forKey: key)
    }
}

/// The one value `ProgrammeRepository` persists. The dates are stored as `CalendarDate` encodes
/// itself, the same way `CycleSettings.lastPeriodDate` is kept. Every field is optional with a
/// defaulting read, and each is decoded on its own, so one unreadable value costs that value and
/// never the record.
struct ProgrammeProgressDTO: Codable {
    var startedOn: CalendarDate? = nil
    var stoppedOn: CalendarDate? = nil
    var contentVersion: String? = nil
    var lessonsRead: [String]? = nil
    var weeklyReviewsViewed: [Int]? = nil
    var ninetyDayReviewViewed: Bool? = nil
}

extension ProgrammeProgressDTO {
    init(from decoder: Decoder) throws {
        let values = try? decoder.container(keyedBy: CodingKeys.self)
        startedOn = try? values?.decode(CalendarDate.self, forKey: .startedOn)
        stoppedOn = try? values?.decode(CalendarDate.self, forKey: .stoppedOn)
        contentVersion = try? values?.decode(String.self, forKey: .contentVersion)
        lessonsRead = try? values?.decode([String].self, forKey: .lessonsRead)
        weeklyReviewsViewed = try? values?.decode([Int].self, forKey: .weeklyReviewsViewed)
        ninetyDayReviewViewed = try? values?.decode(Bool.self, forKey: .ninetyDayReviewViewed)
    }

    /// The sets are written sorted, so the same facts always encode to the same lists.
    init(state: ProgrammeState, completions: ProgrammeCompletions) {
        self.init(
            startedOn: state.startedOn,
            stoppedOn: state.stoppedOn,
            contentVersion: state.contentVersion,
            lessonsRead: completions.lessonsRead.sorted(),
            weeklyReviewsViewed: completions.weeklyReviewsViewed.sorted(),
            ninetyDayReviewViewed: completions.ninetyDayReviewViewed
        )
    }

    /// No start date reads as not started, and a stop marker with no start date is ignored.
    var state: ProgrammeState {
        guard let startedOn else { return .notStarted }
        return ProgrammeState(startedOn: startedOn, stoppedOn: stoppedOn, contentVersion: contentVersion)
    }

    /// Blank lesson ids and weeks outside 1 to 13 are dropped; a missing set is empty and a
    /// missing flag is false. With no start date there are none, as there is no stop marker:
    /// records of a run that cannot be placed must not open the programme she starts next.
    var completions: ProgrammeCompletions {
        guard startedOn != nil else { return ProgrammeCompletions() }
        return ProgrammeCompletions(
            lessonsRead: Set((lessonsRead ?? []).filter(Self.isLessonID)),
            weeklyReviewsViewed: Set((weeklyReviewsViewed ?? []).filter(Self.isWeek)),
            ninetyDayReviewViewed: ninetyDayReviewViewed ?? false
        )
    }

    /// What an explicit record has to be, on the way in and on the way back out of the store.
    /// An id with space around it would be stored and then match no lesson.
    static func isLessonID(_ id: String) -> Bool {
        !id.isEmpty && id == id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isWeek(_ week: Int) -> Bool {
        (1...ProgrammeCalendar.totalWeeks).contains(week)
    }
}
