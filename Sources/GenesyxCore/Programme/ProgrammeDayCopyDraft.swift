import Foundation

/// DRAFT CONTENT: pending medical and editorial review.
///
/// The written copy for each of the ninety programme days. `copy` is what the content schema
/// holds (title, focus, introduction) and is plugged into `ProgrammeContent.draft` through
/// `dayCopy`. The schema has no field for the other three, so they sit beside it here: the "why
/// this matters" line, a per-day question on the reflective days, and the Learn articles that
/// cover the day's topic at greater length.
///
/// The words themselves are in the three `ProgrammeDayCopyDraftPhase` files, one per phase.
public struct ProgrammeDayWriting: Hashable, Sendable {
    /// 1 to 90.
    public let day: Int
    public let copy: ProgrammeDayCopy
    /// One or two sentences, shown under "Why this matters".
    public let whyThisMatters: String
    /// A non-medical question, on reflection, weekly-review and progress-review days.
    public let reflection: String?
    /// Learn articles this day points to instead of restating them.
    public let relatedContent: [ProgrammeContentReference]
    /// Never shown to users.
    public let review: ProgrammeContentReview
}

public enum ProgrammeDayCopyDraft {

    /// All ninety days, in order.
    public static let all: [ProgrammeDayWriting] = phaseOne + phaseTwo + phaseThree

    static let byDay: [Int: ProgrammeDayWriting] =
        Dictionary(all.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })

    /// The title, focus and introduction per day, in the shape `ProgrammeContent` takes.
    public static var dayCopy: [Int: ProgrammeDayCopy] { byDay.mapValues(\.copy) }

    /// The written words for a programme day, or `nil` outside 1 to 90.
    public static func writing(forDay day: Int) -> ProgrammeDayWriting? { byDay[day] }

    /// Every reader-facing string held here, for the guard tests.
    public static var allSurfaces: [String] {
        all.flatMap {
            [$0.copy.title, $0.copy.focus, $0.copy.introduction, $0.whyThisMatters]
                + ($0.reflection.map { [$0] } ?? [])
        }
    }

    /// One day. `health` is false only where the words name no health topic at all.
    static func day(
        _ day: Int,
        _ title: String,
        focus: String,
        intro: String,
        why: String,
        reflect: String? = nil,
        learn: [String] = [],
        health: Bool = true
    ) -> ProgrammeDayWriting {
        ProgrammeDayWriting(
            day: day,
            copy: ProgrammeDayCopy(title: title, focus: focus, introduction: intro),
            whyThisMatters: why,
            reflection: reflect,
            relatedContent: learn.map { .learnArticle(slug: $0) },
            review: ProgrammeContentReview(containsHealthInterpretation: health)
        )
    }
}

extension ProgrammeContent {
    /// Every reader-facing string of the written draft: `draft.allSurfaces`, then each day's
    /// why-this-matters line and question, every lesson paragraph and every Programme Guide
    /// string. The guard tests scan this list, so written copy held anywhere else is unguarded.
    public static var draftWrittenSurfaces: [String] {
        draft.allSurfaces + ProgrammeDayCopyDraft.allSurfaces + ProgrammeLessonsDraft.allSurfaces
            + ProgrammeGuideDraft.allSurfaces
    }
}
