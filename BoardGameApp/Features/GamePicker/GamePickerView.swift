import SwiftUI

struct GamePickerView: View {
    @State private var searchText = ""
    @State private var showGrid = true

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private var filteredGames: [GameDefinition] {
        guard !searchText.isEmpty else { return GameCatalog.all }
        let query = searchText.lowercased()
        return GameCatalog.all.filter { $0.displayName.lowercased().contains(query) }
    }

    var body: some View {
        Group {
            if filteredGames.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if showGrid {
                gridView
            } else {
                listView
            }
        }
        .navigationTitle("Pick a Game")
        .searchable(text: $searchText, prompt: "Search games")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showGrid.toggle() }
                } label: {
                    Image(systemName: showGrid ? "list.bullet" : "square.grid.2x2")
                }
            }
        }
        .navigationDestination(for: GameDefinition.self) { game in
            CreateRecordView(game: game)
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredGames) { game in
                    NavigationLink(value: game) {
                        GameCard(game: game)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var listView: some View {
        List(filteredGames) { game in
            NavigationLink(value: game) {
                GameRow(game: game)
            }
        }
    }
}

private struct GameCard: View {
    let game: GameDefinition

    var body: some View {
        VStack(spacing: 0) {
            Image(game.slug)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(subtitle(for: game))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

private struct GameRow: View {
    let game: GameDefinition

    var body: some View {
        HStack(spacing: 12) {
            Image(game.slug)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayName)
                    .font(.headline)
                Text(subtitle(for: game))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private func subtitle(for game: GameDefinition) -> String {
    var parts: [String] = []
    if !game.identityOptions.isEmpty {
        parts.append("\(game.identityOptions.count) identities")
    }
    parts.append("\(game.endStateFields.count) fields")
    if game.supportsTeams { parts.append("teams") }
    if game.supportsElimination { parts.append("elimination") }
    return parts.joined(separator: " · ")
}

#Preview {
    NavigationStack { GamePickerView() }
}
