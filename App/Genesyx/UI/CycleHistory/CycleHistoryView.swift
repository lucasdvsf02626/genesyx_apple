import GenesyxCore
import SwiftUI

/// The periods she has recorded, newest first, and the cycle each one opens. Facts only: dates,
/// counts of days, and a summary across cycles once enough have been recorded. Nothing is
/// predicted, and no length is judged.
struct CycleHistoryView: View {
    @Environment(\.fertilityKit) private var kit
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var periods: PeriodRepository

    @State private var sheet: PeriodEditSheet.Mode?
    @State private var deleting: CalendarDate?
    @State private var message: String?
    @State private var showsPredictionsNote = false

    init() {}

    var body: some View {
        let rows = CycleHistoryPresentation.rows(cycles: kit.cycles, refusedStarts: kit.refusedPeriodStarts)
        let summary = CycleHistoryPresentation.summary(kit)
        let consentActive = kit.planInput.consentActive
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ConsentWithdrawnBanner()
                if !rows.isEmpty { KitNote(CycleHistoryScreenCopy.intro) }
                GxPrimaryButton(title: CycleHistoryScreenCopy.addStart, enabled: consentActive) { sheet = .addStart }
                    .accessibilityIdentifier("kit.history.add")
                if let message {
                    KitLine(message).accessibilityIdentifier("kit.history.message")
                }
                if showsPredictionsNote {
                    KitNote(CycleHistoryScreenCopy.predictionsNote).accessibilityIdentifier("kit.history.predictionsNote")
                }
                if rows.isEmpty {
                    KitNote(CycleHistoryScreenCopy.emptyState, boxed: true).accessibilityIdentifier("kit.history.empty")
                }
                if !summary.isEmpty {
                    KitCard { KitLines(summary, identifier: "kit.history.summary") }
                }
                ForEach(rows, id: \.index) { row in rowView(row, rowCount: rows.count, consentActive: consentActive) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.history")
        }
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.cycleHistory)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { mode in
            PeriodEditSheet(mode: mode, today: kit.today) { sentence in
                message = sentence
                showsPredictionsNote = true
                sheet = nil
            }
            .withAppEnvironment(container)
        }
        // An alert, as on the pregnancy test history: a confirmation dialog is drawn as a popover
        // at the top of the screen, nowhere near the row it is about.
        .alert(CycleHistoryScreenCopy.deleteTitle, isPresented: deletingBinding, presenting: deleting) { start in
            Button(FertilityKitCopy.delete, role: .destructive) {
                if periods.delete(start: start) {
                    message = CycleHistoryScreenCopy.deleted
                    showsPredictionsNote = true
                }
            }
            Button(FertilityKitCopy.cancel, role: .cancel) {}
        } message: { start in
            Text(CycleHistoryPresentation.deleteMessage(
                isLatest: start == kit.cycles.last?.start, startCount: kit.cycles.count))
        }
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func rowView(_ row: CycleHistoryPresentation.Row, rowCount: Int, consentActive: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(row.lines.enumerated()), id: \.offset) { position, line in
                    Text(line).font(position == 0 ? .gxCardHeadingSmall : .gxBody)
                        .foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .kitRow("kit.history.cycle.\(row.index)", label: row.label)
            // Beside the row, never inside it: a menu inside a one-element row could not be reached.
            Menu {
                Button(row.periodEnd == nil ? CycleHistoryScreenCopy.setEnd : CycleHistoryScreenCopy.changeEnd) {
                    sheet = .setEnd(start: row.start, current: row.periodEnd)
                }
                .disabled(!consentActive)
                Button(CycleHistoryScreenCopy.correctStart) { sheet = .correctStart(row.start) }
                    .disabled(!consentActive)
                Button(CycleHistoryScreenCopy.deletePeriod, role: .destructive) { deleting = row.start }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 22))
                    .foregroundStyle(GenesyxColor.primary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(CycleHistoryScreenCopy.rowActions)
            .accessibilityIdentifier("kit.history.menu.\(row.index)")
        }
        .padding(.leading, 20).padding(.trailing, 8).padding(.vertical, 12)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// What the screen shows, as pure functions over plain values.
enum CycleHistoryPresentation {

    /// One cycle's row. `index` 0 is the newest, because an identifier never carries a date.
    struct Row: Equatable {
        let index: Int
        let start: CalendarDate
        /// The last day of the period she recorded, when she recorded one that counts.
        let periodEnd: CalendarDate?
        let lines: [String]

        var label: String { FertilityKitCopy.sentences(lines) }
    }

