import SwiftUI

/// Multi-select sheet backed by the shared `UserDataStore` — no separate fetch
/// because the roster was prefetched at sign-in. If the store is somehow
/// empty (edge cases like a background refresh failure) we surface a refresh
/// affordance rather than silently showing an empty list.
struct RosterPickerSheet: View {
    var onPick: @MainActor ([SavedPlayer]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataStore.self) private var userData
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if userData.isHydrating && userData.players.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userData.players.isEmpty {
                    ContentUnavailableView(
                        "No saved players",
                        systemImage: "person.2",
                        description: Text("Add players from the Players tab to pick them quickly here."),
                    )
                } else {
                    List(userData.players, selection: $selected) { player in
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
                        let picked = userData.players.filter { selected.contains($0.id) }
                        onPick(picked)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .refreshable { await userData.refreshPlayers() }
        }
    }
}
