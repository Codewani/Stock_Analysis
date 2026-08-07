import Foundation

enum AppEnvironment {
    static var current: Configuration {
#if DEBUG
        return .debug
#else
        return .release
#endif
    }

    enum Configuration {
        case debug
        case release

        var baseURL: URL {
            if let override = ProcessInfo.processInfo.environment["STOCK_API_BASE_URL"],
               let url = URL(string: override) {
                return url
            }

            switch self {
            case .debug:
                return URL(string: "http://127.0.0.1:8000")!
            case .release:
                return URL(string: "https://api.example.com")!
            }
        }
    }
}
