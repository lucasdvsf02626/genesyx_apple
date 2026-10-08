import GenesyxCore
import SwiftUI

/// Adds a period start, sets or clears a period end, or corrects a start. The date picker holds
/// only dates the change can accept; a refusal that still gets through is said in a sentence and
/// the sheet stays open.
struct PeriodEditSheet: View {
    enum Mode: Equatable {
        case addStart
        case setEnd(start: CalendarDate, current: CalendarDate?)
        case correctStart(CalendarDate)
    }

    private let mode: Mode
    private let today: CalendarDate
    private let onDone: (String) -> Void
    /// One calendar, used in both directions between the picker's `Date` and a `CalendarDate`.
    private let calendar = Calendar.autoupdatingCurrent

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var periods: PeriodRepository
    @EnvironmentObject private var consent: ConsentRepository
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: CalendarDate?
    @State private var message: String?

    init(mode: Mode, today: CalendarDate, onDone: @escaping (String) -> Void) {
        self.mode = mode
        self.today = today
        self.onDone = onDone
    }

    var body: some View {
        let starts = periods.periods.map(\.startDate)
        let range = CycleHistoryPresentation.allowedDates(for: mode, today: today, existingStarts: starts)
        let date = min(max(chosen ?? CycleHistoryPresentation.defaultDate(for: mode, today: today, existingStarts: starts),
                           range.lowerBound), range.upperBound)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ConsentWithdrawnBanner()
                    DatePicker(CycleHistoryScreenCopy.dateLabel, selection: pickerBinding(date),
                               in: range.lowerBound.toDate(calendar: calendar)...range.upperBound.toDate(calendar: calendar),
                               displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, calendar)
                        .tint(GenesyxColor.primary)
                        .accessibilityIdentifier("kit.history.sheet.date")
                    if let note = note(for: date, starts: starts) {
                        KitNote(note).accessibilityIdentifier("kit.history.sheet.note")
                    }
                    if let message {
                        KitLine(message).accessibilityIdentifier("kit.history.sheet.message")
                    }
                    if case .setEnd(_, let current) = mode, current != nil {
                        GxGhostButton(title: CycleHistoryScreenCopy.clearEnd, action: clearEnd)
                            .accessibilityIdentifier("kit.history.sheet.clearEnd")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .background(GenesyxColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FertilityKitCopy.cancel) { dismiss() }
                        .accessibilityIdentifier("kit.history.sheet.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(FertilityKitCopy.save) { save(date) }
                        .disabled(!consent.isActive)
                        .accessibilityIdentifier("kit.history.sheet.save")
                }
            }
        }
        .kitContainer("kit.history.sheet")
    }

    private var title: String {
        switch mode {
        case .addStart: return CycleHistoryScreenCopy.addStart
        case .setEnd(_, let current): return current == nil ? CycleHistoryScreenCopy.setEnd : CycleHistoryScreenCopy.changeEnd
        case .correctStart: return CycleHistoryScreenCopy.correctStart
        }
    }

    private func pickerBinding(_ shown: CalendarDate) -> Binding<Date> {
        Binding(
            get: { shown.toDate(calendar: calendar) },
            set: { chosen = CalendarDate(date: $0, calendar: calendar); message = nil })
    }

    /// Said before saving: that the date will move a start, not add one, or how far a start can move.
    private func note(for date: CalendarDate, starts: [CalendarDate]) -> String? {
        switch mode {
        case .addStart:
            return CycleHistoryPresentation.correctionTarget(for: date, existingStarts: starts)
                .map { CycleHistoryScreenCopy.correctionNote(FertilityKitDates.dayMonth($0)) }
        case .correctStart:
            return CycleHistoryScreenCopy.correctRange(CycleHistoryRules.correctionWindowDays)
        case .setEnd:
            return nil
        }
    }

    private func save(_ date: CalendarDate) {
        switch mode {
        case .addStart, .correctStart:
            // nil is the consent refusal, which the banner already explains.
            guard let outcome = periods.recordStart(date, today: today) else { return }
            finish(CycleHistoryScreenCopy.sentence(for: outcome), done: CycleHistoryPresentation.isChange(outcome))
        case .setEnd(let start, _):
            guard let outcome = periods.setEnd(date, forStart: start, today: today) else { return }
            finish(CycleHistoryScreenCopy.sentence(for: outcome), done: outcome == .updated)
        }
    }

    private func clearEnd() {
        guard case .setEnd(let start, _) = mode,
              let outcome = periods.setEnd(nil, forStart: start, today: today) else { return }
        finish(outcome == .updated ? CycleHistoryScreenCopy.endCleared : CycleHistoryScreenCopy.sentence(for: outcome),
               done: outcome == .updated)
    }

    /// A change closes the sheet with its sentence; anything else says why nothing changed and
    /// stays open.
    private func finish(_ sentence: String, done: Bool) {
        if done { onDone(sentence) } else { message = sentence }
    }
}

extension PeriodEditSheet.Mode: Identifiable {
    /// A sheet shows one mode at a time; the start it is about is part of the identity.
    var id: String {
        switch self {
        case .addStart: return "addStart"
        case .setEnd(let start, _): return "setEnd.\(start.dayNumber)"
        case .correctStart(let start): return "correctStart.\(start.dayNumber)"
        }
    }
}

#if DEBUG
#Preview {
    PeriodEditSheet(mode: .addStart, today: FertilityKitClock.current(), onDone: { _ in }).withKitPreview()
}
#endif
