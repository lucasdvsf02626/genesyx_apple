import GenesyxCore
import SwiftUI

/// What the day reader works out from core and the context. Pure, so it is tested without a view.
enum ProgrammeDayReaderPresentation {

    /// A day's words, written entry first and the definition as the fallback.
    struct Page: Equatable {
        let day: Int
        let label: String
        let title: String
        let focus: String
        let introduction: String
        let lessonParagraphs: [String]
        let why: String?
        let reflection: String?
        let related: [ProgrammeContentReference]
        let callToAction: ProgrammeDestination
        let disclaimerRequired: Bool
        let lessonID: String
    }

    struct MainButton: Equatable {
        let label: String
        let route: FertilityKitRoute
    }

    /// The day shown: the one asked for, never after the latest she may read, never before day 1.
    static func shownDay(_ requested: Int?, latest: Int) -> Int {
        min(max(requested ?? latest, 1), latest)
    }

    /// nil outside days 1 to 90. A provider with no text leaves a complete short day.
    static func page(forDay day: Int, lessons: (any ProgrammeLessonProviding)? = ProgrammeContent.draftLessons,
                     content: ProgrammeContent = .draft) -> Page? {
        guard let page = content.presentation(ofDay: day, lessons: lessons) else { return nil }
        let definition = page.definition
        let writing = ProgrammeDayCopyDraft.writing(forDay: day)
        return Page(
            day: day,
            label: FertilityKitCopy.dotJoined([
                FertilityPictureCopy.dayOfProgramme(day),
                FertilityKitCopy.weekOfProgramme(ProgrammeCalendar.week(forDay: day)),
                FertilityKitCopy.minutesToRead(page.estimatedReadMinutes)]),
            title: definition.title, focus: definition.focus, introduction: definition.introduction,
            lessonParagraphs: page.lesson?.paragraphs ?? [],
            why: writing?.whyThisMatters,
            reflection: writing?.reflection ?? definition.optionalReflection,
            related: writing?.relatedContent ?? definition.relatedContent,
            callToAction: definition.callToAction,
            disclaimerRequired: definition.safety.disclaimerRequired,
            lessonID: definition.lesson.id)
    }

    /// The day's main button. Hidden where its route is unavailable, and for the lesson itself:
    /// she is already on it.
    static func mainButton(for destination: ProgrammeDestination, in kit: FertilityKitContext) -> MainButton? {
        guard destination != .programmeLesson,
              let label = ProgrammeReaderCopy.callToActionLabel(for: destination) else { return nil }
        let route = FertilityKitRoutes.route(for: destination, in: kit)
        return route == .unavailable ? nil : MainButton(label: label, route: route)
    }

    /// True when no task of the day has a credit that came from that day's own records. A lesson
    /// opened later (`explicitRecord`) and her settings (`cycleSettings`) are not records of the day.
    static func nothingRecorded(_ plan: ProgrammeDayPlan) -> Bool {
        !plan.tasks.contains { task in
            guard task.credit > 0, let source = task.completionSource else { return false }
            return source != .explicitRecord && source != .cycleSettings
        }
    }

    /// Today: counts only, the very lines the home shows. A past day: the counts, with a
    /// percentage in front only when core offers one.
    static func progressLines(for plan: ProgrammeDayPlan, today: CalendarDate) -> [String] {
        if plan.date == today { return FertilityKitCopy.todayProgressLines(ProgrammeConsistency.today(plan)) }
        return ProgrammeReviewLogic.lines(for: ProgrammeConsistency.day(plan), nothingTracked: nothingRecorded(plan))
    }
}

/// A day of the programme: its focus, lesson, actions and reading, with a way to the days before.
struct ProgrammeDayReaderView: View {
    @Environment(\.fertilityKit) private var kit
    @EnvironmentObject private var programme: ProgrammeRepository

