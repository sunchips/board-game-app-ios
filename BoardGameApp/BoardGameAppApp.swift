import SwiftUI

@main
struct BoardGameAppApp: App {
    @State private var auth = AuthStore()
    @State private var draftStore = DraftStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(auth.userData)
                .environment(draftStore)
        }
    }
}

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        if auth.isSignedIn {
            // Don't block on hydration — the Create tab is fully local (game
            // catalog is hardcoded) and the Records / Players tabs render
            // their own per-section spinners while their data arrives.
            SignedInTabs()
        } else {
            LoginView()
        }
    }
}

private struct SignedInTabs: View {
    var body: some View {
        TabView {
            Tab("Create", systemImage: "plus.circle.fill") {
                NavigationStack { GamePickerView() }
            }
            Tab("Records", systemImage: "list.bullet.rectangle") {
                NavigationStack { RecordsListView() }
            }
            Tab("Players", systemImage: "person.2.fill") {
                NavigationStack { PlayersView() }
            }
        }
    }
}

#Preview {
    let auth = AuthStore()
    return RootView()
        .environment(auth)
        .environment(auth.userData)
        .environment(DraftStore())
}
