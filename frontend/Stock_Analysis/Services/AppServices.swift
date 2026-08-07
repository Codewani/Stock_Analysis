import Foundation

final class AuthService {
    private let apiClient: APIClient
    private let keychain: KeychainHelper

    init(apiClient: APIClient, keychain: KeychainHelper) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    func login(email: String, password: String) async throws -> APIResponse<UserSession> {
        let tokenResponse = try await apiClient.requestForm(
            path: "/login",
            form: ["username": email, "password": password],
            responseType: LoginResponse.self
        )

        let profileResponse = try await apiClient.request(
            path: "/users/me",
            headers: ["Authorization": "Bearer \(tokenResponse.value.accessToken)"],
            responseType: UserProfile.self
        )

        let session = UserSession(
            token: tokenResponse.value.accessToken,
            tokenType: tokenResponse.value.tokenType,
            profile: profileResponse.value
        )
        keychain.saveCodable(session, for: AppState.sessionKey)
        return APIResponse(value: session, exchange: tokenResponse.exchange)
    }

    func signup(payload: SignupPayload) async throws -> APIResponse<SignupResponse> {
        let body = try JSONEncoder().encode(payload)
        return try await apiClient.request(
            path: "/register",
            method: .post,
            body: body,
            responseType: SignupResponse.self,
            fallback: {
                SignupResponse(userID: UUID().uuidString, message: "Your account has been created.")
            }
        )
    }
}

final class PortfolioService {
    private let apiClient: APIClient
    private let mockData: MockDataProvider

    init(apiClient: APIClient, mockData: MockDataProvider) {
        self.apiClient = apiClient
        self.mockData = mockData
    }

    func fetchDashboard() async -> DashboardPayload {
        let snapshots: [PortfolioSnapshot]
        let accounts: [BrokerAccount]
        let holdings: [Holding]

        do {
            snapshots = try await apiClient.request(
                path: "/snap_trade/data/accounts/balances/history",
                requiresAuth: true,
                responseType: [PortfolioSnapshot].self,
                fallback: { self.mockData.portfolioSnapshots() }
            ).value
        } catch {
            snapshots = mockData.portfolioSnapshots()
        }

        do {
            accounts = try await apiClient.request(
                path: "/snap_trade/data/accounts",
                requiresAuth: true,
                responseType: [BrokerAccount].self,
                fallback: { self.mockData.brokerAccounts() }
            ).value
        } catch {
            accounts = mockData.brokerAccounts()
        }

        do {
            holdings = try await apiClient.request(
                path: "/snap_trade/data/accounts/holdings",
                requiresAuth: true,
                responseType: [Holding].self,
                fallback: { self.mockData.holdings() }
            ).value
        } catch {
            holdings = mockData.holdings()
        }

        let sortedSnapshots = snapshots.sorted { $0.snapshotTimestamp > $1.snapshotTimestamp }
        let summary = makePortfolioSummary(from: sortedSnapshots, holdings: holdings)
        return DashboardPayload(summary: summary, snapshots: sortedSnapshots, holdings: holdings, accounts: accounts)
    }

    func stockDetail(for holding: Holding) -> StockDetailPayload {
        StockDetailPayload(
            holding: holding,
            chart: mockData.chartPoints(for: holding.symbol),
            relatedNews: mockData.newsStories().filter { $0.symbol == holding.symbol }
        )
    }

    func updateAccountSnapshots() async -> Bool {
        do {
            _ = try await apiClient.request(
                path: "/snap_trade/data/accounts/update",
                method: .post,
                requiresAuth: true,
                responseType: PortfolioSnapshot.self
            )
            return true
        } catch {
            // Keep the periodic sync best-effort so transient update failures do not interrupt the UI.
            return false
        }
    }

    private func makePortfolioSummary(from snapshots: [PortfolioSnapshot], holdings: [Holding]) -> PortfolioSummary {
        let holdingsValue = holdings.reduce(0) { $0 + $1.marketValue }
        let latestBalance = snapshots.first?.totalBalance ?? holdingsValue
        let previousBalance = snapshots.dropFirst().first?.totalBalance ?? (latestBalance * 0.985)
        let dayChange = latestBalance - previousBalance
        let dayChangePercentage = previousBalance == 0 ? 0 : dayChange / previousBalance
        let buyingPower = snapshots.first?.buyingPower ?? (latestBalance * 0.06)

        return PortfolioSummary(
            totalValue: latestBalance,
            dayChange: dayChange,
            dayChangePercentage: dayChangePercentage,
            buyingPower: buyingPower
        )
    }

