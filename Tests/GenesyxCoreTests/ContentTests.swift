import XCTest
@testable import GenesyxCore

/// Completeness + integrity checks for the ported nutrition/cycle content and overlay helpers.
/// Ported verbatim from the Android `NutritionContentTest.kt`.
final class ContentTests: XCTestCase {

    private let allPhases = Set(Phase.allCases)

    // ── Nutrition focus foods (screens/Nutrition.tsx PHASE_FOODS) ──

    func testEveryPhaseHasFocusFoodsWithExpectedCounts() {
        XCTAssertEqual(Set(NutritionContent.phaseFoods.keys), allPhases)
        XCTAssertEqual(NutritionContent.phaseFoods[.period]!.count, 3)
        XCTAssertEqual(NutritionContent.phaseFoods[.follicular]!.count, 3)
        XCTAssertEqual(NutritionContent.phaseFoods[.ovulatory]!.count, 4)
        XCTAssertEqual(NutritionContent.phaseFoods[.luteal]!.count, 4)
    }

    func testEveryFocusFoodHasNonBlankCopyAndRicherExpandedDescription() {
        for food in NutritionContent.phaseFoods.values.flatMap({ $0 }) {
            XCTAssertFalse(food.name.isBlank, "name blank")
            XCTAssertFalse(food.shortDesc.isBlank, "shortDesc blank for \(food.name)")
            XCTAssertFalse(food.expandedDesc.isBlank, "expandedDesc blank for \(food.name)")
            XCTAssertGreaterThan(
                food.expandedDesc.count, food.shortDesc.count,
                "expandedDesc should be longer than shortDesc for \(food.name)"
            )
        }
    }

    func testEachPhaseUsesOneAccentAndTheFourPhaseAccentsAreDistinct() {
        for (phase, foods) in NutritionContent.phaseFoods {
            let accents = Set(foods.map(\.accent))
            XCTAssertEqual(accents.count, 1, "phase \(phase) should use a single accent")
        }
        let phaseAccents = Set(NutritionContent.phaseFoods.values.map { $0.first!.accent })
        XCTAssertEqual(phaseAccents.count, 4, "the four phases should have distinct accents")
    }

    func testPhaseDescriptionsCoverEveryPhaseAndAreNonBlank() {
        XCTAssertEqual(Set(NutritionContent.phaseDescription.keys), allPhases)
        for desc in NutritionContent.phaseDescription.values {
            XCTAssertFalse(desc.isBlank)
        }
    }

    func testSupplementPlanIsFolateOmega3VitaminDAndZinc() {
        XCTAssertEqual(NutritionContent.supplementPlan.map(\.initial), ["F", "O", "D", "Z"])
        for item in NutritionContent.supplementPlan {
            XCTAssertFalse(item.name.isBlank)
            XCTAssertFalse(item.rationale.isBlank)
        }
    }

    func testThereAreThreeLearnMoreArticlesWithCopy() {
        XCTAssertEqual(NutritionContent.articles.count, 3)
        for article in NutritionContent.articles {
            XCTAssertFalse(article.title.isBlank)
            XCTAssertFalse(article.read.isBlank)
        }
    }

    // ── Cycle content (lib/cycle.ts phaseHeroCopy / phaseFoods / phaseLabel) ──

    func testCycleContentCoversEveryPhase() {
        XCTAssertEqual(Set(CycleContent.phaseHeroCopy.keys), allPhases)
        XCTAssertEqual(Set(CycleContent.phaseLabel.keys), allPhases)
        XCTAssertEqual(Set(CycleContent.phaseFoods.keys), allPhases)
        for foods in CycleContent.phaseFoods.values {
            XCTAssertEqual(foods.count, 4)
        }
        for copy in CycleContent.phaseHeroCopy.values {
            XCTAssertFalse(copy.hero.isBlank)
            XCTAssertFalse(copy.sub.isBlank)
            XCTAssertFalse(copy.tags.isEmpty)
            XCTAssertFalse(copy.focus.title.isBlank)
            XCTAssertFalse(copy.focus.body.isBlank)
        }
    }

    // ── Fertile-window overlay (lib/cycleEngine.ts) ──

    /// Day `n` of a cycle that began on a fixed date, so a test can name the day it means.
    private func day(_ n: Int, cycleLength: Int = 28, periodLength: Int = 5) -> CyclePhaseInfo {
        let start = CalendarDate(2026, 1, 1)
        return CycleEngine.cyclePhase(lastPeriodDate: start, cycleLength: cycleLength,
                                      periodLength: periodLength, target: start.plusDays(n - 1))
    }

