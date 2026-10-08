import GenesyxCore
import SwiftUI

/// What she chose. The date is worked out when she commits, never copied earlier.
enum ProgrammeStartChoice: Equatable {
    case today
    case later(CalendarDate)
}

/// The start date rules, as plain functions of the date the sheet was given.
enum ProgrammeStartPresentation {

    /// Tomorrow through today plus 60 days: the only guard against a past date.
    static func allowedDates(today: CalendarDate) -> ClosedRange<CalendarDate> {
        today.plusDays(1)...today.plusDays(60)
    }

    /// Today for today; a later date held inside the range; and today for a later date that has
    /// meanwhile become today or the past, so a sheet left open over midnight never stores
    /// yesterday.
    static func startDate(choice: ProgrammeStartChoice, today: CalendarDate) -> CalendarDate {
        switch choice {
        case .today:
            return today
        case .later(let date):
            guard date > today else { return today }
            let allowed = allowedDates(today: today)
            return min(max(date, allowed.lowerBound), allowed.upperBound)
        }
    }
}

/// Two steps in one sheet: choose the day, then confirm it. No system alert, so every control can
/// be reached.
struct ProgrammeStartSheet: View {
    private enum Step { case choosing, confirming }

    private let today: CalendarDate
    private let calendar = Calendar.autoupdatingCurrent

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var programme: ProgrammeRepository
    @EnvironmentObject private var consent: ConsentRepository

    @State private var step = Step.choosing
    @State private var choice = ProgrammeStartChoice.today
    @State private var showsPicker = false
    @State private var picked: CalendarDate
    @State private var message: String?
    @State private var alreadyStarted = false

    init(today: CalendarDate) {
        self.today = today
        _picked = State(initialValue: today.plusDays(1))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch step {
                    case .choosing: choose
                    case .confirming: confirm
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                .kitContainer("kit.start.sheet")
            }
            .background(GenesyxColor.background)
            .navigationTitle(FertilityKitCopy.programmeShortName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FertilityKitCopy.cancel) { dismiss() }.accessibilityIdentifier("kit.start.cancel")
                }
            }
        }
    }

    // MARK: Step 1

    private var choose: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(FertilityKitAccessCopy.startTitle).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            KitLine(FertilityKitAccessCopy.startBody, muted: true)
            KitLine(FertilityKitAccessCopy.finalNote, muted: true).accessibilityIdentifier("kit.start.finalNote")
            GxPrimaryButton(title: FertilityKitAccessCopy.startToday) { goToConfirm(.today) }
                .accessibilityIdentifier("kit.start.today")
            if showsPicker {
                DatePicker(FertilityKitAccessCopy.startDateLabel, selection: pickedDate,
                           in: pickerRange, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .environment(\.calendar, calendar)
                    .accessibilityIdentifier("kit.start.datePicker")
                GxPrimaryButton(title: FertilityKitAccessCopy.startOn(FertilityKitDates.dayMonth(laterDate))) {
                    goToConfirm(.later(picked))
                }
                .accessibilityIdentifier("kit.start.confirmLater")
            } else {
                GxGhostButton(title: FertilityKitAccessCopy.startLater) { showsPicker = true }
                    .accessibilityIdentifier("kit.start.later")
            }
        }
        .kitContainer("kit.start.choose")
    }

    /// What a later choice would store, so the button never names a date the commit would not use.
    private var laterDate: CalendarDate {
        ProgrammeStartPresentation.startDate(choice: .later(picked), today: today)
    }

    private var pickerRange: ClosedRange<Date> {
        let allowed = ProgrammeStartPresentation.allowedDates(today: today)
        return allowed.lowerBound.toDate(calendar: calendar)...allowed.upperBound.toDate(calendar: calendar)
    }

    private var pickedDate: Binding<Date> {
        Binding(get: { picked.toDate(calendar: calendar) },
                set: { picked = CalendarDate(date: $0, calendar: calendar) })
    }

    private func goToConfirm(_ chosen: ProgrammeStartChoice) {
        choice = chosen
        message = nil
        step = .confirming
    }

    // MARK: Step 2

    private var confirm: some View {
        let date = ProgrammeStartPresentation.startDate(choice: choice, today: today)
        let line = choice == .today
            ? FertilityKitAccessCopy.reviewToday
            : FertilityKitAccessCopy.reviewLater(FertilityKitDates.dayMonth(date))
        return VStack(alignment: .leading, spacing: 16) {
            Text(line).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("kit.start.reviewDate")
            KitLine(FertilityKitAccessCopy.finalNote, muted: true)
            ConsentWithdrawnBanner()
            if let message { KitLine(message).accessibilityIdentifier("kit.start.message") }
            if alreadyStarted {
                GxPrimaryButton(title: FertilityKitCopy.done) { dismiss() }
                    .accessibilityIdentifier("kit.start.done")
            } else {
                GxPrimaryButton(title: FertilityKitAccessCopy.commit, enabled: consent.isActive) { commit() }
                    .accessibilityIdentifier("kit.start.commit")
                GxGhostButton(title: FertilityKitCopy.back) { message = nil; step = .choosing }
                    .accessibilityIdentifier("kit.start.back")
            }
        }
        .kitContainer("kit.start.review")
    }

    private func commit() {
        switch programme.start(today: ProgrammeStartPresentation.startDate(choice: choice, today: today)) {
        case .started:
            dismiss()
        case .alreadyStarted(let started):
            message = FertilityKitAccessCopy.alreadyStarted(FertilityKitDates.dayMonth(started))
            alreadyStarted = true
        case .refusedNoAccess:
            message = FertilityKitAccessCopy.refusedNoAccess
        case .refusedNoConsent:
            message = FertilityKitAccessCopy.refusedNoConsent
        }
    }
}

#if DEBUG
#Preview {
    ProgrammeStartSheet(today: FertilityKitClock.current()).withKitPreview(access: true)
}
#endif
