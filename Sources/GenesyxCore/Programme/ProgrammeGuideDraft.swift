import Foundation

/// DRAFT CONTENT: pending medical and editorial review.
///
/// The Programme Guide: the app's companion to the printed guide in the kit. An ordered list of
/// thirty sections under the owner's titles. Each is a short read of 60 to 180 words, points at the
/// Learn articles that go further, and ends with one typed action in the app.
///
/// The wording about test results and pH readings is the approved wording from `LhScanCopy`,
/// `PhCopy` and `HcgScanCopy`, used by reference so the two cannot drift apart.

/// Where a guide section's button leads, and what the button says.
public struct ProgrammeGuideAction: Hashable, Sendable {
    public let destination: ProgrammeDestination
    public let label: String
}

public struct ProgrammeGuideSection: Hashable, Sendable, Identifiable {
    /// The section's slug. Stable: it is a route and a read-history key, so it does not change
    /// once released.
    public let id: String
    public let title: String
    public let paragraphs: [String]
    public let relatedContent: [ProgrammeContentReference]
    public let callToAction: ProgrammeGuideAction
    /// Never shown to users.
    public let review: ProgrammeContentReview

    public var slug: String { id }
}

public enum ProgrammeGuideDraft {

    public static func section(slug: String) -> ProgrammeGuideSection? {
        sections.first { $0.id == slug }
    }

    /// Every reader-facing string held here, for the guard tests.
    public static var allSurfaces: [String] {
        sections.flatMap { [$0.title, $0.callToAction.label] + $0.paragraphs }
    }

    /// One section. `health` is false only where the words name no health topic at all.
    private static func section(
        _ slug: String,
        _ title: String,
        to destination: ProgrammeDestination,
        _ label: String,
        learn: [String] = [],
        health: Bool = true,
        _ paragraphs: String...
    ) -> ProgrammeGuideSection {
        ProgrammeGuideSection(
            id: slug,
            title: title,
            paragraphs: paragraphs,
            relatedContent: learn.map { .learnArticle(slug: $0) },
            callToAction: ProgrammeGuideAction(destination: destination, label: label),
            review: ProgrammeContentReview(containsHealthInterpretation: health)
        )
    }

