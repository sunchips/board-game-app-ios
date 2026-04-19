import SwiftUI
import Observation

@MainActor
@Observable
final class RecordsListViewModel {
    var records: [GameRecord] = []
    var selectedGame: String? = nil
    var isLoading: Bool = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            records = try await APIClient.shared.listRecords(game: selectedGame)
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Failed to load records"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RecordsListView: View {
    @State private var model = RecordsListViewModel()

    var body: some View {
        Group {
            if model.isLoading && model.records.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = model.errorMessage, model.records.isEmpty {
                ContentUnavailableView("Couldn't load records", systemImage: "wifi.exclamationmark", description: Text(message))
            } else if model.records.isEmpty {
                ContentUnavailableView("No records yet", systemImage: "tray", description: Text("Submit a session from the Create tab to see it here."))
            } else {
                List(model.records) { record in
                    NavigationLink(value: record) {
                        RecordRow(record: record)
                    }
                }
            }
        }
        .navigationTitle("Records")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("All games") { model.selectedGame = nil; Task { await model.load() } }
                    Divider()
                    ForEach(GameCatalog.all) { g in
                        Button(g.displayName) { model.selectedGame = g.slug; Task { await model.load() } }
                    }
                } label: {
                    Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .navigationDestination(for: GameRecord.self) { record in
            RecordDetailView(record: record)
        }
        .refreshable { await model.load() }
        .task { await model.load() }
    }

    private var filterLabel: String {
        guard let slug = model.selectedGame else { return "All" }
        return GameCatalog.find(slug: slug)?.displayName ?? slug
    }
}

private struct RecordRow: View {
    let record: GameRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(GameCatalog.find(slug: record.game)?.displayName ?? record.game)
                    .font(.headline)
                Spacer()
                Text(record.date).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Label("\(record.playerCount)", systemImage: "person.2")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !record.winners.isEmpty {
                    let winnerNames = record.winners.compactMap { idx -> String? in
                        guard idx < record.players.count else { return nil }
                        return record.players[idx].name
                    }
                    Text("Winner: \(winnerNames.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { RecordsListView() }
}
