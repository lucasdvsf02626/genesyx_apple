import Foundation

/// DRAFT CONTENT: pending medical and editorial review.
///
/// The text of each programme day's lesson: one body per lesson reference, ninety in all. A lesson
/// is short, 80 to 220 words in plain paragraphs. Where a Learn article already covers the topic,
/// the lesson stays brief and the day points at the article (`ProgrammeDayWriting.relatedContent`)
/// instead of restating it.
///
/// The wording about test results and pH readings is the approved wording from `LhScanCopy`,
/// `PhCopy` and `HcgScanCopy`, used by reference so the two cannot drift apart.
///
/// The words themselves are in the three `ProgrammeLessonsDraftPhase` files, one per phase.
public struct ProgrammeLesson: Hashable, Sendable {
    /// The lesson reference this text answers, for example "programme-day-023".
    public let id: String
    public let body: ProgrammeLessonBody
    /// Never shown to users.
    public let review: ProgrammeContentReview
}

public enum ProgrammeLessonsDraft {

    /// Every written lesson, in day order.
    public static let all: [ProgrammeLesson] = (phaseOne + phaseTwo + phaseThree).compactMap { $0 }

    static let byID: [String: ProgrammeLesson] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    public static func lesson(forID id: String) -> ProgrammeLesson? { byID[id] }

    /// Every reader-facing string held here, for the guard tests.
    public static var allSurfaces: [String] { all.flatMap(\.body.paragraphs) }

    /// The lesson for one day, under the id the schedule gives that day. `nil` when every
    /// paragraph is blank, so a blank lesson is dropped here and the tests report it absent.
    /// `health` is false only where the text names no health topic at all.
    static func make(_ day: Int, health: Bool = true, _ paragraphs: String...) -> ProgrammeLesson? {
        guard let body = ProgrammeLessonBody(paragraphs: paragraphs) else { return nil }
        let number = String(day)
        return ProgrammeLesson(
            id: "programme-day-" + String(repeating: "0", count: max(3 - number.count, 0)) + number,
            body: body,
            review: ProgrammeContentReview(containsHealthInterpretation: health)
        )
    }
}

/// Supplies the written lesson text to `ProgrammeContent.presentation(ofDay:lessons:)`.
public struct ProgrammeDraftLessons: ProgrammeLessonProviding, Sendable {
    public init() {}

    public func body(forLessonID id: String) -> ProgrammeLessonBody? {
        ProgrammeLessonsDraft.byID[id]?.body
    }
}