    func testSubLabelIsThePhaseLabelNormallyAndFertileWindowWhenFertile() {
        XCTAssertEqual(CycleContent.phaseSubLabel(day(2)), CycleContent.phaseLabel[.period]!)
        XCTAssertEqual(CycleContent.phaseSubLabel(day(20)), CycleContent.phaseLabel[.luteal]!)
        XCTAssertEqual(CycleContent.phaseSubLabel(day(11)), "Fertile window")   // window opens on day 9
        XCTAssertEqual(CycleContent.phaseSubLabel(day(14)), CycleContent.phaseLabel[.ovulatory]!)
    }

    func testHeroTextOverlaysForNonOvulatoryFertileDaysButNotOvulationItself() {
        // The peak day keeps its own hero even though it sits inside the fertile window.
        XCTAssertEqual(CycleContent.phaseHeroText(day(14)), CycleContent.phaseHeroCopy[.ovulatory]!.hero)
        // The days around it switch to the fertile-window hero.
        XCTAssertEqual(CycleContent.phaseHeroText(day(11)), "Fertile window is open")
        XCTAssertEqual(CycleContent.phaseHeroText(day(7)), CycleContent.phaseHeroCopy[.follicular]!.hero)
        XCTAssertTrue(CycleContent.phaseHeroSubtext(day(11)).contains("Conception"))
        XCTAssertEqual(CycleContent.phaseHeroSubtext(day(20)), CycleContent.phaseHeroCopy[.luteal]!.sub)
    }

    /// On 21/7, 22/8, 23/9 and 24/10 — all selectable in the settings sheet — ovulation is predicted
    /// for a day she is still bleeding, so `phase` answers `.period`. Home keyed the peak copy off the
    /// phase and therefore said "Fertile window is open" on the one day it could have named, on
    /// exactly the cycles where the timing is hardest to work out unaided. The calendar was fixed for
    /// this case; the hero was not.
    func testAShortCyclePeakDayIsNamedEvenWhileSheIsStillBleeding() {
        for (cycleLength, periodLength) in [(21, 7), (22, 8), (23, 9), (24, 10)] {
            let peak = day(cycleLength - 14, cycleLength: cycleLength, periodLength: periodLength)
            XCTAssertEqual(peak.phase, .period, "the premise: this day is inside her period")
            XCTAssertTrue(peak.isOvulationDay)

            XCTAssertEqual(CycleContent.phaseHeroText(peak), CycleContent.phaseHeroCopy[.ovulatory]!.hero,
                           "\(cycleLength)/\(periodLength): her peak day must still be named")
            XCTAssertEqual(CycleContent.phaseSubLabel(peak), CycleContent.phaseLabel[.ovulatory]!)
            XCTAssertEqual(CycleContent.phaseHeroSubtext(peak), CycleContent.phaseHeroCopy[.ovulatory]!.sub)
            XCTAssertEqual(CycleContent.phaseTags(peak), CycleContent.phaseHeroCopy[.ovulatory]!.tags)
        }
    }

    /// The day before the peak on those same cycles: still bleeding, still fertile, not the peak —
    /// so it takes the fertile-window copy rather than being promoted with it.
    func testTheDayBeforeAShortCyclePeakIsStillTheRisingMessage() {
        let almost = day(6, cycleLength: 21, periodLength: 7)
        XCTAssertTrue(almost.isFertileButNotPeak)
        XCTAssertEqual(CycleContent.phaseHeroText(almost), "Fertile window is open")
    }

    // ── Food groups (meal logging, T26) ──

    func testEveryPhaseNamesFoodGroupsAndNamesNoneTwice() {
        XCTAssertEqual(Set(NutritionContent.phaseFoodGroups.keys), allPhases)
        for (phase, groups) in NutritionContent.phaseFoodGroups {
            XCTAssertFalse(groups.isEmpty, "phase \(phase) names no food groups")
            XCTAssertEqual(Set(groups).count, groups.count, "phase \(phase) names a group twice")
        }
    }

    func testEveryFoodGroupHasDistinctNonBlankCopy() {
        for group in FoodGroup.allCases {
            XCTAssertFalse(group.label.isBlank, "label blank for \(group.rawValue)")
            XCTAssertFalse(group.examples.isBlank, "examples blank for \(group.rawValue)")
        }
        XCTAssertEqual(Set(FoodGroup.allCases.map(\.label)).count, FoodGroup.allCases.count)
        XCTAssertEqual(Set(FoodGroup.allCases.map(\.examples)).count, FoodGroup.allCases.count)
    }

