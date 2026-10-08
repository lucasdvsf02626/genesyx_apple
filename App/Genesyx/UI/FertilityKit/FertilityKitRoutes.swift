import GenesyxCore
import SwiftUI

/// Where a control of a kit screen leads. Worked out by `FertilityKitRoutes`, performed by
/// `fertilityKitRoute(_:)`. A control whose route is `.unavailable` is not drawn.
enum FertilityKitRoute: Equatable {
    case tab(Int), hydration, dailyLog(CalendarDate), learnArticle(String)
    case kit(MoreDestination), scan(ScanDeepLink), unavailable
}

/// The one mapping from what core names (a destination, a task, a reference, a guide section) to
/// a real screen. Pure: everything it needs is in the context.
enum FertilityKitRoutes {

    static func route(for destination: ProgrammeDestination, in kit: FertilityKitContext) -> FertilityKitRoute {
        let started = kit.planInput.state.startedOn != nil
        switch destination {
        case .cycle: return .tab(1)
        case .dailyLog: return .dailyLog(kit.today)
        case .hydration: return .hydration
        case .nutrition: return .kit(.kitDietPlan)
        case .insights: return .tab(4)
        case .programmeLesson: return kit.readableDay == nil ? .unavailable : .kit(.kitToday)
        case .weeklyReview: return started ? .kit(.kitReviews) : .unavailable
        case .programmeProgress:
            guard started else { return .unavailable }
            return kit.isNinetyDayReviewAvailable ? .kit(.kitNinetyDayReview) : .kit(.kitReviews)
        case .lhTest: return kit.scanAvailable ? .scan(.ovulationTest) : .unavailable
        // Manual pH logging exists in every build.
        case .phTest: return .tab(2)
        case .fertilityKitGuide: return .kit(.kitGuide)
        }
    }

    /// The task's own destination, with one override: the lesson task of a test-guidance day
    /// names the guide, but the record that completes it is the day's page, so it routes there.
    static func route(forTask task: ProgrammeTask, in kit: FertilityKitContext) -> FertilityKitRoute {
        route(for: task.category == .fertilityKitEducation ? .programmeLesson : task.destination, in: kit)
    }

    static func route(for destination: FertilityPictureDestination, in kit: FertilityKitContext) -> FertilityKitRoute {
        switch destination {
        case .programme(let destination): return route(for: destination, in: kit)
        case .pregnancyTestScreen: return .scan(.pregnancyTest)
        }
    }

    /// `isPublished` is the rule Learn applies when it opens an article, so a row is never
    /// offered that Learn would then refuse. A parameter, so no test depends on the date it runs.
    static func route(for reference: ProgrammeContentReference, in kit: FertilityKitContext,
                      isPublished: (String) -> Bool = { LearnLibrary.articleBySlug($0) != nil }) -> FertilityKitRoute {
        switch reference {
        case .learnArticle(let slug): return isPublished(slug) ? .learnArticle(slug) : .unavailable
        case .recipe: return .kit(.kitDietPlan)
        }
    }

    /// The section's own destination, except where its label promises something more specific
    /// than the destination can say.
    static func route(forGuideSection section: ProgrammeGuideSection, in kit: FertilityKitContext) -> FertilityKitRoute {
        switch section.slug {
        case "your-fertility-kit", "pregnancy-tests": return .kit(.fertilityKit)
        case "understanding-test-history": return .kit(.kitPicture)
        case "nutrition": return .dailyLog(kit.today)
        default: return route(for: section.callToAction.destination, in: kit)
        }
    }

    /// The section on scanning an ovulation test is left out of the list where scanning is not.
    static func isVisible(_ section: ProgrammeGuideSection, in kit: FertilityKitContext) -> Bool {
        section.slug != "scanning-an-ovulation-test" || kit.scanAvailable
    }
}

extension View {
    /// Performs a route when one is set, then clears it. The daily log is the exception: it is a
    /// sheet, and the route stays set until the sheet is dismissed. For pushed screens only.
    func fertilityKitRoute(_ route: Binding<FertilityKitRoute?>) -> some View {
        modifier(FertilityKitRouteModifier(route: route))
    }
}

private struct FertilityKitRouteModifier: ViewModifier {
    @Binding var route: FertilityKitRoute?

    @EnvironmentObject private var router: TabRouter
    @EnvironmentObject private var container: AppContainer
    @Environment(\.fertilityKit) private var kit

    func body(content: Content) -> some View {
        content
            .onChange(of: route) { route in
                if let route { perform(route) }
            }
            .sheet(item: logDay) { day in
                LogView(date: day.date).withAppEnvironment(container)
            }
    }

    private func perform(_ target: FertilityKitRoute) {
        switch target {
        case .tab(let index): router.selection = index
        case .hydration:
            router.pendingHydration = true
            router.selection = 1
        case .learnArticle(let slug):
            router.pendingLearnSlug = slug
            router.selection = 5
        case .kit(let destination): kit.open(destination)
        case .scan(let target): kit.openScan(target)
        case .dailyLog: return   // presented below, and cleared when it is dismissed
        case .unavailable: break
        }
        route = nil
    }

    private var logDay: Binding<FertilityKitLogDay?> {
        Binding(
            get: {
                if case .dailyLog(let date) = route { return FertilityKitLogDay(date: date) }
                return nil
            },
            set: { if $0 == nil { route = nil } })
    }
}

private struct FertilityKitLogDay: Identifiable {
    let date: CalendarDate
    var id: Int { date.dayNumber }
}
