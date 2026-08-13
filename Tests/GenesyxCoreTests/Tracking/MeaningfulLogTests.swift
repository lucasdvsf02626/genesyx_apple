import XCTest
@testable import GenesyxCore

/// What counts as "she logged today" — the predicate behind every streak, the weekly summary, and
/// the notification system's decision to go quiet. It is a cross-platform contract (the same rule
/// runs in the Android `TrackingEngine`), so the interesting assertions here are about what it
/// refuses to count, not what it counts.
final class MeaningfulLogTests: XCTestCase {

    func testEachFieldOnItsOwnMakesADayCount() {
        XCTAssertTrue(DailyLog(mood: .good).isMeaningfulLog)
        XCTAssertTrue(DailyLog(energy: .low).isMeaningfulLog)
        XCTAssertTrue(DailyLog(symptoms: ["Cramps"]).isMeaningfulLog)
        XCTAssertTrue(DailyLog(sleepMinutes: 420).isMeaningfulLog)
        XCTAssertTrue(DailyLog(supplements: ["Iron"]).isMeaningfulLog)
        XCTAssertTrue(DailyLog(notes: "ok").isMeaningfulLog)
        XCTAssertTrue(DailyLog(waterMl: 250).isMeaningfulLog)
    }

    func testAnUntouchedDayDoesNotCount() {
        XCTAssertFalse(DailyLog().isMeaningfulLog)
        XCTAssertFalse(DailyLog(sleepMinutes: 0, notes: "", waterMl: 0).isMeaningfulLog)
    }

    /// ⚠️ Contract guard, not a statement of intent. Recording sex plainly *is* a meaningful log,
    /// and one day it should count — but the moment it counts here and not in the Android
    /// `TrackingEngine`, the two clients report different streaks for identical data and nothing
    /// anywhere reports the divergence. Flipping this needs `tracking_test_vectors.json` and the
    /// Android rule to move in the same commit.
    func testStreakContractIgnoresSexualActivity() {
        XCTAssertFalse(DailyLog(sexualActivity: true).isMeaningfulLog,
                       "coordinate with Android and the shared vectors before changing this")
    }

    /// Logged alongside anything else, the day counts on that other field's merit — so the guard
    /// above suppresses a day, never a streak she had already earned.
    func testItNeverSuppressesADayThatCountsForAnotherReason() {
        XCTAssertTrue(DailyLog(waterMl: 250, sexualActivity: true).isMeaningfulLog)
    }

    /// The streak engine's own predicate is the same contract and carries the same exclusion —
    /// widening one and not the other would be the divergence arriving by the side door.
    func testTheStreakEnginesPredicateExcludesItToo() {
        XCTAssertFalse(DailyLog(sexualActivity: true).hasAnyEntry,
                       "coordinate with Android and the shared vectors before changing this")
        XCTAssertTrue(DailyLog(mood: .good, sexualActivity: true).hasAnyEntry)
    }

    /// ⚠️ The same contract guard, for the same reason, over the food groups added with meal
    /// logging. Ticking off what she ate plainly *is* a meaningful log — and here that costs
    /// something visible, because a day she logs only her meals will not extend her streak. That is
    /// the price of the two clients agreeing, and it is paid until Android carries `food_groups`
    /// and the shared vectors move with it.
    ///
    /// The notification layer already folds food groups in separately
    /// (`NotificationService.snapshot`), so she is not nudged to log on a day she logged. That is
    /// safe precisely because notifications are iOS-only and mirror nothing.
    func testStreakContractIgnoresFoodGroups() {
        XCTAssertFalse(DailyLog(foodGroups: ["vegetables", "protein"]).isMeaningfulLog,
                       "coordinate with Android and the shared vectors before changing this")
        XCTAssertFalse(DailyLog(foodGroups: ["vegetables"]).hasAnyEntry,
                       "coordinate with Android and the shared vectors before changing this")
    }

    func testFoodGroupsNeverSuppressADayThatCountsForAnotherReason() {
        XCTAssertTrue(DailyLog(waterMl: 250, foodGroups: ["fruit"]).isMeaningfulLog)
        XCTAssertTrue(DailyLog(mood: .good, foodGroups: ["fruit"]).hasAnyEntry)
    }
}
