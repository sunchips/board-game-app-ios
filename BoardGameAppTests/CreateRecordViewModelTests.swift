import Testing
@testable import BoardGameApp

@Suite("CreateRecordViewModel — cooperative team end state")
@MainActor
struct CreateRecordViewModelTests {

    @Test("Coop team score stamps onto every player's draft")
    func teamScoreStampsOntoAllPlayers() {
        let hanabi = GameCatalog.find(slug: "hanabi")!
        let model = CreateRecordViewModel(game: hanabi)
        model.addPlayer()
        model.addPlayer()
        model.addPlayer()
        // Hand-edit names so canSubmit's blank check would pass; not strictly
        // required for buildDraft but keeps the fixture closer to the real flow.
        for i in model.players.indices { model.players[i].name = "P\(i)" }

        model.teamIntegers["score"] = 22
        model.teamBooleans["perfect_score"] = false
        model.teamBooleans["exploded"] = false
        model.teamWon = true

        let draft = model.buildDraft()
        #expect(draft.players.count == 3)
        for player in draft.players {
            if case .integer(let n) = player.endState["score"] {
                #expect(n == 22)
            } else {
                Issue.record("expected an integer score on every player")
            }
        }
    }

    @Test("Coop loss stamps team state even with empty winners")
    func coopLossStillStamps() {
        let hanabi = GameCatalog.find(slug: "hanabi")!
        let model = CreateRecordViewModel(game: hanabi)
        model.addPlayer()
        model.addPlayer()
        for i in model.players.indices { model.players[i].name = "P\(i)" }

        model.teamIntegers["score"] = 8
        model.teamBooleans["exploded"] = true
        model.teamWon = false  // team loss

        let draft = model.buildDraft()
        #expect(draft.winners.isEmpty)
        for player in draft.players {
            if case .integer(let n) = player.endState["score"] {
                #expect(n == 8)
            }
            if case .boolean(let b) = player.endState["exploded"] {
                #expect(b == true)
            }
        }
    }

    @Test("Competitive games keep per-player end state")
    func competitiveKeepsPerPlayerEndState() {
        let catan = GameCatalog.find(slug: "catan")!
        let model = CreateRecordViewModel(game: catan)
        model.addPlayer()
        model.addPlayer()
        model.players[0].name = "Alex"
        model.players[0].integers["settlements"] = 4
        model.players[1].name = "Bea"
        model.players[1].integers["settlements"] = 2
        model.winnerIndexes = [0]

        let draft = model.buildDraft()
        if case .integer(let n) = draft.players[0].endState["settlements"] {
            #expect(n == 4)
        }
        if case .integer(let n) = draft.players[1].endState["settlements"] {
            #expect(n == 2)
        }
    }
}
