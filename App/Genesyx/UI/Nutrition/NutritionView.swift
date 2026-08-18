import SwiftUI
import GenesyxCore

/// Nutrition — phase-aware focus foods, hydration, supplement plan, and articles.
/// Ported from the Android `NutritionScreen` + `NutritionViewModel`.
struct NutritionView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var ph: PhRepository

    private let today = CalendarDate.today()
    /// The one goal every other hydration surface is drawn against — the streak, the 7-day "on
    /// goal" count, the water challenge and the goal-reached notification. Typed out again here,
    /// this screen would drift from all of them the day the constant changes.
    private let waterGoalMl = TrackingEngine.defaultWaterGoalMl

    @State private var expandedFood: String?
    @State private var planOpen = false
    @State private var whyExpanded = false
    @State private var groupsExplained = false
    @State private var openRecipe: Recipe?
    @EnvironmentObject private var router: TabRouter
    @State private var articlePath: [String] = []
    @AppStorage(HydrationPrefs.unitKey) private var hydrationUnitRaw = HydrationUnit.glasses.rawValue
    @AppStorage(HydrationPrefs.glassMlKey) private var hydrationGlassMlRaw = 0
    private var hydrationUnit: HydrationUnit { HydrationUnit(rawValue: hydrationUnitRaw) ?? .glasses }
    private var hydrationGlassMl: Int { HydrationPrefs.glassMl(from: hydrationGlassMlRaw) }

    /// The last phase she was told about. Device-local and wiped on sign-out, like the other
    /// `@AppStorage` health state — see `AppContainer.clearLocalState`.
    @AppStorage(NutritionView.lastSeenPhaseKey) private var lastSeenPhaseRaw = ""
    static let lastSeenPhaseKey = "nutrition_last_seen_phase"

    private var phase: Phase? { cycle.settings.map { CycleEngine.cyclePhase(settings: $0, target: today).phase } }

    private var showsPhaseChange: Bool {
        guard let phase else { return false }
        return CycleEngine.announcesPhaseChange(to: phase, lastSeen: Phase(rawValue: lastSeenPhaseRaw))
    }

    /// Consecutive complete weeks (≥4 of 7 days), for the de-pressured "steady weeks" line.
    /// pH days count toward weekly consistency, so pH readings feed the engine here too.
    private var weeklyStreak: Int {
        StreakEngine.compute(
            logsByDate: dailyLog.logByDate,
            phByDate: Set(ph.readings.map { CalendarDate.today(now: $0.recordedAt) }),
            today: today,
            celebrated: []).weeklyStreak
    }

    var body: some View {
        NavigationStack(path: $articlePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    ConsentWithdrawnBanner()
                    // Client parity: cycle-phase food recommendations lead; hydration and general
                    // articles drop below them.
                    if let phase {
                        if showsPhaseChange { phaseChangeCard(phase) }
                        focusFoodsCard(NutritionContent.phaseFoods[phase] ?? [])
                        // Directly beneath the foods they cook, because that adjacency is the whole
                        // reason these cards need no sign-off of their own — see `Recipe`.
                        recipesSection(phase)
                    }
                    // Only the two cards above read the phase. Gating the rest on it meant skipping
                    // cycle setup took the supplement plan — and every per-supplement reminder with
                    // it — out of reach anywhere in the app.
                    supplementPlanCard
                    hydrationCard
                    waterChallengeCard
                    foodLogCard
                    articlesSection
                    HowThisWorksLink(slug: AppGuide.nutritionGuide,
                                     label: "How your focus foods are chosen")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .gxPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { slug in
                ArticleDetailView(slug: slug, path: $articlePath)
            }
            // Settings arrive from the store after the first render, so the silent first record has
            // to react to the phase appearing, not just to the screen appearing.
            .onAppear { recordFirstPhase() }
            .onChange(of: phase) { _ in recordFirstPhase() }
        }
        .sheet(isPresented: $planOpen) { SupplementPlanSheet() }
        .sheet(item: $openRecipe) { recipe in
            RecipeSheet(recipe: recipe) { groups in
                dailyLog.logFoodGroups(Set(groups.map(\.rawValue)), on: today)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(phase.map { "Today · \(CycleContent.phaseLabel[$0]!)" } ?? "Today · Set up your cycle",
                    color: GenesyxColor.primary)
            Text("Your nutrition focus").font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
            Text(phase.map { NutritionContent.phaseDescription[$0]! }
                    ?? "Set up your cycle to get personalised nutrition guidance.")
                .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: Hydration

    /// Hydration Coach — synced from Track's repository-backed log.
    private var hydrationCard: some View {
        let waterMl = dailyLog.waterMl(on: today)
        let remaining = max(waterGoalMl - waterMl, 0)
        let hour = Calendar.current.component(.hour, from: Date())
        let pct = Double(waterMl) / Double(waterGoalMl)
        let streak = dailyLog.streak()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Hydration", color: GenesyxColor.mutedForeground)
                Spacer()
                Button { openHydrationDetail() } label: {
                    HStack(spacing: 4) {
                        Text("Track").font(.gxBodySmall.weight(.semibold))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(GenesyxColor.primary)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .bottom) {
                Text(HydrationFormat.progress(ml: waterMl, goalMl: waterGoalMl, unit: hydrationUnit,
                                              glassMl: hydrationGlassMl))
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text(HydrationCoach.streakLabel(streak))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.trailing)
            }
            ProgressView(value: min(pct, 1))
                .tint(GenesyxColor.foreground)
            Text(HydrationCoach.coachLine(hour: hour, pct: pct))
                .font(.gxBody.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text(HydrationCoach.contextLine(phase: phase))
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            CitationLink("armstrong-2012")
            if weeklyStreak >= 1 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13)).foregroundStyle(GenesyxColor.primary)
                    Text(HydrationCoach.weeklyStreakLabel(weeklyStreak))
                        .font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "drop").font(.system(size: 13)).foregroundStyle(GenesyxColor.mutedForeground)
                Text(remaining > 0 ? "\(HydrationFormat.amount(ml: remaining, unit: hydrationUnit, glassMl: hydrationGlassMl)) to go" : "Target reached — nice work")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Text("Daily target based on general adequate-intake guidance for women (from all food and drink).")
                .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            CitationLink("efsa-water")
            Rectangle().fill(GenesyxColor.border.opacity(0.6)).frame(height: 1)
            Button { withAnimation(.easeInOut(duration: 0.2)) { whyExpanded.toggle() } } label: {
                HStack {
                    Text("Why hydration?").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground).rotationEffect(.degrees(whyExpanded ? 180 : 0))
                }
                // Full-width hit area so a tap anywhere on the row expands the section, rather than
                // falling through the Spacer gap to the card's tap-to-open-Track gesture.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if whyExpanded {
                Text(HydrationCoach.whyText)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                SourcesFooter(sourceIDs: ["armstrong-2012", "valtin-2002", "nhs-water"])
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        // Tap-to-open-Track lives on the whole card (outer), not the background sublayer, so the
        // inner "Why hydration?" and "Track" buttons win their taps instead of losing to it.
        .contentShape(Rectangle())
        .onTapGesture { openHydrationDetail() }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens hydration in Track")
    }

    private func openHydrationDetail() {
        router.pendingHydration = true
        router.selection = 1
    }

    // MARK: Water challenge

    /// Seven consecutive days at the water goal. Everything shown here is derived from the water
    /// she has already logged — `WaterChallenge` stores nothing — so there is no progress record to
    /// wire up, back up, or watch fall out of step with her logs.
    private var waterChallengeCard: some View {
        let state = WaterChallenge.state(logsByDate: dailyLog.logByDate, goalMl: waterGoalMl, today: today)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(state.title, color: GenesyxColor.mutedForeground)
                Spacer()
                if state.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15)).foregroundStyle(GenesyxColor.primary)
                }
            }
            Text(state.progressLabel)
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
            HStack(spacing: 6) {
                ForEach(0..<state.target, id: \.self) { day in
                    Capsule()
                        .fill(day < state.daysDone ? GenesyxColor.primary : GenesyxColor.border.opacity(0.6))
                        .frame(height: 6)
                }
            }
            Text(state.detail)
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .contentShape(Rectangle())
        .onTapGesture { openHydrationDetail() }
        // Seven undifferentiated capsules are noise to VoiceOver; the label already carries the count.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.title). \(state.progressLabel). \(state.detail)")
        .accessibilityHint("Opens hydration in Track")
    }

    // MARK: Phase change

    /// Announced once per transition: her phase has moved on, so the focus foods directly below
    /// have moved with it, and the article explains what genuinely changes across the four.
    ///
    /// Carries no nutrition claim of its own — every line is either a phase label or a statement
    /// about this screen. The reviewed guidance stays in `focusFoodsCard` below, so the card adds
    /// nothing new for a medical reviewer to sign off.
    private func phaseChangeCard(_ phase: Phase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 16))
                    .foregroundStyle(GenesyxColor.electricLavender)
                    .frame(width: 40, height: 40)
                    .background(GenesyxColor.electricLavender.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Your phase just changed", color: GenesyxColor.mutedForeground)
                    Text(CycleContent.phaseLabel[phase]!)
                        .font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    Text("Your focus foods below have changed with it.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // Without this the only way to clear the card is to read an article she may not
                // want; it would then sit on the screen for the rest of the phase.
                Button { markPhaseSeen(phase) } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("nutrition.phaseChangeDismiss")
            }
            if let article = Self.phaseArticle(phase) {
                Button {
                    markPhaseSeen(phase)
                    articlePath.append(article.slug)
                } label: {
                    HStack(spacing: 4) {
                        // The article's own title, so the link cannot describe a piece it no longer
                        // opens — which is what a hand-written label does the day the mapping moves.
                        Text(article.title).font(.gxBodySmall.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(GenesyxColor.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nutrition.phaseChangeCard")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    /// Reading for the phase she has just entered. The card offered the same nutrition article
    /// whichever phase she moved into, so the one card whose whole subject is "this has changed"
    /// pointed at something that had not.
    static let phaseArticleSlugs: [Phase: String] = [
        .period: phaseArticleFallbackSlug,          // iron, and eating through the bleed
        .follicular: "cervical-mucus",              // the sign that predicts the window now approaching
        .ovulatory: "fertile-window",
        .luteal: "sleep-stress-and-your-cycle",     // the phase she feels most, and what it is not her fault for
    ]

    /// The twelve-week series is released by date, so most of the above are not readable yet. A link
    /// to an unpublished slug pushes a route `articleBySlug` cannot resolve and lands her on a blank
    /// screen — falling back keeps the card honest until the piece it wants actually exists.
    static let phaseArticleFallbackSlug = "eating-with-your-cycle"

    static func phaseArticle(_ phase: Phase) -> LearnArticle? {
        phaseArticleSlugs[phase].flatMap(LearnLibrary.articleBySlug)
            ?? LearnLibrary.articleBySlug(phaseArticleFallbackSlug)
    }

    /// She has been told. Recorded on either action, so reading and dismissing both settle it.
    private func markPhaseSeen(_ phase: Phase) {
        withAnimation(.easeInOut(duration: 0.2)) { lastSeenPhaseRaw = phase.rawValue }
    }

    /// The first phase this device sees is recorded without a card — she is mid-phase on a fresh
    /// install, not transitioning. Announcing from the next change is the same rule the Learn badge
    /// uses for a first install, and for the same reason.
    private func recordFirstPhase() {
        guard lastSeenPhaseRaw.isEmpty, let phase else { return }
        lastSeenPhaseRaw = phase.rawValue
    }

    // MARK: Focus foods

    private func focusFoodsCard(_ foods: [PhaseFood]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Focus foods", color: GenesyxColor.mutedForeground)
                Text("Your focus foods this phase").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            ForEach(Array(foods.enumerated()), id: \.element.name) { index, food in
                let open = expandedFood == food.name
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        Circle().fill(Theme.color(for: food.accent)).frame(width: 12, height: 12).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                            Text(food.shortDesc).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                            if open {
                                Text(food.expandedDesc).font(.gxBodySmall)
                                    .foregroundStyle(GenesyxColor.mutedForeground.opacity(0.8)).padding(.top, 8)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14))
                            .foregroundStyle(GenesyxColor.mutedForeground).rotationEffect(.degrees(open ? 90 : 0)).padding(.top, 4)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expandedFood = open ? nil : food.name } }
                    if index < foods.count - 1 {
                        Rectangle().fill(GenesyxColor.border.opacity(0.6)).frame(height: 1).padding(.horizontal, 20)
                    }
                }
            }
        }
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    // MARK: Recipes

    /// The client's ask was to stop listing ingredients and start showing meals. These are meals,
    /// and each is built from a focus food named in the card directly above — which is what lets
    /// them ship without a citation or a sign-off of their own (see `Recipe`).
    ///
    /// Every shipped recipe has approved food-only photography. The phase gradient remains behind
    /// it as a safe fallback for a newly-authored recipe whose asset has not landed yet.
    private func recipesSection(_ phase: Phase) -> some View {
        let recipes = RecipeContent.forPhase(phase)
        let accent = Theme.color(for: FoodAccent(rawValue: phase.rawValue) ?? .period)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(RecipeCopy.eyebrow, color: GenesyxColor.mutedForeground)
                Text(RecipeCopy.title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recipes) { recipe in
                        recipeCard(recipe, accent: accent)
                    }
                }
                // The cards sit inside the page's own 20pt gutter, so the row is padded back out
                // and in again — otherwise the first card starts flush against the screen edge.
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func recipeCard(_ recipe: Recipe, accent: Color) -> some View {
        Button { openRecipe = recipe } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [accent.opacity(0.85), accent.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let imageName = recipe.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 92)
                            .clipped()
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(14)
                    }
                }
                .frame(height: 92)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(RecipeCopy.usesLine(recipe.usesFocusFood))
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(RecipeCopy.meta(minutes: recipe.minutes, serves: recipe.serves))
                        .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground.opacity(0.9))
                        .padding(.top, 2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 220)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutrition.recipe.\(recipe.id)")
        .accessibilityLabel("\(recipe.name). \(RecipeCopy.meta(minutes: recipe.minutes, serves: recipe.serves))")
        .accessibilityHint(RecipeCopy.usesLine(recipe.usesFocusFood))
    }

    // MARK: Supplement plan

    /// Honest count of today's logged supplements (from the daily log), never a fixed placeholder.
    /// Counted against the plan rather than the stored set, the same guard the food-group card
    /// uses, so a supplement logged under an older list cannot render "5 of 4".
    private var supplementsTakenLabel: String {
        let taken = NutritionDaySignal.knownSupplements(dailyLog.log(on: today).supplements)
        let total = NutritionContent.supplementPlan.count
        return taken > 0 ? "\(taken) of \(total) taken today" : "None logged yet today"
    }

    private var supplementPlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "pills.fill").foregroundStyle(GenesyxColor.primary)
                    .frame(width: 44, height: 44).background(GenesyxColor.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your supplement plan").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                    Text("Folate, Omega-3, Vitamin D, and Zinc — taken with breakfast.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    HStack(spacing: -6) {
                        ForEach(Array(NutritionContent.supplementPlan.enumerated()), id: \.element.initial) { i, s in
                            SupplementAvatar(initial: s.initial, index: i)
                        }
                        Text(supplementsTakenLabel).font(.gxBodySmall)
                            .foregroundStyle(GenesyxColor.mutedForeground).padding(.leading, 14)
                    }
                    .padding(.top, 6)
                }
            }
            GxPrimaryButton(title: "Review Plan") { planOpen = true }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    // MARK: Articles

    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow("Learn more", color: GenesyxColor.mutedForeground).padding(.leading, 4)
                Spacer()
                Button("See all articles") { router.selection = 5 }   // 5 = Learn tab
                    .font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
            }
            .padding(.bottom, 2)
            ForEach(learnArticles.filter { $0.category == .nutrition }, id: \.slug) { a in
                Button { articlePath.append(a.slug) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                                .multilineTextAlignment(.leading)
                            Text(a.readingTime).font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    .padding(16)
                    .background(GenesyxColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Circular F/O/D/Z avatar (tint cycles lavender / blue / lavender / pink).
struct SupplementAvatar: View {
    let initial: String
    let index: Int
    var body: some View {
        let tint: Color = index == 1 ? GenesyxColor.electricBlue : (index == 3 ? GenesyxColor.electricPink : GenesyxColor.electricLavender)
        Text(initial)
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 28, height: 28).background(tint.opacity(0.12)).clipShape(Circle())
            .overlay(Circle().strokeBorder(GenesyxColor.card, lineWidth: 1.5))
    }
}

private extension NutritionView {
    /// Meal logging, in food-group terms — the loop this screen has always opened and never closed.
    /// The focus-foods card above tells her what to eat this phase; until now nothing let her say
    /// she had.
    ///
    /// Groups rather than foods deliberately. Naming a dish needs a food database, which is the
    /// deferred barcode work, and counting nutrients needs claims this app has no substantiation
    /// for. Six chips need neither and answer the question she actually has, which is whether the
    /// week has had any vegetables in it.
    var foodLogCard: some View {
        let logged = dailyLog.log(on: today).foodGroups
        // Counted against the known cases, not the stored set: a token written by a build that
        // knows a seventh group would otherwise render "7 of 6".
        let known = FoodGroup.allCases.filter { logged.contains($0.rawValue) }
        let emphasis = phase.flatMap { NutritionContent.phaseFoodGroups[$0] } ?? []
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(FoodLogCopy.title, color: GenesyxColor.mutedForeground)
                Spacer()
                Text("\(known.count)/\(FoodGroup.allCases.count)")
                    .font(.gxBodySmall.weight(.semibold))
                    .foregroundStyle(known.isEmpty ? GenesyxColor.mutedForeground : GenesyxColor.primary)
            }
            Text(FoodLogCopy.summary(logged: known.count, total: FoodGroup.allCases.count))
                .font(.gxBody.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8) {
                ForEach(FoodGroup.allCases) { group in
                    foodGroupChip(group, selected: logged.contains(group.rawValue))
                }
            }
            if let line = FoodLogCopy.phaseLine(emphasis) {
                Text(line)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(GenesyxColor.border.opacity(0.6)).frame(height: 1)
            whatCountsDisclosure
            Text(FoodLogCopy.footnote)
                .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    func foodGroupChip(_ group: FoodGroup, selected: Bool) -> some View {
        Button {
            dailyLog.toggleFoodGroup(group.rawValue, on: today)
        } label: {
            HStack(spacing: 4) {
                if selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                Text(group.label).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? .white : GenesyxColor.foreground.opacity(0.8))
            .padding(.horizontal, 14).frame(height: 36)
            .background(selected ? GenesyxColor.primary : GenesyxColor.card)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(selected ? .clear : GenesyxColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutrition.foodGroup.\(group.rawValue)")
        .accessibilityLabel(selected ? "\(group.label), logged" : "\(group.label), not logged")
        .accessibilityHint(group.examples)
    }

    /// "Starchy carbs" is not self-explanatory, and a chip has no room to say what counts. Same
    /// disclosure pattern as "Why hydration?" three cards up, so it costs one line until she asks.
    var whatCountsDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { groupsExplained.toggle() } } label: {
                HStack {
                    Text("What counts as what?").font(.gxBodySmall.weight(.medium))
                        .foregroundStyle(GenesyxColor.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .rotationEffect(.degrees(groupsExplained ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nutrition.foodGroupsExplain")
            if groupsExplained {
                ForEach(FoodGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.label).font(.gxBodySmall.weight(.medium))
                            .foregroundStyle(GenesyxColor.foreground)
                        Text(group.examples).font(.gxBodySmall)
                            .foregroundStyle(GenesyxColor.mutedForeground.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// One recipe, in full. The "log this" button writes the groups the recipe already knows it covers,
/// so she is not re-entering into the food log what is on the screen in front of her.
private struct RecipeSheet: View {
    let recipe: Recipe
    /// Called with the recipe's groups. Additive on the repository side — see `logFoodGroups`.
    let onLog: ([FoodGroup]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var logged = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(RecipeCopy.usesLine(recipe.usesFocusFood))
                            .font(.gxBodySmall).foregroundStyle(GenesyxColor.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(RecipeCopy.meta(minutes: recipe.minutes, serves: recipe.serves))
                            .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    }

                    section(RecipeCopy.ingredientsHeading) {
                        ForEach(recipe.ingredients, id: \.self) { line in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(GenesyxColor.primary.opacity(0.5))
                                    .frame(width: 5, height: 5).padding(.top, 7)
                                Text(line).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    section(RecipeCopy.methodHeading) {
                        ForEach(Array(recipe.method.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)").font(.gxBodySmall.weight(.semibold))
                                    .foregroundStyle(GenesyxColor.primary)
                                    .frame(width: 22, height: 22)
                                    .background(GenesyxColor.primary.opacity(0.12)).clipShape(Circle())
                                Text(step).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    logButton

                    Text(RecipeCopy.footnote)
                        .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(GenesyxColor.background)
            .navigationTitle(recipe.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    /// Stays on screen after tapping rather than dismissing. Tapping "log" and being thrown back to
    /// the list reads as the sheet closing on her, and she may well still be cooking from it.
    private var logButton: some View {
        Button {
            onLog(recipe.groups)
            withAnimation(.easeInOut(duration: 0.2)) { logged = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: logged ? "checkmark.circle.fill" : "plus.circle")
                Text(logged ? "Added to today" : RecipeCopy.logGroupsAction(recipe.groups))
            }
            .font(.gxBody.weight(.semibold))
            .foregroundStyle(logged ? GenesyxColor.primary : .white)
            .padding(.horizontal, 18).frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(logged ? GenesyxColor.primary.opacity(0.12) : GenesyxColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(logged)
        .accessibilityIdentifier("recipe.logGroups")
    }

    private func section<Content: View>(_ heading: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(heading, color: GenesyxColor.mutedForeground)
            content()
        }
    }
}

private struct SupplementPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prefs: PreferencesRepository

    @EnvironmentObject private var supplements: SupplementsRepository
    @State private var newName = ""
    @State private var newDose = ""
    @State private var newTime: SupplementTime?

    private var custom: [CustomSupplement] { supplements.supplements }

    /// The same bound `CustomSupplement.isValid` applies, mirrored here so the button greys out.
    /// `add` REFUSES an over-long name rather than truncating it, and a button that looks live but
    /// silently does nothing is worse than one that is visibly unavailable.
    private var canAdd: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= CustomSupplement.nameMaxLength
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    genesyxEssentials
                    yourSupplements
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Your supplement plan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got it") { dismiss() } } }
        }
    }

    private var genesyxEssentials: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GENESYX ESSENTIALS").font(.gxEyebrow).tracking(1.4).foregroundStyle(GenesyxColor.mutedForeground)
            Text("Gentle, evidence-informed essentials for fertility prep.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            ForEach(Array(NutritionContent.supplementPlan.enumerated()), id: \.element.initial) { i, s in
                HStack(alignment: .top, spacing: 12) {
                    SupplementAvatar(initial: s.initial, index: i)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.gxBody.weight(.medium)).foregroundStyle(GenesyxColor.foreground)
                        Text(s.rationale).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    Spacer()
                    reminderMenu(key: SupplementReminder.essentialKey(initial: s.initial), name: s.name)
                }
            }
        }
    }

    private var yourSupplements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR SUPPLEMENTS").font(.gxEyebrow).tracking(1.4).foregroundStyle(GenesyxColor.mutedForeground)
            if custom.isEmpty {
                Text("Add your own supplements to keep everything in one place.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            } else {
                ForEach(custom) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "pills").font(.system(size: 15))
                            .foregroundStyle(GenesyxColor.primary)
                            .frame(width: 28, height: 28)
                            .background(GenesyxColor.primary.opacity(0.12)).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.gxBody.weight(.medium)).foregroundStyle(GenesyxColor.foreground)
                            let detail = [item.dose, item.timeOfDay?.label ?? ""]
                                .filter { !$0.isEmpty }.joined(separator: " · ")
                            if !detail.isEmpty {
                                Text(detail).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                            }
                        }
                        Spacer()
                        reminderMenu(key: item.id, name: item.name)
                        Button { remove(item) } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(GenesyxColor.mutedForeground)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(item.name)")
                    }
                }
            }
            addForm
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            field("Name (e.g. Magnesium)", text: $newName)
            HStack(spacing: 8) {
                field("Dose (e.g. 200 mg)", text: $newDose)
                timePicker
            }
            Button(action: add) {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("Add your own supplement").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(canAdd ? GenesyxColor.primary : GenesyxColor.primary.opacity(0.45))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .accessibilityIdentifier("supplement.add")
        }
        .padding(.top, 4)
    }

    /// Off by default, and off is a first-class option rather than something to be talked out of —
    /// a plan of six supplements should not mean six alarms nobody asked for.
    private func reminderMenu(key: String, name: String) -> some View {
        let hour = prefs.supplementReminders[key]
        return Menu {
            Picker("Reminder", selection: Binding(
                get: { prefs.supplementReminders[key] ?? -1 },
                set: { prefs.supplementReminders[key] = $0 < 0 ? nil : $0 }
            )) {
                Text("No reminder").tag(-1)
                ForEach(0..<24, id: \.self) { h in Text(gxHourLabel(h)).tag(h) }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: hour == nil ? "bell" : "bell.fill").font(.system(size: 12, weight: .semibold))
                if let hour { Text(gxHourLabel(hour)).font(.system(size: 12, weight: .medium)) }
            }
            .foregroundStyle(hour == nil ? GenesyxColor.mutedForeground : GenesyxColor.primary)
        }
        .accessibilityLabel(hour == nil
                            ? "Set a reminder for \(name)"
                            : "\(name) reminder at \(gxHourLabel(hour!))")
        .accessibilityIdentifier("supplementReminder.\(key)")
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.gxBodySmall).padding(.horizontal, 12).frame(height: 44)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
    }

    /// The four values Android already writes and the server's `time_of_day` CHECK already accepts.
    /// This replaced a free-text box, which is why the empty tag is a real option rather than a
    /// placeholder: leaving it unset has always been allowed, and the column is nullable.
    private var timePicker: some View {
        Menu {
            Picker("Time of day", selection: Binding(
                get: { newTime?.rawValue ?? "" },
                set: { newTime = SupplementTime(rawValue: $0) }
            )) {
                Text("No time").tag("")
                ForEach(SupplementTime.allCases, id: \.rawValue) { t in Text(t.label).tag(t.rawValue) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(newTime?.label ?? "Time")
                    .font(.gxBodySmall)
                    .foregroundStyle(newTime == nil ? GenesyxColor.mutedForeground : GenesyxColor.foreground)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(.horizontal, 12).frame(width: 132, height: 44)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
        }
        .accessibilityLabel(newTime.map { "Time of day, \($0.label)" } ?? "Time of day, not set")
        .accessibilityIdentifier("supplement.time")
    }

    private func add() {
        let item = CustomSupplement(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            dose: newDose.trimmingCharacters(in: .whitespacesAndNewlines),
            timeOfDay: newTime)
        guard supplements.add(item) else { return }
        newName = ""; newDose = ""; newTime = nil
    }

    /// A tombstone, not an array removal — see `SupplementsRepository.delete`. The reminder goes
    /// with it: a deleted supplement that kept its alarm would wake her for something the app no
    /// longer shows her.
    private func remove(_ item: CustomSupplement) {
        supplements.delete(id: item.id)
        prefs.supplementReminders[item.id] = nil
    }
}
