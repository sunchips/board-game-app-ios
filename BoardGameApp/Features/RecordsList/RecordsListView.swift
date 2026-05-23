import SwiftUI

struct RecordsListView: View {
    @Environment(UserDataStore.self) private var userData
    @State private var selectedGame: String? = nil

    private var visibleRecords: [GameRecord] {
        guard let slug = selectedGame else { return userData.records }
        return userData.records.filter { $0.game == slug }
    }

    var body: some View {
        Group {
            if userData.isHydrating && userData.records.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = userData.errorMessage, userData.records.isEmpty {
                ContentUnavailableView(
                    "Couldn't load records",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message),
                )
            } else if visibleRecords.isEmpty {
                ContentUnavailableView(
                    "No records yet",
                    systemImage: "tray",
                    description: Text("Submit a session from the Create tab to see it here."),
                )
            } else {
                List(visibleRecords) { record in
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
                    Button("All games") { selectedGame = nil }
                    Divider()
                    ForEach(GameCatalog.all) { g in
                        Button(g.displayName) { selectedGame = g.slug }
                    }
                } label: {
                    Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .navigationDestination(for: GameRecord.self) { record in
            RecordDetailView(record: record)
        }
        .refreshable { await userData.refreshRecords() }
    }

    private var filterLabel: String {
        guard let slug = selectedGame else { return "All" }
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
        .environment(UserDataStore())
}
