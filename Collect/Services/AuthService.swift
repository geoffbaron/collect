import Foundation
import SwiftUI
import SwiftData
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUserID: String?
    @Published var currentUserEmail: String?
    @Published var currentUserName: String?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// True after signUp() succeeds — user must verify their email before signing in.
    @Published var pendingEmailVerification = false

    private let auth = SupabaseManager.shared.client.auth
    private var listenerTask: Task<Void, Never>?

    init() {
        startListening()
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - Auth State Listener

    private func startListening() {
        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in auth.authStateChanges {
                guard !Task.isCancelled else { return }
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let user = session?.user {
                        currentUserID    = user.id.uuidString
                        currentUserEmail = user.email
                        currentUserName  = user.userMetadata["name"]?.value as? String
                            ?? user.email?.components(separatedBy: "@").first
                        isAuthenticated  = true
                        pendingEmailVerification = false
                    }
                case .signedOut:
                    clearState()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.signIn(email: email, password: password)
            // isAuthenticated flips via the listener above
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        pendingEmailVerification = false
        do {
            try await auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            // Supabase sends a confirmation email by default.
            // The user won't be signed in until they click the link.
            pendingEmailVerification = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Local guest session — no Supabase account, data stays on-device only.
    /// The guest ID is persisted in UserDefaults so properties survive app restarts.
    func signInAsGuest() {
        let key = "collect_guest_user_id"
        let guestID: String
        if let saved = UserDefaults.standard.string(forKey: key) {
            guestID = saved
        } else {
            guestID = "guest_\(UUID().uuidString)"
            UserDefaults.standard.set(guestID, forKey: key)
        }
        currentUserID    = guestID
        currentUserEmail = nil
        currentUserName  = "Guest"
        isAuthenticated  = true
    }

    func signOut() {
        Task {
            try? await auth.signOut()
            clearState()
        }
    }

    func deleteAccount(modelContext: ModelContext? = nil) async {
        isLoading = true
        // Wipe cloud data before signing out so the session token is still valid
        if let userID = currentUserID, !isGuest {
            let db = SupabaseManager.shared.client
            // Cascade deletes handle floors/rooms/collections/assets via FK
            _ = try? await db.from("properties")
                .delete()
                .eq("user_id", value: userID)
                .execute()
            // Remove uploaded photos
            _ = try? await db.storage.from("asset-photos").remove(paths: [userID + "/"])
            // Clear the migration flag so a fresh sign-in starts clean
            UserDefaults.standard.removeObject(forKey: "collect_migrated_\(userID)")
        }
        if let context = modelContext {
            try? context.delete(model: Asset.self)
            try? context.delete(model: Collection.self)
            try? context.delete(model: Room.self)
            try? context.delete(model: Floor.self)
            try? context.delete(model: Property.self)
        }
        UserDefaults.standard.removeObject(forKey: "collect_onboarding_seen")
        try? await auth.signOut()
        clearState()
        isLoading = false
    }

    // MARK: - Helpers

    /// True when the current session is a local guest (no Supabase account).
    var isGuest: Bool { currentUserID?.hasPrefix("guest_") == true }

    private func clearState() {
        currentUserID    = nil
        currentUserEmail = nil
        currentUserName  = nil
        isAuthenticated  = false
    }
}
