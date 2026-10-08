import GenesyxCore
import SwiftUI

/// Programme Reviews: how the programme is going in figures, the 90-Day Review once it exists and
/// one row for each weekly review that is ready. Every figure is put into words by core.
struct ProgrammeReviewsView: View {
    @Environment(\.fertilityKit) private var kit

    init() {}

    var body: some View {
        let consent = kit.planInput.consentActive
        let started = kit.planInput.state.startedOn != nil
        // Computed once. With consent withdrawn there is nothing to work out.
        let figures = consent && started ? ProgrammeReviewPresentation.consistency(in: kit) : .init()
        let listing = consent && started ? ProgrammeReviewPresentation.listing(in: kit) : .init()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ConsentWithdrawnBanner()
                if consent {
                    if !started {
                        KitLine(ProgrammeReviewScreenCopy.notStarted, muted: true)
                            .accessibilityIdentifier("kit.reviews.empty")
                    } else {
                        if !figures.isEmpty { consistencyCard(figures) }
                        if listing.hasNinetyDay { ninetyDay(listing) }
                        if listing.hasWeeklySection { weekly(listing) }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.reviews")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.programmeReviews)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func consistencyCard(_ figures: ProgrammeReviewPresentation.Consistency) -> some View {
        KitCard(identifier: "kit.reviews.consistency") {
            KitSectionTitle(ProgrammeReviewCopy.consistencyTitle)
            ForEach(figures.overall, id: \.identifier) { figure in figureRow(figure) }
            if !figures.activities.isEmpty {
                KitSectionTitle(ProgrammeReviewScreenCopy.byActivity)
                ForEach(figures.activities, id: \.identifier) { figure in figureRow(figure) }
            }
        }
    }

    private func figureRow(_ figure: ProgrammeReviewPresentation.Figure) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(figure.title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(figure.lines.enumerated()), id: \.offset) { _, line in KitLine(line, muted: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kitRow(figure.identifier, label: FertilityKitCopy.sentences([figure.title] + figure.lines))
    }

    private func ninetyDay(_ listing: ProgrammeReviewPresentation.Listing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if listing.ninetyDayAvailable {
                KitRow(icon: "flag.checkered", title: ProgrammeReviewCopy.ninetyDayTitle,
                       detail: listing.ninetyDayDates, identifier: "kit.reviews.ninetyDay") {
                    kit.open(.kitNinetyDayReview)
                }
            }
            if let note = listing.ninetyDayNote {
                KitNote(note).accessibilityIdentifier("kit.reviews.ninetyDayNote")
            }
        }
    }

    private func weekly(_ listing: ProgrammeReviewPresentation.Listing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KitSectionTitle(ProgrammeReviewScreenCopy.weeklyHeading)
            if let next = listing.nextReview {
                KitLine(next, muted: true).accessibilityIdentifier("kit.reviews.next")
            }
            if listing.noReviewsYet {
                KitLine(ProgrammeReviewScreenCopy.noReviewsYet, muted: true)
                    .accessibilityIdentifier("kit.reviews.noneYet")
            }
            ForEach(listing.weeks, id: \.number) { week in
                KitRow(icon: "calendar", title: week.title, detail: week.dates,
                       identifier: "kit.reviews.week.\(week.number)") {
                    kit.openWeeklyReview(week.number)
                }
            }
        }
    }
}

/// What the Programme Reviews list shows, worked out from the context alone. The screens print
/// it and count nothing themselves. The other two review screens use it for the parts they share.
enum ProgrammeReviewPresentation {

    /// A figure under its name: one row of the consistency card.
    struct Figure: Equatable {
        let identifier: String
        let title: String
        let lines: [String]
    }

    struct Consistency: Equatable {
        /// Programme so far, each phase, and the last thirty days when that is true.
        var overall: [Figure] = []
        /// One for each activity that has a figure and a name. Never ranked.
        var activities: [Figure] = []

        var isEmpty: Bool { overall.isEmpty && activities.isEmpty }
    }

    struct Week: Equatable {
        let number: Int
        let title: String
        let dates: String
    }

    struct Listing: Equatable {
        /// Newest first.
        var weeks: [Week] = []
        var nextReview: String?
        var noReviewsYet = false
        var ninetyDayAvailable = false
        var ninetyDayDates: String?
        var ninetyDayNote: String?

        var hasNinetyDay: Bool { ninetyDayAvailable || ninetyDayNote != nil }
        var hasWeeklySection: Bool { !weeks.isEmpty || nextReview != nil || noReviewsYet }
    }

    /// From day 31 to day 91. Before day 31 the thirty days are not all programme days, and from
    /// day 92 the figure is built from days that ended more than a day ago, so "Last 30 days"
    /// would not be true of either.
    static func showsLastThirtyDays(day: Int) -> Bool {
        (31...ProgrammeCalendar.totalDays + 1).contains(day)
    }

    static func consistency(in kit: FertilityKitContext, content: ProgrammeContent = .draft) -> Consistency {
        guard let start = kit.planInput.state.startedOn else { return Consistency() }
        let day = ProgrammeCalendar.dayNumber(on: kit.today, startedOn: start)
        return consistency(report: kit.report(), day: day, content: content)
    }