    func connectBroker(draft: BrokerConnectionDraft) async throws -> APIResponse<BrokerConnectionResponse> {
        let payload: [String: AnyEncodable] = [
            "broker": AnyEncodable(draft.broker),
            "custom_redirect": AnyEncodable(draft.customRedirect),
            "immediate_redirect": AnyEncodable(draft.immediateRedirect),
            "reconnect": AnyEncodable(draft.reconnect),
            "show_close_button": AnyEncodable(draft.showCloseButton),
            "dark_mode": AnyEncodable(draft.darkMode),
            "connection_portal_version": AnyEncodable(draft.connectionPortalVersion)
        ]
        let body = try JSONEncoder().encode(payload)
        return try await apiClient.request(
            path: "/snap_trade/connections/establish_connection",
            method: .post,
            body: body,
            requiresAuth: true,
            responseType: BrokerConnectionResponse.self,
            fallback: { BrokerConnectionResponse(redirectURL: "https://snaptrade.com/mock-session") }
        )
    }

    func fetchBrokerages() async -> APIResponse<[BrokerageDirectoryEntry]> {
        do {
            return try await apiClient.request(
                path: "https://api.snaptrade.com/api/v1/brokerages",
                responseType: [BrokerageDirectoryEntry].self,
                fallback: { self.mockData.brokerages() }
            )
        } catch {
            return APIResponse(
                value: mockData.brokerages(),
                exchange: NetworkExchange(
                    method: "GET",
                    path: "https://api.snaptrade.com/api/v1/brokerages",
                    requestBody: "",
                    responseBody: "Mock brokerage directory fallback",
                    statusCode: nil,
                    latency: nil,
                    timestamp: .now,
                    source: .mock,
                    errorDescription: error.localizedDescription
                )
            )
        }
    }
}

final class WatchlistService {
    private let apiClient: APIClient
    private let mockData: MockDataProvider

    init(apiClient: APIClient, mockData: MockDataProvider) {
        self.apiClient = apiClient
        self.mockData = mockData
    }

    func fetchWatchlist() async -> APIResponse<[WatchlistSymbol]> {
        do {
            return try await apiClient.request(
                path: "/watchlist",
                requiresAuth: true,
                responseType: [WatchlistSymbol].self,
                fallback: { self.mockData.watchlist() }
            )
        } catch {
            return APIResponse(
                value: mockData.watchlist(),
                exchange: NetworkExchange(method: "GET", path: "/watchlist", requestBody: "", responseBody: "Mock watchlist fallback", statusCode: nil, latency: nil, timestamp: .now, source: .mock, errorDescription: error.localizedDescription)
            )
        }
    }

    func add(symbol: String) async -> APIResponse<[WatchlistSymbol]> {
        let normalizedSymbol = symbol.uppercased()
        let payload = ["symbol": normalizedSymbol]
        let body = try? JSONEncoder().encode(payload)
        _ = try? await apiClient.request(
            path: "/add_to_watchlist",
            method: .post,
            body: body,
            requiresAuth: true,
            responseType: SignupResponse.self,
            fallback: { SignupResponse(userID: UUID().uuidString, message: "Mock add") }
        )
        let current = await fetchWatchlist().value
        let updated: [WatchlistSymbol]
        if current.contains(where: { $0.symbol == normalizedSymbol }) {
            // The re-fetched list already reflects the addition (live backend persisted it).
            updated = current
        } else {
            // Backend call was mocked/unreachable, so merge it in locally for the UI.
            updated = current + [WatchlistSymbol(watchlistItemID: UUID().uuidString, userID: UUID().uuidString, symbol: normalizedSymbol, createdAt: .now)]
        }
        return APIResponse(value: updated, exchange: NetworkExchange(method: "POST", path: "/add_to_watchlist", requestBody: symbol, responseBody: "Local merge", statusCode: nil, latency: nil, timestamp: .now, source: .mock, errorDescription: nil))
    }

    func remove(symbol: String, current: [WatchlistSymbol]) async -> APIResponse<[WatchlistSymbol]> {
        let payload = ["symbol": symbol.uppercased()]
        let body = try? JSONEncoder().encode(payload)
        _ = try? await apiClient.request(
            path: "/remove_from_watchlist",
            method: .post,
            body: body,
            requiresAuth: true,
            responseType: SignupResponse.self,
            fallback: { SignupResponse(userID: UUID().uuidString, message: "Mock remove") }
        )
        let updated = current.filter { $0.symbol != symbol.uppercased() }
        return APIResponse(value: updated, exchange: NetworkExchange(method: "POST", path: "/remove_from_watchlist", requestBody: symbol, responseBody: "Local merge", statusCode: nil, latency: nil, timestamp: .now, source: .mock, errorDescription: nil))
    }
}

struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
