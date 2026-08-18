import SwiftUI
import GenesyxCore

/// The onboarding state machine: Splash → Intro → Quiz → Readiness Summary → app.
/// Ported from the Android onboarding screens, and now with the real brand egg artwork on the
/// splash rather than the `BrandOrb` blobs that stood in for it.
struct OnboardingFlowView: View {

    let onFinished: () -> Void

    /// Holds the quiz answers past the end of the quiz. They are given before there is an account,
    /// so they are written on-device here and owed to her `profiles` row until sign-in provides a
    /// user id to write them under.
    @EnvironmentObject private var prefs: PreferencesRepository
    /// The consent screen writes here. Like the quiz answers, the grant is given before there is an
    /// account, so it is recorded on-device and owed to `consent_events` until sign-in.
    @EnvironmentObject private var consent: ConsentRepository
    /// `.consent` sits immediately before `.quiz` because the quiz is the first thing that asks her
    /// about her body — Article 9 permission has to exist before the first special-category answer
    /// is written, not before the first one is synced.
    private enum Step { case splash, intro, consent, consentDeclined, quiz, summary }
    @State private var step: Step = .splash
    @State private var showAuth = false
    @State private var showGuide = false

    var body: some View {
        ZStack {
            GenesyxColor.background.ignoresSafeArea()
            switch step {
            case .splash:
                SplashView(onStart: { step = .intro }, onSignIn: { showAuth = true })
            case .intro:
                OnboardingIntroView(onContinue: { step = .consent }, onBack: { step = .splash })
            case .consent:
                ConsentView(
                    onAgree: { consent.grant(); step = .quiz },
                    onDecline: { step = .consentDeclined },
                    onBack: { step = .intro })
            case .consentDeclined:
                // Straight to the summary, skipping the quiz. Nothing is recorded on the way, which
                // is the whole point — the summary is fixed guidance, not anything derived from her.
                ConsentDeclinedView(
                    onReconsider: { step = .consent },
                    onContinue: { step = .summary })
            case .quiz:
                QuizView(initialAnswers: prefs.quizAnswers, onComplete: { answers in
                    prefs.recordQuizAnswers(answers)
                    step = .summary
                }, onBack: { step = .consent })
            case .summary:
                // Back lands where she actually came from. A woman who declined never saw the quiz,
                // and sending her into it from here would ask her the health questions she had just
                // refused to have recorded.
                ReadinessSummaryView(onOpenGuide: { showGuide = true }, onContinue: { showAuth = true },
                                     onBack: { step = consent.isActive ? .quiz : .consentDeclined })
            }
        }
        // The guide is bundled, so this opens with no account, no connection and no backend. It is
        // a sheet rather than a step so dismissing it lands back on the summary by construction
        // rather than by remembering to route there.
        .sheet(isPresented: $showGuide) {
            FreeGuideScreen()
        }
        // Auth gates the dashboard (Android parity): every onboarding exit routes through Auth,
        // and only a successful sign-in calls `onFinished` (which sets onboardingComplete → main
        // tabs), so back cannot return to the gate. In local-only v1, AuthView falls back to a
        // permissive mock that does not verify passwords; the gate still enforces "go through Auth."
        .fullScreenCover(isPresented: $showAuth) {
            AuthView(onSignedIn: onFinished)
        }
    }
}

// MARK: - Splash

