import SwiftUI
import GenesyxCore

/// Home screen (lean v1). Demonstrates the ported `CycleEngine` + `CycleContent` end-to-end:
/// shows the current phase hero when cycle settings exist, otherwise prompts to set the last
/// period date. Includes a quick hydration control backed by `DailyLogRepository`.
/// The full Home (hero card, streak, focus food, log CTA) is translated next.
struct HomeView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var session: SessionRepository

    @EnvironmentObject private var router: TabRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lastPeriod = Date()
    @State private var showLog = false
    @State private var showPregnancy = false
    @State private var showCycleSetup = false
    private static let hydrationGoalMl = TrackingEngine.defaultWaterGoalMl

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greetingHeader
                    if let settings = cycle.settings {
                        phaseCard(for: settings)
                        focusCard(for: settings)
                        hydrationCard
                        phNudgeCard
                        GxPrimaryButton(title: "Log today", leadingSystemImage: "square.and.pencil") { showLog = true }
                        // v1: Pregnancy preview entry hidden (destination intact, unreachable). Restore by uncommenting.
                        // pregnancyPathwayLink
                    } else {
                        setupCard
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLog) { LogView() }
            .sheet(isPresented: $showPregnancy) { PregnancyView() }
            .sheet(isPresented: $showCycleSetup) {
                CycleSettingsSheet(current: CycleSettings(lastPeriodDate: CalendarDate(date: lastPeriod))) {
                    cycle.upsert($0)
                }
            }
        }
    }

    // MARK: - Greeting header

    private var greetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.greeting).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                Text(session.displayName ?? "there").font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
            }
            Spacer()
            Text((session.displayName?.first).map { String($0).uppercased() } ?? "G")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [GenesyxColor.babyLavender, GenesyxColor.electricPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var pregnancyPathwayLink: some View {
        Button { showPregnancy = true } label: {
            HStack(spacing: 6) {
                Text("Preview pregnancy pathway").font(.gxBodySmall.weight(.medium))
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(GenesyxColor.mutedForeground)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    // MARK: - Phase hero

    @ViewBuilder
    private func phaseCard(for settings: CycleSettings) -> some View {
        let info = CycleEngine.cyclePhase(settings: settings)
        let inFertile = info.fertileWindow.contains(info.dayOfCycle) && info.phase != .ovulatory

        VStack(alignment: .leading, spacing: 12) {
            Text(CycleContent.phaseSubLabel(info.phase, inFertile: inFertile).uppercased())
                .font(.gxEyebrow)
                .tracking(1.6)
                .foregroundStyle(GenesyxColor.primary)

            Text(CycleContent.phaseHeroText(info.phase, inFertile: inFertile))
                .font(.gxTitle)
                .foregroundStyle(GenesyxColor.foreground)

            Text(CycleContent.phaseHeroSubtext(info.phase, inFertile: inFertile))
                .font(.gxBodySmall)
                .foregroundStyle(GenesyxColor.mutedForeground)

            HStack(spacing: 8) {
                ForEach(CycleContent.phaseTags(info.phase, inFertile: inFertile), id: \.self) { tag in
                    Text(tag)
                        .font(.gxEyebrow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GenesyxColor.secondary)
                        .foregroundStyle(GenesyxColor.foreground)
                        .clipShape(Capsule())
                }
            }

            Divider().overlay(GenesyxColor.border)

            HStack {
                metric("Day", "\(info.dayOfCycle)")
                Spacer()
                metric("Next period", info.daysUntilNextPeriod == 0 ? "Today" : "\(info.daysUntilNextPeriod)d")
                Spacer()
                metric("Predicted ovulation", "Day \(info.ovulationDay)")
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
            Text(label).font(.gxEyebrow).foregroundStyle(GenesyxColor.mutedForeground)
        }
    }

    // MARK: - Today's focus

    @ViewBuilder
    private func focusCard(for settings: CycleSettings) -> some View {
        let info = CycleEngine.cyclePhase(settings: settings)
        if let copy = CycleContent.phaseHeroCopy[info.phase]?.focus {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "leaf.fill").foregroundStyle(GenesyxColor.electricLavender)
                    .frame(width: 40, height: 40).background(GenesyxColor.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Today's focus", color: GenesyxColor.mutedForeground)
                    Text(copy.title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    Text(copy.body).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                Spacer()
            }
            .padding(20)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    // MARK: - Hydration (synced summary — Track owns logging)

    private var hydrationCard: some View {
        let goal = Self.hydrationGoalMl
        let todayMl = dailyLog.waterMl(on: .today())
        let streak = dailyLog.streak()
        let insights = HydrationInsightLogic.lastSevenDays(
            logByDate: dailyLog.logByDate, goalMl: goal, streak: streak)
        let hour = Calendar.current.component(.hour, from: Date())
        let status = HydrationStatusEvaluator.evaluate(
            todayMl: todayMl, goalMl: goal, hour: hour,
            daysOnGoal: insights.daysOnGoal, streak: streak)
        let pct = goal > 0 ? min(Double(todayMl) / Double(goal), 1) : 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("HYDRATION").font(.gxEyebrow).tracking(1.6).foregroundStyle(GenesyxColor.electricBlue)
                Spacer()
                HStack(spacing: 4) {
                    Text("Track").font(.gxEyebrow.weight(.semibold))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(GenesyxColor.primary)
            }
            HStack(alignment: .center, spacing: 16) {
                hydrationRing(pct: pct)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(todayMl.formatted()) / \(goal.formatted()) ml")
                        .font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    statusChip(status)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hydration, \(todayMl.formatted()) of \(goal.formatted()) millilitres, \(status.title.lowercased())")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens hydration in Track")
                .accessibilityAction { openHydrationDetail() }
                Spacer(minLength: 8)
                if streak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(GenesyxColor.electricPink)
                        Text("\(streak)-day streak")
                            .font(.gxEyebrow)
                            .foregroundStyle(GenesyxColor.mutedForeground)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Text(status.focusLine)
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            weekRow(insights)
        }
        .padding(20)
        .background(
            GenesyxColor.card
                .contentShape(Rectangle())
                .onTapGesture { openHydrationDetail() }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func hydrationRing(pct: Double) -> some View {
        ZStack {
            Circle().stroke(GenesyxColor.muted, lineWidth: 7)
            Circle().trim(from: 0, to: pct)
                .stroke(LinearGradient(colors: [GenesyxColor.electricBlue, GenesyxColor.powderBlue],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((pct * 100).rounded()))%")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(GenesyxColor.foreground)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(width: 60, height: 60)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: pct)
    }

    private func statusChip(_ status: HydrationStatus) -> some View {
        let color = status.tone == .positive ? GenesyxColor.primary : GenesyxColor.mutedForeground
        return Text(status.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func weekRow(_ insights: HydrationInsights) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(insights.dailyMl.enumerated()), id: \.offset) { _, ml in
                    let level = HydrationInsightLogic.dayFillLevel(ml: ml, goalMl: Self.hydrationGoalMl)
                    Capsule()
                        .fill(level == 0
                              ? GenesyxColor.muted
                              : GenesyxColor.electricBlue.opacity(level == 1 ? 1 : 0.4))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                }
            }
            Text("\(insights.daysOnGoal) of 7 days on goal")
                .font(.gxEyebrow).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(insights.daysOnGoal) of 7 days on goal this week")
    }

    private func openHydrationDetail() {
        router.pendingHydration = true   // consumed by TrackView
        router.selection = 1             // Track tab
    }

    // MARK: - pH nudge (compact prompt — Track owns logging)

    /// A small tap-through card inviting her to check her urine pH. Shows the last reading when one
    /// exists, otherwise a gentle first-log prompt. Tapping jumps to the pH tracker in Track.
    private var phNudgeCard: some View {
        let latest = ph.readings.last
        return Button { openPhDetail() } label: {
            HStack(spacing: 14) {
                Image(systemName: "testtube.2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(GenesyxColor.primary)
                    .frame(width: 44, height: 44)
                    .background(GenesyxColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check your pH").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    Text(latest.map { String(format: "Last reading %.1f — tap to log again", $0.phValue) }
                         ?? "Log today's reading in the pH tracker")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Check your pH")
        .accessibilityHint("Opens the pH tracker in Track")
        .accessibilityIdentifier("home.phCard")
    }

    private func openPhDetail() {
        router.pendingPh = true   // consumed by TrackView
        router.selection = 1      // Track tab
    }

    // MARK: - First-run setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Genesyx").font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
            Text("When did your last period start? Next we'll confirm your cycle length — every prediction is built from it.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            DatePicker("Last period start", selection: $lastPeriod, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
            Button {
                // Her cycle length drives phases, ovulation and the fertile window. Ask for it here
                // rather than defaulting to 28 silently, which would show every user the same cycle.
                showCycleSetup = true
            } label: {
                Text("Start tracking")
                    .font(.gxLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GenesyxColor.primary)
                    .foregroundStyle(GenesyxColor.onPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
