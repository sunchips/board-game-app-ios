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
    var selectedVariants: Set<String> = []

    /// Cooperative games share an end state — everyone scores the same. These
    /// hold the shared values; at submit time they're stamped onto every
    /// player's draft. Initialised with the game's defaults (mins / false).
    var teamIntegers: [String: Int]
    var teamBooleans: [String: Bool]

    var isSubmitting: Bool = false
    var errorMessage: String?
    var didSubmit: GameRecord?

    /// If non-nil, submit() PUTs against this record's id instead of POSTing
    /// a new one. The view drives the create-vs-update distinction by passing
    /// `editing:` at init time.
    let editingID: UUID?

    init(game: GameDefinition, editing: GameRecord? = nil) {
        self.game = game
        self.editingID = editing?.id

        var ints: [String: Int] = [:]
        var bools: [String: Bool] = [:]
        for field in game.endStateFields {
            switch field {
            case .integer(let key, _, let min, _, _): ints[key] = min
            case .boolean(let key, _, _): bools[key] = false
            }
        }
        self.teamIntegers = ints
        self.teamBooleans = bools

        if let editing {
            self.notes = editing.notes ?? ""
            self.date = Self.dateFormatter.date(from: editing.date) ?? .now
            self.players = editing.players.map { PlayerEntry.from(player: $0, game: game) }
            self.winnerIndexes = Set(editing.winners)
            self.selectedVariants = Set(editing.variants)
            // Cooperative: the per-player end_states are all identical (we
            // stamp from teamIntegers/teamBooleans at create time). Seed the
            // team fields from the first player so the Team Result section
            // reflects what's on disk.
            if game.isCooperative, let firstPlayer = editing.players.first {
                for field in game.endStateFields {
                    switch field {
                    case .integer(let key, _, _, _, _):
                        if case .integer(let v) = firstPlayer.endState[key] { self.teamIntegers[key] = v }
                    case .boolean(let key, _, _):
                        if case .boolean(let v) = firstPlayer.endState[key] { self.teamBooleans[key] = v }
                    }
                }
            }
        } else {
            self.players = []
        }
    }

    var canSubmit: Bool {
        !isSubmitting &&
            players.count >= 1 &&
            players.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty } &&
            (game.isCooperative || !winnerIndexes.isEmpty) &&
            winnerIndexes.allSatisfy { $0 < players.count } &&
            (game.requiredVariantCount == nil || selectedVariants.count == game.requiredVariantCount)
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
        autoDetectAchievements()
        let playerDrafts = players.map { entry -> PlayerDraft in
            guard game.isCooperative else { return entry.toDraft(game: game) }
            var copy = entry
            copy.integers = teamIntegers
            copy.booleans = teamBooleans
            return copy.toDraft(game: game)
        }
        return RecordDraft(
            game: game.slug,
            variants: selectedVariants.sorted(),
            yearPublished: game.yearPublished,
            date: Self.dateFormatter.string(from: date),
            playerCount: players.count,
            winners: winnerIndexes.sorted(),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            players: playerDrafts,
        )
    }

    private func autoDetectAchievements() {
        guard !game.achievements.isEmpty else { return }
        for i in players.indices {
            for achievement in game.achievements {
                if achievement.isMet(integers: players[i].integers, booleans: players[i].booleans) {
                    players[i].booleans[achievement.slug] = true
                }
            }
        }
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let draft = buildDraft()
            didSubmit = if let editingID {
                try await APIClient.shared.updateRecord(id: editingID, body: draft)
            } else {
                try await APIClient.shared.createRecord(draft)
            }
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
            case .integer(let key, _, let min, _, _): integers[key] = min
            case .boolean(let key, _, _): booleans[key] = false
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

    /// Populate from a previously-saved RecordPlayer (the edit-record path).
    /// Pulls integers/booleans back out of the typed end_state map and rebinds
    /// savedPlayerID so the server skips its find-or-create on update.
    static func from(player: RecordPlayer, game: GameDefinition) -> PlayerEntry {
        var entry = PlayerEntry.blank(for: game)
        entry.savedPlayerID = player.savedPlayerID
        entry.name = player.name
        entry.email = player.email ?? ""
        entry.identity = player.identity ?? ""
        entry.team = player.team ?? 1
        entry.eliminated = player.eliminated ?? false
        for (key, value) in player.endState {
            switch value {
            case .integer(let i): entry.integers[key] = i
            case .boolean(let b): entry.booleans[key] = b
            }
        }
        return entry
    }

    func toDraft(game: GameDefinition) -> PlayerDraft {
        var endState: [String: EndStateValue] = [:]
        for field in game.endStateFields {
            switch field {
            case .integer(let key, _, _, _, _):
                endState[key] = .integer(integers[key] ?? 0)
            case .boolean(let key, _, _):
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
            savedPlayerID: savedPlayerID,
        )
    }
}
