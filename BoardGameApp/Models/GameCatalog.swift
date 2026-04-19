import Foundation

/// Hardcoded definitions for each supported game. Mirrors the JSON Schemas in
/// `board-game-record` — one entry per `games/<slug>/<slug>.schema.json`.
///
/// The identity and end-state field lists drive the UI in `CreateRecordView`:
/// - `identityOptions` → Picker shown when non-empty.
/// - `endStateFields` → one Stepper (integer) or Toggle (boolean) per entry.
///
/// Keep keys in sync with the schema `propertyNames.enum` and min/max with the
/// schema `properties.<key>.minimum` / `maximum`. The Swift test suite validates
/// that every supported slug has a non-empty definition.
struct GameDefinition: Identifiable, Hashable, Sendable {
    var id: String { slug }
    let slug: String
    let displayName: String
    let yearPublished: Int?
    let identityOptions: [String]
    let supportsTeams: Bool
    let supportsElimination: Bool
    let endStateFields: [EndStateField]
}

enum EndStateField: Hashable, Sendable {
    case integer(key: String, label: String, min: Int = 0, max: Int? = nil)
    case boolean(key: String, label: String)

    var key: String {
        switch self {
        case .integer(let k, _, _, _): return k
        case .boolean(let k, _): return k
        }
    }

    var label: String {
        switch self {
        case .integer(_, let l, _, _): return l
        case .boolean(_, let l): return l
        }
    }
}

enum GameCatalog {
    static let all: [GameDefinition] = [
        bunnyKingdom,
        calico,
        catan,
        codenames,
        coup,
        everdell,
        huesAndCues,
        jaipur,
        kingOfNewYork,
        parks,
        scythe,
        secretHitler,
        theKingIsDead,
        viticulture,
        wavelength,
    ].sorted { $0.displayName < $1.displayName }

    static func find(slug: String) -> GameDefinition? {
        all.first { $0.slug == slug }
    }

    // MARK: - Individual games (keys mirror board-game-record schemas)

