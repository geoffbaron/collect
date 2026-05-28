import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var featuresService: FeaturesService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if authService.isAuthenticated {
                PropertyListView()
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .task {
            // Inject the main-thread context so SyncService can fetch models during drain
            syncService.modelContext = modelContext
        }
        .task(id: authService.currentUserID) {
            // Run migration/restore whenever a new authenticated user signs in
            guard let userID = authService.currentUserID, !authService.isGuest else { return }
            await MigrationService().runIfNeeded(
                userID: userID,
                modelContext: modelContext,
                uploadPhotos: featuresService.cloudStorageEnabled
            )
            _ = try? await RestoreService().runIfNeeded(
                userID: userID,
                modelContext: modelContext
            )
        }
    }
}
