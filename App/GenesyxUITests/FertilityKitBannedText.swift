import Foundation

/// What no Fertility Kit screen may show, as literals: a UI test cannot import the core guard.
/// The two lists and the matching rules are those of `FertilityKitCopyGuard` in the core tests,
/// and `FertilityKitCopyTests.testTheJourneyListsMatchTheGuard` reads this file and fails when a
/// term is missing from it. The journeys read these lists and never retype a term.
enum FertilityKitBannedText {

    struct Terms {
        /// Found anywhere in the text.
        let anywhere: [String]
        /// Found only as a whole word.
        let wholeWords: [String]
        let noughtPerCent: Bool
    }

    /// The product rules that hold for every word a user can read. A hit fails the journey.
    static let failing = Terms(
        anywhere: ["unlock", "coming soon", "to follow", "\u{2014}", "gx90", "editorial_reviewed",
                   "clinical_reviewed", "streak", "you missed", "you failed", "behind", "guarantee",
                   "diagnos", "boost"],
        wholeWords: ["locked", "lock", "draft", "approved", "reviewed"],
        noughtPerCent: true)

    /// Listed with the screen each was found on and read by a person. Never fails a journey.
    static let reported = Terms(
        anywhere: ["welcome back", "continue with today", "pick up your routine", "score", "grade",
                   "rating", "catch up", "you should", "you must", "\u{2013}"],
        wholeWords: ["poor", "bad", "regular", "irregular", "normal", "late", "overdue"],
        noughtPerCent: false)

    /// The label a nought per cent is reported under.
    static let noughtPerCent = "0%"

    /// The one sentence that may say "scored": the nutrition promise. Taken out before matching.
    static let allowedSentence = "Nothing here is scored, and a blank day costs you nothing."

    /// The terms of a list found in `text`, each once. Every match ignores case.
    /// Rule one: a whole word is matched with word boundaries, so "latest" is not "late".
    /// Rule two: a nought per cent is `0%` not preceded by a digit, so "50%" is not it.
    static func hits(_ terms: Terms, in text: String) -> [String] {
        let lower = text.lowercased().replacingOccurrences(of: allowedSentence.lowercased(), with: "")
        var found = terms.anywhere.filter { lower.contains($0) }
        found += terms.wholeWords.filter {
            lower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: $0))\\b", options: .regularExpression) != nil
        }
        if terms.noughtPerCent, lower.range(of: "(?<![0-9])0%", options: .regularExpression) != nil {
            found.append(noughtPerCent)
        }
        return found
    }
}
