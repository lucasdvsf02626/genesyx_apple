import SwiftUI
import Charts
import GenesyxCore

/// The pH tab. pH used to be a card buried under Nutrition's supplements; it is a top-level
/// destination now.
struct PhTabView: View {
    @EnvironmentObject private var router: TabRouter

    /// The explainer the tab signposts. Named rather than inlined so a test can assert it still
    /// resolves to a *published* article: Learn deep links go through `LearnLibrary.articles`,
    /// which hides anything dated in the future, so a slug can be spelled correctly and still land
    /// her on the "unavailable" screen. `guide-understanding-vaginal-ph` carries no `publishedAt`,
    /// unlike the weekly pieces on the same subject.
    static let learnArticleSlug = "guide-understanding-vaginal-ph"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ConsentWithdrawnBanner()
                    PhTrackerSection(
                        onOpenSupplements: { router.selection = 3 },
                        onOpenLearn: {
                            router.pendingLearnSlug = PhTabView.learnArticleSlug
                            router.selection = 5
                        })
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .gxPageBackground()
            .navigationTitle("Vaginal pH")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Self-contained vaginal-pH card + log sheet: the tracker, the chart, and the "product spine"
/// (the four educational sections). The pH tab's body, and the detail views pushed from Track and
/// Insights. Ported from the Android `PhTrackerSection` / `PhTrackerCard` / `PhLogDialog`.
struct PhTrackerSection: View {
    /// Optional navigation into the supplements area (only wired where a router is available).
    var onOpenSupplements: (() -> Void)? = nil
    /// Optional navigation into the pH explainer in Learn. Same contract as above: nil where no
    /// router exists, so previews and embedded uses simply do not show the link.
    var onOpenLearn: (() -> Void)? = nil

    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var consent: ConsentRepository
    /// One piece of state, presented with `.sheet(item:)`. The pair it replaced — a `showSheet`
    /// flag plus a separate `editing` reading — raced: SwiftUI evaluated the sheet body before the
    /// sibling update landed, so `existing` was still nil and every edit opened as a blank new
    /// reading. Tapping a reading appeared to work and silently filed a duplicate instead.
    @State private var sheet: PhSheetMode?

