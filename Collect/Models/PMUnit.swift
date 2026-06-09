import Foundation
import SwiftUI

/// A leasable apartment / dwelling unit. Server-driven (not SwiftData); PM mode only.
struct PMUnit: Identifiable, Codable, Hashable {
    let id: String
    let propertyID: String
    let buildingID: String?
    let unitNumber: String
    let floorNumber: Int?
    let sqft: Int?
    let bedrooms: Double?
    let bathrooms: Double?
    var leaseStatus: LeaseStatus
    var turnStatus: TurnStatus
    var currentTenantName: String?
    var leaseStart: String?
    var leaseEnd: String?
    var monthlyRent: Double?
    var notes: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, sqft, bedrooms, bathrooms, notes
        case propertyID         = "property_id"
        case buildingID         = "building_id"
        case unitNumber         = "unit_number"
        case floorNumber        = "floor_number"
        case leaseStatus        = "lease_status"
        case turnStatus         = "turn_status"
        case currentTenantName  = "current_tenant_name"
        case leaseStart         = "lease_start"
        case leaseEnd           = "lease_end"
        case monthlyRent        = "monthly_rent"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }

    var bedroomLabel: String {
        guard let b = bedrooms else { return "" }
        return b == 0 ? "Studio" : "\(b.formatted(.number.precision(.fractionLength(0...1))))bd"
    }

    var bathroomLabel: String {
        guard let b = bathrooms else { return "" }
        return "\(b.formatted(.number.precision(.fractionLength(0...1))))ba"
    }

    var sizeLabel: String {
        [
            bedroomLabel.isEmpty ? nil : bedroomLabel,
            bathroomLabel.isEmpty ? nil : bathroomLabel,
            sqft.map { "\($0.formatted()) sqft" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

// MARK: - Lease / Turn status

enum LeaseStatus: String, CaseIterable, Codable {
    case vacant, occupied, notice, eviction

    var displayName: String {
        switch self {
        case .vacant:   "Vacant"
        case .occupied: "Occupied"
        case .notice:   "Notice"
        case .eviction: "Eviction"
        }
    }

    var color: Color {
        switch self {
        case .vacant:   .secondary
        case .occupied: .green
        case .notice:   .orange
        case .eviction: .red
        }
    }

    var isActionable: Bool { self == .vacant || self == .notice }
}

enum TurnStatus: String, CaseIterable, Codable {
    case clean
    case needsTurn   = "needs_turn"
    case inProgress  = "in_progress"
    case turned

    var displayName: String {
        switch self {
        case .clean:      "Clean"
        case .needsTurn:  "Needs Turn"
        case .inProgress: "In Progress"
        case .turned:     "Turned"
        }
    }

    var color: Color {
        switch self {
        case .clean:      .green
        case .needsTurn:  .orange
        case .inProgress: .blue
        case .turned:     .green
        }
    }
}
