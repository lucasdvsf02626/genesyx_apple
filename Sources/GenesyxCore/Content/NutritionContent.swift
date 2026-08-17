import Foundation

/// Nutrition-screen content, ported verbatim from web `screens/Nutrition.tsx` (`PHASE_FOODS`,
/// `PHASE_DESCRIPTION`) + the supplement plan + `mockData.articles`. The Nutrition screen uses
/// this richer per-phase data, NOT the shorter `CycleContent.phaseFoods`.

/// Per-phase accent for food rows. UI-free: the actual color is applied in the app layer
/// (Android carried a Compose `Color`). One distinct accent per phase.
public enum FoodAccent: String, CaseIterable, Sendable {
    case period, follicular, ovulatory, luteal
}

/// Expandable focus-food row: accent dot + name + short blurb, expanding to a detailed blurb.
public struct PhaseFood: Hashable, Sendable {
    public let name: String
    public let shortDesc: String
    public let expandedDesc: String
    public let accent: FoodAccent

    public init(_ name: String, _ shortDesc: String, _ expandedDesc: String, _ accent: FoodAccent) {
        self.name = name
        self.shortDesc = shortDesc
        self.expandedDesc = expandedDesc
        self.accent = accent
    }
}

/// The food groups she can tick off for a day.
///
/// The Eatwell Guide's five, with fruit and vegetables split apart — the Guide counts them as one
/// group, but a day with fruit and no vegetables is precisely the day worth being able to record.
///
/// A fixed vocabulary rather than a food database, and that is the point rather than a shortcut.
/// Naming a group, and listing what is in it, states nothing about what any of it *does* — so this
/// screen carries no claim for a medical reviewer to sign off and none for the CAP Code to want
/// substantiated. Counting nutrients would need both, plus the food database that lives in the
/// deferred barcode work.
public enum FoodGroup: String, CaseIterable, Identifiable, Sendable {
    case vegetables, fruit, starchyCarbs, protein, dairy, oilsAndFats

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .vegetables: return "Vegetables"
        case .fruit: return "Fruit"
        case .starchyCarbs: return "Starchy carbs"
        case .protein: return "Protein"
        case .dairy: return "Dairy & alternatives"
        case .oilsAndFats: return "Oils & fats"
        }
    }

    /// Examples only, so she can tell which chip a meal belongs under. A list of what is in a group
    /// is a definition, not a health statement.
    public var examples: String {
        switch self {
        case .vegetables: return "Salad, greens, peppers, carrots"
        case .fruit: return "Berries, apples, bananas, citrus"
        case .starchyCarbs: return "Potatoes, bread, rice, pasta, oats"
        case .protein: return "Beans, pulses, fish, eggs, meat, tofu"
        case .dairy: return "Milk, yoghurt, cheese, fortified alternatives"
        case .oilsAndFats: return "Olive oil, nuts, seeds, avocado"
        }
    }
}

/// Reader-facing copy for the food log.
///
/// In Core rather than in the view for the same reason `HydrationCoach`'s copy is: it is the only
/// way the content guards can see it. Copy written inline in a SwiftUI body is copy no test scans.
public enum FoodLogCopy {
    public static let title = "What you ate today"

    /// The whole tone of the card in one line. A food log is the easiest surface in a fertility app
    /// to turn into a scoreboard, and a scoreboard is the thing she least needs from it.
    public static let footnote = "A record, not a target. Nothing here is scored, and a blank day costs you nothing."

    public static func summary(logged: Int, total: Int) -> String {
        logged == 0
            ? "Tap a group when you have eaten something from it."
            : "\(logged) of \(total) groups so far today."
    }

    /// Names the groups the focus-foods card above already leans on. A statement about the screen,
    /// not advice — see `NutritionContent.phaseFoodGroups`.
    public static func phaseLine(_ groups: [FoodGroup]) -> String? {
        guard !groups.isEmpty else { return nil }
        return "Your focus foods this phase lean on \(sentenceList(groups.map { $0.label.lowercased() }))."
    }

