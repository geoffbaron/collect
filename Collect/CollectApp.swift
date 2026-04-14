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
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    Task {
                        if isAuth {
                            await limitsService.fetch()
                            await featuresService.fetch()   // plan-gated — needs auth
                        } else {
                            limitsService.reset()
                            featuresService.reset()
                        }
                    }
                }
        }
        .modelContainer(for: [Property.self, Floor.self, Room.self, Collection.self, Asset.self])
    }
}
