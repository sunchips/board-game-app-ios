import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = {
            let e = JSONEncoder()
            e.keyEncodingStrategy = .convertToSnakeCase
            e.dateEncodingStrategy = .iso8601
            e.outputFormatting = [.sortedKeys]
            return e
        }()
        self.decoder = {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            d.dateDecodingStrategy = .iso8601
            return d
        }()
    }

    func listGames() async throws -> [GameSummary] {
        try await send(request: buildRequest(path: "/api/games"))
    }

    func listRecords(game: String? = nil, limit: Int = 100) async throws -> [GameRecord] {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let game, !game.isEmpty { items.append(.init(name: "game", value: game)) }
        return try await send(request: buildRequest(path: "/api/records", query: items))
    }

    func getRecord(id: UUID) async throws -> GameRecord {
        try await send(request: buildRequest(path: "/api/records/\(id.uuidString)"))
    }

    func createRecord(_ body: RecordDraft) async throws -> GameRecord {
        var request = buildRequest(path: "/api/records")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request: request)
    }

    // MARK: - Internals

    private func buildRequest(path: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(url: AppConfig.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError(status: -1, error: "Transport", message: error.localizedDescription, violations: [])
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport }
        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw apiError
            }
            throw APIError(
                status: http.statusCode,
                error: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                message: String(data: data, encoding: .utf8) ?? "Request failed",
                violations: [],
            )
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError(
                status: http.statusCode, error: "Decode",
                message: "Could not parse response: \(error.localizedDescription)",
                violations: [],
            )
        }
    }
}
