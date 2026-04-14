import Foundation
import SwiftUI

/// Fetches global feature flags from Supabase at app startup.
/// Readable by the anon key — no authentication required.
/// Defaults to all features enabled if the fetch fails.
@MainActor
final class FeaturesService: ObservableObject {

    // MARK: - Published flags

    /// LiDAR room layout scanning and floor plan views.
    @Published var floorScansEnabled: Bool = true

    /// Property map view and GPS tagging.
    @Published var locationEnabled: Bool = true

    // MARK: - Private

    private struct FlagRow: Codable {
        let key: String
        let enabled: Bool
    }

    private let db = SupabaseManager.shared.client

    // MARK: - Fetch

    func fetch() async {
        do {
            let rows: [FlagRow] = try await db
                .from("feature_flags")
                .select("key, enabled")
                .execute()
                .value

            let map = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0.enabled) })
            floorScansEnabled = map["floor_scans"]       ?? true
            locationEnabled   = map["location_features"] ?? true
        } catch {
            print("FeaturesService: fetch failed — \(error). Defaults: all enabled.")
        }
    }
}
