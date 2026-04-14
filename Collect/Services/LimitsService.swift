import Foundation
import SwiftUI

/// Fetches and caches the plan limits for the signed-in user.
/// Injected as an environment object so any view can read current limits.
@MainActor
final class LimitsService: ObservableObject {
    @Published var limits: UsageLimits = .default
    @Published var isFetched = false

    private let db = SupabaseManager.shared.client

    func fetch() async {
        do {
            let rows: [UsageLimits] = try await db
                .rpc("get_my_limits")
                .execute()
                .value
            if let first = rows.first {
                limits   = first
                isFetched = true
            }
        } catch {
            print("LimitsService: fetch failed — \(error). Using defaults.")
        }
    }

    func reset() {
        limits   = .default
        isFetched = false
    }
}
