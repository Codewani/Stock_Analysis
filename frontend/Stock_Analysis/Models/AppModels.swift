import Foundation

enum AppTab: String, CaseIterable, Hashable {
    case dashboard
    case watchlist
    case news
    case brokers
}

struct AppToast: Identifiable, Equatable {
    enum Style {
        case success
        case error
        case neutral
    }

    let id = UUID()
    let title: String
    let message: String
    let style: Style
}

struct UserProfile: Codable, Identifiable, Hashable {
    let userID: String
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String

    var id: String { userID }
    var fullName: String { "\(firstName) \(lastName)" }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phoneNumber = "phone_number"
    }
}

struct UserSession: Codable, Hashable {
    let token: String
    let tokenType: String
    let profile: UserProfile

    var authorizationHeader: String {
        "\(tokenType.capitalized) \(token)"
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct SignupPayload: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phoneNumber = "phone_number"
        case password
    }
}

struct SignupResponse: Codable {
    let userID: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case message
    }
}

struct PortfolioSnapshot: Codable, Identifiable, Hashable {
    let snapshotID: String
    let userID: String
    let totalBalance: Double
    let buyingPower: Double?
    let snapshotTimestamp: Date
    let createdAt: Date?

    var id: String { snapshotID }

    enum CodingKeys: String, CodingKey {
        case snapshotID = "snapshot_id"
        case userID = "user_id"
        case totalBalance = "total_balance"
        case buyingPower = "buying_power"
        case snapshotTimestamp = "snapshot_timestamp"
        case createdAt = "created_at"
    }
}

struct PortfolioSummary: Hashable {
    let totalValue: Double
    let dayChange: Double
    let dayChangePercentage: Double
    let buyingPower: Double
}

struct Holding: Codable, Identifiable, Hashable {
    let holdingID: String
    let symbol: String
    let companyName: String
    let shares: Double
    let averageCost: Double
    let currentPrice: Double
    let openPnL: Double?

    var id: String { holdingID }

    var marketValue: Double { shares * currentPrice }
    var unrealizedPL: Double { openPnL ?? shares * (currentPrice - averageCost) }
    var unrealizedPLPercent: Double {
        let costBasis = shares * averageCost
        guard costBasis > 0 else { return 0 }
        return unrealizedPL / costBasis
    }

    init(
        holdingID: String = UUID().uuidString,
        symbol: String,
        companyName: String,
        shares: Double,
        averageCost: Double,
        currentPrice: Double,
        openPnL: Double? = nil
    ) {
        self.holdingID = holdingID
        self.symbol = symbol
        self.companyName = companyName
        self.shares = shares
        self.averageCost = averageCost
        self.currentPrice = currentPrice
        self.openPnL = openPnL
    }

    enum CodingKeys: String, CodingKey {
        case holdingID = "holding_id"
        case symbol
        case shares = "units"
        case averageCost = "average_purchase_price"
        case currentPrice = "price"
        case openPnL = "open_pnl"
        case companyName = "company_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        holdingID = try container.decodeIfPresent(String.self, forKey: .holdingID) ?? UUID().uuidString
        symbol = try container.decode(String.self, forKey: .symbol)
        shares = try container.decode(Double.self, forKey: .shares)
        averageCost = try container.decode(Double.self, forKey: .averageCost)
        currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        openPnL = try container.decodeIfPresent(Double.self, forKey: .openPnL)
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName) ?? symbol
    }
}

struct PricePoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct WatchlistSymbol: Codable, Identifiable, Hashable {
    let watchlistItemID: String
    let userID: String
    let symbol: String
    let createdAt: Date?

    var id: String { watchlistItemID }

    enum CodingKeys: String, CodingKey {
        case watchlistItemID = "watchlist_item_id"
        case userID = "user_id"
        case symbol
        case createdAt = "created_at"
    }
}

enum Sentiment: String, Codable, CaseIterable, Hashable {
    case positive
    case neutral
    case negative
}

struct NewsStory: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let headline: String
    let summary: String
    let source: String
    let publishedAt: Date
    let sentiment: Sentiment
    let importanceScore: Int
    let url: URL?
}

enum NotificationCategory: String, Hashable {
    case system
    case portfolio
    case news
}

struct AppNotification: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let createdAt: Date
    var isRead: Bool
    let category: NotificationCategory
}

