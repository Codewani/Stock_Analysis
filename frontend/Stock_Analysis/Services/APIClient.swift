import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case badStatus(code: Int, body: String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case let .badStatus(code, body):
            return "Request failed with status \(code): \(body)"
        case .encodingFailed:
            return "Failed to encode request body."
        }
    }
}

final class APIClient {
    var baseURL: URL
    var authTokenProvider: (() -> String?)?
    var exchangeRecorder: ((NetworkExchange) -> Void)?
    var onUnauthorized: (() -> Void)?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let responseCache = ResponseCacheStore()
    private static let internetDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let internetDateFormatterWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let backendDateFormatters: [DateFormatter] = {
        let base = Locale(identifier: "en_US_POSIX")

        let withFractionalSeconds = DateFormatter()
        withFractionalSeconds.locale = base
        withFractionalSeconds.timeZone = TimeZone(secondsFromGMT: 0)
        withFractionalSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"

        let withoutFractionalSeconds = DateFormatter()
        withoutFractionalSeconds.locale = base
        withoutFractionalSeconds.timeZone = TimeZone(secondsFromGMT: 0)
        withoutFractionalSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        return [withFractionalSeconds, withoutFractionalSeconds]
    }()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            if let date = Self.internetDateFormatter.date(from: rawValue)
                ?? Self.internetDateFormatterWithoutFractionalSeconds.date(from: rawValue) {
                return date
            }

            for formatter in Self.backendDateFormatters {
                if let date = formatter.date(from: rawValue) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(rawValue)"
            )
        }
    }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = false,
        responseType: T.Type,
        fallback: (() -> T)? = nil
    ) async throws -> APIResponse<T> {
        let startedAt = Date()

        do {
            var request = try makeRequest(path: path, method: method, headers: headers, body: body, requiresAuth: requiresAuth)
            request.timeoutInterval = 12
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.invalidResponse
            }

            let responseBody = String(data: data, encoding: .utf8) ?? ""
            let latency = Date().timeIntervalSince(startedAt)

            guard (200..<300).contains(httpResponse.statusCode) else {
                if requiresAuth && httpResponse.statusCode == 401 {
                    onUnauthorized?()
                }
                throw APIClientError.badStatus(code: httpResponse.statusCode, body: responseBody)
            }

            let value = try decoder.decode(T.self, from: data)
            responseCache.store(data, for: request)
            let exchange = NetworkExchange(
                method: method.rawValue,
                path: path,
                requestBody: body.flatMap { String(data: $0, encoding: .utf8) } ?? "",
                responseBody: responseBody,
                statusCode: httpResponse.statusCode,
                latency: latency,
                timestamp: .now,
                source: .live,
                errorDescription: nil
            )
            exchangeRecorder?(exchange)
            return APIResponse(value: value, exchange: exchange)
        } catch {
            if requiresAuth,
               case let APIClientError.badStatus(code, _) = error,
               code == 401 {
                throw error
            }
            if let cachedResponse = cachedResponse(for: T.self, path: path, method: method, headers: headers, body: body, requiresAuth: requiresAuth, originalError: error) {
                return cachedResponse
            }
            if let fallback {
                let exchange = NetworkExchange(
                    method: method.rawValue,
                    path: path,
                    requestBody: body.flatMap { String(data: $0, encoding: .utf8) } ?? "",
                    responseBody: "Using mock fallback because live request failed.",
                    statusCode: nil,
                    latency: nil,
                    timestamp: .now,
                    source: .mock,
                    errorDescription: error.localizedDescription
                )
                exchangeRecorder?(exchange)
                return APIResponse(value: fallback(), exchange: exchange)
            }
            throw error
        }
    }

    func requestForm<T: Decodable>(
        path: String,
        form: [String: String],
        responseType: T.Type,
        fallback: (() -> T)? = nil
    ) async throws -> APIResponse<T> {
        let formBody = form
            .map {
                let encodedValue = $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\($0.key)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
        return try await request(
            path: path,
            method: .post,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: formBody,
            requiresAuth: false,
            responseType: responseType,
            fallback: fallback
        )
    }

    func clearCachedResponses() {
        responseCache.clear()
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        headers: [String: String],
        body: Data?,
        requiresAuth: Bool
    ) throws -> URLRequest {
        let url: URL
        if let absolute = URL(string: path), absolute.scheme != nil {
            url = absolute
        } else {
            url = baseURL.appending(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil, headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuth, let token = authTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private func cachedResponse<T: Decodable>(
        for responseType: T.Type,
        path: String,
        method: HTTPMethod,
        headers: [String: String],
        body: Data?,
        requiresAuth: Bool,
        originalError: Error
    ) -> APIResponse<T>? {
        guard let request = try? makeRequest(path: path, method: method, headers: headers, body: body, requiresAuth: requiresAuth),
              let data = responseCache.data(for: request),
              let value = try? decoder.decode(responseType, from: data) else {
            return nil
        }

        let exchange = NetworkExchange(
            method: method.rawValue,
            path: path,
            requestBody: body.flatMap { String(data: $0, encoding: .utf8) } ?? "",
            responseBody: String(data: data, encoding: .utf8) ?? "Using cached backend response.",
            statusCode: nil,
            latency: nil,
            timestamp: .now,
            source: .cache,
            errorDescription: "Using cached backend response after live request failed: \(originalError.localizedDescription)"
        )
        exchangeRecorder?(exchange)
        return APIResponse(value: value, exchange: exchange)
    }
}

private final class ResponseCacheStore {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "api_response_cache:"

    func store(_ data: Data, for request: URLRequest) {
        guard shouldCache(request), let key = cacheKey(for: request) else { return }
        defaults.set(data, forKey: key)
    }

    func data(for request: URLRequest) -> Data? {
        guard shouldCache(request), let key = cacheKey(for: request) else { return nil }
        return defaults.data(forKey: key)
    }

    func clear() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func shouldCache(_ request: URLRequest) -> Bool {
        request.httpMethod == HTTPMethod.get.rawValue
    }

    private func cacheKey(for request: URLRequest) -> String? {
        guard let url = request.url?.absoluteString else { return nil }
        return keyPrefix + url
    }
}
