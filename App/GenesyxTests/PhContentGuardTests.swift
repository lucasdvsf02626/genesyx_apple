import XCTest
@testable import Genesyx

/// Guards that Learn pH content (titles/excerpts/bodies) carries no banned clinical or diet terms.
/// Citation SOURCE display titles in medical_sources.json are exempt — this scans article copy only,
/// so "Bacterial vaginosis" as an NHS source name never trips this.
final class PhContentGuardTests: XCTestCase {

    private let banned = ["bv", "thrush", "infection", "candida", "vaginosis", "leafy greens", "whole grains", "mineral water"]
    private let phSlugs: Set<String> = ["guide-vaginal-ph-tracker", "guide-how-to-log-ph", "guide-track-ph-in-nutrition"]

    /// Scans `allArticles` for the same reason the banned-phrase guard does: a pH piece in the
    /// weekly series is compiled in months before it is revealed, and checking only the published
    /// set would first inspect it on the morning it reached readers.
    func testLearnPhGuidesHaveNoBannedTerms() {
        let phArticles = LearnLibrary.allArticles.filter { phSlugs.contains($0.slug) || $0.tags.contains("ph") }
        XCTAssertFalse(phArticles.isEmpty, "expected pH Learn guides to scan")
        for a in phArticles {
            var strings = [a.title, a.excerpt] + a.tags
            for block in a.body {
                switch block {
                case .heading(let t), .paragraph(let t), .callout(let t): strings.append(t)
                case .bulletList(let items): strings += items
                }
            }
            for s in strings {
                let lower = s.lowercased()
                for term in banned {
                    XCTAssertFalse(lower.contains(term), "Banned term \"\(term)\" in pH article \(a.slug): \(s)")
                }
            }
        }
    }
}
