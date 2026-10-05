import Foundation

/// DRAFT CONTENT: pending medical and editorial review.
///
/// The built-in programme: the owner's thirteen week themes and nutrition focuses, a first draft
/// schedule of activities, and short neutral wording for each kind of day. Every item is marked
/// `draft`. Nothing here states what a food, a habit or a test does for anyone; the strings name
/// what a day is about and where to go. Lesson text is not in this file: each day carries a lesson
/// reference, and `draftLessons` supplies the text from `ProgrammeLessonsDraft`. The written
/// title, focus and introduction of each day come from `ProgrammeDayCopyDraft`.
///
/// Every string below reaches `ProgrammeContent.allSurfaces`, which the guard tests scan.
extension ProgrammeContent {

    public static let draft = ProgrammeContent(
        version: "draft-1",
        weeks: draftWeeks,
        phaseTitles: [
            .buildTheFoundation: "Build the Foundation",
            .discoverYourPatterns: "Discover Your Patterns",
            .personaliseAndSustain: "Personalise & Sustain",
        ],
        kindCopy: [
            .shortLesson: ProgrammeDayCopy(
                title: "Short lesson",
                focus: "A few minutes of reading for today.",
                introduction: "Today starts with a short read."),
            .actionDay: ProgrammeDayCopy(
                title: "Action day",
                focus: "Your everyday check-ins.",
                introduction: "Today is for your usual check-ins."),
            .reflection: ProgrammeDayCopy(
                title: "Reflection",
                focus: "A moment to note how the last few days went.",
                introduction: "Take a quiet minute to think about the last few days."),
            .trackerFocus: ProgrammeDayCopy(
                title: "Tracker focus",
                focus: "A closer look at one of your trackers.",
                introduction: "Open one of your trackers and see what it already holds."),
            .testGuidance: ProgrammeDayCopy(
                title: "Test guidance",
                focus: "How the tests in your kit are used and recorded.",
                introduction: "Today covers how to use the tests in your kit and record a result."),
            .weeklyReview: ProgrammeDayCopy(
                title: "Weekly review",
                focus: "A look back over your programme week.",
                introduction: "Your programme week is ready to look back on."),
            .nutritionFocus: ProgrammeDayCopy(
                title: "Nutrition focus",
                focus: "The food focus in Your Diet Plan.",
                introduction: "Open Your Diet Plan for the current food focus."),
            .progressReview: ProgrammeDayCopy(
                title: "Progress review",
                focus: "A look at your programme so far.",
                introduction: "You have reached the end of a phase."),
        ],
        kindReflections: [
            .reflection: "What felt easiest to keep up over the last few days?",
            .weeklyReview: "What would you like to carry into your next programme week?",
            .progressReview: "What have you noticed about your routine so far?",
        ],
        kindReadMinutes: [
            .shortLesson: 3, .actionDay: 2, .reflection: 2, .trackerFocus: 3,
            .testGuidance: 4, .weeklyReview: 3, .nutritionFocus: 3, .progressReview: 4,
        ],
        testGuidanceWeeks: [6, 7],
        dayCopy: ProgrammeDayCopyDraft.dayCopy
    )

    /// The written lesson text for `draft`, by lesson id. Pass it to `presentation(ofDay:lessons:)`.
    public static let draftLessons = ProgrammeDraftLessons()

    // MARK: - Schedule

    /// The draft schedule every week shares.
    ///
    /// Mood, energy, sleep, hydration and supplements count each day. A pH reading counts once a
    /// programme week. An ovulation test counts only on the days the task engine finds relevant.
    /// The nutrition check-in and symptoms are offered and never counted.
    private static let baseActivities: [ProgrammeActivityRule] = [
        .init(.moodCheckIn, .eligible),
        .init(.energyCheckIn, .eligible),
        .init(.sleepCheckIn, .eligible),
        .init(.hydrationCheckIn, .eligible),
        .init(.supplementCheckIn, .eligible),
        .init(.nutritionCheckIn, .optional),
        .init(.symptomCheckIn, .optional),
        .init(.lhTest, .eligible),
        .init(.phTest, .eligible),
    ]

    private static let cycleActivities: [ProgrammeActivityRule] = [
        .init(.cycleCheckIn, .optional),
        .init(.periodLog, .optional),
    ]

    private static func learn(_ slugs: String...) -> [ProgrammeContentReference] {
        slugs.map { .learnArticle(slug: $0) }
    }

    private static func review(_ interpretsHealth: Bool) -> ProgrammeContentReview {
        ProgrammeContentReview(containsHealthInterpretation: interpretsHealth)
    }

    // MARK: - Weeks

