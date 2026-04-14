import SwiftUI
import SwiftData

@main
struct CollectApp: App {
    @StateObject private var authService    = AuthService()
    @StateObject private var limitsService  = LimitsService()
    @StateObject private var featuresService = FeaturesService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(limitsService)
                .environmentObject(featuresService)
                .task { await featuresService.fetch() }            // at startup, no auth needed
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    Task {
                        if isAuth { await limitsService.fetch() }
                        else       { limitsService.reset() }
                    }
                }
        }
        .modelContainer(for: [Property.self, Floor.self, Room.self, Collection.self, Asset.self])
    }
}
