import XCTest
@testable import GenesyxCore

/// The guard every written programme string has to pass: day copy, lesson text and the Programme
/// Guide. One place, so the three test files cannot drift apart.
///
/// `bannedAnywhere` and `bannedWords` are `ProgrammeContentTests`' lists, copied by hand as every
/// banned list in this target is; `additional` is the written content's own. Relaxing any of them
/// is a compliance decision, not a code change.
enum ProgrammeWrittenCopyGuard {

    static let bannedAnywhere = [
        "unlock", "guarantee", "diagnos", "cure", "treat", "infertil", "you are pregnant", "get pregnant fast", "empower",
        "thrush", "infection", "candida", "vaginosis", "prescrib", "leafy greens", "whole grains", "mineral water",
        "you are ovulating", "you ovulated", "you will ovulate", "ovulation confirmed", "confirms ovulation",
        "confirmed", "peak fertility", "most fertile", "best time", "conceive", "conception", "pregnan",
        "intercourse", "have sex", "baby", "gender", "shettles", "sex selection", "boy or girl", "alkaline diet",
        "balance your ph", "sway the sex", "choose the sex", "detox", "flush toxins",
        "congratulat", "due date", "miscarr", "unfortunately", "sorry", "positive", "negative", "expecting", "celebrat",
        "you broke", "you failed", "you missed", "don't lose", "streak is over", "missed", "failed", "should have",
        "behind", "don't forget", "hormone", "optimis", "your journey", "take control of", "boost",
    ]
    static let bannedWords = ["bv", "sti", "stis", "boy", "girl", "hcg"]

    /// The owner's list for the written content. Several are in `bannedAnywhere` already; all
    /// twenty are written out so the list reads as it was given.
    static let additional = [
        "you are pregnant", "positive", "negative", "boost", "guarantee", "detox", "superfood", "cure", "treat",
        "diagnos", "infertil", "failed", "behind", "streak", "should have", "calorie", "weight", "bmi",
        "good food", "bad food",
    ]

    static let placeholders = ["coming soon", "placeholder", "tbc", "tbd", "todo", "lorem", "to follow", "to be written", "draft"]

    /// US spellings of words this content uses or could. "color" and "program" are matched as
    /// whole-word stems so "colour" and "programme" pass.
    static let usSpellings = ["analyz", "personaliz", "organiz", "recogniz", "fiber", "yogurt", "practicing", "favorite", "behavior"]

    /// The owner's guide has a section titled "Pregnancy Tests", so the stem "pregnan" cannot be
    /// banned outright in lesson and guide text. Only this product name is let through, and only
    /// where a caller asks for it; every other use of the stem is still a violation.
    static let productName = "pregnancy test"

    static func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func violations(in surfaces: [String], allowingProductName: Bool = false) -> [String] {
        var found: [String] = []
        let terms = Array(Set(bannedAnywhere + additional + placeholders + usSpellings)).sorted()
        for s in surfaces {
            var lower = s.lowercased()
            if allowingProductName { lower = lower.replacingOccurrences(of: productName, with: "home test") }
            for term in terms where lower.contains(term) { found.append("\"\(term)\" in: \(s)") }
            for term in bannedWords + ["program", "programs", "color", "colors"] where containsWord(term, in: s) {
                found.append("\"\(term)\" in: \(s)")
            }
            if s.contains("\u{2014}") || s.contains("\u{2013}") { found.append("dash in: \(s)") }
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("empty string registered") }
            if s != s.trimmingCharacters(in: .whitespacesAndNewlines) { found.append("untrimmed: \(s)") }
            if s.contains("  ") { found.append("double space in: \(s)") }
        }
        return found
    }

    // MARK: Health topics

    /// A string that names any of these is about a health topic, so its item must be flagged for
    /// clinical review. Stems match from the start of a word; "pH" and "LH" match whole words.
    static func namesAHealthTopic(_ text: String) -> Bool {
        let stems = "cycle|period|ovulat|fertil|test|sleep|water|hydrat|nutrition|food|diet|symptom|mood|energy|supplement|health|medic"
        return text.range(of: "\\b(\(stems))", options: [.regularExpression, .caseInsensitive]) != nil
            || containsWord("ph", in: text) || containsWord("lh", in: text)
    }

    // MARK: Measures

    static func wordCount(_ paragraphs: [String]) -> Int {
        paragraphs.joined(separator: " ").split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    /// Sentences, counted as a full stop, question mark or exclamation mark at the end of the
    /// string or before a space.
    static func sentenceCount(_ text: String) -> Int {
        let pattern = "[.?!](\\s|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    // MARK: Learn slugs

    /// The source of the app's Learn library, or `nil` where the app sources are not present.
    static func learnSource(file: StaticString = #filePath) -> String? {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let learn = root.appendingPathComponent("App/Genesyx/UI/Learn")
        guard let files = try? FileManager.default.contentsOfDirectory(at: learn, includingPropertiesForKeys: nil) else {
            return nil
        }
        return files.filter { $0.pathExtension == "swift" }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    static func learnSlugs(in references: [ProgrammeContentReference]) -> [String] {
        references.compactMap {
            if case .learnArticle(let slug) = $0 { return slug }
            return nil
        }
    }
}
