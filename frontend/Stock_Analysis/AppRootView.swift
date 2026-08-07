import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isValidatingSession {
                SplashView()
                    .transition(.opacity)
            } else if appState.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                AuthContainerView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isValidatingSession)
        .animation(.easeInOut(duration: 0.25), value: appState.isAuthenticated)
        .task(id: appState.isAuthenticated) {
            if appState.isAuthenticated {
                appState.startPeriodicHoldingsUpdate()
            } else {
                appState.stopPeriodicHoldingsUpdate()
            }
        }
        .toastOverlay(toast: appState.toast)
        .tint(Color.brandPrimary)
        .preferredColorScheme(appState.appTheme.colorScheme)
        .animation(.easeOut(duration: 0.2), value: appState.appTheme)
    }
}

/// Shown only while a session restored from the keychain is being confirmed
/// against the backend, so the login screen never flashes for a session that
/// turns out to still be valid.
private struct SplashView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.brandPrimary)
                    .frame(width: 58, height: 58)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
            }
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.brandPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView().tag(AppTab.dashboard)
            WatchlistView().tag(AppTab.watchlist)
            NewsFeedView().tag(AppTab.news)
            BrokerIntegrationsView().tag(AppTab.brokers)
        }
        .tabBarChromeHidden()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $appState.selectedTab)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

private extension View {
    @ViewBuilder
    func tabBarChromeHidden() -> some View {
#if os(iOS)
        toolbar(.hidden, for: .tabBar)
#else
        self
#endif
    }
}

private struct TabBarItem {
    let tab: AppTab
    let icon: String
    let label: String
}

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private let items: [TabBarItem] = [
        TabBarItem(tab: .dashboard, icon: "house", label: "Home"),
        TabBarItem(tab: .watchlist, icon: "star", label: "Watchlist"),
        TabBarItem(tab: .news, icon: "newspaper", label: "News"),
        TabBarItem(tab: .brokers, icon: "building.columns", label: "Brokers")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                let isSelected = selection == item.tab
                Button {
                    guard selection != item.tab else { return }
                    Haptic.selection()
                    selection = item.tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .symbolVariant(isSelected ? .fill : .none)
                            .font(.system(size: 19, weight: .semibold))
                        Text(item.label)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Color.brandPrimary : Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xxs)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }
}
