import Foundation
import SwiftUI
import SwiftData

// MARK: - Auth Service
// Uses Firebase Auth when configured. Falls back to local-only mode for development.
// To enable Firebase: add FirebaseAuth SPM package and GoogleService-Info.plist,
// then uncomment the Firebase imports and implementation below.

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUserID: String?
    @Published var currentUserEmail: String?
    @Published var currentUserName: String?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaultsKey = "collect_current_user"

    init() {
        restoreSession()
    }

    // MARK: - Local Auth (Development)
    // Replace with Firebase Auth for production

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))

        // TODO: Replace with Firebase Auth
        // do {
        //     let result = try await Auth.auth().signIn(withEmail: email, password: password)
        //     currentUserID = result.user.uid
        //     currentUserEmail = result.user.email
        //     currentUserName = result.user.displayName
        //     isAuthenticated = true
        // } catch {
        //     errorMessage = error.localizedDescription
        // }

        guard isValidEmail(email), !password.isEmpty else {
            errorMessage = "Please enter a valid email and password."
            isLoading = false
            return
        }

        currentUserID = UUID().uuidString
        currentUserEmail = email
        currentUserName = email.components(separatedBy: "@").first
        isAuthenticated = true
        saveSession()
        isLoading = false
    }

    func signUp(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        try? await Task.sleep(for: .milliseconds(500))

        // TODO: Replace with Firebase Auth
        // do {
        //     let result = try await Auth.auth().createUser(withEmail: email, password: password)
        //     let changeRequest = result.user.createProfileChangeRequest()
        //     changeRequest.displayName = name
        //     try await changeRequest.commitChanges()
        //     currentUserID = result.user.uid
        //     currentUserEmail = result.user.email
        //     currentUserName = name
        //     isAuthenticated = true
        // } catch {
        //     errorMessage = error.localizedDescription
        // }

        guard !name.isEmpty else {
            errorMessage = "Please enter your name."
            isLoading = false
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email."
            isLoading = false
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            isLoading = false
            return
        }

        currentUserID = UUID().uuidString
        currentUserEmail = email
        currentUserName = name
        isAuthenticated = true
        saveSession()
        isLoading = false
    }

    func signInAsGuest() async {
        currentUserID = "guest"
        currentUserEmail = nil
        currentUserName = "Guest"
        isAuthenticated = true
        // No session saved — guest state clears on next launch
    }

    func signOut() {
        // TODO: Replace with Firebase Auth
        // try? Auth.auth().signOut()

        currentUserID = nil
        currentUserEmail = nil
        currentUserName = nil
        isAuthenticated = false
        clearSession()
    }

    func deleteAccount(modelContext: ModelContext? = nil) async {
        isLoading = true
        try? await Task.sleep(for: .milliseconds(300))

        // Delete all SwiftData records if context is provided
        if let context = modelContext {
            try? context.delete(model: Asset.self)
            try? context.delete(model: Collection.self)
            try? context.delete(model: Room.self)
            try? context.delete(model: Floor.self)
            try? context.delete(model: Property.self)
        }

        // Clear API key
        await AIService.shared.setAPIKey("")

        // Clear onboarding flag
        UserDefaults.standard.removeObject(forKey: "collect_onboarding_seen")

        // Sign out and wipe session
        currentUserID = nil
        currentUserEmail = nil
        currentUserName = nil
        isAuthenticated = false
        clearSession()
        isLoading = false
    }

    // MARK: - Session Persistence

    private func saveSession() {
        let data: [String: String] = [
            "id": currentUserID ?? "",
            "email": currentUserEmail ?? "",
            "name": currentUserName ?? ""
        ]
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String],
              let id = data["id"], !id.isEmpty else { return }

        currentUserID = id
        currentUserEmail = data["email"]
        currentUserName = data["name"]
        isAuthenticated = true
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
