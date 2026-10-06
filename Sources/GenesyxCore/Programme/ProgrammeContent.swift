import Foundation

// The programme's content SCHEMA: value types only. The words and the schedule live in
// `ProgrammeDraftContent.swift`; the rules that read them live in `ProgrammeTaskEngine.swift`.

// MARK: - Shared vocabulary

/// Every kind of programme activity. One list for the schedule, the task engine and consistency.
public enum ProgrammeTaskCategory: String, CaseIterable, Codable, Sendable {
    case cycleCheckIn, periodLog, sleepCheckIn, hydrationCheckIn, nutritionCheckIn, moodCheckIn
    case energyCheckIn, symptomCheckIn, supplementCheckIn, programmeLesson, weeklyReview
    case lhTest, phTest, pregnancyTestRelatedAction, fertilityKitEducation

    /// Counted once per programme week rather than once per day.
    public var isWeekly: Bool { self == .phTest }
}

/// Where a task or a day's call to action leads. A closed list: the app layer maps each case to a
/// real screen, and no caller invents a destination.
public enum ProgrammeDestination: String, CaseIterable, Codable, Sendable {
    case cycle, dailyLog, hydration, nutrition, insights
    case programmeLesson, weeklyReview, programmeProgress
    case lhTest, phTest, fertilityKitGuide
}

/// How a week's schedule wants an activity treated before the day's facts are looked at.
public enum ProgrammeActivityStanding: String, Codable, Sendable {
    /// Relevant and counted in consistency, where the day's rules allow it.
    case eligible
    /// Offered and acknowledged, never counted.
    case optional
}

/// One line of a week's schedule.
public struct ProgrammeActivityRule: Hashable, Sendable {
    public let category: ProgrammeTaskCategory
    public let standing: ProgrammeActivityStanding

    public init(_ category: ProgrammeTaskCategory, _ standing: ProgrammeActivityStanding) {
        self.category = category
        self.standing = standing
    }
}

/// The shape of a programme day. Every week mixes them on one repeating pattern
/// (`ProgrammeContent.dayKind(forDay:)`).
public enum ProgrammeDayKind: String, CaseIterable, Codable, Sendable {
    case shortLesson, actionDay, reflection, trackerFocus, testGuidance, weeklyReview, nutritionFocus
    case progressReview
}

/// The existing parts of the app a week or a day points at. Keys only.
public enum ProgrammeFeature: String, CaseIterable, Codable, Sendable {
    case dailyLog, cycle, cycleHistory, nutrition, hydration, sleep, weeklySummary, insights
    case lhTesting, phTesting, scanner, supplements, learn, programmeConsistency

    /// The screen this feature is reached through.
    public var destination: ProgrammeDestination {
        switch self {
        case .dailyLog, .sleep, .supplements: return .dailyLog
        case .cycle, .cycleHistory: return .cycle
        case .nutrition: return .nutrition
        case .hydration: return .hydration
        case .weeklySummary, .insights: return .insights
        case .lhTesting: return .lhTest
        case .phTesting: return .phTest
        case .scanner: return .fertilityKitGuide
        case .learn: return .programmeLesson
        case .programmeConsistency: return .programmeProgress
        }
    }
}

/// A pointer at content the app already holds, by that content's own identifier.
public enum ProgrammeContentReference: Hashable, Sendable {
    /// A Learn article or guide, by slug.
    case learnArticle(slug: String)
    /// A recipe, by `Recipe.id`.
    case recipe(id: String)
}

// MARK: - Review status (internal, never shown to users)

/// How far a content item has got through review. Raw values are stored in reports and must not
/// be renamed.
public enum ProgrammeReviewStatus: String, CaseIterable, Codable, Sendable {
    case draft = "draft"
    case editorialReviewed = "editorial_reviewed"
    case clinicalReviewed = "clinical_reviewed"
    case approved = "approved"
}

/// The review mark every content item carries. Starts as a draft.
public struct ProgrammeContentReview: Hashable, Sendable {
    public var status: ProgrammeReviewStatus
    /// The item interprets health or fertility, so it needs a clinical reviewer, not only an editor.
    public var containsHealthInterpretation: Bool

    public init(status: ProgrammeReviewStatus = .draft, containsHealthInterpretation: Bool) {
        self.status = status
        self.containsHealthInterpretation = containsHealthInterpretation
    }
}

