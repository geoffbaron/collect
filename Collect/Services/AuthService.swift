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
            for await (event, session) in await auth.authStateChanges {
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
    func signInAsGuest() {
        currentUserID    = "guest_\(UUID().uuidString)"
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
