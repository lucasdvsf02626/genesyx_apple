import GenesyxCore
import SwiftUI

/// The Fertility Kit hub. Every branch is chosen by `kit.accessState`: what is stored about her
/// programme decides nothing until the account holds access.
struct FertilityKitHomeView: View {
    @Environment(\.fertilityKit) private var kit
    @State private var route: FertilityKitRoute?

    init() {}

    var body: some View {
        let state = kit.accessState
        let rows = FertilityKitHomePresentation.rows(for: kit)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if FertilityKitHomePresentation.showsAccessCard(state) {
                    FertilityKitAccessCard(placement: .kitHome)
                }
                if let body = FertilityKitHomePresentation.body(for: state) {
                    KitLine(body.text, muted: true).accessibilityIdentifier(body.identifier)
                }
                if case .active(let day, let week, let phase) = state {
                    ConsentWithdrawnBanner()
                    header(day: day, week: week, phase: phase)
                    weekFocus(week)
                    todayCard(day)
                    weekFigure()
                }
                if !rows.isEmpty {
                    KitSectionTitle(FertilityKitHomeCopy.exploreHeading)
                    ForEach(rows, id: \.id) { row in
                        KitRow(icon: row.icon, title: row.title, detail: row.detail,
                               identifier: "kit.home.row.\(row.id)") { route = row.route }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.home")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .fertilityKitRoute($route)
        .navigationTitle(FertilityKitCopy.kitName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(day: Int, week: Int, phase: ProgrammePhase) -> some View {
        KitCard(tinted: true, identifier: "kit.home.header") {
            Text(FertilityPictureCopy.dayOfProgramme(day)).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("kit.home.header.day")
            Text(FertilityKitCopy.weekOfProgramme(week)).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                .accessibilityIdentifier("kit.home.header.week")
            if let title = ProgrammeContent.draft.phaseTitles[phase] {
                Text(title).font(.gxBody).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("kit.home.header.phase")
            }
        }
    }

    @ViewBuilder
    private func weekFocus(_ week: Int) -> some View {
        if let focus = FertilityKitHomePresentation.weekFocus(week: week) {
            KitCard(identifier: "kit.home.week.focus") {
                KitSectionTitle(FertilityKitHomeCopy.thisWeeksFocus)
                Text(focus.theme).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("kit.home.week.theme")
                KitLine(focus.purpose).accessibilityIdentifier("kit.home.week.purpose")
            }
        }
    }

    @ViewBuilder
    private func todayCard(_ day: Int) -> some View {
        if let plan = kit.todayPlan(), let definition = ProgrammeContent.draft.day(day) {
            let lines = FertilityKitHomePresentation.progressLines(plan, consentActive: kit.planInput.consentActive)
            KitCard(identifier: "kit.home.today") {
                KitSectionTitle(FertilityKitCopy.todaysProgramme)
                Text(definition.title).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("kit.home.today.focus")
                KitSecondaryButton(title: FertilityKitHomeCopy.openToday) { kit.open(.kitToday) }
                    .accessibilityIdentifier("kit.home.today.openDay")
                ProgrammeTaskListView(plan: plan, interactive: true)
                if let first = lines.first {
                    KitLine(first).accessibilityIdentifier("kit.home.today.progress")
                    if lines.count > 1 { KitLine(lines[1]).accessibilityIdentifier("kit.home.today.partly") }
                }
            }
        }
    }

    @ViewBuilder
    private func weekFigure() -> some View {
        let lines = FertilityKitHomePresentation.weekFigureLines(kit)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                KitSectionTitle(FertilityPictureCopy.thisProgrammeWeek)
                KitLines(lines, identifier: "kit.home.week.figure")
            }
        }
    }
}

/// What the home shows, worked out from the context alone.
enum FertilityKitHomePresentation {
    struct HubRow: Equatable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let route: FertilityKitRoute
    }

    struct StateBody: Equatable {
        let identifier: String
        let text: String
    }

    /// Everything but an active programme opens on the access card.
    static func showsAccessCard(_ state: FertilityKitAccessState) -> Bool {
        if case .active = state { return false }
        return true
    }

    /// The line each state adds under the card. Without access there is none.
    static func body(for state: FertilityKitAccessState) -> StateBody? {
        switch state {
        case .noAccess, .active: return nil
        case .notStarted: return StateBody(identifier: "kit.home.notStarted", text: FertilityKitHomeCopy.notStartedBody)
        case .scheduled: return StateBody(identifier: "kit.home.scheduled", text: FertilityKitHomeCopy.scheduledBody)
        case .completed: return StateBody(identifier: "kit.home.completed", text: FertilityKitHomeCopy.completedBody)
        case .stopped: return StateBody(identifier: "kit.home.stopped", text: FertilityKitHomeCopy.stoppedBody)
        }
    }

    /// The week's theme and purpose, verbatim from core. Active only; the week's review and
    /// safety notes are not read.
    static func weekFocus(week: Int) -> (theme: String, purpose: String)? {
        ProgrammeContent.draft.week(week).map { ($0.themeTitle, $0.purpose) }
    }

    /// The focus block of a context: only while the programme is active.
    static func weekFocus(for kit: FertilityKitContext) -> (theme: String, purpose: String)? {
        guard case .active(_, let week, _) = kit.accessState else { return nil }
        return weekFocus(week: week)
    }

    /// Today in counts. With consent withdrawn nothing is counted, and nothing is said.
    static func progressLines(_ plan: ProgrammeDayPlan, consentActive: Bool) -> [String] {
        consentActive ? FertilityKitCopy.todayProgressLines(ProgrammeConsistency.today(plan)) : []
    }

    /// The programme week's figure. The only place a percentage can appear on the home, and only
    /// when core gives one.
    static func weekFigureLines(_ kit: FertilityKitContext) -> [String] {
        guard case .active = kit.accessState, kit.planInput.consentActive else { return [] }
        return ProgrammeReviewLogic.lines(for: kit.report().week)
    }

    /// The hub, by access state. Without access there is none.
    static func rows(for kit: FertilityKitContext) -> [HubRow] {
        let started = kit.planInput.state.startedOn != nil
        let guide = row("guide", "book", FertilityKitCopy.programmeGuide, FertilityKitHomeCopy.guideDetail, .kit(.kitGuide))
        let diet = row("dietPlan", "fork.knife", FertilityKitCopy.dietPlan, FertilityKitHomeCopy.dietPlanDetail, .kit(.kitDietPlan))
        let reviews = row("reviews", "list.clipboard", FertilityKitCopy.programmeReviews,
                          FertilityKitHomeCopy.reviewsDetail, .kit(.kitReviews))
        let ninety = row("ninetyDayReview", "checkmark.circle", ProgrammeReviewCopy.ninetyDayTitle,
                         FertilityKitHomeCopy.ninetyDayReviewDetail, .kit(.kitNinetyDayReview))
        let picture = row("picture", "heart.text.square", FertilityPictureCopy.title,
                          FertilityKitHomeCopy.pictureDetail, .kit(.kitPicture))
        let history = row("cycleHistory", "calendar", FertilityKitCopy.cycleHistory,
                          FertilityKitHomeCopy.cycleHistoryDetail, .kit(.kitCycleHistory))
        let days = row("days", "text.book.closed", FertilityKitHomeCopy.programmeDays,
                       FertilityKitHomeCopy.programmeDaysDetail, .kit(.kitToday))
        let log = row("dailyLog", "square.and.pencil", FertilityKitHomeCopy.dailyLog,
                      FertilityKitHomeCopy.dailyLogDetail, .dailyLog(kit.today))
        let optionalHistory = kit.cycleHistoryAvailable ? [history] : []
        let optionalReviews = started ? [reviews] : []
        let optionalNinety = kit.isNinetyDayReviewAvailable ? [ninety] : []
        switch kit.accessState {
        case .noAccess: return []
        case .notStarted, .scheduled: return [guide, diet, picture] + optionalHistory
        case .active: return [guide, diet] + optionalReviews + optionalNinety + [picture] + optionalHistory
        case .completed: return optionalNinety + optionalReviews + [picture, diet, guide, days, log] + optionalHistory
        case .stopped: return [guide, diet, picture] + optionalReviews + optionalHistory
        }
    }

    private static func row(_ id: String, _ icon: String, _ title: String, _ detail: String,
                            _ route: FertilityKitRoute) -> HubRow {
        HubRow(id: id, icon: icon, title: title, detail: detail, route: route)
    }
}

#if DEBUG
#Preview {
    FertilityKitHomeView().withKitPreview(day: 23)
}
#endif