/// One row of the review report.
public struct ProgrammeReviewItem: Hashable, Sendable {
    /// `dayCopy` and `guideSection` are the written day copy and Programme Guide sections. Only
    /// `itemsNeedingClinicalReview()` lists them; `reviewItems()` stays the 206 schedule items.
    public enum Kind: String, Sendable, CaseIterable { case week, day, lesson, nutritionFocus, dayCopy, guideSection }
    public let kind: Kind
    /// Stable within the content: "week-04", "day-023", the lesson id, "nutrition-focus-04",
    /// "day-copy-023", the guide section's slug.
    public let id: String
    public let review: ProgrammeContentReview
}

// MARK: - Safety

/// The distinctions a day's wording has to keep. Metadata for writers and reviewers, not copy.
public enum ProgrammeSafetyNote: String, CaseIterable, Codable, Sendable {
    /// A predicted date or window is an estimate, never a record.
    case estimateIsNotARecord
    /// An LH result is a test result. It does not establish that ovulation happened.
    case lhResultDoesNotEstablishOvulation
    /// A pH reading is reported as a number and nothing is concluded from it.
    case phIsFactualOnly
    /// A home test result is a recorded result, not a clinical finding.
    case homeTestIsNotAClinicalFinding
    /// An insight describes what was logged. It is not medical advice.
    case insightIsNotMedicalAdvice
}

public struct ProgrammeSafetyMetadata: Hashable, Sendable {
    public let containsHealthInterpretation: Bool
    /// The reader shows the standing medical disclaimer with this day.
    public let disclaimerRequired: Bool
    public let notes: [ProgrammeSafetyNote]

    public init(containsHealthInterpretation: Bool, notes: [ProgrammeSafetyNote] = []) {
        self.containsHealthInterpretation = containsHealthInterpretation
        self.disclaimerRequired = containsHealthInterpretation
        self.notes = notes
    }
}

// MARK: - Lessons

/// The identifier of a day's learning item. The text is not held here: a lesson provider supplies
/// it, and a day whose lesson has no text yet is simply a shorter day.
public struct ProgrammeLessonReference: Hashable, Sendable {
    public let id: String
    public let review: ProgrammeContentReview
}

/// The text of a lesson. Cannot be built empty, so "a lesson with nothing in it" has no value to
/// reach a screen with.
public struct ProgrammeLessonBody: Hashable, Sendable {
    public let paragraphs: [String]

    /// `nil` when no paragraph has any text.
    public init?(paragraphs: [String]) {
        let kept = paragraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !kept.isEmpty else { return nil }
        self.paragraphs = kept
    }
}

/// Supplies lesson text by lesson id. A later content phase implements it.
public protocol ProgrammeLessonProviding {
    func body(forLessonID id: String) -> ProgrammeLessonBody?
}

// MARK: - Weeks and days

/// A week's nutrition focus. `foodGroups` is typed, so a focus can only ever name a food group the
/// tracker really has; empty when the focus is about habits rather than a group.
public struct ProgrammeNutritionFocus: Hashable, Sendable {
    public let title: String
    public let detail: String
    public let foodGroups: [FoodGroup]
    public let review: ProgrammeContentReview

    public init(
        title: String,
        detail: String,
        foodGroups: [FoodGroup] = [],
        review: ProgrammeContentReview = ProgrammeContentReview(containsHealthInterpretation: true)
    ) {
        self.title = title
        self.detail = detail
        self.foodGroups = foodGroups
        self.review = review
    }
}

public struct ProgrammeWeekDefinition: Hashable, Sendable {
    /// 1 to 13.
    public let number: Int
    public let themeTitle: String
    public let purpose: String
    /// The first entry is the week's main feature: tracker-focus days lead there.
    public let connectsTo: [ProgrammeFeature]
    public let nutritionFocus: ProgrammeNutritionFocus
    /// The tracker and test activities scheduled this week. Lessons and reviews come from the
    /// day's kind, not from this list.
    public let activities: [ProgrammeActivityRule]
    public let relatedContent: [ProgrammeContentReference]
    public let safetyNotes: [ProgrammeSafetyNote]
    public let review: ProgrammeContentReview

    public init(
        number: Int,
        themeTitle: String,
        purpose: String,
        connectsTo: [ProgrammeFeature],
        nutritionFocus: ProgrammeNutritionFocus,
        activities: [ProgrammeActivityRule],
        relatedContent: [ProgrammeContentReference] = [],
        safetyNotes: [ProgrammeSafetyNote] = [],
        review: ProgrammeContentReview
    ) {
        self.number = number
        self.themeTitle = themeTitle
        self.purpose = purpose
        self.connectsTo = connectsTo
        self.nutritionFocus = nutritionFocus
        self.activities = activities
        self.relatedContent = relatedContent
        self.safetyNotes = safetyNotes
        self.review = review
    }

