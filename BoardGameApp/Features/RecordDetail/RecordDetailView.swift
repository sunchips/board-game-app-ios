import SwiftUI

struct RecordDetailView: View {
    let record: GameRecord

    private var gameDefinition: GameDefinition? { GameCatalog.find(slug: record.game) }
    private var displayName: String { gameDefinition?.displayName ?? record.game }

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Game", value: displayName)
                if let year = record.yearPublished {
                    LabeledContent("Year Published", value: "\(year)")
                }
                LabeledContent("Date", value: record.date)
                LabeledContent("Players", value: "\(record.playerCount)")
                if !record.variants.isEmpty {
                    LabeledContent("Variants", value: record.variants.joined(separator: ", "))
                }
            }

            if !record.winners.isEmpty {
                Section("Winners") {
                    ForEach(record.winners, id: \.self) { idx in
                        if idx < record.players.count {
                            let p = record.players[idx]
                            Label(p.name, systemImage: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }

            Section("Players") {
                ForEach(Array(record.players.enumerated()), id: \.offset) { offset, player in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(player.name).font(.headline)
                            if record.winners.contains(offset) {
                                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            }
                        }
                        if let identity = player.identity {
                            Text(identity.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let team = player.team {
                            Text("Team \(team)").font(.caption).foregroundStyle(.secondary)
                        }
                        if player.eliminated == true {
                            Text("Eliminated").font(.caption).foregroundStyle(.red)
                        }
                        ForEach(orderedEndStateKeys(for: player), id: \.self) { key in
                            if let value = player.endState[key] {
                                HStack {
                                    Text(label(for: key))
                                    Spacer()
                                    Text(value.displayString)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let notes = record.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            Section {
                LabeledContent("Record ID", value: record.id.uuidString.prefix(8) + "…")
                LabeledContent("Created", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func orderedEndStateKeys(for player: RecordPlayer) -> [String] {
        if let def = gameDefinition {
            let defined = def.endStateFields.map(\.key)
            let definedSet = Set(defined)
            let extras = player.endState.keys.filter { !definedSet.contains($0) }.sorted()
            return defined.filter { player.endState[$0] != nil } + extras
        }
        return player.endState.keys.sorted()
    }

    private func label(for key: String) -> String {
        if let field = gameDefinition?.endStateFields.first(where: { $0.key == key }) {
            return field.label
        }
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
