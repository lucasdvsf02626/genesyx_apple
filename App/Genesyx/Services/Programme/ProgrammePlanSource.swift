import Foundation
import GenesyxCore

/// Reads the real trackers into a `ProgrammePlanInput`. Mapping only: every rule is in
/// `ProgrammePlanService` and the core, and nothing the programme shows is kept anywhere but in
/// the repositories named here.
///
/// Each list is the one its own screen shows. `PhRepository.readings` is already the vaginal,
/// non-deleted set, `LhRepository.results` and `PeriodRepository.periods` hide their tombstones.
@MainActor
struct ProgrammePlanSource {
    let programme: ProgrammeRepository
    let dailyLog: DailyLogRepository
    let ph: PhRepository
    let lh: LhRepository
    let periods: PeriodRepository
    let cycle: CycleRepository
    let prefs: PreferencesRepository
    let consent: ConsentRepository
    /// Supplied by the caller. The feature flag is never read here.
    let scanFeaturesAvailable: Bool
    /// Decides which local day a reading or a result belongs to. It follows the phone, so a
    /// source that is built once and kept still reads in the time zone she is in now. A reading
    /// and a result are instants, unlike a daily log: after a time-zone change one taken near
    /// midnight can fall on the neighbouring day, as it does on every other screen.
    var calendar: Calendar = .autoupdatingCurrent

    func input(today: CalendarDate) -> ProgrammePlanInput {
        ProgrammePlanInput(
            state: programme.state,
            today: today,
            completions: programme.completions,
            logsByDate: dailyLog.logByDate,
            // There is no stored water goal: every screen uses this constant.
            waterGoalMl: TrackingEngine.defaultWaterGoalMl,
            // The app's convention for the local day of a recorded instant.
            phReadingDates: ph.readings.map { CalendarDate.today(calendar, now: $0.recordedAt) },
            lhResultDates: lh.results.map { CalendarDate.today(calendar, now: $0.recordedAt) },
            periods: periods.periods,
            cycleSettings: cycle.settings,
            quizAnswers: prefs.quizAnswers,
            consentActive: consent.isActive,
            scanFeaturesAvailable: scanFeaturesAvailable,
            // Manual pH entry exists in every build.
            phLoggingAvailable: true
        )
    }
}
