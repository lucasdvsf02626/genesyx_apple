import SwiftUI
import GenesyxCore

/// "Your cycle" editor — last period date + cycle/period length steppers.
/// Mirrors the Android `CycleSettingsDialog`; validation matches the data layer
/// (cycle length 21–35, period length 1–10).
struct CycleSettingsSheet: View {

    let current: CycleSettings?
    /// Returns false when the write was refused — see `CycleRepository.upsert`. The sheet stays
    /// open on a false rather than dismissing over a save that never happened.
    let onSave: (CycleSettings) -> Bool

    @Environment(\.dismiss) private var dismiss
    /// Her period dates are health data, so the Article 9 gate covers them like everything else.
    @EnvironmentObject private var consent: ConsentRepository
    // nil until a date is actively chosen — a new user's date is NEVER fabricated (e.g. "today").
    @State private var lastPeriod: Date?
    // Whether the picker is on screen, which is NOT the same question as whether she has chosen.
    // Conflating the two is what put "today" in the field: the empty-state button assigned `Date()`
    // purely to give the picker something to bind to, and that assignment enabled Save.
    @State private var isPickingDate = false
    @State private var cycleLength: Int
    @State private var periodLength: Int

    init(current: CycleSettings?, onSave: @escaping (CycleSettings) -> Bool) {
        self.current = current
        self.onSave = onSave
        // Existing settings prefill; a new user starts empty (see CycleSetup.initialLastPeriod).
        _lastPeriod = State(initialValue: CycleSetup.initialLastPeriod(from: current)?.toDate())
        _cycleLength = State(initialValue: current?.cycleLength ?? CycleEngine.defaultCycleLength)
        _periodLength = State(initialValue: current?.periodLength ?? CycleEngine.defaultPeriodLength)
    }

    /// Non-optional bridge for the graphical picker, only used once `lastPeriod` is set.
    private var lastPeriodBinding: Binding<Date> {
        Binding(get: { lastPeriod ?? Date() }, set: { lastPeriod = $0 })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Disable-first: only renders once she has withdrawn, and it sits above the
                    // form rather than beside the button so she reads why before filling anything in.
                    ConsentWithdrawnBanner()
                    Text("We use this to predict your phases and fertile window.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("First day of last period", color: GenesyxColor.mutedForeground)
                        let showsPicker = CycleSetup.showsDatePicker(
                            lastPeriod: lastPeriod.map { CalendarDate(date: $0) }, isPicking: isPickingDate)
                        if !showsPicker {
                            Button { isPickingDate = true } label: {
                                Text("Choose a date")
                                    .font(.gxBody).foregroundStyle(GenesyxColor.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12).padding(.horizontal, 14)
                                    .background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            Text("Pick the first day of your most recent period — predictions start from it.")
                                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        } else {
                            DatePicker("", selection: lastPeriodBinding, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(GenesyxColor.primary)
                            // The picker has to be handed a non-optional date, so it opens on today
                            // whether or not she means today — and tapping the day it is already
                            // showing may not move the binding, which would leave Save disabled with
                            // nothing on screen explaining why. This is that day, said out loud.
                            if lastPeriod == nil {
                                Button { lastPeriod = Date() } label: {
                                    Text("My period started today")
                                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.primary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("cycle.lastPeriodIsToday")
                            }
                        }
                    }

                    stepper(label: "Cycle length", value: $cycleLength, range: CycleEngine.cycleLengthRange)
                    stepper(label: "Period length", value: $periodLength, range: CycleEngine.periodLengthRange)

                    Spacer(minLength: 8)
                    let canSave = CycleSetup.canSave(lastPeriod: lastPeriod.map { CalendarDate(date: $0) })
                        && consent.isActive
                    GxPrimaryButton(title: "Save") {
                        guard let lastPeriod else { return }   // Save is disabled until a date is chosen
                        // Defence in depth behind the disabled button: `dismiss()` used to run
                        // whether or not the write landed, so a refused save closed the sheet
                        // exactly as a successful one did and her dates were lost in silence.
                        guard onSave(CycleSettings(
                            lastPeriodDate: CalendarDate(date: lastPeriod),
                            cycleLength: cycleLength,
                            periodLength: periodLength
                        )) else { return }
                        dismiss()
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Your cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(GenesyxColor.mutedForeground)
                }
            }
        }
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                Text("\(value.wrappedValue) days").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            HStack(spacing: 8) {
                stepButton("minus") { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } }
                stepButton("plus") { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } }
            }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GenesyxColor.foreground)
                .frame(width: 36, height: 36)
                .background(GenesyxColor.muted)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
