import Foundation

struct UsageLimits: Codable, Equatable {
    let plan:                 String
    let maxVideoSeconds:      Int   // -1 = unlimited
    let maxProperties:        Int   // -1 = unlimited
    let maxRoomsPerProperty:  Int   // -1 = unlimited
    let maxAssetsPerScan:     Int   // -1 = unlimited
    let maxScansPerMonth:     Int   // -1 = unlimited

    // Convenience
    var isVideoUnlimited:      Bool { maxVideoSeconds     == -1 }
    var isPropertiesUnlimited: Bool { maxProperties       == -1 }
    var isScansUnlimited:      Bool { maxScansPerMonth    == -1 }

    /// Safe fallback used before the real limits are fetched.
    static let `default` = UsageLimits(
        plan:                "free",
        maxVideoSeconds:      60,
        maxProperties:        3,
        maxRoomsPerProperty: -1,
        maxAssetsPerScan:    25,
        maxScansPerMonth:     5
    )

    enum CodingKeys: String, CodingKey {
        case plan
        case maxVideoSeconds      = "max_video_seconds"
        case maxProperties        = "max_properties"
        case maxRoomsPerProperty  = "max_rooms_per_property"
        case maxAssetsPerScan     = "max_assets_per_scan"
        case maxScansPerMonth     = "max_scans_per_month"
    }
}
