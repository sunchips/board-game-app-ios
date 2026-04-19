import SwiftUI

@main
struct BoardGameAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Create", systemImage: "plus.circle.fill") {
                NavigationStack { GamePickerView() }
            }
            Tab("Records", systemImage: "list.bullet.rectangle") {
                NavigationStack { RecordsListView() }
            }
        }
    }
}

#Preview {
    RootView()
}
