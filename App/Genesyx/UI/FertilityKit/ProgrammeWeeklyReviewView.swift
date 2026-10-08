import GenesyxCore
import SwiftUI

/// The review of one programme week that has ended. It prints what core hands it, in the order of
/// the brief, and counts nothing. Built only by More, inside the kit host.
struct ProgrammeWeeklyReviewView: View {
    private let week: Int

    @Environment(\.fertilityKit) private var kit
    @EnvironmentObject private var programme: ProgrammeRepository
    @State private var route: FertilityKitRoute?

    init(week: Int) {
        self.week = week
    }

    var body: some View {
        let review = ProgrammeReviewLogic.weekly(week: week, input: kit.reviewInput())
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let review {
                    header(review)
                    consistency(review)
                    if !review.tracked.isEmpty {
                        KitCard {
                            KitSectionTitle(ProgrammeReviewCopy.trackedTitle)
                            ProgrammeReviewTrackedList(counts: review.tracked, identifier: "kit.review.week.tracked",
                                                       route: $route)
                        }
                    }
                    noticed(review)
                    if let strongest = review.strongestRoutine {
                        KitCard {
                            KitSectionTitle(ProgrammeReviewCopy.strongestRoutineTitle)
                            KitLines([strongest.name, strongest.text], identifier: "kit.review.week.strongest")
                        }
                    }
                    if let next = review.nextFocus { nextFocus(next) }
                } else {
                    KitLine(ProgrammeReviewScreenCopy.notAvailable, muted: true)
                        .accessibilityIdentifier("kit.review.week.notAvailable")
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.review.week")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.weeklyReview)
        .navigationBarTitleDisplayMode(.inline)
        .fertilityKitRoute($route)
        .onAppear { ProgrammeReviewPresentation.markViewed(review, in: programme) }
    }

    private func header(_ review: ProgrammeWeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(review.headline).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("kit.review.week.headline")
            let place = [review.phaseTitle, review.themeTitle].compactMap { $0 }
            if !place.isEmpty { KitLine(FertilityKitCopy.dotJoined(place)) }
            KitLine(FertilityKitDates.range(review.firstDate, review.lastDate), muted: true)
        }
    }

    @ViewBuilder
    private func consistency(_ review: ProgrammeWeeklyReview) -> some View {
        if !review.consistencyLines.isEmpty || review.supportLine != nil {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.consistencyTitle)
                if !review.consistencyLines.isEmpty {
                    KitLines(review.consistencyLines, identifier: "kit.review.week.consistency")
                }
                if let support = review.supportLine {
                    KitLine(support).accessibilityIdentifier("kit.review.week.support")
                }
            }
        }
    }

    /// Either what was noticed or that nothing can be said yet: never both, never neither.
    private func noticed(_ review: ProgrammeWeeklyReview) -> some View {
        KitCard {
            KitSectionTitle(ProgrammeReviewCopy.noticedTitle)
            if review.isStillLearning {
                KitLine(ProgrammeEvidenceCopy.stillLearning).accessibilityIdentifier("kit.review.week.stillLearning")
            } else {
                ForEach(Array(review.noticed.enumerated()), id: \.offset) { index, statement in
                    KitLine(statement.text).accessibilityIdentifier("kit.review.week.noticed.\(index)")
                }
            }
        }
    }

    private func nextFocus(_ focus: ProgrammeReviewNextFocus) -> some View {
        KitCard {
            KitSectionTitle(ProgrammeReviewCopy.nextFocusTitle)
            VStack(alignment: .leading, spacing: 6) {
                Text(focus.themeTitle).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                KitLine(focus.purpose)
                KitLine(focus.nutritionFocusTitle, muted: true)
                ForEach(Array(focus.leadingActivities.enumerated()), id: \.offset) { _, name in
                    KitLine(name, muted: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kitRow("kit.review.week.nextFocus",
                    label: FertilityKitCopy.sentences(
                        [focus.themeTitle, focus.purpose, focus.nutritionFocusTitle] + focus.leadingActivities))
        }
    }
}

/// The counts of a review, one row each: the text core wrote, and a way to the place where that
/// record is made unless there is no such place in this build. Shared by the weekly and the
/// 90-Day Review.
struct ProgrammeReviewTrackedList: View {
    let counts: [ProgrammeReviewCount]
    /// The start of every row's identifier; the row's kind follows.
    let identifier: String
    @Binding var route: FertilityKitRoute?

    @Environment(\.fertilityKit) private var kit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(counts) { count in
                let target = FertilityKitRoutes.route(for: count.destination, in: kit)
                if target == .unavailable {
                    KitLine(count.text)
                        .padding(.vertical, 8)
                        .kitRow("\(identifier).\(count.kind.rawValue)", label: count.text)
                } else {
                    Button { route = target } label: {
                        HStack(spacing: 8) {
                            KitLine(count.text)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(GenesyxColor.mutedForeground)
                        }
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .kitRow("\(identifier).\(count.kind.rawValue)", label: count.text)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Week 3") {
    ProgrammeWeeklyReviewView(week: 3).withKitPreview(day: 40)
}
#endif
