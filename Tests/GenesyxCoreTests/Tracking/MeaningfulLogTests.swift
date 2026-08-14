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
        XCTAssertTrue(DailyLog(foodGroups: ["vegetables"]).isMeaningfulLog)
    }

    func testAnUntouchedDayDoesNotCount() {
        XCTAssertFalse(DailyLog().isMeaningfulLog)
        XCTAssertFalse(DailyLog(notes: "", waterMl: 0).isMeaningfulLog)
    }

    /// Sleep is `Int?`, and the optionality already carries "she never opened the sheet" — so a
    /// stored `0` is not an empty value, it is a night she went to the picker, span it to 0h 0m and
    /// tapped Done. `waterMl` is non-optional and `notes` is empty-by-content, so neither can draw
    /// that distinction; they stay zero-means-untouched above.
    ///
    /// This was the last divergence left in the predicate. `TrackingEngine` read `> 0` while
    /// `StreakEngine`, *both* Android predicates and this suite's own vectors changelog ("sleep
    /// meaningful when != null", since v2) all read `!= nil` — so the same 0h night counted toward
    /// her milestones and not toward her Consistency streak, on the same screen-full of app.
    /// Settled 2026-08-13 toward the three, which is also the only direction that can lengthen a
    /// streak rather than take one back from someone already holding it.
    func testAnAllNighterCountsOnBothPredicates() {
        XCTAssertTrue(DailyLog(sleepMinutes: 0).isMeaningfulLog)
        XCTAssertTrue(DailyLog(sleepMinutes: 0).hasAnyEntry)
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

    /// Food groups were held outside this contract until Android could see them: counting a meal-only
    /// day on iOS alone would have given the two clients different streaks for identical rows. H4
    /// paid that debt — Android now reads and persists `food_groups` and applies the same term — so
    /// a day she only ticked her meals on extends her streak on either phone.
    ///
    /// Both predicates are asserted because the app has two engines and only widening one would put
    /// the divergence back, one layer down.
    func testFoodGroupsCountTowardTheStreak() {
        XCTAssertTrue(DailyLog(foodGroups: ["vegetables", "protein"]).isMeaningfulLog)
        XCTAssertTrue(DailyLog(foodGroups: ["vegetables"]).hasAnyEntry)
    }

    func testFoodGroupsAlongsideAnotherFieldStillCount() {
        XCTAssertTrue(DailyLog(waterMl: 250, foodGroups: ["fruit"]).isMeaningfulLog)
        XCTAssertTrue(DailyLog(mood: .good, foodGroups: ["fruit"]).hasAnyEntry)
    }

    /// Every term of the contract, on both predicates, one field at a time.
    ///
    /// Table-driven because the tests above only cover the terms that were argued about, and it is
    /// the unargued ones that go missing. Falsification found the hole: `symptoms` could be deleted
    /// from `hasAnyEntry` and all 240 domain tests stayed green — so a day whose only entry was how
    /// she felt would have quietly stopped counting on iOS while Android went on counting it, which
    /// is precisely the divergence this file exists to prevent.
    func testEveryFieldInTheContractMakesADayCountOnBothPredicates() {
        let logs: [(String, DailyLog)] = [
            ("water", DailyLog(waterMl: 250)),
            ("mood", DailyLog(mood: .good)),
            ("energy", DailyLog(energy: .high)),
            ("symptoms", DailyLog(symptoms: ["cramps"])),
            ("sleep", DailyLog(sleepMinutes: 0)),
            ("supplements", DailyLog(supplements: ["folate"])),
            ("notes", DailyLog(notes: "felt good today")),
            ("food groups", DailyLog(foodGroups: ["vegetables"])),
        ]

        for (field, log) in logs {
            XCTAssertTrue(log.isMeaningfulLog, "\(field) alone should make the day count")
            XCTAssertTrue(log.hasAnyEntry, "\(field) alone should make the day count")
        }
    }
}