    static func sentenceList(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }
        return items.dropLast().joined(separator: ", ") + " and " + last
    }

    /// Everything this card can render, for the banned-phrase guard.
    public static var allStrings: [String] {
        var out = [title, footnote]
        out += FoodGroup.allCases.flatMap { [$0.label, $0.examples] }
        out += (0...FoodGroup.allCases.count).map { summary(logged: $0, total: FoodGroup.allCases.count) }
        out += Phase.allCases.compactMap { phaseLine(NutritionContent.phaseFoodGroups[$0] ?? []) }
        return out
    }
}

/// Supplement-plan item shown as the F/O/D/Z stack + "Review Plan" dialog.
public struct SupplementPlanItem: Hashable, Sendable {
    public let initial: String
    public let name: String
    public let rationale: String
    /// What the Daily Log ticks and stores for this item. Separate from `name` because `name`
    /// carries a dose the tick-list has no room for, and because this string is persisted — it is
    /// the key a logged day is recognised by, so it must not drift when the displayed dose is
    /// re-worded.
    public let logLabel: String

    public init(_ initial: String, _ name: String, _ rationale: String, logLabel: String) {
        self.initial = initial; self.name = name; self.rationale = rationale
        self.logLabel = logLabel
    }
}

/// Learn-more article tile (title + read time), from `mockData.articles`.
public struct Article: Identifiable, Hashable, Sendable {
    public let title: String
    public let read: String
    public var id: String { title }
    public init(_ title: String, _ read: String) { self.title = title; self.read = read }
}

public enum NutritionContent {

    public static let phaseFoods: [Phase: [PhaseFood]] = [
        .period: [
            PhaseFood(
                "Iron-rich foods",
                "Replenish iron lost during bleeding.",
                "Red meat, lentils, and dark leafy greens help restore iron levels. Pair with vitamin C (like lemon juice) to boost absorption. Aim for 2–3 servings daily during your period.",
                .period
            ),
            PhaseFood(
                "Anti-inflammatory foods",
                "Reduce cramping and inflammation.",
                "Omega-3 fatty acids found in salmon, chia seeds, and walnuts reduce prostaglandins that cause cramps. Turmeric in warm milk is a traditional remedy with scientific backing.",
                .period
            ),
            PhaseFood(
                "Warming foods",
                "Support circulation and comfort.",
                "Ginger tea, warm soups, and cooked root vegetables are easier to digest and support circulation. Avoid cold, raw foods which can increase cramping for some people.",
                .period
            ),
        ],
        .follicular: [
            PhaseFood(
                "Fermented foods",
                "Support gut health and rising estrogen.",
                "Yoghurt, kefir, kimchi, and sauerkraut feed your gut microbiome, which plays a role in metabolising estrogen. A healthy gut supports hormonal balance throughout your cycle.",
                .follicular
            ),
            PhaseFood(
                "Sprouted seeds",
                "Phytoestrogens to support follicle growth.",
                "Flaxseeds and pumpkin seeds contain lignans and zinc that support follicle development. Add to smoothies, yoghurt, or salads. Start seed cycling with flax + pumpkin in the first half of your cycle.",
                .follicular
            ),
            PhaseFood(
                "Light proteins",
                "Fuel energy without heaviness.",
                "Eggs, tofu, and legumes provide amino acids for tissue repair and hormone production. Your digestion is stronger in the follicular phase, so it is a good time to try new foods.",
                .follicular
            ),
        ],
        .ovulatory: [
            PhaseFood(
                "Leafy greens",
                "Folate-rich foods to support egg quality.",
                "Spinach, kale, and rocket are rich in folate (B9), which supports egg quality and early fetal development if conception occurs. Aim for 2 generous handfuls per day during your fertile window.",
                .ovulatory
            ),
            PhaseFood(
                "Complex carbs",
                "Steady energy and balanced blood sugar.",
                "Quinoa, sweet potato, and brown rice provide slow-release energy to support your peak activity levels. Avoid refined sugars which can cause energy crashes during your fertile window.",
                .ovulatory
            ),
            PhaseFood(
                "Zinc-rich foods",
                "Support ovulation and immune function.",
                "Pumpkin seeds, shellfish, and beef liver are excellent zinc sources. Zinc is essential for the LH surge that triggers ovulation. Low zinc is linked to irregular ovulation.",
                .ovulatory
            ),
            PhaseFood(
                "Antioxidant foods",
                "Protect egg quality from oxidative stress.",
                "Berries, colourful peppers, and tomatoes are rich in vitamins C and E. Antioxidants neutralise free radicals that can damage eggs. Include a rainbow of colours in each meal.",
                .ovulatory
            ),
        ],
        .luteal: [
            PhaseFood(
                "Magnesium-rich foods",
                "Ease PMS symptoms and support sleep.",
                "Dark chocolate (70%+), almonds, spinach, and pumpkin seeds are high in magnesium. Studies show magnesium supplementation reduces PMS severity including mood changes, bloating, and cramps.",
                .luteal
            ),
            PhaseFood(
                "B6 foods",
                "Support progesterone and reduce mood swings.",
                "Salmon, chicken, bananas, and sunflower seeds are rich in vitamin B6, which supports progesterone production and serotonin synthesis. Low B6 is strongly associated with PMS.",
                .luteal
            ),
            PhaseFood(
                "Fibre-rich foods",
                "Support estrogen clearance.",
                "As progesterone rises, your gut slows down. Oats, flaxseeds, and vegetables support bowel regularity and help clear excess estrogen from the body, reducing PMS bloating.",
                .luteal
            ),
            PhaseFood(
                "Complex carbs",
                "Reduce cravings and stabilise mood.",
                "Serotonin dips in the luteal phase, causing carb cravings. Complex carbs like oats, lentils, and whole grain bread boost serotonin naturally without the crash from refined sugar.",
                .luteal
            ),
        ],
    ]

