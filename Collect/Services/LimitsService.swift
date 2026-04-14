import Foundation
import SwiftUI

/// Fetches and caches the plan limits and current-month scan usage for the signed-in user.
/// Injected as an environment object so any view can read current limits and quota state.
@MainActor
final class LimitsService: ObservableObject {

    // MARK: - Plan limits
    @Published var limits: UsageLimits = .default

    // MARK: - Monthly scan usage
    @Published var scansThisMonth: Int = 0
    @Published var monthlyLimit:   Int = 5      // mirrors free default until fetched

    /// nil when the plan has unlimited scans
    var scansRemaining: Int? {
        monthlyLimit == -1 ? nil : max(0, monthlyLimit - scansThisMonth)
    }

    var canScan: Bool {
        monthlyLimit == -1 || scansThisMonth < monthlyLimit
    }

    var usageLabel: String {
        guard monthlyLimit != -1 else { return "Unlimited scans" }
        let remaining = max(0, monthlyLimit - scansThisMonth)
        return "\(remaining) of \(monthlyLimit) scans remaining this month"
    }

    // MARK: - Private

    private struct ScanUsageRow: Codable {
        let scansThisMonth: Int
        let monthlyLimit:   Int
        let plan:           String
        enum CodingKeys: String, CodingKey {
            case scansThisMonth = "scans_this_month"
            case monthlyLimit   = "monthly_limit"
            case plan
        }
    }

    private let db = SupabaseManager.shared.client

    // MARK: - Fetch

    func fetch() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchLimits()    }
            group.addTask { await self.refreshUsage()   }
        }
    }

    /// Call after a successful scan to keep the counter accurate without a full fetch.
    func refreshUsage() async {
        do {
            let rows: [ScanUsageRow] = try await db
                .rpc("get_scan_usage")
                .execute()
                .value
            if let row = rows.first {
                scansThisMonth = row.scansThisMonth
                monthlyLimit   = row.monthlyLimit
            }
        } catch {
            print("LimitsService: refreshUsage failed — \(error)")
        }
    }

    func reset() {
        limits         = .default
        scansThisMonth = 0
        monthlyLimit   = 5
    }

    // MARK: - Private helpers

    private func fetchLimits() async {
        do {
            let rows: [UsageLimits] = try await db
                .rpc("get_my_limits")
                .execute()
                .value
            if let first = rows.first { limits = first }
        } catch {
            print("LimitsService: fetchLimits failed — \(error)")
        }
    }
}