    public var dayRange: ClosedRange<Int> { ProgrammeCalendar.dayRange(ofWeek: number) }
}

/// The three strings every day shows. Held per day kind as the default, and per day where a
/// writer has replaced the default.
public struct ProgrammeDayCopy: Hashable, Sendable {
    public let title: String
    public let focus: String
    public let introduction: String

    public init(title: String, focus: String, introduction: String) {
        self.title = title
        self.focus = focus
        self.introduction = introduction
    }
}

/// One programme day, produced from the week it sits in and the repeating day-kind pattern.
public struct ProgrammeDayDefinition: Hashable, Sendable {
    /// 1 to 90.
    public let day: Int
    public let week: Int
    public let phase: ProgrammePhase
    public let kind: ProgrammeDayKind
    public let title: String
    public let focus: String
    public let introduction: String
    /// The day's lesson, by reference. See `ProgrammeContent.presentation(ofDay:lessons:)`.
    public let lesson: ProgrammeLessonReference
    /// Every activity that can be offered on this day, before the day's facts decide which are.
    public let todayActions: [ProgrammeTaskCategory]
    /// The week's schedule, carried so the task engine needs nothing but the day.
    public let activities: [ProgrammeActivityRule]
    /// A non-medical prompt, on the days that have one.
    public let optionalReflection: String?
    /// The week's nutrition focus, on nutrition-focus days.
    public let nutritionFocus: ProgrammeNutritionFocus?
    public let relatedFeature: ProgrammeFeature
    public let relatedContent: [ProgrammeContentReference]
    /// Where the day's main button leads.
    public let callToAction: ProgrammeDestination
    public let safety: ProgrammeSafetyMetadata
    /// Reading time with the lesson text, in minutes.
    public let estimatedReadMinutes: Int
    public let review: ProgrammeContentReview
    /// The reminder category this day belongs to. A key only: no wording, no health value.
    public let notificationCategoryKey: String
}

/// What a day screen has to show, with the lesson resolved. There is no "text to follow" state:
/// `lesson` is either real text or absent, and an absent lesson leaves a complete short day made
/// of the title, focus, introduction and the day's actions.
public struct ProgrammeDayPresentation: Hashable, Sendable {
    public let definition: ProgrammeDayDefinition
    public let lesson: ProgrammeLessonBody?
    /// The day's reading time: the definition's with a lesson, one minute without.
    public let estimatedReadMinutes: Int
}

/// A complete programme: thirteen weeks, and a day definition for each of the ninety days derived
/// from them.
public struct ProgrammeContent: Sendable {
    public let version: String
    public let weeks: [ProgrammeWeekDefinition]
    public let phaseTitles: [ProgrammePhase: String]
    /// Default title, focus and introduction per day kind. A day's title is the week's theme and
    /// the kind's title; its introduction is the kind's introduction and the week's purpose.
    public let kindCopy: [ProgrammeDayKind: ProgrammeDayCopy]
    public let kindReflections: [ProgrammeDayKind: String]
    public let kindReadMinutes: [ProgrammeDayKind: Int]
    /// Weeks whose fifth day is test guidance instead of a second short lesson.
    public let testGuidanceWeeks: Set<Int>
    /// Written copy for single days, replacing the generated default.
    public let dayCopy: [Int: ProgrammeDayCopy]
    /// Review status per day and per lesson, where it has moved on from draft.
    public let dayStatuses: [Int: ProgrammeReviewStatus]
    public let lessonStatuses: [Int: ProgrammeReviewStatus]

    public static let notificationCategoryKey = "programme"

    public init(
        version: String,
        weeks: [ProgrammeWeekDefinition],
        phaseTitles: [ProgrammePhase: String],
        kindCopy: [ProgrammeDayKind: ProgrammeDayCopy],
        kindReflections: [ProgrammeDayKind: String],
        kindReadMinutes: [ProgrammeDayKind: Int],
        testGuidanceWeeks: Set<Int>,
        dayCopy: [Int: ProgrammeDayCopy] = [:],
        dayStatuses: [Int: ProgrammeReviewStatus] = [:],
        lessonStatuses: [Int: ProgrammeReviewStatus] = [:]
    ) {
        self.version = version
        self.weeks = weeks
        self.phaseTitles = phaseTitles
        self.kindCopy = kindCopy
        self.kindReflections = kindReflections
        self.kindReadMinutes = kindReadMinutes
        self.testGuidanceWeeks = testGuidanceWeeks
        self.dayCopy = dayCopy
        self.dayStatuses = dayStatuses
        self.lessonStatuses = lessonStatuses
    }

