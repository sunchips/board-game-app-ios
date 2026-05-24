import SwiftUI

@main
struct BoardGameAppApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(auth.userData)
        }
    }
}

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(UserDataStore.self) private var userData

    var body: some View {
        if auth.isSignedIn {
            if userData.isInitialLoad {
                LaunchSplash()
            } else {
                SignedInTabs()
            }
        } else {
            LoginView()
        }
    }
}

/// Shown for the brief window between a session being restored from Keychain
/// and the first /api/session hydration landing. Without this the user sees
/// empty tabs while the network call is in flight. The view matches the iOS
/// launch screen (accent-colored background) so the handoff is seamless.
private struct LaunchSplash: View {
    var body: some View {
        ZStack {
            Color.accentColor.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                Text("Board Game")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
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
}
