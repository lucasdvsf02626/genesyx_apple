import SwiftUI
import GenesyxCore

/// Track — month calendar with phase colors + current-phase card + cycle settings editor.
/// Ported from the Android `TrackScreen`. (The pH tracker section is translated separately.)
struct TrackView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var router: TabRouter

    @State private var monthAnchor = YearMonth.current
    @State private var showCycleSheet = false
    @State private var showCycleDetail = false
    @State private var selectedDay: DayInfo?
    @State private var showLog = false
    @State private var showHydration = false
    @State private var showPhDetail = false
    @State private var showSleepDetail = false
    @State private var showSymptomsDetail = false
    @State private var showNutritionDetail = false

    private let today = CalendarDate.today()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    calendarCard
                    currentPhaseCard
                    GxPrimaryButton(title: "Add to today's log", leadingSystemImage: "plus") { showLog = true }
                    trackersSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.background)
        }
        .sheet(isPresented: $showCycleSheet) {
            CycleSettingsSheet(current: cycle.settings) { cycle.upsert($0) }
        }
        .sheet(isPresented: $showCycleDetail) {
            CycleDetailView(settings: cycle.settings) { showCycleSheet = true }
        }
        .sheet(isPresented: $showLog) { LogView() }
        .sheet(isPresented: $showHydration) { HydrationDetailSheet() }
        .sheet(isPresented: $showPhDetail) { PhDetailView() }
        .sheet(isPresented: $showSleepDetail) { SleepDetailView() }
        .sheet(isPresented: $showSymptomsDetail) { SymptomsDetailView() }
        .sheet(isPresented: $showNutritionDetail) { NutritionDetailView() }
        .sheet(item: $selectedDay) { day in DayDetailSheet(day: day, today: today, log: dailyLog.log(on: day.date)) }
        .onAppear { consumePendingHydration(); consumePendingPh() }
        .onChange(of: router.pendingHydration) { _ in consumePendingHydration() }
        .onChange(of: router.pendingPh) { _ in consumePendingPh() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthAnchor.title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Text(subtitle).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            Button { showCycleSheet = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundStyle(GenesyxColor.foreground)
                    .frame(width: 36, height: 36)
                    .background(GenesyxColor.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        guard let s = cycle.settings else { return "Set up your cycle" }
        let info = CycleEngine.cyclePhase(settings: s, target: today)
        let n = CycleEngine.cycleNumber(lastPeriodDate: s.lastPeriodDate, cycleLength: s.cycleLength, target: today)
        return "Cycle \(n) · Day \(info.dayOfCycle)"
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                monthNav("chevron.left") { monthAnchor = monthAnchor.adding(months: -1) }
                Spacer()
                Text(monthAnchor.shortTitle).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                Spacer()
                monthNav("chevron.right") { monthAnchor = monthAnchor.adding(months: 1) }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { i in
                    Text(["S", "M", "T", "W", "T", "F", "S"][i])
                        .font(.gxEyebrow).foregroundStyle(GenesyxColor.mutedForeground)
                }
            }

            if let settings = cycle.settings {
                let cells = CycleEngine.buildMonthGrid(monthAnchor: monthAnchor, settings: settings, today: today)
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(cells.indices, id: \.self) { i in
                        cellView(cells[i])
                    }
                }
                legend
            } else {
                emptyCalendar
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    @ViewBuilder
    private func cellView(_ cell: CalendarCell) -> some View {
        switch cell {
        case .empty:
            Color.clear.aspectRatio(1, contentMode: .fit)
        case let .day(date, info, isToday):
            let type = CycleEngine.dayType(for: info)
            Button { selectedDay = DayInfo(date: date, info: info) } label: {
                Text("\(date.day)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(type == .ovulation ? .white : GenesyxColor.foreground)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(cellBackground(type))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(cellBorder(type: type, isToday: isToday))
            }
            .buttonStyle(.plain)
        }
    }

    private func cellBackground(_ type: DayType) -> Color {
        switch type {
        case .period: return GenesyxColor.powderPink.tintOnWhite(0.55)
        case .fertile: return GenesyxColor.powderBlue.tintOnWhite(0.55)
        case .ovulation: return GenesyxColor.primary
        case .luteal: return GenesyxColor.babyLavender.tintOnWhite(0.25)
        case .follicular: return GenesyxColor.card
        }
    }

    @ViewBuilder
    private func cellBorder(type: DayType, isToday: Bool) -> some View {
        if isToday {
            RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.foreground, lineWidth: 2)
        } else if type == .follicular {
            RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1)
        }
    }

    private func monthNav(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(GenesyxColor.foreground)
                .frame(width: 32, height: 32)
                .background(GenesyxColor.muted)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        let items: [(String, Color)] = [
            ("Period", GenesyxColor.powderPink.tintOnWhite(0.55)),
            ("Fertile window", GenesyxColor.powderBlue.tintOnWhite(0.55)),
            ("Ovulation", GenesyxColor.primary),
            ("Luteal", GenesyxColor.babyLavender.tintOnWhite(0.25)),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.0) { label, color in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 14, height: 14)
                    Text(label).font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground)
                }
            }
        }
    }

    private var emptyCalendar: some View {
        Button { showCycleSheet = true } label: {
            VStack(spacing: 4) {
                Text("Add your cycle").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                Text("Tell us when your last period started to see your phases here.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28).padding(.horizontal, 16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(GenesyxColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Current phase

    private var currentPhaseCard: some View {
        let info = cycle.settings.map { CycleEngine.cyclePhase(settings: $0, target: today) }
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Current phase", color: GenesyxColor.primary)
            Text(info.map { CycleContent.phaseLabel[$0.phase]! } ?? "—")
                .font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
            Text(phaseBlurb(info))
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func phaseBlurb(_ info: CyclePhaseInfo?) -> String {
        guard let info else { return "Set up your cycle to see today's phase." }
        if info.fertileWindow.contains(info.dayOfCycle) {
            return "You're in your fertile window. Stay hydrated and prioritise rest."
        }
        return "About \(info.daysUntilNextPeriod) days until your next period."
    }

    // MARK: Trackers

    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR TRACKERS")
                .font(.gxEyebrow)
                .tracking(1.4)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                trackerButton(TrackSignalSummary.cycle(settings: cycle.settings, today: today)) { showCycleDetail = true }
                divider
                trackerButton(TrackSignalSummary.hydration(logs: dailyLog.logByDate, today: today)) { showHydration = true }
                divider
                trackerButton(TrackSignalSummary.ph(readings: ph.readings, today: today)) { showPhDetail = true }
                divider
                trackerButton(TrackSignalSummary.sleep(logs: dailyLog.logByDate, today: today)) { showSleepDetail = true }
                divider
                trackerButton(TrackSignalSummary.symptoms(logs: dailyLog.logByDate, today: today)) { showSymptomsDetail = true }
                divider
                trackerButton(TrackSignalSummary.nutrition(logs: dailyLog.logByDate, today: today)) { showNutritionDetail = true }
            }
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(GenesyxColor.border.opacity(0.6))
            .frame(height: 1)
            .padding(.leading, 64)
    }

    private func trackerButton(_ summary: TrackSignalSummary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: summary.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(summary.tint)
                    .frame(width: 38, height: 38)
                    .background(summary.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.title)
                        .font(.gxCardHeadingSmall)
                        .foregroundStyle(GenesyxColor.foreground)
                    Text(summary.value)
                        .font(.gxBodySmall)
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                SparkDots(values: summary.sparkValues, tint: summary.tint)
                    .frame(width: 72)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.title), \(summary.value)")
    }

    // MARK: Hydration

    /// Track is the canonical place to inspect and edit hydration. Home and Nutrition only summarize
    /// the same `DailyLogRepository` value.
    private var hydrationCard: some View {
        let goal = TrackingEngine.defaultWaterGoalMl
        let water = dailyLog.waterMl(on: today)
        let progress = goal > 0 ? min(Double(water) / Double(goal), 1) : 0
        let streak = dailyLog.streak(today: today)
        return Button { showHydration = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow("Hydration", color: GenesyxColor.electricBlue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(water.formatted()).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                    Text("/ \(goal.formatted()) ml")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    Spacer()
                    Text("Manage")
                        .font(.gxBodySmall.weight(.semibold)).foregroundStyle(GenesyxColor.primary)
                }
                ProgressView(value: progress).tint(GenesyxColor.electricBlue)
                HStack(spacing: 8) {
                    Text("\(Int((progress * 100).rounded()))% of goal")
                    if streak > 0 {
                        Text("•")
                        Text("\(streak)-day streak")
                    }
                }
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(20)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration, \(water.formatted()) of \(goal.formatted()) millilitres")
        .accessibilityHint("Opens hydration controls")
    }

    private func consumePendingHydration() {
        guard router.pendingHydration else { return }
        router.pendingHydration = false
        showHydration = true
    }

    private func consumePendingPh() {
        guard router.pendingPh else { return }
        router.pendingPh = false
        showPhDetail = true
    }
}

struct TrackSignalSummary: Equatable {
    let title: String
    let icon: String
    let value: String
    let sparkValues: [Double]
    let tint: Color

    static let emptyValue = "No entries yet — log today to start"

    static func cycle(settings: CycleSettings?, today: CalendarDate) -> TrackSignalSummary {
        guard let settings else {
            return TrackSignalSummary(
                title: "Cycle",
                icon: "calendar",
                value: "Cycle data is building",
                sparkValues: [],
                tint: GenesyxColor.primary)
        }
        let copy = CyclePredictionCopy.summary(settings: settings, today: today)
        return TrackSignalSummary(
            title: "Cycle",
            icon: "calendar",
            value: copy,
            sparkValues: Array(repeating: 1, count: 7),
            tint: GenesyxColor.primary)
    }

    static func hydration(logs: [CalendarDate: DailyLog], today: CalendarDate, goalMl: Int = TrackingEngine.defaultWaterGoalMl) -> TrackSignalSummary {
        let week = trailingSeven(today: today).map { logs[$0]?.waterMl ?? 0 }
        let todayMl = logs[today]?.waterMl ?? 0
        return TrackSignalSummary(
            title: "Hydration",
            icon: "drop.fill",
            value: todayMl > 0 ? "\(todayMl.formatted()) / \(goalMl.formatted()) ml" : emptyValue,
            sparkValues: week.map { goalMl > 0 ? min(Double($0) / Double(goalMl), 1) : 0 },
            tint: GenesyxColor.electricBlue)
    }

    static func ph(readings: [PhReading], today: CalendarDate) -> TrackSignalSummary {
        let valuesByDate = Dictionary(grouping: readings) { CalendarDate.today(now: $0.recordedAt) }
            .mapValues { $0.last?.phValue ?? 0 }
        let latest = readings.last
        return TrackSignalSummary(
            title: "Urine pH",
            icon: "testtube.2",
            value: latest.map { String(format: "Latest %.1f", $0.phValue) } ?? emptyValue,
            sparkValues: trailingSeven(today: today).map { date in
                guard let value = valuesByDate[date] else { return 0 }
                return min(max((value - PhStatus.min) / (PhStatus.max - PhStatus.min), 0), 1)
            },
            tint: GenesyxColor.primary)
    }

    static func sleep(logs: [CalendarDate: DailyLog], today: CalendarDate) -> TrackSignalSummary {
        let week = SleepTrackingData.lastSevenMinutes(logs: logs, today: today)
        let todayMinutes = SleepTrackingData.todayMinutes(logs: logs, today: today)
        return TrackSignalSummary(
            title: "Sleep",
            icon: "bed.double.fill",
            value: SleepTrackingData.valueLabel(todayMinutes),
            sparkValues: week.map { min(Double($0) / Double(SleepInsightLogic.chartCeilingMinutes), 1) },
            tint: GenesyxColor.electricLavender)
    }

    static func symptoms(logs: [CalendarDate: DailyLog], today: CalendarDate) -> TrackSignalSummary {
        let week = trailingSeven(today: today).map { logs[$0]?.symptoms.count ?? 0 }
        let todayCount = logs[today]?.symptoms.count ?? 0
        return TrackSignalSummary(
            title: "Symptoms",
            icon: "waveform.path.ecg",
            value: todayCount > 0 ? "\(todayCount) logged today" : emptyValue,
            sparkValues: week.map { min(Double($0) / 4.0, 1) },
            tint: GenesyxColor.electricPink)
    }

    static func nutrition(logs: [CalendarDate: DailyLog], today: CalendarDate) -> TrackSignalSummary {
        let week = currentWeekDates(today: today).map { logs[$0]?.supplements.count ?? 0 }
        let todayCount = logs[today]?.supplements.count ?? 0
        return TrackSignalSummary(
            title: "Nutrition",
            icon: "pills.fill",
            value: todayCount > 0 ? "\(todayCount) of \(NutritionConsistencyLogic.planSize) supplements today" : emptyValue,
            sparkValues: week.map { min(Double($0) / Double(NutritionConsistencyLogic.planSize), 1) },
            tint: GenesyxColor.primary)
    }

    static func trailingSeven(today: CalendarDate) -> [CalendarDate] {
        (0..<7).map { today.minusDays(6 - $0) }
    }

    static func currentWeekDates(today: CalendarDate) -> [CalendarDate] {
        let monday = today.startOfWeek
        return (0..<7).map { monday.addingDays($0) }
    }
}

enum SleepTrackingData {
    static func todayMinutes(logs: [CalendarDate: DailyLog], today: CalendarDate) -> Int? {
        logs[today]?.sleepMinutes
    }

    static func lastSevenMinutes(logs: [CalendarDate: DailyLog], today: CalendarDate) -> [Int] {
        lastSevenRows(logs: logs, today: today).map(\.minutes)
    }

    static func lastSevenRows(logs: [CalendarDate: DailyLog], today: CalendarDate) -> [SleepHistoryRow] {
        TrackSignalSummary.trailingSeven(today: today).map { date in
            SleepHistoryRow(date: date, minutes: logs[date]?.sleepMinutes ?? 0)
        }
    }

    static func currentWeekMinutes(logs: [CalendarDate: DailyLog], today: CalendarDate) -> [Int] {
        TrackSignalSummary.currentWeekDates(today: today).map { logs[$0]?.sleepMinutes ?? 0 }
    }

    static func valueLabel(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return TrackSignalSummary.emptyValue }
        return SleepInsightLogic.durationLabel(minutes)
    }

    static func trendSummary(logs: [CalendarDate: DailyLog], today: CalendarDate) -> String? {
        let insights = SleepInsightLogic.compute(dailyMinutes: lastSevenMinutes(logs: logs, today: today))
        return insights.nightsLogged > 0 ? insights.insight : nil
    }
}

struct SleepHistoryRow: Equatable {
    let date: CalendarDate
    let minutes: Int

    func dayLabel(today: CalendarDate) -> String {
        if date == today { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date.toDate())
    }
}

enum CyclePredictionCopy {
    static func summary(settings: CycleSettings, today: CalendarDate) -> String {
        let info = CycleEngine.cyclePhase(settings: settings, target: today)
        let ovulation = OvulationLogic.compute(settings: settings, today: today)
        let prefix = "Day \(info.dayOfCycle)"
        guard let ovulation else {
            return "\(prefix) · \(phaseLabel(info.phase))"
        }
        if info.dayOfCycle == ovulation.ovulationDay {
            return "\(prefix) · Predicted ovulation day"
        }
        if let days = ovulation.daysUntilOvulation, days <= 3 {
            if days == 1 { return "\(prefix) · Ovulation predicted tomorrow" }
            return "\(prefix) · Ovulation predicted in \(days) days"
        }
        return "\(prefix) · \(phaseLabel(info.phase))"
    }

    static func phaseLabel(_ phase: Phase) -> String {
        let label = CycleContent.phaseLabel[phase] ?? phase.rawValue.capitalized
        if label.lowercased().hasSuffix("phase") {
            return label.replacingOccurrences(of: " Phase", with: " phase")
        }
        return "\(label) phase"
    }

    static func fertileWindowLabel(_ window: FertileWindow) -> String {
        "Predicted fertile window: days \(window.startDay)–\(window.endDay)"
    }

    static func ovulationDayLabel(_ day: Int) -> String {
        "Predicted ovulation day: day \(day)"
    }
}

private struct SparkDots: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(normalized.enumerated()), id: \.offset) { _, value in
                Circle()
                    .fill(value > 0 ? tint.opacity(value >= 1 ? 1 : 0.45) : GenesyxColor.muted)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private var normalized: [Double] {
        let values = values.prefix(7).map { min(max($0, 0), 1) }
        return values + Array(repeating: 0, count: max(0, 7 - values.count))
    }
}

