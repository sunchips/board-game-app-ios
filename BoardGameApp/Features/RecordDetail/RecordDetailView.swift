import SwiftUI

struct RecordDetailView: View {
    let record: GameRecord

    @Environment(UserDataStore.self) private var userData
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isEditing = false

    private var gameDefinition: GameDefinition? { GameCatalog.find(slug: record.game) }
    private var displayName: String { gameDefinition?.displayName ?? record.game }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(record.game)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.title2.weight(.bold))
                        Text(record.date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Label("\(record.playerCount) players", systemImage: "person.2")
                            if !record.variants.isEmpty {
                                Label(record.variants.joined(separator: ", "), systemImage: "sparkles")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let year = record.yearPublished {
                Section("Details") {
                    LabeledContent("Year Published", value: "\(year)")
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if gameDefinition != nil {
                        Button { isEditing = true } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .disabled(isDeleting)
            }
        }
        .sheet(isPresented: $isEditing) {
            if let game = gameDefinition {
                let current = userData.records.first(where: { $0.id == record.id }) ?? record
                NavigationStack {
                    CreateRecordView(game: game, editing: current)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { isEditing = false }
                            }
                        }
                }
            }
        }
        .confirmationDialog(
            "Delete this record?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible,
        ) {
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the \(displayName) session from \(record.date).")
        }
    }

    private func performDelete() async {
        isDeleting = true
        defer { isDeleting = false }
        if await userData.deleteRecord(id: record.id) {
            dismiss()
        }
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
