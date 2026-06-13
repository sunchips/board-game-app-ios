import SwiftUI

struct GamePickerView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(GameCatalog.all) { game in
                    NavigationLink(value: game) {
                        GameCard(game: game)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Pick a Game")
        .navigationDestination(for: GameDefinition.self) { game in
            CreateRecordView(game: game)
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

                Text(subtitle)
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

    private var subtitle: String {
        var parts: [String] = []
        if !game.identityOptions.isEmpty {
            parts.append("\(game.identityOptions.count) identities")
        }
        parts.append("\(game.endStateFields.count) fields")
        if game.supportsTeams { parts.append("teams") }
        if game.supportsElimination { parts.append("elimination") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { GamePickerView() }
}
