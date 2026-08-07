import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await appState.authService.login(email: email, password: password)
            appState.setSession(response.value)
        } catch {
            errorMessage = error.localizedDescription
            appState.showToast(title: "Login Failed", message: error.localizedDescription, style: .error)
        }
    }
}

@MainActor
final class SignupViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phoneNumber = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var resultMessage: String?
    @Published var errorMessage: String?

    func signup(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let payload = SignupPayload(firstName: firstName, lastName: lastName, email: email, phoneNumber: phoneNumber, password: password)
            let response = try await appState.authService.signup(payload: payload)
            resultMessage = response.value.message
            appState.showToast(title: "Signup Complete", message: response.value.message, style: .success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var payload: DashboardPayload?

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        payload = await appState.portfolioService.fetchDashboard()
    }
}

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var items: [WatchlistSymbol] = []
    @Published var symbolDraft = ""

    func load(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        let response = await appState.watchlistService.fetchWatchlist()
        items = response.value
    }

    func add(appState: AppState) async {
        guard !symbolDraft.isEmpty else { return }
        let response = await appState.watchlistService.add(symbol: symbolDraft)
        items = response.value
        appState.showToast(title: "Watchlist Updated", message: "\(symbolDraft.uppercased()) added.", style: .success)
        symbolDraft = ""
    }

    func remove(symbol: String, appState: AppState) async {
        let response = await appState.watchlistService.remove(symbol: symbol, current: items)
        items = response.value
        appState.showToast(title: "Watchlist Updated", message: "\(symbol) removed.", style: .neutral)
    }
}

@MainActor
final class BrokersViewModel: ObservableObject {
    @Published var draft = BrokerConnectionDraft()
    @Published var isConnecting = false
    @Published var isLoadingBrokerages = false
    @Published var brokerages: [BrokerageDirectoryEntry] = []
    @Published var searchText = ""
    @Published var portalURL: String?
    @Published var resultMessage: String?

    var filteredBrokerages: [BrokerageDirectoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        let source = brokerages.filter { $0.enabled }
        return source
            .filter { $0.searchableText.contains(query) }
            .sorted { left, right in
                let leftRank = brokerageMatchRank(for: left, query: query)
                let rightRank = brokerageMatchRank(for: right, query: query)

                if leftRank != rightRank {
                    return leftRank < rightRank
                }

                return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
            }
    }

    func loadBrokerages(appState: AppState) async {
        guard brokerages.isEmpty else { return }
        isLoadingBrokerages = true
        defer { isLoadingBrokerages = false }
        let response = await appState.portfolioService.fetchBrokerages()
        brokerages = deduplicatedBrokerages(from: response.value)
    }

    func selectBrokerage(_ brokerage: BrokerageDirectoryEntry) {
        draft.broker = brokerage.slug
    }

    func connect(appState: AppState) async {
        isConnecting = true
        defer { isConnecting = false }

        do {
            let response = try await appState.portfolioService.connectBroker(draft: draft)
            portalURL = response.value.redirectURL
            resultMessage = "Connection started. Continue in your browser to finish linking your account."
            appState.showToast(title: "Broker Flow Ready", message: resultMessage ?? "", style: .success)
        } catch {
            resultMessage = error.localizedDescription
            appState.showToast(title: "Connection Failed", message: error.localizedDescription, style: .error)
        }
    }

    private func deduplicatedBrokerages(from entries: [BrokerageDirectoryEntry]) -> [BrokerageDirectoryEntry] {
        var entriesByKey: [String: BrokerageDirectoryEntry] = [:]

        for entry in entries {
            let key = entry.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }

            if let existing = entriesByKey[key] {
                if preferredBrokerage(entry, over: existing) {
                    entriesByKey[key] = entry
                }
            } else {
                entriesByKey[key] = entry
            }
        }

        return entriesByKey.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func preferredBrokerage(_ candidate: BrokerageDirectoryEntry, over existing: BrokerageDirectoryEntry) -> Bool {
        if candidate.enabled != existing.enabled {
            return candidate.enabled
        }
        if candidate.isDegraded != existing.isDegraded {
            return !candidate.isDegraded
        }
        if candidate.allowsTrading != existing.allowsTrading {
            return candidate.allowsTrading == true
        }
        if candidate.primaryLogoURL != nil, existing.primaryLogoURL == nil {
            return true
        }
        if candidate.releaseStage != existing.releaseStage {
            return candidate.releaseStage == "GENERALLY_AVAILABLE"
        }
        return candidate.slug.count < existing.slug.count
    }

    private func brokerageMatchRank(for brokerage: BrokerageDirectoryEntry, query: String) -> Int {
        let displayName = brokerage.displayName.lowercased()
        let name = brokerage.name.lowercased()
        let slug = brokerage.slug.lowercased()

        if displayName == query || slug == query || name == query {
            return 0
        }
        if displayName.hasPrefix(query) {
            return 1
        }
        if slug.hasPrefix(query) {
            return 2
        }
        if name.hasPrefix(query) {
            return 3
        }
        if displayName.contains(query) {
            return 4
        }
        if slug.contains(query) {
            return 5
        }
        if name.contains(query) {
            return 6
        }
        return 7
    }
}
