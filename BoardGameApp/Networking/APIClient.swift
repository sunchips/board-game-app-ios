import Foundation

/// Network client. The bearer token is read from Keychain on each request so
/// the client stays stateless — `AuthStore` owns the source of truth.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let tokenProvider: @Sendable () -> String?

    init(
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () -> String? = APIClient.defaultTokenProvider,
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
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

    // MARK: - Auth

    func signInWithApple(_ body: AppleAuthRequest) async throws -> AuthResponse {
        var request = buildRequest(path: "/api/auth/apple", requiresAuth: false)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request: request)
    }

    // MARK: - Games / records

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

    // MARK: - Saved players

    func listSavedPlayers() async throws -> [SavedPlayer] {
        try await send(request: buildRequest(path: "/api/players"))
    }

    func createSavedPlayer(_ body: SavedPlayerDraft) async throws -> SavedPlayer {
        var request = buildRequest(path: "/api/players")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request: request)
    }

    func updateSavedPlayer(id: UUID, body: SavedPlayerDraft) async throws -> SavedPlayer {
        var request = buildRequest(path: "/api/players/\(id.uuidString)")
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request: request)
    }

    func deleteSavedPlayer(id: UUID) async throws {
        var request = buildRequest(path: "/api/players/\(id.uuidString)")
        request.httpMethod = "DELETE"
        try await sendNoContent(request: request)
    }

    // MARK: - Internals

    private func buildRequest(
        path: String,
        query: [URLQueryItem] = [],
        requiresAuth: Bool = true,
    ) -> URLRequest {
        var components = URLComponents(url: AppConfig.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        let (data, http) = try await execute(request: request)
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

    private func sendNoContent(request: URLRequest) async throws {
        _ = try await execute(request: request)
    }

    private func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError(status: -1, error: "Transport", message: error.localizedDescription, violations: [])
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401, request.value(forHTTPHeaderField: "Authorization") != nil {
                // Server rejected our session token — burn it so the UI falls
                // back to the login screen on the next observation.
                await MainActor.run { NotificationCenter.default.post(name: .apiSessionExpired, object: nil) }
            }
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
        return (data, http)
    }

    /// Default token lookup reads Keychain directly so the shared client stays
    /// sync with wherever AuthStore last persisted.
    @Sendable static func defaultTokenProvider() -> String? {
        guard let raw = KeychainStore.read("session"),
              let data = raw.data(using: .utf8)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let session = try? decoder.decode(AuthSession.self, from: data),
              !session.isExpired
        else { return nil }
        return session.token
    }
}
