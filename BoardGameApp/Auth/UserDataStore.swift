import Foundation
import Observation

/// Single source of truth for the signed-in user's content. `AuthStore` calls
/// `hydrate(from:)` the moment a session lands (whether fresh sign-in or
/// restore from Keychain), so the Records and Players tabs render instantly
/// with whatever was on the server at launch. Pull-to-refresh on either tab
/// then uses the dedicated `refresh*` methods.
@MainActor
@Observable
final class UserDataStore {
    var players: [SavedPlayer] = []
    var records: [GameRecord] = []
    var isHydrating: Bool = false
    var errorMessage: String?

    /// Latest full-bundle fetch time — views can decide whether to kick a
    /// background refresh (e.g. on tab appear) based on this.
    private(set) var lastHydratedAt: Date?

    /// True between an Apple sign-in succeeding and the first bundle landing.
    /// The login screen watches this to keep the spinner up and avoid a split
    /// second of empty tabs.
    var isInitialLoad: Bool { session != nil && lastHydratedAt == nil && isHydrating }

    private var session: AuthSession?

    func attach(session: AuthSession?) async {
        self.session = session
        guard session != nil else {
            clear()
            return
        }
        await hydrate()
    }

    func clear() {
        players = []
        records = []
        errorMessage = nil
        lastHydratedAt = nil
    }

    /// Pull everything the app needs in one authenticated round-trip.
    func hydrate() async {
        guard session != nil else { return }
        isHydrating = true
        errorMessage = nil
        defer { isHydrating = false }
        do {
            let bundle = try await APIClient.shared.fetchSessionBundle()
            players = bundle.players.sorted { $0.name.lowercased() < $1.name.lowercased() }
            records = bundle.records
            lastHydratedAt = Date()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Couldn't load your data"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPlayers() async {
        do {
            let fetched = try await APIClient.shared.listSavedPlayers()
            players = fetched.sorted { $0.name.lowercased() < $1.name.lowercased() }
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRecords(game: String? = nil) async {
        do {
            records = try await APIClient.shared.listRecords(game: game)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Local mutations that mirror successful API writes

    func upsert(player: SavedPlayer) {
        if let idx = players.firstIndex(where: { $0.id == player.id }) {
            players[idx] = player
        } else {
            players.append(player)
        }
        players.sort { $0.name.lowercased() < $1.name.lowercased() }
    }

    func remove(playerID: UUID) {
        players.removeAll { $0.id == playerID }
    }

    func prependRecord(_ record: GameRecord) {
        records.insert(record, at: 0)
    }

    func replaceRecord(_ record: GameRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            // Edge case: editing a record we don't currently have locally.
            // Prepend so the user sees their change immediately.
            records.insert(record, at: 0)
        }
    }

    func remove(recordID: UUID) {
        records.removeAll { $0.id == recordID }
    }

    /// API call + local prune in one place so the views don't have to
    /// coordinate. Returns `true` on success, `false` on failure (and surfaces
    /// the error via `errorMessage`). Idempotent server-side — a 404 means the
    /// row was already gone, which we treat as success for the local store.
    @discardableResult
    func deleteRecord(id: UUID) async -> Bool {
        do {
            try await APIClient.shared.deleteRecord(id: id)
            remove(recordID: id)
            return true
        } catch let apiError as APIError {
            if apiError.status == 404 {
                remove(recordID: id)
                return true
            }
            errorMessage = apiError.errorDescription ?? "Couldn't delete record"
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
