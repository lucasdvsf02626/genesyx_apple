import SwiftUI
import GenesyxCore

/// Daily Log — mood, energy, symptoms, sleep, water, supplements, notes.
/// Ported from the Android `LogScreen`; presented as a sheet. Writes to `DailyLogRepository`.
struct LogView: View {

    @EnvironmentObject private var dailyLog: DailyLogRepository
    @Environment(\.dismiss) private var dismiss

    private let date = CalendarDate.today()
    private static let defaultSymptoms = ["Headache", "Fatigue", "Cramps", "Nausea", "Bloating", "Acne", "Backache", "Tender breasts"]
    static let supplements = ["Folic acid", "Vitamin D", "Iron", "Omega-3"]

    @State private var loaded = false
    @State private var mood: Mood?
    @State private var energy: EnergyLevel?
    @State private var symptoms: Set<String> = []
    @State private var symptomOrder: [String] = []
    @State private var notes = ""
    @State private var sleepMinutes: Int?
    @State private var waterMl = 0
    @State private var selectedSupplements: Set<String> = []

    @State private var showAddSymptom = false
    @State private var customSymptom = ""
    @State private var sleepOpen = false
    @State private var waterOpen = false
    @State private var suppOpen = false

    private var allSymptoms: [String] {
        var seen = Set<String>()
        return (Self.defaultSymptoms + symptomOrder).filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    moodSection
                    energySection
                    symptomsSection
                    miniCards
                    notesSection
                    Spacer().frame(height: 20)
                    GxPrimaryButton(title: "Save log", action: save)
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Log Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(GenesyxColor.mutedForeground)
                }
            }
        }
        .onAppear(perform: populate)
        .sheet(isPresented: $sleepOpen) {
            SleepSheet(initialMinutes: sleepMinutes) { sleepMinutes = $0 }.presentationDetents([.height(260)])
        }
        .sheet(isPresented: $waterOpen) {
            WaterSheet(initialMl: waterMl) { waterMl = $0 }.presentationDetents([.height(220)])
        }
        .sheet(isPresented: $suppOpen) {
            SupplementsSheet(selected: $selectedSupplements).presentationDetents([.medium])
        }
    }

    private func populate() {
        guard !loaded else { return }
        let log = dailyLog.log(on: date)
        mood = log.mood
        energy = log.energy
        symptoms = log.symptoms
        symptomOrder = Array(log.symptoms)
        notes = log.notes ?? ""
        sleepMinutes = log.sleepMinutes
        waterMl = log.waterMl
        selectedSupplements = log.supplements
        loaded = true
    }

    private func save() {
        dailyLog.upsert(
            DailyLog(
                mood: mood, energy: energy, symptoms: symptoms,
                sleepMinutes: sleepMinutes, supplements: selectedSupplements,
                notes: notes.isEmpty ? nil : notes, waterMl: waterMl
            ),
            on: date
        )
        dismiss()
    }

    // MARK: Sections

    private func sectionLabel(_ title: String) -> some View {
        Eyebrow(title, color: GenesyxColor.mutedForeground)
            .padding(.leading, 4).padding(.top, 16).padding(.bottom, 8)
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Mood")
            HStack(spacing: 8) {
                ForEach(Mood.allCases, id: \.self) { m in
                    let sel = mood == m
                    VStack(spacing: 4) {
                        Image(systemName: Self.moodIcon(m))
                            .font(.system(size: 20))
                            .foregroundStyle(sel ? GenesyxColor.primary : GenesyxColor.foreground.opacity(0.7))
                        Text(m.label).font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(sel ? GenesyxColor.primary : GenesyxColor.foreground.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(sel ? GenesyxColor.primary.opacity(0.08) : GenesyxColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(sel ? GenesyxColor.primary : GenesyxColor.border, lineWidth: 1))
                    .onTapGesture { mood = m }
                }
            }
        }
    }

    private static func moodIcon(_ m: Mood) -> String {
        switch m {
        case .great: return "heart.fill"
        case .good: return "face.smiling"
        case .okay: return "face.dashed"
        case .low: return "cloud.rain.fill"
        }
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Energy")
            HStack(spacing: 6) {
                ForEach(EnergyLevel.allCases, id: \.self) { e in
                    let sel = energy == e
                    Text(e.rawValue.capitalized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(sel ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(sel ? GenesyxColor.card : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { energy = e }
                }
            }
            .padding(4)
            .background(GenesyxColor.muted)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Symptoms")
            FlowLayout(spacing: 8) {
                ForEach(allSymptoms, id: \.self) { s in
                    let sel = symptoms.contains(s)
                    HStack(spacing: 4) {
                        if sel { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                        Text(s).font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(sel ? .white : GenesyxColor.foreground.opacity(0.8))
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(sel ? GenesyxColor.primary : GenesyxColor.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(sel ? .clear : GenesyxColor.border, lineWidth: 1))
                    .onTapGesture { if sel { symptoms.remove(s) } else { symptoms.insert(s) } }
                }
                addSymptomChip
            }
        }
    }

    @ViewBuilder
    private var addSymptomChip: some View {
        if showAddSymptom {
            HStack(spacing: 4) {
                TextField("Add symptom", text: $customSymptom)
                    .font(.system(size: 13)).frame(width: 110)
                Button("Add") {
                    let t = customSymptom.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { symptomOrder.append(t); symptoms.insert(t) }
                    customSymptom = ""; showAddSymptom = false
                }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(GenesyxColor.primary)
            }
            .padding(.horizontal, 14).frame(height: 36)
            .overlay(Capsule().strokeBorder(GenesyxColor.border, lineWidth: 1))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 12))
                Text("Add").font(.system(size: 13))
            }
            .foregroundStyle(GenesyxColor.mutedForeground)
            .padding(.horizontal, 14).frame(height: 36)
            .overlay(Capsule().strokeBorder(GenesyxColor.border, lineWidth: 1))
            .onTapGesture { showAddSymptom = true }
        }
    }

    private var miniCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                miniCard("bed.double.fill", "Sleep", sleepValue, GenesyxColor.primary) { sleepOpen = true }
                miniCard("drop.fill", "Water", waterMl > 0 ? String(format: "%.1fL", Double(waterMl) / 1000) : "—", GenesyxColor.electricBlue) { waterOpen = true }
            }
            HStack(spacing: 12) {
                miniCard("pills.fill", "Supplements", "\(selectedSupplements.count) of \(Self.supplements.count)", GenesyxColor.primary) { suppOpen = true }
                miniCard("fork.knife", "Nutrition", "On track", GenesyxColor.electricPink) {}
            }
        }
        .padding(.top, 16)
    }

    private var sleepValue: String {
        guard let m = sleepMinutes else { return "—" }
        return "\(m / 60)h \(m % 60)m"
    }

    private func miniCard(_ icon: String, _ label: String, _ value: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint)
                    .frame(width: 36, height: 36).background(tint.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                Eyebrow(label, color: GenesyxColor.mutedForeground)
                Text(value).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Notes")
            TextField("A short note for future you…", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(GenesyxColor.border, lineWidth: 1))
                .onChange(of: notes) { if $0.count > 2000 { notes = String($0.prefix(2000)) } }
        }
    }
}

