import SwiftUI
import SwiftData

@main
struct CollectApp: App {
    @StateObject private var authService     = AuthService()
    @StateObject private var limitsService   = LimitsService()
    @StateObject private var featuresService = FeaturesService()
    @StateObject private var accountService  = AccountService()
    @StateObject private var syncService     = SyncService()
    @StateObject private var pmSyncService   = PMSyncService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(limitsService)
                .environmentObject(featuresService)
                .environmentObject(accountService)
                .environmentObject(syncService)
                .environmentObject(pmSyncService)
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    Task {
                        if isAuth, let userID = authService.currentUserID, !authService.isGuest {
                            await limitsService.fetch()
                            await featuresService.fetch()
                            await accountService.fetch()
                            syncService.cloudStorageEnabled = featuresService.cloudStorageEnabled
                            syncService.configure(userID: userID)
                            pmSyncService.configure()
                        } else if isAuth {
                            // Guest — fetch limits only, no cloud sync
                            await limitsService.fetch()
                        } else {
                            limitsService.reset()
                            featuresService.reset()
                            accountService.reset()
                            syncService.reset()
                            pmSyncService.reset()
                        }
                    }
                }
        }
        .modelContainer(for: [Property.self, Floor.self, Room.self, Collection.self, Asset.self])
    }
}
