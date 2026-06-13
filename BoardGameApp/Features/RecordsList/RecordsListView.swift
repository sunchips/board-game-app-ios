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
            if userData.isHydratingRecords && userData.records.isEmpty {
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
                List {
                    ForEach(visibleRecords) { record in
                        NavigationLink(value: record) {
                            RecordRow(record: record)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { visibleRecords[$0].id }
                        Task {
                            for id in ids { await userData.deleteRecord(id: id) }
                        }
                    }

                    if !userData.allRecordsLoaded && selectedGame == nil {
                        HStack {
                            Spacer()
                            if userData.isLoadingMoreRecords {
                                ProgressView()
                            } else {
                                Color.clear.frame(height: 1)
                                    .onAppear {
                                        Task { await userData.loadMoreRecords() }
                                    }
                            }
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
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
                        Button {
                            selectedGame = g.slug
                        } label: {
                            Label(g.displayName, image: g.slug)
                        }
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

    private var gameName: String {
        GameCatalog.find(slug: record.game)?.displayName ?? record.game
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(record.game)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(gameName)
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
                            .lineLimit(1)
                    }
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
