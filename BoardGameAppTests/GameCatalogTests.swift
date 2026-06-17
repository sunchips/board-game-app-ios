import Testing
@testable import BoardGameApp

@Suite("Game catalog")
struct GameCatalogTests {

    @Test("Every expected slug is present")
    func allSlugsPresent() {
        let expected: Set<String> = [
            "bunny-kingdom", "calico", "canvas", "catan", "codenames", "coup",
            "everdell", "hanabi", "hibachi", "hues-and-cues", "jaipur",
            "king-of-new-york", "parks", "petiquette", "scythe",
            "secret-hitler", "the-king-is-dead", "viticulture", "wavelength",
        ]
        let actual = Set(GameCatalog.all.map(\.slug))
        #expect(actual == expected)
    }

    @Test("Slugs are unique")
    func slugsUnique() {
        let slugs = GameCatalog.all.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
    }

    @Test("Every game has at least one end-state field")
    func hasFields() {
        for game in GameCatalog.all {
            #expect(!game.endStateFields.isEmpty, "\(game.slug) missing end state fields")
        }
    }

    @Test("End-state keys are unique within a game")
    func endStateKeysUnique() {
        for game in GameCatalog.all {
            let keys = game.endStateFields.map(\.key)
            #expect(Set(keys).count == keys.count, "\(game.slug) has duplicate keys")
        }
    }

    @Test("Coup carries year_published 2012 for folder resolution")
    func coupYear() {
        let coup = GameCatalog.find(slug: "coup")
        #expect(coup?.yearPublished == 2012)
    }

    @Test("Games with identity enums have non-empty options")
    func identityOptionsNonEmpty() {
        let identityGames = [
            "bunny-kingdom", "catan", "codenames", "hibachi",
            "king-of-new-york", "parks", "scythe", "secret-hitler",
            "viticulture",
        ]
        for slug in identityGames {
            let g = GameCatalog.find(slug: slug)
            #expect(g != nil, "missing \(slug)")
            #expect(g?.identityOptions.isEmpty == false, "\(slug) identities are empty")
        }
    }

    @Test("Catalog is sorted by displayName")
    func sortedByDisplayName() {
        let names = GameCatalog.all.map(\.displayName)
        #expect(names == names.sorted())
    }

    @Test("Hanabi is marked cooperative")
    func hanabiIsCooperative() {
        let hanabi = GameCatalog.find(slug: "hanabi")
        #expect(hanabi?.isCooperative == true)
    }

    @Test("Hanabi is the only cooperative game today")
    func onlyHanabiIsCooperative() {
        // Guards against flag flips on competitive games. When the next coop
        // game lands (Pandemic, Spirit Island, …), update this set explicitly.
        let coopSlugs = Set(GameCatalog.all.filter(\.isCooperative).map(\.slug))
        #expect(coopSlugs == ["hanabi"])
    }

    @Test("Canvas requires exactly 4 scoring criteria")
    func canvasVariants() {
        let canvas = GameCatalog.find(slug: "canvas")
        #expect(canvas?.variantOptions.count == 12)
        #expect(canvas?.requiredVariantCount == 4)
    }

    @Test("Variant options are unique within a game")
    func variantOptionsUnique() {
        for game in GameCatalog.all {
            let opts = game.variantOptions
            #expect(Set(opts).count == opts.count, "\(game.slug) has duplicate variant options")
        }
    }

    @Test("Achievement slugs are unique within a game")
    func achievementSlugsUnique() {
        for game in GameCatalog.all {
            let slugs = game.achievements.map(\.slug)
            #expect(Set(slugs).count == slugs.count, "\(game.slug) has duplicate achievement slugs")
        }
    }

    @Test("Canvas achievements detect from end-state values")
    func canvasAchievementDetection() {
        let canvas = GameCatalog.find(slug: "canvas")!
        let find = { (slug: String) in canvas.achievements.first { $0.slug == slug }! }

        // Score-based
        #expect(find("ach_40_points").isMet(integers: ["score": 40], booleans: [:]))
        #expect(!find("ach_40_points").isMet(integers: ["score": 39], booleans: [:]))
        #expect(find("ach_47_points").isMet(integers: ["score": 47], booleans: [:]))
        #expect(!find("ach_47_points").isMet(integers: ["score": 46], booleans: [:]))
        #expect(find("ach_14_ribbons").isMet(integers: ["red_ribbons": 5, "green_ribbons": 4, "blue_ribbons": 3, "purple_ribbons": 2], booleans: [:]))
        #expect(!find("ach_14_ribbons").isMet(integers: ["red_ribbons": 5, "green_ribbons": 4, "blue_ribbons": 3, "purple_ribbons": 1], booleans: [:]))
        #expect(find("ach_7_silver").isMet(integers: ["silver_ribbons": 7], booleans: [:]))

        // Per-painting: 7+ ribbons on 1 painting (sum of colored ribbons)
        #expect(find("ach_7_ribbons_painting").isMet(integers: ["painting_2_red": 2, "painting_2_green": 2, "painting_2_blue": 2, "painting_2_purple": 1], booleans: [:]))
        #expect(!find("ach_7_ribbons_painting").isMet(integers: ["painting_2_red": 2, "painting_2_green": 2, "painting_2_blue": 1, "painting_2_purple": 1], booleans: [:]))

        // Per-painting: 5 of same element
        #expect(find("ach_5_same_element").isMet(integers: ["painting_1_hue": 5], booleans: [:]))
        #expect(!find("ach_5_same_element").isMet(integers: ["painting_1_hue": 4], booleans: [:]))

        // Per-painting: all 4 conditions met (scored + 0 silver)
        #expect(find("ach_all_conditions").isMet(
            integers: ["painting_1_silver": 0], booleans: ["painting_1_scored": true]))
        #expect(!find("ach_all_conditions").isMet(
            integers: ["painting_1_silver": 1], booleans: ["painting_1_scored": true]))

        // Self-reported achievement reads its own boolean
        #expect(find("ach_max_all_cards").isMet(integers: [:], booleans: ["ach_max_all_cards": true]))
        #expect(!find("ach_max_all_cards").isMet(integers: [:], booleans: [:]))
    }
}
