import GenesyxCore
import SwiftUI

/// The one task list: today's programme on the home, and the day's tasks in the reader. A row is
/// read as one element, and states its status in words.
struct ProgrammeTaskListView: View {
    private let plan: ProgrammeDayPlan
    private let interactive: Bool
    private let onDayPage: Bool

    @Environment(\.fertilityKit) private var kit
    @State private var route: FertilityKitRoute?

    init(plan: ProgrammeDayPlan, interactive: Bool, onDayPage: Bool = false) {
        self.plan = plan
        self.interactive = interactive
        self.onDayPage = onDayPage
    }

    var body: some View {
        let daily = ProgrammeTaskPresentation.dailyRows(plan, in: kit, onDayPage: onDayPage)
        let weekly = ProgrammeTaskPresentation.weeklyRows(plan, in: kit)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(daily, id: \.id) { row in taskRow(row, identifier: "kit.task.\(row.id)") }
            if !weekly.isEmpty {
                Text(FertilityKitHomeCopy.weeklyHeading).font(.gxLabel).foregroundStyle(GenesyxColor.mutedForeground)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(weekly, id: \.id) { row in taskRow(row, identifier: "kit.task.weekly.\(row.id)") }
            }
        }
        .fertilityKitRoute($route)
        .kitContainer("kit.tasks")
    }

    @ViewBuilder
    private func taskRow(_ row: ProgrammeTaskPresentation.Row, identifier: String) -> some View {
        let label = FertilityKitCopy.rowLabel(row.name, status: row.status, details: row.detailLines)
        if interactive && row.route != .unavailable {
            Button { route = row.route } label: { content(row, tappable: true) }
                .buttonStyle(.plain)
                .kitRow(identifier, label: label)
                .accessibilityAddTraits(.isButton)
        } else {
            content(row, tappable: false).kitRow(identifier, label: label)
        }
    }

    private func content(_ row: ProgrammeTaskPresentation.Row, tappable: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.status).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(row.detailLines.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if tappable {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(GenesyxColor.muted.opacity(0.6))
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// What a task row says and where it leads, worked out from the plan alone.
enum ProgrammeTaskPresentation {
    struct Row: Equatable {
        let id: String
        let name: String
        let status: String
        let detailLines: [String]
        let route: FertilityKitRoute
    }

    /// The day's tasks in the engine's order, without the ones that do not apply to her today.
    static func dailyRows(_ plan: ProgrammeDayPlan, in kit: FertilityKitContext, onDayPage: Bool) -> [Row] {
        plan.tasks.compactMap { task in
            guard let name = visibleName(task) else { return nil }
            let isLesson = task.category == .programmeLesson || task.category == .fertilityKitEducation
            return Row(id: task.category.rawValue, name: name, status: status(task),
                       detailLines: details(task, in: plan),
                       route: onDayPage && isLesson ? .unavailable : FertilityKitRoutes.route(forTask: task, in: kit))
        }
    }

    /// The once-a-week activities. Not part of today's count.
    static func weeklyRows(_ plan: ProgrammeDayPlan, in kit: FertilityKitContext) -> [Row] {
        plan.weeklyTasks.compactMap { task in
            guard let name = visibleName(task) else { return nil }
            let word = task.isDone ? FertilityKitHomeCopy.weeklyDone
                : task.status == .eligible || task.status == .completed ? FertilityKitHomeCopy.weeklyToDo
                : status(task)
            return Row(id: task.category.rawValue, name: name, status: word, detailLines: [],
                       route: FertilityKitRoutes.route(forTask: task, in: kit))
        }
    }

    /// nil for a task that is not shown: not relevant today, or with no name to go by.
    private static func visibleName(_ task: ProgrammeTask) -> String? {
        task.status == .notApplicable ? nil : ProgrammeReviewCopy.routineName(for: task.category)
    }

    /// An optional task that is done stays optional in the engine, so this reads `isDone`.
    private static func status(_ task: ProgrammeTask) -> String {
        if task.isDone { return FertilityKitCopy.statusDone }
        switch task.status {
        case .completed: return FertilityKitCopy.statusPartDone
        case .optional: return FertilityKitCopy.statusOptional
        case .skipped: return FertilityKitCopy.statusNotRecorded
        case .eligible, .notApplicable: return FertilityKitCopy.statusToDo
        }
    }

    /// Only the nutrition check-in has detail, and only once it is done: no number before then.
    private static func details(_ task: ProgrammeTask, in plan: ProgrammeDayPlan) -> [String] {
        guard task.category == .nutritionCheckIn, task.isDone else { return [] }
        return [FertilityKitCopy.nutritionCheckInCompleted]
            + (plan.foodGroupsRecorded > 0
               ? [FertilityKitCopy.foodGroupsRecorded(plan.foodGroupsRecorded, of: plan.foodGroupTotal)] : [])
    }
}

#if DEBUG
#Preview {
    FertilityKitHomeView().withKitPreview(day: 23)
}
#endif
