import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @State private var apiKey = ""
    @State private var saved = false
    @State private var hasExistingKey = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste your Gemini API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if hasExistingKey && apiKey.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API key is set")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("Your key is stored on-device only and never shared.")
                }

                Section {
                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        Label("Get a free API key", systemImage: "key")
                    }
                }

                Section {
                    Button {
                        Task {
                            await AIService.shared.setAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Text(saved ? "Saved!" : "Save Key")
                            if saved {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deletes your account and all local data from this device.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://aistudio.google.com")!) {
                        Label("Powered by Google Gemini", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete Account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await authService.deleteAccount(modelContext: modelContext) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all local data. This cannot be undone.")
            }
            .onAppear {
                Task {
                    let key = await AIService.shared.apiKey
                    await MainActor.run {
                        hasExistingKey = !key.isEmpty
                        // Show masked placeholder if key exists, blank field for new entry
                        apiKey = ""
                    }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
