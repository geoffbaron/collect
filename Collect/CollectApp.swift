import SwiftUI
import SwiftData

@main
struct CollectApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
        .modelContainer(for: [Property.self, Floor.self, Room.self, Collection.self, Asset.self])
    }
}