    @State private var shownDay: Int?
    @State private var route: FertilityKitRoute?

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let latest = kit.readableDay {
                    let day = ProgrammeDayReaderPresentation.shownDay(shownDay, latest: latest)
                    if let page = ProgrammeDayReaderPresentation.page(forDay: day) {
                        reader(page, latest: latest)
                    }
                } else {
                    KitLine(ProgrammeReaderCopy.notStarted).accessibilityIdentifier("kit.day.notStarted")
                    KitSecondaryButton(title: FertilityKitCopy.openKit) { kit.open(.fertilityKit) }
                        .accessibilityIdentifier("kit.day.openKit")
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.day")
        }
        .id(kit.readableDay.map { ProgrammeDayReaderPresentation.shownDay(shownDay, latest: $0) })
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.yourProgramme)
        .navigationBarTitleDisplayMode(.inline)
        .fertilityKitRoute($route)
        .onAppear { markRead() }
        .onChange(of: shownDay) { _ in markRead() }
    }

    @ViewBuilder
    private func reader(_ page: ProgrammeDayReaderPresentation.Page, latest: Int) -> some View {
        let plan = kit.dayPlan(forDay: page.day)
        let isToday = plan.map { $0.date == kit.today } ?? false
        let progress = plan.map { ProgrammeDayReaderPresentation.progressLines(for: $0, today: kit.today) } ?? []
        let showsRelated = !ProgrammeRelatedPresentation.rows(page.related, in: kit).isEmpty
        let button = ProgrammeDayReaderPresentation.mainButton(for: page.callToAction, in: kit)

        section(ProgrammeReaderCopy.todaysFocus, id: "kit.day.section.focus") {
            Eyebrow(page.label).accessibilityLabel(page.label).accessibilityIdentifier("kit.day.label")
            Text(page.title).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("kit.day.title")
            KitLine(page.focus).accessibilityIdentifier("kit.day.focus")
            KitLine(page.introduction, muted: true).accessibilityIdentifier("kit.day.introduction")
            ForEach(Array(page.lessonParagraphs.enumerated()), id: \.offset) { index, paragraph in
                KitLine(paragraph).accessibilityIdentifier("kit.day.lesson.paragraph.\(index)")
            }
        }
        if let why = page.why {
            section(ProgrammeReaderCopy.whyThisMatters, id: "kit.day.section.why") {
                KitLine(why).accessibilityIdentifier("kit.day.why")
            }
        }
        if let plan {
            section(ProgrammeReaderCopy.todaysActions, id: "kit.day.section.actions") {
                ProgrammeTaskListView(plan: plan, interactive: isToday, onDayPage: true)
                if !isToday {
                    KitSecondaryButton(title: ProgrammeReaderCopy.openThisDaysLog) { route = .dailyLog(plan.date) }
                        .accessibilityIdentifier("kit.day.openLog")
                }
            }
        }
        if showsRelated || button != nil {
            section(ProgrammeReaderCopy.learnMore, id: "kit.day.section.learnMore") {
                ProgrammeRelatedContentList(references: page.related)
                if let button {
                    GxPrimaryButton(title: button.label) { route = button.route }
                        .accessibilityIdentifier("kit.day.cta")
                }
            }
        }
        if !progress.isEmpty {
            section(ProgrammeReaderCopy.yourProgress, id: "kit.day.section.progress") {
                KitLines(progress, identifier: "kit.day.progress")
            }
        }
        if let reflection = page.reflection {
            section(ProgrammeReaderCopy.optionalReflection, id: "kit.day.section.reflection") {
                KitLine(reflection).accessibilityIdentifier("kit.day.reflection")
                KitSecondaryButton(title: ProgrammeReaderCopy.openTodaysLog) { route = .dailyLog(kit.today) }
                    .accessibilityIdentifier("kit.day.openTodaysLog")
            }
        }
        if page.disclaimerRequired {
            KitNote(MEDICAL_DISCLAIMER, boxed: true).accessibilityIdentifier("kit.day.disclaimer")
        }
        if page.day > 1 || page.day < latest {
            HStack(spacing: 12) {
                if page.day > 1 {
                    KitSecondaryButton(title: ProgrammeReaderCopy.previousDay) { shownDay = page.day - 1 }
                        .accessibilityIdentifier("kit.day.previous")
                }
                if page.day < latest {
                    KitSecondaryButton(title: ProgrammeReaderCopy.nextDay) { shownDay = page.day + 1 }
                        .accessibilityIdentifier("kit.day.next")
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, id: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            KitSectionTitle(title).accessibilityIdentifier(id)
            content()
        }
    }

    /// She is reading this lesson, so it is recorded as read. A programme that has not started
    /// records nothing, and the answer is not needed.
    private func markRead() {
        guard let latest = kit.readableDay else { return }
        let day = ProgrammeDayReaderPresentation.shownDay(shownDay, latest: latest)
        guard let page = ProgrammeDayReaderPresentation.page(forDay: day) else { return }
        _ = programme.markLessonRead(page.lessonID)
    }
}

#if DEBUG
#Preview {
    ProgrammeDayReaderView().withKitPreview(day: 23)
}
#endif
