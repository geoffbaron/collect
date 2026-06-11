import Foundation
import SwiftUI

/// A major building system or piece of equipment (HVAC, roof, water heater,
/// appliance, etc.) tracked against a property, building, unit, or common area.
/// Server-driven (not SwiftData); PM mode only.
struct PMCapitalAsset: Identifiable, Codable, Hashable {
    let id: String
    let propertyID: String
    let buildingID: String?
    let unitID: String?
    let commonAreaID: String?
    var name: String
    var assetType: CapitalAssetType
    var manufacturer: String
    var model: String
    var serialNumber: String
    var installDate: String?
    var expectedLifespanYears: Int?
    var purchaseCost: Double?
    var condition: CapitalAssetCondition
    var warrantyExpires: String?
    var lastServicedAt: String?
    var notes: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, model, condition, notes
        case propertyID             = "property_id"
        case buildingID              = "building_id"
        case unitID                  = "unit_id"
        case commonAreaID            = "common_area_id"
        case assetType               = "asset_type"
        case manufacturer
        case serialNumber            = "serial_number"
        case installDate             = "install_date"
        case expectedLifespanYears   = "expected_lifespan_years"
        case purchaseCost            = "purchase_cost"
        case warrantyExpires         = "warranty_expires"
        case lastServicedAt          = "last_serviced_at"
        case createdAt               = "created_at"
        case updatedAt               = "updated_at"
    }
}

enum CapitalAssetType: String, CaseIterable, Codable, Hashable {
    case hvac, roof, waterHeater = "water_heater", appliance
    case electricalPanel = "electrical_panel", plumbing, elevator, structural, other

    var displayName: String {
        switch self {
        case .hvac:            "HVAC"
        case .roof:            "Roof"
        case .waterHeater:     "Water Heater"
        case .appliance:       "Appliance"
        case .electricalPanel: "Electrical Panel"
        case .plumbing:        "Plumbing"
        case .elevator:        "Elevator"
        case .structural:      "Structural"
        case .other:           "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .hvac:            "wind"
        case .roof:            "house.fill"
        case .waterHeater:     "flame.fill"
        case .appliance:       "washer.fill"
        case .electricalPanel: "bolt.fill"
        case .plumbing:        "drop.fill"
        case .elevator:        "arrow.up.arrow.down"
        case .structural:      "building.2.fill"
        case .other:           "cube.box.fill"
        }
    }
}

enum CapitalAssetCondition: String, CaseIterable, Codable, Hashable {
    case excellent, good, fair, poor
    case needsReplacement = "needs_replacement"

    var displayName: String {
        switch self {
        case .excellent:        "Excellent"
        case .good:             "Good"
        case .fair:             "Fair"
        case .poor:             "Poor"
        case .needsReplacement: "Needs Replacement"
        }
    }

    var color: Color {
        switch self {
        case .excellent:        .green
        case .good:             .blue
        case .fair:             .orange
        case .poor:             .red
        case .needsReplacement: .red
        }
    }
}
