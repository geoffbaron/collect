import Foundation
import SwiftUI

/// A recurring maintenance task (e.g. "Replace HVAC filter") for a property,
/// building, unit, or common area. Server-driven (not SwiftData); PM mode only.
struct PMMaintenanceSchedule: Identifiable, Codable, Hashable {
    let id: String
    let propertyID: String
    let buildingID: String?
    let unitID: String?
    let commonAreaID: String?
    var title: String
    var description: String
    var category: WorkOrderCategory
    var frequency: MaintenanceFrequency
    var nextDueDate: String
    var lastCompletedAt: String?
    var assignedTo: String?
    var active: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, frequency, active
        case propertyID         = "property_id"
        case buildingID         = "building_id"
        case unitID              = "unit_id"
        case commonAreaID        = "common_area_id"
        case nextDueDate         = "next_due_date"
        case lastCompletedAt     = "last_completed_at"
        case assignedTo          = "assigned_to"
        case createdAt           = "created_at"
        case updatedAt           = "updated_at"
    }

    /// `nextDueDate` is a "YYYY-MM-DD" date with no timezone. Comparing it as a
    /// UTC-parsed Date against the local start-of-day would mark a schedule
    /// overdue a day early for users west of UTC, so compare date strings
    /// (both "YYYY-MM-DD") directly instead.
    var isOverdue: Bool {
        guard active else { return false }
        return nextDueDate < PMMaintenanceSchedule.todayString()
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}

enum MaintenanceFrequency: String, CaseIterable, Codable, Hashable {
    case daily, weekly, monthly, quarterly, semiannual, annual

    var displayName: String {
        switch self {
        case .daily:      "Daily"
        case .weekly:     "Weekly"
        case .monthly:    "Monthly"
        case .quarterly:  "Quarterly"
        case .semiannual: "Semiannual"
        case .annual:     "Annual"
        }
    }

    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
