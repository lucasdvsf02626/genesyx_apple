import SwiftUI
import GenesyxCore

/// "Your cycle" editor — last period date + cycle/period length steppers.
/// Mirrors the Android `CycleSettingsDialog`; validation matches the data layer
/// (cycle length 21–35, period length 1–10).
struct CycleSettingsSheet: View {

    let current: CycleSettings?
    let onSave: (CycleSettings) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lastPeriod: Date
    @State private var cycleLength: Int
    @State private var periodLength: Int

    init(current: CycleSettings?, onSave: @escaping (CycleSettings) -> Void) {
        self.current = current
        self.onSave = onSave
        _lastPeriod = State(initialValue: current?.lastPeriodDate.toDate() ?? Date())
        _cycleLength = State(initialValue: current?.cycleLength ?? CycleEngine.defaultCycleLength)
        _periodLength = State(initialValue: current?.periodLength ?? CycleEngine.defaultPeriodLength)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("We use this to predict your phases and fertile window.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("First day of last period", color: GenesyxColor.mutedForeground)
                        DatePicker("", selection: $lastPeriod, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(GenesyxColor.primary)
                    }

                    stepper(label: "Cycle length", value: $cycleLength, range: CycleEngine.cycleLengthRange)
                    stepper(label: "Period length", value: $periodLength, range: CycleEngine.periodLengthRange)

                    Spacer(minLength: 8)
                    GxPrimaryButton(title: "Save") {
                        onSave(CycleSettings(
                            lastPeriodDate: CalendarDate(date: lastPeriod),
                            cycleLength: cycleLength,
                            periodLength: periodLength
                        ))
                        dismiss()
                    }
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
