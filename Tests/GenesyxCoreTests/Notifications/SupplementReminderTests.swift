import XCTest
@testable import GenesyxCore

/// Supplement reminders are alarms she set, not nudges the app invented, so they sit outside the
/// planner's budget entirely. What is left to get right is which ones exist, and what they say.
final class SupplementReminderTests: XCTestCase {

    private let magnesium = CustomSupplement(id: "mag", name: "Magnesium", dose: "200 mg", timeOfDay: .evening)
    private let iron = CustomSupplement(id: "iron", name: "Iron", dose: "")

    // MARK: - Which reminders exist

    /// Silence is the default. A plan of six supplements must not mean six alarms she never asked
    /// for — that is how an app gets muted entirely.
    func testASupplementWithNoHourSetGetsNoReminder() {
        XCTAssertTrue(SupplementReminder.all(customs: [magnesium, iron], hours: [:]).isEmpty)
    }

    func testOnlyTheSupplementsSheSetATimeForAreReminded() {
        let reminders = SupplementReminder.all(customs: [magnesium, iron], hours: ["mag": 8])

        XCTAssertEqual(reminders.map(\.id), ["mag"])
        XCTAssertEqual(reminders.first?.hour, 8)
    }

    /// The fixed Genesyx plan has no record of its own, so it is keyed by initial. Excluding it
    /// would mean the four supplements the app actually recommends were the only ones she couldn't
    /// be reminded about.
    func testTheGenesyxEssentialsCanBeRemindedToo() {
        let key = SupplementReminder.essentialKey(initial: "F")
        let reminders = SupplementReminder.all(customs: [], hours: [key: 9])

        XCTAssertEqual(reminders.count, 1)
        XCTAssertTrue(reminders[0].name.hasPrefix("Folate"))
    }

    /// A supplement she has deleted still leaves its hour behind in preferences. It must not
    /// resurrect as an alarm for something that no longer exists.
    func testAnHourLeftBehindByADeletedSupplementRemindsAboutNothing() {
        XCTAssertTrue(SupplementReminder.all(customs: [], hours: ["deleted-id": 8]).isEmpty)
    }

    /// Stored preferences are just JSON on disk; a corrupt hour must not reach a calendar trigger.
    func testAnHourOutsideTheDayIsIgnored() {
        XCTAssertTrue(SupplementReminder.all(customs: [magnesium], hours: ["mag": 24]).isEmpty)
        XCTAssertTrue(SupplementReminder.all(customs: [magnesium], hours: ["mag": -1]).isEmpty)
        XCTAssertEqual(SupplementReminder.all(customs: [magnesium], hours: ["mag": 0]).count, 1)
        XCTAssertEqual(SupplementReminder.all(customs: [magnesium], hours: ["mag": 23]).count, 1)
    }

    /// The scheduled set is compared against a remembered one to decide what to cancel, so the same
    /// input has to produce the same order every launch.
    func testTheOrderIsStableAcrossLaunches() {
        let hours = ["mag": 21, "iron": 8, SupplementReminder.essentialKey(initial: "D"): 8]
        let ids = SupplementReminder.all(customs: [magnesium, iron], hours: hours).map(\.id)

        XCTAssertEqual(ids, ["essential.D", "iron", "mag"])
    }

    // MARK: - What it says

    func testTheDoseIsCarriedWhenSheGaveOne() {
        let reminder = SupplementReminder.all(customs: [magnesium], hours: ["mag": 8])[0]

        XCTAssertEqual(reminder.title, "Time for Magnesium")
        XCTAssertTrue(reminder.body.contains("200 mg"))
    }

    /// Dose is optional free text, so the body has to read properly without one.
    func testTheBodyStillReadsWhenSheGaveNoDose() {
        let reminder = SupplementReminder.all(customs: [iron], hours: ["iron": 8])[0]

        XCTAssertEqual(reminder.body, "From your supplement plan.")
        XCTAssertFalse(reminder.body.hasPrefix("."))
    }

    /// The safety scans walk `allPossibleCopy`, so it has to be the copy that actually ships.
    ///
    /// It once held three invented supplements, which meant the banned-phrase scan cleared a
    /// "Magnesium" the app never sends and never read "Time for Folate (400–800 mcg)", which is
    /// what genuinely reaches her lock screen. A scan pointed at fixtures fails nobody, so this
    /// pins the coupling rather than the copy: every essential in the shipping plan must appear.
    func testTheSafetyScanWalksTheSupplementCopyThatShips() {
        let copy = SupplementReminder.allPossibleCopy

        for essential in NutritionContent.supplementPlan {
            XCTAssertTrue(copy.contains("Time for \(essential.name)"),
                          "\(essential.name) ships but the scan never reads it")
        }
    }
}
