import SwiftUI

struct CreateRecordView: View {
    @State private var model: CreateRecordViewModel
    @State private var showingRoster = false
    @Environment(\.dismiss) private var dismiss

    init(game: GameDefinition) {
        _model = State(initialValue: CreateRecordViewModel(game: game))
    }

    var body: some View {
        Form {
            Section("Session") {
                DatePicker("Date", selection: $model.date, displayedComponents: .date)
                if let year = model.game.yearPublished {
                    LabeledContent("Year Published", value: "\(year)")
                }
            }

            Section("Players") {
                ForEach($model.players) { $entry in
                    PlayerEditorView(entry: $entry, game: model.game)
                }
                .onDelete { model.removePlayer(at: $0) }

                Button {
                    showingRoster = true
                } label: {
                    Label("Pick from Roster", systemImage: "person.2.circle.fill")
                }

                Button {
                    model.addPlayer()
                } label: {
                    Label("Add Player Manually", systemImage: "plus.circle.fill")
                }
            }

            Section("Winners") {
                if model.players.isEmpty {
                    Text("Add players first").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.players.enumerated()), id: \.element.id) { index, entry in
                        Toggle(isOn: Binding(
                            get: { model.winnerIndexes.contains(index) },
                            set: { on in
                                if on { model.winnerIndexes.insert(index) } else { model.winnerIndexes.remove(index) }
                            },
                        )) {
                            Text(entry.name.isEmpty ? "Player \(index + 1)" : entry.name)
                        }
                    }
                }
            }

            Section("Notes") {
                TextField("Optional", text: $model.notes, axis: .vertical)
                    .lineLimit(3...8)
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(model.game.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!model.canSubmit)
            }
        }
        .onChange(of: model.didSubmit) { _, record in
            if record != nil { dismiss() }
        }
        .sheet(isPresented: $showingRoster) {
            RosterPickerSheet { picked in
                model.addPlayers(from: picked)
            }
        }
    }
}

#Preview {
    NavigationStack { CreateRecordView(game: GameCatalog.catan) }
}
