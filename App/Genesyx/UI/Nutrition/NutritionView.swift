import SwiftUI
import GenesyxCore

/// Nutrition — phase-aware focus foods, hydration, supplement plan, and articles.
/// Ported from the Android `NutritionScreen` + `NutritionViewModel`.
struct NutritionView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var ph: PhRepository

    private let today = CalendarDate.today()
    private let waterGoalMl = 2400

    @State private var expandedFood: String?
    @State private var planOpen = false
    @State private var whyExpanded = false
    @EnvironmentObject private var router: TabRouter
    @State private var articlePath: [String] = []
    @AppStorage("hydration_unit") private var hydrationUnitRaw = HydrationUnit.glasses.rawValue
    private var hydrationUnit: HydrationUnit { HydrationUnit(rawValue: hydrationUnitRaw) ?? .glasses }

    private var phase: Phase? { cycle.settings.map { CycleEngine.cyclePhase(settings: $0, target: today).phase } }

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
                    // Client parity: cycle-phase food recommendations lead; hydration and general
                    // articles drop below them.
                    if let phase {
                        focusFoodsCard(NutritionContent.phaseFoods[phase] ?? [])
                    }
                    mealSuggestionsCard
                    if let phase {
                        supplementPlanCard
                    }
                    hydrationCard
                    PhTrackerSection()
                    if let phase {
                        articlesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { slug in
                ArticleDetailView(slug: slug, path: $articlePath)
            }
        }
        .sheet(isPresented: $planOpen) { SupplementPlanSheet() }
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
        let insights = HydrationInsightLogic.lastSevenDays(
            logByDate: dailyLog.logByDate, goalMl: waterGoalMl, streak: streak, today: today)
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
                Text(HydrationFormat.progress(ml: waterMl, goalMl: waterGoalMl, unit: hydrationUnit))
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
            Text(insights.insight)
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
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
                Text(remaining > 0 ? "\(HydrationFormat.amount(ml: remaining, unit: hydrationUnit)) to go" : "Target reached — nice work")
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

    // MARK: Supplement plan

    /// Honest count of today's logged supplements (from the daily log), never a fixed placeholder.
    private var supplementsTakenLabel: String {
        let taken = dailyLog.log(on: today).supplements.count
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
                Button("See all articles") { router.selection = 4 }   // 4 = Learn tab
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
    /// Honest empty state for content not built yet (meal suggestions + food preferences). No fake
    /// data — a clean "coming soon" placeholder that keeps the section discoverable.
    var mealSuggestionsCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "fork.knife").font(.system(size: 16))
                .foregroundStyle(GenesyxColor.electricLavender)
                .frame(width: 40, height: 40)
                .background(GenesyxColor.primary.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Coming soon", color: GenesyxColor.mutedForeground)
                Text("Meal suggestions & food preferences")
                    .font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                Text("Personalised meals and dietary preferences are on the way. For now, your phase focus foods above are your guide.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

private struct SupplementPlanSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Custom supplements persist LOCALLY only for now. Remote Supabase persistence is pending the
    // shared Android schema (see CustomSupplement) — flagged, not applied.
    @AppStorage("custom_supplements") private var customJSON = "[]"
    @State private var newName = ""
    @State private var newDose = ""
    @State private var newTime = ""

    private var custom: [CustomSupplement] { CustomSupplement.decodeList(customJSON) }

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
                            let detail = [item.dose, item.time].filter { !$0.isEmpty }.joined(separator: " · ")
                            if !detail.isEmpty {
                                Text(detail).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                            }
                        }
                        Spacer()
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
                field("Time (e.g. Evening)", text: $newTime)
            }
            Button(action: add) {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("Add your own supplement").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? GenesyxColor.primary.opacity(0.45) : GenesyxColor.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("supplement.add")
        }
        .padding(.top, 4)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.gxBodySmall).padding(.horizontal, 12).frame(height: 44)
            .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
    }

    private func add() {
        let item = CustomSupplement(
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            dose: newDose.trimmingCharacters(in: .whitespacesAndNewlines),
            time: newTime.trimmingCharacters(in: .whitespacesAndNewlines))
        guard item.isValid else { return }
        customJSON = CustomSupplement.encodeList(custom + [item])
        newName = ""; newDose = ""; newTime = ""
    }

    private func remove(_ item: CustomSupplement) {
        customJSON = CustomSupplement.encodeList(custom.filter { $0.id != item.id })
    }
}
