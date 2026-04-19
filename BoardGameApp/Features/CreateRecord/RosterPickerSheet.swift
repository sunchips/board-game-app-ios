import SwiftUI

/// Multi-select sheet that loads the saved-player roster from the server and
/// hands selected rows back to the create-record flow so the user doesn't have
/// to retype frequent players.
struct RosterPickerSheet: View {
    var onPick: @MainActor ([SavedPlayer]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var players: [SavedPlayer] = []
    @State private var selected: Set<UUID> = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && players.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let message = errorMessage, players.isEmpty {
                    ContentUnavailableView("Couldn't load players", systemImage: "wifi.exclamationmark", description: Text(message))
                } else if players.isEmpty {
                    ContentUnavailableView(
                        "No saved players",
                        systemImage: "person.2",
                        description: Text("Add players from the Players tab to pick them quickly here."),
                    )
                } else {
                    List(players, selection: $selected) { player in
                        VStack(alignment: .leading) {
                            Text(player.name).font(.headline)
                            if let email = player.email {
                                Text(email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(player.id)
                    }
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Pick Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selected.count > 0 ? "(\(selected.count))" : "")") {
                        let picked = players.filter { selected.contains($0.id) }
                        onPick(picked)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            players = try await APIClient.shared.listSavedPlayers()
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
