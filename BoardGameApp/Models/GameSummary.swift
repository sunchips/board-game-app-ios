import Foundation

struct GameSummary: Codable, Hashable, Sendable, Identifiable {
    var id: String { slug }
    let slug: String
    let displayName: String
    let yearPublished: Int?
    let identityOptions: [String]
    let endStateFields: [EndStateFieldSpec]
    let supportsTeams: Bool
    let supportsElimination: Bool
    let variants: [String]
}

struct EndStateFieldSpec: Codable, Hashable, Sendable {
    let key: String
    let type: String
    let min: Int?
    let max: Int?

    var isBoolean: Bool { type == "boolean" }
}