    public func week(_ number: Int) -> ProgrammeWeekDefinition? {
        weeks.first { $0.number == number }
    }

    /// The repeating weekly pattern, by position in the programme week:
    ///
    ///     1 short lesson   2 action day   3 tracker focus   4 nutrition focus
    ///     5 short lesson (test guidance in `testGuidanceWeeks`)   6 reflection   7 weekly review
    ///
    /// The last day of each phase (30, 60 and 90) is a progress review instead of whatever the
    /// pattern gives. Week 13 has six days, so day 90 is its sixth and the progress review stands
    /// in for that week's review.
    public func dayKind(forDay day: Int) -> ProgrammeDayKind {
        if day % ProgrammeCalendar.daysPerPhase == 0 { return .progressReview }
        let week = ProgrammeCalendar.week(forDay: day)
        switch day - ProgrammeCalendar.dayRange(ofWeek: week).lowerBound + 1 {
        case 1: return .shortLesson
        case 2: return .actionDay
        case 3: return .trackerFocus
        case 4: return .nutritionFocus
        case 5: return testGuidanceWeeks.contains(week) ? .testGuidance : .shortLesson
        case 6: return .reflection
        default: return .weeklyReview
        }
    }

    /// The definition of a programme day, or `nil` outside 1 to 90.
    public func day(_ day: Int) -> ProgrammeDayDefinition? {
        guard (1...ProgrammeCalendar.totalDays).contains(day),
              let week = week(ProgrammeCalendar.week(forDay: day)) else { return nil }
        let kind = dayKind(forDay: day)
        guard let kindCopy = kindCopy[kind] else { return nil }
        let copy = dayCopy[day] ?? ProgrammeDayCopy(
            title: week.themeTitle + ": " + kindCopy.title,
            focus: kindCopy.focus,
            introduction: kindCopy.introduction + " " + week.purpose
        )

        var actions = week.activities.map(\.category)
        actions.append(kind == .testGuidance ? .fertilityKitEducation : .programmeLesson)
        if kind == .weeklyReview || kind == .progressReview { actions.append(.weeklyReview) }

        let mainFeature = week.connectsTo.first ?? .dailyLog
        let feature: ProgrammeFeature
        let callToAction: ProgrammeDestination
        switch kind {
        case .shortLesson: (feature, callToAction) = (.learn, .programmeLesson)
        case .actionDay, .reflection: (feature, callToAction) = (.dailyLog, .dailyLog)
        case .trackerFocus: (feature, callToAction) = (mainFeature, mainFeature.destination)
        case .nutritionFocus: (feature, callToAction) = (.nutrition, .nutrition)
        case .testGuidance: (feature, callToAction) = (.scanner, .fertilityKitGuide)
        case .weeklyReview: (feature, callToAction) = (.weeklySummary, .weeklyReview)
        case .progressReview: (feature, callToAction) = (.programmeConsistency, .programmeProgress)
        }

        let interprets = week.review.containsHealthInterpretation
        let padded = String(repeating: "0", count: 3 - String(day).count) + String(day)
        return ProgrammeDayDefinition(
            day: day,
            week: week.number,
            phase: ProgrammeCalendar.phase(forDay: day),
            kind: kind,
            title: copy.title,
            focus: copy.focus,
            introduction: copy.introduction,
            lesson: ProgrammeLessonReference(
                id: "programme-day-" + padded,
                review: ProgrammeContentReview(status: lessonStatuses[day] ?? .draft,
                                               containsHealthInterpretation: interprets)
            ),
            todayActions: actions,
            activities: week.activities,
            optionalReflection: kindReflections[kind],
            nutritionFocus: kind == .nutritionFocus ? week.nutritionFocus : nil,
            relatedFeature: feature,
            relatedContent: week.relatedContent,
            callToAction: callToAction,
            safety: ProgrammeSafetyMetadata(containsHealthInterpretation: interprets, notes: week.safetyNotes),
            estimatedReadMinutes: kindReadMinutes[kind] ?? 2,
            review: ProgrammeContentReview(status: dayStatuses[day] ?? .draft,
                                           containsHealthInterpretation: interprets),
            notificationCategoryKey: ProgrammeContent.notificationCategoryKey
        )
    }

