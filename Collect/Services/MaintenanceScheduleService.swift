import Foundation
import Supabase

/// Manages preventive maintenance schedules for a property (optionally
/// scoped to a unit). Server-driven; PM mode only.
@MainActor
final class MaintenanceScheduleService: ObservableObject {

    @Published private(set) var schedules: [PMMaintenanceSchedule] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    func clearError() {
        error = nil
    }

    /// Loads every maintenance schedule for a property (across all units/buildings).
    func load(propertyID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMMaintenanceSchedule] = try await db
                .from("maintenance_schedules")
                .select("*")
                .eq("property_id", value: propertyID)
                .is("deleted_at", value: nil)
                .order("next_due_date", ascending: true)
                .execute()
                .value
            schedules = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Loads maintenance schedules for a single unit.
    func load(unitID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMMaintenanceSchedule] = try await db
                .from("maintenance_schedules")
                .select("*")
                .eq("unit_id", value: unitID)
                .is("deleted_at", value: nil)
                .order("next_due_date", ascending: true)
                .execute()
                .value
            schedules = rows
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
        title: String,
        description: String = "",
        category: WorkOrderCategory = .other,
        frequency: MaintenanceFrequency = .monthly,
        nextDueDate: String
    ) async -> PMMaintenanceSchedule? {
        var payload: [String: String] = [
            "property_id":   propertyID,
            "title":         title,
            "description":   description,
            "category":      category.rawValue,
            "frequency":     frequency.rawValue,
            "next_due_date": nextDueDate,
        ]
        if let buildingID { payload["building_id"] = buildingID }
        if let unitID { payload["unit_id"] = unitID }
        if let commonAreaID { payload["common_area_id"] = commonAreaID }

        do {
            let row: PMMaintenanceSchedule = try await db
                .from("maintenance_schedules")
                .insert(payload)
                .select("*")
                .single()
                .execute()
                .value
            schedules.append(row)
            schedules.sort { $0.nextDueDate < $1.nextDueDate }
            return row
        } catch {
            guard error is URLError else {
                self.error = error.localizedDescription
                return nil
            }
            let now = Date()
            let localID = UUID().uuidString.lowercased()
            let row = PMMaintenanceSchedule(
                id: localID,
                propertyID: propertyID,
                buildingID: buildingID,
                unitID: unitID,
                commonAreaID: commonAreaID,
                title: title,
                description: description,
                category: category,
                frequency: frequency,
                nextDueDate: nextDueDate,
                lastCompletedAt: nil,
                assignedTo: nil,
                active: true,
                createdAt: now,
                updatedAt: now
            )
            var syncPayload: [String: AnyJSON] = [
                "property_id":   .string(propertyID),
                "title":         .string(title),
                "description":   .string(description),
                "category":      .string(category.rawValue),
                "frequency":     .string(frequency.rawValue),
                "next_due_date": .string(nextDueDate),
            ]
            if let buildingID { syncPayload["building_id"] = .string(buildingID) }
            if let unitID { syncPayload["unit_id"] = .string(unitID) }
            if let commonAreaID { syncPayload["common_area_id"] = .string(commonAreaID) }

            schedules.append(row)
            schedules.sort { $0.nextDueDate < $1.nextDueDate }
            PMSyncService.shared.enqueue(.insert(table: "maintenance_schedules", localID: localID, payload: syncPayload))
            return row
        }
    }

    func setActive(_ schedule: PMMaintenanceSchedule, to active: Bool) async {
        guard let idx = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        let previous = schedules[idx].active
        schedules[idx].active = active

        struct RowID: Decodable { let id: String }

        do {
            let updated: [RowID] = try await db
                .from("maintenance_schedules")
                .update(["active": active])
                .eq("id", value: schedule.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                schedules[idx].active = previous
                self.error = "You don't have permission to update this schedule."
            }
        } catch {
            guard error is URLError else {
                schedules[idx].active = previous
                self.error = error.localizedDescription
                return
            }
            PMSyncService.shared.enqueue(.update(table: "maintenance_schedules", id: schedule.id, payload: ["active": .bool(active)]))
        }
    }

    func update(
        _ schedule: PMMaintenanceSchedule,
        title: String,
        description: String,
        category: WorkOrderCategory,
        frequency: MaintenanceFrequency,
        nextDueDate: String
    ) async -> Bool {
        guard let idx = schedules.firstIndex(where: { $0.id == schedule.id }) else { return false }
        let previous = schedules[idx]
        schedules[idx].title = title
        schedules[idx].description = description
        schedules[idx].category = category
        schedules[idx].frequency = frequency
        schedules[idx].nextDueDate = nextDueDate

        struct RowID: Decodable { let id: String }

        do {
            let updated: [RowID] = try await db
                .from("maintenance_schedules")
                .update([
                    "title": title,
                    "description": description,
                    "category": category.rawValue,
                    "frequency": frequency.rawValue,
                    "next_due_date": nextDueDate,
                ])
                .eq("id", value: schedule.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                schedules[idx] = previous
                self.error = "You don't have permission to update this schedule."
                return false
            }
            schedules.sort { $0.nextDueDate < $1.nextDueDate }
            return true
        } catch {
            guard error is URLError else {
                schedules[idx] = previous
                self.error = error.localizedDescription
                return false
            }
            let payload: [String: AnyJSON] = [
                "title": .string(title),
                "description": .string(description),
                "category": .string(category.rawValue),
                "frequency": .string(frequency.rawValue),
                "next_due_date": .string(nextDueDate),
            ]
            schedules.sort { $0.nextDueDate < $1.nextDueDate }
            PMSyncService.shared.enqueue(.update(table: "maintenance_schedules", id: schedule.id, payload: payload))
            return true
        }
    }

    func delete(_ schedule: PMMaintenanceSchedule) async -> Bool {
        struct RowID: Decodable { let id: String }

        do {
            let iso = ISO8601DateFormatter().string(from: Date())
            let updated: [RowID] = try await db
                .from("maintenance_schedules")
                .update(["deleted_at": iso])
                .eq("id", value: schedule.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                self.error = "You don't have permission to delete this schedule."
                return false
            }
            schedules.removeAll { $0.id == schedule.id }
            return true
        } catch {
            guard error is URLError else {
                self.error = error.localizedDescription
                return false
            }
            schedules.removeAll { $0.id == schedule.id }
            PMSyncService.shared.enqueue(.softDelete(table: "maintenance_schedules", id: schedule.id))
            return true
        }
    }
}
