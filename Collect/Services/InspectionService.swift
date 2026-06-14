import Foundation
import Supabase

/// Manages inspections for a unit. Server-driven; PM mode only.
@MainActor
final class InspectionService: ObservableObject {

    @Published private(set) var inspections: [PMInspection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = SupabaseManager.shared.client

    func clearError() {
        error = nil
    }

    var lastCompletedMoveIn: PMInspection? {
        inspections.first {
            $0.inspectionType == .moveIn && $0.status == .completed
        }
    }

    func load(for unitID: String) async {
        isLoading = true
        error = nil
        do {
            let rows: [PMInspection] = try await db
                .from("inspections")
                .select("*")
                .eq("unit_id", value: unitID)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            inspections = rows
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(
        unitID: String,
        type: InspectionTypeEnum,
        baselineID: String? = nil
    ) async -> PMInspection? {
        var payload: [String: String] = [
            "unit_id":         unitID,
            "inspection_type": type.rawValue,
        ]
        if let b = baselineID { payload["baseline_inspection_id"] = b }

        do {
            let row: PMInspection = try await db
                .from("inspections")
                .insert(payload)
                .select("*")
                .single()
                .execute()
                .value
            inspections.insert(row, at: 0)
            return row
        } catch {
            guard error is URLError else {
                self.error = error.localizedDescription
                return nil
            }
            // Offline — the walkthrough (rooms/photos) is local SwiftData and
            // can proceed without this row existing server-side yet.
            let now = Date()
            let localID = UUID().uuidString.lowercased()
            let row = PMInspection(
                id: localID,
                unitID: unitID,
                inspectionType: type,
                status: .inProgress,
                inspectorID: nil,
                scheduledAt: nil,
                completedAt: nil,
                notes: "",
                baselineInspectionID: baselineID,
                createdAt: now,
                updatedAt: now
            )
            var syncPayload: [String: AnyJSON] = [
                "unit_id":         .string(unitID),
                "inspection_type": .string(type.rawValue),
                "status":          .string(InspectionStatusEnum.inProgress.rawValue),
            ]
            if let baselineID { syncPayload["baseline_inspection_id"] = .string(baselineID) }

            inspections.insert(row, at: 0)
            PMSyncService.shared.enqueue(.insert(table: "inspections", localID: localID, payload: syncPayload))
            return row
        }
    }

    func complete(_ inspection: PMInspection) async {
        guard let idx = inspections.firstIndex(where: { $0.id == inspection.id }) else { return }
        inspections[idx].status = .completed
        inspections[idx].completedAt = Date()
        do {
            let iso = ISO8601DateFormatter().string(from: Date())
            try await db
                .from("inspections")
                .update(["status": "completed", "completed_at": iso])
                .eq("id", value: inspection.id)
                .execute()
        } catch {
            guard error is URLError else {
                inspections[idx].status = .inProgress
                inspections[idx].completedAt = nil
                self.error = error.localizedDescription
                return
            }
            let iso = ISO8601DateFormatter().string(from: inspections[idx].completedAt ?? Date())
            PMSyncService.shared.enqueue(.update(table: "inspections", id: inspection.id, payload: [
                "status":       .string("completed"),
                "completed_at": .string(iso),
            ]))
        }
    }
}
