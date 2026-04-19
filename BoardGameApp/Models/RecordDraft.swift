import Foundation

/// In-memory record being edited in the create flow. When submitted, it's
/// serialised with snake_case keys to match the board-game-record core schema.
struct RecordDraft: Encodable, Sendable {
    let game: String
    let variants: [String]
    let yearPublished: Int?
    let date: String
    let playerCount: Int
    let winners: [Int]
    let notes: String?
    let players: [PlayerDraft]
}

struct PlayerDraft: Encodable, Sendable {
    let name: String
    let email: String?
    let identity: String?
    let team: Int?
    let eliminated: Bool?
    let endState: [String: EndStateValue]
}