    /// All ninety day definitions, in order.
    public var days: [ProgrammeDayDefinition] {
        (1...ProgrammeCalendar.totalDays).compactMap { day($0) }
    }

    /// A day ready to show. Pass no provider, or one with no text for this day, and the result is
    /// a complete short day with no lesson section.
    public func presentation(
        ofDay day: Int,
        lessons: (any ProgrammeLessonProviding)? = nil
    ) -> ProgrammeDayPresentation? {
        guard let definition = self.day(day) else { return nil }
        let body = lessons?.body(forLessonID: definition.lesson.id)
        return ProgrammeDayPresentation(
            definition: definition,
            lesson: body,
            estimatedReadMinutes: body == nil ? 1 : definition.estimatedReadMinutes
        )
    }

    // MARK: Review report

    /// Every content item with its review mark: 13 weeks, 13 nutrition focuses, 90 days and 90
    /// lesson references. For reports only; never shown to users.
    public func reviewItems() -> [ProgrammeReviewItem] {
        func padded(_ n: Int, _ width: Int) -> String {
            String(repeating: "0", count: max(width - String(n).count, 0)) + String(n)
        }
        let days = self.days
        return weeks.map { ProgrammeReviewItem(kind: .week, id: "week-" + padded($0.number, 2), review: $0.review) }
            + weeks.map {
                ProgrammeReviewItem(kind: .nutritionFocus, id: "nutrition-focus-" + padded($0.number, 2),
                                    review: $0.nutritionFocus.review)
            }
            + days.map { ProgrammeReviewItem(kind: .day, id: "day-" + padded($0.day, 3), review: $0.review) }
            + days.map { ProgrammeReviewItem(kind: .lesson, id: $0.lesson.id, review: $0.lesson.review) }
    }

    public func reviewItems(with status: ProgrammeReviewStatus) -> [ProgrammeReviewItem] {
        reviewItems().filter { $0.review.status == status }
    }

    /// Items that interpret health or fertility and have not been clinically reviewed. This is the
    /// list handed to a clinician, so it is the union of every flag: the schedule's own marks
    /// (`reviewItems()`), the written lessons, the written day copy and the Programme Guide
    /// sections. A written lesson carries the id of its lesson reference, so one flagged in a week
    /// that is not flagged as a whole still lists that lesson. The written day copy follows the
    /// day's status and the written lesson the lesson's, where this content records one.
    public func itemsNeedingClinicalReview() -> [ProgrammeReviewItem] {
        let writtenLessonFlags = Dictionary(
            ProgrammeLessonsDraft.all.map { ($0.id, $0.review.containsHealthInterpretation) },
            uniquingKeysWith: { $0 || $1 })
        let schedule = reviewItems().map { item -> ProgrammeReviewItem in
            guard item.kind == .lesson, writtenLessonFlags[item.id] == true else { return item }
            return ProgrammeReviewItem(
                kind: .lesson, id: item.id,
                review: ProgrammeContentReview(status: item.review.status, containsHealthInterpretation: true))
        }
        let dayCopy = ProgrammeDayCopyDraft.all.map {
            ProgrammeReviewItem(
                kind: .dayCopy, id: String(format: "day-copy-%03d", $0.day),
                review: ProgrammeContentReview(status: dayStatuses[$0.day] ?? $0.review.status,
                                               containsHealthInterpretation: $0.review.containsHealthInterpretation))
        }
        let guide = ProgrammeGuideDraft.sections.map {
            ProgrammeReviewItem(kind: .guideSection, id: $0.id, review: $0.review)
        }
        return (schedule + dayCopy + guide).filter {
            $0.review.containsHealthInterpretation
                && $0.review.status != .clinicalReviewed && $0.review.status != .approved
        }
    }

    // MARK: Guarded registry

    /// Every reader-facing string this content holds: phase titles, each week's theme, purpose and
    /// nutrition focus, and each day's title, focus, introduction and reflection prompt. The guard
    /// tests scan this list, so a string added to the schema has to be added here to be covered.
    public var allSurfaces: [String] {
        ProgrammePhase.allCases.compactMap { phaseTitles[$0] }
            + weeks.flatMap { [$0.themeTitle, $0.purpose, $0.nutritionFocus.title, $0.nutritionFocus.detail] }
            + days.flatMap { [$0.title, $0.focus, $0.introduction] + ($0.optionalReflection.map { [$0] } ?? []) }
    }
}