    private static let draftWeeks: [ProgrammeWeekDefinition] = [
        ProgrammeWeekDefinition(
            number: 1,
            themeTitle: "Start & Baseline",
            purpose: "Get to know your kit, the programme and the trackers you will use.",
            connectsTo: [.dailyLog, .cycle, .learn],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Your current routine",
                detail: "Record what you already eat, with nothing to change yet."),
            activities: baseActivities + cycleActivities,
            relatedContent: learn("getting-started-first-week", "guide-how-the-log-works", "what-to-log"),
            review: review(false)
        ),
        ProgrammeWeekDefinition(
            number: 2,
            themeTitle: "Understand Your Cycle",
            purpose: "Learn how a cycle is counted, and what is recorded and what is estimated.",
            connectsTo: [.cycle, .cycleHistory],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Notice variety",
                detail: "See which food groups appear across your days."),
            activities: baseActivities + cycleActivities,
            relatedContent: learn("guide-cycle-and-phases"),
            safetyNotes: [.estimateIsNotARecord],
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 3,
            themeTitle: "Nutrition Foundations",
            purpose: "Meet Your Diet Plan and the food group tracker, with no perfect plate required.",
            connectsTo: [.nutrition],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Balanced plate",
                detail: "Look at how the six food groups fit on one plate.",
                foodGroups: FoodGroup.allCases),
            activities: baseActivities,
            relatedContent: learn("guide-nutrition-focus"),
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 4,
            themeTitle: "Hydration & Sleep",
            purpose: "Build simple water and sleep routines, and keep track of them.",
            connectsTo: [.hydration, .sleep, .weeklySummary],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Hydration",
                detail: "Keep water alongside your meals and log it as you go."),
            activities: baseActivities,
            relatedContent: learn("guide-how-hydration-works", "hydration-basics", "guide-sleep-tracking"),
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 5,
            themeTitle: "Your Body Signals",
            purpose: "Notice mood, energy and symptoms, and how one observation differs from a pattern.",
            connectsTo: [.dailyLog],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Fruit and vegetable variety",
                detail: "Try a fruit or vegetable you do not usually pick.",
                foodGroups: [.fruit, .vegetables]),
            activities: baseActivities,
            relatedContent: learn("guide-logging-symptoms", "why-logging-beats-remembering"),
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 6,
            themeTitle: "Understanding Fertility",
            purpose: "Learn about the fertile window, ovulation and LH, and how an estimate differs from a test result.",
            connectsTo: [.cycle, .lhTesting, .scanner],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Protein variety",
                detail: "Rotate between the protein foods you enjoy.",
                foodGroups: [.protein]),
            activities: baseActivities + cycleActivities,
            relatedContent: learn("fertile-window", "understanding-ovulation-tests"),
            safetyNotes: [.estimateIsNotARecord, .lhResultDoesNotEstablishOvulation],
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 7,
            themeTitle: "Understand Your Tests",
            purpose: "See what each test in your kit can and cannot tell you, and how to record a result.",
            connectsTo: [.phTesting, .lhTesting, .scanner],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Fibre-rich choices",
                detail: "Notice the vegetables, fruit and starchy carbs in your meals.",
                foodGroups: [.vegetables, .fruit, .starchyCarbs]),
            activities: baseActivities + [.init(.pregnancyTestRelatedAction, .optional)],
            relatedContent: learn("understanding-ovulation-tests", "guide-vaginal-ph-tracker", "guide-how-to-log-ph"),
            safetyNotes: [.lhResultDoesNotEstablishOvulation, .phIsFactualOnly, .homeTestIsNotAClinicalFinding],
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 8,
            themeTitle: "Build Consistency",
            purpose: "Why steady habits count for more than perfect days, and how to pick up your routine.",
            connectsTo: [.programmeConsistency],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Oils and fats",
                detail: "Notice where oils, nuts, seeds and avocado appear in your meals.",
                foodGroups: [.oilsAndFats]),
            activities: baseActivities,
            relatedContent: learn("small-habits-that-hold"),
            review: review(false)
        ),
        ProgrammeWeekDefinition(
            number: 9,
            themeTitle: "Discover Your Patterns",
            purpose: "Tell an observation from a trend and a pattern, and see why more data helps.",
            connectsTo: [.insights, .weeklySummary, .cycleHistory],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Meal regularity",
                detail: "Notice when you eat across the day."),
            activities: baseActivities,
            relatedContent: learn("reading-your-trends", "what-insights-mean"),
            safetyNotes: [.insightIsNotMedicalAdvice],
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 10,
            themeTitle: "Your Fertility Goal",
            purpose: "See how the goal you chose shapes what the programme puts first.",
            connectsTo: [.dailyLog, .cycle],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Practical preparation",
                detail: "Plan one or two meals ahead so that logging stays easy."),
            activities: baseActivities,
            relatedContent: learn("using-what-you-learn"),
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 11,
            themeTitle: "Strengthen Your Routine",
            purpose: "Find your strongest routines and the ones that need more support.",
            connectsTo: [.programmeConsistency, .dailyLog],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Sustainable choices",
                detail: "Keep the food habits that fit your everyday life."),
            activities: baseActivities,
            relatedContent: learn("small-habits-that-hold"),
            review: review(false)
        ),
        ProgrammeWeekDefinition(
            number: 12,
            themeTitle: "Understand Your Insights",
            purpose: "Learn the four evidence levels, and what Genesyx can and cannot say.",
            connectsTo: [.insights],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Understand your nutrition pattern",
                detail: "Look back at the food groups you have recorded so far."),
            activities: baseActivities,
            relatedContent: learn("what-insights-mean"),
            safetyNotes: [.insightIsNotMedicalAdvice],
            review: review(true)
        ),
        ProgrammeWeekDefinition(
            number: 13,
            themeTitle: "Review, Personalise & Continue",
            purpose: "Look back over your programme and choose what to continue after day 90.",
            connectsTo: [.programmeConsistency, .insights],
            nutritionFocus: ProgrammeNutritionFocus(
                title: "Long-term routine",
                detail: "Choose the food habits you want to carry on with."),
            activities: baseActivities,
            relatedContent: learn("using-what-you-learn", "when-to-ask-for-support"),
            review: review(false)
        ),
    ]
}
