import Foundation
import SwiftData

@Model
final class Room {
    var id: UUID
    var name: String
    var floor: Floor?

    @Relationship(deleteRule: .cascade, inverse: \Collection.room)
    var collections: [Collection]

    @Attribute(.externalStorage)
    var layoutData: Data?

    /// User-adjusted GPS anchor for the floor plan on the property map (nil = auto from assets)
    var mapLatitude:  Double?
    var mapLongitude: Double?
    /// Clockwise rotation of the floor plan in degrees (0 = X→East, Z→North)
    var mapHeading: Double = 0

    init(name: String, floor: Floor) {
        self.id = UUID()
        self.name = name
        self.floor = floor
        self.collections = []
    }

    var hasLayout: Bool { layoutData != nil }

    /// Effective GPS center for the property map — manual override, or averaged from asset GPS.
    var effectiveMapCenter: (lat: Double, lon: Double)? {
        if let lat = mapLatitude, let lon = mapLongitude { return (lat, lon) }
        let assets = collections.flatMap { $0.assets }
        let gps = assets.compactMap { a -> (Double, Double)? in
            guard let lat = a.latitude, let lon = a.longitude else { return nil }
            return (lat, lon)
        }
        guard !gps.isEmpty else { return nil }
        return (
            lat: gps.map(\.0).reduce(0, +) / Double(gps.count),
            lon: gps.map(\.1).reduce(0, +) / Double(gps.count)
        )
    }

    var sortedCollections: [Collection] {
        collections.sorted { $0.capturedAt > $1.capturedAt }
    }

    var totalAssets: Int {
        collections.reduce(0) { $0 + $1.assets.count }
    }

    var locationPath: String {
        guard let floor = floor, let property = floor.property else { return name }
        return "\(property.name) > \(floor.name) > \(name)"
    }
}
