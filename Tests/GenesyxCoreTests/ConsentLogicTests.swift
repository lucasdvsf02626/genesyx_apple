import XCTest
@testable import GenesyxCore

/// Pins Article 9 consent state resolution: latest-event-wins, version-exact matching, the
/// withdrawn-wins tie-break, and the copy guard.
final class ConsentLogicTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 86_400
    private let current = ConsentPolicy.currentVersion

    private func event(
        _ action: ConsentAction,
        _ daysAgo: Double,
        version: String? = nil,
        id: String = UUID().uuidString
    ) -> ConsentEvent {
        ConsentEvent(
            id: id,
            version: version ?? ConsentPolicy.currentVersion,
            action: action,
            occurredAt: now.addingTimeInterval(-daysAgo * day)
        )
    }

    // ── Never asked ──

    func testNoEventsIsNotConsent() {
        XCTAssertNil(ConsentLogic.latest([]))
        XCTAssertFalse(ConsentLogic.isActive([]), "silence is not consent — she must be asked")
    }

    // ── Latest event decides ──

    func testAGrantOnTheCurrentVersionIsActive() {
        XCTAssertTrue(ConsentLogic.isActive([event(.granted, 1)]))
    }

    func testAWithdrawalAfterAGrantStopsProcessing() {
        let events = [event(.granted, 5), event(.withdrawn, 1)]
        XCTAssertEqual(ConsentLogic.latest(events)?.action, .withdrawn)
        XCTAssertFalse(ConsentLogic.isActive(events))
    }

    func testSheCanChangeHerMindBackAgain() {
        let events = [event(.granted, 9), event(.withdrawn, 5), event(.granted, 1)]
        XCTAssertTrue(ConsentLogic.isActive(events), "re-granting after a withdrawal restores consent")
    }

    func testOrderInTheArrayDoesNotMatterOnlyTime() {
        let shuffled = [event(.granted, 1), event(.withdrawn, 5), event(.granted, 9)]
        XCTAssertTrue(ConsentLogic.isActive(shuffled), "resolution is by timestamp, not array order")
    }

    // ── Version is matched exactly ──

    func testAGrantAgainstOlderWordingIsNotConsentToTheNewWording() {
        let events = [event(.granted, 1, version: "2026-01-01.v0")]
        XCTAssertFalse(
            ConsentLogic.isActive(events),
            "the wording changed, so she has not agreed to what is in force now — ask again"
        )
    }

    func testAnUnrecognisedVersionFailsClosed() {
        let events = [event(.granted, 1, version: "who-knows")]
        XCTAssertFalse(ConsentLogic.isActive(events), "unknown version is corrupt or a downgrade — re-ask")
    }

    func testWithdrawalStopsProcessingWhateverVersionItNames() {
        let events = [event(.granted, 5), event(.withdrawn, 1, version: "2026-01-01.v0")]
        XCTAssertFalse(ConsentLogic.isActive(events), "a withdrawal is not version-scoped")
    }

    // ── Tie-break ──

    func testASimultaneousGrantAndWithdrawalResolvesToWithdrawn() {
        let events = [event(.granted, 1, id: "aaa"), event(.withdrawn, 1, id: "zzz")]
        XCTAssertEqual(
            ConsentLogic.latest(events)?.action, .withdrawn,
            "two devices syncing in the same second must not coin-flip in favour of keeping her data"
        )
        XCTAssertFalse(ConsentLogic.isActive(events))
    }

    func testTheTieBreakIgnoresIdOrdering() {
        // Reversed ids relative to the test above: the outcome must not depend on them.
        let events = [event(.granted, 1, id: "zzz"), event(.withdrawn, 1, id: "aaa")]
        XCTAssertEqual(ConsentLogic.latest(events)?.action, .withdrawn)
    }

    func testIdBreaksTiesBetweenTwoIdenticalActions() {
        let events = [event(.granted, 1, id: "aaa"), event(.granted, 1, id: "zzz")]
        XCTAssertEqual(ConsentLogic.latest(events)?.id, "zzz", "stable, so the resolved state does not flicker")
    }

    // ── When to put the question in front of her ──

    func testAUserWhoWasNeverAskedIsAsked() {
        XCTAssertTrue(
            ConsentLogic.needsAsking([]),
            "everyone upgrading from a build that never asked has an empty trail, and an empty "
                + "trail is not consent — they must be asked, not grandfathered"
        )
    }

    func testSheIsNotAskedAgainOnceSheHasAgreedToTheCurrentWording() {
        XCTAssertFalse(ConsentLogic.needsAsking([event(.granted, 1)]))
    }

    func testAGrantAgainstSupersededWordingIsAskedAgain() {
        XCTAssertTrue(ConsentLogic.needsAsking([event(.granted, 30, version: "2026-01-01.v0")]))
    }

    func testAWithdrawalIsNotRePosedEveryLaunch() {
        let events = [event(.granted, 5), event(.withdrawn, 1)]
        XCTAssertFalse(ConsentLogic.isActive(events))
        XCTAssertFalse(
            ConsentLogic.needsAsking(events),
            "she answered; nagging is how a refusal is worn down, and Article 7(4) is about "
                + "consent being freely given. Profile is where she changes her mind."
        )
    }

    func testAWithdrawalAgainstOldWordingIsStillNotRePosed() {
        XCTAssertFalse(ConsentLogic.needsAsking([event(.withdrawn, 1, version: "2026-01-01.v0")]))
    }

    // ── Copy guard ──

    func testConsentCopyNamesTheControllerTheDataAndTheWithdrawalRoute() {
        XCTAssertTrue(ConsentPolicy.body.contains("Genesyx"), "informed consent has to name the controller")
        // v2 stopped using the words "health data" as a summary and lists the categories instead,
        // which is the stronger form of the same duty: "specific" and "informed" in Article 9(2)(a)
        // means she is told what is collected, not handed a label that could mean anything. So each
        // category is pinned by name, and the sensitivity is still stated.
        for category in ["cycle", "vaginal pH", "symptoms and mood", "sexual activity"] {
            XCTAssertTrue(ConsentPolicy.body.contains(category),
                          "the consent body must name '\(category)' — it is collected")
        }
        XCTAssertTrue(ConsentPolicy.body.lowercased().contains("especially sensitive"),
                      "she has to be told the law treats this differently, not just what it is")
        XCTAssertTrue(
            ConsentPolicy.withdrawal.contains("Profile"),
            "Article 7(3) — she must be told where to withdraw before she agrees"
        )
        XCTAssertTrue(
            ConsentPolicy.purpose.lowercased().contains("do not sell"),
            "purpose limitation is part of what makes the consent informed"
        )
    }

    func testConsentCopyCarriesNoBannedPhrases() {
        let banned = [
            "bv", "thrush", "infection", "candida", "vaginosis",
            "boy or girl", "sex selection", "alkaline diet", "balance your ph",
            "sway the sex", "choose the sex", "gender sway", "guaranteed",
        ]
        for surface in ConsentPolicy.allSurfaces {
            let lowered = surface.lowercased()
            for phrase in banned {
                XCTAssertFalse(lowered.contains(phrase), "banned phrase '\(phrase)' in consent copy: \(surface)")
            }
        }
    }

    func testEverySurfaceIsRegisteredForScanning() {
        XCTAssertEqual(ConsentPolicy.allSurfaces.count, 13, "a new string was added without registering it for the guard")
        XCTAssertFalse(ConsentPolicy.allSurfaces.contains { $0.isEmpty })
    }

    /// Not a style check. `ConsentLogic.isActive` compares the stored version to this string exactly,
    /// so changing the wording without bumping it keeps relying on consent nobody gave for it. This
    /// fails on a copy edit to force that decision into the open.
    func testVersionIsPinnedSoCopyChangesCannotShipSilently() {
        XCTAssertEqual(ConsentPolicy.currentVersion, "2026-08-18.v2")
        XCTAssertEqual(
            ConsentPolicy.body,
            "Genesyx records information about your cycle, your vaginal pH readings, your daily symptoms and mood, and — if you choose to log it — your sexual activity. UK data protection law treats all of this as especially sensitive, so we need your clear permission before collecting any of it."
        )
        // v2 names sexual activity, so the tick has to name it too: agreeing to "my health data" is
        // not explicit consent to intimate data under Article 9(2)(a).
        XCTAssertEqual(
            ConsentPolicy.agreeLabel,
            "I agree to Genesyx collecting the health and intimate data described above"
        )
    }
}
