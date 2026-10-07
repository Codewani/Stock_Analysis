import SwiftUI
#if os(iOS)
import UIKit
#endif

private func hideKeyboard() {
#if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
}

// MARK: - Shared news card

struct NewsStoryCard: View {
    let story: NewsStory

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    HStack(spacing: 6) {
                        SymbolAvatar(symbol: story.symbol, size: 26)
                        Text(story.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    Badge(text: "AI \(story.importanceScore)", tint: story.sentiment.tint)
                }

                Text(story.headline)
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(story.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    Text(story.source)
                    Text("•")
                    Text(story.publishedAt.relativeString)
                    Spacer()
                    Text(story.sentiment.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(story.sentiment.tint)
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)

                if let url = story.url {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Read source")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Watchlist

struct WatchlistView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WatchlistViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    addSymbolCard
                    watchlistContent
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .compatibleRefreshable { await viewModel.load(appState: appState) }
            .screenBackground()
            .navigationTitle("Watchlist")
        }
        .task {
            guard viewModel.items.isEmpty else { return }
            await viewModel.load(appState: appState)
        }
    }

    private var addSymbolCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Add a symbol")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: Spacing.sm) {
                    AppTextField(title: "e.g. AAPL", text: $viewModel.symbolDraft, icon: "magnifyingglass", autocapitalizeCharacters: true)
                    Button {
                        Task { await viewModel.add(appState: appState) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.appIcon)
                    .disabled(viewModel.symbolDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var watchlistContent: some View {
        if viewModel.items.isEmpty && !viewModel.isLoading {
            EmptyStateView(title: "Your watchlist is empty", message: "Add a ticker above to start tracking it.", systemImage: "star")
        } else {
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        watchlistRow(item)
                        if index < viewModel.items.count - 1 {
                            Rectangle()
                                .fill(Color.appBorder)
                                .frame(height: 0.5)
                                .padding(.leading, Spacing.md + 44 + Spacing.sm)
                        }
                    }
                }
            }
        }
    }

    private func watchlistRow(_ item: WatchlistSymbol) -> some View {
        let series = deterministicSeries(seed: item.symbol, count: 20, base: 100)
        let trendColor = Color.trend((series.last ?? 0) - (series.first ?? 0))

        return HStack(spacing: Spacing.sm) {
            SymbolAvatar(symbol: item.symbol, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.symbol)
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Text(item.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "Recently added")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Sparkline(values: series, color: trendColor)
                .frame(width: 60, height: 28)
            Button {
                Task { await viewModel.remove(symbol: item.symbol, appState: appState) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(Color.appSurfaceSecondary, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
    }
}

// MARK: - News feed

struct NewsFeedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(appState.latestNews) { story in
                        NewsStoryCard(story: story)
                    }
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .compatibleRefreshable {
                appState.simulateNewsEvent()
            }
            .screenBackground()
            .navigationTitle("News Feed")
        }
    }
}

// MARK: - Broker integrations

struct BrokerIntegrationsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = BrokersViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var isBrokerageListDismissed = false
    @State private var searchCardFrame: CGRect = .zero
    private let scrollCoordinateSpace = "brokerScroll"

