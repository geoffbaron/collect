import Foundation

enum PromptType: String, CaseIterable, Identifiable {
    case generalInventory
    case furnitureInventory
    case electronics
    case bookInventory
    case safetyEquipment
    case damageAssessment
    case propertyManagement
    case singleItem
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalInventory:   "General Inventory"
        case .furnitureInventory: "Furniture"
        case .electronics:        "Electronics"
        case .bookInventory:      "Books"
        case .safetyEquipment:    "Safety Equipment"
        case .damageAssessment:   "Damage Assessment"
        case .propertyManagement: "Property Management"
        case .singleItem:         "Single Item"
        case .custom:             "Custom Prompt"
        }
    }

    var icon: String {
        switch self {
        case .generalInventory:   "list.clipboard"
        case .furnitureInventory: "sofa"
        case .electronics:        "desktopcomputer"
        case .bookInventory:      "books.vertical"
        case .safetyEquipment:    "exclamationmark.shield"
        case .damageAssessment:   "exclamationmark.triangle"
        case .propertyManagement: "building.2"
        case .singleItem:         "viewfinder"
        case .custom:             "text.cursor"
        }
    }

    var description: String {
        switch self {
        case .generalInventory:   "Identify and catalog all visible items in the room"
        case .furnitureInventory: "Focus on furniture pieces — type, material, condition, and dimensions"
        case .electronics:        "Identify electronic devices, appliances, and their connections"
        case .bookInventory:      "Read every spine and cover — title, author, genre, and condition"
        case .safetyEquipment:    "Locate fire extinguishers, smoke detectors, exit signs, and safety gear"
        case .damageAssessment:   "Document visible damage — cracks, stains, wear, and needed repairs"
        case .propertyManagement: "Catalog landlord-owned fixtures, appliances, and systems with serial numbers and condition"
        case .singleItem:         "Identify just the main item you photograph, ignoring the background"
        case .custom:             "Describe what you want to collect"
        }
    }
}
