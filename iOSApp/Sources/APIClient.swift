import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func search(_ query: [String: String]) async throws -> SearchResponse {
        try await get("/api/v1/search", query: query)
    }

    func listing(mlsNumber: String, boardId: String?) async throws -> Listing {
        var query: [String: String] = [:]
        if let boardId, !boardId.isEmpty { query["boardId"] = boardId }
        return try await get("/api/v1/listings/\(Self.encode(mlsNumber))", query: query)
    }

    func autocomplete(_ text: String) async throws -> [LocationSuggestion] {
        let response: LocationsResponse = try await get(
            "/api/v1/locations/autocomplete",
            query: ["search": text]
        )
        return response.locations ?? []
    }

    private func baseURL() throws -> String {
        var base = AppSettings.shared.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            throw APIError(message: "Add your server address in Settings.")
        }
        if !base.lowercased().hasPrefix("http://") && !base.lowercased().hasPrefix("https://") {
            base = "http://" + base
        }
        while base.hasSuffix("/") { base.removeLast() }
        return base
    }

    private func get<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        guard var components = URLComponents(string: try baseURL() + path) else {
            throw APIError(message: "The server address in Settings is not a valid URL.")
        }
        if !query.isEmpty {
            components.percentEncodedQuery = query
                .sorted { $0.key < $1.key }
                .map { "\(Self.encode($0.key))=\(Self.encode($0.value))" }
                .joined(separator: "&")
        }
        guard let url = components.url else {
            throw APIError(message: "The server address in Settings is not a valid URL.")
        }

        var request = URLRequest(url: url)
        request.setValue(AppSettings.shared.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw APIError(message: Self.describe(error))
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = json?["error"] as? String
            if status == 401 {
                throw APIError(message: "The server rejected the API key. Check it in Settings.")
            }
            throw APIError(message: message ?? "Server error (HTTP \(status)).")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(message: "Unexpected response from server: \(error.localizedDescription)")
        }
    }

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "You're offline."
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            return "Can't reach the server. Make sure it's running (npm start) and your iPhone is on the same Wi-Fi as your PC."
        default:
            return error.localizedDescription
        }
    }

    private static let allowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
