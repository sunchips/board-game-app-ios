import SwiftUI

/// Multi-select sheet backed by the shared `UserDataStore` — no separate fetch
/// because the roster was prefetched at sign-in. If the store is somehow
/// empty (edge cases like a background refresh failure) we surface a refresh
/// affordance rather than silently showing an empty list.
struct RosterPickerSheet: View {
    /// SavedPlayer ids already in the draft — these rows are shown but
    /// disabled with an "Added" badge so the user understands why they can't
    /// pick them. Pass an empty set to opt out of any filtering.
    var alreadyPickedIDs: Set<UUID> = []
    var onPick: @MainActor ([SavedPlayer]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataStore.self) private var userData
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if userData.isHydratingPlayers && userData.players.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userData.players.isEmpty {
                    ContentUnavailableView(
                        "No saved players",
                        systemImage: "person.2",
                        description: Text("Add players from the Players tab to pick them quickly here."),
                    )
                } else {
                    List(userData.players, selection: $selected) { player in
                        let isAlreadyAdded = alreadyPickedIDs.contains(player.id)
                        VStack(alignment: .leading) {
                            HStack {
                                Text(player.name).font(.headline)
                                if player.isSelf {
                                    Text("You")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tint)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                }
                                if isAlreadyAdded {
                                    Spacer()
                                    Text("Added")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15), in: Capsule())
                                }
                            }
                            if let email = player.email {
                                Text(email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(isAlreadyAdded ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        .disabled(isAlreadyAdded)
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
                        // Defensive: strip any already-added ids in case the
                        // List somehow let one through (it shouldn't, but the
                        // model layer also de-dupes — belt + braces).
                        let picked = userData.players.filter {
                            selected.contains($0.id) && !alreadyPickedIDs.contains($0.id)
                        }
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
            .onChange(of: alreadyPickedIDs) { _, newValue in
                // If the parent updates the exclusion set while the sheet is
                // open, drop any selections that would now be duplicates.
                selected.subtract(newValue)
            }
        }
    }
}
