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

    private var phase: Phase? { cycle.settings.map { CycleEngine.cyclePhase(settings: $0, target: today).phase } }

    /// Consecutive complete weeks (≥5 of 7 days), for the de-pressured "steady weeks" line.
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
                    hydrationCard
                    PhTrackerSection()
                    if let phase {
                        focusFoodsCard(NutritionContent.phaseFoods[phase] ?? [])
                        supplementPlanCard
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

    /// Hydration Coach — live, time-of-day-aware coaching over today's water.
    private var hydrationCard: some View {
        let waterMl = dailyLog.waterMl(on: today)
        let remaining = max(waterGoalMl - waterMl, 0)
        let hour = Calendar.current.component(.hour, from: Date())
        let pct = Double(waterMl) / Double(waterGoalMl)
        let streak = dailyLog.streak()
        return VStack(alignment: .leading, spacing: 14) {
            // Eyebrow + (de-pressured) streak
            HStack {
                Eyebrow("Hydration", color: GenesyxColor.mutedForeground)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 11))
                        .foregroundStyle(streak > 0 ? GenesyxColor.electricPink : GenesyxColor.mutedForeground)
                    Text(HydrationCoach.streakLabel(streak))
                        .font(.system(size: 11.5, weight: .medium)).foregroundStyle(GenesyxColor.mutedForeground)
                }
            }
            // Big number + steppers
            HStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text(String(format: "%.1f", Double(waterMl) / 1000))
                        .font(.system(size: 28, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
                    Text("/ \(String(format: "%.1f", Double(waterGoalMl) / 1000)) L")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).padding(.bottom, 4)
                }
                Spacer()
                HStack(spacing: 8) {
                    waterButton("minus", bg: GenesyxColor.muted, fg: GenesyxColor.foreground) { dailyLog.adjustWater(-200) }
                    waterButton("plus", bg: GenesyxColor.primary, fg: .white) { dailyLog.adjustWater(200) }
                }
            }
            ProgressView(value: min(pct, 1))
                .tint(GenesyxColor.foreground)
            // Coach line — names the part of the day + the action
            Text(HydrationCoach.coachLine(hour: hour, pct: pct))
                .font(.gxBody.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
            // Context line — phase-aware, behavioural only
            Text(HydrationCoach.contextLine(phase: phase))
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            // Weekly consistency — only once there's a complete week to celebrate
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
                Text(remaining > 0 ? "\(remaining)ml to go" : "Target reached — nice work")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            // Collapsible "Why hydration?" explainer
            Rectangle().fill(GenesyxColor.border.opacity(0.6)).frame(height: 1)
            Button { withAnimation(.easeInOut(duration: 0.2)) { whyExpanded.toggle() } } label: {
                HStack {
                    Text("Why hydration?").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground).rotationEffect(.degrees(whyExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if whyExpanded {
                Text(HydrationCoach.whyText)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func waterButton(_ symbol: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(fg)
                .frame(width: 36, height: 36).background(bg).clipShape(Circle())
        }
        .buttonStyle(.plain)
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

/// Pure copy + time-of-day logic for the Hydration Coach — kept separate so it's unit-testable
/// and its strings can be scanned by the content-safety test. Behavioural, never medical.
enum HydrationCoach {

    enum DayPart: Equatable {
        case morning, midday, afternoon, evening, night
        static func at(hour: Int) -> DayPart {
            switch hour {
            case 5...11:  return .morning
            case 12...15: return .midday
            case 16...19: return .afternoon
            case 20...22: return .evening
            default:      return .night      // 23, 0–4
            }
        }
    }

    /// First two words always name the part of the day. Column chosen by `pct` (scales to the goal).
    static func coachLine(hour: Int, pct: Double) -> String {
        let under = pct < 1.0
        switch DayPart.at(hour: hour) {
        case .morning:
            return under
                ? "Morning — start with a glass now. Anchor it to breakfast so you don't have to remember later."
                : "Great start — you're already hydrated this morning."
        case .midday:
            return under
                ? "Midday — a glass with lunch keeps you steady through the afternoon dip."
                : "Steady through lunch — nice."
        case .afternoon:
            return under
                ? "Afternoon — one glass with your desk break. This is where most days slip."
                : "You've kept it steady through the afternoon."
        case .evening:
            return under
                ? "Evening — small sips only. Don't front-load before bed."
                : "Target hit — ease off the water before bed."
        case .night:
            return under
                ? "Late night — a small sip if you're thirsty, nothing more."
                : "You're hydrated for the day."
        }
    }

    static func contextLine(phase: Phase?) -> String {
        guard let phase else { return "Log your cycle to get phase-aware hydration guidance." }
        switch phase {
        case .period:     return "Iron-rich foods and steady water help during your period."
        case .follicular: return "You likely have energy this week — keep water steady to match."
        case .ovulatory:  return "Nothing special required — keep drinking."
        case .luteal:     return "Smaller, regular meals and water can ease energy dips."
        }
    }

    /// Weekly-consistency line — only surfaced when there's at least one complete week (≥5 of 7
    /// days). De-pressured: celebrates steadiness, never demands perfection.
    static func weeklyStreakLabel(_ weeks: Int) -> String {
        weeks == 1
            ? "1 steady week — consistency is doing its quiet work."
            : "\(weeks) steady weeks — consistency is doing its quiet work."
    }

    /// Always-visible daily-streak pill copy — de-pressured, encouraging even at zero.
    static func streakLabel(_ streak: Int) -> String {
        switch streak {
        case 0:  return "Daily streak — start today"
        case 1:  return "Day 1 — great start"
        default: return "\(streak)-day daily streak"
        }
    }

    static let whyText = "Steady hydration supports your energy and mood, and it makes your pH readings more consistent — concentrated urine reads more acidic, well-hydrated reads closer to neutral. The old 'eight glasses a day' rule came from a 1945 recommendation whose next sentence got lost: most of that water already comes from food. Thirst is a reasonable guide. Anchor a glass to meals and routines, and you won't have to think about it."

    /// Every user-facing string, for the content-safety scan.
    static var allStrings: [String] {
        var out: [String] = []
        for hour in [7, 13, 17, 21, 2] {
            out.append(coachLine(hour: hour, pct: 0.2))
            out.append(coachLine(hour: hour, pct: 1.0))
        }
        for phase in Phase.allCases { out.append(contextLine(phase: phase)) }
        out.append(contextLine(phase: nil))
        for streak in [0, 1, 3] { out.append(streakLabel(streak)) }
        for weeks in [1, 4] { out.append(weeklyStreakLabel(weeks)) }
        out.append(whyText)
        return out
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

private struct SupplementPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Your supplement plan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got it") { dismiss() } } }
        }
    }
}

