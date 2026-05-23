import Foundation

struct SavedPlayer: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var email: String?
    var notes: String?
    let createdAt: Date
    let updatedAt: Date
}

struct SavedPlayerDraft: Codable, Hashable, Sendable {
    var name: String
    var email: String?
    var notes: String?
}