    /// Newest first. The open cycle shows where it started; a completed one shows its dates and
    /// length, whatever that length is, with no comment.
    static func rows(cycles: [DerivedCycle], refusedStarts: Set<CalendarDate>) -> [Row] {
        cycles.reversed().enumerated().map { index, cycle in
            var lines: [String]
            if let end = cycle.end {
                lines = [FertilityKitDates.range(cycle.start, end)]
                if let length = cycle.length { lines.append(CycleHistoryScreenCopy.length(length)) }
            } else {
                lines = [CycleHistoryScreenCopy.currentCycle,
                         CycleHistoryScreenCopy.started(FertilityKitDates.dayMonth(cycle.start))]
            }
            let periodEnd = cycle.periodDays.map { cycle.start.plusDays($0 - 1) }
            if let days = cycle.periodDays { lines.append(CycleHistoryScreenCopy.periodDays(days)) }
            // The seeded record is never presented as something she recorded.
            if !cycle.isRecorded { lines.append(CycleHistoryScreenCopy.fromSettings) }
            if refusedStarts.contains(cycle.start) { lines.append(CycleHistoryScreenCopy.notSaved) }
            return Row(index: index, start: cycle.start, periodEnd: periodEnd, lines: lines)
        }
    }

    /// The wording of the delete alert. Her latest start moves her predictions back to the one
    /// before it, but only when there is one: for her only record nothing is promised.
    static func deleteMessage(isLatest: Bool, startCount: Int) -> String {
        isLatest && startCount > 1 ? CycleHistoryScreenCopy.deleteLatestBody : CycleHistoryScreenCopy.deleteBody
    }

    /// The statements that hold across cycles, once enough have been recorded to say anything.
    static func summary(_ kit: FertilityKitContext) -> [String] {
        guard CycleHistory.canMakeCrossCycleStatement(kit.cycles) else { return [] }
        return FertilityPicturePatterns.statements(kit.pictureInput())
            .filter { $0.level == .crossCyclePattern }.map(\.text)
    }

    /// A save that changed something closes the sheet; one that did not says why and stays open.
    static func isChange(_ outcome: PeriodStartOutcome) -> Bool {
        switch outcome {
        case .append, .backFill, .correction: return true
        case .noChange, .refused: return false
        }
    }

    // MARK: The sheet

    /// What the date picker holds. Everything in it is a date the change accepts.
    static func allowedDates(for mode: PeriodEditSheet.Mode, today: CalendarDate,
                             existingStarts: [CalendarDate]) -> ClosedRange<CalendarDate> {
        let window = CycleHistoryRules.correctionWindowDays
        switch mode {
        case .addStart:
            return CycleHistoryRules.earliestDate...max(CycleHistoryRules.earliestDate, today)
        case .setEnd(let start, _):
            return start...max(start, min(today, start.plusDays(window - 1)))
        case .correctStart(let old):
            // The rule corrects the NEAREST start in the window, and the later one on a tie. So
            // where another start is close, some dates of the plain range would move that
            // other period instead: they are left out. What is left is one run around `old`.
            let starts = existingStarts + [old]
            func movesOld(_ date: CalendarDate) -> Bool {
                CycleHistoryRules.accepts(date, today: today) && nearestStart(to: date, in: starts) == old
            }
            var low = old
            while low.dayNumber > old.dayNumber - window, movesOld(low.minusDays(1)) { low = low.minusDays(1) }
            var high = old
            while high.dayNumber < old.dayNumber + window, movesOld(high.plusDays(1)) { high = high.plusDays(1) }
            return low...high
        }
    }

    /// Where the picker opens, inside `allowedDates`.
    static func defaultDate(for mode: PeriodEditSheet.Mode, today: CalendarDate,
                            existingStarts: [CalendarDate]) -> CalendarDate {
        let range = allowedDates(for: mode, today: today, existingStarts: existingStarts)
        let wanted: CalendarDate
        switch mode {
        case .addStart: wanted = today
        case .setEnd(let start, let current): wanted = current ?? min(today, start)
        case .correctStart(let old): wanted = old.minusDays(1)
        }
        return min(max(wanted, range.lowerBound), range.upperBound)
    }

    /// The start that saving `date` as a new period would move instead of adding one: the nearest
    /// start within the window, never one on that very date (that is already recorded).
    static func correctionTarget(for date: CalendarDate, existingStarts: [CalendarDate]) -> CalendarDate? {
        guard let nearest = nearestStart(to: date, in: existingStarts), nearest != date else { return nil }
        return nearest
    }

    /// `CycleHistoryRules.apply`'s own choice: the nearest start within the window, the later one on a tie.
    private static func nearestStart(to date: CalendarDate, in starts: [CalendarDate]) -> CalendarDate? {
        func distance(_ start: CalendarDate) -> Int { abs(CycleEngine.daysBetween(start, date)) }
        return starts.filter { distance($0) <= CycleHistoryRules.correctionWindowDays }
            .min { (distance($0), $1.dayNumber) < (distance($1), $0.dayNumber) }
    }
}

#if DEBUG
#Preview {
    CycleHistoryView().withKitPreview()
}
#endif