private struct CycleDetailView: View {
    let settings: CycleSettings?
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let today = CalendarDate.today()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let settings {
                        cycleContent(settings)
                    } else {
                        emptyCycleContent
                    }
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func cycleContent(_ settings: CycleSettings) -> some View {
        let info = CycleEngine.cyclePhase(settings: settings, target: today)
        return VStack(alignment: .leading, spacing: 16) {
            todayCard(
                eyebrow: "Today",
                title: CyclePredictionCopy.summary(settings: settings, today: today),
                subtitle: "Predictions use your saved cycle length and last period date.",
                tint: GenesyxColor.primary)

            VStack(alignment: .leading, spacing: 12) {
                Text("PREDICTED TIMING")
                    .font(.gxEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                metricLine("Current cycle day", "Day \(info.dayOfCycle)")
                metricLine("Phase", CyclePredictionCopy.phaseLabel(info.phase))
                metricLine("Fertile window", "Days \(info.fertileWindow.startDay)–\(info.fertileWindow.endDay)")
                metricLine("Predicted ovulation", "Day \(info.ovulationDay)")
            }
            .padding(16)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            Text("\(CyclePredictionCopy.fertileWindowLabel(info.fertileWindow)). \(CyclePredictionCopy.ovulationDayLabel(info.ovulationDay)).")
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            Button {
                dismiss()
                onEdit()
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit cycle settings")
                }
                .font(.gxLabel)
                .foregroundStyle(GenesyxColor.primary)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(GenesyxColor.card)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyCycleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            todayCard(
                eyebrow: "Cycle",
                title: "Cycle data is building",
                subtitle: "Log more cycles to refine predictions.",
                tint: GenesyxColor.primary)
            Button {
                dismiss()
                onEdit()
            } label: {
                Text("Add cycle settings")
                    .font(.gxLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(GenesyxColor.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func metricLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)
            Spacer()
            Text(value)
                .font(.gxBodySmall.weight(.semibold))
                .foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct PhDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                PhTrackerSection()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Urine pH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// The full hydration editor. It is repository-backed, so changes immediately update Home,
/// Nutrition, Insights, streaks, and notification planning without a second view-owned total.
private struct HydrationDetailSheet: View {
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @Environment(\.dismiss) private var dismiss

    private let today = CalendarDate.today()
    private let goal = TrackingEngine.defaultWaterGoalMl
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    @State private var manualMl = ""
    @State private var feedbackOverride: DailyLogSyncState?

    var body: some View {
        let water = dailyLog.waterMl(on: today)
        let streak = dailyLog.streak(today: today)
        let insight = HydrationInsightLogic.lastSevenDays(
            logByDate: dailyLog.logByDate, goalMl: goal, streak: streak, today: today)
        let status = HydrationStatusEvaluator.evaluate(
            todayMl: water, goalMl: goal,
            hour: Calendar.current.component(.hour, from: Date()),
            daysOnGoal: insight.daysOnGoal, streak: streak)
        let progress = goal > 0 ? min(Double(water) / Double(goal), 1) : 0
        let syncState = feedbackOverride ?? dailyLog.syncState(on: today)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("Today", color: GenesyxColor.electricBlue)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(water.formatted()).font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
                            Text("/ \(goal.formatted()) ml")
                                .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
                        }
                        ProgressView(value: progress).tint(GenesyxColor.electricBlue)
                        HStack(spacing: 6) {
                            syncIcon(syncState)
                            Text(syncState.label)
                        }
                        .font(.gxBodySmall.weight(.medium))
                        .foregroundStyle(syncColor(syncState))
                        Text(status.focusLine)
                            .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GenesyxColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                    quickActions(water: water)
                    manualEntry

                    weeklyBlock(insight)
                    historyBlock(insight)
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { manualMl = water == 0 ? "" : "\(water)" }
        .onChange(of: water) { newValue in
            guard manualMl.isEmpty || Int(manualMl) != newValue else { return }
            manualMl = newValue == 0 ? "" : "\(newValue)"
        }
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MANUAL ENTRY").font(.gxEyebrow).tracking(1.4)
                .foregroundStyle(GenesyxColor.mutedForeground)
            HStack(spacing: 10) {
                TextField("ml", text: $manualMl)
                    .keyboardType(.numberPad)
                    .font(.gxBody)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(GenesyxColor.muted.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Save") { saveManualEntry() }
                    .font(.gxLabel)
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 48)
                    .background(manualValue == nil ? GenesyxColor.mutedForeground.opacity(0.45) : GenesyxColor.primary)
                    .clipShape(Capsule())
                    .disabled(manualValue == nil)
            }
        }
        .padding(16)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func quickActions(water: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ADD").font(.gxEyebrow).tracking(1.4)
                .foregroundStyle(GenesyxColor.mutedForeground)
            HStack(spacing: 8) {
                adjustmentButton(title: "−250", delta: -250, secondary: true, disabled: water <= 0)
                adjustmentButton(title: "+200", delta: 200, secondary: false)
                adjustmentButton(title: "+250", delta: 250, secondary: false)
                adjustmentButton(title: "+500", delta: 500, secondary: false)
            }
        }
        .padding(16)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func adjustmentButton(title: String, delta: Int, secondary: Bool, disabled: Bool = false) -> some View {
        Button { applyHydrationChange { dailyLog.adjustWater(delta, on: today) } } label: {
            Text(title).font(.gxLabel)
                .foregroundStyle(secondary ? GenesyxColor.foreground : .white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(disabled ? GenesyxColor.muted.opacity(0.5) : (secondary ? GenesyxColor.muted : GenesyxColor.primary))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(delta < 0 ? "Remove \(-delta) millilitres" : "Add \(delta) millilitres")
    }

    private func weeklyBlock(_ insight: HydrationInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LAST 7 DAYS").font(.gxEyebrow).tracking(1.4)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                Spacer()
                Text("\(insight.daysOnGoal) of 7 on goal")
                    .font(.gxBodySmall.weight(.semibold))
                    .foregroundStyle(GenesyxColor.foreground)
            }
            HStack(spacing: 6) {
                ForEach(Array(insight.dailyMl.enumerated()), id: \.offset) { _, ml in
                    let level = HydrationInsightLogic.dayFillLevel(ml: ml, goalMl: goal)
                    Capsule()
                        .fill(level == 0
                              ? GenesyxColor.muted
                              : GenesyxColor.electricBlue.opacity(level == 1 ? 1 : 0.45))
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: streakIcon(streak: insight.streak))
                    .font(.system(size: 12))
                    .foregroundStyle(insight.streak > 0 ? GenesyxColor.electricPink : GenesyxColor.mutedForeground)
                Text("\(insight.streak)-day streak")
                    .font(.gxBodySmall.weight(.medium))
                    .foregroundStyle(GenesyxColor.foreground)
            }
            Text(insight.insight)
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func historyBlock(_ insight: HydrationInsights) -> some View {
        let rows = HydrationHistoryRow.lastSevenDays(today: today, dailyMl: insight.dailyMl)

        return VStack(alignment: .leading, spacing: 12) {
            Text("HISTORY").font(.gxEyebrow).tracking(1.4)
                .foregroundStyle(GenesyxColor.mutedForeground)
            Text("Daily totals")
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(rows, id: \.date) { row in
                    VStack(spacing: 4) {
                        Text(row.dayLabel(today: today))
                            .font(.gxEyebrow)
                            .foregroundStyle(GenesyxColor.mutedForeground)
                        Text(row.displayTotal)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(row.ml > 0 ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(GenesyxColor.muted.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var manualValue: Int? {
        guard let value = Int(manualMl.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return min(max(value, 0), 10_000)
    }

    private func saveManualEntry() {
        guard let value = manualValue else { return }
        applyHydrationChange { dailyLog.setWater(value, on: today) }
    }

    private func applyHydrationChange(_ change: () -> Void) {
        change()
        feedbackOverride = .saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            feedbackOverride = nil
        }
    }

    private func syncIcon(_ state: DailyLogSyncState) -> Image {
        switch state {
        case .saved: return Image(systemName: "checkmark.circle.fill")
        case .synced: return Image(systemName: "icloud.and.arrow.up.fill")
        case .willSyncWhenOnline: return Image(systemName: "icloud.slash")
        }
    }

    private func syncColor(_ state: DailyLogSyncState) -> Color {
        switch state {
        case .saved, .synced: return GenesyxColor.primary
        case .willSyncWhenOnline: return GenesyxColor.mutedForeground
        }
    }

    private func streakIcon(streak: Int) -> String {
        streak > 0 ? "flame.fill" : "flame"
    }

}

struct HydrationHistoryRow: Equatable {
    let date: CalendarDate
    let ml: Int

    static func lastSevenDays(today: CalendarDate, dailyMl: [Int]) -> [HydrationHistoryRow] {
        dailyMl.prefix(7).enumerated().map { offset, ml in
            HydrationHistoryRow(date: today.minusDays(6 - offset), ml: ml)
        }
    }

    var displayTotal: String {
        ml > 0 ? String(format: "%.1fL", Double(ml) / 1000) : "0L"
    }

    func dayLabel(today: CalendarDate) -> String {
        if date == today { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date.toDate())
    }
}

private struct SleepDetailView: View {
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @Environment(\.dismiss) private var dismiss

    private let today = CalendarDate.today()
    @State private var hours = 7
    @State private var minutes = 0
    @State private var feedbackOverride: DailyLogSyncState?

    var body: some View {
        let todayMinutes = SleepTrackingData.todayMinutes(logs: dailyLog.logByDate, today: today)
        let history = SleepTrackingData.lastSevenRows(logs: dailyLog.logByDate, today: today)
        let trendSummary = SleepTrackingData.trendSummary(logs: dailyLog.logByDate, today: today)
        let syncState = feedbackOverride ?? dailyLog.syncState(on: today)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    todayCard(
                        eyebrow: "Today",
                        title: SleepTrackingData.valueLabel(todayMinutes),
                        subtitle: "Sleep duration from today's log",
                        tint: GenesyxColor.electricLavender)
                    sleepEditor(todayMinutes: todayMinutes, syncState: syncState)
                    sleepHistoryCard(rows: history, today: today)
                    if let trendSummary {
                        insightCard(trendSummary)
                    }
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { syncPicker(to: todayMinutes) }
        .onChange(of: todayMinutes) { syncPicker(to: $0) }
        .onChange(of: hours) { if $0 >= 12 { minutes = 0 } }
    }

    private func sleepEditor(todayMinutes: Int?, syncState: DailyLogSyncState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EDIT SLEEP")
                .font(.gxEyebrow)
                .tracking(1.4)
                .foregroundStyle(GenesyxColor.mutedForeground)
            Stepper(value: $hours, in: 0...12) {
                HStack {
                    Text("Hours").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    Spacer()
                    Text("\(hours)h").font(.gxBodySmall.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                }
            }
            Stepper(value: $minutes, in: 0...(hours >= 12 ? 0 : 55), step: 5) {
                HStack {
                    Text("Minutes").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    Spacer()
                    Text("\(minutes)m").font(.gxBodySmall.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                }
            }
            HStack(spacing: 8) {
                Button("Save") { saveSleep() }
                    .font(.gxLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(GenesyxColor.primary)
                    .clipShape(Capsule())
                if todayMinutes != nil {
                    Button("Clear") { clearSleep() }
                        .font(.gxLabel)
                        .foregroundStyle(GenesyxColor.foreground)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(GenesyxColor.muted)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 6) {
                syncIcon(syncState)
                Text(syncState.label)
            }
            .font(.gxBodySmall.weight(.medium))
            .foregroundStyle(syncColor(syncState))
        }
        .padding(16)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func syncPicker(to total: Int?) {
        let value = total ?? 420
        hours = value / 60
        minutes = value % 60
    }

    private func saveSleep() {
        dailyLog.setSleep(hours * 60 + minutes, on: today)
        showSavedFeedback()
    }

    private func clearSleep() {
        dailyLog.setSleep(nil, on: today)
        showSavedFeedback()
    }

    private func showSavedFeedback() {
        feedbackOverride = .saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            feedbackOverride = nil
        }
    }

    private func syncIcon(_ state: DailyLogSyncState) -> Image {
        switch state {
        case .saved: return Image(systemName: "checkmark.circle.fill")
        case .synced: return Image(systemName: "icloud.and.arrow.up.fill")
        case .willSyncWhenOnline: return Image(systemName: "icloud.slash")
        }
    }

    private func syncColor(_ state: DailyLogSyncState) -> Color {
        switch state {
        case .saved, .synced: return GenesyxColor.primary
        case .willSyncWhenOnline: return GenesyxColor.mutedForeground
        }
    }
}

private func sleepHistoryCard(rows: [SleepHistoryRow], today: CalendarDate) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("LAST 7 DAYS")
            .font(.gxEyebrow)
            .tracking(1.4)
            .foregroundStyle(GenesyxColor.mutedForeground)
        HStack(spacing: 6) {
            ForEach(rows, id: \.date) { row in
                let fill = min(Double(row.minutes) / Double(SleepInsightLogic.chartCeilingMinutes), 1)
                VStack(spacing: 6) {
                    Capsule()
                        .fill(row.minutes > 0 ? GenesyxColor.electricLavender.opacity(fill >= 1 ? 1 : 0.55) : GenesyxColor.muted)
                        .frame(width: 10, height: max(8, 42 * fill))
                        .frame(height: 44, alignment: .bottom)
                    Text(row.minutes > 0 ? SleepInsightLogic.durationLabel(row.minutes) : "—")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(row.minutes > 0 ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(row.dayLabel(today: today))
                        .font(.system(size: 9))
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    .padding(16)
    .background(GenesyxColor.card)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
}

private struct SymptomsDetailView: View {
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @Environment(\.dismiss) private var dismiss

    private let today = CalendarDate.today()

    var body: some View {
        let week = TrackSignalSummary.trailingSeven(today: today).map { dailyLog.log(on: $0).symptoms.count }
        let todaySymptoms = dailyLog.log(on: today).symptoms.sorted()
        let insights = SymptomPatternLogic.compute(logs: dailyLog.logByDate, today: today)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    todayCard(
                        eyebrow: "Today",
                        title: todaySymptoms.isEmpty ? TrackSignalSummary.emptyValue : todaySymptoms.joined(separator: ", "),
                        subtitle: "Symptoms from today's log",
                        tint: GenesyxColor.electricPink)
                    detailHistoryCard(
                        title: "Last 7 days",
                        values: week,
                        valueLabel: { $0 > 0 ? "\($0)" : "—" },
                        fill: { min(Double($0) / 4.0, 1) },
                        tint: GenesyxColor.electricPink)
                    insightCard(insights.insight)
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct NutritionDetailView: View {
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @Environment(\.dismiss) private var dismiss

    private let today = CalendarDate.today()

    var body: some View {
        let week = TrackSignalSummary.currentWeekDates(today: today).map { dailyLog.log(on: $0).supplements.count }
        let todaySupplements = dailyLog.log(on: today).supplements.sorted()
        let insights = NutritionConsistencyLogic.compute(dailyCounts: week)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    todayCard(
                        eyebrow: "Today",
                        title: todaySupplements.isEmpty ? TrackSignalSummary.emptyValue : todaySupplements.joined(separator: ", "),
                        subtitle: "Supplements from today's log",
                        tint: GenesyxColor.primary)
                    detailHistoryCard(
                        title: "This week",
                        values: week,
                        valueLabel: { $0 > 0 ? "\($0)/\(NutritionConsistencyLogic.planSize)" : "—" },
                        fill: { min(Double($0) / Double(NutritionConsistencyLogic.planSize), 1) },
                        tint: GenesyxColor.primary)
                    insightCard(insights.insight)
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private func todayCard(eyebrow: String, title: String, subtitle: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Eyebrow(eyebrow, color: tint)
        Text(title)
            .font(.gxCardHeading)
            .foregroundStyle(title == TrackSignalSummary.emptyValue ? GenesyxColor.mutedForeground : GenesyxColor.foreground)
            .fixedSize(horizontal: false, vertical: true)
        Text(subtitle)
            .font(.gxBodySmall)
            .foregroundStyle(GenesyxColor.mutedForeground)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(GenesyxColor.card)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
}

private func detailHistoryCard(
    title: String,
    values: [Int],
    valueLabel: @escaping (Int) -> String,
    fill: @escaping (Int) -> Double,
    tint: Color
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title.uppercased())
            .font(.gxEyebrow)
            .tracking(1.4)
            .foregroundStyle(GenesyxColor.mutedForeground)
        HStack(spacing: 8) {
            ForEach(Array(values.prefix(7).enumerated()), id: \.offset) { _, value in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(value > 0 ? tint.opacity(fill(value) >= 1 ? 1 : 0.45) : GenesyxColor.muted)
                        .frame(width: 10, height: max(8, 42 * fill(value)))
                        .frame(height: 44, alignment: .bottom)
                    Text(valueLabel(value))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(value > 0 ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    .padding(16)
    .background(GenesyxColor.card)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
}

private func insightCard(_ text: String) -> some View {
    Text(text)
        .font(.gxBodySmall)
        .foregroundStyle(GenesyxColor.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
}

/// Identifiable wrapper so a tapped day can drive a `.sheet(item:)`.
struct DayInfo: Identifiable {
    let date: CalendarDate
    let info: CyclePhaseInfo
    var id: Int { date.dayNumber }
}

private struct DayDetailSheet: View {
    let day: DayInfo
    let today: CalendarDate
    let log: DailyLog
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let phase = day.info.phase
        let isFuture = day.date > today
        let isFertile = day.info.fertileWindow.contains(day.info.dayOfCycle)
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Day \(day.info.dayOfCycle) · \(CycleContent.phaseLabel[phase]!)", color: GenesyxColor.primary)
            Text(detail(isFuture: isFuture, isFertile: isFertile, phase: phase))
                .font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
            Spacer()
            GxPrimaryButton(title: "Close") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GenesyxColor.background)
        .presentationDetents([.height(220)])
    }

    private func detail(isFuture: Bool, isFertile: Bool, phase: Phase) -> String {
        if isFuture && phase == .ovulatory { return "Predicted: ovulation day — peak fertility." }
        if isFuture && isFertile { return "Predicted: fertile window." }
        if isFuture { return "Predicted: \(CycleContent.phaseLabel[phase]!.lowercased())." }
        if let summary = loggedSummary { return summary }
        return day.date == today ? "Nothing logged yet today." : "No log for this day."
    }

    /// A real summary of what she logged on this day, or nil if the day is empty.
    private var loggedSummary: String? {
        var parts: [String] = []
        if log.waterMl > 0 { parts.append(String(format: "%.1f L water", Double(log.waterMl) / 1000)) }
        if let mood = log.mood { parts.append("mood \(mood.label.lowercased())") }
        if let energy = log.energy { parts.append("\(energy.rawValue) energy") }
        if !log.symptoms.isEmpty { parts.append("\(log.symptoms.count) symptom\(log.symptoms.count == 1 ? "" : "s")") }
        if !log.supplements.isEmpty { parts.append("\(log.supplements.count) supplement\(log.supplements.count == 1 ? "" : "s")") }
        if let m = log.sleepMinutes, m > 0 { parts.append(String(format: "%.1f h sleep", Double(m) / 60)) }
        guard !parts.isEmpty else { return nil }
        return "Logged: " + parts.joined(separator: ", ") + "."
    }
}
