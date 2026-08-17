import SwiftUI
import GenesyxCore

/// Daily Log — mood, energy, symptoms, sleep, water, supplements, notes.
/// Ported from the Android `LogScreen`; presented as a sheet. Writes to `DailyLogRepository`.
struct LogView: View {

    @EnvironmentObject private var dailyLog: DailyLogRepository
    @Environment(\.dismiss) private var dismiss

    /// The day being logged. Defaults to today, but the calendar passes a past date so a day she
    /// missed — or got wrong — can still be filled in. Never a future date: the callers gate that,
    /// because there is nothing to record about a day that has not happened.
    private let date: CalendarDate

    init(date: CalendarDate = .today()) {
        self.date = date
    }

    private static let defaultSymptoms = ["Headache", "Fatigue", "Cramps", "Nausea", "Bloating", "Acne", "Backache", "Tender breasts"]
    /// Derived from the plan the Nutrition tab shows her, not typed out again — see
    /// `NutritionContent.supplementLogOptions` for what maintaining two lists cost.
    static let supplements = NutritionContent.supplementLogOptions

    @State private var loaded = false
    @State private var mood: Mood?
    @State private var energy: EnergyLevel?
    @State private var symptoms: Set<String> = []
    @State private var symptomOrder: [String] = []
    @State private var notes = ""
    @State private var sleepMinutes: Int?
    @State private var waterMl = 0
    @State private var selectedSupplements: Set<String> = []
    @State private var sexualActivity = false
    @State private var foodGroups: Set<String> = []

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
                    intimacySection
                    foodGroupsSection
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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(GenesyxColor.mutedForeground)
                }
            }
            // On the hierarchy, not on either field: the note and "Add symptom" both wrap to a second
            // line, where Return types a newline instead of dismissing. One toolbar covers both, and
            // a second one added lower down would render a second Done beside this one.
            .gxKeyboardDoneToolbar()
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

    /// Naming the day matters once the sheet can open on more than one: without it a back-filled
    /// entry looks identical to today's, and she has no way to tell which she is about to overwrite.
    private var navigationTitle: String {
        guard date != CalendarDate.today() else { return "Log Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date.toDate())
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
        sexualActivity = log.sexualActivity
        foodGroups = log.foodGroups
        loaded = true
    }

    /// Overwrites the fields this sheet edits and leaves the rest of the day alone.
    ///
    /// It used to build a fresh `DailyLog` from `@State`, which silently reset every field the
    /// sheet does not show. That was harmless while the sheet showed all of them; it stopped being
    /// harmless the moment food groups became loggable from Nutrition, because saving a note here
    /// would have wiped what she ticked off there — a data loss with no error and no undo.
    ///
    /// The sheet now edits food groups too, so it writes them rather than carrying them through: an
    /// editor that cannot un-tick is not an editor. That is safe because `populate()` snapshots the
    /// stored day on appear, so anything logged from Nutrition is already selected here before she
    /// can save over it. The read-modify-write stays regardless — it costs nothing and it is the
    /// only thing standing between the next field logged from somewhere else and the same bug.
    private func save() {
        var entry = dailyLog.log(on: date)
        entry.mood = mood
        entry.energy = energy
        entry.symptoms = symptoms
        entry.sleepMinutes = sleepMinutes
        entry.supplements = selectedSupplements
        entry.notes = notes.isEmpty ? nil : notes
        entry.waterMl = waterMl
        entry.sexualActivity = sexualActivity
        entry.foodGroups = foodGroups
        dailyLog.upsert(entry, on: date)
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

    /// The most private thing she records, so the screen says out loud what becomes of it rather
    /// than leaving her to guess. The claim is literal: `daily_logs` is owner-only under RLS.
    ///
    /// The copy used to add "a linked partner sees your name — never your logs". Partner linking
    /// is excluded from the 1.2.0 public release, so that sentence now describes a feature she
    /// cannot reach and would only prompt her to hunt for it. Restore it alongside
    /// `FeatureFlags.partnerInvites`.
    private var intimacySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Intimacy")
            Button {
                sexualActivity.toggle()
            } label: {
                HStack(spacing: 4) {
                    if sexualActivity { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                    Text("Sex").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(sexualActivity ? .white : GenesyxColor.foreground.opacity(0.8))
                .padding(.horizontal, 14).frame(height: 36)
                .background(sexualActivity ? GenesyxColor.primary : GenesyxColor.card)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(sexualActivity ? .clear : GenesyxColor.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("log.sexualActivity")
            .accessibilityLabel(sexualActivity ? "Sex, logged" : "Sex, not logged")

            Text("Private to you. Only you can see your logs.")
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)
                .padding(.top, 8).padding(.leading, 4)
        }
    }

    /// The same six groups Nutrition offers, so a meal ticked here and a meal ticked there are the
    /// same record on the same day. A toggle rather than the recipe card's additive `logFoodGroups`:
    /// this is the day's editor, and the whole reason it exists is that the Track day sheet could
    /// report "3 food groups" with nowhere to correct them.
    private var foodGroupsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Food groups")
            FlowLayout(spacing: 8) {
                ForEach(FoodGroup.allCases) { group in
                    let sel = foodGroups.contains(group.rawValue)
                    Button {
                        if sel { foodGroups.remove(group.rawValue) } else { foodGroups.insert(group.rawValue) }
                    } label: {
                        HStack(spacing: 4) {
                            if sel { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                            Text(group.label).font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(sel ? .white : GenesyxColor.foreground.opacity(0.8))
                        .padding(.horizontal, 14).frame(height: 36)
                        .background(sel ? GenesyxColor.primary : GenesyxColor.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(sel ? .clear : GenesyxColor.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("log.foodGroup.\(group.rawValue)")
                    .accessibilityLabel("\(group.label), \(sel ? "logged" : "not logged")")
                }
            }
        }
    }

    private var miniCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                miniCard("bed.double.fill", "Sleep", sleepValue, GenesyxColor.primary) { sleepOpen = true }
                miniCard("drop.fill", "Water", String(format: "%.1fL", Double(waterMl) / 1000), GenesyxColor.electricBlue) { waterOpen = true }
                    .accessibilityIdentifier("log.waterCard")
            }
            HStack(spacing: 12) {
                // A plain count, not "n of 4": the sheet also offers the supplements she added
                // herself, and those are hers rather than part of the four-item plan.
                miniCard("pills.fill", "Supplements", "\(selectedSupplements.count) logged", GenesyxColor.primary) { suppOpen = true }
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
                .accessibilityIdentifier("log.notesField")
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

    /// Sleep caps at 12h, so at 12h only 0m is selectable — the pick always matches what is saved.
    private var minuteOptions: [Int] {
        hours >= 12 ? [0] : Array(stride(from: 0, through: 55, by: 5))
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) { ForEach(0...12, id: \.self) { Text("\($0)h") } }.pickerStyle(.wheel)
                Picker("Minutes", selection: $minutes) { ForEach(minuteOptions, id: \.self) { Text("\($0)m") } }.pickerStyle(.wheel)
            }
            .padding()
            .onChange(of: hours) { if $0 >= 12 { minutes = 0 } }
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
                    .gxKeyboardDoneToolbar()
                    .accessibilityIdentifier("log.waterMlField")
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
    @EnvironmentObject private var supplements: SupplementsRepository
    @Environment(\.dismiss) private var dismiss

    /// The plan's four, then the ones she added herself, then anything already recorded for this
    /// day that is neither.
    ///
    /// Her own supplements belong here because "Review Plan" already lets her add one and set a
    /// reminder for it — so the app would wake her at 8am for a Magnesium it then gave her nowhere
    /// to tick. The trailing group covers a supplement logged under an older list, which would
    /// otherwise sit in her day while being invisible and impossible to untick.
    private var options: [String] {
        var seen = Set<String>()
        let known = (LogView.supplements + supplements.supplements.map(\.name))
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return known + selected.subtracting(known).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { s in
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
