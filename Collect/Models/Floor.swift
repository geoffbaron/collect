import Foundation
import SwiftData

@Model
final class Floor {
    var id: UUID
    var name: String
    var sortOrder: Int
    var property: Property?

    @Relationship(deleteRule: .cascade, inverse: \Room.floor)
    var rooms: [Room]

    init(name: String, sortOrder: Int, property: Property) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.property = property
        self.rooms = []
    }

    var sortedRooms: [Room] {
        rooms.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var totalCollections: Int {
        rooms.reduce(0) { $0 + $1.collections.count }
    }
}