    /// ⚠️ The whole compliance position of the food-log card is that it *names categories and says
    /// nothing about what they do*. That is why it carries no citation, no disclaimer and no
    /// medical sign-off, while the focus-foods card directly above it — which does make claims —
    /// has all three.
    ///
    /// So the realistic failure is not a banned phrase; nobody is going to type "alkaline diet"
    /// here. It is one warm sentence added later — "protein supports egg quality" — that quietly
    /// moves this card into the category that needs substantiating under CAP Code 3.7, with every
    /// other guard still green. This is the test that notices.
    func testFoodLogCopyMakesNoHealthClaim() {
        let claimWords = [
            "boost", "improve", "helps you", "help you", "good for", "supports", "support your",
            "increases", "reduces", "prevents", "treats", "cures", "balances", "optimis",
            "fertility", "conceive", "egg quality", "hormone",
        ]
        for text in FoodLogCopy.allStrings {
            let lower = text.lowercased()
            for word in claimWords {
                XCTAssertFalse(lower.contains(word),
                    "\"\(word)\" makes the food-log card a claim surface. It has no citation and no "
                    + "sign-off — put it in phaseFoods, which has both. Copy: \(text)")
            }
        }
    }

    func testFoodLogSummaryDistinguishesAnEmptyDayAndNeverExceedsTheTotal() {
        let total = FoodGroup.allCases.count
        XCTAssertNotEqual(FoodLogCopy.summary(logged: 0, total: total),
                          FoodLogCopy.summary(logged: 1, total: total))
        XCTAssertTrue(FoodLogCopy.summary(logged: total, total: total).contains("\(total) of \(total)"))
        XCTAssertFalse(FoodLogCopy.summary(logged: 0, total: total).contains("0"),
                       "an empty day is an invitation, not a score of zero")
    }

    func testFoodLogPhaseLineNamesEveryGroupItWasGiven() {
        XCTAssertNil(FoodLogCopy.phaseLine([]))
        for phase in Phase.allCases {
            let groups = NutritionContent.phaseFoodGroups[phase]!
            let line = FoodLogCopy.phaseLine(groups)!
            for group in groups {
                XCTAssertTrue(line.lowercased().contains(group.label.lowercased()),
                              "\(phase) line omits \(group.label): \(line)")
            }
        }
    }

    func testSentenceListReadsAsEnglish() {
        XCTAssertEqual(FoodLogCopy.sentenceList([]), "")
        XCTAssertEqual(FoodLogCopy.sentenceList(["fruit"]), "fruit")
        XCTAssertEqual(FoodLogCopy.sentenceList(["fruit", "protein"]), "fruit and protein")
        XCTAssertEqual(FoodLogCopy.sentenceList(["fruit", "protein", "dairy"]),
                       "fruit, protein and dairy")
    }

    func testTagsPrependFertileWindowForNonOvulatoryFertileDaysOnly() {
        let base = CycleContent.phaseHeroCopy[.follicular]!.tags
        let fertile = CycleContent.phaseTags(day(11))
        XCTAssertEqual(fertile.first, "Fertile window")
        XCTAssertEqual(fertile.count, base.count + 1)
        // The peak day is not overlaid.
        XCTAssertEqual(CycleContent.phaseTags(day(14)), CycleContent.phaseHeroCopy[.ovulatory]!.tags)
        // Not fertile -> unchanged.
        XCTAssertEqual(CycleContent.phaseTags(day(7)), base)
    }

    /// `.ovulatory` is entered on `dayOfCycle == ovulationDay` and left the next day, so it is
    /// always exactly today — never a forecast. The sub-line had been written for an approaching
    /// window and said "expected in 1–2 days", which put the card at odds with its own hero, with
    /// the "Predicted ovulation: Day 14" printed directly beneath it on Home, and with Track.
    func testOvulatoryCopyNamesTheDayRatherThanForecastingIt() {
        let info = CycleEngine.cyclePhase(
            settings: CycleSettings(lastPeriodDate: CalendarDate.today().addingDays(-13),
                                    cycleLength: 28, periodLength: 5))
        XCTAssertEqual(info.dayOfCycle, 14)
        XCTAssertEqual(info.phase, .ovulatory, "day 14 of a 28-day cycle is the ovulation day itself")

        let sub = CycleContent.phaseHeroSubtext(info)
        for forecast in ["1–2 days", "1-2 days", "expected in", "days away", "approaching"] {
            XCTAssertFalse(sub.lowercased().contains(forecast.lowercased()),
                           "the one day she is ovulating must not be described as still to come: \(sub)")
        }
    }
}

private extension String {
    /// Kotlin `isNotBlank()` parity: non-empty after trimming whitespace.
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
