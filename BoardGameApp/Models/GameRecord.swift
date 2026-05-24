import Foundation

struct GameRecord: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let game: String
    let yearPublished: Int?
    let variants: [String]
    let date: String              // ISO yyyy-MM-dd (server format)
    let playerCount: Int
    let winners: [Int]
    let notes: String?
    let players: [RecordPlayer]
    let createdAt: Date
}

struct RecordPlayer: Codable, Hashable, Sendable {
    let name: String
    let email: String?
    let identity: String?
    let team: Int?
    let eliminated: Bool?
    let endState: [String: EndStateValue]
    /// Roster row this player corresponds to. The server stamps this in on
    /// create/update (find-or-create against the user's roster), so on read
    /// it's reliably populated and we can pre-fill it back into the edit form.
    let savedPlayerID: UUID?

    enum CodingKeys: String, CodingKey {
        case name, email, identity, team, eliminated, endState, savedPlayerID
    }
}

enum EndStateValue: Codable, Hashable, Sendable {
    case integer(Int)
    case boolean(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            self = .boolean(b)
            return
        }
        if let i = try? c.decode(Int.self) {
            self = .integer(i)
            return
        }
        throw DecodingError.typeMismatch(
            EndStateValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "end_state values must be int or bool"),
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .integer(let i): try c.encode(i)
        case .boolean(let b): try c.encode(b)
        }
    }

    var displayString: String {
        switch self {
        case .integer(let i): return String(i)
        case .boolean(let b): return b ? "Yes" : "No"
        }
    }
}