    /// Which groups the phase's focus foods above already lean on — read straight off the
    /// `phaseFoods` copy, entry by entry, so it repeats guidance rather than adding any.
    ///
    /// That is what keeps this line free of a sign-off: it is a statement about the screen, the
    /// same move `phaseChangeCard` makes. If it ever starts saying a group is *good for* a phase,
    /// it has become a claim and needs the reviewer that `phaseFoods` already had.
    public static let phaseFoodGroups: [Phase: [FoodGroup]] = [
        .period: [.protein, .vegetables, .oilsAndFats],
        .follicular: [.dairy, .protein, .oilsAndFats],
        .ovulatory: [.vegetables, .fruit, .protein, .starchyCarbs],
        .luteal: [.starchyCarbs, .vegetables, .protein, .oilsAndFats],
    ]

    public static let phaseDescription: [Phase: String] = [
        .period: "Foods to restore and replenish during your cycle.",
        .follicular: "Foods to support rising energy and hormone balance.",
        .ovulatory: "Foods chosen to gently support your body through this week of your cycle.",
        .luteal: "Foods to ease PMS and support your winding-down phase.",
    ]

    public static let supplementPlan: [SupplementPlanItem] = [
        SupplementPlanItem("F", "Folate (400–800 mcg)", "Supports egg quality and early cell development.", logLabel: "Folate"),
        SupplementPlanItem("O", "Omega-3 (DHA/EPA)", "Hormone balance and reduced inflammation.", logLabel: "Omega-3"),
        SupplementPlanItem("D", "Vitamin D (600–1000 IU)", "Supports ovulation and overall wellbeing.", logLabel: "Vitamin D"),
        SupplementPlanItem("Z", "Zinc (8–11 mg)", "Supports the LH surge that triggers ovulation.", logLabel: "Zinc"),
    ]

    /// The Daily Log's supplement tick-list — **derived from the plan, never typed out again.**
    ///
    /// The two lists were maintained separately and drifted: the plan named Zinc, the tick-list
    /// offered Iron. Zinc was therefore impossible to log, "4 of 4 taken today" was unreachable, and
    /// Iron — which is in nobody's plan here — counted toward it. Deriving the list is what makes
    /// that class of drift unrepresentable rather than merely tested for.
    public static let supplementLogOptions: [String] = supplementPlan.map(\.logLabel)

    public static let articles: [Article] = [
        Article("Eating for your luteal phase", "4 min read"),
        Article("How hydration shapes fertility", "3 min read"),
        Article("A gentle guide to supplements", "6 min read"),
    ]
}
