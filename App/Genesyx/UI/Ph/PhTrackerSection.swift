import SwiftUI
import Charts
import GenesyxCore

/// Self-contained urine-pH card + log sheet, embedded on Track and Nutrition.
/// Ported from the Android `PhTrackerSection` / `PhTrackerCard` / `PhLogDialog`.
struct PhTrackerSection: View {
    @EnvironmentObject private var ph: PhRepository
    @State private var showSheet = false
    @State private var editing: PhReading?

    var body: some View {
        PhTrackerCard(readings: ph.readings) { editing = nil; showSheet = true }
            .sheet(isPresented: $showSheet) {
                PhLogSheet(
                    existing: editing,
                    onSave: { reading in
                        if editing == nil { ph.create(reading) } else { ph.update(reading) }
                        showSheet = false
                    },
                    onDelete: { id in ph.delete(id: id); showSheet = false }
                )
            }
    }
}

private enum PhRange: String, CaseIterable, Identifiable {
    case week = "7d", month = "30d", quarter = "90d", all = "All"
    var id: String { rawValue }
    var days: Double? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

private struct PhTrackerCard: View {
    let readings: [PhReading]
    let onLog: () -> Void
    @State private var range: PhRange = .month

    private var filtered: [PhReading] {
        guard let days = range.days else { return readings }
        let cutoff = Date().addingTimeInterval(-days * 86_400)
        return readings.filter { $0.recordedAt > cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Track your pH", color: GenesyxColor.primary)
                    Text("Urine Tracker").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                }
                Spacer()
                Button(action: onLog) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                        Text("Log pH").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(GenesyxColor.primary).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let latest = readings.last {
                latestPanel(latest)
                rangeSelector
                if filtered.count >= 2 {
                    PhChart(readings: filtered).frame(height: 180)
                } else {
                    chartEmpty("Not enough readings in this range")
                }
            } else {
                emptyState
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func latestPanel(_ latest: PhReading) -> some View {
        let status = PhStatus.classify(latest.phValue)
        let color = Theme.color(for: status)
        return HStack(spacing: 14) {
            Image(systemName: "drop.fill").foregroundStyle(color)
                .frame(width: 48, height: 48).background(color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("Latest reading", color: GenesyxColor.mutedForeground)
                Text(String(format: "%.1f", latest.phValue)).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(GenesyxColor.foreground)
                Text(latest.recordedAt.formatted(.dateTime.day().month().hour().minute()))
                    .font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            Text(status.label.uppercased()).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(color.opacity(0.18)).clipShape(Capsule())
        }
        .padding(16)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(PhRange.allCases) { r in
                let active = r == range
                Text(r.rawValue).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(active ? GenesyxColor.card : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { range = r }
            }
        }
        .padding(4).background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func chartEmpty(_ message: String) -> some View {
        Text(message).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity).frame(height: 180)
            .background(GenesyxColor.muted.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No readings yet").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            Text("Log your first pH to start your chart.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            GxPrimaryButton(title: "Log pH", leadingSystemImage: "plus", action: onLog).padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

/// pH line chart. The three status bands (acidic <6, optimal 6–7.5, alkaline >7.5) fall into
/// exactly equal thirds of the 4.5–9.0 domain, so the background is three equal bands.
private struct PhChart: View {
    let readings: [PhReading]

    var body: some View {
        Chart {
            ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                LineMark(x: .value("i", index), y: .value("pH", reading.phValue))
                    .foregroundStyle(GenesyxColor.primary)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("i", index), y: .value("pH", reading.phValue))
                    .foregroundStyle(GenesyxColor.primary)
                    .symbolSize(40)
            }
        }
        .chartYScale(domain: PhStatus.min...PhStatus.max)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [PhStatus.min, 6.0, 7.5, PhStatus.max]) { value in
                AxisValueLabel { if let v = value.as(Double.self) { Text(String(format: "%.1f", v)).font(.system(size: 9)) } }
                AxisGridLine()
            }
        }
        .chartBackground { _ in
            VStack(spacing: 0) {
                Theme.color(for: .alkaline).opacity(0.06)
                Theme.color(for: .optimal).opacity(0.08)
                Theme.color(for: .acidic).opacity(0.06)
            }
        }
    }
}

/// Log / edit a urine-pH reading: value tile coloured by status, slider 4.5–9.0 step 0.1 with
/// ± buttons, when picker, notes, Save (+ Delete when editing).
private struct PhLogSheet: View {
    let existing: PhReading?
    let onSave: (PhReading) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double
    @State private var recordedAt: Date
    @State private var notes: String

    init(existing: PhReading?, onSave: @escaping (PhReading) -> Void, onDelete: @escaping (String) -> Void) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _value = State(initialValue: existing?.phValue ?? 6.5)
        _recordedAt = State(initialValue: existing?.recordedAt ?? Date())
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private func clampRound(_ v: Double) -> Double {
        min(max((v * 10).rounded() / 10, PhStatus.min), PhStatus.max)
    }

    var body: some View {
        let status = PhStatus.classify(value)
        let color = Theme.color(for: status)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Track your urine pH from 4.5 to 9.0.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)

                    VStack(spacing: 6) {
                        Text(String(format: "%.1f", value)).font(.system(size: 44, weight: .semibold)).foregroundStyle(color)
                        Text(status.label.uppercased()).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 3)
                            .background(color.opacity(0.18)).clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 8) {
                        roundButton("minus") { value = clampRound(value - PhStatus.step) }
                        Slider(value: $value, in: PhStatus.min...PhStatus.max, step: PhStatus.step).tint(color)
                        roundButton("plus") { value = clampRound(value + PhStatus.step) }
                    }

                    Eyebrow("When", color: GenesyxColor.mutedForeground)
                    DatePicker("", selection: $recordedAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().datePickerStyle(.compact)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4).padding(12)
                        .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
                        .onChange(of: notes) { if $0.count > 500 { notes = String($0.prefix(500)) } }
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle(existing == nil ? "Log pH reading" : "Edit pH reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(PhReading(
                            id: existing?.id ?? UUID().uuidString,
                            phValue: value, recordedAt: recordedAt,
                            notes: notes.isEmpty ? nil : notes
                        ))
                    }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    if let existing {
                        Button("Delete", role: .destructive) { onDelete(existing.id) }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GenesyxColor.foreground)
                .frame(width: 44, height: 44).background(GenesyxColor.muted).clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
