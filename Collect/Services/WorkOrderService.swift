import Foundation

/// Manages work orders for a property (optionally scoped to a unit).
/// Server-driven; PM mode only.
@MainActor
final class WorkOrderService: ObservableObject {

    @Published private(set) var workOrders: [PMWorkOrder] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    /// Loads every work order for a property (across all units/buildings).
    func load(propertyID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMWorkOrder] = try await db
                .from("work_orders")
                .select("*")
                .eq("property_id", value: propertyID)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            workOrders = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Loads work orders for a single unit.
    func load(unitID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMWorkOrder] = try await db
                .from("work_orders")
                .select("*")
                .eq("unit_id", value: unitID)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            workOrders = rows
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
        priority: WorkOrderPriority = .medium,
        dueDate: String? = nil
    ) async -> PMWorkOrder? {
        var payload: [String: String] = [
            "property_id": propertyID,
            "title":       title,
            "description": description,
            "category":    category.rawValue,
            "priority":    priority.rawValue,
        ]
        if let buildingID { payload["building_id"] = buildingID }
        if let unitID { payload["unit_id"] = unitID }
        if let commonAreaID { payload["common_area_id"] = commonAreaID }
        if let dueDate { payload["due_date"] = dueDate }

        do {
            let row: PMWorkOrder = try await db
                .from("work_orders")
                .insert(payload)
                .select("*")
                .single()
                .execute()
                .value
            workOrders.insert(row, at: 0)
            return row
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func updateStatus(_ workOrder: PMWorkOrder, to status: WorkOrderStatus) async {
        guard let idx = workOrders.firstIndex(where: { $0.id == workOrder.id }) else { return }
        let previousStatus = workOrders[idx].status
        let previousCompletedAt = workOrders[idx].completedAt
        workOrders[idx].status = status

        var payload: [String: String] = ["status": status.rawValue]
        if status == .completed {
            let iso = ISO8601DateFormatter().string(from: Date())
            payload["completed_at"] = iso
            workOrders[idx].completedAt = Date()
        } else {
            payload["completed_at"] = ""
            workOrders[idx].completedAt = nil
        }

        do {
            if status == .completed {
                try await db
                    .from("work_orders")
                    .update(payload)
                    .eq("id", value: workOrder.id)
                    .execute()
            } else {
                try await db
                    .from("work_orders")
                    .update(["status": status.rawValue, "completed_at": nil] as [String: String?])
                    .eq("id", value: workOrder.id)
                    .execute()
            }
        } catch {
            workOrders[idx].status = previousStatus
            workOrders[idx].completedAt = previousCompletedAt
            self.error = error.localizedDescription
        }
    }
}