private struct SplashView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            // The floating egg motif, at the four positions the stand-in orbs held — that
            // composition was already tuned against the copy, so only the shapes changed.
            //
            // Three deliberate departures from the orbs' numbers:
            //
            // Sizes are up ~15% — a crescent fills less of its frame than a circle, so a 150pt egg
            // reads smaller than a 150pt orb did.
            //
            // Fades are roughly half the orbs' 0.7–0.9. Those were near-white and these are fully
            // saturated, so carrying the old values across put colour behind the headline rather
            // than behind the screen.
            //
            // The fourth moved out of the bottom-right corner into the gap above the button. That
            // corner is where the "not medical advice" line wraps, and the line staying legible on
            // a first run matters more than the wallpaper being symmetrical.
            BrandEgg(.warm, size: 170, fade: 0.55).rotationEffect(.degrees(-20)).offset(x: -118, y: -262)
            BrandEgg(.cool, size: 140, fade: 0.45).rotationEffect(.degrees(155)).offset(x: 116, y: -168)
            BrandEgg(.cool, size: 110, fade: 0.38).rotationEffect(.degrees(-150)).offset(x: -132, y: 196)
            BrandEgg(.warm, size: 124, fade: 0.42).rotationEffect(.degrees(30)).offset(x: 142, y: 84)

            VStack(spacing: 0) {
                Image("brand_lockup")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 220, height: 54)
                    .accessibilityLabel("Genesyx")
                    .accessibilityIdentifier("onboarding.brandLogo")
                Spacer()
                Eyebrow("Step into the future of fertility", color: GenesyxColor.primary)
                Spacer().frame(height: 16)
                Text("Feel informed, supported and ready for your conception journey.")
                    .font(.gxDisplayLarge)
                    .foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 20)
                Text("A premium, gently-guided companion blending cycle awareness, nutrition and supplement support.")
                    .font(.gxBody)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.center)
                Spacer()
                GxPrimaryButton(title: "Start Your Personalised Quiz", trailingSystemImage: "arrow.right", action: onStart)
                GxGhostButton(title: "Sign in", action: onSignIn)
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(GenesyxColor.primary)
                    Text("Educational wellness support — not medical advice. Consult a healthcare professional for medical concerns.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Intro

private struct OnboardingIntroView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let bg: Color
        let title: String
        let desc: String
    }

    private let benefits: [Benefit] = [
        .init(icon: "heart", tint: GenesyxColor.electricLavender, bg: GenesyxColor.electricLavender.tintOnWhite(0.12),
              title: "Understand your cycle", desc: "Recognise patterns with calm, clear guidance."),
        .init(icon: "leaf", tint: GenesyxColor.electricBlue, bg: GenesyxColor.powderBlue.tintOnWhite(0.30),
              title: "Support fertility nutrition", desc: "Cycle-aware food and supplement focus."),
        .init(icon: "chart.bar", tint: GenesyxColor.electricPink, bg: GenesyxColor.powderPink.tintOnWhite(0.30),
              title: "Receive tailored insights", desc: "Gentle observations based on your tracking."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { GxBackButton(action: onBack); Spacer() }
                Text("Your fertility preparation, gently guided")
                    .font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
                // The standfirst that sat here named cycle awareness, nutrition and insights — the
                // same three things the cards below name, with icons, one line each. The splash had
                // already said it too, on the screen immediately before this one.
                Spacer().frame(height: 32)
                ForEach(benefits) { b in
                    HStack(spacing: 16) {
                        Image(systemName: b.icon)
                            .foregroundStyle(b.tint)
                            .frame(width: 48, height: 48)
                            .background(b.bg)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                            Text(b.desc).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(GenesyxColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.bottom, 12)
                }
                Spacer().frame(height: 16)
                GxPrimaryButton(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Quiz

private struct QuizView: View {
    /// Hands the answers up rather than keeping them: every question is answered before Continue
    /// unlocks, so completion is the one point at which they are whole.
    let onComplete: ([String: String]) -> Void
    let onBack: () -> Void
    /// What she has already answered, if she is arriving back here from the summary. `@State` is
    /// destroyed when this view leaves the hierarchy, so without seeding it the back button dropped
    /// her on question 1 of 5 with all five answers cleared and made her type them all again.
    let initialAnswers: [String: String]

    init(initialAnswers: [String: String] = [:],
         onComplete: @escaping ([String: String]) -> Void,
         onBack: @escaping () -> Void) {
        self.initialAnswers = initialAnswers
        self.onComplete = onComplete
        self.onBack = onBack
        _answers = State(initialValue: initialAnswers)
        // Open on the first question she has not answered, so returning lands her where she stopped
        // rather than making her page past work she has already done.
        let firstUnanswered = QuizContent.questions.firstIndex { initialAnswers[$0.id] == nil }
        _step = State(initialValue: firstUnanswered ?? max(QuizContent.questions.count - 1, 0))
    }

    private let questions = QuizContent.questions
    @State private var step: Int
    @State private var answers: [String: String]
    @State private var pendingFact: DidYouKnow?

    private var question: QuizQuestion { questions[step] }
    private var selected: String? { answers[question.id] }
    private var isLast: Bool { step == questions.count - 1 }

    private func advance() { if isLast { onComplete(answers) } else { step += 1 } }
    private func onContinue() { if let fact = question.fact { pendingFact = fact } else { advance() } }

    /// Leaves with no key at all for this question — not an option id standing in for silence. It
    /// removes rather than merely skipping the write, because she can answer, go back, and skip.
    /// No "Did you know?" either: the fact is what follows engaging with the question.
    private func skip() {
        answers.removeValue(forKey: question.id)
        advance()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                GxBackButton(action: { if step == 0 { onBack() } else { step -= 1 } })
                ProgressView(value: Double(step + 1), total: Double(questions.count))
                    .tint(GenesyxColor.primary)
                Text("\(step + 1)/\(questions.count)")
                    .font(.gxBodySmall.weight(.semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer().frame(height: 32)
            Text(question.question).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
            Spacer().frame(height: 8)
            Text(question.helper).font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
            Spacer().frame(height: 28)
            ForEach(question.options, id: \.id) { option in
                GxOptionPill(text: option.label, selected: selected == option.id) {
                    answers[question.id] = option.id
                }
                // Identified by shape rather than by copy, so a UI test can walk the quiz without
                // pinning the wording — which T7 is about to rewrite.
                .accessibilityIdentifier("quiz.option")
                .padding(.bottom, 12)
            }
            Spacer()
            GxPrimaryButton(title: isLast ? "See My Summary" : "Continue", enabled: selected != nil, action: onContinue)
            if question.isOptional {
                GxGhostButton(title: "Skip this question", action: skip)
                    .accessibilityIdentifier("quiz.skip")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .alert(pendingFact?.title ?? "", isPresented: Binding(
            get: { pendingFact != nil },
            set: { if !$0 { pendingFact = nil } }
        )) {
            Button("Continue") { pendingFact = nil; advance() }
        } message: {
            Text(pendingFact?.body ?? "")
        }
    }
}

// MARK: - Readiness summary

private struct ReadinessSummaryView: View {
    let onOpenGuide: () -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    private let insights: [(icon: String, label: String, value: String)] = [
        ("calendar", "Cycle awareness", "Build a steady tracking rhythm"),
        ("leaf", "Nutrition focus", "Folate, omega-3, and zinc-rich foods"),
        ("sparkles", "Daily support", "Gentle prompts and supplement plan"),
    ]
    private let nextSteps = [
        "Start logging your cycle for 7 days",
        "Review your personalised nutrition focus",
        "Save the free fertility nutrition guide",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)
                BrandOrb(size: 80)
                Spacer().frame(height: 20)
                Eyebrow("Your readiness summary", color: GenesyxColor.primary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(GenesyxColor.primary.tintOnWhite(0.10))
                    .clipShape(Capsule())
                Spacer().frame(height: 12)
                Text("A thoughtful starting point")
                    .font(.gxTitle).foregroundStyle(GenesyxColor.foreground).multilineTextAlignment(.center)
                Spacer().frame(height: 8)
                Text("You're already taking meaningful steps. Here's where Genesyx will support you next.")
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)

                Spacer().frame(height: 28)
                VStack(spacing: 16) {
                    ForEach(insights, id: \.label) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .foregroundStyle(GenesyxColor.primary)
                                .frame(width: 44, height: 44)
                                .background(GenesyxColor.primary.tintOnWhite(0.10))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Eyebrow(item.label, color: GenesyxColor.mutedForeground)
                                Text(item.value).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Spacer().frame(height: 16)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested next steps").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    ForEach(nextSteps, id: \.self) { s in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                                .foregroundStyle(GenesyxColor.primary)
                            Text(s).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(GenesyxColor.powderBlue.tintOnWhite(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Spacer().frame(height: 24)
                GxPrimaryButton(title: "Open My Free Guide", leadingSystemImage: "book", action: onOpenGuide)
                GxGhostButton(title: "Register / Login to continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
