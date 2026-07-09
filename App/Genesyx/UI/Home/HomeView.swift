import SwiftUI
import GenesyxCore

/// Home screen (lean v1). Demonstrates the ported `CycleEngine` + `CycleContent` end-to-end:
/// shows the current phase hero when cycle settings exist, otherwise prompts to set the last
/// period date. Includes a quick hydration control backed by `DailyLogRepository`.
/// The full Home (hero card, streak, focus food, log CTA) is translated next.
struct HomeView: View {

    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var session: SessionRepository

    @State private var lastPeriod = Date()
    @State private var showLog = false
    @State private var showPregnancy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greetingHeader
                    if let settings = cycle.settings {
                        phaseCard(for: settings)
                        focusCard(for: settings)
                        hydrationCard
                        GxPrimaryButton(title: "Log today", leadingSystemImage: "square.and.pencil") { showLog = true }
                        pregnancyPathwayLink
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
                metric("Ovulation", "Day \(info.ovulationDay)")
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

    // MARK: - Hydration

    private var hydrationCard: some View {
        let ml = dailyLog.waterMl(on: .today())
        let streak = dailyLog.streak()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HYDRATION").font(.gxEyebrow).tracking(1.6).foregroundStyle(GenesyxColor.electricBlue)
                Spacer()
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 11))
                        Text("\(streak)-day streak").font(.gxEyebrow)
                    }
                    .foregroundStyle(GenesyxColor.electricPink)
                }
            }
            HStack {
                Text("\(ml) ml").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                Spacer()
                Button { dailyLog.adjustWater(-250) } label: { Image(systemName: "minus.circle.fill") }
                Button { dailyLog.adjustWater(250) } label: { Image(systemName: "plus.circle.fill") }
            }
            .font(.system(size: 26))
            .foregroundStyle(GenesyxColor.electricBlue)
        }
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    // MARK: - First-run setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Genesyx").font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
            Text("When did your last period start? We'll map your cycle from there.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            DatePicker("Last period start", selection: $lastPeriod, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
            Button {
                cycle.upsert(CycleSettings(lastPeriodDate: CalendarDate(date: lastPeriod)))
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
