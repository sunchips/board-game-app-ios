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
