import Combine
import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Equatable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var session: UserSession?
    @Published var backendBaseURL: URL {
        didSet {
            apiClient.baseURL = backendBaseURL
            UserDefaults.standard.set(backendBaseURL.absoluteString, forKey: Self.backendURLKey)
        }
    }
    @Published var appTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: Self.appThemeKey)
        }
    }
    @Published var toast: AppToast?
    @Published var isValidatingSession = false
    @Published var selectedTab: AppTab = .dashboard
    @Published var portfolioRefreshVersion = 0
    @Published var latestNews: [NewsStory]
    @Published var notifications: [AppNotification]
    @Published var notificationPreferences: NotificationPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(notificationPreferences) {
                UserDefaults.standard.set(data, forKey: Self.notificationPreferencesKey)
            }
        }
    }

    let keychain = KeychainHelper(service: "com.kondwani.StockAnalysis")
    let mockData = MockDataProvider()
    let apiClient: APIClient
    let authService: AuthService
    let portfolioService: PortfolioService
    let watchlistService: WatchlistService
    private var holdingsUpdateTask: Task<Void, Never>?
    private var tokenExpiryTask: Task<Void, Never>?

    static let sessionKey = "user_session"
    static let backendURLKey = "backend_base_url"
    static let notificationPreferencesKey = "notification_preferences"
    static let appThemeKey = "app_theme_preference"

    var isAuthenticated: Bool {
        session != nil
    }

    init() {
        let storedURL = UserDefaults.standard.string(forKey: Self.backendURLKey)
            .flatMap(URL.init(string:))
            ?? AppEnvironment.current.baseURL

        let storedPreferences: NotificationPreferences = {
            guard let data = UserDefaults.standard.data(forKey: Self.notificationPreferencesKey),
                  let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
                return .default
            }
            return preferences
        }()

        let storedTheme: AppTheme = UserDefaults.standard.string(forKey: Self.appThemeKey)
            .flatMap(AppTheme.init(rawValue:)) ?? .system

        self.backendBaseURL = storedURL
        self.appTheme = storedTheme
        self.notificationPreferences = storedPreferences
        self.latestNews = MockDataProvider().newsStories()
        self.notifications = MockDataProvider().notifications()

        let client = APIClient(baseURL: storedURL)
        self.apiClient = client
        self.authService = AuthService(apiClient: client, keychain: keychain)
        self.portfolioService = PortfolioService(apiClient: client, mockData: mockData)
        self.watchlistService = WatchlistService(apiClient: client, mockData: mockData)

        if let saved: UserSession = keychain.loadCodable(for: Self.sessionKey) {
            if let expiration = Self.tokenExpirationDate(from: saved.token), expiration <= .now {
                keychain.deleteValue(for: Self.sessionKey)
            } else {
                self.session = saved
            }
        }

        client.authTokenProvider = { [weak self] in
            self?.session?.token
        }
        client.onUnauthorized = { [weak self] in
            Task { @MainActor in
                self?.handleExpiredSession()
            }
        }

        if session != nil {
            scheduleTokenExpirationIfNeeded()
            startPeriodicHoldingsUpdate()
            validateSessionOnLaunch()
        }
    }

    func setSession(_ session: UserSession) {
        self.session = session
        keychain.saveCodable(session, for: Self.sessionKey)
        scheduleTokenExpirationIfNeeded()
        startPeriodicHoldingsUpdate()
        showToast(title: "Signed In", message: "Welcome back.", style: .success)
    }

    func signOut() {
        tokenExpiryTask?.cancel()
        tokenExpiryTask = nil
        stopPeriodicHoldingsUpdate()
        session = nil
        apiClient.clearCachedResponses()
        keychain.deleteValue(for: Self.sessionKey)
        selectedTab = .dashboard
        showToast(title: "Signed Out", message: "You've been signed out.", style: .neutral)
    }

    func startPeriodicHoldingsUpdate() {
        guard isAuthenticated else { return }

        holdingsUpdateTask?.cancel()
        holdingsUpdateTask = Task { [weak self] in
            guard let self else { return }

            await self.refreshPortfolioData()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(600))
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }
                await self.refreshPortfolioData()
            }
        }
    }

    func stopPeriodicHoldingsUpdate() {
        holdingsUpdateTask?.cancel()
        holdingsUpdateTask = nil
    }

    func refreshPortfolioData() async {
        let didUpdate = await portfolioService.updateAccountSnapshots()
        guard didUpdate else { return }
        portfolioRefreshVersion += 1
    }

    /// Confirms a session restored from the keychain still works against the
    /// backend, rather than trusting the locally-decoded JWT expiry alone. A
    /// confirmed 401 signs the user out via `onUnauthorized`; any other
    /// failure (backend unreachable, offline) keeps the locally-valid session
    /// signed in.
    private func validateSessionOnLaunch() {
        guard let session else { return }
        isValidatingSession = true

        Task { [weak self] in
            guard let self else { return }
            defer { self.isValidatingSession = false }

            do {
                let response = try await self.apiClient.request(
                    path: "/users/me",
                    headers: ["Authorization": "Bearer \(session.token)"],
                    requiresAuth: true,
                    responseType: UserProfile.self
                )
                guard let current = self.session else { return }
                let refreshed = UserSession(token: current.token, tokenType: current.tokenType, profile: response.value)
                self.session = refreshed
                self.keychain.saveCodable(refreshed, for: Self.sessionKey)
            } catch {
                // Confirmed-invalid sessions are already handled by `onUnauthorized`.
            }
        }
    }

    func handleExpiredSession() {
        guard session != nil else { return }
        tokenExpiryTask?.cancel()
        tokenExpiryTask = nil
        stopPeriodicHoldingsUpdate()
        session = nil
        apiClient.clearCachedResponses()
        keychain.deleteValue(for: Self.sessionKey)
        selectedTab = .dashboard
        showToast(title: "Session Expired", message: "Please sign in again.", style: .error)
    }

    func simulateNewsEvent() {
        let story = mockData.breakingNewsStory()
        latestNews.insert(story, at: 0)
        notifications.insert(
            AppNotification(
                title: story.headline,
                subtitle: "\(story.symbol) moved to the top of your feed",
                createdAt: .now,
                isRead: false,
                category: .news
            ),
            at: 0
        )
        showToast(title: "Feed Updated", message: "A new story just landed in your feed.", style: .success)
    }

    func showToast(title: String, message: String, style: AppToast.Style) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = AppToast(title: title, message: message, style: style)
        }

        Task {
            try? await Task.sleep(for: .seconds(2.6))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.toast = nil
                }
            }
        }
    }

    private func scheduleTokenExpirationIfNeeded() {
        tokenExpiryTask?.cancel()

        guard let token = session?.token,
              let expiration = Self.tokenExpirationDate(from: token) else {
            tokenExpiryTask = nil
            return
        }

        let delay = expiration.timeIntervalSinceNow
        guard delay > 0 else {
            handleExpiredSession()
            return
        }

        tokenExpiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self?.handleExpiredSession()
        }
    }

    private static func tokenExpirationDate(from token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count == 3,
              let payloadData = base64URLDecode(String(segments[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return nil
        }

        return Date(timeIntervalSince1970: exp)
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var padded = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder != 0 {
            padded += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: padded)
    }

    deinit {
        holdingsUpdateTask?.cancel()
        tokenExpiryTask?.cancel()
    }
}
