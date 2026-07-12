import SwiftUI
import GenesyxCore

/// Insights — every card is computed from the user's real logged data: urine pH, hydration,
/// cycle regularity, symptom patterns, and predicted ovulation. No mock/hardcoded/sine values.
/// (The old Android "Nutrition consistency" mock card is intentionally dropped — the Hydration
/// card is the honest weekly-water view.)
struct InsightsView: View {

    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var cycle: CycleRepository

    private static let waterGoalMl = 2400

    /// Real water for the last 7 days (oldest → newest) with narrow weekday-initial labels.
    private var last7Days: [(label: String, ml: Int)] {
        let today = CalendarDate.today()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"   // single-letter weekday
        return (0..<7).reversed().map { back in
            let day = today.minusDays(back)
            return (formatter.string(from: day.toDate()), dailyLog.waterMl(on: day))
        }
    }

    /// Daily/weekly streak + week-dots, computed from real logs and pH days (pH days count
    /// toward weekly consistency). `celebrated: []` — milestone firing lives in WS2, not here.
    private var streakState: StreakState {
        StreakEngine.compute(
            logsByDate: dailyLog.logByDate,
            phByDate: Set(ph.readings.map { CalendarDate.today(now: $0.recordedAt) }),
            today: CalendarDate.today(),
            celebrated: [])
    }

    private var consistencyCard: some View {
        ConsistencyCard(model: ConsistencyInsightLogic.model(from: streakState))
    }

    /// Week-over-week hydration delta — only shown when BOTH weeks have logged days (§8).
    private var hydrationDeltaLine: String? {
        let today = CalendarDate.today()
        let thisWeek = (0..<7).map { dailyLog.waterMl(on: today.minusDays($0)) }.filter { $0 > 0 }
        let lastWeek = (7..<14).map { dailyLog.waterMl(on: today.minusDays($0)) }.filter { $0 > 0 }
        return HydrationDeltaLogic.weekOverWeekLine(thisWeekMl: thisWeek, lastWeekMl: lastWeek)
    }

    /// pH readings in the last 30 days — the "how solid is this trend" context line.
    private var phCountLine: String {
        let cutoff = CalendarDate.today().minusDays(30)
        let count = ph.readings.filter { CalendarDate.today(now: $0.recordedAt) >= cutoff }.count
        return PhContextLogic.readingCountLine(count: count)
    }

    /// The 28 dates behind the symptom heatmap (oldest → newest), so a tapped cell can jump
    /// to that day's Log History entry.
    private var symptomDates: [CalendarDate] {
        let today = CalendarDate.today()
        return (0..<28).reversed().map { today.minusDays($0) }
    }

    private var hydrationInsightsCard: some View {
        let week = last7Days
        // Use the same streak the Consistency card shows (StreakEngine, with morning grace).
        // `dailyLog.streak()` has no grace, so before she logged today the two cards on this very
        // screen disagreed about the same number.
        let insights = HydrationInsightLogic.compute(
            dailyMl: week.map(\.ml), goalMl: Self.waterGoalMl, streak: streakState.dailyHydration)
        return HydrationInsightsCard(
            insights: insights, labels: week.map(\.label),
            goalMl: Self.waterGoalMl, hasPh: !ph.readings.isEmpty,
            deltaLine: hydrationDeltaLine)
    }

    private var cycleRegularityCard: some View {
        CycleRegularityCard(insights: CycleRegularityLogic.compute(settings: cycle.settings))
    }

    private var symptomPatternsCard: some View {
        SymptomPatternsCard(
            insights: SymptomPatternLogic.compute(logs: dailyLog.logByDate),
            weekdayLabels: weekdayInitials,
            dates: symptomDates)
    }

    private var ovulationCard: some View {
        OvulationCard(
            insights: OvulationLogic.compute(settings: cycle.settings),
            cycleLength: cycle.settings?.cycleLength ?? 28,
            periodLength: cycle.settings?.periodLength ?? 5)
    }

