// WaterChallenge.swift
// The seven-day hydration challenge: seven consecutive days at or above the water goal.
//
// Deliberately STATELESS. There is no start date, no "attempt" record, nothing persisted and
// nothing pushed — the whole thing is recomputed from the water she has already logged. That is
// what makes it safe: a challenge with its own stored progress is a second copy of the truth, and
// the app has just spent a release fixing what happens when a second copy of the truth falls out of
// step with the first. Reinstall the app, sign in on a new phone, restore from a backup — the
// challenge lands wherever her logs say it should, because it never knew anything else.
//
// It also repeats for free: an eighth consecutive day extends the run rather than starting a
// bookkeeping problem, and a missed day simply puts the count back to zero with no penalty state.

import Foundation

public struct WaterChallengeState: Equatable {

    /// Days at or above goal, counted toward this run — capped at `target`.
    public let daysDone: Int
    /// Seven. Exposed so the UI's dot row and the copy can't disagree about the length.
    public let target: Int
    public let isComplete: Bool
    public let title: String
    /// e.g. "3 of 7 days".
    public let progressLabel: String
    public let detail: String

    public init(
        daysDone: Int,
        target: Int,
        isComplete: Bool,
        title: String,
        progressLabel: String,
        detail: String
    ) {
        self.daysDone = daysDone
        self.target = target
        self.isComplete = isComplete
        self.title = title
        self.progressLabel = progressLabel
        self.detail = detail
    }
}

public enum WaterChallenge {

    public static let target = 7
    public static let title = "7-day hydration challenge"

    /// The challenge as her logs currently describe it.
    ///
    /// Uses the same morning grace as every other streak in the app (`TrackingEngine.streak`): a
    /// run that reached yesterday still reads at full length this morning, before she has had a
    /// chance to drink anything. Without that, the card would reset itself overnight and ask her to
    /// start again every single day.
    public static func state<Log: TrackingLoggable>(
        logsByDate: [CalendarDate: Log],
        goalMl: Int = TrackingEngine.defaultWaterGoalMl,
        today: CalendarDate = .today()
    ) -> WaterChallengeState {
        let onGoal = Set(logsByDate.filter { $0.value.waterMl >= goalMl }.keys)
        let run = TrackingEngine.streak(days: onGoal, today: today)
        let done = min(run, target)

        return WaterChallengeState(
            daysDone: done,
            target: target,
            isComplete: run >= target,
            title: title,
            progressLabel: "\(done) of \(target) days",
            detail: detail(run: run, goalMl: goalMl))
    }

    /// No scolding at zero: a run that has just ended and a run that never started read the same,
    /// because the difference is not something she needs to be reminded of.
    static func detail(run: Int, goalMl: Int) -> String {
        let litres = String(format: "%.1fL", Double(goalMl) / 1000)
        switch run {
        case 0:
            return "Reach \(litres) today and day one is done."
        case target - 1:
            return "One more day at \(litres) to finish."
        case ..<target:
            return "\(target - run) more days at \(litres) to finish."
        case target:
            return "Seven days at your goal — challenge complete."
        default:
            return "Challenge complete, and \(run) days running."
        }
    }

    /// Every line this type can produce, for the banned-phrase and no-guilt scans.
    public static func allStrings() -> [String] {
        [title] + (0...(target + 3)).map { detail(run: $0, goalMl: TrackingEngine.defaultWaterGoalMl) }
            + (0...target).map { "\($0) of \(target) days" }
    }
}
