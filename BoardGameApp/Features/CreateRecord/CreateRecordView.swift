import SwiftUI

struct CreateRecordView: View {
    @State private var model: CreateRecordViewModel
    @State private var showingRoster = false
    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataStore.self) private var userData

    init(game: GameDefinition, editing: GameRecord? = nil) {
        _model = State(initialValue: CreateRecordViewModel(game: game, editing: editing))
    }

    private var isEditing: Bool { model.editingID != nil }

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

                if let me = userData.players.first(where: \.isSelf), !model.hasSelf {
                    Button {
                        model.addPlayers(from: [me])
                    } label: {
                        Label("Add Me", systemImage: "person.crop.circle.badge.plus")
                    }
                }

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

            if !model.game.variantOptions.isEmpty {
                Section {
                    ForEach(model.game.variantOptions, id: \.self) { variant in
                        Toggle(isOn: Binding(
                            get: { model.selectedVariants.contains(variant) },
                            set: { on in
                                if on { model.selectedVariants.insert(variant) } else { model.selectedVariants.remove(variant) }
                            },
                        )) {
                            Text(variant.capitalized)
                        }
                        .disabled(!model.selectedVariants.contains(variant) && model.game.requiredVariantCount != nil && model.selectedVariants.count >= model.game.requiredVariantCount!)
                    }
                } header: {
                    if let count = model.game.requiredVariantCount {
                        Text("Scoring Criteria (\(model.selectedVariants.count)/\(count))")
                    } else {
                        Text("Variants")
                    }
                }
            }

            if model.game.isCooperative && !model.game.endStateFields.isEmpty {
                Section("Team Result") {
                    ForEach(model.game.endStateFields, id: \.key) { field in
                        EndStateFieldView(field: field, integers: $model.teamIntegers, booleans: $model.teamBooleans)
                    }
                }
            }

            Section(model.game.isCooperative ? "Outcome" : "Winners") {
                if model.players.isEmpty {
                    Text("Add players first").foregroundStyle(.secondary)
                } else if model.game.isCooperative {
                    Toggle("Team won this game", isOn: $model.teamWon)
                    Text(model.teamWon
                        ? "Every player will be recorded as a winner."
                        : "Nobody will be recorded as a winner — this is a team loss.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        .navigationTitle(isEditing ? "Edit \(model.game.displayName)" : model.game.displayName)
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
            if let record {
                if isEditing {
                    userData.replaceRecord(record)
                } else {
                    userData.prependRecord(record)
                }
                // Manual player entries get auto-rostered server-side; pull the
                // refreshed list so the new entries show up immediately.
                Task { await userData.refreshPlayers() }
                dismiss()
            }
        }
        .sheet(isPresented: $showingRoster) {
            RosterPickerSheet(alreadyPickedIDs: model.pickedSavedPlayerIDs) { picked in
                model.addPlayers(from: picked)
            }
        }
    }
}

#Preview {
    NavigationStack { CreateRecordView(game: GameCatalog.catan) }
        .environment(UserDataStore())
}