    /// `day` is today's programme day, not held to 1 to 90.
    static func consistency(report: ProgrammeConsistencyReport, day: Int,
                            content: ProgrammeContent = .draft) -> Consistency {
        var result = Consistency()
        func add(_ identifier: String, _ title: String, _ figure: ProgrammeConsistencyFigure) {
            let lines = ProgrammeReviewLogic.lines(for: figure)
            if !lines.isEmpty { result.overall.append(Figure(identifier: identifier, title: title, lines: lines)) }
        }
        add("kit.reviews.consistency.programme", ProgrammeReviewScreenCopy.consistencySoFar, report.programme)
        for phase in ProgrammePhase.allCases {
            guard let title = content.phaseTitles[phase], let figure = report.phases[phase] else { continue }
            add("kit.reviews.consistency.phase.\(phase.rawValue)", title, figure)
        }
        if showsLastThirtyDays(day: day) {
            add("kit.reviews.consistency.last30", ProgrammeReviewScreenCopy.lastThirtyDays, report.trailing30Days)
        }
        for category in ProgrammeTaskCategory.allCases where category != .nutritionCheckIn {
            guard let figure = report.categories[category],
                  let name = ProgrammeReviewCopy.routineName(for: category) else { continue }
            let lines = ProgrammeReviewLogic.lines(for: figure)
            if !lines.isEmpty {
                result.activities.append(Figure(identifier: "kit.reviews.consistency.activity.\(category.rawValue)",
                                                title: name, lines: [ProgrammeReviewCopy.onOneLine(lines)]))
            }
        }
        return result
    }

    static func listing(in kit: FertilityKitContext) -> Listing {
        let state = kit.planInput.state
        guard let start = state.startedOn else { return Listing() }
        func date(_ day: Int) -> CalendarDate { ProgrammeCalendar.date(ofDay: day, startedOn: start) }
        /// A review that would come after the day she stopped never comes.
        func comes(after last: CalendarDate) -> Bool { state.stoppedOn.map { last < $0 } ?? true }

        var listing = Listing()
        listing.weeks = ProgrammeReviewLogic.availableWeeks(state: state, today: kit.today).reversed().map { week in
            let days = ProgrammeCalendar.dayRange(ofWeek: week)
            return Week(number: week, title: ProgrammeReviewScreenCopy.weekRow(week),
                        dates: FertilityKitDates.range(date(days.lowerBound), date(days.upperBound)))
        }
        listing.ninetyDayAvailable = kit.isNinetyDayReviewAvailable
        if listing.ninetyDayAvailable {
            listing.ninetyDayDates = FertilityKitDates.range(start, date(ProgrammeCalendar.totalDays))
        }
        switch kit.position {
        case .active(_, let week, _):
            let lastOfWeek = date(ProgrammeCalendar.dayRange(ofWeek: week).upperBound)
            if comes(after: lastOfWeek) {
                let ready = lastOfWeek.plusDays(1)
                listing.nextReview = ready == kit.today.plusDays(1)
                    ? ProgrammeReviewScreenCopy.nextReviewReadyTomorrow(week)
                    : ProgrammeReviewScreenCopy.nextReviewReady(week, FertilityKitDates.dayMonth(ready))
            }
            let lastDay = date(ProgrammeCalendar.totalDays)
            if comes(after: lastDay) {
                listing.ninetyDayNote = ProgrammeReviewScreenCopy.ninetyDayReady(
                    FertilityKitDates.dayMonth(lastDay.plusDays(1)))
            }
        case .beforeStart:
            listing.noReviewsYet = listing.weeks.isEmpty
        case .notStarted, .completed, .stopped:
            break
        }
        return listing
    }

    /// What the 90-Day Review says in place of the review: when it will be ready, or that it is
    /// not available.
    static func ninetyDayUnavailable(in kit: FertilityKitContext) -> String {
        listing(in: kit).ninetyDayNote ?? ProgrammeReviewScreenCopy.notAvailable
    }

    /// The tracked counts of a review that belong under "Body check-ins" in the 90-Day Review.
    static let bodyKinds: Set<ProgrammeReviewCount.Kind> = [.moodCheckIns, .energyCheckIns, .symptomDays]

    /// The statements, and the still-learning sentence beside them. No statement and not learning:
    /// no section.
    static func showsPatterns(_ review: ProgrammeNinetyDayReview) -> Bool {
        !review.patterns.isEmpty || review.isStillLearning
    }

    /// A review that exists is the only one that is recorded as viewed.
    @MainActor
    static func markViewed(_ review: ProgrammeWeeklyReview?, in programme: ProgrammeRepository) {
        if let review { programme.markWeeklyReviewViewed(week: review.week) }
    }

    @MainActor
    static func markViewed(_ review: ProgrammeNinetyDayReview?, in programme: ProgrammeRepository) {
        if review != nil { programme.markNinetyDayReviewViewed() }
    }
}

#if DEBUG
#Preview("Day 40") {
    ProgrammeReviewsView().withKitPreview(day: 40)
}
#endif