    /// Weekday initials for the last 7 days (oldest → newest); aligns the symptom heatmap columns.
    private var weekdayInitials: [String] {
        let today = CalendarDate.today()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return (0..<7).reversed().map { formatter.string(from: today.minusDays($0).toDate()) }
    }

    var body: some View {
        let insights = PhInsightLogic.compute(ph.readings)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    logHistoryLink
                    consistencyCard
                    PhInsightsCard(ph: insights, countLine: phCountLine, hasTrend: ph.readings.count >= 2)
                    hydrationInsightsCard
                    cycleRegularityCard
                    symptomPatternsCard
                    ovulationCard
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.background)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var logHistoryLink: some View {
        NavigationLink {
            LogHistoryView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18)).foregroundStyle(GenesyxColor.primary)
                    .frame(width: 40, height: 40)
                    .background(GenesyxColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("My logs").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    Text("See everything you've tracked").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(20)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Insights").font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
            Text("Understanding your patterns helps you make informed, empowered decisions for your wellbeing.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

/// Consistency (WS1/WS3a §5.1) — daily & weekly streak, a Monday-first 7-dot "days logged this
/// week" row, and a de-pressured insight line. Never guilt: the empty state invites, doesn't scold.
private struct ConsistencyCard: View {
    let model: ConsistencyCardModel
    private static let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Consistency").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text("This week").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
            }
            if model.isEmpty {
                Text(model.insight)
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            } else {
                HStack(spacing: 12) {
                    tile("Daily streak", model.dailyStreak == 1 ? "1 day" : "\(model.dailyStreak) days")
                    tile("Weekly streak", model.weeklyStreak == 1 ? "1 week" : "\(model.weeklyStreak) weeks")
                }
                .padding(.top, 16)
                weekDots.padding(.top, 16)
                Text(model.insight)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
                if model.bestDailyStreak > model.dailyStreak {
                    Text("Best daily streak: \(model.bestDailyStreak) days")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var weekDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                let on = i < model.weekDots.count && model.weekDots[i]
                VStack(spacing: 6) {
                    Circle()
                        .fill(on ? GenesyxColor.primary : GenesyxColor.muted.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white).opacity(on ? 1 : 0))
                    Text(Self.dayLetters[i]).font(.system(size: 10)).foregroundStyle(GenesyxColor.mutedForeground)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PhInsightsCard: View {
    let ph: PhInsights
    let countLine: String
    /// False with a single reading — there is no previous value to compare against.
    let hasTrend: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Urine pH").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                NavigationLink {
                    PhTrackerScreen()
                } label: {
                    Text("Open tracker").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
                }
                .buttonStyle(.plain)
            }
            if !ph.hasReadings {
                Text("No pH readings yet. Log your first one on Track or Nutrition.")
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 12)
            } else {
                // Never invent a reading: a missing value/status renders nothing rather than
                // falling back to "0.0 / OPTIMAL", which would be a clinical claim we never measured.
                if let value = ph.currentValue, let status = ph.currentStatus {
                    let color = Theme.color(for: status)
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow("Current", color: GenesyxColor.mutedForeground)
                            HStack(spacing: 8) {
                                Text(String(format: "%.1f", value))
                                    .font(.system(size: 30, weight: .semibold)).foregroundStyle(color)
                                Text(status.label.uppercased()).font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 3)
                                    .background(color.opacity(0.18)).clipShape(Capsule())
                            }
                        }
                        Spacer()
                        trendBadge
                    }
                    .padding(.top, 14)
                }
                HStack(spacing: 12) {
                    avgTile("7-day avg", ph.avg7)
                    avgTile("30-day avg", ph.avg30)
                }
                .padding(.top, 16)
                Text(ph.insight).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 16)
                if !ph.recommendation.isEmpty {
                    Text(ph.recommendation).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 6)
                }
                Text(countLine).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground.opacity(0.9)).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    /// A trend needs two readings. With one, `PhInsightLogic` reports `.flat` — showing that as
    /// "→ vs previous" would compare against a reading that doesn't exist, so we show nothing.
    @ViewBuilder private var trendBadge: some View {
        if hasTrend {
            HStack(spacing: 4) {
                Image(systemName: trendSymbol).font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
                Text("vs previous").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
        }
    }

    private var trendSymbol: String {
        switch ph.trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "arrow.right"
        }
    }

    private func avgTile(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value.map { String(format: "%.2f", $0) } ?? "—")
                .font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Real weekly hydration — 7-day bar chart (scaled to the 2.4L goal), goal line, two summary
