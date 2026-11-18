import SwiftUI
import GenesyxCore

/// Nutrition — phase-aware focus foods, hydration, supplement plan, and articles.
/// Ported from the Android `NutritionScreen` + `NutritionViewModel`.
struct NutritionView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository

    private let today = CalendarDate.today()
    private let waterGoalMl = 2400

    @State private var expandedFood: String?
    @State private var planOpen = false
    @EnvironmentObject private var router: TabRouter
    @State private var articlePath: [String] = []

    private var phase: Phase? { cycle.settings.map { CycleEngine.cyclePhase(settings: $0, target: today).phase } }

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

    private var hydrationCard: some View {
        let waterMl = dailyLog.waterMl(on: today)
        let remaining = max(waterGoalMl - waterMl, 0)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Hydration", color: GenesyxColor.mutedForeground)
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(String(format: "%.1f", Double(waterMl) / 1000))
                            .font(.system(size: 28, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
                        Text("/ \(String(format: "%.1f", Double(waterGoalMl) / 1000)) L")
                            .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).padding(.bottom, 4)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    waterButton("minus", bg: GenesyxColor.muted, fg: GenesyxColor.foreground) { dailyLog.adjustWater(-200) }
                    waterButton("plus", bg: GenesyxColor.primary, fg: .white) { dailyLog.adjustWater(200) }
                }
            }
            ProgressView(value: min(Double(waterMl) / Double(waterGoalMl), 1))
                .tint(GenesyxColor.foreground)
            HStack(spacing: 6) {
                Image(systemName: "drop").font(.system(size: 13)).foregroundStyle(GenesyxColor.mutedForeground)
                Text(remaining > 0 ? "\(remaining)ml to go" : "Target reached — nice work")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
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
                        Text("3 of 4 taken today").font(.gxBodySmall)
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

