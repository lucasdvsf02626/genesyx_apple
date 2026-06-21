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
        .ovulatory: PhaseHeroCopy(
            hero: "High chance of conception today",
            sub: "Ovulation expected in 1–2 days. Stay hydrated and rested.",
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

    public static func phaseSubLabel(_ phase: Phase, inFertile: Bool) -> String {
        inFertile ? "Fertile window" : phaseLabel[phase]!
    }

    public static func phaseHeroText(_ phase: Phase, inFertile: Bool) -> String {
        (inFertile && phase != .ovulatory) ? "Fertile window is open" : phaseHeroCopy[phase]!.hero
    }

    public static func phaseHeroSubtext(_ phase: Phase, inFertile: Bool) -> String {
        if inFertile && phase != .ovulatory {
            return "Conception chances are rising — stay hydrated and prioritise rest."
        } else {
            return phaseHeroCopy[phase]!.sub
        }
    }

    public static func phaseTags(_ phase: Phase, inFertile: Bool) -> [String] {
        let base = phaseHeroCopy[phase]!.tags
        return (inFertile && phase != .ovulatory) ? ["Fertile window"] + base : base
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
