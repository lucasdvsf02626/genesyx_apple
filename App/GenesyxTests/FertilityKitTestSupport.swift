import XCTest
import GenesyxCore
@testable import Genesyx

/// The one fixture every app test of the Fertility Kit uses, so that no two test files declare a
/// fixture of their own under a name that collides in the single test bundle.
@MainActor
enum KitFixture {

    /// An isolated container: its own store, no backend, no network monitor, consent granted and
    /// signed in. Nothing is seeded and no access is held.
    static func container(fertilityKit: Bool = true, cycleHistory: Bool = true) -> AppContainer {
        let store = LocalStore(defaults: UserDefaults(suiteName: "kit.fixture.\(UUID().uuidString)")!)
        let container = AppContainer(store: store, backend: nil, monitorNetwork: false,
                                     fertilityKit: fertilityKit, cycleHistory: cycleHistory)
        container.consent.grant()
        container.session.signIn(email: "kit.fixture@example.com", name: "Fixture")
        return container
    }

    /// A context as a plain value, with no container behind it. `day` makes `today` programme
    /// day N, `startsIn` schedules the start that many days ahead, and `state` wins over both
    /// (it is how a stop marker is built). A reading or a result belongs to the local day of
    /// its instant, by the calendar the app's own source uses.
    static func context(
        today: CalendarDate, day: Int? = nil, startsIn: Int? = nil, state: ProgrammeState? = nil,
        access: Bool = true, scan: Bool = true, cycleHistory: Bool = true, consent: Bool = true,
        logs: [CalendarDate: DailyLog] = [:], periods: [PeriodRecord] = [], cycles: [DerivedCycle] = [],
        refusedPeriodStarts: Set<CalendarDate> = [], phReadings: [PhReading] = [], lhResults: [LhResult] = [],
        quizAnswers: [String: String] = [:], navigation: FertilityKitNavigation = FertilityKitNavigation(),
        cycleSettings: CycleSettings? = nil, completions: ProgrammeCompletions = ProgrammeCompletions()
    ) -> FertilityKitContext {
        let resolved = state
            ?? day.map { ProgrammeState(startedOn: today.minusDays($0 - 1)) }
            ?? startsIn.map { ProgrammeState(startedOn: today.plusDays($0)) }
            ?? .notStarted
        let calendar = Calendar.autoupdatingCurrent
        let input = ProgrammePlanInput(
            state: resolved, today: today, completions: completions, logsByDate: logs,
            phReadingDates: phReadings.map { CalendarDate.today(calendar, now: $0.recordedAt) },
            lhResultDates: lhResults.map { CalendarDate.today(calendar, now: $0.recordedAt) },
            periods: periods, cycleSettings: cycleSettings, quizAnswers: quizAnswers, consentActive: consent,
            scanFeaturesAvailable: scan, phLoggingAvailable: true)
        return FertilityKitContext(
            isHosted: true, today: today, scanAvailable: scan, cycleHistoryAvailable: cycleHistory, hasAccess: access,
            planInput: input, cycles: cycles, refusedPeriodStarts: refusedPeriodStarts, phReadings: phReadings,
            lhResults: scan ? lhResults : [], navigation: navigation)
    }

    /// The context `FertilityKitHost` would build from this container on `today`: the same
    /// mapping, field for field, for a test that goes through the real repositories.
    static func context(from container: AppContainer, today: CalendarDate, scan: Bool = true,
                        navigation: FertilityKitNavigation = FertilityKitNavigation()) -> FertilityKitContext {
        let source = ProgrammePlanSource(
            programme: container.programme, dailyLog: container.dailyLog, ph: container.ph, lh: container.lh,
            periods: container.periods, cycle: container.cycle, prefs: container.prefs, consent: container.consent,
            scanFeaturesAvailable: scan)
        return FertilityKitContext(
            isHosted: container.fertilityKit, today: today, scanAvailable: scan,
            cycleHistoryAvailable: container.cycleHistory,
            hasAccess: container.fertilityKit && container.kitAccess.hasAccess,
            planInput: source.input(today: today), cycles: container.periods.cycles,
            refusedPeriodStarts: Set(container.periods.refusedStarts), phReadings: container.ph.readings,
            lhResults: scan ? container.lh.results : [], navigation: navigation)
    }

    /// The six facts of the base UI-test seed (`AppContainer.uiTestSeeded()`, from "uiTestNoCycle"
    /// down to the LH results: lines 304 to 329), in calendar-date arithmetic from `anchor`:
    /// cycle settings with the last period 8 days before; 750 ml of water on the day; a log the
    /// day before and one 3 days before; pH readings 5 days before, 2 days before and on the day;
    /// ovulation test results 2 days and 1 day before.
    static func baseSeed(on container: AppContainer, anchor: CalendarDate) {
        let calendar = Calendar.autoupdatingCurrent
        func noon(_ daysBefore: Int) -> Date { anchor.minusDays(daysBefore).toDate(calendar: calendar) }
        container.cycle.upsert(CycleSettings(lastPeriodDate: anchor.minusDays(8), cycleLength: 28, periodLength: 5))
        container.dailyLog.setWater(750, on: anchor)
        container.dailyLog.upsert(
            DailyLog(mood: .good, energy: .normal, symptoms: ["Fatigue", "Cramps"], sleepMinutes: 445,
                     supplements: ["Folate", "Vitamin D"], waterMl: 1_800),
            on: anchor.minusDays(1))
        container.dailyLog.upsert(
            DailyLog(mood: .great, energy: .high, symptoms: ["Bloating"], sleepMinutes: 480,
                     supplements: ["Omega-3"], waterMl: 2_100),
            on: anchor.minusDays(3))
        container.ph.create(PhReading(phValue: 6.3, recordedAt: noon(5)))
        container.ph.create(PhReading(phValue: 6.7, recordedAt: noon(2)))
        container.ph.create(PhReading(phValue: 6.9, recordedAt: noon(0)))
        for (daysBefore, classification) in [(2, LhClassification.low), (1, .positive)] {
            let at = noon(daysBefore)
            container.lh.create(LhResult(
                recordedAt: at, cycleDay: LhCycleDay.snapshot(settings: container.cycle.settings, at: at, calendar: calendar),
                classification: classification))
        }
    }
}
