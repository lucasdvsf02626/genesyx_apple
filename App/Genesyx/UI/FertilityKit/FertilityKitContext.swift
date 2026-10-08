import GenesyxCore
import SwiftUI

/// Where the account stands with the Fertility Kit. Worked out from access and the calendar,
/// never stored.
enum FertilityKitAccessState: Equatable {
    /// No access, or a grant that was taken back. A stored start date changes nothing here.
    case noAccess
    /// Access held, no start date chosen.
    case notStarted
    /// Access held, start date ahead.
    case scheduled(startsOn: CalendarDate, daysUntilStart: Int)
    case active(day: Int, week: Int, phase: ProgrammePhase)
    /// From day 91.
    case completed
    /// A stop marker found in storage.
    case stopped

    static func resolve(hasAccess: Bool, state: ProgrammeState, today: CalendarDate) -> FertilityKitAccessState {
        guard hasAccess else { return .noAccess }
        switch ProgrammeCalendar.position(state, on: today) {
        case .notStarted: return .notStarted
        case .beforeStart(let daysUntilStart):
            return .scheduled(startsOn: state.startedOn ?? today, daysUntilStart: daysUntilStart)
        case .active(let day, let week, let phase): return .active(day: day, week: week, phase: phase)
        case .completed: return .completed
        case .stopped: return .stopped
        }
    }
}

/// Everything a Fertility Kit screen reads, as one plain value. `FertilityKitHost` builds it from
/// the repositories and puts it in the environment; a screen reads it and never observes a
/// repository in order to redraw.
struct FertilityKitContext {
    /// False anywhere outside More: nothing of the kit renders.
    var isHosted = false
    var today: CalendarDate
    var scanAvailable = false
    var cycleHistoryAvailable = false
    /// The kit is on in this build and the account holds access.
    var hasAccess = false
    /// State, completions, logs, test dates, periods, cycle settings, quiz answers and consent.
    var planInput: ProgrammePlanInput
    var cycles: [DerivedCycle] = []
    /// Period starts kept on this phone that the server refused.
    var refusedPeriodStarts: Set<CalendarDate> = []
    var phReadings: [PhReading] = []
    /// Already empty when scanning is not available.
    var lhResults: [LhResult] = []
    var navigation = FertilityKitNavigation()
}

/// The four closures More hands down. The defaults do nothing.
struct FertilityKitNavigation {
    var open: (MoreDestination) -> Void = { _ in }
    var openScan: (ScanDeepLink) -> Void = { _ in }
    /// A guide section's slug.
    var openGuideSection: (String) -> Void = { _ in }
    /// A programme week, 1 to 13.
    var openWeeklyReview: (Int) -> Void = { _ in }
}

extension FertilityKitContext {

    func open(_ destination: MoreDestination) { navigation.open(destination) }
    func openScan(_ target: ScanDeepLink) { navigation.openScan(target) }
    func openGuideSection(_ slug: String) { navigation.openGuideSection(slug) }
    func openWeeklyReview(_ week: Int) { navigation.openWeeklyReview(week) }

    var accessState: FertilityKitAccessState {
        FertilityKitAccessState.resolve(hasAccess: hasAccess, state: planInput.state, today: today)
    }

    var position: ProgrammePosition { ProgrammeCalendar.position(planInput.state, on: today) }

    /// The programme day the reader opens on: today's while active, 90 once completed, otherwise none.
    var readableDay: Int? {
        switch position {
        case .active(let day, _, _): return day
        case .completed: return ProgrammeCalendar.totalDays
        case .notStarted, .beforeStart, .stopped: return nil
        }
    }

    var isNinetyDayReviewAvailable: Bool {
        ProgrammeReviewLogic.isNinetyDayReviewAvailable(state: planInput.state, today: today)
    }

    /// nil when today is not a programme day.
    func todayPlan() -> ProgrammeDayPlan? {
        ProgrammePlanService.plan(on: today, input: planInput)
    }

    /// nil without a start date or outside days 1 to 90.
    func dayPlan(forDay day: Int) -> ProgrammeDayPlan? {
        guard let start = planInput.state.startedOn, (1...ProgrammeCalendar.totalDays).contains(day) else { return nil }
        return ProgrammePlanService.plan(on: ProgrammeCalendar.date(ofDay: day, startedOn: start), input: planInput)
    }

    /// Up to ninety plans. Take them once at the top of a body, never inside a loop.
    func plans() -> [ProgrammeDayPlan] { ProgrammePlanService.plans(planInput) }

    func report() -> ProgrammeConsistencyReport { ProgrammePlanService.report(planInput) }

    func reviewInput(patterns: [ProgrammeEvidenceStatement] = []) -> ProgrammeReviewInput {
        ProgrammeReviewInput(
            state: planInput.state, today: today, goal: ProgrammePlanService.goal(planInput),
            consentActive: planInput.consentActive, plans: plans(), logsByDate: planInput.logsByDate,
            waterGoalMl: planInput.waterGoalMl, phReadingDates: planInput.phReadingDates,
            lhResultDates: scanAvailable ? planInput.lhResultDates : [], cycles: cycles, patterns: patterns,
            content: .draft)
    }