/// tiles, a de-pressured insight line, and (only if pH readings exist) an honest pH-connection line.
private struct HydrationInsightsCard: View {
    let insights: HydrationInsights
    let labels: [String]
    let goalMl: Int
    let hasPh: Bool
    let deltaLine: String?
    private let barHeight: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                Text("Hydration").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text("This week").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.electricBlue)
            }
            chart.padding(.top, 18)
            HStack(spacing: 12) {
                tile("7-day total", String(format: "%.1f L", Double(insights.totalMl) / 1000))
                tile("Days on goal", "\(insights.daysOnGoal) / 7")
            }
            .padding(.top, 16)
            if let deltaLine {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12)).foregroundStyle(GenesyxColor.electricBlue)
                    Text(deltaLine).font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                }
                .padding(.top, 12)
            }
            Text(insights.insight)
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            if hasPh {
                Text("Steady hydration makes your pH readings more comparable — concentrated urine reads more acidic.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 6)
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var chart: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(insights.dailyMl.enumerated()), id: \.offset) { index, ml in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        // A day with nothing logged gets a flat grey track, not a blue stub — the old
                        // 2pt floor on the gradient drew "you drank a little" for days she never logged.
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ml > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [GenesyxColor.electricBlue, GenesyxColor.powderBlue],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(GenesyxColor.muted))
                            .frame(height: ml > 0 ? max(barHeight * CGFloat(min(Double(ml) / Double(goalMl), 1)), 2) : 2)
                        Text(index < labels.count ? labels[index] : "")
                            .font(.system(size: 10)).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight + 18)
            // Goal line at 100% (top of the bar area).
            HStack(spacing: 6) {
                DashedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(GenesyxColor.mutedForeground.opacity(0.6)).frame(height: 1)
                Text(String(format: "%.1fL goal", Double(goalMl) / 1000)).font(.system(size: 9))
                    .foregroundStyle(GenesyxColor.mutedForeground).fixedSize()
            }
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Real-data cards (cycle regularity, symptom patterns, ovulation)

