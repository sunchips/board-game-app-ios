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
    /// Fully cooperative game (e.g. Hanabi). When true, the create-record form
    /// shows a single "Team won this game" toggle instead of a per-player
    /// winner picker — `winners` is conventionally all-or-nothing.
    let isCooperative: Bool
    let variantOptions: [String]
    let requiredVariantCount: Int?
    let achievements: [GameAchievement]
    let endStateFields: [EndStateField]

    init(
        slug: String,
        displayName: String,
        yearPublished: Int?,
        identityOptions: [String],
        supportsTeams: Bool,
        supportsElimination: Bool,
        isCooperative: Bool = false,
        variantOptions: [String] = [],
        requiredVariantCount: Int? = nil,
        achievements: [GameAchievement] = [],
        endStateFields: [EndStateField],
    ) {
        self.slug = slug
        self.displayName = displayName
        self.yearPublished = yearPublished
        self.identityOptions = identityOptions
        self.supportsTeams = supportsTeams
        self.supportsElimination = supportsElimination
        self.isCooperative = isCooperative
        self.variantOptions = variantOptions
        self.requiredVariantCount = requiredVariantCount
        self.achievements = achievements
        self.endStateFields = endStateFields
    }
}

enum EndStateField: Hashable, Sendable {
    case integer(key: String, label: String, min: Int = 0, max: Int? = nil, group: String? = nil)
    case boolean(key: String, label: String, group: String? = nil)

    var key: String {
        switch self {
        case .integer(let k, _, _, _, _): return k
        case .boolean(let k, _, _): return k
        }
    }

    var label: String {
        switch self {
        case .integer(_, let l, _, _, _): return l
        case .boolean(_, let l, _): return l
        }
    }

    var group: String? {
        switch self {
        case .integer(_, _, _, _, let g): return g
        case .boolean(_, _, let g): return g
        }
    }
}

struct GameAchievement: Identifiable, Hashable, Sendable {
    var id: String { slug }
    let slug: String
    let name: String
    let description: String
    let condition: AchievementCondition

    func isMet(integers: [String: Int], booleans: [String: Bool]) -> Bool {
        condition.isMet(integers: integers, booleans: booleans)
    }
}

indirect enum AchievementCondition: Hashable, Sendable {
    case integerAtLeast(key: String, value: Int)
    case integerAtMost(key: String, value: Int)
    case sumAtLeast(keys: [String], value: Int)
    case booleanEquals(key: String, value: Bool)
    case anyOf([AchievementCondition])
    case allOf([AchievementCondition])

    func isMet(integers: [String: Int], booleans: [String: Bool]) -> Bool {
        switch self {
        case .integerAtLeast(let key, let value):
            return (integers[key] ?? 0) >= value
        case .integerAtMost(let key, let value):
            return (integers[key] ?? 0) <= value
        case .sumAtLeast(let keys, let value):
            return keys.reduce(0) { $0 + (integers[$1] ?? 0) } >= value
        case .booleanEquals(let key, let value):
            return (booleans[key] ?? false) == value
        case .anyOf(let conditions):
            return conditions.contains { $0.isMet(integers: integers, booleans: booleans) }
        case .allOf(let conditions):
            return conditions.allSatisfy { $0.isMet(integers: integers, booleans: booleans) }
        }
    }
}

