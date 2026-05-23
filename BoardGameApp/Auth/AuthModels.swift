import Foundation

struct AppUser: Codable, Hashable, Sendable {
    let id: UUID
    let email: String?
    let displayName: String?
}

struct AuthResponse: Codable, Sendable {
    let token: String
    let expiresAt: Date
    let user: AppUser
    let isNewUser: Bool
}

/// Matches the SessionBundle DTO the server returns from `GET /api/session`.
struct SessionBundle: Codable, Sendable {
    let user: AppUser
    let players: [SavedPlayer]
    let records: [GameRecord]
}

struct AppleAuthRequest: Encodable, Sendable {
    let identityToken: String
    let fullName: String?
}

struct AuthSession: Codable, Sendable {
    let token: String
    let expiresAt: Date
    let user: AppUser

    var isExpired: Bool { expiresAt <= Date() }
}
