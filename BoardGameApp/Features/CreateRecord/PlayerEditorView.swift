import SwiftUI

struct PlayerEditorView: View {
    @Binding var entry: PlayerEntry
    let game: GameDefinition

    var body: some View {
        DisclosureGroup(entry.name.isEmpty ? "New Player" : entry.name) {
            TextField("Name", text: $entry.name)
                .textInputAutocapitalization(.words)
            TextField("Email (optional)", text: $entry.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)

            if !game.identityOptions.isEmpty {
                Picker("Identity", selection: $entry.identity) {
                    Text("—").tag("")
                    ForEach(game.identityOptions, id: \.self) { opt in
                        Text(opt.replacingOccurrences(of: "-", with: " ").capitalized).tag(opt)
                    }
                }
            }

            if game.supportsTeams {
                Stepper(value: $entry.team, in: 1...8) {
                    LabeledContent("Team", value: "\(entry.team)")
                }
            }

            if game.supportsElimination {
                Toggle("Eliminated", isOn: $entry.eliminated)
            }

            // Cooperative games share one end state across the whole table —
            // it's edited in the form's Team Result section, not per-player.
            if !game.isCooperative {
                ForEach(game.endStateFields, id: \.key) { field in
                    EndStateFieldView(field: field, integers: $entry.integers, booleans: $entry.booleans)
                }
            }
        }
    }
}
