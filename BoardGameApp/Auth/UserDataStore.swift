import Foundation
import Observation

/// Single source of truth for the signed-in user's content. `AuthStore` calls
/// `hydrate()` the moment a session lands. Players and records are fetched
/// in parallel via independent endpoints — each surface updates as its data
/// arrives, so the slower tail call (usually records) doesn't gate the other.
/// Pull-to-refresh on either tab uses the same per-section refresh method.
@MainActor
@Observable
final class UserDataStore {
    var players: [SavedPlayer] = []
    var records: [GameRecord] = []
    /// First page only; older records load on demand via `loadMoreRecords()`.
    /// Set true once a page comes back short of the page size.
    private(set) var allRecordsLoaded: Bool = false
    var isHydratingPlayers: Bool = false
    var isHydratingRecords: Bool = false
    var isLoadingMoreRecords: Bool = false
    var errorMessage: String?

    /// True while either bucket is filling. Used by views that want a single
    /// "anything-loading" indicator (e.g. a toolbar spinner).
    var isHydrating: Bool { isHydratingPlayers || isHydratingRecords }

    /// Wall-clock of last successful refresh per bucket. Views can use these
    /// to gate background refreshes on tab reappearance (skip if recent).
    private(set) var playersLastLoadedAt: Date?
    private(set) var recordsLastLoadedAt: Date?

    /// Initial fetch size — small enough to render fast on a cold session,
    /// large enough that most users never hit "Load more".
    private static let initialRecordsPageSize = 50
    /// Subsequent page size when loading more.
    private static let recordsPageSize = 100

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
        allRecordsLoaded = false
        errorMessage = nil
        playersLastLoadedAt = nil
        recordsLastLoadedAt = nil
    }

    /// Kick off both fetches in parallel. Each tab observes its own loading
    /// flag and array independently, so the UI fills incrementally — the
    /// faster response paints first and the screen never sits empty waiting
    /// on the slower one.
    func hydrate() async {
        guard session != nil else { return }
        errorMessage = nil
        async let players: Void = refreshPlayers()
        async let records: Void = refreshRecords()
        _ = await (players, records)
    }

    func refreshPlayers() async {
        isHydratingPlayers = true
        defer { isHydratingPlayers = false }
        do {
            let fetched = try await APIClient.shared.listSavedPlayers()
            players = fetched.sorted { $0.name.lowercased() < $1.name.lowercased() }
            playersLastLoadedAt = Date()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRecords(game: String? = nil) async {
        isHydratingRecords = true
        defer { isHydratingRecords = false }
        do {
            let limit = Self.initialRecordsPageSize
            let fetched = try await APIClient.shared.listRecords(game: game, limit: limit)
            records = fetched
            allRecordsLoaded = fetched.count < limit
            recordsLastLoadedAt = Date()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Append the next page of older records. Triggered by the bottom-of-list
    /// sentinel in RecordsListView. No-op if we've already loaded everything
    /// or another page fetch is in flight.
    func loadMoreRecords() async {
        guard !isLoadingMoreRecords, !allRecordsLoaded, session != nil else { return }
        isLoadingMoreRecords = true
        defer { isLoadingMoreRecords = false }
        do {
            // The server doesn't support keyset pagination yet, so we ask for
            // the running total + one page and slice off what we already have.
            // Cheap until the user has thousands of records, at which point
            // server-side pagination becomes worth adding.
            let want = records.count + Self.recordsPageSize
            let fetched = try await APIClient.shared.listRecords(game: nil, limit: want)
            allRecordsLoaded = fetched.count < want
            records = fetched
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
