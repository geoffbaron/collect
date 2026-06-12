import Foundation

/// A shared space on a property (lobby, gym, laundry…). Server-driven;
/// PM mode only. Mirrors public.common_areas.
struct PMCommonArea: Identifiable, Codable, Hashable {
    let id: String
    let propertyID: String
    let buildingID: String?
    var name: String
    var areaType: CommonAreaType
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case propertyID = "property_id"
        case buildingID = "building_id"
        case areaType   = "area_type"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }
}

enum CommonAreaType: String, CaseIterable, Codable, Hashable {
    case lobby, gym, pool, hallway, laundry, parking, office, other

    var displayName: String {
        switch self {
        case .lobby:   "Lobby"
        case .gym:     "Gym"
        case .pool:    "Pool"
        case .hallway: "Hallway"
        case .laundry: "Laundry"
        case .parking: "Parking"
        case .office:  "Office"
        case .other:   "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .lobby:   "sofa.fill"
        case .gym:     "dumbbell.fill"
        case .pool:    "figure.pool.swim"
        case .hallway: "door.sliding.left.hand.closed"
        case .laundry: "washer.fill"
        case .parking: "car.fill"
        case .office:  "briefcase.fill"
        case .other:   "square.grid.2x2.fill"
        }
    }
}

/// Manages a property's common areas. Follows the BuildingService pattern.
@MainActor
final class CommonAreaService: ObservableObject {

    @Published private(set) var commonAreas: [PMCommonArea] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    func clearError() {
        error = nil
    }

    func load(for propertyID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMCommonArea] = try await db
                .from("common_areas")
                .select("*")
                .eq("property_id", value: propertyID)
                .is("deleted_at", value: nil)
                .order("name")
                .execute()
                .value
            commonAreas = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(propertyID: String, name: String, areaType: CommonAreaType) async -> PMCommonArea? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        do {
            let row: PMCommonArea = try await db
                .from("common_areas")
                .insert([
                    "property_id": propertyID,
                    "name":        trimmed,
                    "area_type":   areaType.rawValue,
                ])
                .select("*")
                .single()
                .execute()
                .value
            commonAreas.append(row)
            commonAreas.sort { $0.name < $1.name }
            return row
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func delete(_ area: PMCommonArea) async -> Bool {
        struct RowID: Decodable { let id: String }
        do {
            let iso = ISO8601DateFormatter().string(from: Date())
            let deleted: [RowID] = try await db
                .from("common_areas")
                .update(["deleted_at": iso])
                .eq("id", value: area.id)
                .select("id")
                .execute()
                .value
            guard !deleted.isEmpty else {
                error = "You don't have permission to delete this common area."
                return false
            }
            commonAreas.removeAll { $0.id == area.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
