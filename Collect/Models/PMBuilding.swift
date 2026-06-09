import Foundation

/// A building within a property complex — the structural grouping above units.
/// Server-driven (not stored in SwiftData); PM mode only.
struct PMBuilding: Identifiable, Codable, Hashable {
    let id: String
    let propertyID: String
    let name: String
    let address: String
    let floorCount: Int?
    let yearBuilt: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, address
        case propertyID  = "property_id"
        case floorCount  = "floor_count"
        case yearBuilt   = "year_built"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}
