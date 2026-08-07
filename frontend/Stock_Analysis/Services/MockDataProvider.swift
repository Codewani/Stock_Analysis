import Foundation

struct MockDataProvider {
    func userProfile() -> UserProfile {
        UserProfile(
            userID: UUID().uuidString,
            firstName: "Kondwani",
            lastName: "Tester",
            email: "qa@portfolio.app",
            phoneNumber: "555-0100"
        )
    }

    func portfolioSnapshots() -> [PortfolioSnapshot] {
        let now = Date()
        return stride(from: 6, through: 0, by: -1).map { offset in
            let value = 128_400 + Double((6 - offset) * 1650) - Double(offset * 220)
            let buyingPower = value * 0.06
            return PortfolioSnapshot(
                snapshotID: UUID().uuidString,
                userID: UUID().uuidString,
                totalBalance: value,
                buyingPower: buyingPower,
                snapshotTimestamp: Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now,
                createdAt: now
            )
        }
    }

    func holdings() -> [Holding] {
        [
            Holding(symbol: "AAPL", companyName: "Apple", shares: 42.35, averageCost: 187.10, currentPrice: 203.42),
            Holding(symbol: "NVDA", companyName: "NVIDIA", shares: 14.8, averageCost: 901.50, currentPrice: 948.22),
            Holding(symbol: "AMZN", companyName: "Amazon", shares: 18.0, averageCost: 175.23, currentPrice: 182.14),
            Holding(symbol: "TSLA", companyName: "Tesla", shares: 10.25, averageCost: 201.76, currentPrice: 188.15)
        ]
    }

    func chartPoints(for symbol: String) -> [PricePoint] {
        let now = Date()
        let baseline = holdings().first(where: { $0.symbol == symbol })?.currentPrice ?? 100
        return stride(from: 11, through: 0, by: -1).map { offset in
            let drift = Double(offset) * -0.55
            let variation = Double.random(in: -3.0...4.5)
            return PricePoint(
                date: Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now,
                value: baseline + drift + variation
            )
        }
    }

    func watchlist() -> [WatchlistSymbol] {
        ["MSFT", "META", "GOOGL", "AMD"].map {
            WatchlistSymbol(
                watchlistItemID: UUID().uuidString,
                userID: UUID().uuidString,
                symbol: $0,
                createdAt: .now
            )
        }
    }

    func newsStories() -> [NewsStory] {
        [
            NewsStory(symbol: "AAPL", headline: "Apple supplier mix points to resilient iPhone cycle", summary: "Channel checks imply steadier demand than feared, with margins holding into the summer refresh.", source: "FinSignal", publishedAt: .now.addingTimeInterval(-1800), sentiment: .positive, importanceScore: 88, url: URL(string: "https://example.com/apple")),
            NewsStory(symbol: "NVDA", headline: "NVIDIA extends AI lead as enterprise orders accelerate", summary: "Data-center buyers are still favoring NVIDIA clusters, reinforcing pricing power into next quarter.", source: "MarketWire", publishedAt: .now.addingTimeInterval(-3600), sentiment: .positive, importanceScore: 94, url: URL(string: "https://example.com/nvda")),
            NewsStory(symbol: "TSLA", headline: "Tesla delivery revisions pressure near-term sentiment", summary: "Analysts cut near-term forecasts after additional delivery revisions, though long-term autonomy optionality remains in focus.", source: "StreetScope", publishedAt: .now.addingTimeInterval(-7800), sentiment: .negative, importanceScore: 76, url: URL(string: "https://example.com/tesla")),
            NewsStory(symbol: "AMZN", headline: "Amazon ad revenue strength supports margin outlook", summary: "Advertising and cloud mix continue to offset retail investment, helping free cash flow resilience.", source: "Pulse Desk", publishedAt: .now.addingTimeInterval(-9600), sentiment: .neutral, importanceScore: 67, url: URL(string: "https://example.com/amazon"))
        ]
    }

    func notifications() -> [AppNotification] {
        [
            AppNotification(title: "Daily recap ready", subtitle: "Portfolio closed up 1.9% today.", createdAt: .now.addingTimeInterval(-3200), isRead: false, category: .portfolio),
            AppNotification(title: "Watchlist hit", subtitle: "MSFT was mentioned in a high-importance story.", createdAt: .now.addingTimeInterval(-7200), isRead: true, category: .news)
        ]
    }

    func brokerAccounts() -> [BrokerAccount] {
        [
            BrokerAccount(id: UUID().uuidString, displayName: "Robinhood Individual", institution: "Robinhood", status: "linked"),
            BrokerAccount(id: UUID().uuidString, displayName: "Schwab IRA", institution: "Charles Schwab", status: "mock")
        ]
    }

