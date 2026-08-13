import SwiftUI
import GenesyxCore

/// The onboarding state machine: Splash → Intro → Quiz → Readiness Summary → (Waitlist) → app.
/// Ported from the Android onboarding screens, and now with the real brand egg artwork on the
/// splash rather than the `BrandOrb` blobs that stood in for it.
struct OnboardingFlowView: View {

    let onFinished: () -> Void

    /// Holds the quiz answers past the end of the quiz. They are given before there is an account,
    /// so they are written on-device here and owed to her `profiles` row until sign-in provides a
    /// user id to write them under.
    @EnvironmentObject private var prefs: PreferencesRepository
    /// Reached only for the waiting-list write, which happens before there is an account — so it
    /// goes straight to the backend rather than through a session-scoped repository.
    @EnvironmentObject private var container: AppContainer

    private enum Step { case splash, intro, quiz, summary, waitlist }
    @State private var step: Step = .splash
    @State private var showAuth = false

    var body: some View {
        ZStack {
            GenesyxColor.background.ignoresSafeArea()
            switch step {
            case .splash:
                SplashView(onStart: { step = .intro }, onSignIn: { showAuth = true })
            case .intro:
                OnboardingIntroView(onContinue: { step = .quiz }, onBack: { step = .splash })
            case .quiz:
                QuizView(onComplete: { answers in
                    prefs.recordQuizAnswers(answers)
                    step = .summary
                }, onBack: { step = .intro })
            case .summary:
                ReadinessSummaryView(onUnlockGuide: { step = .waitlist }, onContinue: { showAuth = true }, onBack: { step = .quiz })
            case .waitlist:
                WaitlistView(
                    onJoin: { email in
                        guard let backend = container.backend else { throw RemoteError.notAvailable }
                        try await backend.joinWaitlist(email: email)
                    },
                    onContinue: { showAuth = true },
                    onBack: { step = .summary }
                )
            }
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
                Text("GENESYX").font(.gxTitle).tracking(2).foregroundStyle(GenesyxColor.foreground)
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

    private let questions = QuizContent.questions
    @State private var step = 0
    @State private var answers: [String: String] = [:]
    @State private var pendingFact: DidYouKnow?

    private var question: QuizQuestion { questions[step] }
    private var selected: String? { answers[question.id] }
    private var isLast: Bool { step == questions.count - 1 }

    private func advance() { if isLast { onComplete(answers) } else { step += 1 } }
    private func onContinue() { if let fact = question.fact { pendingFact = fact } else { advance() } }

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
    let onUnlockGuide: () -> Void
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
                GxPrimaryButton(title: "Unlock My Free Guide", leadingSystemImage: "book", action: onUnlockGuide)
                GxGhostButton(title: "Register / Login to continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Waitlist

private struct WaitlistView: View {
    /// Stores the address on the waiting list. Throws when it can't — the confirmation below is
    /// shown only after this returns, so the screen never claims a place it didn't secure.
    let onJoin: (String) async throws -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var email = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var error: String?

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard EmailValidator.isValid(trimmed) else {
            error = "Please enter a valid email address."
            return
        }
        submitting = true
        Task {
            do {
                try await onJoin(trimmed)
                submitted = true
            } catch {
                self.error = "We couldn't add you to the list just now. Please check your connection and try again."
            }
            submitting = false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if submitted {
                    Spacer().frame(height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 64, height: 64).background(GenesyxColor.primary).clipShape(Circle())
                    Spacer().frame(height: 20)
                    Text("You're on the list").font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                    Spacer().frame(height: 8)
                    Text("Thanks — you're on the Genesyx early-access list. Register to open your fertility nutrition guidance inside the app.")
                        .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
                    Spacer().frame(height: 28)
                    GxPrimaryButton(title: "Register / Login to continue", action: onContinue)
                } else {
                    Spacer().frame(height: 24)
                    Eyebrow("Free with early access", color: GenesyxColor.primary)
                    Spacer().frame(height: 8)
                    Text("A gentle guide to fertility nutrition")
                        .font(.gxTitle).foregroundStyle(GenesyxColor.foreground).multilineTextAlignment(.center)
                    Spacer().frame(height: 8)
                    Text("Join the Genesyx early-access list — your fertility nutrition guidance is waiting inside the app once you register.")
                        .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
                    Spacer().frame(height: 20)
                    TextField("your@email.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16).frame(height: 52)
                        .background(GenesyxColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(error == nil ? GenesyxColor.border : GenesyxColor.destructive, lineWidth: 1))
                        .onChange(of: email) { _ in error = nil }
                    if let error {
                        Text(error).font(.gxBodySmall).foregroundStyle(GenesyxColor.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                    }
                    Spacer().frame(height: 16)
                    GxPrimaryButton(title: "Join the Waiting List", enabled: !submitting, action: submit)
                    GxGhostButton(title: "Register / Login to continue", action: onContinue)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
