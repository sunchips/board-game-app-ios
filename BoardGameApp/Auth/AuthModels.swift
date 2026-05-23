import Foundation

struct AuthUser: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let email: String?
    let name: String?
    let createdAt: Date
}

struct AuthSession: Codable, Hashable, Sendable {
    let sessionToken: String
    let expiresInSeconds: Int
    let user: AuthUser
}

struct AppleSignInRequest: Codable, Sendable {
    let identityToken: String
    let email: String?
    let name: String?
}
