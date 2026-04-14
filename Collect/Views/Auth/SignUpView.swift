import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool { !password.isEmpty && password == confirmPassword }
    private var formIsValid: Bool { !name.isEmpty && !email.isEmpty && password.count >= 6 && passwordsMatch }

    var body: some View {
        NavigationStack {
            if authService.pendingEmailVerification {
                // MARK: - Verification pending
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    VStack(spacing: 8) {
                        Text("Check your email")
                            .font(.title2.bold())

                        Text("We sent a confirmation link to **\(email)**. Tap it to activate your account, then come back and sign in.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)
                    }

                    Button("Back to Sign In") {
                        authService.pendingEmailVerification = false
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            } else {
                // MARK: - Sign up form
                Form {
                    Section {
                        TextField("Full Name", text: $name)
                            .textContentType(.name)

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }

                    Section {
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)

                        if !password.isEmpty && password.count < 6 {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if let error = authService.errorMessage {
                        Section {
                            Text(error).foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button {
                            Task { await authService.signUp(name: name, email: email, password: password) }
                        } label: {
                            Group {
                                if authService.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Create Account")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(!formIsValid || authService.isLoading)
                    }
                }
                .navigationTitle("Sign Up")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }
}
