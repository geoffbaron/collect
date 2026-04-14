import Foundation
import SwiftData

@Model
final class Property {
    var id: UUID
    var name: String
    var address: String
    var createdAt: Date
    var updatedAt: Date
    var ownerID: String

    @Relationship(deleteRule: .cascade, inverse: \Floor.property)
    var floors: [Floor]

    init(name: String, address: String = "", ownerID: String) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = Date()
        self.updatedAt = Date()
        self.ownerID = ownerID
        self.floors = []
    }

    var sortedFloors: [Floor] {
        floors.sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalRooms: Int {
        floors.reduce(0) { $0 + $1.rooms.count }
    }

    var totalCollections: Int {
        floors.reduce(0) { count, floor in
            count + floor.rooms.reduce(0) { $0 + $1.collections.count }
        }
    }
}
