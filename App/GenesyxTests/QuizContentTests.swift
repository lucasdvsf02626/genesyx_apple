import XCTest
import GenesyxCore

/// Content-safety guard for the onboarding quiz (mirrors the Learn/Notification scans).
final class QuizContentTests: XCTestCase {

    private let bannedPhrases = [
        "boy or girl", "sex selection", "alkaline diet", "balance your ph",
        "sway the sex", "choose the sex", "gender sway",
    ]

    func testNoBannedPhrasesInQuizContent() {
        for q in QuizContent.questions {
            var strings = [q.question, q.helper]
            strings += q.options.map { $0.label }
            if let fact = q.fact { strings += [fact.title, fact.body] }
            for s in strings {
                let lower = s.lowercased()
                for phrase in bannedPhrases {
                    XCTAssertFalse(lower.contains(phrase), "Banned phrase \"\(phrase)\" in quiz \(q.id): \(s)")
                }
            }
        }
    }

    func testGenderQuestionCarriesNoUnsupportedClaim() {
        let gender = QuizContent.questions.first { $0.id == "gender" }
        XCTAssertNotNil(gender, "Gender question must exist")
        XCTAssertNil(gender?.fact, "Gender question must not carry a 'Did you know?' claim")
        XCTAssertEqual(gender?.options.count, 4, "Gender question has four options — ANDROID MUST MATCH")
    }

    /// `either` and `private` predate the Girl/Boy change and must keep their ids: they are storage
    /// keys for `quiz_answers.answers`, so renaming either one orphans every answer already given.
    /// `hope` is deliberately absent — retired, not remapped, because it never recorded which sex.
    func testGenderOptionIdsPreserveStoredAnswers() {
        let gender = QuizContent.questions.first { $0.id == "gender" }
        XCTAssertEqual(gender?.options.map { $0.id }, ["girl", "boy", "either", "private"])
    }

    /// Optionality is scoped, not general. The sex-preference question is the one she may decline
    /// to place on the record at all; making the other four skippable would quietly hollow out the
    /// personalisation they drive, and is a product decision nobody has taken.
    func testOnlyTheSexPreferenceQuestionIsOptional() {
        let optional = QuizContent.questions.filter { $0.isOptional }.map { $0.id }
        XCTAssertEqual(optional, ["gender"], "ANDROID MUST MATCH: only `gender` may be skipped")
    }

    /// These ids are storage keys, not just array order: her answers persist to `quiz_answers.answers`
    /// keyed by them. Renaming one orphans every answer already given to that question, on both
    /// clients, with nothing to report it — so a change here is a data migration, not a rename.
    func testFiveQuestionsInOrder() {
        XCTAssertEqual(QuizContent.questions.map { $0.id }, ["stage", "cycle", "supplements", "gender", "support"])
    }
}
