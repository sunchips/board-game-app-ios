import Foundation
import Observation

/// Single source of truth for the signed-in user's content. `AuthStore` calls
/// `hydrate()` the moment a session lands. Players and records are fetched
/// in parallel via independent endpoints — each surface updates as its data
/// arrives, so the slower tail call (usually records) doesn't gate the other.
/// Pull-to-refresh on either tab uses the same per-section refresh method.
///
/// A disk snapshot mirrors the in-memory state so the next cold launch can
/// render the tabs immediately from cache while the network catches up.
/// Cache is per-user (keyed by AuthSession.user.id) and is cleared on sign-out.
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

    /// Last persisted snapshot wall-clock time. Views can show it as a
    /// "Last updated …" footer if they want.
    private(set) var snapshotLoadedAt: Date?

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
        guard let session else {
            clear()
            return
        }
        // Restore cached state synchronously first so the tabs render
        // immediately on relaunch instead of waiting on the network.
        loadSnapshot(for: session.user.id)
        await hydrate()
    }

    func clear() {
        players = []
        records = []
        allRecordsLoaded = false
        errorMessage = nil
        playersLastLoadedAt = nil
        recordsLastLoadedAt = nil
        snapshotLoadedAt = nil
        if let url = currentSnapshotURL() {
            try? FileManager.default.removeItem(at: url)
        }
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
            saveSnapshot()
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
            saveSnapshot()
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
            saveSnapshot()
            return true
        } catch let apiError as APIError {
            if apiError.status == 404 {
                remove(recordID: id)
                saveSnapshot()
                return true
            }
            errorMessage = apiError.errorDescription ?? "Couldn't delete record"
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Snapshot persistence

    private struct Snapshot: Codable {
        let players: [SavedPlayer]
        let records: [GameRecord]
        let savedAt: Date
    }

    private static let snapshotEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let snapshotDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func snapshotURL(for userID: UUID) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches.appending(path: "snapshot-\(userID.uuidString).json")
    }

    private func currentSnapshotURL() -> URL? {
        guard let userID = session?.user.id else { return nil }
        return snapshotURL(for: userID)
    }

    private func loadSnapshot(for userID: UUID) {
        guard let url = snapshotURL(for: userID),
              let data = try? Data(contentsOf: url),
              let snapshot = try? Self.snapshotDecoder.decode(Snapshot.self, from: data)
        else { return }
        // Don't clobber fresh state if hydrate already landed.
        if players.isEmpty { players = snapshot.players }
        if records.isEmpty { records = snapshot.records }
        snapshotLoadedAt = snapshot.savedAt
    }

    private func saveSnapshot() {
        guard let url = currentSnapshotURL() else { return }
        let snapshot = Snapshot(players: players, records: records, savedAt: Date())
        // Fire-and-forget write on a detached task so we never block the UI.
        Task.detached(priority: .utility) { [snapshot] in
            guard let data = try? Self.snapshotEncoder.encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
