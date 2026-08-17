import SwiftUI
import GenesyxCore
#if canImport(UIKit)
import UIKit
#endif

/// Shared tab selection so an article CTA can jump into another tab (reuse, not stack).
@MainActor
final class TabRouter: ObservableObject {
    @Published var selection: Int
    /// Set by a Learn notification tap; consumed by `LearnLandingView`, which pushes the article.
    @Published var pendingLearnSlug: String?
    /// Set by the Home hydration card tap; consumed by `TrackView`, which opens the hydration detail.
    @Published var pendingHydration = false
    init(selection: Int = 0) { self.selection = selection }
}

private let learnShareRoot = "https://genesyx.co.uk"

// MARK: - Hero image (with category-gradient fallback)

struct LearnHero: View {
    let article: LearnArticle
    var height: CGFloat = 180

    private var assetExists: Bool {
        guard let name = article.heroImage else { return false }
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return true
        #endif
    }

    var body: some View {
        Group {
            if assetExists, let name = article.heroImage {
                Image(name).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [article.category.tint.opacity(0.55), article.category.tint.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(Image(systemName: "book").font(.system(size: 26)).foregroundStyle(.white.opacity(0.85)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

// MARK: - Learn landing (tab root)

struct LearnLandingView: View {
    @EnvironmentObject private var router: TabRouter
    @AppStorage("learn_intro_seen") private var introSeen = false
    @State private var path: [String] = []
    @State private var showSearch = false
    @State private var selectedCategory: LearnCategory?
    @State private var showGuide = false

    private var rows: [LearnArticle] {
        if let cat = selectedCategory {
            return LearnLibrary.articles.filter { $0.category == cat }
        }
        // Unfiltered: featured is shown as the hero, the rest as rows.
        return LearnLibrary.articles.filter { !$0.featured }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if !introSeen { introHint }
                    HowToUseCard { path.append(HowToUseView.route) }
                    TwelveWeekPlanCard { path.append(TwelveWeekPlan.route) }
                    categoryChips
                    if selectedCategory == nil, let featured = LearnLibrary.featured {
                        FeaturedCard(article: featured) { path.append(featured.slug) }
                    }
                    if selectedCategory == .guides {
                        GuideBookRow { showGuide = true }
                    }
                    ForEach(rows) { a in
                        ArticleRow(article: a) { path.append(a.slug) }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .gxPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                        .tint(GenesyxColor.foreground)
                }
            }
            .navigationDestination(for: String.self) { slug in
                if slug == TwelveWeekPlan.route {
                    TwelveWeekPlanView(path: $path)
                } else if slug == HowToUseView.route {
                    HowToUseView { path.append($0) }
                } else {
                    ArticleDetailView(slug: slug, path: $path)
                }
            }
            .sheet(isPresented: $showSearch) {
                LearnSearchView { slug in
                    showSearch = false
                    path.append(slug)
                }
            }
            .sheet(isPresented: $showGuide) {
                FreeGuideScreen()
            }
            .onChange(of: router.pendingLearnSlug) { slug in
                guard let slug else { return }
                path.append(slug)
                router.pendingLearnSlug = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Learn").font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
            Text("Short, honest reads on tracking, nutrition, and making sense of your own data.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var introHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 16)).foregroundStyle(GenesyxColor.primary)
                .frame(width: 36, height: 36).background(GenesyxColor.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("New here?").font(.gxBodySmall.weight(.semibold)).foregroundStyle(GenesyxColor.foreground)
                Text("Start with \u{201C}Your first week with Genesyx.\u{201D}")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            }
            Spacer()
            Button { withAnimation { introSeen = true } } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(GenesyxColor.mutedForeground)
            }
        }
        .padding(14)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture { introSeen = true; path.append("getting-started-first-week") }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LearnCategory.allCases) { cat in
                    let sel = selectedCategory == cat
                    Text(cat.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(sel ? .white : GenesyxColor.foreground.opacity(0.8))
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(sel ? GenesyxColor.primary : GenesyxColor.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(sel ? .clear : GenesyxColor.border, lineWidth: 1))
                        .onTapGesture { selectedCategory = sel ? nil : cat }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - 12-week plan

/// Not a `LearnArticle`. The library is a counted, cited, date-gated set; this page is the
/// contents list for that set. Putting it in `learnArticles` would bump the 32-article
/// integrity count and register opening the plan as having read a weekly piece.
enum TwelveWeekPlan {
    static let route = "twelve-week-plan"
}

private struct TwelveWeekPlanCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "list.number")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(GenesyxColor.primary)
                    .frame(width: 44, height: 44)
                    .background(GenesyxColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start your 12-week plan here")
                        .font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                    Text("One new article each week. Read them as they arrive.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(14)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn.twelveWeekPlan")
    }
}

private struct TwelveWeekPlanView: View {
    @Binding var path: [String]

    private static let months = [
        "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your 12-week plan")
                        .font(.gxDisplayLarge).foregroundStyle(GenesyxColor.foreground)
                    Text("A short, honest article each Sunday. Open a week when it arrives, or come back and pick up where you left off.")
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                }
                ForEach(Array(LearnLibrary.weeklySeries.enumerated()), id: \.element.id) { index, article in
                    weekRow(week: index + 1, article: article)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("learn.twelveWeekPlan.screen")
    }

    private func weekRow(week: Int, article: LearnArticle) -> some View {
        let available = LearnLibrary.articleBySlug(article.slug) != nil
        return Button {
            if available { path.append(article.slug) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(week)")
                    .font(.gxLabel).foregroundStyle(GenesyxColor.primary)
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                    Text(available ? "Ready to read" : arrivesLabel(article.publishedAt))
                        .font(.system(size: 12)).foregroundStyle(GenesyxColor.mutedForeground)
                }
                Spacer(minLength: 8)
                if available {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
                }
            }
            .padding(14)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityIdentifier("learn.twelveWeekPlan.week.\(week)")
        .accessibilityLabel("Week \(week), \(article.title), \(available ? "ready to read" : arrivesLabel(article.publishedAt))")
    }

    private func arrivesLabel(_ date: CalendarDate?) -> String {
        guard let date else { return "Coming soon" }
        let month = date.month >= 1 && date.month <= 12 ? Self.months[date.month] : ""
        return "Arrives \(date.day) \(month)"
    }
}

// MARK: - Cards / rows

private struct FeaturedCard: View {
    let article: LearnArticle
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                LearnHero(article: article, height: 180)
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(article.category.label, color: GenesyxColor.primary)
                    Text(article.title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                    Text(article.excerpt).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                    Text(article.readingTime).font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground).padding(.top, 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

/// The bundled PDF guide, sitting alongside the written guides. Deliberately *not* a
/// `LearnArticle`: the library is a fixed, counted set with publication dates, sources and
/// disclaimers, and a PDF has none of those. Keeping it out also keeps it out of `markRead`, so
/// opening it cannot be mistaken for having read the ten written guides.
private struct GuideBookRow: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 24)).foregroundStyle(GenesyxColor.primary)
                    .frame(width: 96, height: 72)
                    .background(GenesyxColor.primary.tintOnWhite(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(FreeGuide.title).font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading).lineLimit(2)
                    Text("PDF guide").font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(10)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn.guideBook")
    }
}

// MARK: - How to use Genesyx

/// The table of contents for the app's own how-to guides.
///
/// Grouped by tab because the question this answers is *"what is this screen for?"* — asked while
/// looking at the screen. An alphabetical or chronological list would require her to already know
/// what the feature is called, which is the thing she is trying to find out.
struct HowToUseView: View {
    /// Pushed onto the same `[String]` path the articles use, so it must not collide with a slug.
    /// `AppGuideTests` asserts it doesn't.
    static let route = "how-to-use-genesyx"

    let onOpen: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Every part of the app, and what it is for. Start anywhere — nothing here has to be read in order.")
                    .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(AppGuide.byTab, id: \.tab) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.tab.uppercased())
                            .font(.gxEyebrow).foregroundStyle(GenesyxColor.primary)
                        // Resolved through `LearnLibrary`, so a guide that is not published simply
                        // does not appear. A row that opens an "unavailable" screen would be worse
                        // than a missing row: it looks like a broken app rather than a shorter list.
                        ForEach(group.entries) { entry in
                            if let article = LearnLibrary.articleBySlug(entry.slug) {
                                AppGuideRow(entry: entry, article: article) { onOpen(entry.slug) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle("How to use Genesyx")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppGuideRow: View {
    let entry: AppGuideEntry
    let article: LearnArticle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title).font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                    Text(entry.purpose).font(.system(size: 12)).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(12)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

/// The entry point on the Learn tab. Given its own card rather than folded into the category chips
/// because "I don't know how this app works" is a different need from "I want to read something".
struct HowToUseCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 24)).foregroundStyle(GenesyxColor.primary)
                    .frame(width: 96, height: 72)
                    .background(GenesyxColor.primary.tintOnWhite(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("How to use Genesyx").font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                    Text("Every feature, and what it is for")
                        .font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(10)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn.howToUse")
    }
}

/// The "How this works" signpost a tab carries at the foot of its own screen.
///
/// One type rather than a hand-rolled button per tab: the deep link is two coupled statements
/// (`pendingLearnSlug`, then `selection`) and getting only the first right lands her on the Learn
/// list with no explanation of why she is there. Written once, it cannot be half-written elsewhere.
struct HowThisWorksLink: View {
    @EnvironmentObject private var router: TabRouter
    let slug: String
    var label = "How this works"

    var body: some View {
        Button {
            router.pendingLearnSlug = slug
            router.selection = 5
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle").font(.system(size: 13, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(GenesyxColor.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct ArticleRow: View {
    let article: LearnArticle
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                LearnHero(article: article, height: 72)
                    .frame(width: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title).font(.gxLabel).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading).lineLimit(2)
                    Text(article.readingTime).font(.system(size: 11.5)).foregroundStyle(GenesyxColor.mutedForeground)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(10)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search

struct LearnSearchView: View {
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [LearnArticle] { LearnLibrary.search(query) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                if !isSearching {
                    emptyState(icon: "magnifyingglass", title: "Search the library",
                               message: "Find articles by title, topic, or tag.")
                } else if results.isEmpty {
                    emptyState(icon: "doc.text.magnifyingglass", title: "No results",
                               message: "Nothing matched \u{201C}\(query)\u{201D}. Try a different word.")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(results) { a in
                                ArticleRow(article: a) { onOpen(a.slug) }
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                    }
                }
            }
            .background(GenesyxColor.background)
            .navigationTitle("Search").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onAppear { focused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(GenesyxColor.mutedForeground)
            TextField("Search articles", text: $query)
                .focused($focused).autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(GenesyxColor.mutedForeground) }
            }
        }
        .padding(.horizontal, 14).frame(height: 48)
        .background(GenesyxColor.card).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(GenesyxColor.border, lineWidth: 1))
        .padding(.horizontal, 20).padding(.top, 12)
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(GenesyxColor.mutedForeground)
            Text(title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            Text(message).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 40).padding(.top, 80)
    }
}

// MARK: - Article detail

struct ArticleDetailView: View {
    let slug: String
    @Binding var path: [String]

    @EnvironmentObject private var tabs: TabRouter
    @EnvironmentObject private var learn: LearnProgress
    @State private var showLog = false

    var body: some View {
        if let article = LearnLibrary.articleBySlug(slug) {
            // Remembered so a Learn nudge never offers her something she has already read — and so
            // the tab badge and the Home card drop it the moment she opens it.
            content(article).onAppear { learn.markRead(slug) }
        } else {
            unavailable
        }
    }

    private func content(_ article: LearnArticle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LearnHero(article: article, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Eyebrow("\(article.category.label) · \(article.readingTime)", color: GenesyxColor.primary)
                Text(article.title).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)

                ForEach(Array(article.body.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }

                if let sourceIDs = LearnSourceMap.sources(for: article.slug) {
                    SourcesFooter(sourceIDs: sourceIDs)
                }

                if let cta = article.cta { ctaButton(cta) }

                if article.disclaimerRequired {
                    Text(MEDICAL_DISCLAIMER)
                        .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GenesyxColor.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.top, 6)
                }

                relatedSection(article)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(GenesyxColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(article.title)\n\n\(article.excerpt)\n\n\(learnShareRoot)") {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(GenesyxColor.foreground)
            }
        }
        .sheet(isPresented: $showLog) { LogView() }
    }

    @ViewBuilder
    private func blockView(_ block: ArticleBlock) -> some View {
        switch block {
        case .heading(let t):
            Text(t).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground).padding(.top, 6)
        case .paragraph(let t):
            Text(t).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(GenesyxColor.primary).frame(width: 5, height: 5).padding(.top, 8)
                        Text(item).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
                    }
                }
            }
        case .callout(let t):
            Text(t)
                .font(.gxBody.italic()).foregroundStyle(GenesyxColor.foreground.opacity(0.9))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GenesyxColor.primary.opacity(0.08))
                .overlay(Rectangle().fill(GenesyxColor.primary).frame(width: 3), alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func ctaButton(_ cta: ArticleCta) -> some View {
        GxPrimaryButton(title: cta.label) {
            switch cta.type {
            case .openLog: showLog = true
            case .openTrack: tabs.selection = 1
            case .openPh: tabs.selection = 2
            case .openNutrition: tabs.selection = 3
            case .openInsights: tabs.selection = 4
            case .openArticle:
                if let target = cta.targetSlug, !path.isEmpty { path[path.count - 1] = target }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func relatedSection(_ article: LearnArticle) -> some View {
        let related = LearnLibrary.related(article)
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Related").font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground).padding(.top, 8)
                ForEach(related) { r in
                    // Related taps REPLACE the current article (one back press for a chain).
                    ArticleRow(article: r) {
                        if !path.isEmpty { path[path.count - 1] = r.slug } else { path.append(r.slug) }
                    }
                }
            }
        }
    }

    private var unavailable: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.questionmark").font(.system(size: 32)).foregroundStyle(GenesyxColor.mutedForeground)
            Text("That article isn't available").font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            Text("It may have moved or been removed.").font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
            GxGhostButton(title: "Back to Learn") { path.removeAll() }.padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(GenesyxColor.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}
