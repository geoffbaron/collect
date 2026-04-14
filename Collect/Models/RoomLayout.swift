import Foundation

/// Serializable 2D floor plan extracted from a RoomPlan scan
struct RoomLayout: Codable {

    struct Wall: Codable {
        var width: Float    // horizontal span in meters
        var height: Float   // wall height
        var centerX: Float
        var centerZ: Float
        var yaw: Float      // rotation around Y-axis (radians)
    }

    struct Opening: Codable {
        enum Kind: String, Codable { case door, window, opening }
        var kind: Kind
        var width: Float
        var centerX: Float
        var centerZ: Float
        var yaw: Float
    }

    struct PlacedObject: Codable {
        var category: String
        var width: Float
        var depth: Float
        var centerX: Float
        var centerZ: Float
        var yaw: Float
    }

    var roomName: String
    var scannedAt: Date
    var walls: [Wall]
    var openings: [Opening]
    var objects: [PlacedObject]

    // Bounding box in room coords (CGRect x=roomX, y=roomZ)
    var bounds: CGRect {
        var pts: [(Float, Float)] = []
        for w in walls {
            let c = cos(w.yaw), s = sin(w.yaw), hw = w.width / 2
            pts += [(w.centerX + c*hw, w.centerZ + s*hw),
                    (w.centerX - c*hw, w.centerZ - s*hw)]
        }
        guard !pts.isEmpty else { return CGRect(origin: .zero, size: CGSize(width: 10, height: 10)) }
        let xs = pts.map(\.0), zs = pts.map(\.1)
        let pad: Float = 0.6
        return CGRect(
            x: CGFloat(xs.min()! - pad), y: CGFloat(zs.min()! - pad),
            width: CGFloat(xs.max()! - xs.min()! + pad*2),
            height: CGFloat(zs.max()! - zs.min()! + pad*2)
        )
    }

    func toData() -> Data? { try? JSONEncoder().encode(self) }
    static func from(_ data: Data) -> RoomLayout? { try? JSONDecoder().decode(Self.self, from: data) }

    // MARK: - Asset matching

    /// Maps asset name/category keywords to RoomPlan object category strings.
    private static let categoryKeywords: [(keywords: [String], target: String)] = [
        (["sofa", "couch", "loveseat", "sectional", "chesterfield"], "sofa"),
        (["chair", "armchair", "recliner", "stool", "ottoman", "bench"], "chair"),
        (["table", "desk", "nightstand", "coffee table", "dining table", "side table", "end table", "countertop"], "table"),
        (["bed", "mattress", "bunk", "crib", "futon"], "bed"),
        (["tv", "television", "monitor", "display", "screen", "projector"], "television"),
        (["refrigerator", "fridge", "freezer"], "refrigerator"),
        (["toilet", "commode"], "toilet"),
        (["bathtub", "tub", "jacuzzi", "whirlpool"], "bathtub"),
        (["sink", "basin", "lavatory"], "sink"),
        (["stove", "oven", "range", "cooktop", "microwave"], "stove"),
        (["cabinet", "wardrobe", "bookcase", "bookshelf", "shelving", "chest", "dresser", "storage", "armoire", "closet"], "storage"),
        (["washer", "dryer", "washing machine", "laundry"], "washerDryer"),
        (["dishwasher"], "dishwasher"),
        (["fireplace", "hearth", "mantle"], "fireplace"),
        (["stairs", "staircase", "step"], "stairs"),
    ]

    /// Greedily match a list of (name, category) pairs to placed objects.
    /// Returns a dict keyed by index in the input array → matched PlacedObject.
    func matchAssets(_ assets: [(name: String, category: String)]) -> [Int: PlacedObject] {
        var remaining = objects  // pool — each object can only be claimed once
        var result: [Int: PlacedObject] = [:]

        for (idx, asset) in assets.enumerated() {
            let combined = (asset.name + " " + asset.category).lowercased()
            for (keywords, target) in Self.categoryKeywords {
                guard keywords.contains(where: { combined.contains($0) }) else { continue }
                if let matchIdx = remaining.firstIndex(where: { $0.category == target }) {
                    result[idx] = remaining[matchIdx]
                    remaining.remove(at: matchIdx)
                    break
                }
            }
        }
        return result
    }
}
