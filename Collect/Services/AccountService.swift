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

/// A quick combination of product mode + plan that super admins can switch
/// between to preview the app as different kinds of customers, without
/// needing separate test accounts.
enum TestPersona: String, CaseIterable, Identifiable {
    case homeownerFree
    case homeownerPro
    case propertyManagerFree
    case propertyManagerPro
    case propertyManagerEnterprise

    var id: String { rawValue }

    var productMode: ProductMode {
        switch self {
        case .homeownerFree, .homeownerPro:
            return .homeowner
        case .propertyManagerFree, .propertyManagerPro, .propertyManagerEnterprise:
            return .propertyManager
        }
    }

    var plan: String {
        switch self {
        case .homeownerFree, .propertyManagerFree:
            return "free"
        case .homeownerPro, .propertyManagerPro:
            return "pro"
        case .propertyManagerEnterprise:
            return "enterprise"
        }
    }

    var displayName: String {
        switch self {
        case .homeownerFree:           "Homeowner — Free"
        case .homeownerPro:            "Homeowner — Pro"
        case .propertyManagerFree:     "Property Manager — Free"
        case .propertyManagerPro:      "Property Manager — Pro"
        case .propertyManagerEnterprise: "Property Manager — Enterprise"
        }
    }

    /// Matches a persona to the account's current (productMode, plan), if any.
    static func matching(productMode: ProductMode, plan: String) -> TestPersona? {
        allCases.first { $0.productMode == productMode && $0.plan == plan }
    }
}

/// A user's role within an account. Mirrors account_members.role.
enum AccountRole: String, CaseIterable, Codable, Hashable {
    case owner, admin, manager, member, maintenance

    var displayName: String {
        switch self {
        case .owner:       "Owner"
        case .admin:       "Admin"
        case .manager:     "Manager"
        case .member:      "Member"
        case .maintenance: "Maintenance"
        }
    }
}

/// An account member joined with profile name/email — for assignee pickers
/// and labels.
struct TeamMember: Identifiable, Hashable {
    let userID: String
    let role: AccountRole
    let name: String?
    let email: String?

    var id: String { userID }
    var displayName: String { name ?? email ?? "Unknown" }
}

/// Fetches and updates the signed-in account's product mode (and plan).
/// RLS scopes `accounts` to the caller's membership, so a bare select returns
/// exactly their account; the update is allowed only for owners/admins.
@MainActor
final class AccountService: ObservableObject {

    @Published private(set) var productMode: ProductMode = .homeowner
    @Published private(set) var plan: String = "free"
    /// True when the signed-in user has profiles.is_super_admin = true.
    @Published private(set) var isSuperAdmin: Bool = false
    /// The signed-in user's role in their active account.
    @Published private(set) var role: AccountRole?
    /// Everyone in the active account, for assignee pickers. Loaded lazily
    /// via loadMembers().
    @Published private(set) var members: [TeamMember] = []

    var isPropertyManager: Bool { productMode == .propertyManager }
    /// Maintenance staff get a work-order-first experience on mobile.
    var isMaintenance: Bool { role == .maintenance }

    private var accountID: String?
    private let db = SupabaseManager.shared.client

    private struct AccountRow: Codable {
        let id: String
        let product_mode: String
        let plan: String
    }

    private struct ProfileRow: Codable {
        let account_id: String?
        let is_super_admin: Bool?
    }

    /// Fetches the signed-in account's product mode/plan and the user's
    /// super-admin flag. Both lookups are scoped to the current user's id,
    /// since super admins can read every row in `accounts`/`profiles`
    /// (read-all RLS policies) and an unscoped `.single()` would otherwise
    /// match more than one row for them.
    func fetch() async {
        guard let session = try? await db.auth.session else {
            print("AccountService: fetch failed — no session")
            return
        }
        let userID = session.user.id.uuidString.lowercased()

        do {
            let profile: ProfileRow = try await db
                .from("profiles")
                .select("account_id, is_super_admin")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            isSuperAdmin = profile.is_super_admin ?? false

            guard let accountId = profile.account_id else { return }

            let row: AccountRow = try await db
                .from("accounts")
                .select("id, product_mode, plan")
                .eq("id", value: accountId)
                .single()
                .execute()
                .value
            accountID   = row.id
            productMode = ProductMode(rawValue: row.product_mode) ?? .homeowner
            plan        = row.plan

            struct MembershipRow: Codable { let role: String }
            let membership: MembershipRow? = try? await db
                .from("account_members")
                .select("role")
                .eq("account_id", value: accountId)
                .eq("user_id", value: userID)
                .single()
                .execute()
                .value
            role = membership.flatMap { AccountRole(rawValue: $0.role) }
        } catch {
            print("AccountService: fetch failed — \(error)")
        }
    }

    /// Loads every member of the active account with their profile name/email,
    /// for assignee pickers. account_members has no FK to profiles, so this is
    /// two queries instead of an embed.
    func loadMembers() async {
        if accountID == nil { await fetch() }
        guard let accountID else { return }

        struct MemberRow: Codable { let user_id: String; let role: String }
        struct ProfileNameRow: Codable { let id: String; let name: String?; let email: String? }

        do {
            let memberRows: [MemberRow] = try await db
                .from("account_members")
                .select("user_id, role")
                .eq("account_id", value: accountID)
                .order("created_at", ascending: true)
                .execute()
                .value
            let profiles: [ProfileNameRow] = try await db
                .from("profiles")
                .select("id, name, email")
                .in("id", values: memberRows.map(\.user_id))
                .execute()
                .value
            let profileByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            members = memberRows.map { row in
                TeamMember(
                    userID: row.user_id,
                    role: AccountRole(rawValue: row.role) ?? .member,
                    name: profileByID[row.user_id]?.name,
                    email: profileByID[row.user_id]?.email
                )
            }
        } catch {
            print("AccountService: loadMembers failed — \(error)")
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

    /// Applies a (productMode, plan) preset in one update — used by the
    /// super-admin "Test as" persona switcher.
    func applyPersona(_ persona: TestPersona) async {
        if accountID == nil { await fetch() }
        guard let id = accountID else { return }
        let previousMode = productMode
        let previousPlan = plan
        productMode = persona.productMode // optimistic — revert on failure
        plan = persona.plan
        do {
            try await db
                .from("accounts")
                .update(["product_mode": persona.productMode.rawValue, "plan": persona.plan])
                .eq("id", value: id)
                .execute()
        } catch {
            productMode = previousMode
            plan = previousPlan
            print("AccountService: applyPersona failed — \(error)")
        }
    }

    func reset() {
        accountID   = nil
        productMode = .homeowner
        plan        = "free"
        isSuperAdmin = false
        role        = nil
        members     = []
    }
}
