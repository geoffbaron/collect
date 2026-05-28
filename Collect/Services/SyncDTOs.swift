import Foundation

// MARK: - Upsert DTOs
// Wire-format structs for Supabase upserts.
// CodingKeys use snake_case to match column names exactly.
// The Supabase Swift SDK passes these through its PostgrestEncoder.

struct PropertyUpsertDTO: Encodable {
    let id: String
    let userId: String
    let name: String
    let address: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case name, address
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FloorUpsertDTO: Encodable {
    let id: String
    let userId: String
    let propertyId: String
    let name: String
    let sortOrder: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case propertyId = "property_id"
        case name
        case sortOrder  = "sort_order"
        case updatedAt  = "updated_at"
    }
}

struct RoomUpsertDTO: Encodable {
    let id: String
    let userId: String
    let floorId: String
    let name: String
    let mapLatitude: Double?
    let mapLongitude: Double?
    let mapHeading: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case floorId      = "floor_id"
        case name
        case mapLatitude  = "map_latitude"
        case mapLongitude = "map_longitude"
        case mapHeading   = "map_heading"
        case updatedAt    = "updated_at"
    }
}

struct CollectionUpsertDTO: Encodable {
    let id: String
    let userId: String
    let roomId: String
    let promptType: String
    let customPrompt: String?
    let status: String
    let capturedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case roomId       = "room_id"
        case promptType   = "prompt_type"
        case customPrompt = "custom_prompt"
        case status
        case capturedAt   = "captured_at"
        case updatedAt    = "updated_at"
    }
}

struct AssetUpsertDTO: Encodable {
    let id: String
    let userId: String
    let collectionId: String
    let name: String
    let category: String
    let assetDescription: String
    let condition: String?
    let quantity: Int
    let confidence: Double
    let estimatedValue: Double?
    let latitude: Double?
    let longitude: Double?
    let layoutX: Double?
    let layoutZ: Double?
    let isConfirmed: Bool
    var photo1Path: String?
    var photo2Path: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId           = "user_id"
        case collectionId     = "collection_id"
        case name, category
        case assetDescription = "asset_description"
        case condition, quantity, confidence
        case estimatedValue   = "estimated_value"
        case latitude, longitude
        case layoutX          = "layout_x"
        case layoutZ          = "layout_z"
        case isConfirmed      = "is_confirmed"
        case photo1Path       = "photo1_path"
        case photo2Path       = "photo2_path"
        case updatedAt        = "updated_at"
    }
}

// MARK: - Soft-delete DTO

struct SoftDeleteDTO: Encodable {
    let deletedAt: Date
    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
    }
}

// MARK: - Fetch DTOs (Decodable, for restore)

struct PropertyFetchDTO: Decodable {
    let id: String
    let userId: String
    let name: String
    let address: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case name, address
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct FloorFetchDTO: Decodable {
    let id: String
    let userId: String
    let propertyId: String
    let name: String
    let sortOrder: Int
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case propertyId = "property_id"
        case name
        case sortOrder  = "sort_order"
        case updatedAt  = "updated_at"
        case deletedAt  = "deleted_at"
    }
}

struct RoomFetchDTO: Decodable {
    let id: String
    let userId: String
    let floorId: String
    let name: String
    let mapLatitude: Double?
    let mapLongitude: Double?
    let mapHeading: Double
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case floorId      = "floor_id"
        case name
        case mapLatitude  = "map_latitude"
        case mapLongitude = "map_longitude"
        case mapHeading   = "map_heading"
        case updatedAt    = "updated_at"
        case deletedAt    = "deleted_at"
    }
}

struct CollectionFetchDTO: Decodable {
    let id: String
    let userId: String
    let roomId: String
    let promptType: String
    let customPrompt: String?
    let status: String
    let capturedAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case roomId       = "room_id"
        case promptType   = "prompt_type"
        case customPrompt = "custom_prompt"
        case status
        case capturedAt   = "captured_at"
        case updatedAt    = "updated_at"
        case deletedAt    = "deleted_at"
    }
}

struct AssetFetchDTO: Decodable {
    let id: String
    let userId: String
    let collectionId: String
    let name: String
    let category: String
    let assetDescription: String
    let condition: String?
    let quantity: Int
    let confidence: Double
    let estimatedValue: Double?
    let latitude: Double?
    let longitude: Double?
    let layoutX: Double?
    let layoutZ: Double?
    let isConfirmed: Bool
    let photo1Path: String?
    let photo2Path: String?
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId           = "user_id"
        case collectionId     = "collection_id"
        case name, category
        case assetDescription = "asset_description"
        case condition, quantity, confidence
        case estimatedValue   = "estimated_value"
        case latitude, longitude
        case layoutX          = "layout_x"
        case layoutZ          = "layout_z"
        case isConfirmed      = "is_confirmed"
        case photo1Path       = "photo1_path"
        case photo2Path       = "photo2_path"
        case updatedAt        = "updated_at"
        case deletedAt        = "deleted_at"
    }
}

// MARK: - Restore snapshot

struct UserDataSnapshot {
    let properties: [PropertyFetchDTO]
    let floors: [FloorFetchDTO]
    let rooms: [RoomFetchDTO]
    let collections: [CollectionFetchDTO]
    let assets: [AssetFetchDTO]
}
