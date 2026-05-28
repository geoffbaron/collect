import Foundation
import SwiftData
import UIKit

/// All Supabase I/O for cloud sync. Called only by SyncService, MigrationService,
/// and RestoreService — no view should call this directly.
actor CloudRepository {
    static let shared = CloudRepository()

    private let db     = SupabaseManager.shared.client
    private let bucket = "asset-photos"

    // MARK: - Upserts

    func upsert(property: Property, userID: String) async throws {
        let dto = PropertyUpsertDTO(
            id:        property.id.uuidString,
            userId:    userID,
            name:      property.name,
            address:   property.address,
            createdAt: property.createdAt,
            updatedAt: property.updatedAt
        )
        try await db.from("properties").upsert(dto).execute()
    }

    func upsert(floor: Floor, userID: String) async throws {
        guard let propertyID = floor.property?.id else { return }
        let dto = FloorUpsertDTO(
            id:         floor.id.uuidString,
            userId:     userID,
            propertyId: propertyID.uuidString,
            name:       floor.name,
            sortOrder:  floor.sortOrder,
            updatedAt:  Date()
        )
        try await db.from("floors").upsert(dto).execute()
    }

    func upsert(room: Room, userID: String) async throws {
        guard let floorID = room.floor?.id else { return }
        let dto = RoomUpsertDTO(
            id:           room.id.uuidString,
            userId:       userID,
            floorId:      floorID.uuidString,
            name:         room.name,
            mapLatitude:  room.mapLatitude,
            mapLongitude: room.mapLongitude,
            mapHeading:   room.mapHeading,
            updatedAt:    Date()
        )
        try await db.from("rooms").upsert(dto).execute()
    }

    func upsert(collection: Collection, userID: String) async throws {
        guard let roomID = collection.room?.id else { return }
        let dto = CollectionUpsertDTO(
            id:           collection.id.uuidString,
            userId:       userID,
            roomId:       roomID.uuidString,
            promptType:   collection.promptType,
            customPrompt: collection.customPrompt,
            status:       collection.status.rawValue,
            capturedAt:   collection.capturedAt,
            updatedAt:    Date()
        )
        try await db.from("collections").upsert(dto).execute()
    }

    func upsert(asset: Asset, userID: String, uploadPhotos: Bool) async throws {
        guard let collectionID = asset.collection?.id else { return }

        var photo1Path: String? = nil
        var photo2Path: String? = nil

        if uploadPhotos {
            if let data = asset.photo1Data {
                photo1Path = try? await uploadPhoto(
                    data: data, assetID: asset.id, slot: 1, userID: userID)
            }
            if let data = asset.photo2Data {
                photo2Path = try? await uploadPhoto(
                    data: data, assetID: asset.id, slot: 2, userID: userID)
            }
        }

        var dto = AssetUpsertDTO(
            id:               asset.id.uuidString,
            userId:           userID,
            collectionId:     collectionID.uuidString,
            name:             asset.name,
            category:         asset.category,
            assetDescription: asset.assetDescription,
            condition:        asset.condition,
            quantity:         asset.quantity,
            confidence:       asset.confidence,
            estimatedValue:   asset.estimatedValue,
            latitude:         asset.latitude,
            longitude:        asset.longitude,
            layoutX:          asset.layoutX.map { Double($0) },
            layoutZ:          asset.layoutZ.map { Double($0) },
            isConfirmed:      asset.isConfirmed,
            photo1Path:       photo1Path,
            photo2Path:       photo2Path,
            listingStatus:    asset.listingStatus,
            listingTitle:     asset.listingTitle,
            listingDescription: asset.listingDescription,
            askingPrice:      asset.askingPrice,
            listedFacebook:   asset.listedFacebook,
            listedCraigslist: asset.listedCraigslist,
            listedAt:         asset.listedAt,
            soldPrice:        asset.soldPrice,
            soldPlatform:     asset.soldPlatform,
            soldAt:           asset.soldAt,
            updatedAt:        Date()
        )
        // Preserve existing photo paths if we didn't upload new ones
        if !uploadPhotos {
            // Fetch existing paths to avoid overwriting previously-uploaded photos
            if let existing = try? await fetchAssetPhotoPaths(id: asset.id.uuidString) {
                dto.photo1Path = existing.0
                dto.photo2Path = existing.1
            }
        }

        try await db.from("assets").upsert(dto).execute()
    }

    // MARK: - Batch upserts (used during migration)

    func batchUpsertAssets(_ assets: [Asset], userID: String, uploadPhotos: Bool) async throws {
        // Chunk to avoid request size limits
        let chunks = stride(from: 0, to: assets.count, by: 50).map {
            Array(assets[$0..<min($0 + 50, assets.count)])
        }
        for chunk in chunks {
            for asset in chunk {
                try await upsert(asset: asset, userID: userID, uploadPhotos: uploadPhotos)
            }
        }
    }

    // MARK: - Soft deletes

    func softDelete(table: String, id: UUID) async throws {
        try await db.from(table)
            .update(SoftDeleteDTO(deletedAt: Date()))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Photo upload

    func uploadPhoto(data: Data, assetID: UUID, slot: Int, userID: String) async throws -> String {
        let path = "\(userID)/\(assetID.uuidString)/photo\(slot).jpg"
        _ = try await db.storage
            .from(bucket)
            .upload(path, data: data, options: .init(contentType: "image/jpeg", upsert: true))
        return path
    }

    func downloadPhoto(path: String) async throws -> Data {
        try await db.storage.from(bucket).download(path: path)
    }

    func deletePhotos(assetID: UUID, userID: String) async throws {
        let paths = [
            "\(userID)/\(assetID.uuidString)/photo1.jpg",
            "\(userID)/\(assetID.uuidString)/photo2.jpg",
        ]
        _ = try await db.storage.from(bucket).remove(paths: paths)
    }

    // MARK: - Fetch (for restore)

    func fetchUserData(userID: String) async throws -> UserDataSnapshot {
        async let properties: [PropertyFetchDTO] = db.from("properties")
            .select()
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .order("created_at")
            .execute()
            .value

        async let floors: [FloorFetchDTO] = db.from("floors")
            .select()
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .order("sort_order")
            .execute()
            .value

        async let rooms: [RoomFetchDTO] = db.from("rooms")
            .select()
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .order("name")
            .execute()
            .value

        async let collections: [CollectionFetchDTO] = db.from("collections")
            .select()
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .order("captured_at")
            .execute()
            .value

        async let assets: [AssetFetchDTO] = db.from("assets")
            .select()
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .order("created_at")
            .execute()
            .value

        return try await UserDataSnapshot(
            properties:  properties,
            floors:      floors,
            rooms:       rooms,
            collections: collections,
            assets:      assets
        )
    }

    func hasCloudData(userID: String) async -> Bool {
        struct CountResult: Decodable { let count: Int }
        let rows: [PropertyFetchDTO]? = try? await db.from("properties")
            .select()
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .limit(1)
            .execute()
            .value
        return (rows?.count ?? 0) > 0
    }

    // MARK: - Private helpers

    private func fetchAssetPhotoPaths(id: String) async throws -> (String?, String?) {
        struct Paths: Decodable {
            let photo1Path: String?
            let photo2Path: String?
            enum CodingKeys: String, CodingKey {
                case photo1Path = "photo1_path"
                case photo2Path = "photo2_path"
            }
        }
        let rows: [Paths] = try await db.from("assets")
            .select("photo1_path, photo2_path")
            .eq("id", value: id)
            .execute()
            .value
        return (rows.first?.photo1Path, rows.first?.photo2Path)
    }
}
