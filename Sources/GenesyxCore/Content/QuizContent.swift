import Foundation

/// Onboarding quiz content — verbatim from the web app (mockData.ts) + screenshots.

public struct QuizOption: Hashable, Sendable {
    public let id: String
    public let label: String
    public init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

public struct DidYouKnow: Hashable, Sendable {
    public let title: String
    public let body: String
    public init(title: String, body: String) { self.title = title; self.body = body }
}

public struct QuizQuestion: Hashable, Sendable {
    public let id: String
    public let question: String
    public let helper: String
    public let options: [QuizOption]
    /// Shown after answering this question, before advancing.
    public let fact: DidYouKnow?

    public init(
        id: String,
        question: String,
        helper: String,
        options: [QuizOption],
        fact: DidYouKnow? = nil
    ) {
        self.id = id
        self.question = question
        self.helper = helper
        self.options = options
        self.fact = fact
    }
}

public enum QuizContent {

    public static let questions: [QuizQuestion] = [
        QuizQuestion(
            id: "stage",
            question: "Where are you in your conception journey?",
            helper: "There's no wrong answer — we'll tailor your experience.",
            options: [
                QuizOption("exploring", "Just starting to think about it"),
                QuizOption("preparing", "Actively preparing my body"),
                QuizOption("trying", "Trying to conceive now"),
                QuizOption("support", "Looking for extra support"),
            ]
        ),
        QuizQuestion(
            id: "cycle",
            question: "How regular does your cycle usually feel?",
            helper: "An honest answer helps us personalise your insights.",
            options: [
                QuizOption("very", "Very regular, predictable"),
                QuizOption("mostly", "Mostly regular with small shifts"),
                QuizOption("irregular", "Often irregular"),
                QuizOption("unsure", "I'm not sure yet"),
            ],
            fact: DidYouKnow(
                title: "Did you know?",
                body: "Only about 13% of cycles are exactly 28 days. A healthy cycle can range "
                    + "from 21 to 35 days — your rhythm is uniquely yours, and tracking it reveals "
                    + "your most fertile window."
            )
        ),
        QuizQuestion(
            id: "supplements",
            question: "Are you currently taking fertility supplements?",
            helper: "We'll build a plan that fits where you are.",
            options: [
                QuizOption("yes", "Yes, a full routine"),
                QuizOption("some", "A few key ones"),
                QuizOption("no", "Not yet"),
                QuizOption("guidance", "I'd love guidance on this"),
            ]
        ),
        QuizQuestion(
            id: "gender",
            question: "Do you have a gender preference for your baby?",
            helper: "This is just for you — we keep it gentle and private.",
            options: [
                QuizOption("girl", "A girl"),
                QuizOption("boy", "A boy"),
                QuizOption("either", "Either is wonderful"),
                QuizOption("surprise", "Keep it a surprise"),
            ],
            fact: DidYouKnow(
                title: "Did you know?",
                body: "Research suggests that timing, diet, and even pH balance can subtly "
                    + "influence the likelihood of conceiving a boy or girl. Nothing is guaranteed "
                    + "— but small, gentle shifts can support your hopes."
            )
        ),
        QuizQuestion(
            id: "support",
            question: "What would you like the most support with?",
            helper: "Choose what feels most important right now.",
            options: [
                QuizOption("nutrition", "Fertility nutrition guidance"),
                QuizOption("tracking", "Understanding my cycle"),
                QuizOption("supplements", "Supplement support"),
                QuizOption("emotional", "Feeling calm and informed"),
            ]
        ),
    ]
}
