import Foundation

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
