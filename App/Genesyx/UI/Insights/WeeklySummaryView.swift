import SwiftUI
import GenesyxCore

/// Weekly Summary — a scannable recap of one ISO week (Mon–Sun), shown at the top of My Logs.
/// The week selector defaults to the current week; forward is disabled once you reach it. Every
/// value is derived from real logged data via `WeeklySummaryLogic`, and the narrative is a single
/// deterministic line (no LLM).
struct WeeklySummaryView: View {

    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var ph: PhRepository

    @State private var weekStart: CalendarDate = CalendarDate.today().startOfWeek

    private let goalMl = 2400
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let barHeight: CGFloat = 96
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var phValuesByDate: [CalendarDate: [Double]] {
        var map: [CalendarDate: [Double]] = [:]
        for r in ph.readings {
            map[CalendarDate.today(now: r.recordedAt), default: []].append(r.phValue)
        }
        return map
    }

    private var summary: WeeklySummary {
        WeeklySummaryLogic.summary(
            weekStart: weekStart, logsByDate: dailyLog.logByDate,
            phValuesByDate: phValuesByDate, goalMl: goalMl)
    }

    /// True once the selected week is the current one — the forward arrow can go no further.
    private var isCurrentWeek: Bool { weekStart >= CalendarDate.today().startOfWeek }

    private var rangeLabel: String {
        let sunday = weekStart.addingDays(6)
        if weekStart.month == sunday.month {
            return "\(weekStart.day)–\(sunday.day) \(Self.months[sunday.month - 1])"
        }
        return "\(weekStart.day) \(Self.months[weekStart.month - 1]) – \(sunday.day) \(Self.months[sunday.month - 1])"
    }

    var body: some View {
        let s = summary
        return VStack(alignment: .leading, spacing: 0) {
            selector
            if s.isEmpty {
                emptyState
            } else {
                chart(s).padding(.top, 18)
                dotRow(s).padding(.top, 16)
                statTiles(s).padding(.top, 16)
                moodEnergyRows(s)
                deltaChips(s)
                Text(s.narrative)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Selector

    private var selector: some View {
        HStack {
            Text("Weekly summary").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            Spacer()
            HStack(spacing: 10) {
                Button { weekStart = weekStart.addingDays(-7) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(GenesyxColor.primary)
                Text(rangeLabel)
                    .font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.foreground)
                    .frame(minWidth: 84)
                Button { weekStart = weekStart.addingDays(7) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isCurrentWeek ? GenesyxColor.mutedForeground : GenesyxColor.primary)
                .opacity(isCurrentWeek ? 0.35 : 1)
                .disabled(isCurrentWeek)
            }
        }
    }

    // MARK: Chart (water bars vs goal line)

    private func chart(_ s: WeeklySummary) -> some View {
        ZStack(alignment: .top) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(s.waterByDay.enumerated()), id: \.offset) { index, ml in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ml > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [GenesyxColor.electricBlue, GenesyxColor.powderBlue],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(GenesyxColor.muted))
                            .frame(height: ml > 0 ? max(barHeight * CGFloat(min(Double(ml) / Double(goalMl), 1)), 2) : 2)
                        Text(dayLetters[index]).font(.system(size: 10)).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight + 18)
            HStack(spacing: 6) {
                WeeklyDashedLine().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(GenesyxColor.mutedForeground.opacity(0.6)).frame(height: 1)
                Text(String(format: "%.1fL goal", Double(goalMl) / 1000)).font(.system(size: 9))
                    .foregroundStyle(GenesyxColor.mutedForeground).fixedSize()
            }
        }
    }

    // MARK: Logged-day dot row

    private func dotRow(_ s: WeeklySummary) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { i in
                let on = i < s.loggedDays.count && s.loggedDays[i]
                Circle()
                    .fill(on ? GenesyxColor.primary : GenesyxColor.muted.opacity(0.5))
                    .frame(width: 18, height: 18)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white).opacity(on ? 1 : 0))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Stat tiles + mood/energy/sleep/pH rows

    private func statTiles(_ s: WeeklySummary) -> some View {
        HStack(spacing: 12) {
            tile("Week total", String(format: "%.1f L", Double(s.waterTotalMl) / 1000))
            tile("Days on goal", "\(s.daysOnGoal) / 7")
        }
    }

    @ViewBuilder
    private func moodEnergyRows(_ s: WeeklySummary) -> some View {
        if !s.moodTallies.isEmpty {
            metricRow("Mood", s.moodTallies.map { "\($0.mood.label) ×\($0.count)" }.joined(separator: " · "))
                .padding(.top, 12)
        }
        if !s.energyTallies.isEmpty {
            metricRow("Energy", s.energyTallies.map { "\($0.level.id.capitalized) ×\($0.count)" }.joined(separator: " · "))
                .padding(.top, 10)
        }
        if let sleep = s.sleepAverageMinutes {
            metricRow("Sleep average", "\(sleep / 60)h \(sleep % 60)m").padding(.top, 10)
        }
        if let phAvg = s.phAverage {
            metricRow("pH average", String(format: "%.2f", phAvg)).padding(.top, 10)
        }
    }

    // MARK: Delta chips (vs previous week)

    @ViewBuilder
    private func deltaChips(_ s: WeeklySummary) -> some View {
        let chips = deltaItems(s)
        if !chips.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    HStack(spacing: 4) {
                        Image(systemName: chip.symbol).font(.system(size: 10, weight: .semibold))
                        Text(chip.text).font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(GenesyxColor.muted.opacity(0.4)).clipShape(Capsule())
                }
            }
            .padding(.top, 12)
        }
    }

    private func deltaItems(_ s: WeeklySummary) -> [(symbol: String, text: String)] {
        var out: [(String, String)] = []
        if let w = s.deltas.waterTotalMl {
            out.append((arrow(w), "\(signed(w))ml water"))
        }
        if let d = s.deltas.daysLogged {
            out.append((arrow(d), "\(signed(d)) day\(abs(d) == 1 ? "" : "s") logged"))
        }
        if let sleep = s.deltas.sleepAverageMinutes {
            out.append((arrow(sleep), "\(signed(sleep))m sleep"))
        }
        return out
    }

    private func arrow(_ v: Int) -> String { v > 0 ? "arrow.up" : (v < 0 ? "arrow.down" : "arrow.right") }
    private func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : (v < 0 ? "−\(abs(v))" : "±0") }

    // MARK: Empty state

    private var emptyState: some View {
        Text("Nothing logged this week yet — one small entry starts the picture.")
            .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
            .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
    }

    // MARK: Reusable bits

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

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Eyebrow(label, color: GenesyxColor.mutedForeground)
            Spacer()
            Text(value).font(.gxBodySmall.weight(.medium)).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
        }
    }
}

/// Horizontal dashed goal line for the weekly water chart (mirrors the Insights hydration chart).
private struct WeeklyDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
