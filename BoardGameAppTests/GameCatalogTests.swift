import Testing
@testable import BoardGameApp

@Suite("Game catalog")
struct GameCatalogTests {

    @Test("Every expected slug is present")
    func allSlugsPresent() {
        let expected: Set<String> = [
            "bunny-kingdom", "calico", "catan", "codenames", "coup",
            "everdell", "hues-and-cues", "jaipur", "king-of-new-york",
            "parks", "scythe", "secret-hitler", "the-king-is-dead",
            "viticulture", "wavelength",
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
            "bunny-kingdom", "catan", "codenames", "king-of-new-york",
            "parks", "scythe", "secret-hitler", "viticulture",
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
}