    private var groupedBrokerAccounts: [(institution: String, accounts: [BrokerAccount])] {
        guard let payload = dashboardViewModel.payload else { return [] }
        let grouped = Dictionary(grouping: payload.accounts) { account in
            account.institution.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return grouped
            .map { key, value in (institution: key, accounts: value) }
            .sorted { $0.institution.localizedCaseInsensitiveCompare($1.institution) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    searchCard
                    connectCard
                    linkedAccountsSection
                }
                .padding(Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .coordinateSpace(name: scrollCoordinateSpace)
            // Tapping anywhere in the scroll area outside the whole search card
            // (search bar + results list together) collapses the results list.
            // Row buttons still fire their own action since this is `simultaneous`,
            // not exclusive — but excluding the card's own frame means selecting a
            // brokerage no longer races with this gesture to instantly collapse it.
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    guard !searchCardFrame.contains(value.location) else { return }
                    guard !isBrokerageListDismissed else { return }
                    isBrokerageListDismissed = true
                    hideKeyboard()
                }
            )
            .screenBackground()
            .navigationTitle("Brokers")
        }
        .task {
            await viewModel.loadBrokerages(appState: appState)
            guard dashboardViewModel.payload == nil else { return }
            await dashboardViewModel.load(appState: appState)
        }
        .onChange(of: viewModel.searchText) { _, _ in
            isBrokerageListDismissed = false
        }
        .onChange(of: viewModel.portalURL) { _, newValue in
            guard let newValue, let url = URL(string: newValue) else { return }
            openURL(url)
        }
    }

    private var searchCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Find a brokerage")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                AppTextField(
                    title: "Search brokerages",
                    text: $viewModel.searchText,
                    icon: "magnifyingglass",
                    autocapitalizationDisabled: true,
                    onFocusChange: { focused in
                        if focused {
                            isBrokerageListDismissed = false
                        }
                    }
                )

                if !isBrokerageListDismissed {
                    if viewModel.isLoadingBrokerages && viewModel.brokerages.isEmpty {
                        LoadingStateView(title: "Loading broker directory")
                            .frame(height: 120)
                    } else if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EmptyStateView(
                            title: "Search for a brokerage",
                            message: "Start typing to find supported brokerages and connect one.",
                            systemImage: "magnifyingglass"
                        )
                    } else if viewModel.filteredBrokerages.isEmpty {
                        EmptyStateView(
                            title: "No brokerages found",
                            message: "Try another brokerage name or slug.",
                            systemImage: "building.columns"
                        )
                    } else {
                        VStack(spacing: Spacing.xs) {
                            ForEach(viewModel.filteredBrokerages.prefix(12)) { brokerage in
                                brokerageRow(brokerage)
                            }
                        }
                    }
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(scrollCoordinateSpace))
        } action: { newValue in
            searchCardFrame = newValue
        }
    }

    private func brokerageRow(_ brokerage: BrokerageDirectoryEntry) -> some View {
        let isSelected = viewModel.draft.broker == brokerage.slug

        return Button {
            Haptic.light()
            viewModel.selectBrokerage(brokerage)
        } label: {
            HStack(spacing: Spacing.sm) {
                AsyncImage(url: brokerage.primaryLogoURL) { image in
                    image.resizable().scaledToFit().padding(9)
                } placeholder: {
                    Image(systemName: "building.columns.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(width: 46, height: 46)
                .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(brokerage.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        if brokerage.isDegraded {
                            Badge(text: "Degraded", tint: .warning)
                        }
                    }
                    Text(brokerage.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.positive : Color.brandPrimary)
            }
            .padding(Spacing.sm)
            .background(
                isSelected ? Color.brandPrimary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
        }
        .buttonStyle(.pressableCard)
    }

    private var connectCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Link a broker")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                AppTextField(title: "Broker slug", text: $viewModel.draft.broker, icon: "building.columns", autocapitalizeCharacters: true)

                Toggle("Immediate redirect", isOn: $viewModel.draft.immediateRedirect)
                    .tint(Color.brandPrimary)
                    .font(.system(size: 14))
                Toggle("Dark mode in portal", isOn: $viewModel.draft.darkMode)
                    .tint(Color.brandPrimary)
                    .font(.system(size: 14))

                Button {
                    Task {
                        await viewModel.connect(appState: appState)
                        if let portalURL = viewModel.portalURL, let url = URL(string: portalURL) {
                            openURL(url)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isConnecting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Connect Broker")
                            Image(systemName: "link")
                        }
                    }
                }
                .buttonStyle(.appPrimary(isDisabled: viewModel.isConnecting))
                .disabled(viewModel.isConnecting)

                if let portalURL = viewModel.portalURL, let url = URL(string: portalURL) {
                    Link(destination: url) {
                        Label("Launch connection portal", systemImage: "arrow.up.forward.app")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                }

                if let resultMessage = viewModel.resultMessage {
                    Text(resultMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var linkedAccountsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Linked accounts")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)

            if dashboardViewModel.payload != nil {
                if groupedBrokerAccounts.isEmpty {
                    Card {
                        EmptyStateView(title: "No accounts linked", message: "Connect a broker above to see accounts here.", systemImage: "building.columns")
                    }
                } else {
                    ForEach(groupedBrokerAccounts, id: \.institution) { group in
                        Card {
                            HStack(spacing: Spacing.sm) {
                                ZStack {
                                    Circle().fill(Color.brandPrimary.opacity(0.12)).frame(width: 40, height: 40)
                                    Image(systemName: "building.columns.fill")
                                        .foregroundStyle(Color.brandPrimary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(group.institution)
                                        .font(.cardTitle)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(group.accounts.count == 1 ? "1 connected account" : "\(group.accounts.count) connected accounts")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                Badge(
                                    text: group.accounts.contains { $0.status.caseInsensitiveCompare("linked") == .orderedSame }
                                        ? "Linked"
                                        : (group.accounts.first?.status.capitalized ?? "Unknown"),
                                    tint: .positive
                                )
                            }
                        }
                    }
                }
            } else {
                Card {
                    LoadingStateView(title: "Loading broker accounts")
                        .frame(height: 80)
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                appearanceCard
                notificationsCard
                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                }
                .buttonStyle(.appDestructive)
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .screenBackground()
        .navigationTitle("Settings")
        .compatibleInlineNavigationTitle()
    }

    private var appearanceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Appearance")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 2) {
                    ForEach(AppTheme.allCases) { theme in
                        themeButton(theme)
                    }
                }
                .padding(3)
                .background(Color.appSurfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
        }
    }

    private func themeButton(_ theme: AppTheme) -> some View {
        let isSelected = appState.appTheme == theme

        return Button {
            Haptic.selection()
            withAnimation(.easeOut(duration: 0.2)) { appState.appTheme = theme }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: theme.icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(theme.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.brandPrimary : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.md - 3, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var notificationsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Notification Preferences")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                preferenceToggle("Email alerts", keyPath: \.emailAlerts)
                preferenceToggle("Push alerts", keyPath: \.pushAlerts)
                preferenceToggle("Breaking news", keyPath: \.breakingNews)
                preferenceToggle("Watchlist mentions", keyPath: \.watchlistMentions)
                preferenceToggle("AI sentiment alerts", keyPath: \.sentimentAlerts)
            }
        }
    }

    private func preferenceToggle(_ title: String, keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { appState.notificationPreferences[keyPath: keyPath] },
                set: { appState.notificationPreferences[keyPath: keyPath] = $0 }
            )
        )
        .tint(Color.brandPrimary)
        .font(.system(size: 14))
    }
}
