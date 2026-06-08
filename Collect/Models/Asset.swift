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

    // MARK: - Marketplace listing

    /// Raw value of ListingStatus enum (SwiftData stores strings)
    var listingStatus: String = ListingStatus.notListed.rawValue
    var listingTitle: String?
    var listingDescription: String?
    var askingPrice: Double?
    var listedFacebook: Bool   = false
    var listedCraigslist: Bool = false
    var listedAt: Date?
    var soldPrice: Double?
    var soldPlatform: String?
    var soldAt: Date?
    /// Direct URL to the live marketplace listing (e.g. fb.com/marketplace/item/…)
    var listingURL: String?

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

    // MARK: - Listing helpers

    var listing: ListingStatus {
        get { ListingStatus(rawValue: listingStatus) ?? .notListed }
        set { listingStatus = newValue.rawValue }
    }

    var listedMarketplaces: [Marketplace] {
        var result: [Marketplace] = []
        if listedFacebook   { result.append(.facebook) }
        if listedCraigslist { result.append(.craigslist) }
        return result
    }

    var isListed: Bool { listing != .notListed }
}