    func brokerages() -> [BrokerageDirectoryEntry] {
        [
            BrokerageDirectoryEntry(
                id: UUID().uuidString,
                name: "Robinhood",
                displayName: "Robinhood",
                slug: "ROBINHOOD",
                description: "Commission-free brokerage for stocks, options, and crypto.",
                url: URL(string: "https://www.robinhood.com/"),
                openURL: URL(string: "https://robinhood.com"),
                logoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/robinhood-logo.png"),
                squareLogoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/robinhood-logo-square.png"),
                enabled: true,
                allowsTrading: false,
                isDegraded: false,
                releaseStage: "GENERALLY_AVAILABLE",
                brokerageType: BrokerageTypeInfo(id: UUID().uuidString, name: "Traditional Brokerage"),
                authorizationTypes: [BrokerageAuthorizationType(type: "read", authType: "OAUTH")]
            ),
            BrokerageDirectoryEntry(
                id: UUID().uuidString,
                name: "Fidelity",
                displayName: "Fidelity",
                slug: "FIDELITY",
                description: "Large US brokerage with full-service investing and retirement accounts.",
                url: URL(string: "https://www.fidelity.com/"),
                openURL: URL(string: "https://fidelity.com"),
                logoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/fidelity-logo.png"),
                squareLogoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/fidelity-logo-square.png"),
                enabled: true,
                allowsTrading: false,
                isDegraded: false,
                releaseStage: "GENERALLY_AVAILABLE",
                brokerageType: BrokerageTypeInfo(id: UUID().uuidString, name: "Traditional Brokerage"),
                authorizationTypes: [BrokerageAuthorizationType(type: "read", authType: "OAUTH")]
            ),
            BrokerageDirectoryEntry(
                id: UUID().uuidString,
                name: "Interactive Brokers",
                displayName: "IBKR",
                slug: "INTERACTIVE-BROKERS",
                description: "Global brokerage with broad market access and advanced trading tools.",
                url: URL(string: "https://www.interactivebrokers.com/"),
                openURL: URL(string: "https://www.interactivebrokers.com/en/home.php"),
                logoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/interactive-brokers-logo.png"),
                squareLogoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/interactive-brokers-logo-square.png"),
                enabled: true,
                allowsTrading: true,
                isDegraded: false,
                releaseStage: "GENERALLY_AVAILABLE",
                brokerageType: BrokerageTypeInfo(id: UUID().uuidString, name: "Traditional Brokerage"),
                authorizationTypes: [BrokerageAuthorizationType(type: "read", authType: "OAUTH")]
            ),
            BrokerageDirectoryEntry(
                id: UUID().uuidString,
                name: "Coinbase",
                displayName: "Coinbase",
                slug: "COINBASE",
                description: "Secure crypto platform for buying, selling, and storing digital assets.",
                url: URL(string: "https://www.coinbase.com/"),
                openURL: URL(string: "https://www.coinbase.com/"),
                logoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/coinbase_logo.png"),
                squareLogoURL: URL(string: "https://passiv-brokerage-logos.s3.ca-central-1.amazonaws.com/coinbase-logo-square.jpg"),
                enabled: true,
                allowsTrading: true,
                isDegraded: false,
                releaseStage: "GENERALLY_AVAILABLE",
                brokerageType: BrokerageTypeInfo(id: UUID().uuidString, name: "Cryptocurrency Exchange"),
                authorizationTypes: [BrokerageAuthorizationType(type: "read", authType: "OAUTH")]
            )
        ]
    }

    func portfolioSummary(from snapshots: [PortfolioSnapshot], holdings: [Holding]) -> PortfolioSummary {
        let latest = snapshots.first?.totalBalance ?? holdings.reduce(0) { $0 + $1.marketValue }
        let previous = snapshots.dropFirst().first?.totalBalance ?? (latest * 0.985)
        let change = latest - previous
        let percentage = previous == 0 ? 0 : change / previous
        let buyingPower = snapshots.first?.buyingPower ?? (latest * 0.06)
        return PortfolioSummary(totalValue: latest, dayChange: change, dayChangePercentage: percentage, buyingPower: buyingPower)
    }

    func breakingNewsStory() -> NewsStory {
        NewsStory(
            symbol: ["AAPL", "NVDA", "TSLA", "AMZN", "MSFT"].randomElement() ?? "AAPL",
            headline: "Breaking: shares move on fresh market activity",
            summary: "A new story just landed in your feed — pull to refresh anytime to catch the latest market-moving headlines.",
            source: "Market Wire",
            publishedAt: .now,
            sentiment: [.positive, .neutral, .negative].randomElement() ?? .neutral,
            importanceScore: Int.random(in: 60...98),
            url: nil
        )
    }
}