// MARK: - Sub-sheets

private struct SleepSheet: View {
    let initialMinutes: Int?
    let onDone: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int
    @State private var minutes: Int

    init(initialMinutes: Int?, onDone: @escaping (Int) -> Void) {
        self.initialMinutes = initialMinutes
        self.onDone = onDone
        _hours = State(initialValue: (initialMinutes ?? 420) / 60)
        _minutes = State(initialValue: (initialMinutes ?? 420) % 60)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) { ForEach(0...12, id: \.self) { Text("\($0)h") } }.pickerStyle(.wheel)
                Picker("Minutes", selection: $minutes) { ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0)m") } }.pickerStyle(.wheel)
            }
            .padding()
            .navigationTitle("Sleep").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onDone(hours * 60 + minutes); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct WaterSheet: View {
    let initialMl: Int
    let onDone: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input: String

    init(initialMl: Int, onDone: @escaping (Int) -> Void) {
        self.initialMl = initialMl
        self.onDone = onDone
        _input = State(initialValue: String(initialMl))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("0", text: $input)
                    .keyboardType(.numberPad).multilineTextAlignment(.center)
                    .font(.gxPhValue)
                    .onChange(of: input) { input = String($0.filter(\.isNumber).prefix(5)) }
                Text("millilitres").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding()
            .navigationTitle("Water").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone(min(max(Int(input) ?? 0, 0), 10_000)); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct SupplementsSheet: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(LogView.supplements, id: \.self) { s in
                        let checked = selected.contains(s)
                        HStack {
                            Text(s).font(.gxBody.weight(.medium)).foregroundStyle(GenesyxColor.foreground)
                            Spacer()
                            if checked { Image(systemName: "checkmark").foregroundStyle(GenesyxColor.primary) }
                        }
                        .padding(14)
                        .background(checked ? GenesyxColor.primary.opacity(0.08) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(checked ? GenesyxColor.primary : GenesyxColor.border, lineWidth: 1))
                        .onTapGesture { if checked { selected.remove(s) } else { selected.insert(s) } }
                    }
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle("Supplements").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
