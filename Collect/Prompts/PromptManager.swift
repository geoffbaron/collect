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

        case .bookInventory:
            return PromptTemplate(
                type: type,
                systemPrompt: """
                You are a book cataloging specialist with expertise in reading spines and covers from photographs. \
                Analyze the provided images and identify every book visible. Read each spine and cover carefully \
                before writing the title — accuracy matters more than speed.

                Return a JSON array with one object per distinct title. Fields:
                - "name": exact title as printed on the spine or cover. If the title is partially obscured, \
                  include whatever is legible. If completely unreadable, use "Unidentified Book".
                - "category": primary genre or subject — choose the single best fit from: \
                  Fiction, Mystery/Thriller, Science Fiction, Fantasy, Romance, Historical Fiction, \
                  Literary Fiction, Biography/Memoir, History, Science, Self-Help, Business, \
                  Philosophy, Religion/Spirituality, Cookbook, Art/Photography, Travel, \
                  Children's, Young Adult, Textbook, Reference, Comics/Graphic Novel, Poetry, Other
                - "description": include the author name if readable; note whether it is hardcover or \
                  paperback if determinable; include series name and volume number if visible; \
                  note publisher or edition if printed on spine; add any other identifying details.
                - "condition": one of (Like New, Good, Fair, Poor, Reading Copy). \
                  "Like New" = no visible wear. "Good" = minor wear, intact spine. \
                  "Fair" = noticeable wear, possible highlighting. "Poor" = heavy wear, damage. \
                  "Reading Copy" = falling apart but text intact.
                - "quantity": number of copies of this exact title visible. Usually 1 — only increment \
                  when you can clearly see duplicate copies of the same edition side by side.
                - "confidence": 0.0–1.0 reflecting how clearly the title and author were readable. \
                  Use 0.9–1.0 for clearly legible spines, 0.5–0.8 for partially obscured, \
                  0.1–0.4 for largely unreadable (inferred from cover art, color, or spine thickness).

                Important rules:
                • One entry per distinct title — never merge different books into one entry.
                • Do not skip thin books or paperbacks even if spines are narrow.
                • If books are stacked horizontally, read the title from the spine orientation.
                • Prefer the title as written on the book over any prior knowledge of the title.
                Return ONLY valid JSON, no markdown or explanation.
                """,
                userPromptPrefix: "Catalog every book visible. Read each spine and cover carefully — title, author, genre, format, and condition:"
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
