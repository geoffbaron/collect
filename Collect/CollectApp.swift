import SwiftUI
import SwiftData

@main
struct CollectApp: App {
    @StateObject private var authService     = AuthService()
    @StateObject private var limitsService   = LimitsService()
    @StateObject private var featuresService = FeaturesService()
    @StateObject private var syncService     = SyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(limitsService)
                .environmentObject(featuresService)
                .environmentObject(syncService)
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    Task {
                        if isAuth, let userID = authService.currentUserID, !authService.isGuest {
                            await limitsService.fetch()
                            await featuresService.fetch()
                            syncService.cloudStorageEnabled = featuresService.cloudStorageEnabled
                            syncService.configure(userID: userID)
                        } else if isAuth {
                            // Guest — fetch limits only, no cloud sync
                            await limitsService.fetch()
                        } else {
                            limitsService.reset()
                            featuresService.reset()
                            syncService.reset()
                        }
                    }
                }
        }
        .modelContainer(for: [Property.self, Floor.self, Room.self, Collection.self, Asset.self])
    }
}
