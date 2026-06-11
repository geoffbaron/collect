import Foundation
import SwiftUI

/// A maintenance ticket against a property, building, unit, or common area.
/// Server-driven (not SwiftData); PM mode only.
struct PMWorkOrder: Identifiable, Codable, Hashable {
    let id: String
    let propertyID: String
    let buildingID: String?
    let unitID: String?
    let commonAreaID: String?
    var title: String
    var description: String
    var category: WorkOrderCategory
    var priority: WorkOrderPriority
    var status: WorkOrderStatus
    var assignedTo: String?
    let reportedBy: String?
    var dueDate: String?
    var completedAt: Date?
    let sourceInspectionID: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, priority, status
        case propertyID         = "property_id"
        case buildingID         = "building_id"
        case unitID              = "unit_id"
        case commonAreaID        = "common_area_id"
        case assignedTo          = "assigned_to"
        case reportedBy          = "reported_by"
        case dueDate             = "due_date"
        case completedAt         = "completed_at"
        case sourceInspectionID  = "source_inspection_id"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }

    var isOpen: Bool { status == .open || status == .inProgress }
}

enum WorkOrderCategory: String, CaseIterable, Codable, Hashable {
    case plumbing, electrical, hvac, appliance, structural, pest, safety, cosmetic, other

    var displayName: String {
        switch self {
        case .plumbing:   "Plumbing"
        case .electrical: "Electrical"
        case .hvac:       "HVAC"
        case .appliance:  "Appliance"
        case .structural: "Structural"
        case .pest:       "Pest Control"
        case .safety:     "Safety"
        case .cosmetic:   "Cosmetic"
        case .other:      "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .plumbing:   "drop.fill"
        case .electrical: "bolt.fill"
        case .hvac:       "wind"
        case .appliance:  "washer.fill"
        case .structural: "building.2.fill"
        case .pest:       "ant.fill"
        case .safety:     "shield.fill"
        case .cosmetic:   "paintbrush.fill"
        case .other:      "wrench.and.screwdriver.fill"
        }
    }
}

enum WorkOrderPriority: String, CaseIterable, Codable, Hashable {
    case low, medium, high, urgent

    var displayName: String {
        switch self {
        case .low:    "Low"
        case .medium: "Medium"
        case .high:   "High"
        case .urgent: "Urgent"
        }
    }

    var color: Color {
        switch self {
        case .low:    .secondary
        case .medium: .blue
        case .high:   .orange
        case .urgent: .red
        }
    }
}

enum WorkOrderStatus: String, CaseIterable, Codable, Hashable {
    case open
    case inProgress = "in_progress"
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .open:       "Open"
        case .inProgress: "In Progress"
        case .completed:  "Completed"
        case .cancelled:  "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .open:       .orange
        case .inProgress: .blue
        case .completed:  .green
        case .cancelled:  .secondary
        }
    }
}
