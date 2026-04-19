import Foundation
import Observation

@MainActor
@Observable
final class CreateRecordViewModel {
    let game: GameDefinition

    var date: Date = .now
    var notes: String = ""
    var players: [PlayerEntry]
    var winnerIndexes: Set<Int> = []

    var isSubmitting: Bool = false
    var errorMessage: String?
    var didSubmit: GameRecord?

    init(game: GameDefinition) {
        self.game = game
        self.players = [PlayerEntry.blank(for: game), PlayerEntry.blank(for: game)]
    }

    var canSubmit: Bool {
        !isSubmitting &&
            players.count >= 1 &&
            players.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty } &&
            !winnerIndexes.isEmpty &&
            winnerIndexes.allSatisfy { $0 < players.count }
    }

    func addPlayer() {
        players.append(.blank(for: game))
    }

    func addPlayers(from saved: [SavedPlayer]) {
        players.append(contentsOf: saved.map { PlayerEntry.from(saved: $0, game: game) })
    }

    func removePlayer(at offsets: IndexSet) {
        players.remove(atOffsets: offsets)
        winnerIndexes = Set(winnerIndexes.compactMap { idx -> Int? in
            guard idx < players.count else { return nil }
            return idx
        })
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let draft = RecordDraft(
            game: game.slug,
            variants: [],
            yearPublished: game.yearPublished,
            date: Self.dateFormatter.string(from: date),
            playerCount: players.count,
            winners: winnerIndexes.sorted(),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            players: players.map { $0.toDraft(game: game) },
        )

        do {
            didSubmit = try await APIClient.shared.createRecord(draft)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Submission failed"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

struct PlayerEntry: Identifiable, Hashable {
    let id = UUID()
    var name: String = ""
    var email: String = ""
    var identity: String = ""
    var team: Int = 1
    var eliminated: Bool = false
    var integers: [String: Int]
    var booleans: [String: Bool]

    static func blank(for game: GameDefinition) -> PlayerEntry {
        var integers: [String: Int] = [:]
        var booleans: [String: Bool] = [:]
        for field in game.endStateFields {
            switch field {
            case .integer(let key, _, let min, _): integers[key] = min
            case .boolean(let key, _): booleans[key] = false
            }
        }
        return PlayerEntry(integers: integers, booleans: booleans)
    }

    static func from(saved: SavedPlayer, game: GameDefinition) -> PlayerEntry {
        var entry = PlayerEntry.blank(for: game)
        entry.name = saved.name
        entry.email = saved.email ?? ""
        return entry
    }

    func toDraft(game: GameDefinition) -> PlayerDraft {
        var endState: [String: EndStateValue] = [:]
        for field in game.endStateFields {
            switch field {
            case .integer(let key, _, _, _):
                endState[key] = .integer(integers[key] ?? 0)
            case .boolean(let key, _):
                endState[key] = .boolean(booleans[key] ?? false)
            }
        }
        return PlayerDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email,
            identity: identity.isEmpty ? nil : identity,
            team: game.supportsTeams ? team : nil,
            eliminated: game.supportsElimination ? eliminated : nil,
            endState: endState,
        )
    }
}
