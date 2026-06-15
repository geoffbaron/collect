import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var featuresService: FeaturesService
    @EnvironmentObject private var accountService: AccountService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Maintenance staff work out of the account-wide ticket queue —
                // the property list is local SwiftData and would be empty for them.
                if accountService.isMaintenance {
                    MaintenanceHomeView()
                } else {
                    PropertyListView()
                }
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

            // ── Guest data adoption ─────────────────────────────────────────
            // This runs unconditionally — before the migration flag check —
            // so data created while signed in as guest gets claimed even if
            // MigrationService already ran (and set its flag) on a previous
            // launch before this user had a real account.
            let flagKey = "collect_migrated_\(userID)"
            let allProperties = (try? modelContext.fetch(FetchDescriptor<Property>())) ?? []
            let guestOwned = allProperties.filter { $0.ownerID.hasPrefix("guest_") }
            if !guestOwned.isEmpty {
                print("ContentView: adopting \(guestOwned.count) guest properties → \(userID)")
                for property in guestOwned { property.ownerID = userID }
                try? modelContext.save()
                // Clear the migration flag so MigrationService re-uploads everything
                UserDefaults.standard.removeObject(forKey: flagKey)
            }

            await MigrationService().runIfNeeded(
                userID: userID,
                modelContext: modelContext,
                uploadPhotos: featuresService.cloudStorageEnabled
            )
            _ = try? await RestoreService().runIfNeeded(
                userID: userID,
                modelContext: modelContext
            )

            // ── Backfill listing photos ─────────────────────────────────────
            // Ensure features are loaded (the onChange handler in CollectApp fetches
            // them concurrently; this guarantees we have the latest value).
            await featuresService.fetch()
            syncService.cloudStorageEnabled = featuresService.cloudStorageEnabled

            // If cloud storage is enabled but existing listed assets never had
            // their photos uploaded, upload them directly now.
            if featuresService.cloudStorageEnabled {
                let all = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
                let needsUpload = all.filter {
                    $0.isListed && ($0.photo1Data != nil || $0.photo2Data != nil)
                }
                print("ContentView: checking \(needsUpload.count) listed asset(s) for photo upload")
                for asset in needsUpload {
                    let hasP1 = asset.photo1Data != nil
                    let hasP2 = asset.photo2Data != nil
                    print("ContentView: backfill '\(asset.name)' photo1=\(hasP1) photo2=\(hasP2)")
                    do {
                        try await CloudRepository.shared.upsert(
                            asset: asset, userID: userID, uploadPhotos: true
                        )
                        print("ContentView: ✓ upsert done for '\(asset.name)' (photo upload logged above)")
                    } catch {
                        print("ContentView: ✗ upsert failed for '\(asset.name)': \(error)")
                    }
                }
            }
        }
    }
}
