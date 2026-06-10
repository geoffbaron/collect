import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var accountService: AccountService
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

                // MARK: Product mode (account-wide; not available to guests)
                if !authService.isGuest {
                    Section {
                        Picker("Product", selection: Binding(
                            get: { accountService.productMode },
                            set: { newMode in Task { await accountService.setProductMode(newMode) } }
                        )) {
                            ForEach(ProductMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                    } header: {
                        Text("Product")
                    } footer: {
                        Text("Switch between cataloging your own home and managing properties.")
                    }
                }

                // MARK: Super admin persona switcher (testing only)
                if accountService.isSuperAdmin {
                    Section {
                        Picker("Test as", selection: Binding(
                            get: {
                                TestPersona.matching(productMode: accountService.productMode, plan: accountService.plan)
                            },
                            set: { newPersona in
                                guard let newPersona else { return }
                                Task { await accountService.applyPersona(newPersona) }
                            }
                        )) {
                            Text("Custom").tag(Optional<TestPersona>.none)
                            ForEach(TestPersona.allCases) { persona in
                                Text(persona.displayName).tag(Optional(persona))
                            }
                        }
                    } header: {
                        Text("Super Admin")
                    } footer: {
                        Text("Switch this account between product/plan combinations to preview the app as different kinds of customers. This changes your real account's settings.")
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

                // MARK: Cloud sync status
                if !authService.isGuest {
                    Section("Cloud Sync") {
                        switch syncService.syncState {
                        case .idle:
                            Label("Up to date", systemImage: "checkmark.icloud")
                                .foregroundStyle(.secondary)
                        case .syncing:
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text("Syncing…").foregroundStyle(.secondary)
                            }
                        case .error(let msg):
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Sync issue", systemImage: "exclamationmark.icloud")
                                    .foregroundStyle(.orange)
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Sync Now") { syncService.forceDrain() }
                            .disabled(syncService.syncState == .syncing)
                    }
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
