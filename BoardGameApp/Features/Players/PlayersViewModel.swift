import Foundation
import Observation

@MainActor
@Observable
final class PlayersViewModel {
    var players: [SavedPlayer] = []
    var isLoading: Bool = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            players = try await APIClient.shared.listSavedPlayers()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Failed to load players"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(name: String, email: String?, notes: String?) async throws {
        let draft = SavedPlayerDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        )
        let created = try await APIClient.shared.createSavedPlayer(draft)
        players = (players + [created]).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func update(id: UUID, name: String, email: String?, notes: String?) async throws {
        let draft = SavedPlayerDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        )
        let updated = try await APIClient.shared.updateSavedPlayer(id: id, body: draft)
        if let index = players.firstIndex(where: { $0.id == id }) {
            players[index] = updated
            players.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
    }

    func delete(_ player: SavedPlayer) async {
        do {
            try await APIClient.shared.deleteSavedPlayer(id: player.id)
            players.removeAll { $0.id == player.id }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Failed to delete"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
