import SwiftUI

struct GamePickerView: View {
    var body: some View {
        List(GameCatalog.all) { game in
            NavigationLink(value: game) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.displayName).font(.headline)
                    Text(subtitle(for: game))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Pick a Game")
        .navigationDestination(for: GameDefinition.self) { game in
            CreateRecordView(game: game)
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
        if let year = game.yearPublished { parts.append("published \(year)") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { GamePickerView() }
}
