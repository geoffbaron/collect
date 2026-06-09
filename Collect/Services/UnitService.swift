import Foundation

/// Loads and manages units for a given building. Server-driven; PM mode only.
@MainActor
final class UnitService: ObservableObject {

    @Published private(set) var units: [PMUnit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private var currentBuildingID: String?
    private let db = SupabaseManager.shared.client

    var vacantCount: Int  { units.filter { $0.leaseStatus == .vacant }.count }
    var occupiedCount: Int { units.filter { $0.leaseStatus == .occupied }.count }
    var needsTurnCount: Int {
        units.filter { $0.turnStatus == .needsTurn || $0.turnStatus == .inProgress }.count
    }

    func load(for buildingID: String) async {
        currentBuildingID = buildingID
        isLoading = true
        error = nil
        do {
            let rows: [PMUnit] = try await db
                .from("units")
                .select("*")
                .eq("building_id", value: buildingID)
                .is("deleted_at", value: nil)
                .order("unit_number")
                .execute()
                .value
            units = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(
        propertyID: String,
        buildingID: String,
        unitNumber: String,
        bedrooms: Double? = nil,
        bathrooms: Double? = nil,
        sqft: Int? = nil
    ) async -> PMUnit? {
        var payload: [String: String] = [
            "property_id": propertyID,
            "building_id": buildingID,
            "unit_number": unitNumber.trimmingCharacters(in: .whitespaces),
        ]
        if let b = bedrooms  { payload["bedrooms"]  = String(b) }
        if let b = bathrooms { payload["bathrooms"] = String(b) }
        if let s = sqft      { payload["sqft"]      = String(s) }

        do {
            let row: PMUnit = try await db
                .from("units")
                .insert(payload)
                .select("*")
                .single()
                .execute()
                .value
            units.append(row)
            units.sort { $0.unitNumber < $1.unitNumber }
            return row
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func updateLeaseStatus(of id: String, to status: LeaseStatus) async {
        guard let idx = units.firstIndex(where: { $0.id == id }) else { return }
        let previous = units[idx].leaseStatus
        units[idx].leaseStatus = status
        do {
            try await db
                .from("units")
                .update(["lease_status": status.rawValue])
                .eq("id", value: id)
                .execute()
        } catch {
            units[idx].leaseStatus = previous
            self.error = error.localizedDescription
        }
    }

    func updateTurnStatus(of id: String, to status: TurnStatus) async {
        guard let idx = units.firstIndex(where: { $0.id == id }) else { return }
        let previous = units[idx].turnStatus
        units[idx].turnStatus = status
        do {
            try await db
                .from("units")
                .update(["turn_status": status.rawValue])
                .eq("id", value: id)
                .execute()
        } catch {
            units[idx].turnStatus = previous
            self.error = error.localizedDescription
        }
    }
}