struct NotificationPreferences: Codable, Hashable {
    var emailAlerts: Bool
    var pushAlerts: Bool
    var breakingNews: Bool
    var watchlistMentions: Bool
    var sentimentAlerts: Bool

    static let `default` = NotificationPreferences(
        emailAlerts: true,
        pushAlerts: true,
        breakingNews: true,
        watchlistMentions: true,
        sentimentAlerts: true
    )
}

struct BrokerAccount: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let institution: String
    let status: String

    init(id: String, displayName: String, institution: String, status: String) {
        self.id = id
        self.displayName = displayName
        self.institution = institution
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .init("id")) ?? UUID().uuidString
        displayName = try container.decodeIfPresent(String.self, forKey: .init("name"))
            ?? container.decodeIfPresent(String.self, forKey: .init("display_name"))
            ?? "Broker Account"
        institution = try container.decodeIfPresent(String.self, forKey: .init("institution_name"))
            ?? container.decodeIfPresent(String.self, forKey: .init("broker"))
            ?? "SnapTrade"
        status = try container.decodeIfPresent(String.self, forKey: .init("status")) ?? "linked"
    }
}

struct BrokerageAuthorizationType: Codable, Hashable {
    let type: String
    let authType: String

    enum CodingKeys: String, CodingKey {
        case type
        case authType = "auth_type"
    }
}

struct BrokerageTypeInfo: Codable, Hashable {
    let id: String
    let name: String
}

struct BrokerageDirectoryEntry: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let slug: String
    let description: String
    let url: URL?
    let openURL: URL?
    let logoURL: URL?
    let squareLogoURL: URL?
    let enabled: Bool
    let allowsTrading: Bool?
    let isDegraded: Bool
    let releaseStage: String?
    let brokerageType: BrokerageTypeInfo?
    let authorizationTypes: [BrokerageAuthorizationType]

    var primaryLogoURL: URL? {
        squareLogoURL ?? logoURL
    }

    var searchableText: String {
        [displayName, name, slug, description].joined(separator: " ").lowercased()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case slug
        case description
        case url
        case openURL = "open_url"
        case logoURL = "aws_s3_logo_url"
        case squareLogoURL = "aws_s3_square_logo_url"
        case enabled
        case allowsTrading = "allows_trading"
        case isDegraded = "is_degraded"
        case releaseStage = "release_stage"
        case brokerageType = "brokerage_type"
        case authorizationTypes = "authorization_types"
    }
}

struct BrokerConnectionDraft: Hashable {
    var broker: String = ""
    var customRedirect: String = "https://snaptrade.com"
    var immediateRedirect: Bool = true
    var reconnect: String = ""
    var showCloseButton: Bool = true
    var darkMode: Bool = true
    var connectionPortalVersion: String = "v4"
}

struct BrokerConnectionResponse: Decodable, Hashable {
    let redirectURL: String?
    let sessionID: String?

    private enum CodingKeys: String, CodingKey {
        case redirectURI = "redirectURI"
        case redirectUri = "redirectUri"
        case url
        case sessionId
        case session_id
    }

    init(redirectURL: String?, sessionID: String? = nil) {
        self.redirectURL = redirectURL
        self.sessionID = sessionID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        redirectURL = try container.decodeIfPresent(String.self, forKey: .redirectURI)
            ?? container.decodeIfPresent(String.self, forKey: .redirectUri)
            ?? container.decodeIfPresent(String.self, forKey: .url)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionId)
            ?? container.decodeIfPresent(String.self, forKey: .session_id)
    }
}

enum APIDataSource: String, Hashable {
    case live
    case cache
    case mock
}

struct NetworkExchange: Identifiable, Hashable {
    let id = UUID()
    let method: String
    let path: String
    let requestBody: String
    let responseBody: String
    let statusCode: Int?
    let latency: TimeInterval?
    let timestamp: Date
    let source: APIDataSource
    let errorDescription: String?

    var wasSuccessful: Bool {
        guard let statusCode else { return source == .mock || source == .cache }
        return (200..<300).contains(statusCode)
    }
}

struct APIResponse<Value> {
    let value: Value
    let exchange: NetworkExchange
}

struct DashboardPayload {
    let summary: PortfolioSummary
    let snapshots: [PortfolioSnapshot]
    let holdings: [Holding]
    let accounts: [BrokerAccount]
}

struct StockDetailPayload {
    let holding: Holding
    let chart: [PricePoint]
    let relatedNews: [NewsStory]
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

enum HTTPMethod: String, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    var id: String { rawValue }
}
