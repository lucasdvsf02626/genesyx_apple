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
        XCTAssertEqual(gender?.options.count, 3, "Gender question has three options (Android parity)")
    }

    func testFiveQuestionsInOrder() {
        XCTAssertEqual(QuizContent.questions.map { $0.id }, ["stage", "cycle", "supplements", "gender", "support"])
    }
}
