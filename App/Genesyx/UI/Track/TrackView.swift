import SwiftUI
import GenesyxCore

/// Track — month calendar with phase colors + current-phase card + cycle settings editor.
/// Ported from the Android `TrackScreen`. (The pH tracker section is translated separately.)
struct TrackView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository

    @State private var monthAnchor = YearMonth.current
    @State private var showCycleSheet = false
    @State private var selectedDay: DayInfo?
    @State private var showLog = false

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
                    PhTrackerSection()
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
        .sheet(isPresented: $showLog) { LogView() }
        .sheet(item: $selectedDay) { day in DayDetailSheet(day: day, today: today, log: dailyLog.log(on: day.date)) }
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
