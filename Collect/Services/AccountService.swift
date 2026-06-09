import Foundation
import SwiftUI

/// Which product experience the signed-in account uses. Set on the account
/// (shared by all members), not the individual user. Mirrors the
/// accounts.product_mode column added in the Phase 0 foundation migration.
enum ProductMode: String, CaseIterable, Hashable {
    case homeowner
    case propertyManager = "property_manager"

    var displayName: String {
        switch self {
        case .homeowner:       "Homeowner"
        case .propertyManager: "Property Manager"
        }
    }
}

/// Fetches and updates the signed-in account's product mode (and plan).
/// RLS scopes `accounts` to the caller's membership, so a bare select returns
/// exactly their account; the update is allowed only for owners/admins.
@MainActor
final class AccountService: ObservableObject {

    @Published private(set) var productMode: ProductMode = .homeowner
    @Published private(set) var plan: String = "free"

    var isPropertyManager: Bool { productMode == .propertyManager }

    private var accountID: String?
    private let db = SupabaseManager.shared.client

    private struct AccountRow: Codable {
        let id: String
        let product_mode: String
        let plan: String
    }

    func fetch() async {
        do {
            let row: AccountRow = try await db
                .from("accounts")
                .select("id, product_mode, plan")
                .single()
                .execute()
                .value
            accountID   = row.id
            productMode = ProductMode(rawValue: row.product_mode) ?? .homeowner
            plan        = row.plan
        } catch {
            print("AccountService: fetch failed — \(error)")
        }
    }

    func setProductMode(_ mode: ProductMode) async {
        if accountID == nil { await fetch() }
        guard let id = accountID else { return }
        let previous = productMode
        productMode = mode // optimistic — revert on failure
        do {
            try await db
                .from("accounts")
                .update(["product_mode": mode.rawValue])
                .eq("id", value: id)
                .execute()
        } catch {
            productMode = previous
            print("AccountService: setProductMode failed — \(error)")
        }
    }

    func reset() {
        accountID   = nil
        productMode = .homeowner
        plan        = "free"
    }
}
