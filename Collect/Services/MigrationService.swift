import Foundation
import SwiftData

/// Pushes all existing local SwiftData content to Supabase on the user's first cloud sign-in.
/// Safe to call on every launch — it no-ops after the initial migration completes.
@MainActor
final class MigrationService {

    private let repo = CloudRepository.shared

    func runIfNeeded(userID: String, modelContext: ModelContext, uploadPhotos: Bool) async {
        let flagKey = "collect_migrated_\(userID)"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        // If the server already has data, this is a returning user — skip migration,
        // let RestoreService handle it.
        let hasCloud = await repo.hasCloudData(userID: userID)
        if hasCloud {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        // ── Guest data adoption ───────────────────────────────────────────────
        // If the user previously used the app as a guest, their data is stored
        // with ownerID = "guest_XXXX". Reassign it to their real account ID so
        // the migration (and all future syncs) can find and upload it.
        do {
            let allProperties = try modelContext.fetch(FetchDescriptor<Property>())
            let guestProperties = allProperties.filter { $0.ownerID.hasPrefix("guest_") }
            if !guestProperties.isEmpty {
                print("MigrationService: adopting \(guestProperties.count) guest-owned properties to \(userID)")
                for property in guestProperties {
                    property.ownerID = userID
                }
                try? modelContext.save()
            }
        } catch {
            print("MigrationService: guest adoption fetch failed — \(error)")
        }

        // Fetch all properties owned by this user
        let properties: [Property]
        do {
            properties = try modelContext.fetch(
                FetchDescriptor<Property>(predicate: #Predicate { $0.ownerID == userID })
            )
        } catch {
            print("MigrationService: failed to fetch properties — \(error)")
            return
        }

        guard !properties.isEmpty else {
            // Nothing to migrate — new user
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        print("MigrationService: migrating \(properties.count) properties to cloud…")

        for property in properties {
            do {
                // Push property
                try await repo.upsert(property: property, userID: userID)

                // Push floors
                for floor in property.floors {
                    try await repo.upsert(floor: floor, userID: userID)

                    // Push rooms
                    for room in floor.rooms {
                        try await repo.upsert(room: room, userID: userID)

                        // Push collections + assets
                        for collection in room.collections {
                            try await repo.upsert(collection: collection, userID: userID)
                            try await repo.batchUpsertAssets(
                                collection.assets,
                                userID: userID,
                                uploadPhotos: uploadPhotos
                            )
                        }
                    }
                }
            } catch {
                // Don't set the flag — will retry on next launch
                print("MigrationService: failed on property \(property.name) — \(error)")
                return
            }
        }

        UserDefaults.standard.set(true, forKey: flagKey)
        print("MigrationService: migration complete.")
    }
}
