import Foundation
import SwiftData
import UIKit

/// Downloads all cloud data and populates SwiftData on a fresh device sign-in.
/// Only runs when the user is authenticated but has zero local properties.
@MainActor
final class RestoreService {

    private let repo = CloudRepository.shared

    /// Returns the number of assets restored, or nil if restore was skipped.
    @discardableResult
    func runIfNeeded(userID: String, modelContext: ModelContext) async throws -> Int? {
        // Check if local data already exists for this user
        let localProps = try modelContext.fetch(
            FetchDescriptor<Property>(predicate: #Predicate { $0.ownerID == userID })
        )
        guard localProps.isEmpty else { return nil }

        // Check if there's anything in the cloud to restore
        let hasCloud = await repo.hasCloudData(userID: userID)
        guard hasCloud else { return nil }

        print("RestoreService: restoring cloud data…")

        let snapshot = try await repo.fetchUserData(userID: userID)

        // Build lookup maps keyed by UUID string for fast relationship resolution
        var propertyMap: [String: Property] = [:]
        var floorMap:    [String: Floor]    = [:]
        var roomMap:     [String: Room]     = [:]
        var collectionMap: [String: Collection] = [:]

        // ── Properties ─────────────────────────────────────────
        for dto in snapshot.properties where dto.deletedAt == nil {
            guard let uuid = UUID(uuidString: dto.id) else { continue }
            let property = Property(name: dto.name, address: dto.address, ownerID: userID)
            property.id        = uuid
            property.createdAt = dto.createdAt
            property.updatedAt = dto.updatedAt
            modelContext.insert(property)
            propertyMap[dto.id] = property
        }

        // ── Floors ─────────────────────────────────────────────
        for dto in snapshot.floors where dto.deletedAt == nil {
            guard let uuid = UUID(uuidString: dto.id),
                  let property = propertyMap[dto.propertyId] else { continue }
            let floor = Floor(name: dto.name, sortOrder: dto.sortOrder, property: property)
            floor.id = uuid
            modelContext.insert(floor)
            floorMap[dto.id] = floor
        }

        // ── Rooms ──────────────────────────────────────────────
        for dto in snapshot.rooms where dto.deletedAt == nil {
            guard let uuid = UUID(uuidString: dto.id),
                  let floor = floorMap[dto.floorId] else { continue }
            let room = Room(name: dto.name, floor: floor)
            room.id           = uuid
            room.mapLatitude  = dto.mapLatitude
            room.mapLongitude = dto.mapLongitude
            room.mapHeading   = dto.mapHeading
            modelContext.insert(room)
            roomMap[dto.id] = room
        }

        // ── Collections ────────────────────────────────────────
        for dto in snapshot.collections where dto.deletedAt == nil {
            guard let uuid = UUID(uuidString: dto.id),
                  let room = roomMap[dto.roomId],
                  let promptType = PromptType(rawValue: dto.promptType) else { continue }
            let collection = Collection(promptType: promptType, room: room, customPrompt: dto.customPrompt)
            collection.id          = uuid
            collection.capturedAt  = dto.capturedAt
            collection.status      = CollectionStatus(rawValue: dto.status) ?? .completed
            modelContext.insert(collection)
            collectionMap[dto.id] = collection
        }

        // ── Assets (metadata first, photos downloaded in background) ──
        var assetObjects: [(Asset, AssetFetchDTO)] = []
        for dto in snapshot.assets where dto.deletedAt == nil {
            guard let uuid = UUID(uuidString: dto.id),
                  let collection = collectionMap[dto.collectionId] else { continue }
            let asset = Asset(
                name:             dto.name,
                category:         dto.category,
                assetDescription: dto.assetDescription,
                condition:        dto.condition,
                quantity:         dto.quantity,
                confidence:       dto.confidence,
                collection:       collection
            )
            asset.id             = uuid
            asset.estimatedValue = dto.estimatedValue
            asset.latitude       = dto.latitude
            asset.longitude      = dto.longitude
            asset.layoutX        = dto.layoutX.map { Float($0) }
            asset.layoutZ        = dto.layoutZ.map { Float($0) }
            asset.isConfirmed    = dto.isConfirmed
            // Must insert before writing @Attribute(.externalStorage) data
            modelContext.insert(asset)
            assetObjects.append((asset, dto))
        }

        try? modelContext.save()
        let restoredCount = assetObjects.count
        print("RestoreService: restored \(restoredCount) assets. Downloading photos in background…")

        // ── Photo downloads (background, non-blocking) ─────────
        for (asset, dto) in assetObjects {
            if let path = dto.photo1Path {
                Task.detached(priority: .background) { [weak self] in
                    await self?.downloadPhoto(path: path, assetID: asset.id, slot: 1,
                                              modelContext: modelContext)
                }
            }
            if let path = dto.photo2Path {
                Task.detached(priority: .background) { [weak self] in
                    await self?.downloadPhoto(path: path, assetID: asset.id, slot: 2,
                                              modelContext: modelContext)
                }
            }
        }

        return restoredCount
    }

    // MARK: - Background photo download

    private func downloadPhoto(path: String, assetID: UUID, slot: Int,
                               modelContext: ModelContext) async {
        do {
            let data = try await repo.downloadPhoto(path: path)
            await MainActor.run {
                guard let asset = try? modelContext.fetch(
                    FetchDescriptor<Asset>(predicate: #Predicate { $0.id == assetID })
                ).first else { return }
                if slot == 1 { asset.photo1Data = data }
                else         { asset.photo2Data = data }
                try? modelContext.save()
            }
        } catch {
            print("RestoreService: photo download failed (\(path)) — \(error)")
        }
    }
}