enum GameCatalog {
    static let all: [GameDefinition] = [
        bunnyKingdom,
        calico,
        canvas,
        catan,
        codenames,
        coup,
        everdell,
        hanabi,
        hibachi,
        huesAndCues,
        jaipur,
        kingOfNewYork,
        parks,
        petiquette,
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

    static let canvas = GameDefinition(
        slug: "canvas", displayName: "Canvas", yearPublished: 2021,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        variantOptions: [
            "composition", "consistency", "emphasis", "hierarchy",
            "movement", "proportion", "proximity", "repetition",
            "space", "style", "symmetry", "variety",
        ],
        requiredVariantCount: 4,
        achievements: [
            GameAchievement(
                slug: "ach_all_conditions", name: "Jack of All Trades",
                description: "Meet all 4 scoring conditions with 1 painting",
                condition: .anyOf((1...3).map { n in
                    .allOf([
                        .booleanEquals(key: "painting_\(n)_scored", value: true),
                        .integerAtMost(key: "painting_\(n)_silver", value: 0),
                    ])
                })),
            GameAchievement(
                slug: "ach_4_silver_painting", name: "Hidden Gem",
                description: "Score 4+ silver ribbons with 1 painting",
                condition: .anyOf((1...3).map { n in
                    .integerAtLeast(key: "painting_\(n)_silver", value: 4)
                })),
            GameAchievement(
                slug: "ach_7_ribbons_painting", name: "Masterpiece",
                description: "Score 7+ ribbons with 1 painting",
                condition: .anyOf((1...3).map { n in
                    .sumAtLeast(keys: ["painting_\(n)_red", "painting_\(n)_green", "painting_\(n)_blue", "painting_\(n)_purple"], value: 7)
                })),
            GameAchievement(
                slug: "ach_5_same_element", name: "Elemental Master",
                description: "Have 5 of the same element on 1 painting",
                condition: .anyOf((1...3).flatMap { n in
                    ["hue", "tone", "texture", "shape"].map { e in
                        .integerAtLeast(key: "painting_\(n)_\(e)", value: 5)
                    }
                })),
            GameAchievement(
                slug: "ach_max_all_cards", name: "Critical Acclaim",
                description: "Get max ribbons from all 4 scoring cards",
                condition: .booleanEquals(key: "ach_max_all_cards", value: true)),
            GameAchievement(
                slug: "ach_7_silver", name: "Rogue Artist",
                description: "Score 7+ silver ribbons",
                condition: .integerAtLeast(key: "silver_ribbons", value: 7)),
            GameAchievement(
                slug: "ach_14_ribbons", name: "Ribbon Hunter",
                description: "Score 14+ ribbons",
                condition: .sumAtLeast(keys: ["red_ribbons", "green_ribbons", "blue_ribbons", "purple_ribbons"], value: 14)),
            GameAchievement(
                slug: "ach_40_points", name: "Point Collector",
                description: "Score 40+ points",
                condition: .integerAtLeast(key: "score", value: 40)),
            GameAchievement(
                slug: "ach_47_points", name: "Master Artist",
                description: "Beat the designer's top score (47)",
                condition: .integerAtLeast(key: "score", value: 47)),
        ],
        endStateFields: [
            // Summary
            .integer(key: "score", label: "Score"),
            .integer(key: "red_ribbons", label: "Red Ribbons"),
            .integer(key: "green_ribbons", label: "Green Ribbons"),
            .integer(key: "blue_ribbons", label: "Blue Ribbons"),
            .integer(key: "purple_ribbons", label: "Purple Ribbons"),
            .integer(key: "silver_ribbons", label: "Silver Ribbons"),
            .integer(key: "paintings", label: "Paintings", max: 3),
            // Painting 1
            .boolean(key: "painting_1_scored", label: "Scored", group: "Painting 1"),
            .integer(key: "painting_1_red", label: "Red", group: "Painting 1"),
            .integer(key: "painting_1_green", label: "Green", group: "Painting 1"),
            .integer(key: "painting_1_blue", label: "Blue", group: "Painting 1"),
            .integer(key: "painting_1_purple", label: "Purple", group: "Painting 1"),
            .integer(key: "painting_1_silver", label: "Silver", max: 4, group: "Painting 1"),
            .integer(key: "painting_1_hue", label: "Hue", group: "Painting 1"),
            .integer(key: "painting_1_tone", label: "Tone", group: "Painting 1"),
            .integer(key: "painting_1_texture", label: "Texture", group: "Painting 1"),
            .integer(key: "painting_1_shape", label: "Shape", group: "Painting 1"),
            // Painting 2
            .boolean(key: "painting_2_scored", label: "Scored", group: "Painting 2"),
            .integer(key: "painting_2_red", label: "Red", group: "Painting 2"),
            .integer(key: "painting_2_green", label: "Green", group: "Painting 2"),
            .integer(key: "painting_2_blue", label: "Blue", group: "Painting 2"),
            .integer(key: "painting_2_purple", label: "Purple", group: "Painting 2"),
            .integer(key: "painting_2_silver", label: "Silver", max: 4, group: "Painting 2"),
            .integer(key: "painting_2_hue", label: "Hue", group: "Painting 2"),
            .integer(key: "painting_2_tone", label: "Tone", group: "Painting 2"),
            .integer(key: "painting_2_texture", label: "Texture", group: "Painting 2"),
            .integer(key: "painting_2_shape", label: "Shape", group: "Painting 2"),
            // Painting 3
            .boolean(key: "painting_3_scored", label: "Scored", group: "Painting 3"),
            .integer(key: "painting_3_red", label: "Red", group: "Painting 3"),
            .integer(key: "painting_3_green", label: "Green", group: "Painting 3"),
            .integer(key: "painting_3_blue", label: "Blue", group: "Painting 3"),
            .integer(key: "painting_3_purple", label: "Purple", group: "Painting 3"),
            .integer(key: "painting_3_silver", label: "Silver", max: 4, group: "Painting 3"),
            .integer(key: "painting_3_hue", label: "Hue", group: "Painting 3"),
            .integer(key: "painting_3_tone", label: "Tone", group: "Painting 3"),
            .integer(key: "painting_3_texture", label: "Texture", group: "Painting 3"),
            .integer(key: "painting_3_shape", label: "Shape", group: "Painting 3"),
            // Achievements (self-report for ones that can't be auto-detected)
            .boolean(key: "ach_max_all_cards", label: "Max Ribbons from All 4 Cards", group: "Achievements"),
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

    static let hanabi = GameDefinition(
        slug: "hanabi", displayName: "Hanabi", yearPublished: 2010,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        isCooperative: true,
        endStateFields: [
            .integer(key: "score", label: "Score", max: 25),
            .integer(key: "firework_red", label: "Red Firework", max: 5),
            .integer(key: "firework_yellow", label: "Yellow Firework", max: 5),
            .integer(key: "firework_green", label: "Green Firework", max: 5),
            .integer(key: "firework_blue", label: "Blue Firework", max: 5),
            .integer(key: "firework_white", label: "White Firework", max: 5),
            .integer(key: "fuse_tokens_remaining", label: "Fuse Tokens Remaining", max: 3),
            .integer(key: "hint_tokens_remaining", label: "Hint Tokens Remaining", max: 8),
            .boolean(key: "perfect_score", label: "Perfect Score"),
            .boolean(key: "exploded", label: "Exploded"),
        ],
    )

    static let hibachi = GameDefinition(
        slug: "hibachi", displayName: "Hibachi", yearPublished: 2021,
        identityOptions: ["black", "blue", "green", "red"],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "recipes_completed", label: "Recipes Completed", max: 3),
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

    static let petiquette = GameDefinition(
        slug: "petiquette", displayName: "Petiquette", yearPublished: 2025,
        identityOptions: [],
        supportsTeams: false, supportsElimination: false,
        endStateFields: [
            .integer(key: "score", label: "Score"),
            .integer(key: "matches", label: "Matches"),
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
