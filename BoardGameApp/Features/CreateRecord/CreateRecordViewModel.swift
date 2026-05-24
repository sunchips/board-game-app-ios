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

    /// Cooperative games share an end state — everyone scores the same. These
    /// hold the shared values; at submit time they're stamped onto every
    /// player's draft. Initialised with the game's defaults (mins / false).
    var teamIntegers: [String: Int]
    var teamBooleans: [String: Bool]

    var isSubmitting: Bool = false
    var errorMessage: String?
    var didSubmit: GameRecord?

    init(game: GameDefinition) {
        self.game = game
        self.players = []
        var ints: [String: Int] = [:]
        var bools: [String: Bool] = [:]
        for field in game.endStateFields {
            switch field {
            case .integer(let key, _, let min, _): ints[key] = min
            case .boolean(let key, _): bools[key] = false
            }
        }
        self.teamIntegers = ints
        self.teamBooleans = bools
    }

    var canSubmit: Bool {
        !isSubmitting &&
            players.count >= 1 &&
            players.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty } &&
            // Cooperative games are all-or-nothing: an empty winnerIndexes set
            // encodes a team loss, which is a valid record. Competitive games
            // still require at least one winner.
            (game.isCooperative || !winnerIndexes.isEmpty) &&
            winnerIndexes.allSatisfy { $0 < players.count }
    }

    /// Coop-only convenience: mirror of `winnerIndexes` as a single Bool.
    /// `true` means every player index is a winner; `false` means the
    /// `winnerIndexes` set is empty. Reads/writes are valid only when
    /// `game.isCooperative` is true — the view gates on it.
    var teamWon: Bool {
        get { !winnerIndexes.isEmpty }
        set {
            winnerIndexes = newValue ? Set(players.indices) : []
        }
    }

    func addPlayer() {
        players.append(.blank(for: game))
        syncCooperativeWinners()
    }

    func addPlayers(from saved: [SavedPlayer]) {
        // Skip anyone already represented by their SavedPlayer.id — the picker
        // also filters these out, but this is the model-layer safety net so a
        // future call site can't accidentally double-add.
        let already = pickedSavedPlayerIDs
        let fresh = saved.filter { !already.contains($0.id) }
        players.append(contentsOf: fresh.map { PlayerEntry.from(saved: $0, game: game) })
        syncCooperativeWinners()
    }

    var hasSelf: Bool { players.contains(where: \.isSelf) }

    /// SavedPlayer ids currently represented in the draft. Used by the roster
    /// picker to disable rows that would otherwise be duplicate-adds.
    var pickedSavedPlayerIDs: Set<UUID> {
        Set(players.compactMap(\.savedPlayerID))
    }

    func removePlayer(at offsets: IndexSet) {
        players.remove(atOffsets: offsets)
        winnerIndexes = Set(winnerIndexes.compactMap { idx -> Int? in
            guard idx < players.count else { return nil }
            return idx
        })
        syncCooperativeWinners()
    }

    /// Maintain the all-or-nothing invariant for cooperative games as players
    /// are added or removed: if any winner was marked, every player index is a
    /// winner; otherwise none are. No-op for competitive games.
    private func syncCooperativeWinners() {
        guard game.isCooperative else { return }
        if !winnerIndexes.isEmpty {
            winnerIndexes = Set(players.indices)
        }
    }

    /// Snapshot the current form into a wire-format draft. Pure / sync so it
    /// can be unit-tested without standing up an APIClient. `submit()` is the
    /// only production caller.
    func buildDraft() -> RecordDraft {
        let playerDrafts = players.map { entry -> PlayerDraft in
            // Cooperative: stamp the shared team end-state onto every player
            // at submit time. The UI only exposes one input per field.
            guard game.isCooperative else { return entry.toDraft(game: game) }
            var copy = entry
            copy.integers = teamIntegers
            copy.booleans = teamBooleans
            return copy.toDraft(game: game)
        }
        return RecordDraft(
            game: game.slug,
            variants: [],
            yearPublished: game.yearPublished,
            date: Self.dateFormatter.string(from: date),
            playerCount: players.count,
            winners: winnerIndexes.sorted(),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            players: playerDrafts,
        )
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            didSubmit = try await APIClient.shared.createRecord(buildDraft())
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
    /// When this entry was populated from a row in the saved-player roster,
    /// this captures the SavedPlayer.id so duplicate-add affordances can
    /// recognise the player without resorting to fragile name matching.
    /// `nil` for manual entries.
    var savedPlayerID: UUID? = nil
    var name: String = ""
    var email: String = ""
    var identity: String = ""
    var team: Int = 1
    var eliminated: Bool = false
    var isSelf: Bool = false
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
        entry.savedPlayerID = saved.id
        entry.name = saved.name
        entry.email = saved.email ?? ""
        entry.isSelf = saved.isSelf
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
