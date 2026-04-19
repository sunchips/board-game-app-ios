import SwiftUI

@main
struct BoardGameAppApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        if auth.isSignedIn {
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
    RootView().environment(AuthStore())
}
