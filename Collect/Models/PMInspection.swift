import Foundation

/// An inspection visit to a unit. Server-driven (not SwiftData); PM mode only.
struct PMInspection: Identifiable, Codable, Hashable {
    let id: String
    let unitID: String
    let inspectionType: InspectionTypeEnum
    var status: InspectionStatusEnum
    let inspectorID: String?
    let scheduledAt: Date?
    var completedAt: Date?
    var notes: String
    let baselineInspectionID: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, notes, status
        case unitID              = "unit_id"
        case inspectionType      = "inspection_type"
        case inspectorID         = "inspector_id"
        case scheduledAt         = "scheduled_at"
        case completedAt         = "completed_at"
        case baselineInspectionID = "baseline_inspection_id"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }

    var isCompleted: Bool { status == .completed }
}

enum InspectionTypeEnum: String, CaseIterable, Codable, Hashable {
    case moveIn  = "move_in"
    case moveOut = "move_out"
    case routine
    case turn

    var displayName: String {
        switch self {
        case .moveIn:  "Move-In"
        case .moveOut: "Move-Out"
        case .routine: "Routine"
        case .turn:    "Turn"
        }
    }

    var systemImage: String {
        switch self {
        case .moveIn:  "door.right.hand.open"
        case .moveOut: "door.right.hand.closed"
        case .routine: "calendar.badge.checkmark"
        case .turn:    "arrow.trianglehead.2.clockwise"
        }
    }
}

enum InspectionStatusEnum: String, Codable, Hashable {
    case inProgress = "in_progress"
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .inProgress: "In Progress"
        case .completed:  "Completed"
        case .cancelled:  "Cancelled"
        }
    }
}
