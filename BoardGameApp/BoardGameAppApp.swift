import SwiftUI

@main
struct BoardGameAppApp: App {
    @State private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView(auth: auth)
        }
    }
}

struct RootView: View {
    @Bindable var auth: AuthService

    var body: some View {
        if auth.isSignedIn {
            TabView {
                Tab("Create", systemImage: "plus.circle.fill") {
                    NavigationStack { GamePickerView() }
                }
                Tab("Records", systemImage: "list.bullet.rectangle") {
                    NavigationStack { RecordsListView() }
                }
                Tab("Account", systemImage: "person.crop.circle") {
                    NavigationStack { AccountView(auth: auth) }
                }
            }
        } else {
            SignInView(auth: auth)
        }
    }
}

struct AccountView: View {
    @Bindable var auth: AuthService

    var body: some View {
        Form {
            Section("Signed in as") {
                if let name = auth.currentUser?.name, !name.isEmpty {
                    LabeledContent("Name", value: name)
                }
                if let email = auth.currentUser?.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }
            }
            Section {
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
            }
        }
        .navigationTitle("Account")
    }
}

#Preview {
    RootView(auth: AuthService())
}