    var body: some View {
        PhTrackerCard(
            readings: ph.readings,
            onOpenSupplements: onOpenSupplements,
            onOpenLearn: onOpenLearn,
            // Disable-first. With consent withdrawn the repository refuses the write anyway, so
            // offering "Log pH" only invites her to fill in a reading that cannot be kept.
            //
            // The *edit* entry points stay open on purpose. Tapping a reading is also the only way
            // to reach "Delete this reading", and `PhRepository.delete` sits outside the gate
            // deliberately: erasing what she already recorded is Article 17 and has to stay
            // available after a withdrawal. So the sheet still opens; what it refuses is Save.
            isLoggingEnabled: consent.isActive,
            onLog: { sheet = .new },
            onEdit: { sheet = .edit($0) })
            .sheet(item: $sheet) { mode in
                PhLogSheet(
                    existing: mode.reading,
                    canSave: consent.isActive,
                    onSave: { reading in
                        // Defence in depth: `sheet = nil` ran unconditionally, so a refused write
                        // closed the sheet exactly as a saved one did. Hold the sheet open on a
                        // refusal — the banner on the tab behind it says why.
                        let saved = mode.reading == nil ? ph.create(reading) : ph.update(reading)
                        if saved { sheet = nil }
                    },
                    onDelete: { id in ph.delete(id: id); sheet = nil }
                )
            }
    }
}

/// What the log sheet is open on. `Identifiable` so `.sheet(item:)` hands the value to the body
/// rather than reading it back out of a sibling `@State`.
private enum PhSheetMode: Identifiable {
    case new
    case edit(PhReading)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let reading): return reading.id
        }
    }

    var reading: PhReading? {
        if case .edit(let reading) = self { return reading }
        return nil
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
    var onOpenSupplements: (() -> Void)? = nil
    var onOpenLearn: (() -> Void)? = nil
    /// False once she has withdrawn Article 9 consent. The chart and the history stay readable —
    /// withdrawal stops collection, it does not hide what is already hers — and tapping a reading
    /// still opens the sheet, because that is the route to deleting it. What goes away is the
    /// offer to record something new. Defaults true so previews and embedded uses are unaffected.
    var isLoggingEnabled: Bool = true
    let onLog: () -> Void
    let onEdit: (PhReading) -> Void
    @State private var range: PhRange = .month
    @State private var disclaimerExpanded = false
    @State private var historyExpanded = false

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
                    Text("Vaginal pH Tracker").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
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
                .disabled(!isLoggingEnabled)
                .opacity(isLoggingEnabled ? 1 : 0.4)
            }

            Text(PhCopy.cycleContextCaveat)
                .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phCaveat")
            Text(PhCopy.accuracyCaveat)
                .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phAccuracyCaveat")
            // Collapsed on the card so the small print stops crowding the tracker itself. The log
            // sheet keeps it pinned and always visible — that is the surface where she records a
            // reading, and there the disclaimer must never be a tap away.
            Button { withAnimation(.easeInOut(duration: 0.2)) { disclaimerExpanded.toggle() } } label: {
                HStack {
                    Text("Safety note").font(.caption2.weight(.medium)).foregroundStyle(GenesyxColor.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .rotationEffect(.degrees(disclaimerExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("phDisclaimerToggle")
            if disclaimerExpanded {
                Text(PhCopy.disclaimer)
                    .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("phDisclaimer")
            }

            if let latest = readings.last {
                Button { onEdit(latest) } label: { latestPanel(latest) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit or delete this reading")
                rangeSelector
                if filtered.count >= 2 {
                    PhChart(readings: filtered).frame(height: 180)
                } else {
                    chartEmpty("Not enough readings in this range")
                }
                history
            } else {
                emptyState
            }

            PhSpine(latest: readings.last, onOpenSupplements: onOpenSupplements, onOpenLearn: onOpenLearn)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func latestPanel(_ latest: PhReading) -> some View {
        let color = Theme.color(for: PhStatus.classify(latest.phValue))
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
            Text(PhStatus.classify(latest.phValue).label.uppercased())
                .font(.system(size: 11, weight: .semibold))
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
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(active ? GenesyxColor.card : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { range = r }
                    .accessibilityIdentifier("phRange.\(r.rawValue)")
                    // Which range is showing was said in colour and background alone, so VoiceOver
                    // read four bare labels with no way to tell the active one — and nothing
                    // outside the view could drive them either.
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4).background(GenesyxColor.muted).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// The full history, newest first — deliberately ignoring `range`, which reads as a chart
    /// control. A reading she entered wrongly months ago has to stay reachable without her first
    /// working out that the chart's "All" tab is also what unhides it in the list.
    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { historyExpanded.toggle() } } label: {
                HStack {
                    Text("Reading history (\(readings.count))")
                        .font(.caption2.weight(.medium)).foregroundStyle(GenesyxColor.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .rotationEffect(.degrees(historyExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("phHistoryToggle")

            if historyExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(readings.reversed().enumerated()), id: \.element.id) { index, reading in
                        Button { onEdit(reading) } label: { historyRow(reading) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("phHistoryRow\(index)")
                            .accessibilityHint("Edit or delete this reading")
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    private func historyRow(_ reading: PhReading) -> some View {
        let color = Theme.color(for: PhStatus.classify(reading.phValue))
        return HStack(spacing: 12) {
            Text(String(format: "%.1f", reading.phValue))
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                .frame(width: 46, height: 34)
                .background(color.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.recordedAt.formatted(.dateTime.day().month().hour().minute()))
                    .font(.system(size: 13)).foregroundStyle(GenesyxColor.foreground)
                if let notes = reading.notes, !notes.isEmpty {
                    Text(notes).font(.system(size: 11)).foregroundStyle(GenesyxColor.mutedForeground)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GenesyxColor.mutedForeground)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(GenesyxColor.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .disabled(!isLoggingEnabled)
                .opacity(isLoggingEnabled ? 1 : 0.4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

/// Vaginal pH line chart. Two-band background: healthy (green) up to 4.5, elevated (amber) above.
/// The visible domain is `PhStatus.chartDomain` rather than the full loggable range — see there for
/// why the full range made the chart unreadable.
private struct PhChart: View {
    let readings: [PhReading]

    private var domain: ClosedRange<Double> { PhStatus.chartDomain(for: readings.map(\.phValue)) }

    var body: some View {
        Chart {
            ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                // Defensive clamp so a stray out-of-range value stays on-chart.
                let y = PhStatus.clamped(reading.phValue)
                LineMark(x: .value("i", index), y: .value("pH", y))
                    .foregroundStyle(GenesyxColor.primary)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("i", index), y: .value("pH", y))
                    .foregroundStyle(GenesyxColor.primary)
                    .symbolSize(40)
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [domain.lowerBound, 4.5, domain.upperBound]) { value in
                AxisValueLabel { if let v = value.as(Double.self) { Text(String(format: "%.1f", v)).font(.system(size: 9)) } }
                AxisGridLine()
            }
        }
        .chartBackground { _ in
            GeometryReader { geo in
                // Two bands, proportional to the visible domain: elevated (>4.5) on top, healthy
                // beneath it down to the floor. The floor is the bottom of the healthy band, so
                // there is nothing left to leave unshaded.
                let span = domain.upperBound - domain.lowerBound
                let elevatedHeight = geo.size.height * (domain.upperBound - 4.5) / span
                VStack(spacing: 0) {
                    Theme.color(for: .elevated).opacity(0.10).frame(height: elevatedHeight)
                    Theme.color(for: .healthy).opacity(0.12)
                }
            }
        }
    }
}

/// The pH "product spine": four cited sections answering Why pH matters, What this result means,
/// What to do next, and the Genesyx supplements connection. Wellness framing only — the health
/// claim in "Why pH matters" carries a Sources footer (NHS + StatPearls) to satisfy Guideline 1.4.1.
private struct PhSpine: View {
    let latest: PhReading?
    let onOpenSupplements: (() -> Void)?
    let onOpenLearn: (() -> Void)?

    private static let sourceIDs = ["vaginal-ph", "statpearls-vaginitis"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle().fill(GenesyxColor.border.opacity(0.6)).frame(height: 1)

            // a. Why pH matters — the one general health statement, so it carries the citations.
            section(PhCopy.spineWhyTitle, PhCopy.spineWhyBody) {
                SourcesFooter(sourceIDs: PhSpine.sourceIDs)
            }

            // The way *into* the pH reading. Four Learn guides send her to this tracker and the
            // tracker sent her nowhere back, so the sections below lean on background she had no
            // signposted route to. Placed under "Why pH matters" because that is where the question
            // it answers actually occurs to her.
            if let onOpenLearn {
                Button(action: onOpenLearn) {
                    HStack(spacing: 4) {
                        Text("Read: Understanding your vaginal pH")
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(GenesyxColor.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("phSpine.learn")
            }

            // b + c. Interpretation and next-steps only when there's a current reading.
            if let latest {
                let status = PhStatus.classify(latest.phValue)
                section(PhCopy.spineMeaningTitle, status == .elevated ? PhCopy.elevated : PhCopy.healthy)
                section(PhCopy.spineNextTitle, status == .elevated ? PhCopy.elevatedSignpost : PhCopy.spineNextHealthy)
            }

            // c2. Supporting vaginal health. Shown unconditionally, unlike b and c: it is the one
            // section that is useful before she has ever logged a reading, and it is the answer to
            // "what can I do?" — which the tab previously could not answer at all.
            section(PhCopy.spineSupportTitle, PhCopy.spineSupportBody) {
                Text(PhCopy.spineSupportSignpost)
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .accessibilityIdentifier("phSpine.support")

            // d. Genesyx supplements connection (navigational; no causal pH claim).
            VStack(alignment: .leading, spacing: 8) {
                Text(PhCopy.spineSupplementsTitle).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                Text(PhCopy.spineSupplementsBody).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                if let onOpenSupplements {
                    Button(action: onOpenSupplements) {
                        HStack(spacing: 4) {
                            Text("See your supplement plan").font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(GenesyxColor.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("phSpine.supplements")
                }
            }
        }
        .accessibilityIdentifier("phSpine")
    }

    private func section<Footer: View>(_ title: String, _ body: String, @ViewBuilder footer: () -> Footer = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            Text(body).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            footer()
        }
    }
}

/// Log / edit a vaginal-pH reading: value tile coloured by status, slider 3.8–7.0 step 0.1 with
/// ± buttons, when picker, notes, Save, Cancel (+ a confirmed Delete when editing).
private struct PhLogSheet: View {
    let existing: PhReading?
    /// False once Article 9 consent is withdrawn. Save is disabled; Delete is not, because
    /// removing a reading she already recorded is Article 17 and stays available either way.
    var canSave: Bool = true
    let onSave: (PhReading) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double
    @State private var recordedAt: Date
    @State private var notes: String
    @State private var confirmingDelete = false

    init(existing: PhReading?, canSave: Bool = true, onSave: @escaping (PhReading) -> Void, onDelete: @escaping (String) -> Void) {
        self.existing = existing
        self.canSave = canSave
        self.onSave = onSave
        self.onDelete = onDelete
        _value = State(initialValue: existing?.phValue ?? 4.2)
        _recordedAt = State(initialValue: existing?.recordedAt ?? Date())
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private func clampRound(_ v: Double) -> Double {
        PhStatus.clamped((v * 10).rounded() / 10)
    }

    var body: some View {
        let status = PhStatus.classify(value)
        let color = Theme.color(for: status)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Only renders while consent is withdrawn, and it is the same wording the
                    // tracking tabs carry. The sheet is reachable in that state solely so she can
                    // delete a reading, so the banner explains the disabled Save before she meets it.
                    ConsentWithdrawnBanner()
                    Text("Track your vaginal pH from 3.8 to 7.0.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    Text(PhCopy.accuracyCaveat)
                        .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("phLogAccuracyCaveat")
                    Text(PhCopy.disclaimer)
                        .font(.caption2).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 6) {
                        Text(String(format: "%.1f", value)).font(.system(size: 44, weight: .semibold)).foregroundStyle(color)
                            .accessibilityIdentifier("ph.currentValue")
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
                        .accessibilityIdentifier("ph.notesField")
                        .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GenesyxColor.border, lineWidth: 1))
                        .onChange(of: notes) { if $0.count > 500 { notes = String($0.prefix(500)) } }

                    // Deleting belongs down here, away from the two buttons she reaches for by
                    // reflex, and behind a question. It used to sit in the top-left toolbar slot —
                    // where every other screen in iOS puts Cancel — and fired on the first tap, so
                    // backing out of an edit she had decided not to make destroyed the reading.
                    if let existing {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Text("Delete this reading")
                                .font(.gxBodySmall.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityIdentifier("ph.deleteReading")
                        // An alert, not a confirmation dialog: the dialog drops a custom `.cancel`
                        // label, so "Keep it" rendered as a bare "Cancel" — the same word as the
                        // toolbar button she just learned does not delete anything.
                        .alert("Delete this reading?", isPresented: $confirmingDelete) {
                            Button("Delete", role: .destructive) { onDelete(existing.id) }
                            Button("Keep it", role: .cancel) {}
                        } message: {
                            Text("This removes it from your history everywhere. It cannot be undone.")
                        }
                    }
                }
                .padding(20)
            }
            .background(GenesyxColor.background)
            .navigationTitle(existing == nil ? "Log pH reading" : "Edit pH reading")
            .navigationBarTitleDisplayMode(.inline)
            // The notes field wraps, so Return types a newline rather than dismissing, and the
            // keyboard then covers the Save button she is reaching for.
            .gxKeyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(PhReading(
                            id: existing?.id ?? UUID().uuidString,
                            phValue: value, recordedAt: recordedAt,
                            notes: notes.isEmpty ? nil : notes,
                            // New readings are vaginal; an edit keeps the existing reading's type.
                            measurementType: existing?.measurementType ?? .vaginal
                        ))
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
