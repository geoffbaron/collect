import Foundation
import Supabase

/// Loads and manages buildings for a given property. Server-driven; PM mode only.
@MainActor
final class BuildingService: ObservableObject {

    @Published private(set) var buildings: [PMBuilding] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    func load(for propertyID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMBuilding] = try await db
                .from("buildings")
                .select("id, property_id, name, address, floor_count, year_built, created_at, updated_at")
                .eq("property_id", value: propertyID)
                .is("deleted_at", value: nil)
                .order("name")
                .execute()
                .value
            buildings = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(propertyID: String, name: String, address: String = "") async -> PMBuilding? {
        do {
            let row: PMBuilding = try await db
                .from("buildings")
                .insert([
                    "property_id": propertyID,
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "address": address.trimmingCharacters(in: .whitespaces),
                ])
                .select("id, property_id, name, address, floor_count, year_built, created_at, updated_at")
                .single()
                .execute()
                .value
            buildings.append(row)
            return row
        } catch {
            guard error is URLError else {
                self.error = error.localizedDescription
                return nil
            }
            let now = Date()
            let localID = UUID().uuidString.lowercased()
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
            let row = PMBuilding(
                id: localID,
                propertyID: propertyID,
                name: trimmedName,
                address: trimmedAddress,
                floorCount: nil,
                yearBuilt: nil,
                createdAt: now,
                updatedAt: now
            )
            let syncPayload: [String: AnyJSON] = [
                "property_id": .string(propertyID),
                "name":        .string(trimmedName),
                "address":     .string(trimmedAddress),
            ]
            buildings.append(row)
            PMSyncService.shared.enqueue(.insert(table: "buildings", localID: localID, payload: syncPayload))
            return row
        }
    }

    func delete(_ building: PMBuilding) async {
        do {
            try await db
                .from("buildings")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: building.id)
                .execute()
            buildings.removeAll { $0.id == building.id }
        } catch {
            guard error is URLError else {
                self.error = error.localizedDescription
                return
            }
            buildings.removeAll { $0.id == building.id }
            PMSyncService.shared.enqueue(.softDelete(table: "buildings", id: building.id))
        }
    }
}
