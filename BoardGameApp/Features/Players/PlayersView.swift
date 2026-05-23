import SwiftUI

struct PlayersView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(UserDataStore.self) private var userData
    @State private var showingAdd = false
    @State private var editing: SavedPlayer?
    @State private var mutationError: String?

    var body: some View {
        Group {
            if userData.isHydrating && userData.players.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = userData.errorMessage, userData.players.isEmpty {
                ContentUnavailableView(
                    "Couldn't load players",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(message),
                )
            } else if userData.players.isEmpty {
                ContentUnavailableView(
                    "No players yet",
                    systemImage: "person.2.badge.plus",
                    description: Text("Add the people you play with so you can pick them quickly next time."),
                )
                .overlay(alignment: .bottom) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Player", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 32)
                }
            } else {
                List {
                    ForEach(userData.players) { player in
                        Button { editing = player } label: {
                            PlayerRow(player: player)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let victims = offsets.map { userData.players[$0] }
                        Task {
                            for p in victims { await delete(p) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Players")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    if let name = auth.session?.user.displayName, !name.isEmpty {
                        Text(name)
                    }
                    if let email = auth.session?.user.email {
                        Text(email)
                    }
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            PlayerEditSheet(title: "New Player") { name, email, notes in
                try await create(name: name, email: email, notes: notes)
            }
        }
        .sheet(item: $editing) { player in
            PlayerEditSheet(title: "Edit Player", initial: player) { name, email, notes in
                try await update(id: player.id, name: name, email: email, notes: notes)
            }
        }
        .refreshable { await userData.refreshPlayers() }
    }

    @MainActor
    private func create(name: String, email: String?, notes: String?) async throws {
        let draft = SavedPlayerDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        )
        let created = try await APIClient.shared.createSavedPlayer(draft)
        userData.upsert(player: created)
    }

    @MainActor
    private func update(id: UUID, name: String, email: String?, notes: String?) async throws {
        let draft = SavedPlayerDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
        )
        let updated = try await APIClient.shared.updateSavedPlayer(id: id, body: draft)
        userData.upsert(player: updated)
    }

    @MainActor
    private func delete(_ player: SavedPlayer) async {
        do {
            try await APIClient.shared.deleteSavedPlayer(id: player.id)
            userData.remove(playerID: player.id)
        } catch let apiError as APIError {
            mutationError = apiError.errorDescription
        } catch {
            mutationError = error.localizedDescription
        }
    }
}

private struct PlayerRow: View {
    let player: SavedPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.name).font(.headline)
            if let email = player.email {
                Text(email).font(.caption).foregroundStyle(.secondary)
            }
            if let notes = player.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct PlayerEditSheet: View {
    let title: String
    var initial: SavedPlayer? = nil
    var onSave: @MainActor (String, String?, String?) async throws -> Void

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).textInputAutocapitalization(.words)
                    TextField("Email (optional)", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                }
                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let message = errorMessage {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let initial {
                    name = initial.name
                    email = initial.email ?? ""
                    notes = initial.notes ?? ""
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(name, email.isEmpty ? nil : email, notes.isEmpty ? nil : notes)
            dismiss()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
