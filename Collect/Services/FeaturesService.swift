import Foundation
import SwiftUI

/// Fetches plan-gated feature access for the signed-in user.
/// Calls get_my_features() which joins the user's plan against plan_features.
/// Defaults to false (no access) — premium features are off until proven otherwise.
@MainActor
final class FeaturesService: ObservableObject {

    // MARK: - Published flags

    /// LiDAR room layout scanning and floor plan views. Pro/Enterprise only.
    @Published var floorScansEnabled: Bool = false

    /// Property map view and GPS tagging. Pro/Enterprise only.
    @Published var locationEnabled: Bool = false

    // MARK: - Private

    private struct FeatureRow: Codable {
        let key: String
        let enabled: Bool
    }

    private let db = SupabaseManager.shared.client

    // MARK: - Fetch (requires auth — joins user's plan)

    func fetch() async {
        do {
            let rows: [FeatureRow] = try await db
                .rpc("get_my_features")
                .execute()
                .value

            let map = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0.enabled) })
            floorScansEnabled = map["floor_scans"]       ?? false
            locationEnabled   = map["location_features"] ?? false
        } catch {
            print("FeaturesService: fetch failed — \(error)")
        }
    }

    func reset() {
        floorScansEnabled = false
        locationEnabled   = false
    }
}