    static let bunnyKingdom = GameDefinition(
        slug: "bunny-kingdom", displayName: "Bunny Kingdom", yearPublished: nil,
        identityOptions: ["red", "blue", "yellow", "green"],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "vp", label: "Victory Points"),
            .integer(key: "fiefs", label: "Fiefs"),
            .integer(key: "cities", label: "Cities"),
            .integer(key: "towers", label: "Towers"),
            .integer(key: "fief_vp", label: "Fief VP"),
            .integer(key: "parchment_vp", label: "Parchment VP"),
            .integer(key: "golden_parchments", label: "Golden Parchments"),
        ],
    )

    static let calico = GameDefinition(
        slug: "calico", displayName: "Calico", yearPublished: nil,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "cats_vp", label: "Cats VP"),
            .integer(key: "buttons_vp", label: "Buttons VP"),
            .integer(key: "design_goal_vp", label: "Design Goal VP"),
        ],
    )

    static let catan = GameDefinition(
        slug: "catan", displayName: "Catan", yearPublished: nil,
        identityOptions: ["red", "blue", "white", "orange"],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "settlements", label: "Settlements"),
            .integer(key: "cities", label: "Cities"),
            .integer(key: "roads", label: "Roads"),
            .boolean(key: "longest_road", label: "Longest Road"),
            .boolean(key: "largest_army", label: "Largest Army"),
            .integer(key: "dev_card_vp", label: "VP Dev Cards"),
            .integer(key: "knights_played", label: "Knights Played"),
        ],
    )

    static let codenames = GameDefinition(
        slug: "codenames", displayName: "Codenames", yearPublished: nil,
        identityOptions: ["spymaster", "operative"],
        supportsTeams: true, supportsElimination: false,
        endStateFields: [
            .integer(key: "agents_remaining", label: "Agents Remaining", max: 9),
            .boolean(key: "assassin_hit", label: "Assassin Hit"),
            .boolean(key: "starting_team", label: "Starting Team"),
        ],
    )

    static let coup = GameDefinition(
        slug: "coup", displayName: "Coup", yearPublished: 2012,
        identityOptions: [],
        supportsTeams: false, supportsElimination: true,
        endStateFields: [
            .integer(key: "coins", label: "Coins", max: 12),
            .integer(key: "influences_remaining", label: "Influences Remaining", max: 2),
        ],
    )

    static let everdell = GameDefinition(
        slug: "everdell", displayName: "Everdell", yearPublished: nil,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "vp", label: "Victory Points"),
            .integer(key: "base_vp", label: "Base VP"),
            .integer(key: "point_tokens", label: "Point Tokens"),
            .integer(key: "event_vp", label: "Event VP"),
            .integer(key: "journey_vp", label: "Journey VP"),
            .integer(key: "prosperity_vp", label: "Prosperity VP"),
            .integer(key: "constructions", label: "Constructions", max: 15),
            .integer(key: "critters", label: "Critters", max: 15),
        ],
    )

    static let huesAndCues = GameDefinition(
        slug: "hues-and-cues", displayName: "Hues and Cues", yearPublished: nil,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "vp", label: "Victory Points"),
            .integer(key: "cues_given", label: "Cues Given"),
            .integer(key: "bullseyes", label: "Bullseyes"),
        ],
    )

    static let jaipur = GameDefinition(
        slug: "jaipur", displayName: "Jaipur", yearPublished: nil,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "seals", label: "Seals", max: 2),
            .integer(key: "total_rupees", label: "Total Rupees"),
            .integer(key: "bonus_tokens", label: "Bonus Tokens"),
            .integer(key: "camel_wins", label: "Camel Wins", max: 3),
        ],
    )

    static let kingOfNewYork = GameDefinition(
        slug: "king-of-new-york", displayName: "King of New York", yearPublished: nil,
        identityOptions: ["captain-fish", "drakonis", "kong", "meka-dragon", "sheriff", "the-king"],
        supportsTeams: false, supportsElimination: true,
        endStateFields: [
            .integer(key: "vp", label: "Victory Points", max: 20),
            .integer(key: "hearts", label: "Hearts", max: 10),
            .integer(key: "energy", label: "Energy"),
            .integer(key: "power_cards", label: "Power Cards"),
            .boolean(key: "superstar", label: "Superstar"),
            .boolean(key: "statue_of_liberty", label: "Statue of Liberty"),
        ],
    )

    static let parks = GameDefinition(
        slug: "parks", displayName: "Parks", yearPublished: nil,
        identityOptions: ["red", "blue", "green", "yellow", "orange"],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "vp", label: "Victory Points"),
            .integer(key: "parks_visited", label: "Parks Visited"),
            .integer(key: "park_vp", label: "Park VP"),
            .integer(key: "photos", label: "Photos"),
            .integer(key: "wildlife", label: "Wildlife"),
            .integer(key: "year_bonus_vp", label: "Year Bonus VP"),
            .integer(key: "canteen", label: "Canteen", max: 3),
            .integer(key: "gear", label: "Gear"),
        ],
    )

    static let scythe = GameDefinition(
        slug: "scythe", displayName: "Scythe", yearPublished: nil,
        identityOptions: ["saxony", "nordic", "crimea", "rusviet", "polania"],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "coins", label: "Coins"),
            .integer(key: "stars", label: "Stars", max: 6),
            .integer(key: "popularity", label: "Popularity", max: 18),
            .integer(key: "power", label: "Power", max: 16),
            .integer(key: "territories", label: "Territories"),
            .integer(key: "resources", label: "Resources"),
            .integer(key: "workers", label: "Workers", min: 2, max: 8),
            .integer(key: "mechs", label: "Mechs", max: 4),
            .integer(key: "structures", label: "Structures", max: 4),
            .integer(key: "recruits", label: "Recruits", max: 4),
            .integer(key: "upgrades", label: "Upgrades", max: 6),
            .integer(key: "objectives_completed", label: "Objectives Completed", max: 2),
            .boolean(key: "factory_card", label: "Factory Card"),
        ],
    )

    static let secretHitler = GameDefinition(
        slug: "secret-hitler", displayName: "Secret Hitler", yearPublished: nil,
        identityOptions: ["liberal", "fascist", "hitler"],
        supportsTeams: true, supportsElimination: false,
        endStateFields: [
            .integer(key: "policies_liberal", label: "Liberal Policies", max: 5),
            .integer(key: "policies_fascist", label: "Fascist Policies", max: 6),
            .boolean(key: "hitler_chancellor_win", label: "Hitler Chancellor Win"),
            .boolean(key: "hitler_assassinated", label: "Hitler Assassinated"),
        ],
    )

    static let theKingIsDead = GameDefinition(
        slug: "the-king-is-dead", displayName: "The King Is Dead", yearPublished: nil,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "followers_welsh", label: "Welsh Followers"),
            .integer(key: "followers_scots", label: "Scots Followers"),
            .integer(key: "followers_english", label: "English Followers"),
            .integer(key: "supporters_placed", label: "Supporters Placed", max: 3),
            .integer(key: "regions_welsh", label: "Welsh Regions", max: 8),
            .integer(key: "regions_scots", label: "Scots Regions", max: 8),
            .integer(key: "regions_english", label: "English Regions", max: 8),
        ],
    )

    static let viticulture = GameDefinition(
        slug: "viticulture", displayName: "Viticulture", yearPublished: nil,
        identityOptions: ["green", "yellow", "red", "blue", "purple", "orange"],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "vp", label: "Victory Points"),
            .integer(key: "lira", label: "Lira"),
            .integer(key: "workers", label: "Workers", min: 3, max: 7),
            .integer(key: "residuals", label: "Residuals", max: 5),
            .integer(key: "structures", label: "Structures", max: 8),
            .integer(key: "vine_cards", label: "Vine Cards"),
            .integer(key: "wine_tokens", label: "Wine Tokens"),
            .integer(key: "orders_filled", label: "Orders Filled"),
        ],
    )

    static let wavelength = GameDefinition(
        slug: "wavelength", displayName: "Wavelength", yearPublished: nil,
        identityOptions: [],
        supportsTeams: true, supportsElimination: false,
        endStateFields: [
            .integer(key: "team_score", label: "Team Score", max: 10),
            .integer(key: "bullseyes", label: "Bullseyes"),
            .integer(key: "rounds_psychic", label: "Rounds as Psychic"),
        ],
    )
}
