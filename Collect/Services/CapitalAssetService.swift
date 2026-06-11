import Foundation

/// Manages capital assets (major systems/equipment) for a property
/// (optionally scoped to a unit). Server-driven; PM mode only.
@MainActor
final class CapitalAssetService: ObservableObject {

    @Published private(set) var capitalAssets: [PMCapitalAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    func clearError() {
        error = nil
    }

    /// Loads every capital asset for a property (across all units/buildings).
    func load(propertyID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMCapitalAsset] = try await db
                .from("capital_assets")
                .select("*")
                .eq("property_id", value: propertyID)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            capitalAssets = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Loads capital assets for a single unit.
    func load(unitID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMCapitalAsset] = try await db
                .from("capital_assets")
                .select("*")
                .eq("unit_id", value: unitID)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            capitalAssets = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(
        propertyID: String,
        buildingID: String? = nil,
        unitID: String? = nil,
        commonAreaID: String? = nil,
        name: String,
        assetType: CapitalAssetType = .other,
        manufacturer: String = "",
        model: String = "",
        serialNumber: String = "",
        installDate: String? = nil,
        condition: CapitalAssetCondition = .good
    ) async -> PMCapitalAsset? {
        var payload: [String: String] = [
            "property_id":   propertyID,
            "name":          name,
            "asset_type":    assetType.rawValue,
            "manufacturer":  manufacturer,
            "model":         model,
            "serial_number": serialNumber,
            "condition":     condition.rawValue,
        ]
        if let buildingID { payload["building_id"] = buildingID }
        if let unitID { payload["unit_id"] = unitID }
        if let commonAreaID { payload["common_area_id"] = commonAreaID }
        if let installDate { payload["install_date"] = installDate }

        do {
            let row: PMCapitalAsset = try await db
                .from("capital_assets")
                .insert(payload)
                .select("*")
                .single()
                .execute()
                .value
            capitalAssets.insert(row, at: 0)
            return row
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func updateCondition(_ asset: PMCapitalAsset, to condition: CapitalAssetCondition) async {
        guard let idx = capitalAssets.firstIndex(where: { $0.id == asset.id }) else { return }
        let previous = capitalAssets[idx].condition
        capitalAssets[idx].condition = condition

        struct RowID: Decodable { let id: String }

        do {
            let updated: [RowID] = try await db
                .from("capital_assets")
                .update(["condition": condition.rawValue])
                .eq("id", value: asset.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                capitalAssets[idx].condition = previous
                self.error = "You don't have permission to update this asset."
            }
        } catch {
            capitalAssets[idx].condition = previous
            self.error = error.localizedDescription
        }
    }

    func update(
        _ asset: PMCapitalAsset,
        name: String,
        assetType: CapitalAssetType,
        manufacturer: String,
        model: String,
        serialNumber: String,
        installDate: String?,
        warrantyExpires: String?,
        lastServicedAt: String?,
        notes: String
    ) async -> Bool {
        guard let idx = capitalAssets.firstIndex(where: { $0.id == asset.id }) else { return false }
        let previous = capitalAssets[idx]
        capitalAssets[idx].name = name
        capitalAssets[idx].assetType = assetType
        capitalAssets[idx].manufacturer = manufacturer
        capitalAssets[idx].model = model
        capitalAssets[idx].serialNumber = serialNumber
        capitalAssets[idx].installDate = installDate
        capitalAssets[idx].warrantyExpires = warrantyExpires
        capitalAssets[idx].lastServicedAt = lastServicedAt
        capitalAssets[idx].notes = notes

        struct RowID: Decodable { let id: String }

        do {
            let updated: [RowID] = try await db
                .from("capital_assets")
                .update([
                    "name": name,
                    "asset_type": assetType.rawValue,
                    "manufacturer": manufacturer,
                    "model": model,
                    "serial_number": serialNumber,
                    "install_date": installDate,
                    "warranty_expires": warrantyExpires,
                    "last_serviced_at": lastServicedAt,
                    "notes": notes,
                ] as [String: String?])
                .eq("id", value: asset.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                capitalAssets[idx] = previous
                self.error = "You don't have permission to update this asset."
                return false
            }
            return true
        } catch {
            capitalAssets[idx] = previous
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(_ asset: PMCapitalAsset) async -> Bool {
        struct RowID: Decodable { let id: String }

        do {
            let iso = ISO8601DateFormatter().string(from: Date())
            let updated: [RowID] = try await db
                .from("capital_assets")
                .update(["deleted_at": iso])
                .eq("id", value: asset.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                self.error = "You don't have permission to delete this asset."
                return false
            }
            capitalAssets.removeAll { $0.id == asset.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
