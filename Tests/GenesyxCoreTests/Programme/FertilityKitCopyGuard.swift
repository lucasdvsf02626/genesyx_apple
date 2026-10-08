import Foundation
@testable import GenesyxCore

/// The guard every Fertility Kit copy registry is held to, and the two lists checked over every
/// word a kit screen prints. A helper, not a test case: `FertilityKitCopyTests` proves it can
/// fail, and each registry's own test calls it.
///
/// The UI journeys cannot import this file, so `App/GenesyxUITests/FertilityKitBannedText.swift`
/// repeats the two on-screen lists as literals and `testTheJourneyListsMatchTheGuard` keeps the
/// two in step.
enum FertilityKitCopyGuard {

    /// Terms, by how they are matched. Every match ignores case.
    struct Terms {
        /// Found anywhere in the text.
        var anywhere: [String] = []
        /// Found only as a whole word: "latest" is not "late".
        var wholeWords: [String] = []
        /// A nought per cent: `0%` not preceded by a digit, so "50%" and "100%" are not it.
        var noughtPerCent = false

        var all: [String] { anywhere + wholeWords + (noughtPerCent ? [FertilityKitCopyGuard.noughtPerCent] : []) }
    }

    static let noughtPerCent = "0%"

    /// The one sentence that may say "scored": the nutrition promise, repeated from the tracker.
    /// It is taken out of a text before the text is matched.
    static let allowedSentence = "Nothing here is scored, and a blank day costs you nothing."

    /// What new interface copy may not say, on top of `ProgrammeWrittenCopyGuard`.
    static let newCopy = Terms(
        anywhere: ["welcome back", "continue with today", "pick up your routine", "gx90",
                   "editorial_reviewed", "clinical_reviewed", "score", "grade", "rating", "catch up",
                   "you should", "you must"],
        wholeWords: ["locked", "lock", "approved", "poor", "bad", "regular", "irregular", "normal", "late", "overdue"],
        noughtPerCent: true)

    /// The product rules that hold for every word a user can read. A hit fails a test.
    static let onScreenFailing = Terms(
        anywhere: ["unlock", "coming soon", "to follow", "\u{2014}", "gx90", "editorial_reviewed",
                   "clinical_reviewed", "streak", "you missed", "you failed", "behind", "guarantee", "diagnos", "boost"],
        wholeWords: ["locked", "lock", "draft", "approved", "reviewed"],
        noughtPerCent: true)

    /// Listed with where each was found and read by a person. Never fails a journey.
    static let onScreenReported = Terms(
        anywhere: ["welcome back", "continue with today", "pick up your routine", "score", "grade", "rating",
                   "catch up", "you should", "you must", "\u{2013}"],
        wholeWords: ["poor", "bad", "regular", "irregular", "normal", "late", "overdue"])

    /// The terms of `terms` found in `text`, each once.
    static func hits(_ terms: Terms, in text: String) -> [String] {
        let lower = text.lowercased().replacingOccurrences(of: allowedSentence.lowercased(), with: "")
        var found = terms.anywhere.filter { lower.contains($0) }
        found += terms.wholeWords.filter { ProgrammeWrittenCopyGuard.containsWord($0, in: lower) }
        if terms.noughtPerCent, lower.range(of: "(?<![0-9])0%", options: .regularExpression) != nil {
            found.append(noughtPerCent)
        }
        return found
    }

    /// `ProgrammeWrittenCopyGuard.violations`, plus the kit's own list.
    static func violations(in surfaces: [String], allowingProductName: Bool = false) -> [String] {
        ProgrammeWrittenCopyGuard.violations(in: surfaces, allowingProductName: allowingProductName)
            + surfaces.flatMap { surface in hits(newCopy, in: surface).map { "\"\($0)\" in: \(surface)" } }
    }

    /// Every string literal with a space in `Sources/GenesyxCore/Programme/<name>` that no
    /// surface holds. A literal with interpolations is checked piece by piece: each piece of
    /// wording between two interpolations has to be found in a surface, which it is as soon as
    /// the registry lists one sample of the function. Wording a registry never lists is wording
    /// the guard never sees.
    static func unregisteredLiterals(inFile name: String, surfaces: [String]) throws -> [String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent("Sources/GenesyxCore/Programme/" + name), encoding: .utf8)
        return unregisteredLiterals(inSource: text, surfaces: surfaces)
    }

    static func unregisteredLiterals(inSource text: String, surfaces: [String]) -> [String] {
        literals(in: withoutComments(text)).filter { literal in
            guard literal.joined().contains(" ") else { return false }
            return literal.contains { piece in
                piece.contains(where: \.isLetter) && !surfaces.contains { $0.contains(piece) }
            }
        }.map { $0.joined(separator: "\\(…)") }
    }

    static func withoutComments(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line }
            .joined(separator: "\n")
    }

    /// Each string literal of `code` as its pieces of text, split where an interpolation stood.
    static func literals(in code: String) -> [[String]] {
        var result: [[String]] = []
        let characters = Array(code)
        var index = 0
        while index < characters.count {
            if characters[index] == "\"" {
                let (pieces, next) = literal(in: characters, from: index + 1)
                result.append(pieces)
                index = next
            } else {
                index += 1
            }
        }
        return result
    }

    /// Reads one literal whose opening quote has been passed. Returns its pieces and the index
    /// after its closing quote.
    private static func literal(in characters: [Character], from start: Int) -> (pieces: [String], next: Int) {
        var pieces: [String] = []
        var piece = ""
        var index = start
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                return (pieces + [piece], index + 1)
            }
            if character == "\\", index + 1 < characters.count {
                if characters[index + 1] == "(" {
                    pieces.append(piece)
                    piece = ""
                    index = endOfInterpolation(in: characters, from: index + 2)
                } else {
                    // An escape is kept as the character it stands for where that is plain.
                    let escaped = characters[index + 1]
                    piece.append(escaped == "n" ? "\n" : escaped)
                    index += 2
                }
                continue
            }
            piece.append(character)
            index += 1
        }
        return (pieces + [piece], index)
    }

    /// The index after the parenthesis that closes an interpolation, strings inside it skipped.
    private static func endOfInterpolation(in characters: [Character], from start: Int) -> Int {
        var depth = 1
        var index = start
        while index < characters.count, depth > 0 {
            switch characters[index] {
            case "(": depth += 1; index += 1
            case ")": depth -= 1; index += 1
            case "\"": index = literal(in: characters, from: index + 1).next
            default: index += 1
            }
        }
        return index
    }
}
