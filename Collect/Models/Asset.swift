import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID
    var name: String
    var category: String
    var assetDescription: String
    var condition: String?
    var quantity: Int
    var confidence: Double

    @Attribute(.externalStorage)
    var thumbnailData: Data?

    /// Up to 2 representative frames captured from the scan video
    @Attribute(.externalStorage)
    var photo1Data: Data?

    @Attribute(.externalStorage)
    var photo2Data: Data?

    /// AI-suggested market/replacement value in USD
    var estimatedValue: Double?

    /// GPS coordinate recorded at scan time (indoor-assisted when available)
    var latitude: Double?
    var longitude: Double?

    /// Room-coordinate position matched from RoomPlan scan (meters, same space as RoomLayout)
    var layoutX: Float?
    var layoutZ: Float?

    var collection: Collection?
    var isConfirmed: Bool

    init(
        name: String,
        category: String,
        assetDescription: String,
        condition: String? = nil,
        quantity: Int = 1,
        confidence: Double = 1.0,
        collection: Collection
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.assetDescription = assetDescription
        self.condition = condition
        self.quantity = quantity
        self.confidence = confidence
        self.collection = collection
        self.isConfirmed = false
    }

    var photos: [Data] {
        [photo1Data, photo2Data].compactMap { $0 }
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var hasPinnedPosition: Bool {
        layoutX != nil && layoutZ != nil
    }
}
