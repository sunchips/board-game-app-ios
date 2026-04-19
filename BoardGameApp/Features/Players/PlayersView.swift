import SwiftUI

struct PlayersView: View {
    @Environment(AuthStore.self) private var auth
    @State private var model = PlayersViewModel()
    @State private var showingAdd = false
    @State private var editing: SavedPlayer?

    var body: some View {
        Group {
            if model.isLoading && model.players.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = model.errorMessage, model.players.isEmpty {
                ContentUnavailableView(
                    "Couldn't load players",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(message),
                )
            } else if model.players.isEmpty {
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
                    ForEach(model.players) { player in
                        Button { editing = player } label: {
                            PlayerRow(player: player)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let victims = offsets.map { model.players[$0] }
                        Task {
                            for p in victims { await model.delete(p) }
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
                try await model.create(name: name, email: email, notes: notes)
            }
        }
        .sheet(item: $editing) { player in
            PlayerEditSheet(title: "Edit Player", initial: player) { name, email, notes in
                try await model.update(id: player.id, name: name, email: email, notes: notes)
            }
        }
        .refreshable { await model.load() }
        .task { await model.load() }
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
