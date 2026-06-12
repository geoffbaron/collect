import Foundation

/// Manages work orders for a property (optionally scoped to a unit).
/// Server-driven; PM mode only.
@MainActor
final class WorkOrderService: ObservableObject {

    /// Property/unit display context for account-wide lists, keyed by work
    /// order id. Populated by loadAll().
    struct DisplayContext: Hashable {
        let propertyName: String?
        let unitNumber: String?
    }

    @Published private(set) var workOrders: [PMWorkOrder] = []
    @Published private(set) var context: [String: DisplayContext] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    func clearError() {
        error = nil
    }

    /// A work_orders row with its property/unit embeds, decoded from the
    /// same JSON object PMWorkOrder comes from.
    private struct AllRow: Decodable {
        let workOrder: PMWorkOrder
        let propertyName: String?
        let unitNumber: String?

        private enum EmbedKeys: String, CodingKey { case properties, units }
        private struct PropertyEmbed: Decodable { let name: String? }
        private struct UnitEmbed: Decodable { let unit_number: String? }

        init(from decoder: Decoder) throws {
            workOrder = try PMWorkOrder(from: decoder)
            let c = try decoder.container(keyedBy: EmbedKeys.self)
            propertyName = try c.decodeIfPresent(PropertyEmbed.self, forKey: .properties)?.name
            unitNumber   = try c.decodeIfPresent(UnitEmbed.self, forKey: .units)?.unit_number
        }
    }

    /// Loads every work order across the account (all properties), with
    /// property/unit context for display. Server-driven, so it works for
    /// staff who have no local SwiftData properties.
    func loadAll() async {
        isLoading = true
        error = nil
        do {
            let rows: [AllRow] = try await db
                .from("work_orders")
                .select("*, properties(name), units(unit_number)")
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            workOrders = rows.map(\.workOrder)
            context = Dictionary(uniqueKeysWithValues: rows.map {
                ($0.workOrder.id, DisplayContext(propertyName: $0.propertyName, unitNumber: $0.unitNumber))
            })
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

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
        dueDate: String? = nil,
        assignedTo: String? = nil
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
        if let assignedTo { payload["assigned_to"] = assignedTo }

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

        if status == .completed {
            workOrders[idx].completedAt = Date()
        } else {
            workOrders[idx].completedAt = nil
        }

        struct RowID: Decodable { let id: String }

        do {
            let updated: [RowID]
            if status == .completed {
                let iso = ISO8601DateFormatter().string(from: Date())
                updated = try await db
                    .from("work_orders")
                    .update(["status": status.rawValue, "completed_at": iso])
                    .eq("id", value: workOrder.id)
                    .select("id")
                    .execute()
                    .value
            } else {
                updated = try await db
                    .from("work_orders")
                    .update(["status": status.rawValue, "completed_at": nil] as [String: String?])
                    .eq("id", value: workOrder.id)
                    .select("id")
                    .execute()
                    .value
            }
            if updated.isEmpty {
                workOrders[idx].status = previousStatus
                workOrders[idx].completedAt = previousCompletedAt
                self.error = "You don't have permission to update this work order."
            }
        } catch {
            workOrders[idx].status = previousStatus
            workOrders[idx].completedAt = previousCompletedAt
            self.error = error.localizedDescription
        }
    }

    func update(
        _ workOrder: PMWorkOrder,
        title: String,
        description: String,
        category: WorkOrderCategory,
        priority: WorkOrderPriority,
        dueDate: String?,
        assignedTo: String?
    ) async -> Bool {
        guard let idx = workOrders.firstIndex(where: { $0.id == workOrder.id }) else { return false }
        let previous = workOrders[idx]
        workOrders[idx].title = title
        workOrders[idx].description = description
        workOrders[idx].category = category
        workOrders[idx].priority = priority
        workOrders[idx].dueDate = dueDate
        workOrders[idx].assignedTo = assignedTo

        struct RowID: Decodable { let id: String }

        do {
            let updated: [RowID] = try await db
                .from("work_orders")
                .update([
                    "title": title,
                    "description": description,
                    "category": category.rawValue,
                    "priority": priority.rawValue,
                    "due_date": dueDate,
                    "assigned_to": assignedTo,
                ] as [String: String?])
                .eq("id", value: workOrder.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                workOrders[idx] = previous
                self.error = "You don't have permission to update this work order."
                return false
            }
            return true
        } catch {
            workOrders[idx] = previous
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(_ workOrder: PMWorkOrder) async -> Bool {
        struct RowID: Decodable { let id: String }

        do {
            let iso = ISO8601DateFormatter().string(from: Date())
            let updated: [RowID] = try await db
                .from("work_orders")
                .update(["deleted_at": iso])
                .eq("id", value: workOrder.id)
                .select("id")
                .execute()
                .value
            if updated.isEmpty {
                self.error = "You don't have permission to delete this work order."
                return false
            }
            workOrders.removeAll { $0.id == workOrder.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