/// Cycle length vs the typical 21–35 day range (honest single-cycle view — no fabricated history).
private struct CycleRegularityCard: View {
    let insights: CycleRegularityInsights?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Cycle regularity").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text("Current setup").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
            }
            if let insights {
                rangeBar(cycleLength: insights.cycleLength).frame(height: 22).padding(.top, 20)
                HStack {
                    Text("Your cycle: \(insights.cycleLength) days").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.foreground)
                    Spacer()
                    Text("Typical: 21–35 days").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                .padding(.top, 12)
                Text(insights.insight).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            } else {
                Text("Log your last period to see cycle regularity.")
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 12)
            }
        }
        .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func rangeBar(cycleLength: Int) -> some View {
        GeometryReader { geo in rangeContent(width: geo.size.width, cycleLength: cycleLength) }
    }

    private func rangeContent(width: Double, cycleLength: Int) -> some View {
        let axisMin = 15.0, axisMax = 40.0
        func x(_ day: Double) -> Double { (day - axisMin) / (axisMax - axisMin) * width }
        return ZStack(alignment: .leading) {
            Capsule().fill(GenesyxColor.muted.opacity(0.5)).frame(height: 10)
            Capsule()
                .fill(LinearGradient(colors: [GenesyxColor.electricLavender.opacity(0.6), GenesyxColor.babyLavender.opacity(0.6)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: max(x(35) - x(21), 2), height: 10).offset(x: x(21))
            Circle().fill(GenesyxColor.primary).frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .offset(x: min(max(x(Double(cycleLength)) - 8, 0), width - 16))
        }
        .frame(height: 22)
    }
}

/// 4×7 heatmap of real logged-symptom counts over 28 days, with an honest thin-data guard.
private struct SymptomPatternsCard: View {
    let insights: SymptomPatternInsights
    let weekdayLabels: [String]
    let dates: [CalendarDate]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Symptom patterns").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text("Last 4 weeks").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
            }
            if insights.daysWithSymptoms == 0 {
                Text("No symptoms logged yet. Log how you feel to see patterns.")
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 12)
            } else {
                heatmap.padding(.top, 16)
            }
            Text(insights.insight).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
        }
        .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var heatmap: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Color.clear.frame(width: 32, height: 1)
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label).font(.system(size: 9)).foregroundStyle(GenesyxColor.mutedForeground).frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<4, id: \.self) { week in
                HStack(spacing: 6) {
                    Text("Wk \(week + 1)").font(.system(size: 9)).foregroundStyle(GenesyxColor.mutedForeground)
                        .frame(width: 32, alignment: .leading)
                    ForEach(0..<7, id: \.self) { day in
                        let index = week * 7 + day
                        let count = index < insights.dailyCounts.count ? insights.dailyCounts[index] : 0
                        cell(index: index, count: count)
                    }
                }
            }
        }
    }

    /// A heatmap cell. Days with symptoms tap through to that day's Log History entry;
    /// empty days are inert (nothing to open).
    @ViewBuilder
    private func cell(index: Int, count: Int) -> some View {
        let swatch = RoundedRectangle(cornerRadius: 6)
            .fill(GenesyxColor.electricLavender.opacity(alpha(count)))
            .frame(height: 26).frame(maxWidth: .infinity)
        if count > 0, index < dates.count {
            NavigationLink { LogHistoryView(focusDate: dates[index]) } label: { swatch }
                .buttonStyle(.plain)
                .accessibilityLabel("Symptoms logged, open this day")
        } else {
            swatch
        }
    }

    private func alpha(_ count: Int) -> Double {
        switch count {
        case 0:  return 0.05
        case 1:  return 0.2
        case 2:  return 0.35
        default: return 0.5
        }
    }
}

