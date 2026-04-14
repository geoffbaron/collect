import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Account info
                Section("Account") {
                    if let name = authService.currentUserName {
                        LabeledContent("Name", value: name)
                    }
                    if let email = authService.currentUserEmail {
                        LabeledContent("Email", value: email)
                    }
                    if authService.isGuest {
                        Text("You're in guest mode — create an account to save your data across devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Sign out
                Section {
                    Button(role: .none) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // MARK: Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } footer: {
                    Text("Deletes your account and all data on this device permanently.")
                }

                // MARK: About
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Label("Powered by Google Gemini", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authService.signOut() }
                Button("Cancel", role: .cancel) { }
            }
            .confirmationDialog("Delete Account?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task { await authService.deleteAccount(modelContext: modelContext) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all local data. This cannot be undone.")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "1"
        return "\(version) (\(build))"
    }
}
