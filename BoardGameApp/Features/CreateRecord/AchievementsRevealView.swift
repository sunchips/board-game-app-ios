import SwiftUI

struct AchievementsRevealView: View {
    let earnedAchievements: [(playerName: String, achievement: GameAchievement)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(earnedAchievements.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 14) {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.achievement.name)
                                .font(.headline)
                            Text(entry.achievement.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(entry.playerName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Achievements Unlocked!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static func check(
        game: GameDefinition,
        players: [PlayerEntry]
    ) -> [(playerName: String, achievement: GameAchievement)] {
        guard !game.achievements.isEmpty else { return [] }
        var earned: [(String, GameAchievement)] = []
        for player in players {
            let name = player.name.trimmingCharacters(in: .whitespaces)
            for achievement in game.achievements {
                if achievement.isMet(integers: player.integers, booleans: player.booleans) {
                    earned.append((name.isEmpty ? "Player" : name, achievement))
                }
            }
        }
        return earned
    }
}
