import Foundation

extension Notification.Name {
    /// Posted from the API layer when the server returns 401 on an authorised
    /// request — `AuthStore` observes this and clears the Keychain session.
    static let apiSessionExpired = Notification.Name("boardgame.api.sessionExpired")
}

struct APIError: LocalizedError, Decodable, Sendable {
    let status: Int
    let error: String
    let message: String
    let violations: [Violation]

    struct Violation: Decodable, Hashable, Sendable {
        let path: String
        let message: String
    }

    var errorDescription: String? {
        if violations.isEmpty { return message }
        let details = violations.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
        return "\(message)\n\(details)"
    }

    static let transport = APIError(
        status: -1, error: "Transport", message: "Network request failed", violations: [],
    )
}
