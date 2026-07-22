import XCTest
@testable import Genesyx

/// Guards that Learn pH content (titles/excerpts/bodies) carries no banned clinical or diet terms.
/// Citation SOURCE display titles in medical_sources.json are exempt — this scans article copy only,
/// so "Bacterial vaginosis" as an NHS source name never trips this.
final class PhContentGuardTests: XCTestCase {

    private let banned = ["bv", "thrush", "infection", "candida", "vaginosis", "leafy greens", "whole grains", "mineral water"]
    private let phSlugs: Set<String> = ["guide-urine-tracker-with-stick", "guide-how-to-log-ph", "guide-track-ph-in-nutrition"]

    func testLearnPhGuidesHaveNoBannedTerms() {
        let phArticles = LearnLibrary.articles.filter { phSlugs.contains($0.slug) || $0.tags.contains("ph") }
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
