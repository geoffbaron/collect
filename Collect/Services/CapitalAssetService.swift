import Foundation
import Supabase

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
            guard error is URLError else {
                self.error = error.localizedDescription
                return nil
            }
            let now = Date()
            let localID = UUID().uuidString.lowercased()
            let row = PMCapitalAsset(
                id: localID,
                propertyID: propertyID,
                buildingID: buildingID,
                unitID: unitID,
                commonAreaID: commonAreaID,
                name: name,
                assetType: assetType,
                manufacturer: manufacturer,
                model: model,
                serialNumber: serialNumber,
                installDate: installDate,
                expectedLifespanYears: nil,
                purchaseCost: nil,
                condition: condition,
                warrantyExpires: nil,
                lastServicedAt: nil,
                notes: "",
                createdAt: now,
                updatedAt: now
            )
            var syncPayload: [String: AnyJSON] = [
                "property_id":   .string(propertyID),
                "name":          .string(name),
                "asset_type":    .string(assetType.rawValue),
                "manufacturer":  .string(manufacturer),
                "model":         .string(model),
                "serial_number": .string(serialNumber),
                "condition":     .string(condition.rawValue),
            ]
            if let buildingID { syncPayload["building_id"] = .string(buildingID) }
            if let unitID { syncPayload["unit_id"] = .string(unitID) }
            if let commonAreaID { syncPayload["common_area_id"] = .string(commonAreaID) }
            if let installDate { syncPayload["install_date"] = .string(installDate) }

            capitalAssets.insert(row, at: 0)
            PMSyncService.shared.enqueue(.insert(table: "capital_assets", localID: localID, payload: syncPayload))
            return row
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
            guard error is URLError else {
                capitalAssets[idx].condition = previous
                self.error = error.localizedDescription
                return
            }
            PMSyncService.shared.enqueue(.update(table: "capital_assets", id: asset.id, payload: ["condition": .string(condition.rawValue)]))
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
            guard error is URLError else {
                capitalAssets[idx] = previous
                self.error = error.localizedDescription
                return false
            }
            let payload: [String: AnyJSON] = [
                "name": .string(name),
                "asset_type": .string(assetType.rawValue),
                "manufacturer": .string(manufacturer),
                "model": .string(model),
                "serial_number": .string(serialNumber),
                "install_date": installDate.map { .string($0) } ?? .null,
                "warranty_expires": warrantyExpires.map { .string($0) } ?? .null,
                "last_serviced_at": lastServicedAt.map { .string($0) } ?? .null,
                "notes": .string(notes),
            ]
            PMSyncService.shared.enqueue(.update(table: "capital_assets", id: asset.id, payload: payload))
            return true
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
            guard error is URLError else {
                self.error = error.localizedDescription
                return false
            }
            capitalAssets.removeAll { $0.id == asset.id }
            PMSyncService.shared.enqueue(.softDelete(table: "capital_assets", id: asset.id))
            return true
        }
    }
}
