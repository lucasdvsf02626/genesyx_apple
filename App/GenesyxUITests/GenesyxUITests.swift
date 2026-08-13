import XCTest

/// UI regression coverage for the core surfaces, driven by the app's `-uiTestSeed` harness
/// (seeds realistic data + lands on the main tabs). Uses visible labels so tests stay stable.
final class GenesyxUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app seeded, starting on the given tab index
    /// (0=Home, 1=Track, 2=pH, 3=Nutrition, 4=Insights, 5=Learn, 6=Profile).
    private func launchSeeded(tab: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
        app.launch()
        return app
    }

    /// Seeded, but with onboarding left un-run so the quiz can be driven.
    private func launchOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestOnboarding", "YES"]
        app.launch()
        return app
    }

    /// The quiz answers now go somewhere, which means the flow reaches out of itself for the first
    /// time: `OnboardingFlowView` takes a repository from the environment, and a missing
    /// `@EnvironmentObject` is a crash, not a warning. Nothing else in the suite launches
    /// onboarding at all, so without this the whole flow ships unexercised.
    ///
    /// Where it stops: nothing on screen shows her answers back to her, so this proves the path
    /// runs, not that the answers landed. That they landed is `RepositoryTests`' job.
    func testTheOnboardingQuizRunsEndToEnd() {
        let app = launchOnboarding()

        XCTAssertTrue(app.buttons["Start Your Personalised Quiz"].waitForExistence(timeout: 10),
                      "an un-onboarded launch should open on the splash")
        app.buttons["Start Your Personalised Quiz"].tap()
        app.buttons["Continue"].tap()               // intro

        // Answer every question with whichever option is first — the copy is T7's to rewrite, so
        // the test holds on to the shape of the quiz rather than its wording.
        for question in 1...5 {
            // The step counter, so the loop can't pass by quietly answering the same screen twice.
            XCTAssertTrue(app.staticTexts["\(question)/5"].waitForExistence(timeout: 5),
                          "should be on question \(question) of 5")
            let option = app.buttons.matching(identifier: "quiz.option").firstMatch
            XCTAssertTrue(option.exists, "question \(question) should offer options")
            option.tap()
            // One question answers into a "Did you know?" alert, which has to be dismissed before
            // the next one appears.
            if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
            if app.alerts.buttons["Continue"].exists { app.alerts.buttons["Continue"].tap() }
            if app.buttons["See My Summary"].exists { app.buttons["See My Summary"].tap() }
        }

        XCTAssertTrue(app.staticTexts["A thoughtful starting point"].waitForExistence(timeout: 10),
                      "answering every question should land on the readiness summary")
    }

    /// T7: the sex-preference question is the only one she may decline, and declining must not be
    /// dressed up as an answer. What this can prove on screen is that Skip appears on that question
    /// alone and carries her past it with nothing selected; that nothing is *stored* is
    /// `RepositoryTests`' job, for the same reason as the end-to-end test above.
    func testTheSexPreferenceQuestionIsTheOnlyOneSheCanSkip() {
        let app = launchOnboarding()

        XCTAssertTrue(app.buttons["Start Your Personalised Quiz"].waitForExistence(timeout: 10))
        app.buttons["Start Your Personalised Quiz"].tap()
        app.buttons["Continue"].tap()               // intro

        let skip = app.buttons["quiz.skip"]
        for question in 1...3 {
            XCTAssertTrue(app.staticTexts["\(question)/5"].waitForExistence(timeout: 5),
                          "should be on question \(question) of 5")
            XCTAssertFalse(skip.exists, "question \(question) is required and must offer no way past it")
            app.buttons.matching(identifier: "quiz.option").firstMatch.tap()
            if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
            if app.alerts.buttons["Continue"].exists { app.alerts.buttons["Continue"].tap() }
        }

        XCTAssertTrue(app.staticTexts["4/5"].waitForExistence(timeout: 5),
                      "should reach the sex-preference question")
        XCTAssertTrue(skip.exists, "the sex-preference question must be skippable")
        XCTAssertFalse(app.buttons["Continue"].isEnabled,
                       "Continue still waits for a choice — Skip is the way past, not a disabled button")
        skip.tap()

        XCTAssertTrue(app.staticTexts["5/5"].waitForExistence(timeout: 5), "Skip should move her on")
        app.buttons.matching(identifier: "quiz.option").firstMatch.tap()
        app.buttons["See My Summary"].tap()
        XCTAssertTrue(app.staticTexts["A thoughtful starting point"].waitForExistence(timeout: 10),
                      "declining one question must not hold up the summary")
    }

    /// Drives the quiz from the splash to the readiness summary, for tests that need what follows it.
    private func advanceToReadinessSummary(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Start Your Personalised Quiz"].waitForExistence(timeout: 10))
        app.buttons["Start Your Personalised Quiz"].tap()
        app.buttons["Continue"].tap()               // intro
        for question in 1...5 {
            XCTAssertTrue(app.staticTexts["\(question)/5"].waitForExistence(timeout: 5))
            let option = app.buttons.matching(identifier: "quiz.option").firstMatch
            XCTAssertTrue(option.exists)
            option.tap()
            if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
            if app.alerts.buttons["Continue"].exists { app.alerts.buttons["Continue"].tap() }
            if app.buttons["See My Summary"].exists { app.buttons["See My Summary"].tap() }
        }
        XCTAssertTrue(app.staticTexts["A thoughtful starting point"].waitForExistence(timeout: 10))
    }

    /// The waiting-list screen used to promise "We'll send your free fertility nutrition guide to
    /// <email> shortly" — mail that no code ever sends. It must never make an unsendable promise
    /// again, and it must still reject a bad address before claiming anything.
    func testWaitlistMakesNoUnsendablePromise() {
        let app = launchOnboarding()
        advanceToReadinessSummary(app)

        app.buttons["Unlock My Free Guide"].tap()
        XCTAssertTrue(app.staticTexts["A gentle guide to fertility nutrition"].waitForExistence(timeout: 5),
                      "Unlock should open the waiting-list screen")

        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "inbox")).count, 0,
                       "the waiting-list screen must not claim it emails anything")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "we'll send")).count, 0,
                       "the 'we'll send your guide' promise must not come back")

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("not-an-email")
        app.buttons["Join the Waiting List"].tap()
        XCTAssertTrue(app.staticTexts["Please enter a valid email address."].waitForExistence(timeout: 5),
                      "a bad address is rejected before anything is claimed")
    }

    func testMainTabsPresent() {
        let app = launchSeeded()
        // Custom seven-icon bottom bar (all tabs visible, no "More" overflow).
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10), "Tab bar should appear on seeded launch")
        for label in ["Home", "Track", "pH", "Nutrition", "Insights", "Learn", "Profile"] {
            XCTAssertTrue(app.buttons[label].exists, "Missing tab: \(label)")
        }
    }

    /// The supplement card used to print a hardcoded "3 of 4 taken today" to every user, on a
    /// fresh install, forever. The seeded user logs water today but no supplements, so the only
    /// honest thing the card can say is that none are logged.
    func testSupplementCountReflectsTodaysLog() {
        let app = launchSeeded(tab: 3)   // Nutrition
        XCTAssertTrue(app.staticTexts["None logged yet today"].waitForExistence(timeout: 10),
                      "Supplement count must come from today's log, not a placeholder")
        XCTAssertFalse(app.staticTexts["3 of 4 taken today"].exists,
                       "The hardcoded supplement count must never come back")
    }

    /// Every supplement she can see is hers to be reminded about — the four Genesyx essentials
    /// included, since excluding them would mean the ones the app actually recommends were the only
    /// ones with no reminder. Reaching the sheet at all is half the point: it reads preferences out
    /// of the environment, and a sheet that doesn't inherit them crashes on open rather than
    /// failing a unit test.
    func testEachSupplementCanBeGivenItsOwnReminderTime() {
        let app = launchSeeded(tab: 3)   // Nutrition

        let review = app.buttons["Review Plan"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()

        let folate = app.buttons["supplementReminder.essential.F"]
        XCTAssertTrue(folate.waitForExistence(timeout: 5), "the Genesyx essentials need reminders too")
        XCTAssertTrue(folate.label.hasPrefix("Set a reminder"), "no supplement is reminded about until she says so")

        folate.tap()

        // The menu offers "No reminder" alongside the hours — off stays a first-class choice, not
        // something she has to back out of the menu to keep.
        XCTAssertTrue(app.buttons["No reminder"].waitForExistence(timeout: 5),
                      "turning a reminder back off must be as easy as setting one")
    }

    /// The most private thing she can record, so this walks the whole path rather than trusting the
    /// model test: log it, save, reopen, and find it still there. A field that saves but doesn't
    /// repopulate reads as the app having quietly discarded it — worse here than anywhere else.
    func testSexualActivityIsLoggedPrivatelyAndComesBack() {
        let app = launchSeeded(tab: 0)

        app.buttons["Log today"].tap()
        let chip = app.buttons["log.sexualActivity"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Log Today should offer the intimacy chip")
        XCTAssertEqual(chip.label, "Sex, not logged", "nothing is recorded until she says so")

        // The promise made on screen is a real one: partner linking exchanges display names, and
        // `daily_logs` is owner-only under RLS.
        XCTAssertTrue(app.staticTexts["Private to you. A linked partner sees your name — never your logs."].exists,
                      "she should be told what becomes of this before she taps it")

        chip.tap()
        XCTAssertEqual(chip.label, "Sex, logged")
        app.buttons["Save log"].tap()

        app.buttons["Log today"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Sex, logged", "it must survive the save it just went through")
    }

    /// The month grid spends its backgrounds on the four predicted cycle phases, so what she
    /// actually recorded arrives as dots. Dots are invisible to a screen reader, which is why the
    /// cell carries an explicit label — and why asserting on that label is the honest way to prove
    /// the marker rendered. Drives the real path rather than reading a fixture: the seed plants a pH
    /// reading today but no intimacy, so this logs it and then goes looking for it.
    func testCalendarMarksWhatSheRecordedOnTheDay() {
        let app = launchSeeded(tab: 0)

        app.buttons["Log today"].tap()
        let chip = app.buttons["log.sexualActivity"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        app.buttons["Save log"].tap()

        app.buttons.matching(identifier: "Track").firstMatch.tap()

        // Today carries both markers: the seeded pH reading and the intimacy just logged.
        let todayCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "today", "intimacy logged")
        ).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 10), "the day she logged it should be marked")
        XCTAssertTrue(todayCell.label.contains("pH logged"), "the seeded pH reading should be marked too")

        // A dot she cannot decode is decoration, so the key names all three.
        for label in ["pH test", "Symptoms / notes", "Intimacy"] {
            XCTAssertTrue(app.staticTexts[label].exists, "the legend should explain the \(label) dot")
        }

        // Opening the day must account for every dot on it — a marked day described as empty reads
        // as the app having lost what she entered.
        todayCell.tap()
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged:")
        ).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "the day sheet should summarise the day")
        XCTAssertTrue(summary.label.contains("intimacy"), "the sheet must not contradict the dot: \(summary.label)")
        XCTAssertTrue(summary.label.contains("pH test"), "the sheet must not contradict the dot: \(summary.label)")
    }

    /// The other half of the rule: a day she left alone stays clean. Without this the marker test
    /// passes just as well against a grid that dots every cell. Counts rather than naming dates, so
    /// it does not start failing on the 3rd of a month when the seeded days fall behind the anchor.
    func testCalendarLeavesUntouchedDaysUnmarked() {
        let app = launchSeeded(tab: 1)   // Track

        // Every cell labels itself "<day number>, <phase>[, markers…]", which is what separates the
        // grid from the rest of the buttons on the screen.
        let cells = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+, .*"))
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 10), "the month grid should render")

        let marked = cells.allElementsBoundByIndex.filter { $0.label.contains("logged") }
        XCTAssertFalse(marked.isEmpty, "the seeded days should be marked")
        XCTAssertGreaterThanOrEqual(cells.count - marked.count, 20,
                                    "most of the month is untouched and must stay bare")
    }

    /// Cycle setup is skippable, and skipping it used to take the entire month grid away — no cells,
    /// so nothing to tap, so no way to record or review any day at all. The calendar is where logging
    /// happens; it cannot be gated on a period date she has not given us.
    func testTheCalendarWorksWithoutACycleSetUp() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestNoCycle", "YES", "-uiTestTab", "1"]
        app.launch()

        // No phase in the label now, so the cells are bare day numbers with markers appended.
        let cells = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+(,.*)?$"))
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 10), "the month grid should render anyway")
        XCTAssertGreaterThanOrEqual(cells.count, 28, "a full month of days, not a setup prompt")

        // The invitation to set the cycle up is still made — it just no longer costs her the grid.
        XCTAssertTrue(app.staticTexts["Add your cycle"].exists)
        // And nothing claims a phase it cannot know.
        XCTAssertFalse(app.staticTexts["Fertile window"].exists, "no cycle, no phase key")

        // A whole month back, so every cell is in the past whatever date the suite runs on.
        app.buttons["Previous month"].tap()
        guard let day = cells.allElementsBoundByIndex.first(where: { !$0.label.contains("logged") }) else {
            return XCTFail("needed one unlogged day to back-fill")
        }
        let dayNumber = String(day.label.prefix(while: { $0.isNumber }))
        day.tap()

        let add = app.buttons["Add a log"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "an empty day should still offer to take a log")
        add.tap()

        let chip = app.buttons["log.sexualActivity"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "the log sheet should open on the day she tapped")
        chip.tap()
        app.buttons["Save log"].tap()

        let marked = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "\(dayNumber), ", "intimacy logged")
        ).firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 10), "the day she logged should carry the marker")
    }

    /// The client's "entries don't stay on the right date". The store was never the problem — the log
    /// sheet was pinned to today, so a day she missed could not be filled in and a mistake could not
    /// be corrected. Steps back a whole month so every cell is in the past regardless of the date the
    /// suite runs on, and finishes by proving the entry landed *there* and not on today.
    func testAPastDayCanBeLoggedAndTheEntryStaysOnIt() {
        let app = launchSeeded(tab: 1)   // Track

        app.buttons["Previous month"].tap()

        let cells = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+, .*"))
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 10), "the month grid should render")
        guard let pastDay = cells.allElementsBoundByIndex.first(where: { !$0.label.contains("logged") }) else {
            return XCTFail("needed one unlogged day in the previous month to back-fill")
        }
        let pastDayNumber = String(pastDay.label.prefix(while: { $0.isNumber }))

        pastDay.tap()
        let edit = app.buttons["Add a log"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "an empty past day should offer to take a log")
        edit.tap()

        let chip = app.buttons["log.sexualActivity"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "the log sheet should open on the day she tapped")
        XCTAssertFalse(app.navigationBars["Log Today"].exists,
                       "a back-filled day must not present itself as today")
        chip.tap()
        app.buttons["Save log"].tap()

        // Back on the grid: the day she chose now carries the marker.
        let marked = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "\(pastDayNumber), ", "intimacy logged")
        ).firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 10),
                      "the entry belongs to the day she opened, not the day she typed it")

        // And today did not quietly receive it instead — the defect this test exists for.
        app.buttons["Next month"].tap()
        let todayCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "today")
        ).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 10))
        XCTAssertFalse(todayCell.label.contains("intimacy logged"),
                       "logging a past day must not write to today: \(todayCell.label)")
    }

    /// A day that has not happened has nothing to record, so the sheet stays read-only there.
    func testAFutureDayIsNotOfferedALog() {
        let app = launchSeeded(tab: 1)   // Track

        app.buttons["Next month"].tap()

        let cells = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+, .*"))
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 10), "the month grid should render")
        cells.element(boundBy: 14).tap()

        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5), "the day sheet should open")
        XCTAssertFalse(app.buttons["Add a log"].exists, "a future day must not invite a log")
        XCTAssertFalse(app.buttons["Edit this day"].exists, "nor offer to edit one")
    }

    func testLearnTabShowsArticles() {
        let app = launchSeeded(tab: 5)   // Learn
        XCTAssertTrue(app.staticTexts["Your first week with Genesyx"].waitForExistence(timeout: 10),
                      "Learn should show the featured article")
    }

    /// The Home card has to cross two boundaries the unit tests can't reach: it sets a slug on the
    /// shared router, switches tab, and relies on `LearnLandingView` — a view that is alive but
    /// hidden — to notice and push. A card that named an article but landed nowhere would still
    /// pass every test in `NotificationTests`.
    ///
    /// A seeded launch is a fresh install, so nothing is new: the headline is the library one.
    func testHomeLearnCardOpensTheArticleItNames() {
        let app = launchSeeded(tab: 0)

        let card = app.buttons["home.learnCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Home should offer a read")
        XCTAssertTrue(card.label.hasPrefix("A read for your week:"),
                      "nothing arrived in this build, so it must not claim to be new — got '\(card.label)'")
        card.tap()

        // "Related" only exists at the foot of an article, so reaching it proves the push landed
        // rather than merely switching tab.
        XCTAssertTrue(app.staticTexts["Related"].waitForExistence(timeout: 10),
                      "the card should open the article itself, not just the Learn tab")
    }

    /// Nothing has arrived in a fresh install, so the tab must be bare. A badge of 16 would be the
    /// library presenting itself as a backlog.
    func testLearnTabIsNotBadgedOnAFreshInstall() {
        let app = launchSeeded(tab: 0)
        let learn = app.buttons["Learn"]

        XCTAssertTrue(learn.waitForExistence(timeout: 10))
        XCTAssertEqual(learn.label, "Learn", "a first install has no new articles to announce")
    }

    /// Only the phase-change card and the focus foods read the phase. The supplement plan and the
    /// articles were gated on it too, so skipping cycle setup took the plan — and every
    /// per-supplement reminder, which has no other entry point — out of reach entirely.
    func testNutritionKeepsWhatDoesNotNeedACycle() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestNoCycle", "YES", "-uiTestTab", "3"]
        app.launch()

        XCTAssertTrue(app.buttons["Review Plan"].waitForExistence(timeout: 10),
                      "the supplement plan is the only route to per-supplement reminders")
        XCTAssertTrue(app.buttons["See all articles"].exists, "nutrition articles need no phase")

        // And nothing claims a phase it cannot know.
        XCTAssertFalse(app.staticTexts["Your focus foods this phase"].exists,
                       "focus foods are per-phase and must stay gated")
    }

    /// The third no-cycle surface, after Track and Nutrition. Skipping cycle setup used to collapse
    /// the whole dashboard to a single setup card — hydration, the pH nudge, this week's article and
    /// Log today all vanished, though none of them needs a phase. Only the phase and focus cards do.
    func testHomeKeepsWhatDoesNotNeedACycle() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestNoCycle", "YES", "-uiTestTab", "0"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.hydrationCard").firstMatch.waitForExistence(timeout: 10),
                      "hydration needs no cycle and must survive a skipped setup")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.phCard").firstMatch.exists,
                      "the pH nudge needs no cycle")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.learnCard").firstMatch.exists,
                      "this week's article needs no cycle")
        XCTAssertTrue(app.buttons["Log today"].exists, "logging needs no cycle")

        // The invitation to set the cycle up is still made — it just no longer costs her everything else.
        XCTAssertTrue(app.staticTexts["Welcome to Genesyx"].exists, "the setup card still invites her in")
    }

    // MARK: - The phase-change card

    /// Seeded launches wipe defaults, so every one of them is a first install — the card must stay
    /// away. This is the case that actually ships to a new user, and it is the one an over-eager
    /// `lastSeen == nil` check would get wrong by announcing a transition that never happened.
    func testNutritionShowsNoPhaseChangeCardOnAFreshInstall() {
        let app = launchSeeded(tab: 3)

        XCTAssertTrue(app.staticTexts["Your nutrition focus"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["nutrition.phaseChangeCard"].exists,
                       "she is mid-phase on a first install, not transitioning")
    }

    /// With a stale phase on the device the card is due, and tapping it must land on the article
    /// itself — the slug is a bare string, so a typo would push a route nothing can resolve and
    /// leave her on a blank screen.
    func testPhaseChangeCardOpensTheCycleEatingArticle() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "3", "-uiTestPhaseChange", "YES"]
        app.launch()

        let card = app.buttons["nutrition.phaseChangeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "a crossed phase should be announced")
        card.tap()

        // "Related" only exists at the foot of an article, so reaching it proves the push landed.
        XCTAssertTrue(app.staticTexts["Related"].waitForExistence(timeout: 10),
                      "the card should open 'Eating with your cycle', not just scroll")
    }

    /// Dismissing has to be as final as reading: the card records the phase either way, or the one
    /// she closed comes straight back and the × is decoration.
    func testDismissingThePhaseChangeCardKeepsItAway() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "3", "-uiTestPhaseChange", "YES"]
        app.launch()

        let card = app.buttons["nutrition.phaseChangeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["nutrition.phaseChangeDismiss"].tap()

        XCTAssertFalse(card.waitForExistence(timeout: 3), "dismissing should settle it")

        // Leave and come back — the phase is stored, not just held in view state.
        app.buttons["Home"].tap()
        app.buttons["Nutrition"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 3), "and it must not return on the next visit")
    }

    // MARK: - Streak milestone celebration

    /// The in-app half of a milestone, and the only half most users ever get: a banner needs
    /// notification permission, which a UI test cannot grant and which most people never do.
    ///
    /// That is precisely what this proves. The celebration used to be computed inside `replan()`,
    /// behind a gate requiring `authorizationStatus == .authorized` — so the woman who declined
    /// notifications logged for a week and the app said nothing at all. Running under a simulator
    /// with no permission is not a limitation of this test, it *is* the test.
    func testMilestoneIsCelebratedInTheAppWithoutNotificationPermission() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestMilestone", "YES", "-uiTestTab", "0"]
        app.launch()

        let celebration = app.buttons["milestone.dismiss"]
        XCTAssertTrue(celebration.waitForExistence(timeout: 10),
                      "a week of logging should be celebrated in the app, permission or not")

        // Both day7 and the first complete week are crossed by this seed, and only the larger is
        // shown — one good week is one moment, not two stacked modals.
        XCTAssertTrue(app.staticTexts["A full steady week"].exists,
                      "the biggest thing she did is what she should be congratulated for")
        XCTAssertFalse(app.staticTexts["One week strong"].exists,
                       "crossing two milestones at once must not queue two celebrations")

        celebration.tap()
        XCTAssertTrue(celebration.waitForNonExistence(timeout: 5), "Thanks should close it")
    }

    /// A celebration is a moment, not a badge: it happens once. The flag is written the moment the
    /// milestone is handled, so anything that recomputed the streak on each launch — the obvious
    /// way to build this — would greet her with the same modal every morning for the rest of the
    /// week. A cold relaunch is the only way to catch that.
    func testACelebratedMilestoneDoesNotReturnOnTheNextLaunch() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestMilestone", "YES", "-uiTestTab", "0"]
        app.launch()

        let celebration = app.buttons["milestone.dismiss"]
        XCTAssertTrue(celebration.waitForExistence(timeout: 10))
        celebration.tap()
        XCTAssertTrue(celebration.waitForNonExistence(timeout: 5))

        app.terminate()

        // Same store, so the same seven logged days and the same crossed milestone — the only thing
        // that should stop it re-firing is the flag the first launch wrote.
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-uiTestSeed", "YES", "-uiTestKeepStore", "YES", "-uiTestTab", "0"]
        relaunched.launch()

        XCTAssertTrue(relaunched.descendants(matching: .any)
                        .matching(identifier: "home.hydrationCard").firstMatch
                        .waitForExistence(timeout: 10),
                      "the app should come back up on Home")
        XCTAssertFalse(relaunched.buttons["milestone.dismiss"].exists,
                       "she has already been congratulated for this week")
    }

    // MARK: - Recipe cards

    /// The whole path a reader takes: see a card, open it, read the method, log what she cooked.
    ///
    /// Worth an end-to-end test because each half fails silently in a different way. The row is a
    /// horizontal scroller pulled back out of the page's own 20pt gutter with a negative pad, which
    /// compiles identically whether the first card lands on the gutter or off the screen edge. And
    /// the log button calls `logFoodGroups`, whose whole reason for existing — being additive, not a
    /// toggle — is invisible from the view: wire it to `toggleFoodGroup` per group instead and this
    /// screen looks exactly the same until it quietly *un*-ticks a group she logged by hand.
    ///
    /// Phase-agnostic on purpose. The seed puts her mid-follicular today, but a recipe exists for
    /// every phase and this test should not start failing on the day the seed date moves.
    func testARecipeCardOpensAndLogsWhatSheCooked() {
        let app = launchSeeded(tab: 3)

        XCTAssertTrue(app.staticTexts["Something to cook"].waitForExistence(timeout: 10),
                      "every phase ships recipes, so the section should be on the screen")

        let cards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'nutrition.recipe.'"))
        XCTAssertGreaterThan(cards.count, 0, "the recipe row rendered no reachable cards")

        let loggedChips = NSPredicate(format: "label ENDSWITH ', logged'")
        let loggedBefore = app.buttons.matching(loggedChips).count

        cards.element(boundBy: 0).tap()

        // Uppercased because both headings render through `Eyebrow`, which uppercases what it is
        // given — this asserts the string on the screen, not the one in `RecipeCopy`.
        XCTAssertTrue(app.staticTexts["YOU'LL NEED"].waitForExistence(timeout: 5),
                      "the sheet should list the ingredients")
        XCTAssertTrue(app.staticTexts["METHOD"].exists, "and the method to cook them")

        let logButton = app.buttons["recipe.logGroups"]
        XCTAssertTrue(logButton.exists, "she should be able to record that she cooked it")
        logButton.tap()

        // Confirms in place. Dismissing here would read as the sheet closing on her, and she may
        // well still be cooking from it.
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS 'Added to today'"),
                               evaluatedWith: logButton)], timeout: 5)

        app.buttons["Done"].tap()

        // And the write actually reached the day, not just the button's own state.
        XCTAssertTrue(app.staticTexts["Something to cook"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons.matching(loggedChips).count, loggedBefore,
                             "cooking a recipe should tick its food groups on the log above")
    }

    /// H4 gave food groups three readers outside Nutrition — Track's day summary, the My Logs card,
    /// and the Insights "Days with meals" tile — and shipped all three with no UI coverage between
    /// them. The domain suite proves the arithmetic; it cannot prove any of it reached a screen, and
    /// the test above stops at the Nutrition tab it was written for.
    ///
    /// Writes to *today* deliberately. Seeding a past day would make the Insights tile flaky: it
    /// counts within the current ISO week, so a Monday run would legitimately see zero.
    func testAMealLoggedTodayReachesTrackMyLogsAndInsights() {
        let app = launchSeeded(tab: 3)   // Nutrition

        XCTAssertTrue(app.staticTexts["Something to cook"].waitForExistence(timeout: 10))
        let cards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'nutrition.recipe.'"))
        XCTAssertGreaterThan(cards.count, 0, "the recipe row rendered no reachable cards")
        cards.element(boundBy: 0).tap()

        let logButton = app.buttons["recipe.logGroups"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        logButton.tap()
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS 'Added to today'"),
                               evaluatedWith: logButton)], timeout: 5)
        app.buttons["Done"].tap()

        // My Logs first: the seed logs 750 ml today, so today's card already exists and sorts to the
        // top of the history — the food-group row is the only thing this step adds to it.
        app.buttons.matching(identifier: "Insights").firstMatch.tap()
        let logsCard = app.staticTexts["My logs"]
        XCTAssertTrue(logsCard.waitForExistence(timeout: 10))
        logsCard.tap()
        XCTAssertTrue(app.navigationBars["Your logs"].waitForExistence(timeout: 5))
        // Uppercased: the row label renders through `Eyebrow`.
        XCTAssertTrue(app.staticTexts["FOOD GROUPS"].waitForExistence(timeout: 5),
                      "the day she cooked on should list what she ate")

        app.navigationBars["Your logs"].buttons.firstMatch.tap()

        // Then the weekly tile. Read by identifier because "Days logged" and "Supplements taken" sit
        // beside it and any of the three can read "N / 7".
        let mealDays = app.staticTexts["insights.foodGroupDays"]
        for _ in 0..<12 where !mealDays.exists { app.swipeUp() }
        XCTAssertTrue(mealDays.waitForExistence(timeout: 10),
                      "Insights should carry the days-with-meals tile")
        XCTAssertFalse(mealDays.label.hasPrefix("0"),
                       "a meal logged today should move the tile off zero, got \(mealDays.label)")
        XCTAssertTrue(app.staticTexts["DAYS WITH MEALS"].exists, "and the tile should say what it counts")

        // Finally the calendar day sheet, which summarises the day in prose.
        app.buttons.matching(identifier: "Track").firstMatch.tap()
        // ", today" and not "today": `cellLabel` comma-joins its parts, while Track's own "Log
        // today" button matches the bare word and sits below the fold.
        let todayCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", ", today")).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 10))
        todayCell.tap()
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged:")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "the day sheet should summarise today")
        XCTAssertTrue(summary.label.contains("food group"),
                      "the sheet must account for the meal she logged: \(summary.label)")
    }

    /// The day sheet reported "N food groups" before the log sheet could edit them, so "Edit this
    /// day" opened an editor with no control for the thing she had just been shown. This proves the
    /// control both records and clears — an editor that can only add is a logger, and she would have
    /// no way to undo a mis-tap.
    func testTheLogSheetCanRecordAndClearAMeal() {
        let app = launchSeeded(tab: 0)

        app.buttons["Log today"].tap()
        let veg = app.buttons["log.foodGroup.vegetables"]
        XCTAssertTrue(veg.waitForExistence(timeout: 10), "the log sheet should offer the food groups")
        XCTAssertEqual(veg.label, "Vegetables, not logged", "nothing is seeded on today")
        veg.tap()
        app.buttons["Save log"].tap()

        XCTAssertTrue(todaySummary(app).label.contains("1 food group"),
                      "the day she ticked it on should say so: \(todaySummary(app).label)")

        // Straight back in through "Edit this day", which is the affordance that had nowhere to send
        // her. Reopened, the chip must come back ticked — otherwise `populate` is not reading the
        // field and the next save silently wipes it.
        app.buttons["Edit this day"].tap()
        XCTAssertTrue(veg.waitForExistence(timeout: 10))
        XCTAssertEqual(veg.label, "Vegetables, logged", "the sheet should reopen on what she saved")
        veg.tap()
        app.buttons["Save log"].tap()

        XCTAssertFalse(todaySummary(app).label.contains("food group"),
                       "un-ticking must actually clear it: \(todaySummary(app).label)")
    }

    /// The regression guard for the risk the editor re-opens. Food groups are logged from *two*
    /// places now, and `save()` writes the whole field rather than carrying it through — so a stale
    /// `populate` would make saving an unrelated note here delete the meal she logged in Nutrition,
    /// with no error and no undo. This is the exact bug that was found and fixed on Android.
    ///
    /// Asserts both halves: "intimacy" proves the save really landed, "food group" proves it landed
    /// without taking the meal with it. Checking only the meal would pass against a save that never
    /// happened at all.
    func testSavingTheLogSheetKeepsAMealLoggedFromNutrition() {
        let app = launchSeeded(tab: 3)   // Nutrition

        XCTAssertTrue(app.staticTexts["Something to cook"].waitForExistence(timeout: 10))
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'nutrition.recipe.'")).element(boundBy: 0).tap()
        let logButton = app.buttons["recipe.logGroups"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        logButton.tap()
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS 'Added to today'"),
                               evaluatedWith: logButton)], timeout: 5)
        app.buttons["Done"].tap()

        // Now edit the same day from the log sheet, changing something else entirely.
        app.buttons.matching(identifier: "Home").firstMatch.tap()
        app.buttons["Log today"].tap()
        let intimacy = app.buttons["log.sexualActivity"]
        XCTAssertTrue(intimacy.waitForExistence(timeout: 10))
        intimacy.tap()
        app.buttons["Save log"].tap()

        let summary = todaySummary(app)
        XCTAssertTrue(summary.label.contains("intimacy"), "the save should have landed: \(summary.label)")
        XCTAssertTrue(summary.label.contains("food group"),
                      "saving the log sheet must not delete what she logged in Nutrition: \(summary.label)")
    }

    /// Opens today on the Track calendar and returns its "Logged: …" line. Matches on ", today"
    /// rather than "today" because `cellLabel` comma-joins its parts, while Track's own "Log today"
    /// button matches the bare word and sits below the fold.
    private func todaySummary(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "Track").firstMatch.tap()
        let todayCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", ", today")).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 10), "the calendar should mark today")
        todayCell.tap()
        let summary = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Logged:")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "the day sheet should summarise today")
        return summary
    }

    func testHomeShowsLogToday() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Log today"].waitForExistence(timeout: 10), "Home should show the Log today button")
    }

    /// Quick-add now lives in the Track hydration sheet (the Home card is a tap-through summary).
    /// Hydration defaults to the glasses unit (1 glass = 250 ml), so quick-add is +1/+2 glasses and
    /// the readout is in glasses. A single +1 glass adds exactly one (no double-fire), and −1 glass
    /// returns the total to where it started. Seed logs 750 ml today = 3 glasses; goal 2400 = 9.6.
    func testTrackHydrationQuickAddAddsExactlyAndReverses() {
        let app = launchSeeded(tab: 0)

        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hydration,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "Home should show the hydration summary")
        summary.tap()

        XCTAssertTrue(app.navigationBars["Hydration"].waitForExistence(timeout: 5), "Summary should open the Track hydration sheet")
        XCTAssertTrue(app.staticTexts["3 / 9.6 glasses"].waitForExistence(timeout: 5), "Sheet should reflect the seeded 750 ml as 3 glasses")

        app.buttons["Add 1 glass"].tap()
        XCTAssertTrue(app.staticTexts["4 / 9.6 glasses"].waitForExistence(timeout: 5), "One tap must add exactly one glass, not double-fire")

        app.buttons["Remove 1 glass"].tap()
        XCTAssertTrue(app.staticTexts["3 / 9.6 glasses"].waitForExistence(timeout: 5), "After +1 then −1 glass, the total must be unchanged")
    }

    /// Manual entry files an exact figure, and the whole capsule takes the tap.
    ///
    /// The size check is the point. `tap()` hits an element's centre, so it lands on the "Save"
    /// glyphs whether or not the capsule around them is live — a tap-only test passes against the
    /// bug this guards. Sizing the Button from outside its label (`.frame`/`.background` after
    /// `Button("Save")`) draws a capsule that is not part of the tap target, and every miss is
    /// swallowed by the background, which is what "the save button does nothing" was.
    func testTrackHydrationManualEntrySavesAndTakesTapsAcrossTheCapsule() {
        let app = launchSeeded(tab: 0)

        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hydration,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "Home should show the hydration summary")
        summary.tap()
        XCTAssertTrue(app.navigationBars["Hydration"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["3 / 9.6 glasses"].waitForExistence(timeout: 5), "Sheet should open on the seeded 750 ml")

        let field = app.textFields["hydrationManualMlField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The hydration sheet should offer manual ml entry")
        field.tap()
        // Prefilled with today's total, so clear it before typing rather than appending to it.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        field.typeText("2000")

        let save = app.buttons["hydrationSaveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Manual entry should offer a Save button")

        // The number pad covers Save, so put it away the only way this field offers.
        app.buttons["keyboardDone"].tap()

        // Near the right edge, NOT the centre. `tap()` hits an element's centre, which is over the
        // "Save" glyphs and fires even when the capsule around them is dead — so a centre tap passes
        // against the bug this guards. XCUITest reports the outer 88x48 frame either way, so the
        // frame is no help either; only a tap that lands off the text tells the two apart.
        save.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["8 / 9.6 glasses"].waitForExistence(timeout: 5),
                      "A tap near the edge of the Save capsule must file the reading — 2000 / 250 = 8 glasses")
    }

    // MARK: - Keyboard dismissal
    //
    // Five fields raise a keyboard she cannot put away: the three `.numberPad` ones have no return
    // key at all, and the two wrapping note fields have one that types a newline. Either way the
    // keyboard sits over what she is editing until she finds somewhere blank to tap. One shared
    // toolbar serves them all; one test each, so a surface that loses it names itself instead of
    // hiding behind the others.

    /// The field that shares a hierarchy with the partner-email field, so a Done bound to one
    /// field's `@FocusState` would have rendered here and done nothing.
    func testProfileGlassSizeFieldOffersAKeyboardDismiss() {
        let app = launchSeeded(tab: 6)   // Profile
        let glassSize = app.textFields["hydrationGlassSizeField"]
        for _ in 0..<6 where !glassSize.exists { app.swipeUp() }
        XCTAssertTrue(glassSize.waitForExistence(timeout: 10), "Profile should show the glass-size field")
        assertDoneDismissesKeyboard(app, field: glassSize)
    }

    /// Nested in a ScrollView inside a sheet, which is where a keyboard toolbar is least reliable.
    func testTrackManualHydrationFieldOffersAKeyboardDismiss() {
        let app = launchSeeded(tab: 0)   // Home
        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hydration,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "Home should show the hydration summary")
        summary.tap()
        XCTAssertTrue(app.navigationBars["Hydration"].waitForExistence(timeout: 10))

        let manualMl = app.textFields["hydrationManualMlField"]
        XCTAssertTrue(manualMl.waitForExistence(timeout: 10), "The hydration sheet should offer manual ml entry")
        assertDoneDismissesKeyboard(app, field: manualMl)
    }

    /// A plain VStack in a short sheet — no ScrollView to dismiss the keyboard into.
    func testLogWaterFieldOffersAKeyboardDismiss() {
        let app = launchSeeded(tab: 0)   // Home
        XCTAssertTrue(app.buttons["Log today"].waitForExistence(timeout: 15), "Home should show the Log today button")
        app.buttons["Log today"].tap()

        // By identifier, not by label: the log sheet also carries an EFSA citation whose label ends
        // in "water", and it matched first.
        let waterCard = app.buttons["log.waterCard"]
        XCTAssertTrue(waterCard.waitForExistence(timeout: 10), "The log sheet should offer a Water card")
        waterCard.tap()

        let waterMl = app.textFields["log.waterMlField"]
        XCTAssertTrue(waterMl.waitForExistence(timeout: 10), "The water sheet should offer a millilitre field")
        assertDoneDismissesKeyboard(app, field: waterMl)
    }

    /// A wrapping note field: it has a return key, but Return types a newline, so there is still no
    /// way out. Shares its toolbar with the "Add symptom" field further up the same ScrollView.
    func testLogNotesFieldOffersAKeyboardDismiss() {
        let app = launchSeeded(tab: 0)   // Home
        XCTAssertTrue(app.buttons["Log today"].waitForExistence(timeout: 15), "Home should show the Log today button")
        app.buttons["Log today"].tap()

        let notes = app.textFields["log.notesField"]
        for _ in 0..<6 where !notes.exists { app.swipeUp() }
        XCTAssertTrue(notes.waitForExistence(timeout: 10), "The log sheet should offer a notes field")
        assertDoneDismissesKeyboard(app, field: notes)
    }

    /// The other wrapping note field, and the one where it matters most: the keyboard comes up over
    /// the Save button, so without a Done the reading cannot be filed.
    func testPhNotesFieldOffersAKeyboardDismiss() {
        // The pH tab, not Track: Track reaches the pH section only through a detail sheet, whereas
        // the tab is the section.
        let app = launchSeeded(tab: 2)

        // Scroll on isHittable, not on exists: Track renders its whole scroll eagerly, so the button
        // is in the tree from launch and an exists-guard scrolls nowhere and then taps nothing.
        //
        // Swipe *down*, toward the top. "Log pH" sits in the section header, so there is nothing
        // above it to reach and a settled launch already has it in view. This swiped up until
        // 2026-08-13, so the one launch in N where the first isHittable check landed before the tab
        // finished laying out scrolled the header off the top and could never scroll back — ten
        // swipes and then a failure, with the button above the viewport. Nothing here is
        // refreshable, so a swipe at the top rubber-bands harmlessly and buys the settle time the
        // check was missing.
        let logPh = app.buttons["Log pH"]
        XCTAssertTrue(logPh.waitForExistence(timeout: 10), "The pH tab should offer a Log pH button")
        for _ in 0..<10 where !logPh.isHittable { app.swipeDown() }
        XCTAssertTrue(logPh.isHittable, "Log pH should be in reach at the top of the pH tab")
        logPh.tap()

        let notes = app.textFields["ph.notesField"]
        XCTAssertTrue(notes.waitForExistence(timeout: 10), "The pH sheet should offer a notes field")
        assertDoneDismissesKeyboard(app, field: notes)
    }

    /// Requirement 1B.9. Only `readings.last` was ever editable, so a value she mistyped weeks ago
    /// could not be corrected or removed — the log sheet handled any reading, nothing just handed it
    /// one. The list is deliberately unfiltered by the chart's range control, so this passes on the
    /// 30d default with a reading seeded 5 days back either way.
    func testPhHistoryListOpensAnOlderReadingForEditing() {
        let app = launchSeeded(tab: 2)

        let toggle = app.buttons["phHistoryToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "the pH tab should offer a reading history")
        for _ in 0..<10 where !toggle.isHittable { app.swipeUp() }
        toggle.tap()

        // Seeded readings are 6.3 (5d), 6.7 (2d) and 6.9 (today); the list is newest first, so
        // row 2 is the oldest — the one the latest-reading panel could never reach.
        let oldest = app.buttons["phHistoryRow2"]
        XCTAssertTrue(oldest.waitForExistence(timeout: 10), "every reading should be listed, not just the latest")
        for _ in 0..<10 where !oldest.isHittable { app.swipeUp() }
        oldest.tap()

        XCTAssertTrue(app.navigationBars["Edit pH reading"].waitForExistence(timeout: 10),
                      "tapping an older reading should open it for editing, not start a new one")
        XCTAssertEqual(app.staticTexts["ph.currentValue"].label, "6.3",
                       "the sheet should load the reading that was tapped")
        XCTAssertTrue(app.buttons["Delete"].exists, "an older reading has to be deletable too")
    }

    /// The audit's exact repro, and the gate H0 has to clear. `RepositoryTests` proves the DTO
    /// round-trips; only this proves the whole path — sheet, repository, UserDefaults, and a second
    /// **process** reading it back. The defect that shipped was invisible to every in-process test,
    /// so the fix cannot be guarded by one.
    ///
    /// The relaunch keeps the store but stays backend-less on purpose: a launch without the seed
    /// flag would resolve the real Supabase backend, and no test may point at the shared project.
    func testAVaginalPhReadingSurvivesKillingAndReopeningTheApp() {
        let app = launchSeeded(tab: 2)

        let logPh = app.buttons["Log pH"]
        XCTAssertTrue(logPh.waitForExistence(timeout: 10), "the pH tab should offer a Log pH button")
        // Down, not up — same header button and the same flake as in the keyboard test above.
        for _ in 0..<10 where !logPh.isHittable { app.swipeDown() }
        logPh.tap()

        // Saved at the sheet's default 4.2 — distinct from the seeded 6.3/6.7/6.9, so the assertion
        // after the relaunch is about this reading and not one that was always there.
        XCTAssertTrue(app.navigationBars["Log pH reading"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["ph.currentValue"].label, "4.2")
        app.buttons["Save"].tap()

        // Three seeded + the one just saved. Row 3 exists only if all four are in the list.
        let toggle = app.buttons["phHistoryToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        for _ in 0..<10 where !toggle.isHittable { app.swipeUp() }
        toggle.tap()
        XCTAssertTrue(app.buttons["phHistoryRow3"].waitForExistence(timeout: 10),
                      "the reading should file before the restart")

        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-uiTestSeed", "YES", "-uiTestKeepStore", "YES", "-uiTestTab", "2"]
        relaunched.launch()

        let afterRestart = relaunched.buttons["phHistoryToggle"]
        XCTAssertTrue(afterRestart.waitForExistence(timeout: 10),
                      "her pH history must still be there after a cold start — this is what was lost")
        for _ in 0..<10 where !afterRestart.isHittable { relaunched.swipeUp() }
        afterRestart.tap()
        XCTAssertTrue(relaunched.buttons["phHistoryRow3"].waitForExistence(timeout: 10),
                      "all four readings must survive the restart, and stay editable")
    }

    private func assertDoneDismissesKeyboard(
        _ app: XCUIApplication, field: XCUIElement, file: StaticString = #filePath, line: UInt = #line
    ) {
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10),
                      "tapping the field should raise the keyboard", file: file, line: line)
        let done = app.buttons["keyboardDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10),
                      "a field with no dismissing return key must offer a Done above the keyboard",
                      file: file, line: line)
        done.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 10),
                      "Done must put the keyboard away", file: file, line: line)
    }

    func testHomeHydrationSummaryOpensTrackHydrationControls() {
        let app = launchSeeded(tab: 0)
        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hydration,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        summary.tap()

        // Landing on the Track hydration sheet (nav bar + its glasses quick-add controls) proves the jump.
        XCTAssertTrue(app.navigationBars["Hydration"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add 2 glass"].exists)
        XCTAssertTrue(app.buttons["Remove 1 glass"].exists)
    }

    func testTabNavigation() {
        let app = launchSeeded(tab: 0)
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        // The Home hydration card shows a label-only "Track" affordance, so match the tab-bar
        // buttons by their accessibility identifier to avoid a duplicate-"Track" collision.
        for label in ["Track", "pH", "Nutrition", "Insights", "Learn", "Profile", "Home"] {
            let tab = app.buttons.matching(identifier: label).firstMatch
            tab.tap()
            XCTAssertTrue(tab.exists, "Should switch to \(label)")
        }
    }

    func testInsightsOpensLogHistory() {
        let app = launchSeeded(tab: 4)   // Insights
        let logsCard = app.staticTexts["My logs"]
        XCTAssertTrue(logsCard.waitForExistence(timeout: 10), "Insights should show the 'My logs' card")
        logsCard.tap()
        XCTAssertTrue(app.navigationBars["Your logs"].waitForExistence(timeout: 5), "Should push the log-history screen")
    }

    /// The cycle card may report only the length she configured. Regularity is a property of several
    /// completed cycles and the app stores one `cycle_settings` row, so the old "Cycle regularity"
    /// title read as a measurement the app had never taken.
    func testInsightsReportsCycleLengthWithoutClaimingRegularity() {
        let app = launchSeeded(tab: 4)   // Insights
        let length = app.staticTexts["Your cycle: 28 days"]
        for _ in 0..<12 where !length.exists { app.swipeUp() }
        XCTAssertTrue(length.waitForExistence(timeout: 10), "Insights should report the length she configured")

        // Checked before the title because `continueAfterFailure` is false in this class: a title
        // assertion first aborts the run, and the claim guard — the point of the test — never runs.
        let claims = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'regularity'"))
        XCTAssertEqual(claims.count, 0, "nothing on Insights may claim regularity from one configured cycle length")
        XCTAssertTrue(app.staticTexts["Current cycle length"].exists, "and the card should be titled by what it knows")
    }

    func testProfileShowsAccountActions() {
        let app = launchSeeded(tab: 6)   // Profile
        XCTAssertTrue(app.staticTexts["Personal Details"].waitForExistence(timeout: 10), "Profile should show account rows")
        XCTAssertTrue(app.staticTexts["Delete account"].exists || app.buttons["Delete account"].exists,
                      "Profile should offer account deletion (App Store requirement)")

        let privacyPolicy = app.descendants(matching: .any)
            .matching(identifier: "Privacy Policy")
            .firstMatch
        for _ in 0..<4 where !privacyPolicy.exists { app.swipeUp() }
        XCTAssertTrue(privacyPolicy.waitForExistence(timeout: 5),
                      "Profile should provide an accessible in-app privacy-policy link")
    }

    /// The three Profile rows used to raise a paragraph of text and change nothing. An alert and an
    /// editor are indistinguishable from the outside, so the assertion is on what each one opens.
    func testTheProfileRowsOpenRealEditors() {
        let app = launchSeeded(tab: 6)   // Profile

        XCTAssertTrue(app.staticTexts["Personal Details"].waitForExistence(timeout: 10))
        app.staticTexts["Personal Details"].tap()
        XCTAssertTrue(app.navigationBars["Personal details"].waitForExistence(timeout: 5),
                      "Personal Details should open an editor, not an alert")
        XCTAssertTrue(app.textFields["displayNameField"].exists, "her name should be editable there")
        app.buttons["Cancel"].tap()

        app.staticTexts["Health Profile"].tap()
        XCTAssertTrue(app.navigationBars["Your cycle"].waitForExistence(timeout: 5),
                      "Health Profile should open the cycle editor")
        app.buttons["Cancel"].tap()

        app.staticTexts["Tracking Preferences"].tap()
        XCTAssertTrue(app.navigationBars["Tracking preferences"].waitForExistence(timeout: 5),
                      "Tracking Preferences should open an editor")
        app.buttons["Cancel"].tap()
    }

    /// Her onboarding answers were captured once and then frozen. Proving the editor *saves* is the
    /// whole point — a picker that forgets on dismiss looks identical to the alert it replaced.
    func testAChangedTrackingPreferenceIsStillThereWhenSheComesBack() {
        let app = launchSeeded(tab: 6)   // Profile

        XCTAssertTrue(app.staticTexts["Tracking Preferences"].waitForExistence(timeout: 10))
        app.staticTexts["Tracking Preferences"].tap()

        let trying = app.buttons["quizOption.stage.trying"]
        XCTAssertTrue(trying.waitForExistence(timeout: 5), "the journey-stage options should be offered")
        // States the premise: a seeded launch answers no quiz, so the assertion at the end is about
        // the save and not about what happened to be there already.
        XCTAssertFalse(trying.isSelected, "a seeded launch should start with no answer chosen")
        trying.tap()
        app.buttons["Save"].tap()

        app.staticTexts["Tracking Preferences"].tap()
        XCTAssertTrue(trying.waitForExistence(timeout: 5))
        XCTAssertTrue(trying.isSelected, "the answer she saved should be the one selected on her return")
    }

    /// The other half of T7. A question she was allowed to skip in onboarding must not become
    /// permanently answered the first time she opens this editor and touches it, so the chosen
    /// option clears on a second tap — and only where the question is optional.
    func testTheOptionalAnswerCanBeWithdrawnInTrackingPreferences() {
        let app = launchSeeded(tab: 6)   // Profile

        XCTAssertTrue(app.staticTexts["Tracking Preferences"].waitForExistence(timeout: 10))
        app.staticTexts["Tracking Preferences"].tap()

        let girl = app.buttons["quizOption.gender.girl"]
        XCTAssertTrue(girl.waitForExistence(timeout: 5), "the sex-preference options should be offered")
        girl.tap()
        XCTAssertTrue(girl.isSelected, "her choice should register")
        girl.tap()
        XCTAssertFalse(girl.isSelected, "tapping it again should leave the question unanswered")

        // The required questions keep the old behaviour: a second tap is not an escape hatch.
        let trying = app.buttons["quizOption.stage.trying"]
        trying.tap()
        trying.tap()
        XCTAssertTrue(trying.isSelected, "a required answer must not be clearable")
    }

    /// Device-side data-isolation guard: seeded (User A) health data must be gone after sign-out,
    /// so a next user on the same device starts clean. Runs FULLY LOCALLY via the seed harness —
    /// no production accounts. Server-side RLS isolation is proven separately by backend probes.
    func testSignOutClearsHealthDataLocally() {
        let app = launchSeeded(tab: 0)   // Home, with seeded cycle data
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))

        // Seeded cycle is present → the first-run setup prompt must NOT be showing yet.
        let setupPrompt = app.staticTexts["When did your last period start? Next we'll confirm your cycle length — every prediction is built from it."]
        XCTAssertFalse(setupPrompt.exists, "Seeded cycle should render, not the empty setup prompt")

        // Sign out from Profile.
        app.buttons["Profile"].tap()
        let logout = app.buttons["Log out"]
        XCTAssertTrue(logout.waitForExistence(timeout: 5), "Signed-in Profile should offer Log out")
        logout.tap()

        // Home now shows the empty setup prompt (cycle wiped, no relaunch).
        app.buttons["Home"].tap()
        XCTAssertTrue(setupPrompt.waitForExistence(timeout: 5), "After sign-out, cycle data must be cleared")

        // Insights pH is empty too.
        app.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["No pH readings yet. Log your first one on the pH tab."].waitForExistence(timeout: 5),
                      "After sign-out, pH readings must be cleared")
    }
}
