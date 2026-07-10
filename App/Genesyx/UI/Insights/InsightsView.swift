import SwiftUI
import GenesyxCore

/// Insights — pH insights (from real readings) + cycle regularity, symptom heatmap, and
/// nutrition consistency (mock analytics, ported verbatim from `mockData.ts`).
struct InsightsView: View {

    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository

    // Mock analytics, ported verbatim from the Android InsightsScreen (kept hidden for v1).
    private let cycleBars = [82, 78, 90, 85, 88, 80, 92]
    private let nutritionBars = [60, 75, 70, 85, 78, 90, 82]

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

    private var hydrationInsightsCard: some View {
        let week = last7Days
        let insights = HydrationInsightLogic.compute(
            dailyMl: week.map(\.ml), goalMl: Self.waterGoalMl, streak: dailyLog.streak())
        return HydrationInsightsCard(
            insights: insights, labels: week.map(\.label),
            goalMl: Self.waterGoalMl, hasPh: !ph.readings.isEmpty)
    }

    var body: some View {
        let insights = PhInsightLogic.compute(ph.readings)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    logHistoryLink
                    PhInsightsCard(ph: insights)
                    hydrationInsightsCard
                    // v1: mock analytics (cycle regularity, symptom heatmap, nutrition consistency)
                    // are hidden pending real data — only the pH insight above is computed from real
                    // readings. To restore, remove the /* */ around the block below.
                    /*
                    BarsCard(
                        title: "Cycle regularity", trailing: "Last 7 cycles",
                        values: cycleBars, labels: (1...7).map { "C\($0)" }, barHeight: 128,
                        gradient: LinearGradient(colors: [GenesyxColor.primary.opacity(0.8), GenesyxColor.primary.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                        insight: "Your cycles are tracking with steady consistency — a small day-to-day variation is completely typical."
                    )
                    SymptomPatternsCard()
                    BarsCard(
                        title: "Nutrition consistency", trailing: nil,
                        values: nutritionBars, labels: ["M", "T", "W", "T", "F", "S", "S"], barHeight: 112,
                        gradient: LinearGradient(colors: [GenesyxColor.electricBlue, GenesyxColor.powderBlue], startPoint: .top, endPoint: .bottom),
                        insight: "You've stayed close to your hydration goal four days this week — gentle progress."
                    )
                    */
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

private struct PhInsightsCard: View {
    let ph: PhInsights

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
                let status = ph.currentStatus ?? .optimal
                let color = Theme.color(for: status)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow("Current", color: GenesyxColor.mutedForeground)
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f", ph.currentValue ?? 0))
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
                HStack(spacing: 12) {
                    avgTile("7-day avg", ph.avg7)
                    avgTile("30-day avg", ph.avg30)
                }
                .padding(.top, 16)
                Text(ph.insight).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 16)
                if !ph.recommendation.isEmpty {
                    Text(ph.recommendation).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var trendBadge: some View {
        let symbol: String
        switch ph.trend {
        case .up: symbol = "arrow.up"
        case .down: symbol = "arrow.down"
        case .flat: symbol = "arrow.right"
        }
        return HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            Text("vs previous").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [GenesyxColor.electricBlue, GenesyxColor.powderBlue],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: max(barHeight * CGFloat(min(Double(ml) / Double(goalMl), 1)), 2))
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
                Text("2.4L goal").font(.system(size: 9)).foregroundStyle(GenesyxColor.mutedForeground).fixedSize()
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

private struct BarsCard: View {
    let title: String
    let trailing: String?
    let values: [Int]
    let labels: [String]
    let barHeight: CGFloat
    let gradient: LinearGradient
    let insight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                Text(title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                if let trailing { Text(trailing).font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.primary) }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(values.indices, id: \.self) { i in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gradient)
                            .frame(height: barHeight * CGFloat(values[i]) / 100)
                        Text(labels[i]).font(.system(size: 10)).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight + 18)
            .padding(.top, 18)
            Text(insight).font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 14)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct SymptomPatternsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Symptom patterns").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            VStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { c in
                            let intensity = (sin(Double(r * 7 + c) * 1.7) + 1) / 2
                            RoundedRectangle(cornerRadius: 6)
                                .fill(GenesyxColor.primary.opacity(alpha(intensity)))
                                .frame(height: 26)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.top, 14)
            Text("Fatigue tends to ease in the second half of your cycle — useful to plan rest accordingly.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8)).padding(.top, 14)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func alpha(_ intensity: Double) -> Double {
        if intensity > 0.7 { return 0.5 }
        if intensity > 0.4 { return 0.3 }
        if intensity > 0.15 { return 0.15 }
        return 0.05
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

    @EnvironmentObject private var dailyLog: DailyLogRepository

    private var entries: [(date: CalendarDate, log: DailyLog)] {
        dailyLog.logByDate
            .filter { !$0.value.isBlank }
            .map { (date: $0.key, log: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty {
                    emptyState
                } else {
                    ForEach(entries, id: \.date) { entry in
                        LogHistoryCard(date: entry.date, log: entry.log)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
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