    func pictureInput() -> FertilityPictureInput {
        pictureInput(today: today, consistency: planInput.state.startedOn == nil ? nil : report())
    }

    /// The pattern statements as of day 90, for the 90-Day Review only: the pattern rules take
    /// every window from the input's today, so nothing recorded after the programme can enter a
    /// sentence shown under that review. They do not read the consistency figures.
    func ninetyDayPatterns() -> [ProgrammeEvidenceStatement] {
        guard let start = planInput.state.startedOn else { return [] }
        let lastDay = ProgrammeCalendar.date(ofDay: ProgrammeCalendar.totalDays, startedOn: start)
        return FertilityPicturePatterns.statements(pictureInput(today: min(today, lastDay), consistency: nil))
    }

    /// Consent is passed on purpose: its default is false and would silently withhold the picture.
    private func pictureInput(today: CalendarDate, consistency: ProgrammeConsistencyReport?) -> FertilityPictureInput {
        FertilityPictureInput(
            today: today, calendar: .autoupdatingCurrent, consentActive: planInput.consentActive,
            cycleSettings: planInput.cycleSettings, cycles: cycles, logsByDate: planInput.logsByDate,
            waterGoalMl: planInput.waterGoalMl, hydrationUnit: HydrationPrefs.current.unit,
            glassMl: HydrationPrefs.current.glassMl, phReadings: phReadings, lhResults: lhResults,
            scanFeaturesAvailable: scanAvailable, phLoggingAvailable: planInput.phLoggingAvailable,
            programmeState: planInput.state, consistency: consistency, content: .draft)
    }
}

private struct FertilityKitContextKey: EnvironmentKey {
    /// Not hosted: what every screen outside More reads, and what a Release build always reads.
    static var defaultValue: FertilityKitContext {
        let today = FertilityKitClock.current()
        return FertilityKitContext(today: today, planInput: ProgrammePlanInput(state: .notStarted, today: today))
    }
}

extension EnvironmentValues {
    var fertilityKit: FertilityKitContext {
        get { self[FertilityKitContextKey.self] }
        set { self[FertilityKitContextKey.self] = newValue }
    }
}

/// The one reader of the device's date for the kit. The calendar is the one the plan source and
/// the picture use for the local day of a record, so "today" and "the day a reading belongs to"
/// cannot disagree.
enum FertilityKitClock {

    static func current() -> CalendarDate {
        let deviceToday = CalendarDate.today(.autoupdatingCurrent)
        #if DEBUG
        // A seeded launch is anchored to the date of its seed, so a UI journey never depends on
        // the time of day it runs at.
        if UserDefaults.standard.bool(forKey: "uiTestSeed") {
            return resolve(anchorDayNumber: UserDefaults.standard.object(forKey: "uiTestKitAnchor") as? Int,
                           shift: KitUITestSeed.positive(UserDefaults.standard.string(forKey: "uiTestKitDayShift")) ?? 0,
                           deviceToday: deviceToday)
        }
        #endif
        return deviceToday
    }

    /// The anchor when there is one, otherwise the device's date, plus the shift.
    static func resolve(anchorDayNumber: Int?, shift: Int, deviceToday: CalendarDate) -> CalendarDate {
        (anchorDayNumber.map(CalendarDate.init(dayNumber:)) ?? deviceToday).plusDays(shift)
    }
}

#if DEBUG
/// Launch options read by the kit's development controls. Here, so this stays the only kit file
/// that names the defaults.
enum FertilityKitDebugOptions {
    /// `-uiTestKitHideDebug YES`: the QA reset buttons are not drawn.
    static var hidesDebugControls: Bool { UserDefaults.standard.bool(forKey: "uiTestKitHideDebug") }
}

extension View {
    /// Preview scaffolding for a kit screen. It builds its own container: an isolated store,
    /// consent granted first (a seed is refused without it), a sign-in, a grant when `access`,
    /// and a start that makes today programme day `day`.
    @MainActor
    func withKitPreview(access: Bool = true, day: Int? = nil) -> some View {
        let store = LocalStore(defaults: UserDefaults(suiteName: "preview.kit.\(UUID().uuidString)")!)
        let container = AppContainer(store: store, backend: nil, monitorNetwork: false)
        container.consent.grant()
        container.session.signIn(email: "kit.preview@example.com", name: "Preview")
        KitUITestSeed(access: access, day: day).apply(to: container, anchor: FertilityKitClock.current())
        return NavigationStack {
            FertilityKitHost(gated: false, scanAvailable: true, cycleHistoryAvailable: container.cycleHistory,
                             navigation: FertilityKitNavigation()) { self }
        }
        .withAppEnvironment(container)
        .environmentObject(TabRouter())
        .tint(GenesyxColor.primary)
    }
}
#endif
