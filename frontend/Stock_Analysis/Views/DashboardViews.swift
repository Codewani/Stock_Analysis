import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.payload == nil {
                    LoadingStateView(title: "Loading portfolio…")
                } else if let payload = viewModel.payload {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            PortfolioHeroCard(summary: payload.summary, snapshots: payload.snapshots)
                            metrics(summary: payload.summary)
                            holdingsPreview(payload.holdings)
                            latestNewsPreview
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.xs)
                        .padding(.bottom, Spacing.xxxl)
                    }
                    .compatibleRefreshable { await viewModel.load(appState: appState) }
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorStateView(title: "Dashboard unavailable", message: errorMessage) {
                        Task { await viewModel.load(appState: appState) }
                    }
                } else {
                    EmptyStateView(title: "No portfolio yet", message: "Link a broker to see your holdings here.", systemImage: "chart.pie")
                }
            }
            .screenBackground()
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        NotificationCenterView()
                    } label: {
                        Image(systemName: "bell")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .task(id: appState.portfolioRefreshVersion) {
            await viewModel.load(appState: appState)
        }
    }

    private func metrics(summary: PortfolioSummary) -> some View {
        HStack(spacing: Spacing.sm) {
            StatTile(title: "Buying power", value: summary.buyingPower.currencyString, subtitle: "Available to trade")
            StatTile(title: "Day move", value: summary.dayChange.currencyString, subtitle: summary.dayChangePercentage.percentString)
        }
    }

    private func holdingsPreview(_ holdings: [Holding]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Holdings")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                NavigationLink {
                    HoldingsListView(holdings: holdings)
                } label: {
                    seeAllLabel("See all")
                }
            }

            if holdings.isEmpty {
                Card {
                    EmptyStateView(title: "No holdings yet", message: "Link a broker to bring in live positions.", systemImage: "briefcase")
                }
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(holdings.prefix(3).enumerated()), id: \.element.id) { index, holding in
                            NavigationLink {
                                StockDetailView(holding: holding)
                            } label: {
                                HoldingRow(holding: holding)
                                    .padding(Spacing.md)
                            }
                            .buttonStyle(.pressableCard)

                            if index < min(holdings.count, 3) - 1 {
                                rowDivider
                            }
                        }
                    }
                }
            }
        }
    }

    private var latestNewsPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("News")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                NavigationLink {
                    NewsFeedView()
                } label: {
                    seeAllLabel("Open feed")
                }
            }
            ForEach(appState.latestNews.prefix(2)) { story in
                NewsStoryCard(story: story)
            }
        }
    }

    private func seeAllLabel(_ title: String) -> some View {
        HStack(spacing: 2) {
            Text(title)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.brandPrimary)
    }
}

/// Portfolio value card with a scrubbable chart: press and drag across it to
/// inspect the balance at any point in time, Robinhood-style. The headline
/// value and trend pill track whatever point is currently selected, and
/// revert to the latest balance once you lift your finger.
struct PortfolioHeroCard: View {
    let summary: PortfolioSummary
    let snapshots: [PortfolioSnapshot]

    @State private var selection: PricePoint?

    private var chronological: [PricePoint] {
        snapshots
            .sorted { $0.snapshotTimestamp < $1.snapshotTimestamp }
            .map { PricePoint(date: $0.snapshotTimestamp, value: $0.totalBalance) }
    }

    private var baseline: Double? {
        chronological.first?.value
    }

    private var displayedValue: Double {
        selection?.value ?? summary.totalValue
    }

    private var displayedChange: Double {
        guard let selection, let baseline else { return summary.dayChange }
        return selection.value - baseline
    }

    private var displayedChangePercentage: Double {
        guard let selection, let baseline, baseline != 0 else { return summary.dayChangePercentage }
        return (selection.value - baseline) / baseline
    }

    private var trendColor: Color {
        Color.trend(displayedChange)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headerLabel)
                        .font(.microText)
                        .foregroundStyle(Color.textTertiary)
                        .kerning(0.4)
                    Text(displayedValue.currencyString)
                        .font(.heroValue)
                        .monospacedDigit()
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    TrendPill(value: displayedChange, percentage: displayedChangePercentage)
                }

                if chronological.count > 1 {
                    InteractiveAreaChart(points: chronological, color: trendColor, selection: $selection)
                        .frame(height: 140)
                        .padding(.top, Spacing.xs)

                    HStack {
                        Text(chronological.first?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "")
                        Spacer()
                        Text("Today")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: selection)
    }

    private var headerLabel: String {
        guard let selection else { return "PORTFOLIO VALUE" }
        return selection.date.formatted(date: .abbreviated, time: .omitted).uppercased()
    }
}

/// Hairline separator used between rows inside a zero-padding `Card`.
private var rowDivider: some View {
    Rectangle()
        .fill(Color.appBorder)
        .frame(height: 0.5)
        .padding(.leading, Spacing.md + 44 + Spacing.sm)
}

struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack(spacing: Spacing.sm) {
            SymbolAvatar(symbol: holding.symbol, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(holding.symbol)
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Text(holding.companyName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 3) {
                Text(holding.marketValue.currencyString)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                Text(holding.unrealizedPL.currencyString)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.trend(holding.unrealizedPL))
            }
        }
    }
}

struct HoldingsListView: View {
    let holdings: [Holding]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("\(holdings.count) position\(holdings.count == 1 ? "" : "s")")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)

                if holdings.isEmpty {
                    Card {
                        EmptyStateView(title: "No holdings", message: "Link a broker to bring in live positions.", systemImage: "briefcase")
                    }
                } else {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(holdings.enumerated()), id: \.element.id) { index, holding in
                                NavigationLink {
                                    StockDetailView(holding: holding)
                                } label: {
                                    HoldingRow(holding: holding)
                                        .padding(Spacing.md)
                                }
                                .buttonStyle(.pressableCard)

                                if index < holdings.count - 1 {
                                    rowDivider
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .screenBackground()
        .navigationTitle("Holdings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StockDetailView: View {
    @EnvironmentObject private var appState: AppState
    let holding: Holding

    @State private var range: ChartRange = .oneMonth
    @State private var relatedNews: [NewsStory] = []
    @State private var chartSelection: PricePoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                chartCard
                positionCard
                newsSection
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .screenBackground()
        .navigationTitle(holding.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard relatedNews.isEmpty else { return }
            relatedNews = appState.portfolioService.stockDetail(for: holding).relatedNews
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                SymbolAvatar(symbol: holding.symbol, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text(holding.companyName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            Text(displayedPrice.currencyString)
                .font(.heroValue)
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
            TrendPill(value: displayedChange, percentage: displayedChangePercentage)
        }
        .animation(.easeOut(duration: 0.12), value: chartSelection)
    }

    private var displayedPrice: Double {
        chartSelection?.value ?? holding.currentPrice
    }

    private var displayedChange: Double {
        guard let chartSelection, let baseline = syntheticHistory.first?.value else {
            return holding.unrealizedPL
        }
        return chartSelection.value - baseline
    }

    private var displayedChangePercentage: Double {
        guard let chartSelection, let baseline = syntheticHistory.first?.value, baseline != 0 else {
            return holding.unrealizedPLPercent
        }
        return (chartSelection.value - baseline) / baseline
    }

    private var chartCard: some View {
        let points = syntheticHistory
        let trendColor = Color.trend((points.last?.value ?? 0) - (points.first?.value ?? 0))

        return Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                InteractiveAreaChart(points: points, color: trendColor, selection: $chartSelection)
                    .frame(height: 200)

                RangeSelector(selection: $range)
            }
        }
    }

    private var syntheticHistory: [PricePoint] {
        let values = deterministicSeries(
            seed: holding.symbol + range.rawValue,
            count: range.pointCount,
            base: holding.currentPrice,
            volatility: 0.018
        )
        let now = Date()
        let calendar = Calendar.current
        return values.enumerated().map { index, value in
            let daysAgo = values.count - 1 - index
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return PricePoint(date: date, value: value)
        }
    }

    private var positionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Position")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: Spacing.sm) {
                    StatTile(
                        title: "Shares",
                        value: holding.shares.formatted(.number.precision(.fractionLength(0...2))),
                        subtitle: "Avg cost \(holding.averageCost.currencyString)"
                    )
                    StatTile(
                        title: "Market value",
                        value: holding.marketValue.currencyString,
                        subtitle: "\(holding.unrealizedPL >= 0 ? "+" : "")\(holding.unrealizedPL.currencyString) total"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var newsSection: some View {
        if !relatedNews.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Related news")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                ForEach(relatedNews) { story in
                    NewsStoryCard(story: story)
                }
            }
        }
    }
}

struct NotificationCenterView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            if appState.notifications.isEmpty {
                EmptyStateView(
                    title: "No notifications",
                    message: "Updates about your portfolio and watchlist will show up here.",
                    systemImage: "bell.slash"
                )
                .padding(.top, Spacing.xxxl)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(appState.notifications) { item in
                        notificationRow(item)
                    }
                }
                .padding(Spacing.lg)
            }
        }
        .screenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    Circle().fill(categoryColor(item.category).opacity(0.14)).frame(width: 36, height: 36)
                    Image(systemName: categoryIcon(item.category))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(categoryColor(item.category))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    Text(item.createdAt.relativeString)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer(minLength: 0)
                if !item.isRead {
                    Circle().fill(Color.brandPrimary).frame(width: 8, height: 8)
                }
            }
        }
    }

    private func categoryIcon(_ category: NotificationCategory) -> String {
        switch category {
        case .system: return "gearshape.fill"
        case .portfolio: return "chart.pie.fill"
        case .news: return "newspaper.fill"
        }
    }

    private func categoryColor(_ category: NotificationCategory) -> Color {
        switch category {
        case .system: return .textSecondary
        case .portfolio: return .brandPrimary
        case .news: return .warning
        }
    }
}
