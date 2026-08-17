import Foundation

/// Phase copy + foods, ported verbatim from web `cycle.ts` (see docs/DATA_LAYER.md Part C).

public struct FocusCopy: Hashable, Sendable {
    public let title: String
    public let body: String
    public init(_ title: String, _ body: String) { self.title = title; self.body = body }
}

public struct PhaseHeroCopy: Hashable, Sendable {
    public let hero: String
    public let sub: String
    public let tags: [String]
    public let focus: FocusCopy
}

public struct FocusFood: Hashable, Sendable {
    public let title: String
    public let desc: String
    public init(_ title: String, _ desc: String) { self.title = title; self.desc = desc }
}

public enum CycleContent {

    public static let phaseLabel: [Phase: String] = [
        .period: "Period",
        .follicular: "Follicular Phase",
        .ovulatory: "Ovulatory Phase",
        .luteal: "Luteal Phase",
    ]

    public static let phaseHeroCopy: [Phase: PhaseHeroCopy] = [
        .period: PhaseHeroCopy(
            hero: "Rest and replenish your body",
            sub: "Energy is naturally lower — choose iron-rich, warming meals.",
            tags: ["Low estrogen", "Restore iron"],
            focus: FocusCopy("Add a warm iron-rich meal", "Lentils, beef, or dark greens help replenish what's lost.")
        ),
        .follicular: PhaseHeroCopy(
            hero: "Building energy for ovulation",
            sub: "Estrogen is rising. Focus on fresh, nutrient-dense foods.",
            tags: ["Estrogen rising", "Building energy"],
            focus: FocusCopy("Add 2 cups of leafy greens", "Folate-forward foods support egg quality.")
        ),
        // `.ovulatory` is exactly one day — `CycleEngine` enters it on `dayOfCycle == ovulationDay`
        // and leaves it the next day. The sub-line was written for an approaching window and read
        // "Ovulation expected in 1–2 days", which contradicted its own hero, the "Predicted
        // ovulation: Day 14" directly beneath it, and Track saying "Day 14 · Predicted ovulation day".
        .ovulatory: PhaseHeroCopy(
            hero: "High chance of conception today",
            sub: "This is your predicted ovulation day. Stay hydrated and rested.",
            tags: ["High estrogen", "Peak energy"],
            focus: FocusCopy("Hydrate and prioritise protein", "Eggs, salmon, and avocado support hormone balance.")
        ),
        .luteal: PhaseHeroCopy(
            hero: "Slow down and nourish",
            sub: "Progesterone rises. Choose magnesium-rich foods to ease symptoms.",
            tags: ["Progesterone rising", "Lower energy"],
            focus: FocusCopy("Try a magnesium-rich snack", "Pumpkin seeds, dark chocolate, or bananas help mood + sleep.")
        ),
    ]

    // ── Fertile-window overlay (ports lib/cycleEngine.ts). When the day is in the fertile window
    // and it isn't the ovulation day itself, the hero copy switches to "fertile window" messaging.

    /// Which copy the hero speaks in. Taken from the day rather than from `phase`, because on a short
    /// cycle the peak day lands inside the period and `phase` reports `.period` — see
    /// `CyclePhaseInfo.isOvulationDay`. Home asked the phase and so told a woman on a 21-day cycle
    /// "Fertile window is open" on the one day it could have named.
    static func heroPhase(_ info: CyclePhaseInfo) -> Phase {
        info.isOvulationDay ? .ovulatory : info.phase
    }

    public static func phaseSubLabel(_ info: CyclePhaseInfo) -> String {
        info.isFertileButNotPeak ? "Fertile window" : phaseLabel[heroPhase(info)]!
    }

    public static func phaseHeroText(_ info: CyclePhaseInfo) -> String {
        info.isFertileButNotPeak ? "Fertile window is open" : phaseHeroCopy[heroPhase(info)]!.hero
    }

    public static func phaseHeroSubtext(_ info: CyclePhaseInfo) -> String {
        info.isFertileButNotPeak
            ? "Conception chances are rising — stay hydrated and prioritise rest."
            : phaseHeroCopy[heroPhase(info)]!.sub
    }

    public static func phaseTags(_ info: CyclePhaseInfo) -> [String] {
        let base = phaseHeroCopy[heroPhase(info)]!.tags
        return info.isFertileButNotPeak ? ["Fertile window"] + base : base
    }

    public static let phaseFoods: [Phase: [FocusFood]] = [
        .period: [
            FocusFood("Lentils & beans", "Plant iron to replenish what's lost during menstruation."),
            FocusFood("Dark leafy greens", "Spinach and kale pair iron with folate for steady energy."),
            FocusFood("Bone broth", "Warming, mineral-rich, gentle on a tender gut."),
            FocusFood("Dark chocolate", "Magnesium to soften cramps and lift mood."),
        ],
        .follicular: [
            FocusFood("Sprouted grains", "Steady carbs for rising estrogen and morning energy."),
            FocusFood("Fermented foods", "Kimchi or kefir support estrogen metabolism."),
            FocusFood("Citrus & berries", "Vitamin C supports collagen and egg quality."),
            FocusFood("Pumpkin seeds", "Zinc to fuel the building phase of your cycle."),
        ],
        .ovulatory: [
            FocusFood("Wild salmon", "Omega-3s support hormone balance at ovulation."),
            FocusFood("Avocado", "Healthy fats help your body use estrogen well."),
            FocusFood("Eggs", "Choline and B12 — a complete fertility breakfast."),
            FocusFood("Leafy greens", "Folate supports cell division and conception."),
        ],
        .luteal: [
            FocusFood("Sweet potato", "Slow carbs to steady progesterone-driven cravings."),
            FocusFood("Pumpkin seeds", "Magnesium to ease PMS and improve sleep."),
            FocusFood("Bananas", "B6 to lift mood as the luteal phase winds down."),
            FocusFood("Turkey", "Tryptophan helps with rest and calm."),
        ],
    ]
}