    /// The thirty sections, in the owner's order.
    public static let sections: [ProgrammeGuideSection] = [

        section("welcome-to-genesyx", "Welcome to Genesyx",
                to: .dailyLog, "Open today's log",
                learn: ["getting-started-first-week"],
                "Genesyx is a place to record how your days go and to learn about your cycle at your own pace. You log small things, such as mood, sleep, water and food groups, and the app keeps them and shows them back to you clearly.",
                "This Programme Guide is the companion to your Fertility Kit. It explains each part of the app and each item in the box, and every section ends with a link to the relevant screen.",
                "Genesyx records and describes. It does not give medical advice, and it will always tell you when a question is one for a GP, nurse, pharmacist or midwife."),

        section("your-fertility-kit", "Your Fertility Kit",
                to: .fertilityKitGuide, "Open My Fertility Kit",
                "Your Fertility Kit combines the items in the box with a premium experience in the app. In the box are ovulation tests, vaginal pH test strips, pregnancy tests, a printed Programme Guide and your access card.",
                "In the app, the kit gives you the 90-Day Fertility Programme and Your Diet Plan, along with programme reviews and guidance on using each test.",
                "Activating your kit and starting the programme are separate steps. Activation gives you access. The programme begins only when you choose to start it, so there is no need to begin on the day the box arrives.",
                "Each test has its own leaflet. Always use it for how to carry out and read that test."),

        section("how-the-90-day-programme-works", "How the 90-Day Programme Works",
                to: .programmeProgress, "See your programme progress",
                health: false,
                "The programme lasts 90 days, arranged in 13 weeks and three phases. Each week has a theme, and each day has one focus, a short read, a few actions and a line on why it matters.",
                "Days are counted from the date you start. The programme keeps moving with the calendar, so if you are away for a while you come back to the current day. Nothing resets, you are never returned to day 1, and later days are never held back.",
                "The actions use the trackers Genesyx already has. There is no separate programme log. When you record something in the usual place, the programme recognises it.",
                "Most days take a few minutes. After a gap, the programme simply says welcome back."),

        section("understanding-your-cycle", "Understanding Your Cycle",
                to: .cycle, "Open your cycle",
                learn: ["guide-cycle-and-phases"],
                "A cycle runs from the first day of one period to the day before the next. The first day of a period is cycle day 1, and the number of days in the whole cycle is its length.",
                "Cycle length differs between people and from one cycle to the next. A cycle that is a few days longer or shorter than your last is common, and travel, illness or a demanding few weeks can all shift it.",
                "Genesyx works from the dates and lengths you enter. The starting values are only a place to begin, and you can change them at any time.",
                "If your cycles are very irregular, have stopped, or have changed and stayed changed, a GP or nurse is the right person to ask."),

        section("cycle-phases", "Cycle Phases",
                to: .cycle, "See your current phase",
                learn: ["guide-cycle-and-phases", "eating-with-your-cycle"],
                "Genesyx names four phases. Period starts on day 1 and lasts as many days as your period length. Follicular runs from the end of your period to the day before predicted ovulation. Ovulatory is the predicted ovulation day. Luteal runs from the day after that until your next period begins.",
                "The phases are worked out from your settings, so their boundaries are estimates. They describe where you are in the count of days. They are not a reading of what your body is doing.",
                "You will see your current phase on the Home screen, on the calendar and in the Nutrition tab. When you correct a period date, the phases adjust to match."),

        section("cycle-tracking", "Cycle Tracking",
                to: .cycle, "Open your calendar",
                learn: ["guide-cycle-and-phases", "fertile-window"],
                "Tracking your cycle in Genesyx comes down to one habit: recording the day each period starts. That single date keeps every estimate current.",
                "On the calendar, days you have logged are marked, and days ahead show estimated periods, an estimated fertile window and a predicted ovulation day. A legend explains each colour.",
                "Keep two kinds of information apart as you read it. Recorded dates are things that happened and that you entered. Estimated dates are predictions from your settings and will move if your dates change.",
                "Your cycle history builds from the point you begin recording. Genesyx does not invent cycles from before then."),

        section("body-signals", "Body Signals",
                to: .dailyLog, "Log how you feel today",
                learn: ["guide-logging-symptoms", "why-logging-beats-remembering", "cervical-mucus"],
                "Body signals are the things you notice in yourself from day to day: how your mood is, how much energy you have, and any symptoms. Genesyx gives each a place in the Daily Log.",
                "Recording a signal is different from interpreting it. The app keeps what you enter and can show how often something appears. It does not decide what a signal means.",
                "One entry is an observation. The same thing recurring at a similar point over several cycles is a pattern, and patterns take time to appear. Until then, the most useful thing is to keep noting what you notice, in the same words each time."),

        section("mood-and-energy", "Mood & Energy",
                to: .dailyLog, "Log mood and energy",
                learn: ["guide-how-the-log-works", "why-logging-beats-remembering"],
                "Mood and energy are the two quickest check-ins in Genesyx. Mood has four options, from Great to Low. Energy has three: Low, Normal and High. Each takes one tap.",
                "Log them as they are. You do not have to explain an entry, and there is no preferred answer. The programme counts the check-in as done whatever you choose, and a low day never lowers your consistency.",
                "Over time these small entries become a reliable account of how your weeks have gone, which memory alone rarely gives.",
                "If low mood lasts, or is affecting your daily life, please speak to a GP."),

        section("symptoms", "Symptoms",
                to: .dailyLog, "Log today's symptoms",
                learn: ["guide-logging-symptoms", "what-to-log"],
                "The symptoms section of the Daily Log lists common entries and lets you add your own. Tap whatever applies. A custom symptom is saved and offered again next time, so name it in a way you will recognise.",
                "Genesyx counts what you enter and shows you the totals. It does not link a symptom to a cause or tell you what it means. In the programme, symptoms are optional and are never counted.",
                "A symptom record is useful to bring to an appointment, where interpretation belongs. If a symptom is severe, new for you or worrying, speak to a GP, nurse or pharmacist without waiting to see a pattern."),

        section("sleep", "Sleep",
                to: .dailyLog, "Log last night's sleep",
                learn: ["guide-sleep-tracking", "sleep-stress-and-your-cycle"],
                "Genesyx tracks sleep as one figure a day: how long you slept, entered by you in hours and minutes. It does not use sensors and it does not rate sleep quality.",
                "A rough entry made most mornings is all it takes. Across a week, the Insights screen shows your average over the nights you logged and how many nights were recorded. Nights without an entry are left out of the average.",
                "The programme only checks that you logged your sleep. The length of a night never affects your consistency.",
                "If poor sleep is a lasting problem for you, a GP or pharmacist can talk it through."),

        section("hydration", "Hydration",
                to: .hydration, "Track today's water",
                learn: ["guide-how-hydration-works", "hydration-basics", "hydration-and-reproductive-health"],
                "The hydration tracker lets you log water a glass at a time against a daily target. A progress bar shows how far through the target you are, and a short line of guidance changes through the day.",
                "The target is a tracking aid. How much water a person needs varies, and for most healthy adults thirst is a reasonable guide. Food and other drinks contribute too, so your logged total is always a partial picture.",
                "In the programme, water builds gradually towards the day's action, so part of your target still counts. The simplest way to keep the habit is to tie a glass to something you already do, such as a meal.",
                "If you have been given medical advice about fluids, that advice comes first."),

        section("your-diet-plan", "Your Diet Plan",
                to: .nutrition, "Open Your Diet Plan",
                learn: ["guide-nutrition-focus"],
                "Your Diet Plan is the food side of your Fertility Kit. It is not a set of rules and it does not ask you to cut anything out. It is built on the six food groups in the Genesyx tracker.",
                "It brings together today's food record, the nutrition focus for the current programme week, a guide to each food group and meal ideas that list the groups they include.",
                "The food record is a record, not a target. Nothing here is scored. The programme notes whether you made a nutrition check-in and shows how many groups you recorded as a plain count. It never produces a nutrition percentage or a grade.",
                "If you eat in a particular way for medical reasons, or have an allergy, that advice comes first."),

        section("nutrition", "Nutrition",
                to: .nutrition, "Tick today's food groups",
                learn: ["eating-with-your-cycle", "nutrition-before-conception", "guide-nutrition-focus"],
                "Genesyx records food by group. The six groups are vegetables, fruit, starchy carbs, protein, dairy and alternatives, and oils and fats. When a meal includes a group, you tick it for the day.",
                "The groups are a vocabulary for describing what you ate. Genesyx does not rank them, count nutrients or tell you how much of anything to eat.",
                "Each programme week offers one small nutrition focus, such as noticing variety or planning a meal ahead. Each is an invitation to look at one aspect of your routine. None is a requirement.",
                "The Learn library has longer articles on eating across your cycle and on nutrition when planning ahead. For advice about your own diet, a GP, pharmacist or registered dietitian can help."),

        section("healthy-routines", "Healthy Routines",
                to: .dailyLog, "Open today's log",
                learn: ["small-habits-that-hold", "what-to-log"],
                "A routine is something you do without having to decide to. The programme helps you build a few small ones around logging: a mood tap, a glass of water recorded, last night's sleep entered.",
                "Routines hold when they are small and attached to something that already happens. Choose a fixed moment, such as a meal or bedtime, and do your check-in then. Keep a smallest version for difficult days: one entry is enough to keep your record going.",
                "Aim for most days, not every day. A day off changes very little. When you have been away, the programme simply welcomes you back and you continue with today."),

        section("understanding-fertility", "Understanding Fertility",
                to: .cycle, "See your estimated window",
                learn: ["fertile-window", "when-to-ask-for-support"],
                "In each cycle there is a short stretch of days around ovulation known as the fertile window. Genesyx shows an estimate of it on your calendar, worked out from your cycle settings.",
                "Three things are easy to confuse and are kept separate throughout the app. An estimated fertile window is a prediction from your dates. An ovulation test result is what one test showed. Ovulation itself is something neither the app nor a home test observes directly.",
                "The estimate is a guide and is best read as a range. It is not a method of contraception and should not be used as one.",
                "If you have concerns about your fertility, a GP is the right starting point. The Learn article on when to ask for support explains the usual thresholds."),

        section("ovulation", "Ovulation",
                to: .cycle, "See your predicted dates",
                learn: ["fertile-window", "guide-cycle-and-phases"],
                "Ovulation is the release of an egg. It usually happens once in a cycle, and its timing varies between people and between cycles. It does not reliably fall on day 14.",
                "Genesyx predicts an ovulation day by counting back 14 days from when your next period is expected. This is a convention based on your settings. It is a prediction, not an observation, and it moves whenever your dates change.",
                "The app never states that ovulation has happened. A predicted day arriving is not evidence of it, and neither is an ovulation test result.",
                "If you have questions about ovulation, or your cycles are very irregular, a GP or nurse can advise."),

        section("lh-testing", "LH Testing",
                to: .lhTest, "Open ovulation tests",
                learn: ["understanding-ovulation-tests"],
                "LH is a substance your body produces, and its level usually rises shortly before ovulation. An ovulation test looks for LH in urine.",
                "A test shows what LH was doing in that sample at that moment. A result showing a surge is not evidence that ovulation has happened, and a low result describes that test only.",
                LhScanCopy.resultNote,
                "The programme lists an ovulation test as a counted action only on days inside your estimated fertile window, and only where your app offers test recording. On other days it does not apply.",
                "Use the leaflet for how and when to test. Some health conditions and medicines can affect LH results, so if yours are confusing, a GP, nurse or pharmacist can help."),

        section("scanning-an-ovulation-test", "Scanning an Ovulation Test",
                to: .lhTest, "Record an ovulation test",
                learn: ["understanding-ovulation-tests"],
                "Where your version of Genesyx offers it, you can record an ovulation test by scanning the strip with your phone's camera or by entering the result yourself. Both save the same kind of record.",
                "Complete the test as the product instructions describe and wait for the development time in the leaflet. To scan, place the strip flat on a plain surface in even light, keep the whole strip in the frame and make sure the test line area and control line area are both visible.",
                "If a scan cannot be read, try again in better light or enter the result by hand, using the leaflet. If the control line is absent, the test is invalid and needs repeating with a new strip.",
                "A saved result is the result of one test. It does not change your predicted dates."),

        section("vaginal-ph", "Vaginal pH",
                to: .phTest, "Open the pH tracker",
                learn: ["guide-understanding-vaginal-ph", "vaginal-ph-explained", "guide-vaginal-ph-tracker"],
                "Vaginal pH is a measure of acidity, read from a paper test strip as a number. It shifts naturally across your cycle, so your own pattern over time tells you more than any single reading.",
                "Genesyx records each reading and shows it against the typical range. It reports the number and keeps the history. It does not interpret a reading, and a reading is not a statement about your health or your fertility.",
                PhCopy.accuracyCaveat,
                PhCopy.elevatedSignpost,
                PhCopy.disclaimer),

        section("scanning-a-ph-test", "Scanning a pH Test",
                to: .phTest, "Log a pH reading",
                learn: ["guide-how-to-log-ph", "guide-track-ph-in-nutrition"],
                "A pH reading can be saved in two ways. You can enter the value yourself, matching the pad on your strip to the colour chart that came with it. Where your version of Genesyx offers scanning, you can also scan the strip with your camera.",
                "Complete the test as its instructions describe and wait for the stated development time. To scan, place the strip on a flat, neutral surface, use even lighting without shadows or reflections, and keep the whole strip inside the frame.",
                "If a scan cannot be read, scan again in better light or enter the value by hand. Do not save a value you are doubtful about: read the strip again instead.",
                "Add your cycle day to the note when you save. One reading a week is enough to build a history."),

        section("pregnancy-tests", "Pregnancy Tests",
                to: .fertilityKitGuide, "Open My Fertility Kit",
                "Your kit includes pregnancy tests. Use them exactly as the instructions that came with them describe, wait for the time those instructions give, and read the strip within the time they allow. A test read too early or too late may not be reliable.",
                "Where Genesyx offers a place to record a test, it records what the strip shows: a test line detected, no test line detected, or an invalid test.",
                HcgScanCopy.aboutNote,
                HcgScanCopy.resultNote,
                "Recording a test is always your choice. It does not change anything else in the app, it does not stop or alter your programme, and it is never counted in your consistency."),

        section("understanding-test-history", "Understanding Test History",
                to: .fertilityKitGuide, "See your test results",
                learn: ["guide-track-ph-in-nutrition", "understanding-ovulation-tests"],
                "Each test you record is kept with its date and time, and whether it was scanned or entered by hand. Over time these records form a history.",
                "pH readings appear on a chart, where you can see the range your readings usually sit in. Ovulation test results, where your app records them, appear as a list of recent results, each standing for one test on one day.",
                "History is for seeing your own record at a glance and for sharing with a professional if you choose. It is a list of results, not a conclusion. Genesyx does not combine results into a verdict, and a test result never changes the estimated dates on your calendar.",
                "You can delete a result you entered by mistake."),

        section("supplements", "Supplements",
                to: .dailyLog, "Log today's supplements",
                learn: ["gentle-guide-supplements", "fertility-supplements-explained"],
                "The Daily Log includes a supplements section where you can tick what you have taken that day. If you told Genesyx during set-up that you take supplements, ticking them is one of your programme actions. If you said you do not, it is left out.",
                "This guide does not tell you which supplements to take or in what amount. That depends on your diet, your health and any medicines you use, and it is a question for a pharmacist or GP.",
                "Supplements can interact with medicines and with each other. If you take regular medication, check with a pharmacist before starting anything new.",
                "The Learn library has two articles that set out what the evidence does and does not support."),

        section("consistency", "Consistency",
                to: .programmeProgress, "See your consistency",
                learn: ["small-habits-that-hold"],
                "Programme Consistency shows how many of your relevant actions you completed. Today is shown as a count, for example 2 of 5 activities completed today. Past weeks and phases are shown as a percentage.",
                "Only actions that were relevant to you are counted. Optional actions and those that did not apply on a given day are left out, so they cannot lower your figure.",
                "Consistency reflects whether you did an action, never what the result was. Low mood, low energy, symptoms, a short night, a pH value, a test result and your cycle length have no effect on it.",
                "Days without a log are a normal part of any routine. The programme does not reset or hold you back. Pick up your routine and continue with today."),

        section("understanding-your-insights", "Understanding Your Insights",
                to: .insights, "See your insights",
                learn: ["what-insights-mean", "reading-your-trends", "using-what-you-learn"],
                "Insights are built only from what you have logged and from your cycle settings. Genesyx sorts what it can say into four levels: an observation from a single day, a trend within a week, a pattern within a cycle, and a pattern across cycles.",
                "Each level needs more data than the one before. Patterns within a cycle are offered only when there is enough cycle context, and patterns across cycles only when there is real history. When there is not enough, the app says it is still learning your pattern.",
                "An insight describes your record. It does not explain causes, predict what will happen or assess your health. If something in your record is persistent, new for you and unexplained, raise it with a GP or nurse."),

        section("days-1-30", "Days 1-30",
                to: .programmeProgress, "See your programme progress",
                learn: ["getting-started-first-week", "guide-how-the-log-works"],
                "The first phase is called Build the Foundation. Over four weeks and the start of a fifth, it introduces the trackers the programme relies on.",
                "Week 1 covers the kit, the programme and your first check-ins. Week 2 explains how your cycle is counted and the difference between recorded and estimated dates. Week 3 introduces Your Diet Plan and the six food groups. Week 4 looks at water and sleep as everyday habits.",
                "The phase closes on day 30 with a progress review. By then the aim is modest: that logging feels familiar, and that you know where everything is. Nothing in this phase asks you to change how you live."),

        section("days-31-60", "Days 31-60",
                to: .programmeProgress, "See your programme progress",
                learn: ["fertile-window", "understanding-ovulation-tests", "reading-your-trends"],
                "The second phase is called Discover Your Patterns. It adds understanding to the routines from the first phase.",
                "Week 5 covers mood, energy and symptoms. Week 6 explains the fertile window, ovulation and LH, and the difference between an estimate and a test result. Week 7 goes through each test in your kit and how to record a result. Week 8 is about consistency and returning after a gap. Week 9 begins to look at observations, trends and patterns.",
                "The phase closes on day 60 with a second progress review. Testing in this phase is always optional and applies only on the days it is relevant to you."),

        section("days-61-90", "Days 61-90",
                to: .programmeProgress, "See your programme progress",
                learn: ["using-what-you-learn", "what-insights-mean"],
                health: false,
                "The third phase is called Personalise & Sustain. It turns what you have learned into a routine of your own.",
                "Week 10 explains how the goal you chose shapes the order of your actions. Week 11 helps you find your strongest routines and support the ones that slip. Week 12 explains the four evidence levels used for your insights and what Genesyx can and cannot say. Week 13, days 85 to 90, looks back over the programme and helps you decide what to continue.",
                "The phase closes on day 90 with your 90-Day Review. There is nothing to pass and no standard to reach. The purpose is to leave you with a routine that suits you."),

        section("your-90-day-review", "Your 90-Day Review",
                to: .programmeProgress, "View your 90-Day Review",
                learn: ["using-what-you-learn"],
                "Your 90-Day Review is ready on day 90. It summarises the whole programme using only what you recorded.",
                "It shows the dates the programme covered, the days on which you were active, the cycles and tests you recorded, your nutrition check-ins, your water and sleep tracking, your body check-ins and your programme consistency. It names your strongest routines and any patterns your record supports.",
                "Where there is too little data to say something, the review leaves it out. It does not assess your health or your fertility, and it makes no predictions.",
                "Use it to decide what to carry on with. The routines you kept most steadily are usually the ones worth keeping."),

        section("continuing-with-genesyx", "Continuing With Genesyx",
                to: .insights, "See your insights",
                learn: ["when-to-ask-for-support", "using-what-you-learn"],
                "Day 90 ends the daily lessons. It does not end your access. Your premium features, including Your Diet Plan, your programme history, your test history and this guide, remain available.",
                "Your trackers carry on exactly as before, and your record keeps growing for as long as you log. Insights that need more history, such as patterns across cycles, continue to develop after the programme.",
                "From here the routine is yours. A short daily check-in and a weekly look at your summary is enough to keep your record useful.",
                "If you would like to talk to someone about your cycle, your results or your plans, a GP, nurse, pharmacist or midwife can help, and your record will support that conversation."),
    ]
}