/// Predicted ovulation + fertile window on a cycle timeline. Everything is labelled "predicted".
private struct OvulationCard: View {
    let insights: OvulationInsights?
    let cycleLength: Int
    let periodLength: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ovulation").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Text("This cycle").font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary)
            }
            if let insights {
                timeline(insights).frame(height: 26).padding(.top, 20)
                HStack(spacing: 12) {
                    tile("Ovulation day", "Day \(insights.ovulationDay)")
                    tile("Fertile window", "Day \(insights.fertileWindow.startDay)–\(insights.fertileWindow.endDay)")
                }
                .padding(.top, 16)
                Text(insights.insight).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            } else {
                Text("Set up your cycle to see your ovulation window.")
                    .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 12)
            }
        }
        .padding(20).background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func timeline(_ ins: OvulationInsights) -> some View {
        GeometryReader { geo in timelineContent(width: geo.size.width, ins: ins) }
    }

    private func timelineContent(width: Double, ins: OvulationInsights) -> some View {
        let total = Double(max(cycleLength, 1))
        func x(_ day: Int) -> Double { Double(max(day - 1, 0)) / total * width }
        let fertileStart = max(ins.fertileWindow.startDay, 1)
        let fertileEnd = min(ins.fertileWindow.endDay, cycleLength)
        return ZStack(alignment: .leading) {
            Capsule().fill(GenesyxColor.muted.opacity(0.5)).frame(height: 10)
            Capsule().fill(GenesyxColor.electricPink.opacity(0.55))
                .frame(width: max(x(periodLength + 1) - x(1), 2), height: 10).offset(x: x(1))
            Capsule().fill(GenesyxColor.electricLavender.opacity(0.6))
                .frame(width: max(x(fertileEnd + 1) - x(fertileStart), 2), height: 10).offset(x: x(fertileStart))
            Circle().fill(GenesyxColor.primary).frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                .offset(x: min(max(x(ins.ovulationDay) - 6, 0), width - 12))
            Rectangle().fill(GenesyxColor.foreground)
                .frame(width: 2, height: 22)
                .offset(x: min(max(x(ins.cycleDay) - 1, 0), width - 2), y: -6)
        }
        .frame(height: 22)
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Full urine-pH tracker (card + chart + Log pH), pushed from the Insights "Open tracker" link.
private struct PhTrackerScreen: View {
    var body: some View {
        ScrollView {
            PhTrackerSection()
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(GenesyxColor.background)
        .navigationTitle("Urine pH")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Log history

/// Full history of the user's daily logs — every entry made on "Log Today", newest first.
/// Pushed from Insights so the user can read back all their logs. Read-only.
struct LogHistoryView: View {

    /// When set (e.g. tapped from the symptom heatmap), scroll to and briefly highlight that day.
    var focusDate: CalendarDate? = nil

    @EnvironmentObject private var dailyLog: DailyLogRepository

    private var entries: [(date: CalendarDate, log: DailyLog)] {
        dailyLog.logByDate
            .filter { !$0.value.isBlank }
            .map { (date: $0.key, log: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(entries, id: \.date) { entry in
                            LogHistoryCard(date: entry.date, log: entry.log,
                                           highlighted: entry.date == focusDate)
                                .id(entry.date)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .onAppear {
                guard let focusDate else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation { proxy.scrollTo(focusDate, anchor: .top) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(GenesyxColor.background)
        .navigationTitle("Your logs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 28)).foregroundStyle(GenesyxColor.mutedForeground)
            Text("No logs yet")
                .font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            Text("Your daily logs will appear here once you start logging.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct LogHistoryCard: View {
    let date: CalendarDate
    let log: DailyLog
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.dateFormatter.string(from: date.toDate()))
                .font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)

            if log.mood != nil || log.energy != nil {
                HStack(spacing: 8) {
                    if let mood = log.mood { pill("Mood", mood.label) }
                    if let energy = log.energy { pill("Energy", energy.rawValue.capitalized) }
                }
            }

            if !log.symptoms.isEmpty {
                metricRow("Symptoms", log.symptoms.sorted().joined(separator: ", "))
            }
            if let minutes = log.sleepMinutes {
                metricRow("Sleep", "\(minutes / 60)h \(minutes % 60)m")
            }
            if log.waterMl > 0 {
                metricRow("Water", String(format: "%.1f L", Double(log.waterMl) / 1000))
            }
            if !log.supplements.isEmpty {
                metricRow("Supplements", log.supplements.sorted().joined(separator: ", "))
            }
            if let notes = log.notes, !notes.isEmpty {
                metricRow("Notes", notes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(GenesyxColor.primary, lineWidth: highlighted ? 2 : 0))
    }

    private func pill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(GenesyxColor.mutedForeground)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(GenesyxColor.muted.opacity(0.5))
        .clipShape(Capsule())
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Text(value).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM yyyy"
        return f
    }()
}

private extension DailyLog {
    /// A log with no data worth showing in history.
    var isBlank: Bool {
        mood == nil && energy == nil && symptoms.isEmpty && sleepMinutes == nil
            && supplements.isEmpty && (notes?.isEmpty ?? true) && waterMl == 0
    }
}
