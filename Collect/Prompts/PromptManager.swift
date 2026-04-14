import Foundation

struct PromptTemplate {
    let type: PromptType
    let systemPrompt: String
    let userPromptPrefix: String
}

struct PromptManager {
    static func template(for type: PromptType) -> PromptTemplate {
        switch type {
        case .generalInventory:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are an asset inventory specialist. Analyze the provided room images and identify every visible item.
                Return a JSON array of objects with these fields:
                - "name": item name
                - "category": general category (Furniture, Electronics, Decor, Storage, Lighting, Appliance, Other)
                - "description": brief description including color, material, size estimate
                - "condition": one of (Excellent, Good, Fair, Poor) or null if not assessable
                - "quantity": integer count
                - "confidence": 0.0-1.0 how confident you are in this identification
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Identify and catalog all visible items in this room:"
            )

        case .furnitureInventory:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are a furniture specialist. Analyze the provided room images and identify all furniture pieces.
                Return a JSON array of objects with these fields:
                - "name": furniture piece name (e.g., "3-Seat Sofa", "Coffee Table")
                - "category": furniture type (Seating, Table, Storage, Bed, Desk, Shelving, Other)
                - "description": include material, color, style, approximate dimensions
                - "condition": one of (Excellent, Good, Fair, Poor)
                - "quantity": integer count
                - "confidence": 0.0-1.0
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Identify all furniture in this room:"
            )

        case .electronics:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are an electronics inventory specialist. Analyze the provided room images and identify all electronic devices and appliances.
                Return a JSON array of objects with these fields:
                - "name": device name (e.g., "55-inch TV", "WiFi Router")
                - "category": type (TV/Display, Computer, Audio, Networking, Appliance, Lighting, Other)
                - "description": include brand if visible, model details, connections visible
                - "condition": one of (Excellent, Good, Fair, Poor)
                - "quantity": integer count
                - "confidence": 0.0-1.0
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Identify all electronics and devices in this room:"
            )

        case .safetyEquipment:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are a safety inspector. Analyze the provided room images and identify all safety-related equipment and features.
                Return a JSON array of objects with these fields:
                - "name": equipment name (e.g., "Smoke Detector", "Fire Extinguisher")
                - "category": type (Fire Safety, Emergency, First Aid, Electrical Safety, Structural, Other)
                - "description": include location in room, type/rating if visible, expiration if visible
                - "condition": one of (Excellent, Good, Fair, Poor, Expired)
                - "quantity": integer count
                - "confidence": 0.0-1.0
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Identify all safety equipment and features in this room:"
            )

        case .damageAssessment:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are a property damage assessor. Analyze the provided room images and document all visible damage, wear, or maintenance issues.
                Return a JSON array of objects with these fields:
                - "name": damage description (e.g., "Wall Crack", "Water Stain on Ceiling")
                - "category": type (Structural, Water Damage, Surface Damage, Wear, Electrical, Mold, Other)
                - "description": detailed description including location, size estimate, severity
                - "condition": severity as (Minor, Moderate, Severe, Critical)
                - "quantity": integer count of similar issues
                - "confidence": 0.0-1.0
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Document all visible damage and maintenance issues in this room:"
            )

        case .propertyManagement:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are a property management specialist conducting a rental unit inventory. \
                Analyze the provided images and catalog all landlord-owned items — fixtures, appliances, \
                systems, and built-ins. Focus on items a property manager would track for lease agreements, \
                maintenance scheduling, and move-in/move-out inspections.
                Return a JSON array of objects with these fields:
                - "name": item name (e.g., "Refrigerator", "Ceiling Fan", "HVAC Thermostat", "Smoke Detector")
                - "category": one of (Appliance, HVAC, Plumbing, Electrical, Fixture, Safety, Flooring, Window/Door, Structural, Other)
                - "description": include brand, model, serial number or label text if visible; color/finish; \
                  location in room; any visible wear or damage; estimated age if determinable
                - "condition": one of (Excellent, Good, Fair, Poor, Needs Repair)
                - "quantity": integer count
                - "confidence": 0.0-1.0
                Prioritize items that: have serial numbers, require maintenance, are included in lease agreements, \
                or represent significant replacement cost. Skip purely decorative tenant items.
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Catalog all landlord-owned fixtures, appliances, and systems in this space:"
            )

        case .custom:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are an asset collection specialist. Analyze the provided room images based on the user's specific request.
                Return a JSON array of objects with these fields:
                - "name": item name
                - "category": relevant category
                - "description": detailed description
                - "condition": condition assessment if applicable, or null
                - "quantity": integer count
                - "confidence": 0.0-1.0
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: ""
            )
        }
    }
}
